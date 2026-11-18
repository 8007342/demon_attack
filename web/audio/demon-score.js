/* The MIDI-first score player (adaptive-soundtrack design §5.1, §11.4, §12): one committed multitrack score per
   section (web/audio/score/, written by tools/score/score_gen.lua), played on the song's bar grid by synth voices,
   moved between sections by SongDirector (lib/game/song_director.dart) through demonAudio.song(move). It is the
   game's only music: the overture, every sector, every carrier, the bridges between them, the defeat and the coda.

   It runs inside demon-audio.js's scheduler (one audio clock, one 25 ms timer): tick(until) schedules every note up
   to `until` (a lookahead of LOOKAHEAD seconds) with start(when) on the audio clock, so the main thread only does a
   few node creations per tick and timing never depends on frame rate.

   The combining rules, all on the audio clock:
   - Section moves land on the requested time, which SongDirector puts on a bar or beat line of the playing section.
     A move that would fall inside the already-scheduled window slips to the next line instead (state.slipped counts
     these). The latest pending move replaces an earlier one. A `now` move (the defeat) lands 30 ms ahead and
     cancels whatever was scheduled past it.
   - `enter: same` keeps the bar position (modulo the destination's length); `start` begins at its first bar.
   - Tails and bridges hand over to `next` at their own end; a tail without one repeats its hold bars. `next` may
     name another song (`song:section`), and a move's `then` overrides it (the bridge into the tour's carrier): the
     next song's grid starts on the bridge's last bar line.
   - A section with `fx: worldized` passes the music through a mono band-pass (300 Hz-4 kHz, design §4.4) while it
     plays; the next section opens it again.
   - Intensity is a track mask (song-map tier masks plus the v2, power and fleet layers) applied on the requested
     line: newly audible tracks fade in over 20 ms, silenced ones out over 60 ms, notes of silent tracks are not
     scheduled. Nothing restarts.
   - Held notes of the section being left are released over 30 ms at the move.
   - Stingers are short scores in scale degrees, transposed to the playing section's key and put on its grid.
     A stinger with `break` (the 1UP) silences the section over its stop-time; an unknown accent plays nothing.
   - Voices: a key struck again on its track chokes its previous note; lead and bass are monophonic; at most 48
     voices (32 on phones), stealing pads first, then leads, never kick, snare or bass.
   - Loading: score.json, then each song's sections in parallel, song by song in the run's order (the overture and
     Krybor first). A move to a song still loading runs once it has loaded.

   Voices are synthesis (the guaranteed-everywhere layer, §11.8 step 2) until the CC0 sample bank plays them
   (design §12.9). makeVoice() is the seam: with web/audio/bank/bank.json present (tools/bank/bank_build.lua), a note
   whose zone has decoded plays an AudioBufferSourceNode (zone, playbackRate, velocity layer, round robin, loop)
   into the same role bus, through the same voice rules and cap. The bank loads progressively after the score, one
   Opus sprite at a time in priority order (core, then cymbals, pads, timpani and bells, then extra layers and round
   robins), within 41 MB decoded on desktop and 16 MB on phones (the phone tier skips the sprites the bank marks
   desktop-only). Until a note's zone decodes, the synth voice plays it. A section's track plays from the bank only
   if the bank covers every one of its notes, so a part never changes timbre in the middle of a section. With no
   bank.json, nothing else is fetched or created: the synth path is exactly as before.

   The bank is off by default (BANK_DEFAULT) until the operator approves it (design §12.9.7): `?bank=1` (or 0) in the
   page's URL decides for that load, else the per-device choice the /console music panel stores
   (demonAttack.scoreBank = 'on' | 'off'), else BANK_DEFAULT. While it is off not even bank.json is fetched. */
(() => {
  'use strict';
  const LOOKAHEAD = .25;          // seconds of score scheduled ahead of the audio clock
  const MARGIN = .03;
  const OUT_GAIN = .55;           // the score's output gain before its section trim             // a requested time closer than this to now is re-quantised
  const root = new URL('./audio/score/', document.baseURI);
  // --- sample-bank: the switch. Flip to true once the operator approves the sampled score (design §12.9.7).
  const BANK_DEFAULT = false;
  const BANK_KEY = 'demonAttack.scoreBank';
  function storage() { try { return window.localStorage || null; } catch { return null; } }
  function bankChoice() {
    try {
      const q = String(window.location?.search || '').match(/[?&]bank=([^&#]*)/);
      if (q) return q[1] === '1' || q[1] === 'on' || q[1] === 'true';
    } catch { /* no location */ }
    try { const v = storage()?.getItem(BANK_KEY); if (v === 'on' || v === 'off') return v === 'on'; } catch { /* denied storage */ }
    return BANK_DEFAULT;
  }

  // --- SMF type 1 with track names (the conductor track first). Notes: {beat, len, pitch, vel}, sorted by beat.
  function parseScore(buffer) {
    const data = new Uint8Array(buffer), view = new DataView(buffer);
    const text = (from, size) => { let s = ''; for (let i = 0; i < size; i++) s += String.fromCharCode(data[from + i]); return s; };
    if (text(0, 4) !== 'MThd') throw new Error('not a MIDI file');
    const tracks = view.getUint16(10), ppq = view.getUint16(12);
    let pos = 8 + view.getUint32(4);
    const out = { ppq, tracks: {}, markers: [] };
    for (let n = 0; n < tracks; n++) {
      if (text(pos, 4) !== 'MTrk') throw new Error('missing track chunk');
      const end = pos + 8 + view.getUint32(pos + 4);
      let p = pos + 8, tick = 0, status = 0, name = `track${n}`;
      const notes = [], open = new Map();
      const vlq = () => { let v = 0, b; do { b = data[p++]; v = (v << 7) | (b & 127); } while (b & 128); return v; };
      while (p < end) {
        tick += vlq();
        if (data[p] & 128) status = data[p++];
        if (status === 0xff) {
          const type = data[p++], size = vlq();
          if (type === 0x03) name = text(p, size);
          if (type === 0x06) out.markers.push({ beat: tick / ppq, name: text(p, size) });
          p += size;
          if (type === 0x2f) break;
          continue;
        }
        if (status === 0xf0 || status === 0xf7) { p += vlq(); continue; }
        const kind = status & 0xf0;
        if (kind === 0xc0 || kind === 0xd0) { p += 1; continue; }
        const pitch = data[p++], vel = data[p++];
        if (kind === 0x90 && vel) {
          const list = open.get(pitch) || []; list.push({ tick, vel }); open.set(pitch, list);
        } else if (kind === 0x80 || kind === 0x90) {
          const on = open.get(pitch)?.shift();
          if (on) notes.push({ beat: on.tick / ppq, len: (tick - on.tick) / ppq, pitch, vel: on.vel });
        }
      }
      if (n > 0) { notes.sort((a, b) => a.beat - b.beat || a.pitch - b.pitch); out.tracks[name] = notes; }
      pos = end;
    }
    return out;
  }
  // First index with notes[i].beat >= beat.
  function lowerBound(notes, beat) {
    let lo = 0, hi = notes.length;
    while (lo < hi) { const mid = (lo + hi) >> 1; if (notes[mid].beat < beat - 1e-9) lo = mid + 1; else hi = mid; }
    return lo;
  }
  const scales = { minor: [0, 2, 3, 5, 7, 8, 10], major: [0, 2, 4, 5, 7, 9, 11] };
  const frequency = pitch => 440 * 2 ** ((pitch - 69) / 12);

  function create(host) {
    // host: { input(), lifeLoss: [names] }
    let manifest = null, failed = false, context = null, out = null, wanted = null, loadError = null, fx = null;
    const songs = new Map();       // id -> { spec, sections: Map(id -> { spec, score }) }
    let current = null;            // { id, song, section, startAt, entry, spec, data, songSpec }
    let pending = null;            // a section move { at, song, section, enter, reason }
    let maskEvents = [];           // [{ at, tier?, variant?, fleet?, power? }] in time order
    let breaks = [];               // stop-times of a stinger's `break`: [{ from, to }] (the section's own notes rest)
    const mask = { tier: 1, variant: 'v1', fleet: false, power: 0 };
    let audible = new Set();
    let scheduledUntil = 0, segment = 0, slipped = 0, stolen = 0;
    const voices = new Set(), moveLog = [], stingLog = [], lastSting = new Map();
    const trackGains = new Map(), buses = {};
    const cap = phoneClass() ? 32 : 48;

    function phoneClass() {
      try { if ((navigator.deviceMemory ?? 8) <= 4) return true; } catch { /* no navigator */ }
      try { return !!window.matchMedia?.('(pointer: coarse)').matches; } catch { return false; }
    }

    // --- loading: score.json (~50 KB), then the songs in the run's order, each song's sections fetched in
    // parallel and parsed as they arrive (a section is a few KB: no long task). The whole run is ~340 KB of MIDI,
    // ~115 KB gzipped; the overture and Krybor are ready first.
    function loadOrder(map) {
      const family = id => (map.songs[id]?.form === 'carrier' ? 'c' : id);
      const order = [];
      const add = id => { if (id && map.songs[id] && !order.includes(id)) order.push(id); };
      for (const scene of ['menu', 'credits', 'gameover']) add(map.scenes?.[scene]?.split(':')[0]); // credits-page: the title's CREDITS song early
      for (const play of map.plays || []) {
        for (const [pair, bridge] of Object.entries(map.bridges || {})) if (pair.split('>')[1] === family(play.song)) add(bridge);
        add(play.song);
      }
      for (const id of Object.keys(map.songs)) add(id);
      return order;
    }
    async function loadSong(id, spec) {
      const parsed = await Promise.all(Object.entries(spec.sections).map(async ([sid, sspec]) => {
        const res = await fetch(new URL(sspec.file, root));
        if (!res.ok) throw new Error(`score section ${sspec.file} unavailable`);
        return [sid, { spec: sspec, score: parseScore(await res.arrayBuffer()) }];
      }));
      songs.set(id, { spec, sections: new Map(parsed) });
    }
    // --- mix-retune: per-section level trims (dB), generated by tools/mix_meter/trim.mjs into mix-trim.json. Keys
    // are `song:section@tier` (sections that follow the tier masks) or `song:section` (fixed-mask sections). A missing
    // file or key is 0 dB: the score plays as written.
    // With the bank on, the trims measured on the sampled score (mix-trim.json `bank`), when the file has them.
    let trimFile = null, trims = null, trimDb = 0;
    const pickTrims = () => { trims = (bankOn && trimFile?.bank?.trims) || trimFile?.trims || null; };
    const trimFetch = Promise.resolve().then(() => fetch(new URL('mix-trim.json', root)))
      .then(r => (r.ok ? r.json() : null)).catch(() => null);
    // --- score-sampler: the CC0 sample bank (design §12.9). bank.json is tiny; the sprites load after attach().
    // --- sample-bank: only when the switch is on (host.bank overrides it, for tests and the meter).
    let bankOn = typeof host?.bank === 'boolean' ? host.bank : bankChoice();
    const bankRoot = new URL('./audio/bank/', document.baseURI);
    let bankFetch = null;
    const bankSpec = () => (bankFetch ||= Promise.resolve().then(() => fetch(new URL('bank.json', bankRoot)))
      .then(r => (r.ok ? r.json() : null)).catch(() => null));
    if (bankOn) bankSpec();
    let bank = null, bankLoading = null;
    const bankState = { present: false, tier: null, sprites: 0, loaded: 0, skipped: 0, failedSprites: 0, decodedBytes: 0, budget: 0,
      zones: 0, ready: 0, sampled: 0, synth: 0, error: null };
    const loading = (async () => {
      try {
        const response = await fetch(new URL('score.json', root));
        if (!response.ok) throw new Error('score unavailable');
        const map = await response.json();
        trimFile = await trimFetch;
        pickTrims();
        for (const id of loadOrder(map)) {
          await loadSong(id, map.songs[id]);
          if (!manifest) manifest = map;   // ready once the first song is parsed
          flushWanted();
        }
      } catch (error) { failed = true; loadError = String(error?.message || error); }
      flushWanted();
    })();
    const ready = () => !!manifest && !failed && !!context;
    const loaded = id => songs.has(id);
    // `next` (or a move's `then`): a section of the same song, or `song:section`.
    function successor(seg) {
      const next = seg.then || seg.spec.next;
      if (!next) return null;
      const i = next.indexOf(':');
      return i < 0 ? { song: seg.song, section: next } : { song: next.slice(0, i), section: next.slice(i + 1) };
    }

    // --- the grid of the playing section ----------------------------------------------------------------------
    const beatSeconds = (songId) => songs.get(songId).spec.barSamples / 48000 / 4;
    const segBeat = (seg, t) => seg.entry + (t - seg.startAt) / beatSeconds(seg.song);
    const segTime = (seg, beat) => seg.startAt + (beat - seg.entry) * beatSeconds(seg.song);
    function nextLine(seg, after, beats) {
      const g = segBeat(seg, after);
      return segTime(seg, Math.ceil(g / beats - 1e-9) * beats);
    }
    // When a tail or bridge with a successor reaches its end (Infinity for loops and held tails).
    function boundary(seg) {
      if (!seg || seg.spec.kind === 'loop' || seg.stalled || !successor(seg)) return Infinity;
      return segTime(seg, seg.spec.bars * 4);
    }

    // --- masks ------------------------------------------------------------------------------------------------
    function audibleSet(seg) {
      const set = new Set();
      if (!seg) return set;
      const layers = manifest.layers;
      if (seg.spec.mask === 'all') {
        for (const name of seg.spec.tracks) if (!layers.fleet.includes(name)) set.add(name);
      } else {
        const masks = seg.spec.masks || seg.songSpec.masks || manifest.masks;
        for (const name of masks[String(mask.tier)] || masks['1']) set.add(name);
        if (mask.variant === 'v2') for (const name of layers.v2) set.add(name);
        if (mask.power > 0) for (const name of layers.power) set.add(name);
      }
      if (mask.fleet) for (const name of layers.fleet) set.add(name);
      return set;
    }
    // Ramps every track gain to the new mask at `at`: 20 ms in, 60 ms out.
    function applyMask(at) {
      const next = audibleSet(current);
      for (const [name, gain] of trackGains) {
        const on = next.has(name), was = audible.has(name);
        if (on === was) continue;
        for (const g of gain.sampled ? [gain, gain.sampled] : [gain]) {
          g.gain.cancelScheduledValues?.(at);
          g.gain.setValueAtTime(on ? 0 : 1, at);
          g.gain.linearRampToValueAtTime(on ? 1 : 0, at + (on ? .02 : .06));
        }
      }
      audible = next;
    }
    // The playing section's trim, ramped on the score's own output gain at the line where the section or tier changes
    // (moves and mask changes land on bar or beat lines), so the level follows the music's own grid.
    const TRIM_GLIDE = .05;
    const trimKey = seg => (seg.spec.mask === 'all' ? `${seg.song}:${seg.section}` : `${seg.song}:${seg.section}@${mask.tier}`);
    function applyTrim(at) {
      const db = current && trims ? (trims[trimKey(current)] ?? 0) : 0;
      if (!out || db === trimDb) return;
      trimDb = db;
      out.gain.cancelScheduledValues?.(at);
      out.gain.setTargetAtTime(OUT_GAIN * 10 ** (db / 20), at, TRIM_GLIDE);
    }
    // --- bank-fidelity: a role whose synth bus distorts (the bass's drive) gets a twin gain into its clean bus for
    // sampled voices (`sampled`), masked together with the track's gain (design §12.11).
    function trackGain(name) {
      let gain = trackGains.get(name);
      if (!gain) {
        const role = manifest.tracks[name]?.role || 'lead';
        gain = context.createGain();
        gain.gain.value = 1;
        gain.connect(bus(role));
        gain.sampled = sampledInput(role, 1);
        trackGains.set(name, gain);
      }
      return gain;
    }
    function sampledInput(role, value) {
      const clean = buses[sampledBus[roleBus[role]]];
      if (!clean) return null;
      const g = gainNode(value);
      g.connect(clean);
      return g;
    }

    // --- the bus graph: per role, into the music chain (host.input(): demon-audio's music bus input) ----------
    const node = (factory, ...args) => (typeof context[factory] === 'function' ? context[factory](...args) : null);
    function chain(...nodes) {
      const list = nodes.filter(Boolean);
      for (let i = 0; i + 1 < list.length; i++) list[i].connect(list[i + 1]);
      return list;
    }
    function filter(type, freq, q = .7, gainDb = 0) {
      const f = node('createBiquadFilter');
      if (!f) return null;
      f.type = type; f.frequency.value = freq; f.Q.value = q; if (f.gain) f.gain.value = gainDb;
      return f;
    }
    function gainNode(value) { const g = context.createGain(); g.gain.value = value; return g; }
    // tanh drive curve; `drive` sets the gain stage, `bias` a little asymmetry (even harmonics).
    function shaper(drive, bias = 0) {
      const s = node('createWaveShaper');
      if (!s) return null;
      const n = 2048, curve = new Float32Array(n), norm = Math.tanh(drive * (1 + Math.abs(bias)));
      for (let i = 0; i < n; i++) { const x = i * 2 / (n - 1) - 1; curve[i] = Math.tanh(drive * (x + bias * x * x)) / norm; }
      s.curve = curve; s.oversample = phoneClass() ? '2x' : '4x';
      return s;
    }
    function reverb(seconds) {
      const conv = node('createConvolver');
      if (!conv || typeof context.createBuffer !== 'function') return null;
      const rate = context.sampleRate || 48000, length = Math.floor(rate * seconds);
      const ir = context.createBuffer(2, length, rate);
      let seed = 1982;
      for (let ch = 0; ch < 2; ch++) {
        const d = ir.getChannelData(ch);
        for (let i = 0; i < length; i++) { seed = (seed * 16807) % 2147483647; d[i] = (seed / 1073741823.5 - 1) * Math.exp(-4.5 * i / length); }
      }
      conv.buffer = ir;
      return conv;
    }
    function buildBuses() {
      out = gainNode(OUT_GAIN);
      // The worldized chain (design §4.4): a band-pass that is wide open until a section asks for it, and a mono
      // fold (a one-channel gain downmixes, the next stage upmixes to the centre) crossfaded with the stereo path.
      const low = filter('highpass', 20, .7), high = filter('lowpass', 20000, .7);
      if (low && high) {
        chain(out, low, high);
        const stereo = gainNode(1), mono = gainNode(0), fold = gainNode(1);
        fold.channelCount = 1; fold.channelCountMode = 'explicit'; fold.channelInterpretation = 'speakers';
        high.connect(stereo); stereo.connect(host.input());
        high.connect(fold); fold.connect(mono); mono.connect(host.input());
        fx = { low, high, stereo, mono, on: false };
      } else out.connect(host.input());
      const wet = gainNode(.32), room = reverb(phoneClass() ? 1.1 : 1.7);
      if (room) chain(room, wet, out);
      const send = (from, amount) => { if (room) { const g = gainNode(amount); from.connect(g); g.connect(room); } };
      const pan = value => { const p = node('createStereoPanner'); if (p) p.pan.value = value; return p; };
      // Drums: dry, with a little room.
      buses.drums = gainNode(.9); buses.drums.connect(out); send(buses.drums, .1);
      // Bass: light drive, then a low-pass blend.
      buses.bass = gainNode(.8);
      chain(buses.bass, shaper(1.6, .08), filter('lowpass', 2800, .8), gainNode(.9), out);
      // --- bank-fidelity: the sampled bass skips the drive. Growlybass is a DI recording, and its role level (3.7, to
      // match the synth's loudness) drove this shaper three times hotter than the synth does: THD+N -7.6 dB across the
      // stage, against the synth's -22.6 dB (design §12.11). Its clean bus has the same gains and no nonlinear stage.
      buses.bassSampled = gainNode(.8);
      chain(buses.bassSampled, gainNode(.9), out);
      // Guitars: pre-EQ -> two gain stages through tanh shapers -> a cabinet of filters (high-pass 80 Hz, a notch
      // near 400 Hz, presence at 2-3 kHz, low-pass 5.5 kHz) -> left and right doubles with different curves.
      const guitar = (side, drive, bias, presence) => {
        const input = gainNode(1);
        const output = gainNode(.42);
        chain(input, filter('highpass', 110, .7), gainNode(3.2), shaper(drive, bias), gainNode(.9), shaper(2.2, 0),
          filter('highpass', 80, .7), filter('peaking', 400, 1.2, -5), filter('peaking', presence, .9, 4),
          filter('lowpass', 5500, .7), pan(side), output, out);
        send(output, .06);
        return input;
      };
      buses.guitarL = guitar(-.65, 5.5, .12, 2400);
      buses.guitarR = guitar(.65, 6.2, -.08, 2900);
      // Lead: medium drive, a cabinet, a dotted-eighth echo and room.
      buses.lead = gainNode(1);
      const leadOut = gainNode(.32);
      chain(buses.lead, gainNode(2), shaper(3, .05), filter('peaking', 1800, 1, 3), filter('lowpass', 5200, .7), leadOut, out);
      const delay = node('createDelay', 1);
      if (delay) {
        delay.delayTime.value = .3;
        const fb = gainNode(.28), dwet = gainNode(.16);
        leadOut.connect(delay); delay.connect(fb); fb.connect(delay); delay.connect(dwet); dwet.connect(out);
      }
      send(leadOut, .22);
      // Pads and the clean guitar: dry plus a long room.
      buses.pad = gainNode(.5); buses.pad.connect(out); send(buses.pad, .45);
      buses.clean = gainNode(.5); buses.clean.connect(out); send(buses.clean, .35);
      buses.perc = gainNode(.7); buses.perc.connect(out); send(buses.perc, .3);
      buses.sting = gainNode(1);
    }
    const roleBus = { drums: 'drums', bass: 'bass', guitarL: 'guitarL', guitarR: 'guitarR', lead: 'lead', clean: 'clean',
      organ: 'pad', strings: 'pad', brass: 'pad', choir: 'pad', timpani: 'perc', bells: 'perc', uke: 'clean' };
    function bus(role) { return buses[roleBus[role] || 'pad']; }
    const sampledBus = { bass: 'bassSampled' };

    // --- voices -------------------------------------------------------------------------------------------------
    let noise = null;
    function noiseBuffer() {
      if (noise || typeof context.createBuffer !== 'function') return noise;
      const rate = context.sampleRate || 48000;
      noise = context.createBuffer(1, rate, rate);
      const d = noise.getChannelData(0);
      let seed = 7;
      for (let i = 0; i < d.length; i++) { seed = (seed * 16807) % 2147483647; d[i] = seed / 1073741823.5 - 1; }
      return noise;
    }
    // One voice: sources -> (per-voice filter) -> envelope gain -> destination. Returns { sources, gain, end }.
    function voiceFrame(destination, at) {
      const env = context.createGain();
      env.gain.value = 0;
      env.gain.setValueAtTime(0, at);
      env.connect(destination);
      return { env, sources: [], nodes: [env] };
    }
    function osc(frame, type, freq, at, input, detune = 0) {
      const o = context.createOscillator();
      o.type = type;
      o.frequency.setValueAtTime(freq, at);
      if (detune && o.detune) o.detune.value = detune;
      o.connect(input || frame.env);
      frame.sources.push(o);
      return o;
    }
    function noiseSource(frame, at, input) {
      const buffer = noiseBuffer();
      if (!buffer || typeof context.createBufferSource !== 'function') return null;
      const s = context.createBufferSource();
      s.buffer = buffer;
      s.connect(input || frame.env);
      frame.sources.push(s);
      return s;
    }
    function perNoteFilter(frame, type, freq, q) {
      const f = filter(type, freq, q);
      if (!f) return frame.env;
      f.connect(frame.env);
      frame.nodes.push(f);
      return f;
    }
    // Envelope: attack to `peak`, exponential decay toward `sustain` over `decay`, release at the note's end.
    function envelope(frame, at, dur, peak, attack, decay, sustain, release) {
      const g = frame.env.gain;
      g.setValueAtTime(0, at);
      g.linearRampToValueAtTime(peak, at + attack);
      if (sustain < 1) g.setTargetAtTime(peak * Math.max(sustain, .0001), at + attack, decay / 3);
      const off = at + Math.max(attack + .005, dur);
      g.setTargetAtTime(0, off, release / 3);
      return off + release * 2;
    }
    const tomHz = { 41: 82, 43: 98, 45: 116, 47: 134, 48: 156, 50: 182 };
    // The seam for the sample bank: role, pitch, velocity -> a voice into `dest`. A bank zone when the note's track
    // may sample (`sample`) and its zone has decoded, else synthesis.
    function makeVoice(role, pitch, vel, at, dur, dest, sample = true) {
      if (bankOn && bank && sample) {
        const voice = sampleVoice(role, pitch, vel, at, dur, dest);
        if (voice) return voice;
      }
      return synthVoice(role, pitch, vel, at, dur, dest);
    }
    function synthVoice(role, pitch, vel, at, dur, dest) {
      const v = vel / 127, frame = voiceFrame(dest, at);
      let end;
      const f = frequency(pitch);
      switch (role) {
        case 'drums': {
          if (pitch === 35 || pitch === 36) {
            const o = osc(frame, 'sine', 150, at);
            o.frequency.exponentialRampToValueAtTime(46, at + .07);
            end = envelope(frame, at, .02, 1.1 * v, .002, .32, .0001, .2);
            const click = noiseSource(frame, at, perNoteFilter(frame, 'highpass', 2600, .7));
            if (click) click.playbackRate.value = 1.2;
          } else if (pitch === 38 || pitch === 40 || pitch === 37) {
            const body = osc(frame, 'triangle', pitch === 37 ? 420 : 190, at);
            body.frequency.exponentialRampToValueAtTime(pitch === 37 ? 380 : 150, at + .06);
            noiseSource(frame, at, perNoteFilter(frame, 'bandpass', 1900, .75));
            end = envelope(frame, at, .01, (pitch === 37 ? .5 : .95) * v, .001, .16, .0001, .1);
          } else if (pitch === 42 || pitch === 44 || pitch === 46) {
            noiseSource(frame, at, perNoteFilter(frame, 'highpass', 7600, .8));
            const decay = pitch === 46 ? .3 : pitch === 44 ? .03 : .05;
            end = envelope(frame, at, .005, .38 * v, .001, decay, .0001, decay);
          } else if (pitch === 51 || pitch === 53) {
            noiseSource(frame, at, perNoteFilter(frame, 'bandpass', 5400, 1.4));
            osc(frame, 'sine', pitch === 53 ? 2500 : 3100, at);
            end = envelope(frame, at, .005, .2 * v, .001, pitch === 53 ? .6 : .42, .0001, .3);
          } else if (tomHz[pitch]) {
            const o = osc(frame, 'sine', tomHz[pitch] * 1.5, at);
            o.frequency.exponentialRampToValueAtTime(tomHz[pitch], at + .09);
            noiseSource(frame, at, perNoteFilter(frame, 'lowpass', 700, .7));
            end = envelope(frame, at, .01, .9 * v, .002, .38, .0001, .25);
          } else {
            // Crash, china, splash.
            const s = noiseSource(frame, at, perNoteFilter(frame, 'highpass', pitch === 52 ? 3200 : 4600, .6));
            if (s) s.playbackRate.value = pitch === 55 ? 1.3 : .9;
            const decay = pitch === 55 ? .55 : pitch === 52 ? .9 : 1.5;
            end = envelope(frame, at, .01, .42 * v, .002, decay, .0001, decay * .6);
          }
          break;
        }
        case 'bass': {
          const input = perNoteFilter(frame, 'lowpass', 260 + v * 900, 2.2);
          osc(frame, 'sawtooth', f, at, input);
          osc(frame, 'sine', f, at, input);
          if (input.frequency) input.frequency.setTargetAtTime(220 + v * 260, at + .01, .08);
          end = envelope(frame, at, dur, .7 * v, .004, .2, .75, .06);
          break;
        }
        case 'guitarL': case 'guitarR': {
          // A power chord from its root (root + fifth, and the octave on the right double); a velocity <= 92 is
          // palm-muted: darker before the amp and quickly damped.
          const palm = vel <= 92, right = role === 'guitarR';
          const input = perNoteFilter(frame, 'lowpass', palm ? 720 : 3000, palm ? 1.4 : .8);
          const cents = right ? 7 : -7;
          osc(frame, 'sawtooth', f, at, input, cents);
          osc(frame, 'sawtooth', f * 1.4983, at, input, -cents);
          if (right) osc(frame, 'square', f * 2, at, input, cents * .5);
          end = palm ? envelope(frame, at, dur, .5 * v, .002, .1, .32, .03)
            : envelope(frame, at, dur, .5 * v, .003, .6, .8, .05);
          break;
        }
        case 'lead': {
          const input = perNoteFilter(frame, 'lowpass', 3400, .9);
          const a = osc(frame, 'sawtooth', f, at, input), b = osc(frame, 'sawtooth', f, at, input, 8);
          if (dur > .45 && a.detune) {
            const lfo = context.createOscillator(), depth = context.createGain();
            lfo.frequency.value = 5.6; depth.gain.setValueAtTime(0, at); depth.gain.linearRampToValueAtTime(14, at + Math.min(.6, dur));
            lfo.connect(depth); depth.connect(a.detune); depth.connect(b.detune);
            frame.sources.push(lfo); frame.nodes.push(depth);
          }
          end = envelope(frame, at, dur, .42 * v, .006, .3, .85, .08);
          break;
        }
        case 'clean': {
          osc(frame, 'triangle', f, at);
          osc(frame, 'sine', f * 2, at, perNoteFilter(frame, 'lowpass', 2400, .7));
          end = envelope(frame, at, dur, .5 * v, .003, 1.4, .25, .3);
          break;
        }
        case 'uke': {
          // A plucked nylon string: triangle and its octave through a soft low-pass, a quick decay. The sampled
          // ukulele's zone replaces this (a gap until the bank has one).
          const input = perNoteFilter(frame, 'lowpass', 2200 + v * 1400, .8);
          osc(frame, 'triangle', f, at, input);
          osc(frame, 'sine', f * 2, at, input, 4);
          end = envelope(frame, at, dur, .5 * v, .002, .55, .12, .22);
          break;
        }
        case 'organ': {
          osc(frame, 'sine', f, at); osc(frame, 'sine', f * 2, at); osc(frame, 'triangle', f * 4, at, perNoteFilter(frame, 'lowpass', 3000, .7));
          end = envelope(frame, at, dur, .26 * v, .02, .2, .9, .25);
          break;
        }
        case 'strings': {
          const input = perNoteFilter(frame, 'lowpass', 2300, .6);
          osc(frame, 'sawtooth', f, at, input, -7); osc(frame, 'sawtooth', f, at, input, 7);
          end = envelope(frame, at, dur, .22 * v, .2, .4, .9, .35);
          break;
        }
        case 'brass': {
          const input = perNoteFilter(frame, 'lowpass', 420, 1.1);
          if (input.frequency) { input.frequency.setValueAtTime(420, at); input.frequency.linearRampToValueAtTime(2600, at + .07); input.frequency.setTargetAtTime(1700, at + .07, .15); }
          osc(frame, 'sawtooth', f, at, input); osc(frame, 'sawtooth', f, at, input, 5);
          end = envelope(frame, at, dur, .3 * v, .035, .3, .8, .14);
          break;
        }
        case 'choir': {
          const input = perNoteFilter(frame, 'bandpass', 880, .9);
          osc(frame, 'sawtooth', f, at, input, -5); osc(frame, 'triangle', f, at, input, 5);
          end = envelope(frame, at, dur, .55 * v, .28, .4, .9, .4);
          break;
        }
        case 'timpani': {
          const o = osc(frame, 'sine', f * 1.03, at);
          o.frequency.exponentialRampToValueAtTime(f, at + .12);
          osc(frame, 'triangle', f * 1.5, at, perNoteFilter(frame, 'lowpass', 600, .7));
          noiseSource(frame, at, perNoteFilter(frame, 'lowpass', 320, .7));
          end = envelope(frame, at, .02, .9 * v, .003, 1.5, .0001, .6);
          break;
        }
        case 'bells': {
          // Inharmonic partials with their own decays (a tubular bell).
          for (const [ratio, level, decay] of [[1, 1, 2.6], [2.76, .5, 1.4], [5.4, .28, .8], [8.93, .14, .4]]) {
            const g = context.createGain();
            g.gain.setValueAtTime(level, at); g.gain.setTargetAtTime(0, at, decay / 3);
            g.connect(frame.env); frame.nodes.push(g);
            osc(frame, 'sine', f * ratio, at, g);
          }
          end = envelope(frame, at, .02, .28 * v, .002, 2.6, .0001, 1.2);
          break;
        }
        default: {
          osc(frame, 'triangle', f, at);
          end = envelope(frame, at, dur, .3 * v, .01, .3, .7, .1);
        }
      }
      for (const s of frame.sources) { s.start(at); try { s.stop(end + .02); } catch { /* already stopped */ } }
      return { ...frame, end };
    }
    // --- score-sampler: zones -----------------------------------------------------------------------------------
    // bank.json (tools/bank/bank_build.lua): instruments in the order they are tried, each with roles and an optional
    // `when` (velMax, durMax in seconds); zones with a sprite, offset and length (s), root and key range (pitched) or
    // keys (drums), a velocity range, a round robin, a loop (s from the zone's start) and a gain. The device's tier:
    // every sprite on desktop, the sprites marked `phone` on phones.
    function prepareBank(spec) {
      const phone = phoneClass(), tierZones = spec.zones.filter(z => !phone || z.phone);
      const instruments = spec.instruments.map(inst => ({ ...inst, byPitch: new Map() }));
      const byId = new Map(instruments.map(inst => [inst.id, inst]));
      for (const z of tierZones) {
        const inst = byId.get(z.inst);
        if (!inst) continue;
        const keys = z.keys || Array.from({ length: z.hi - z.lo + 1 }, (_, i) => z.lo + i);
        for (const k of keys) { if (!inst.byPitch.has(k)) inst.byPitch.set(k, []); inst.byPitch.get(k).push(z); }
      }
      const sprites = spec.sprites.filter(s => !phone || s.phone);
      const budget = phone ? spec.budgets?.decodedPhone ?? 16e6 : spec.budgets?.decodedDesktop ?? 41e6;
      Object.assign(bankState, { present: true, tier: phone ? 'phone' : 'desktop', sprites: sprites.length, budget, zones: tierZones.length });
      return { spec, roles: spec.roles || {}, instruments, sprites, buffers: new Map(), rr: new Map(), coverage: new Map() };
    }
    // The instrument that plays a note (plan only: decode state does not matter): the first whose role, `when` and
    // zones (every chord tone of guitar parts) fit.
    function instrumentFor(role, pitch, vel, seconds) {
      const tones = role === 'drums' ? [0] : bank.roles[role]?.chord || [0];
      for (const inst of bank.instruments) {
        if (!inst.roles.includes(role)) continue;
        const w = inst.when;
        if (w && ((w.velMax != null && vel > w.velMax) || (w.durMax != null && seconds > w.durMax))) continue;
        if (tones.every(t => inst.byPitch.has(pitch + t))) return inst;
      }
      return null;
    }
    // Whether a section's track plays from the bank: only if the bank covers all its notes (one timbre per part).
    function trackSampled(seg, name, role, notes, bs) {
      const key = `${seg.song}/${seg.section}/${name}`;
      let ok = bank.coverage.get(key);
      if (ok === undefined) {
        ok = !!bank.roles[role] && notes.every(n => instrumentFor(role, n.pitch, n.vel, n.len * bs));
        bank.coverage.set(key, ok);
      }
      return ok;
    }
    // A decoded zone of `inst` for pitch and velocity: the velocity layer that contains it (else the nearest one
    // decoded), cycling its round robins.
    function zoneFor(inst, pitch, vel) {
      const list = inst.byPitch.get(pitch);
      if (!list) return null;
      let best = null, bestDistance = Infinity;
      for (const z of list) {
        if (!bank.buffers.has(z.sprite)) continue;
        const distance = vel < z.vlo ? z.vlo - vel : vel > z.vhi ? vel - z.vhi : 0;
        if (distance < bestDistance) { best = z; bestDistance = distance; }
      }
      if (!best) return null;
      const layer = list.filter(z => bank.buffers.has(z.sprite) && z.vlo === best.vlo && z.vhi === best.vhi && (z.root ?? z.keys?.[0]) === (best.root ?? best.keys?.[0]));
      if (layer.length < 2) return best;
      const key = `${inst.id}:${best.root ?? best.keys[0]}:${best.vlo}`, n = bank.rr.get(key) || 0;
      bank.rr.set(key, n + 1);
      return layer[n % layer.length];
    }
    // A sampled voice, or null (no instrument, or a tone's zone not decoded yet: the synth plays the note).
    function sampleVoice(role, pitch, vel, at, dur, dest) {
      const inst = instrumentFor(role, pitch, vel, dur);
      if (!inst) return null;
      const spec = bank.roles[role] || {}, tones = role === 'drums' ? [0] : spec.chord || [0];
      const zones = [];
      for (const t of tones) {
        const z = zoneFor(inst, pitch + t, vel);
        if (!z) { bankState.synth++; return null; }
        zones.push(z);
      }
      bankState.sampled++;
      const v = vel / 127, frame = voiceFrame(dest.sampled || dest, at);
      // Palm-muted guitar (velocity <= 92) keeps the synth's darker pre-amp colour; the staccato zones damp it.
      const input = (role === 'guitarL' || role === 'guitarR') && vel <= 92 ? perNoteFilter(frame, 'lowpass', 1800, .9) : frame.env;
      let stopAt = Infinity, looped = false;
      zones.forEach((z, i) => {
        const buffer = bank.buffers.get(z.sprite), src = context.createBufferSource();
        const cents = (spec.cents || 0) * (i % 2 ? -1 : 1);
        const rate = z.keys ? 1 : 2 ** ((pitch + tones[i] - z.root) / 12 + cents / 1200);
        src.buffer = buffer;
        src.playbackRate.value = rate;
        src.connect(input);
        frame.sources.push(src);
        src.zone = z;
        if (z.loop && z.art === 'sus') {
          src.loop = true; src.loopStart = z.offset + z.loop[0]; src.loopEnd = z.offset + z.loop[1]; looped = true;
        } else stopAt = Math.min(stopAt, at + z.length / rate);
      });
      const level = (spec.level ?? .5) * 10 ** ((zones[0].gainDb || 0) / 20) * (.35 + .65 * v);
      const g = frame.env.gain;
      g.setValueAtTime(level, at);
      let end;
      if (inst.art === 'hit') end = stopAt;
      else {
        const release = zones[0].release ?? .06, off = at + Math.max(.005, dur);
        g.setTargetAtTime(0, off, release / 3);
        end = Math.min(off + release * 2, looped ? Infinity : stopAt);
      }
      for (const s of frame.sources) {
        const z = s.zone;
        s.start(at, z.offset, s.loop ? undefined : z.length);
        try { s.stop(end + .005); } catch { /* already stopped */ }
      }
      return { ...frame, end, sampled: true };
    }
    // Progressive loading: one sprite at a time in bank.json's order (fetch, decode), within the tier's decoded budget.
    async function loadBank() {
      const spec = await bankSpec();
      if (!spec || !context || failed) return;
      if (typeof context.decodeAudioData !== 'function') { bankState.error = 'no decodeAudioData'; return; }
      try { bank = prepareBank(spec); } catch (error) { bankState.error = String(error?.message || error); bank = null; return; }
      for (const sprite of bank.sprites) {
        if (bankState.decodedBytes + sprite.decodedBytes > bankState.budget) { bankState.skipped++; continue; }
        try {
          const res = await fetch(new URL(sprite.file, bankRoot));
          if (!res.ok) throw new Error(`${sprite.file} unavailable`);
          const bytes = await res.arrayBuffer();
          // Safari before 18.4 cannot decode Opus: the sprite fails and its notes stay synthesized (design §11.8).
          const buffer = await new Promise((resolve, reject) => {
            const p = context.decodeAudioData(bytes, resolve, reject);
            if (p && typeof p.then === 'function') p.then(resolve, reject);
          });
          bank.buffers.set(sprite.file, buffer);
          bankState.loaded++;
          bankState.decodedBytes += buffer.length * buffer.numberOfChannels * 4;
          bankState.ready = bank.spec.zones.filter(z => bank.buffers.has(z.sprite)).length;
        } catch (error) { bankState.failedSprites++; bankState.error = String(error?.message || error); }
      }
    }
    const priority = role => (role === 'organ' || role === 'strings' || role === 'brass' || role === 'choir') ? 0
      : (role === 'lead' || role === 'clean' || role === 'bells' || role === 'uke') ? 1 : role === 'bass' ? 3 : 2;
    const mono = role => role === 'lead' || role === 'bass';
    function releaseVoice(entry, at, seconds = .03) {
      if (entry.released) return;
      entry.released = true;
      if (entry.at >= at - 1e-4) {
        // Not started yet: it never plays.
        for (const s of entry.sources) { try { s.stop(at); } catch { /* stopped */ } }
        return;
      }
      const g = entry.env.gain;
      g.cancelScheduledValues?.(at);
      g.setTargetAtTime(0, at, seconds / 3);
      for (const s of entry.sources) { try { s.stop(at + seconds * 1.5 + .01); } catch { /* stopped */ } }
      entry.end = Math.min(entry.end, at + seconds * 1.5);
    }
    function play(trackName, role, pitch, vel, at, dur, dest, seg, sample = true) {
      const now = context.currentTime;
      if (at < now - .01) return null;
      const isKickSnare = role === 'drums' && (pitch === 35 || pitch === 36 || pitch === 38 || pitch === 40);
      // Choke and mono rules, then the cap.
      let sounding = 0, victim = null;
      for (const v of voices) {
        if (v.end <= now) { voices.delete(v); continue; }
        if (!v.released && v.track === trackName && v.dest === dest && (v.pitch === pitch || mono(role)) && v.at < at + 1e-6) releaseVoice(v, at, .008);
        if (!v.released && v.end > at) {
          sounding++;
          if (v.priority < 3 && !v.kickSnare && (!victim || v.priority < victim.priority || (v.priority === victim.priority && v.at < victim.at))) victim = v;
        }
      }
      if (sounding >= cap && victim) { releaseVoice(victim, at, .02); stolen++; }
      const voice = makeVoice(role, pitch, vel, at, dur, dest, sample);
      const entry = { ...voice, track: trackName, pitch, at, priority: isKickSnare ? 3 : priority(role), kickSnare: isKickSnare, dest, seg };
      voices.add(entry);
      const last = voice.sources[voice.sources.length - 1];
      if (last) last.onended = () => { voices.delete(entry); for (const n of [...entry.sources, ...entry.nodes]) { try { n.disconnect(); } catch { /* detached */ } } };
      return entry;
    }

    // --- scheduling ---------------------------------------------------------------------------------------------
    // Schedules the notes of `seg` that start in [a, b).
    function scheduleNotes(seg, a, b) {
      const len = seg.spec.bars * 4, hold = (seg.spec.hold || 0) * 4, bs = beatSeconds(seg.song);
      let g0 = segBeat(seg, a);
      const g1 = segBeat(seg, b);
      let guard = 0;
      while (g0 < g1 - 1e-9 && guard++ < 64) {
        let local, span;
        if (seg.spec.kind === 'loop') { local = ((g0 % len) + len) % len; span = len - local; }
        else if (g0 < len) { local = g0; span = len - g0; }
        else if (hold > 0) { local = len + (g0 - len) % hold; span = len + hold - local; }
        else return;
        const take = Math.min(span, g1 - g0);
        const origin = segTime(seg, g0) - local * bs;   // time of local beat 0 in this piece
        for (const [name, notes] of Object.entries(seg.data.score.tracks)) {
          if (!audible.has(name)) continue;
          const role = manifest.tracks[name]?.role || 'lead';
          const dest = trackGain(name);
          const sample = bankOn && !!bank && trackSampled(seg, name, role, notes, bs);
          for (let i = lowerBound(notes, local); i < notes.length && notes[i].beat < local + take - 1e-9; i++) {
            const n = notes[i];
            if (breaks.length && resting(origin + n.beat * bs)) continue;
            play(name, role, n.pitch, n.vel, origin + n.beat * bs, n.len * bs, dest, seg.id, sample);
          }
        }
        g0 += take;
      }
    }
    function enter(move, at) {
      const song = songs.get(move.song);
      const data = song?.sections.get(move.section);
      if (!data) {
        // Its song is still loading: the section being left holds, and the move runs once the song has loaded.
        if (current) current.stalled = true;
        wanted = { ...move, at: -1 };
        return;
      }
      const old = current;
      if (old) for (const v of voices) if (v.seg === old.id && v.end > at) releaseVoice(v, at, .03);
      let entry = 0;
      if (move.enter === 'same' && old) {
        const g = Math.round(segBeat(old, at)), oldLen = old.spec.bars * 4, len = data.spec.bars * 4;
        const local = old.spec.kind === 'loop' ? ((g % oldLen) + oldLen) % oldLen : g;
        entry = ((local % len) + len) % len;
      }
      current = { id: ++segment, song: move.song, section: move.section, startAt: at, entry, spec: data.spec, data, songSpec: song.spec,
        then: move.then || null };
      applyMask(at);
      applyTrim(at);
      worldize(at, data.spec.fx === 'worldized');
      moveLog.push({ song: move.song, section: move.section, at, entry, requestedAt: move.requestedAt, reason: move.reason || null });
      if (moveLog.length > 16) moveLog.shift();
    }
    function tick(until) {
      if (!context) return;
      const now = context.currentTime;
      if (scheduledUntil < now) scheduledUntil = now;  // fell behind (a long frame): never schedule into the past
      let guard = 0;
      while (scheduledUntil < until - 1e-9 && guard++ < 64) {
        let end = until;
        const edge = boundary(current);
        if (pending && pending.at < end) end = Math.max(scheduledUntil, pending.at);
        if (edge < end) end = Math.max(scheduledUntil, edge);
        if (maskEvents.length && maskEvents[0].at < end) end = Math.max(scheduledUntil, maskEvents[0].at);
        if (current && end > scheduledUntil) scheduleNotes(current, scheduledUntil, end);
        scheduledUntil = end;
        // What happens at `end`, in order: mask changes, then a pending move (it wins over an auto-advance).
        while (maskEvents.length && maskEvents[0].at <= end + 1e-9) {
          const e = maskEvents.shift();
          for (const key of ['tier', 'variant', 'fleet', 'power']) if (e[key] !== undefined) mask[key] = e[key];
          applyMask(e.at);
          applyTrim(e.at);
        }
        if (pending && pending.at <= end + 1e-9) {
          const move = pending; pending = null;
          enter(move, move.at);
        }
        else if (current && boundary(current) <= end + 1e-9) enter({ ...successor(current), enter: 'start', reason: 'end' }, boundary(current));
      }
    }
    // A requested time at or after what is already scheduled (else the next line after it).
    function settle(at, quantum) {
      const floor = Math.max(scheduledUntil, context.currentTime + MARGIN);
      if (at >= floor - 1e-9) return at;
      slipped++;
      const beats = quantum === 'beat' ? 1 : quantum === 'now' ? 0 : 4;
      return current && beats ? nextLine(current, floor, beats) : floor;
    }
    function resolve(move) {
      const now = context.currentTime, floor = Math.max(scheduledUntil, now + MARGIN);
      if (move.quantum === 'now') return now + MARGIN;
      if (typeof move.at === 'number' && move.at >= 0) return settle(move.at, move.quantum);
      if (current) return nextLine(current, floor, move.quantum === 'beat' ? 1 : 4);
      return floor;
    }
    // A move from SongDirector: { song, section?, at, quantum, enter, tier?, variant?, fleet?, then?, reason }.
    // Returns the time it lands on, -1 while the score, the move's song or the audio context is not ready (it runs
    // once they are), or -2 when the score failed to load (the game is silent then).
    function move(m) {
      if (failed) return -2;
      if (!ready() || (m.section && !loaded(m.song))) { wanted = m.section ? m : (wanted ? { ...wanted, ...maskOf(m) } : null); return -1; }
      const startsScore = !current && !pending && m.section;
      if (!m.section && !current && !pending) return -1;
      const at = resolve(m);
      // A `now` move cancels what was scheduled past it (enter() releases those notes before they start).
      if (m.quantum === 'now' && at < scheduledUntil) scheduledUntil = Math.max(context.currentTime, at);
      const mk = maskOf(m);
      if (Object.keys(mk).length) {
        maskEvents = maskEvents.filter(e => e.at < at - 1e-9);   // the latest request wins
        maskEvents.push({ at, ...mk });
      }
      if (m.section) pending = { ...m, at, requestedAt: context.currentTime };
      if (startsScore) scheduledUntil = Math.max(scheduledUntil, context.currentTime);
      return at;
    }
    function maskOf(m) {
      const out = {};
      if (m.tier !== undefined && m.tier !== null) out.tier = Math.min(4, Math.max(1, Math.round(m.tier)));
      if (m.variant) out.variant = m.variant;
      if (m.fleet !== undefined && m.fleet !== null) out.fleet = !!m.fleet;
      return out;
    }
    function flushWanted() {
      if (!wanted || failed || !ready()) return;
      if (wanted.section && !loaded(wanted.song)) return;
      const w = wanted; wanted = null;
      move({ ...w, at: -1 });
    }
    // The worldized chain: the band-pass closes in over a beat or so while a worldized section plays, and opens
    // again when the next one starts.
    function worldize(at, on) {
      if (!fx || fx.on === on) return;
      fx.on = on;
      const glide = on ? .6 : .08;
      fx.low.frequency.cancelScheduledValues?.(at); fx.high.frequency.cancelScheduledValues?.(at);
      fx.low.frequency.setTargetAtTime(on ? 300 : 20, at, glide / 3);
      fx.high.frequency.setTargetAtTime(on ? 4000 : 20000, at, glide / 3);
      fx.stereo.gain.setTargetAtTime(on ? 0 : 1, at, glide / 3);
      fx.mono.gain.setTargetAtTime(on ? 1 : 0, at, glide / 3);
    }
    // --- bonus-music: a stinger's `break` [from, to] (beats from its anchor) is a stop-time. The playing section's
    // notes that would sound in it are released at `from` (60 ms) or never start, and none is scheduled inside it;
    // the section's grid runs on, so the band comes back on the line at `to`.
    function resting(t) { return breaks.some(b => t >= b.from - 1e-6 && t < b.to - 1e-6); }
    function rest(from, to) {
      const now = context.currentTime;
      breaks = breaks.filter(b => b.to > now);
      breaks.push({ from, to });
      for (const v of voices) if (current && v.seg === current.id && !v.released && v.end > from) releaseVoice(v, Math.max(from, v.at), .06);
    }
    // Stingers: the accent's score in the playing section's key, on its grid. An unknown name plays nothing (null).
    function accent(name) {
      if (!ready() || !current) return null;
      const stingName = manifest.accents[name];
      const sting = stingName && manifest.stingers[stingName];
      if (!sting) return null;
      const now = context.currentTime, bs = beatSeconds(current.song);
      const last = lastSting.get(stingName) ?? -Infinity;
      if (now - last < (sting.spacing || 1) * bs) return null;
      const lifeLoss = host.lifeLoss?.includes(name);
      const live = stingLog.filter(s => s.end > now).length;
      if (live >= 2 && !lifeLoss && !sting.always) return null;
      const lead = Math.min(0, ...sting.notes.map(n => n.t));
      const earliest = now + MARGIN - lead * bs;
      const g = segBeat(current, earliest);
      const anchor = segTime(current, Math.ceil(g / sting.quantum - 1e-9) * sting.quantum);
      const tonic = current.spec.tonic ?? current.songSpec.tonic, mode = current.spec.mode ?? current.songSpec.mode;
      const scale = scales[mode] || scales.minor;
      let end = anchor;
      if (sting.break) rest(anchor + sting.break[0] * bs, anchor + sting.break[1] * bs);
      for (const n of sting.notes) {
        const role = manifest.tracks[n.track]?.role || 'lead';
        let pitch = n.drum;
        if (pitch === undefined) {
          const step = n.deg !== undefined ? scale[(n.deg - 1) % 7] + 12 * Math.floor((n.deg - 1) / 7) : n.semi || 0;
          pitch = 12 * ((n.oct ?? 4) + 1) + tonic + step;
        }
        const at = anchor + n.t * bs;
        play(`sting:${n.track}`, role, pitch, n.v, at, n.len * bs, stingInput(role), 0, true);
        end = Math.max(end, at + n.len * bs);
      }
      lastSting.set(stingName, now);
      stingLog.push({ name, sting: stingName, at: anchor, end, requestedAt: now });
      if (stingLog.length > 16) stingLog.shift();
      return anchor;
    }
    const stingInputs = new Map();
    function stingInput(role) {
      let g = stingInputs.get(role);
      if (!g) { g = gainNode(.9); g.connect(bus(role)); g.sampled = sampledInput(role, .9); stingInputs.set(role, g); }
      return g;
    }
    function attach(ctx) {
      if (context) return;
      context = ctx;
      buildBuses();
      scheduledUntil = context.currentTime;
      flushWanted();
      // The bank after the score: the music never waits for it.
      if (bankOn) startBank();
    }
    function startBank() {
      if (!bankLoading && context) bankLoading = loading.then(loadBank).catch(error => { bankState.error = String(error?.message || error); });
    }
    // --- sample-bank: the /console switch. Stores the choice on this device and applies from the next scheduled
    // notes (a part already sounding keeps its voices). Switching off keeps the decoded sprites until the page
    // reloads, so an A/B is instant; a page that never switches on never fetches the bank.
    function setBank(on) {
      bankOn = !!on;
      try { storage()?.setItem(BANK_KEY, bankOn ? 'on' : 'off'); } catch { /* private mode */ }
      pickTrims();
      if (bankOn) { bankSpec(); startBank(); }
      applyTrim(Math.max(scheduledUntil, context?.currentTime ?? 0));
      return bankOn;
    }
    // The power-up layer (ride and double kick) follows the active powers on the next bar line.
    function power(active) {
      if (!ready() || !current) { mask.power = active; return; }
      const level = Math.max(0, Math.round(active) || 0);
      if (level === mask.power && !maskEvents.some(e => e.power !== undefined)) return;
      const at = nextLine(current, Math.max(scheduledUntil, context.currentTime + MARGIN), 4);
      maskEvents = maskEvents.filter(e => !(e.power !== undefined && e.at >= at));
      maskEvents.push({ at, power: level });
      maskEvents.sort((x, y) => x.at - y.at);
    }
    function nextBar(after) { return current && context ? nextLine(current, Math.max(after, scheduledUntil), 4) : after; }
    return {
      attach, tick, move, accent, power, nextBar, loading, parseScore, setBank,
      get bankOn() { return bankOn; },
      // Resolves once the bank's sprites for this device have loaded (or immediately when there is no bank or it is off).
      get bankLoading() { return bankLoading || (bankOn ? bankSpec().then(() => undefined) : Promise.resolve()); },
      get playing() { return !!(pending || current || wanted); },
      get time() { return context?.currentTime ?? -1; },
      // The playing section and the time of its beat 0 (its bar lines are start + k bars): SongDirector's sync.
      get position() { return current ? { song: current.song, section: current.section, start: segTime(current, 0), startAt: current.startAt, entry: current.entry } : null; },
      get state() {
        const now = context?.currentTime ?? 0;
        return { loaded: !!manifest, songs: [...songs.keys()], failed, loadError, song: current?.song ?? null, section: current?.section ?? null,
          then: current?.then ?? null, worldized: !!fx?.on, trimDb, trims: !!trims,
          startAt: current?.startAt ?? null, entry: current?.entry ?? null, beat: current ? segBeat(current, now) : null,
          pending: pending ? { song: pending.song, section: pending.section, at: pending.at, then: pending.then ?? null } : null,
          wanted: wanted ? { song: wanted.song, section: wanted.section } : null,
          mask: { ...mask }, audible: [...audible].sort(), queuedMasks: maskEvents.map(e => ({ ...e })),
          // Sounding now (scheduled voices that have not started yet are not counted).
          voices: [...voices].filter(v => !v.released && v.at <= now && v.end > now).length,
          scheduled: [...voices].filter(v => !v.released && v.end > now).length, cap, stolen, slipped, scheduledUntil,
          moves: moveLog.slice(), stingers: stingLog.slice(),
          // The sample bank (design §12.9): absent, loading or loaded; notes sampled and notes the synth played while
          // their zone was not decoded yet.
          bankLoaded: bankState.present && bankState.loaded + bankState.skipped + bankState.failedSprites >= bankState.sprites && bankState.loaded > 0,
          bankDecodedBytes: bankState.decodedBytes, bankOn, bank: { ...bankState, enabled: bankOn } };
      },
    };
  }
  window.demonScore = Object.freeze({ create, parseScore, LOOKAHEAD });
})();
