/* The MIDI-first score player (adaptive-soundtrack design §5.1, §11.4): one committed multitrack score per
   section (web/audio/score/, written by tools/score/score_gen.lua), played on the song's bar grid by synth voices,
   moved between sections by SongDirector (lib/game/song_director.dart) through demonAudio.song(move).

   It runs inside demon-audio.js's scheduler (one audio clock, one 25 ms timer): tick(until) schedules every note up
   to `until` (a lookahead of LOOKAHEAD seconds) with start(when) on the audio clock, so the main thread only does a
   few node creations per tick and timing never depends on frame rate.

   The combining rules, all on the audio clock:
   - Section moves land on the requested time, which SongDirector puts on a bar or beat line of the playing section
     (or, from recorded music, on that cue's bar line). A move that would fall inside the already-scheduled window
     slips to the next line instead (state.slipped counts these). The latest pending move replaces an earlier one.
   - `enter: same` keeps the bar position (modulo the destination's length); `start` begins at its first bar.
   - Tails and bridges hand over to `next` at their own end; a tail without one repeats its hold bars.
   - Intensity is a track mask (song-map tier masks plus the v2, power and fleet layers) applied on the requested
     line: newly audible tracks fade in over 20 ms, silenced ones out over 60 ms, notes of silent tracks are not
     scheduled. Nothing restarts.
   - Held notes of the section being left are released over 30 ms at the move.
   - Stingers are short scores in scale degrees, transposed to the playing section's key and put on its grid.
   - Voices: a key struck again on its track chokes its previous note; lead and bass are monophonic; at most 48
     voices (32 on phones), stealing pads first, then leads, never kick, snare or bass.

   Voices are synthesis (the guaranteed-everywhere layer, §11.8 step 2). makeVoice() is the seam for the CC0 sample
   bank (§11.4 "Loading"): a bank adds a zone lookup there and plays an AudioBufferSourceNode through the same role
   buses; the score, the graph player and the buses stay as they are. */
(() => {
  'use strict';
  const LOOKAHEAD = .25;          // seconds of score scheduled ahead of the audio clock
  const MARGIN = .03;             // a requested time closer than this to now is re-quantised
  const root = new URL('./audio/score/', document.baseURI);

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
    // host: { context(), input(), legacyBar(), yieldLegacy(at), lifeLoss: [names] }
    let manifest = null, failed = false, context = null, out = null, wanted = null, loadError = null;
    let enabled = readEnabled();
    const songs = new Map();       // id -> { spec, sections: Map(id -> { spec, score }) }
    let current = null;            // { id, song, section, startAt, entry, spec, data, songSpec }
    let pending = null;            // a section move { at, song, section, enter, reason }
    let maskEvents = [];           // [{ at, tier?, variant?, fleet?, power? }] in time order
    const mask = { tier: 1, variant: 'v1', fleet: false, power: 0 };
    let audible = new Set();
    let scheduledUntil = 0, segment = 0, slipped = 0, stolen = 0;
    const voices = new Set(), moveLog = [], stingLog = [], lastSting = new Map();
    const trackGains = new Map(), buses = {};
    const cap = phoneClass() ? 32 : 48;

    function readEnabled() {
      try { if (/[?&]score=off\b/.test(location.search)) return false; } catch { /* no location */ }
      try { return window.localStorage?.getItem('demonAttack.score') !== 'off'; } catch { return true; }
    }
    function phoneClass() {
      try { if ((navigator.deviceMemory ?? 8) <= 4) return true; } catch { /* no navigator */ }
      try { return !!window.matchMedia?.('(pointer: coarse)').matches; } catch { return false; }
    }

    // --- loading: the whole score is ~60 KB; it is fetched and parsed once, before the first gesture.
    const loading = (async () => {
      try {
        const response = await fetch(new URL('score.json', root));
        if (!response.ok) throw new Error('score unavailable');
        const map = await response.json();
        for (const [id, spec] of Object.entries(map.songs)) {
          const sections = new Map();
          for (const [sid, sspec] of Object.entries(spec.sections)) {
            const res = await fetch(new URL(sspec.file, root));
            if (!res.ok) throw new Error(`score section ${sspec.file} unavailable`);
            sections.set(sid, { spec: sspec, score: parseScore(await res.arrayBuffer()) });
          }
          songs.set(id, { spec, sections });
        }
        manifest = map;   // ready only once every section is parsed
      } catch (error) { failed = true; manifest = null; loadError = String(error?.message || error); }
      flushWanted();
    })();
    const ready = () => !!manifest && !failed && !!context;

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
      if (!seg || seg.spec.kind === 'loop' || !seg.spec.next) return Infinity;
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
        gain.gain.cancelScheduledValues?.(at);
        gain.gain.setValueAtTime(on ? 0 : 1, at);
        gain.gain.linearRampToValueAtTime(on ? 1 : 0, at + (on ? .02 : .06));
      }
      audible = next;
    }
    function trackGain(name) {
      let gain = trackGains.get(name);
      if (!gain) {
        gain = context.createGain();
        gain.gain.value = 1;
        gain.connect(bus(manifest.tracks[name]?.role || 'lead'));
        trackGains.set(name, gain);
      }
      return gain;
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
      out = gainNode(.55);
      out.connect(host.input());
      const wet = gainNode(.32), room = reverb(phoneClass() ? 1.1 : 1.7);
      if (room) chain(room, wet, out);
      const send = (from, amount) => { if (room) { const g = gainNode(amount); from.connect(g); g.connect(room); } };
      const pan = value => { const p = node('createStereoPanner'); if (p) p.pan.value = value; return p; };
      // Drums: dry, with a little room.
      buses.drums = gainNode(.9); buses.drums.connect(out); send(buses.drums, .1);
      // Bass: light drive, then a low-pass blend.
      buses.bass = gainNode(.8);
      chain(buses.bass, shaper(1.6, .08), filter('lowpass', 2800, .8), gainNode(.9), out);
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
      organ: 'pad', strings: 'pad', brass: 'pad', choir: 'pad', timpani: 'perc', bells: 'perc' };
    function bus(role) { return buses[roleBus[role] || 'pad']; }

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
    // The seam for the sample bank: role, pitch, velocity -> a voice into `dest`. Synthesis today.
    function makeVoice(role, pitch, vel, at, dur, dest) {
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
    const priority = role => (role === 'organ' || role === 'strings' || role === 'brass' || role === 'choir') ? 0
      : (role === 'lead' || role === 'clean' || role === 'bells') ? 1 : role === 'bass' ? 3 : 2;
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
    function play(trackName, role, pitch, vel, at, dur, dest, seg) {
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
      const voice = makeVoice(role, pitch, vel, at, dur, dest);
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
          for (let i = lowerBound(notes, local); i < notes.length && notes[i].beat < local + take - 1e-9; i++) {
            const n = notes[i];
            play(name, role, n.pitch, n.vel, origin + n.beat * bs, n.len * bs, dest, seg.id);
          }
        }
        g0 += take;
      }
    }
    function enter(move, at) {
      const song = songs.get(move.song);
      const data = song?.sections.get(move.section);
      if (!data) return;
      const old = current;
      if (old) for (const v of voices) if (v.seg === old.id && v.end > at) releaseVoice(v, at, .03);
      let entry = 0;
      if (move.enter === 'same' && old) {
        const g = Math.round(segBeat(old, at)), oldLen = old.spec.bars * 4, len = data.spec.bars * 4;
        const local = old.spec.kind === 'loop' ? ((g % oldLen) + oldLen) % oldLen : g;
        entry = ((local % len) + len) % len;
      }
      current = { id: ++segment, song: move.song, section: move.section, startAt: at, entry, spec: data.spec, data, songSpec: song.spec };
      applyMask(at);
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
        }
        if (pending && pending.at <= end + 1e-9) {
          const move = pending; pending = null;
          if (move.stop) halt(move.at, move.seconds); else enter(move, move.at);
        }
        else if (current && boundary(current) <= end + 1e-9) enter({ song: current.song, section: current.spec.next, enter: 'start', reason: 'end' }, boundary(current));
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
      if (typeof move.at === 'number' && move.at >= 0) return settle(move.at, move.quantum);
      if (move.quantum === 'now') return floor;
      if (current) return nextLine(current, floor, move.quantum === 'beat' ? 1 : 4);
      const legacy = host.legacyBar?.(floor);
      return typeof legacy === 'number' && legacy >= floor ? legacy : floor;
    }
    // A move from SongDirector: { song, section?, at, quantum, enter, tier?, variant?, fleet?, reason, fallback? }.
    // Returns the time it lands on, -1 while the score or the audio context is not ready (it runs once both are),
    // or -2 when the score is off or failed (the fallback cue has been played instead).
    function move(m) {
      if (!enabled || failed) { if (m.fallback) host.fallback?.(m.fallback); return -2; }
      if (!ready()) { wanted = m.section ? m : (wanted ? { ...wanted, ...maskOf(m) } : null); return -1; }
      const startsScore = !current && !pending && m.section;
      if (!m.section && !current && !pending) return -1;
      const at = resolve(m);
      const mk = maskOf(m);
      if (Object.keys(mk).length) {
        maskEvents = maskEvents.filter(e => e.at < at - 1e-9);   // the latest request wins
        maskEvents.push({ at, ...mk });
      }
      if (m.section) pending = { ...m, at, requestedAt: context.currentTime };
      if (startsScore) { host.yieldLegacy?.(at); scheduledUntil = Math.max(scheduledUntil, context.currentTime); }
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
      if (!wanted) return;
      if (failed || !enabled) { const w = wanted; wanted = null; if (w.fallback) host.fallback?.(w.fallback); return; }
      if (!ready()) return;
      const w = wanted; wanted = null;
      move({ ...w, at: -1 });
    }
    // The recorded music takes over at `at`: until then the score keeps playing; there it releases everything
    // sounding (notes already scheduled past `at` never start) and forgets its moves.
    function halt(at, seconds) {
      for (const v of voices) releaseVoice(v, at, seconds);
      current = null; pending = null; maskEvents = [];
      moveLog.push({ song: null, section: null, at, reason: 'recorded' });
      if (moveLog.length > 16) moveLog.shift();
    }
    function stop(at, seconds = .09) {
      wanted = null;
      if (!context) return;
      if (!current || at <= scheduledUntil + 1e-9) halt(at, seconds);
      else pending = { stop: true, at, seconds };
    }
    // Stingers: the accent's score in the playing section's key, on its grid.
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
      if (live >= 2 && !lifeLoss) return null;
      const lead = Math.min(0, ...sting.notes.map(n => n.t));
      const earliest = now + MARGIN - lead * bs;
      const g = segBeat(current, earliest);
      const anchor = segTime(current, Math.ceil(g / sting.quantum - 1e-9) * sting.quantum);
      const tonic = current.spec.tonic ?? current.songSpec.tonic, mode = current.spec.mode ?? current.songSpec.mode;
      const scale = scales[mode] || scales.minor;
      let end = anchor;
      for (const n of sting.notes) {
        const role = manifest.tracks[n.track]?.role || 'lead';
        let pitch = n.drum;
        if (pitch === undefined) {
          const step = n.deg !== undefined ? scale[(n.deg - 1) % 7] + 12 * Math.floor((n.deg - 1) / 7) : n.semi || 0;
          pitch = 12 * ((n.oct ?? 4) + 1) + tonic + step;
        }
        const at = anchor + n.t * bs;
        play(`sting:${n.track}`, role, pitch, n.v, at, n.len * bs, stingInput(role), 0);
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
      if (!g) { g = gainNode(.9); g.connect(bus(role)); stingInputs.set(role, g); }
      return g;
    }
    function attach(ctx) {
      if (context) return;
      context = ctx;
      buildBuses();
      scheduledUntil = context.currentTime;
      flushWanted();
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
    function setEnabled(value) {
      enabled = !!value;
      try { window.localStorage?.setItem('demonAttack.score', enabled ? 'on' : 'off'); } catch { /* storage denied */ }
      return enabled;
    }
    return {
      attach, tick, move, stop, accent, power, nextBar, setEnabled, loading, parseScore,
      get playing() { return !!(pending ? !pending.stop : current || wanted); },
      get enabled() { return enabled; },
      get time() { return context?.currentTime ?? -1; },
      // The playing section and the time of its beat 0 (its bar lines are start + k bars): SongDirector's sync.
      get position() { return current ? { song: current.song, section: current.section, start: segTime(current, 0), startAt: current.startAt, entry: current.entry } : null; },
      get state() {
        const now = context?.currentTime ?? 0;
        return { enabled, loaded: !!manifest, failed, loadError, song: current?.song ?? null, section: current?.section ?? null,
          startAt: current?.startAt ?? null, entry: current?.entry ?? null, beat: current ? segBeat(current, now) : null,
          pending: pending ? { song: pending.song, section: pending.section, at: pending.at } : null,
          wanted: wanted ? { song: wanted.song, section: wanted.section } : null,
          mask: { ...mask }, audible: [...audible].sort(), queuedMasks: maskEvents.map(e => ({ ...e })),
          voices: [...voices].filter(v => !v.released && v.end > now).length, cap, stolen, slipped, scheduledUntil,
          moves: moveLog.slice(), stingers: stingLog.slice() };
      },
    };
  }
  window.demonScore = Object.freeze({ create, parseScore, LOOKAHEAD });
})();
