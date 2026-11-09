/* Original game music: recorded ACE-Step loops (web/audio/music/, built by
   tools/music_pipeline.py from the per-level motifs in tools/music_motifs.py)
   on a shared 120 BPM audio-clock grid, with the original MIDI scores and a
   Web Audio synthesizer as fallback and for effects.

   Every level has an intro, four intensity tiers of one motif (same riff and
   bar structure, so a tier change keeps the loop position), an outro for the
   travel that follows it, and an accent sprite (dive, last stand, hatch,
   reinforcements). The game drives the tier with intensity(tier) and the
   stingers with accent(name); both are read-only with respect to the game.
   API calls are safe before the first user gesture and when audio is unavailable. */
(() => {
  'use strict';
  const midiRoot = new URL('./audio/midi/', document.baseURI);
  const musicRoot = new URL('./audio/music/', document.baseURI);
  const midiCache = new Map(), bytesCache = new Map(), bufferCache = new Map(), ready = new Map();  // ready: decoded buffers, synchronously
  let context, master, music, effects, timer, pending, active, wanted, nextBeat = 0, beat = 0;
  let muted = false, paused = false, requested = 0;
  // The level whose music plays: its intro, then its tiers.
  const scene = { level: 0, tier: 1, section: null, phaseTier: 0 };
  const voices = new Set(), accentsLive = [], accentLog = [], lastAccent = new Map();
  const beatSeconds = .5;
  const fileGain = .7;          // recorded cues are mastered to -18..-19 LUFS
  const bufferLimit = 12;       // decoded cues kept (a level is ~8: intro, 4 tiers, outro, accents, clear)
  const masterGain = .65, effectsGain = .9;  // effects sit above the denser rock/metal mixes
  // Cue table (mirrors web/audio/music/manifest.json; checked by test-worker).
  const accentSlots = ['dive', 'laststand', 'hatch', 'reinforce', 'breakthrough'];
  const accentQuantum = { dive: .25, reinforce: .25, laststand: .5, hatch: .5, breakthrough: .5 };  // seconds: half-beat / beat
  const slotSeconds = 1.5;
  function cueInfo(name) {
    if (/^l[1-5]-t[1-4]$/.test(name)) return { kind: 'loop', beats: 32, level: +name[1], tier: +name[4] };
    if (/^l[1-5]-intro$/.test(name)) return { kind: 'tail', beats: 16, level: +name[1] };
    if (/^l[1-5]-outro$/.test(name)) return { kind: 'loop', beats: 16, level: +name[1] };
    if (/^l[1-5]-accents$/.test(name)) return { kind: 'sprite', beats: 15, level: +name[1] };
    return { menu: { kind: 'loop', beats: 32 }, alienwin: { kind: 'loop', beats: 32 },
      levelclear: { kind: 'tail', beats: 12 }, victory: { kind: 'tail', beats: 20 }, finale: { kind: 'tail', beats: 36 },
      'levelclear-fleet': { kind: 'tail', beats: 12 }, 'finale-fleet': { kind: 'tail', beats: 36 },
      cackle: { kind: 'oneshot', beats: 8, next: 'alienwin' } }[name] || { kind: 'loop', beats: 32 };
  }
  const immediate = ['levelclear', 'victory', 'finale', 'levelclear-fleet', 'finale-fleet', 'cackle'];
  // The whole allied fleet survived: a bigger arrangement of the same march,
  // bar for bar, chosen by fleetIntact() before (or switched in place after) the cue.
  const fleetVariant = { levelclear: 'levelclear-fleet', finale: 'finale-fleet' };
  let fleetIntactFlag = false;
  const probe = typeof Audio === 'function' ? new Audio() : null;
  const formats = probe?.canPlayType?.('audio/ogg; codecs="opus"') ? ['ogg', 'm4a'] : ['m4a', 'ogg'];

  function parseMidi(buffer) {
    const data = new Uint8Array(buffer);
    const view = new DataView(buffer);
    let pos = 14, end, tick = 0, status = 0;
    const ppq = view.getUint16(12), notes = [], open = new Map();
    const variable = () => { let n = 0, b; do { b = data[pos++]; n = (n << 7) | (b & 127); } while (b & 128); return n; };
    const length = view.getUint32(pos + 4); pos += 8; end = pos + length;
    while (pos < end) {
      tick += variable();
      if (data[pos] & 128) status = data[pos++];
      if (status === 0xff) { const type = data[pos++], size = variable(); pos += size; if (type === 0x2f) break; continue; }
      const kind = status & 0xf0, channel = status & 15, pitch = data[pos++], velocity = data[pos++], key = channel * 128 + pitch;
      if (kind === 0x90 && velocity) open.set(key, { beat: tick/ppq, pitch, velocity, channel });
      else if (kind === 0x80 || kind === 0x90) {
        const note = open.get(key);
        if (note) { notes.push({ ...note, duration: tick/ppq-note.beat }); open.delete(key); }
      }
    }
    return { notes, length: Math.max(4, tick / ppq) };
  }
  function loadMidi(name) {
    if (!midiCache.has(name)) midiCache.set(name, fetch(new URL(`${name}.mid`, midiRoot)).then(response => { if (!response.ok) throw new Error('MIDI unavailable'); return response.arrayBuffer(); }).then(parseMidi).catch(() => { midiCache.delete(name); return null; }));
    return midiCache.get(name);
  }
  // Compressed bytes may be fetched before the first gesture; decoding needs a context.
  function fetchBytes(name, format) {
    const key = `${name}.${format}`;
    if (!bytesCache.has(key)) bytesCache.set(key, fetch(new URL(key, musicRoot)).then(response => { if (!response.ok) throw new Error('music unavailable'); return response.arrayBuffer(); }).catch(() => { bytesCache.delete(key); return null; }));
    return bytesCache.get(key);
  }
  function decode(bytes) {
    return new Promise((resolve, reject) => {
      try {
        // Copy: decodeAudioData detaches its input, and the bytes stay cached.
        const result = context.decodeAudioData(bytes.slice(0), resolve, reject);
        if (result?.then) result.then(resolve, reject);
      } catch (error) { reject(error); }
    });
  }
  function inUse(key) {
    if ([active?.name, pending?.name, 'levelclear'].includes(key)) return true;
    const info = cueInfo(key);
    return info.level === scene.level && scene.level > 0;  // the current level's set stays decoded
  }
  async function loadBuffer(name) {
    if (!context?.decodeAudioData) return null;
    if (!bufferCache.has(name)) {
      bufferCache.set(name, (async () => {
        for (const format of formats) {
          const bytes = await fetchBytes(name, format);
          if (!bytes) continue;
          try { const buffer = await decode(bytes); if (buffer?.duration > 1) return buffer; } catch { /* try the next format */ }
        }
        return null;
      })().then(buffer => { if (!buffer) bufferCache.delete(name); else if (bufferCache.has(name)) ready.set(name, buffer); return buffer; }));
      // Evict the oldest decoded cue that is not in use.
      for (const key of bufferCache.keys()) {
        if (bufferCache.size <= bufferLimit) break;
        if (key !== name && !inUse(key)) { bufferCache.delete(key); ready.delete(key); }
      }
    }
    return bufferCache.get(name);
  }
  async function resolveCue(name) {
    const info = cueInfo(name);
    const buffer = await loadBuffer(name);
    if (buffer) {
      const opening = info.beats * beatSeconds;
      const tail = info.kind === 'tail';
      return { name, info, buffer, loop: info.kind !== 'oneshot',
        loopStart: tail ? Math.min(opening, buffer.duration - beatSeconds) : 0,
        loopEnd: tail ? buffer.duration : Math.min(buffer.duration, opening) };
    }
    const track = await loadMidi(name);
    return track ? { name, info, track, loop: info.kind === 'loop', loopTail: info.kind === 'tail' } : null;
  }

  function voice(note, at, duration, output = music) {
    if (!context || paused || at < context.currentTime-.1) return;
    const oscillator = context.createOscillator(), gain = context.createGain();
    const percussion = note.channel === 9;
    oscillator.type = percussion ? 'triangle' : note.channel === 1 ? 'sawtooth' : note.channel === 2 ? 'sine' : 'square';
    oscillator.frequency.setValueAtTime(440 * 2 ** ((note.pitch-69)/12), at);
    if (percussion) oscillator.frequency.exponentialRampToValueAtTime(35, at + .08);
    const volume = (note.velocity/127) * (percussion ? .16 : note.channel===2 ? .1 : .055);
    gain.gain.setValueAtTime(0, at);
    gain.gain.linearRampToValueAtTime(volume, at + .008);
    gain.gain.exponentialRampToValueAtTime(.0001, at + Math.max(.025, duration));
    oscillator.connect(gain); gain.connect(output);
    oscillator.start(at); oscillator.stop(at + duration + .04);
    const entry = { oscillator, gain, output, tag: note.tag, at };
    voices.add(entry);
    oscillator.onended = () => { voices.delete(entry); oscillator.disconnect(); gain.disconnect(); };
    return entry;
  }
  function release(entry, at, seconds = .025) {
    entry.released = true;
    entry.gain.gain.cancelScheduledValues(at);
    entry.gain.gain.setTargetAtTime(.0001, at, seconds);
    try { entry.oscillator.stop(at + seconds * 3.6); } catch { /* already stopped */ }
  }
  // Recorded cue playback: one buffer source per cue, started on a bar boundary
  // (at `offset` seconds into the file when a tier change keeps the loop position).
  function startFile(entry, at, offset = 0, fadeIn = 0) {
    const source = context.createBufferSource(), gain = context.createGain();
    source.buffer = entry.buffer;
    source.loop = entry.loop;
    if (entry.loop) { source.loopStart = entry.loopStart; source.loopEnd = entry.loopEnd; }
    if (fadeIn > 0) { gain.gain.setValueAtTime(0, at); gain.gain.linearRampToValueAtTime(fileGain, at + fadeIn); }
    else gain.gain.value = fileGain;
    source.connect(gain); gain.connect(music);
    source.start(at, offset);
    entry.player = { source, gain, startedAt: at, offset };
    source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch { /* detached */ } };
  }
  function stopFile(entry, at, seconds) {
    const player = entry?.player;
    if (!player) return;
    entry.player = null;
    player.gain.gain.cancelScheduledValues(at);
    player.gain.gain.setValueAtTime(fileGain, at);
    player.gain.gain.linearRampToValueAtTime(0, at + seconds);
    try { player.source.stop(at + seconds + .01); } catch { /* not started */ }
  }
  function activate(entry, at, offsetBeats = 0, fadeIn = 0) {
    active = entry; beat = offsetBeats;
    if (entry.info.tier) { scene.section = 'tiers'; scene.playing = entry.info.tier; }
    if (entry.buffer) startFile(entry, at, offsetBeats * beatSeconds, fadeIn);
    // A one-shot that hands over (the cackle) queues its successor at its end.
    if (entry.info.next) queue(entry.info.next, { atBeat: entry.info.beats });
  }
  function due(entry) {
    if (entry.atBeat !== undefined) return beat >= entry.atBeat && beat % 4 === 0;
    return beat % (entry.boundary || 4) === 0;
  }
  function schedule() {
    if (!context || paused || context.state !== 'running') return;
    while (nextBeat < context.currentTime + .12) {
      // All cues share 120 BPM; switching on a bar preserves pulse and release tails.
      if (pending && due(pending)) {
        const entry = pending; pending = null;
        if (entry.inPlace) {
          // Same march, same bars: continue at the same position (or tail-loop position).
          const opening = entry.info.beats;
          const position = beat < opening ? beat : opening + ((beat - opening) % 4);
          stopFile(active, nextBeat, .06);
          active = entry;
          if (entry.buffer) startFile(entry, nextBeat, position * beatSeconds, .02);
        } else if (entry.tierSwitch && active?.info.tier) {
          // Same motif, same bar structure: keep the loop position.
          const up = entry.info.tier > active.info.tier;
          const offset = beat % entry.info.beats;
          stopFile(active, nextBeat, up ? .06 : beatSeconds);
          activate(entry, nextBeat, offset, up ? .02 : .12);
        } else {
          stopFile(active, nextBeat, .12);
          activate(entry, nextBeat);
        }
      }
      if (active?.track) {
        const length = active.track.length;
        const local = active.loopTail && beat >= length ? length - 4 + ((beat - length) % 4) : beat % length;
        if (active.loop || active.loopTail || beat < length) for (const note of active.track.notes) if (note.beat >= local && note.beat < local+1) voice(note, nextBeat + (note.beat-local)*beatSeconds, note.duration*beatSeconds);
      }
      beat++; nextBeat += beatSeconds;
    }
  }
  // Keep the bar grid phase-continuous: only skip whole beats that fell behind.
  function realign() {
    if (!context) return;
    const lag = context.currentTime + .02 - nextBeat;
    if (lag > 0) { const skip = Math.ceil(lag / beatSeconds); nextBeat += skip * beatSeconds; beat += skip; }
  }
  async function unlock() {
    try {
      if (!context) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return false;
        context = new AudioContext();
        master = context.createGain(); music = context.createGain(); effects = context.createGain();
        master.gain.value = muted ? 0 : masterGain; effects.gain.value = effectsGain;
        music.connect(master); effects.connect(master); master.connect(context.destination);
        nextBeat = context.currentTime + .04;
        timer = setInterval(schedule, 25);
        await context.resume();
        if (wanted && !active) await start(wanted.name, ++requested);
        loadBuffer('levelclear');
        if (scene.level) preloadLevel(scene.level);
      } else await context.resume();
      realign(); schedule(); return true;
    } catch { return false; }
  }
  function prefetch(name) { for (const format of formats.slice(0, 1)) fetchBytes(name, format); }
  // A level's set loads lazily when the level is cued: bytes first, then
  // decoding in play order (tier 1 and the accents before the higher tiers).
  function preloadLevel(level) {
    const names = [`l${level}-t1`, `l${level}-accents`, `l${level}-t2`, `l${level}-t3`, `l${level}-t4`, `l${level}-outro`];
    names.forEach(prefetch);
    if (!context) return;
    names.reduce((chain, name) => chain.then(() => loadBuffer(name)), Promise.resolve());
  }
  async function queue(name, options = {}) {
    const ticket = requested;
    const entry = await resolveCue(name);
    if (!entry || ticket !== requested) return;
    pending = Object.assign(entry, options);
  }
  async function start(name, ticket) {
    const entry = await resolveCue(name);
    if (ticket !== requested || !entry) return;
    if (active?.name === name || pending?.name === name) return;
    if (!active || immediate.includes(name)) {
      // Clear, victory and the cackle must follow the moment, rather than wait up to a bar.
      // Release current/future scheduled music voices over 90ms; effects survive.
      if (context && active) {
        for (const voice of voices) if (voice.output === music) release(voice, context.currentTime);
        stopFile(active, context.currentTime, .09);
      }
      pending = null;
      if (context) { nextBeat = context.currentTime + .02; beat = 0; }
      activate(entry, nextBeat);
      schedule();
    } else pending = entry;
  }
  function cueName(mode, level, phase, cycle) {
    const lvl = Math.min(5, Math.max(1, Math.round(level) || 1));
    switch (mode) {
      case 'level': return `l${Math.min(4, lvl)}-intro`;
      case 'boss': return 'l5-intro';
      case 'travel': return `l${lvl}-outro`;
      case 'victory': return cycle >= 4 ? 'finale' : 'victory';
      case 'gameover': return 'cackle';
      case 'levelclear': case 'menu': return mode;
      default: return 'menu';
    }
  }
  // Carrier fallback when the game sends no intensity: its form picks the tier.
  const phaseTier = (phase, cycle) => Math.min(4, Math.max(1, Math.round(phase) + (cycle > 0 ? 1 : 0)));
  async function cue(mode, level = 1, phase = 1, cycle = 0) {
    let name = cueName(mode, level, phase, cycle);
    const variant = fleetVariant[name];
    if (variant) {
      if (active?.name === variant || pending?.name === variant) return;  // already celebrating the intact fleet
      if (fleetIntactFlag) name = variant;
    }
    if (!['levelclear', 'victory', 'finale'].includes(name.split('-')[0])) fleetIntactFlag = false;
    // Repeated events (carrier phase changes, a second game-over notice) do not restart a scene.
    if (mode === 'boss' && scene.level === 5 && (scene.section === 'tiers' || active?.name === 'l5-intro' || pending?.name === 'l5-intro')) {
      scene.phaseTier = phaseTier(phase, cycle);
      if (scene.section === 'tiers' && !scene.driven) intensity(scene.phaseTier, true);
      return;
    }
    if (name === 'cackle' && ['cackle', 'alienwin'].some(n => active?.name === n || pending?.name === n)) return;
    const ticket = ++requested;
    wanted = { name };
    const info = cueInfo(name);
    if (info.level && name.endsWith('-intro')) {
      Object.assign(scene, { level: info.level, section: 'intro', tier: 1, driven: false, phaseTier: mode === 'boss' ? phaseTier(phase, cycle) : 0 });
      preloadLevel(info.level);
    } else if (!name.endsWith('-outro')) { scene.section = null; }
    else scene.section = 'outro';
    // Fetch likely successors early; decoding still waits until they are cued.
    if (name === 'cackle') prefetch('alienwin');
    if (scene.level && (name.endsWith('-outro') || name === 'levelclear' || name === 'victory')) prefetch(`l${scene.level === 5 ? 1 : scene.level + 1}-intro`);
    if (!context) { formats.slice(0, 1).forEach(format => fetchBytes(name, format)); return; }
    await start(name, ticket);
  }
  // The ground forces report that the whole allied fleet survived (level clear
  // or campaign victory). Before the cue: pick the bigger variant. During the
  // normal cue: switch to it on the next bar at the same position.
  async function fleetIntact() {
    fleetIntactFlag = true;
    // Same tick as the cue (main.dart dispatches game events after the cues):
    // the normal march is still loading, so start the variant in its place.
    if (fleetVariant[wanted?.name] && active?.name !== wanted.name) {
      const name = fleetVariant[wanted.name];
      wanted = { name };
      if (context) await start(name, ++requested);
      return true;
    }
    const base = active?.name;
    if (!fleetVariant[base] || pending?.name === fleetVariant[base]) return false;
    const ticket = requested;
    const entry = await resolveCue(fleetVariant[base]);
    if (!entry || ticket !== requested || active?.name !== base) return false;
    pending = Object.assign(entry, { inPlace: true });
    return true;
  }
  // Intensity 1..4 of the current level. Tier changes land on the next bar and
  // keep the loop position; leaving the intro waits for its two-bar phrase.
  async function intensity(tier, fromPhase = false) {
    tier = Math.min(4, Math.max(1, Math.round(tier) || 1));
    if (!fromPhase) scene.driven = true;
    scene.tier = tier;
    if (!scene.level || !['intro', 'tiers'].includes(scene.section)) return tier;
    const name = `l${scene.level}-t${tier}`;
    if (active?.name === name && !pending) return tier;
    if (pending?.name === name) return tier;
    const ticket = requested;
    const entry = await resolveCue(name);
    if (!entry || ticket !== requested || scene.tier !== tier) return tier;
    if (active?.name === name) { pending = null; return tier; }
    if (!context || !active) { wanted = { name }; return tier; }
    // From the intro: hand over when its opening has played (then on a bar line).
    pending = Object.assign(entry, active.info.tier ? { tierSwitch: true } : active.info.kind === 'tail' ? { atBeat: active.info.beats } : {});
    return tier;
  }
  // Accents: the current level's stinger, quantized to the next half-beat or
  // beat of the music grid; never delays the caller.
  async function accent(name) {
    if (!context || paused || context.state !== 'running' || !accentSlots.includes(name) || !scene.level) return null;
    if ((lastAccent.get(name) ?? -9) > context.currentTime - 1) return null;  // at most one per second each
    lastAccent.set(name, context.currentTime);
    // Only an already-decoded sprite is used; otherwise start loading it and use the fallback.
    const key = `l${scene.level}-accents`, sprite = ready.get(key) || null;
    if (!sprite) loadBuffer(key);
    const now = context.currentTime;
    const quantum = accentQuantum[name];
    const lastBeat = nextBeat - beatSeconds;
    const at = lastBeat + quantum * Math.max(0, Math.ceil((now + .03 - lastBeat) / quantum - 1e-9));
    for (const live of accentsLive.splice(0)) if (live.end > now) accentsLive.push(live);
    if (accentsLive.length >= 2) return null;
    const slot = accentSlots.indexOf(name);
    if (sprite) {
      const source = context.createBufferSource(), gain = context.createGain();
      source.buffer = sprite; gain.gain.value = fileGain;
      source.connect(gain); gain.connect(music);
      source.start(at, slot * slotSeconds, slotSeconds);
      source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch { /* detached */ } };
    } else {
      // Fallback: a short synthesized figure with the same role.
      const pitches = { dive: [64, 67, 76], laststand: [52, 53, 65], hatch: [40, 46, 58], reinforce: [52, 55, 64], breakthrough: [52, 53, 52, 53] }[name];
      pitches.forEach((pitch, i) => voice({ pitch, velocity: 100, channel: 1 }, at + i * .125, .2));
    }
    accentsLive.push({ name, at, end: at + slotSeconds });
    accentLog.push({ name, at, requestedAt: now, level: scene.level, source: sprite ? 'file' : 'synth' });
    if (accentLog.length > 16) accentLog.shift();
    return at;
  }
  function mute(value = true) { muted = !!value; if (master) master.gain.setTargetAtTime(muted ? 0 : masterGain, context.currentTime, .03); return muted; }
  function pause() { paused = true; if (context) context.suspend().catch(() => {}); }
  async function resume() { paused = false; if (context) { await context.resume().catch(() => {}); realign(); } }

  // Effects: short synth voices with per-effect and global voice limits.
  const effectLimits = { shot: 4, hit: 4, explosion: 5, wave: 6, extraLife: 6 };
  const effectCeiling = 14;
  let noise;
  function limitVoices(tag) {
    const now = context.currentTime, live = [...voices].filter(v => v.output === effects && !v.released && v.at + .5 > now);
    const same = live.filter(v => v.tag === tag);
    // Steal the oldest voice; the new trigger keeps its exact timing.
    if (same.length >= (effectLimits[tag] || 3)) release(same[0], now, .008);
    else if (live.length >= effectCeiling) release(live[0], now, .008);
  }
  function noiseBurst(at, duration, level, frequency) {
    if (!context.createBuffer || !context.createBiquadFilter) return;
    if (!noise) { noise = context.createBuffer(1, context.sampleRate * .5, context.sampleRate); const data = noise.getChannelData(0); let seed = 1; for (let i = 0; i < data.length; i++) { seed = (seed * 16807) % 2147483647; data[i] = seed / 1073741823.5 - 1; } }
    const source = context.createBufferSource(), filter = context.createBiquadFilter(), gain = context.createGain();
    source.buffer = noise; filter.type = 'lowpass';
    filter.frequency.setValueAtTime(frequency, at); filter.frequency.exponentialRampToValueAtTime(120, at + duration);
    gain.gain.setValueAtTime(level, at); gain.gain.exponentialRampToValueAtTime(.0001, at + duration);
    source.connect(filter); filter.connect(gain); gain.connect(effects);
    source.start(at); source.stop(at + duration + .02);
    source.onended = () => { source.disconnect(); filter.disconnect(); gain.disconnect(); };
  }
  // --- ground war sfx: synth voices + filtered noise, no new assets ---
  function sweep(at, duration, from, to, level, type = 'sawtooth') {
    if (!context.createOscillator) return;
    const osc = context.createOscillator(), gain = context.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(from, at); osc.frequency.exponentialRampToValueAtTime(to, at + duration);
    gain.gain.setValueAtTime(level, at); gain.gain.exponentialRampToValueAtTime(.0001, at + duration);
    osc.connect(gain); gain.connect(effects); osc.start(at); osc.stop(at + duration + .02);
    osc.onended = () => { osc.disconnect(); gain.disconnect(); };
  }
  function groundSfx(name, now) {
    if (name === 'missileLaunch') { limitVoices('explosion'); noiseBurst(now, .55, .1, 3200); sweep(now, .5, 90, 340, .05); return true; }
    if (name === 'missileIncoming') { sweep(now, .7, 1900, 700, .035, 'sine'); return true; }
    if (name === 'homingLock') { limitVoices('hit'); voice({ pitch: 96, velocity: 55, channel: 0, tag: 'hit' }, now, .05, effects); voice({ pitch: 101, velocity: 55, channel: 0, tag: 'hit' }, now + .07, .06, effects); noiseBurst(now + .05, .3, .05, 5000); return true; }
    if (name === 'groundExplosion') { limitVoices('explosion'); voice({ pitch: 31, velocity: 100, channel: 9, tag: 'explosion' }, now, .3, effects); noiseBurst(now, .7, .16, 1500); return true; }
    return false;
  }
  function sfx(name) {
    if (!context || paused || context.state !== 'running') return;
    const now = context.currentTime + .005;
    if (name === 'extraLife' || name === 'wave') {
      limitVoices(name);
      const [pitches, step, length, velocity] = name === 'extraLife' ? [[76, 81, 88], .09, .3, 75] : [[72, 79, 84], .1, .22, 60];
      pitches.forEach((pitch, index) => voice({ pitch, velocity, channel: 0, tag: name }, now + index*step, length, effects));
      return;
    }
    if (name === 'fleetIntact') return;  // a music event, not an effect
    // --- ground war sfx (missile whoosh, incoming whistle, homing lock, ground blast) ---
    if (groundSfx(name, now)) return;
    const shapes = { shot: [82, .055, 35], explosion: [35, .24, 95], hit: [47, .12, 85], powerup: [84,.3,80], heart: [88,.16,65], life: [43,.4,90] };
    const [pitch, duration, velocity] = shapes[name] || shapes.hit;
    const tag = shapes[name] ? name : 'hit';
    limitVoices(tag);
    voice({ pitch, velocity, channel: name==='explosion' ? 9 : 0, tag }, now, duration, effects);
    if (name === 'explosion') noiseBurst(now, .32, .12, 2400);
    else if (name === 'life') noiseBurst(now, .45, .08, 900);
  }
  document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
  window.demonAudio = Object.freeze({ unlock, cue, intensity, accent, fleetIntact, mute, pause, resume, sfx, get muted() { return muted; },
    // Read-only diagnostics for browser checks.
    get state() { return { context: context?.state ?? 'none', time: context?.currentTime ?? 0, nextBeat, beat, active: active?.name ?? null, pending: pending?.name ?? null, source: active ? (active.buffer ? 'file' : 'midi') : null, startedAt: active?.player?.startedAt ?? null, offset: active?.player?.offset ?? null, duration: active?.buffer?.duration ?? null, loopStart: active?.loopStart ?? null, loopEnd: active?.loopEnd ?? null, paused, muted, voices: voices.size, sounding: [...voices].filter(v => !v.released).length, decoded: [...bufferCache.keys()], formats, scene: { ...scene }, accents: accentLog.slice(), fleetIntact: fleetIntactFlag }; } });
  // Unlock from real DOM gestures, including Flutter canvas input.
  for (const type of ['pointerdown','keydown']) window.addEventListener(type, unlock, { once: true, capture: true });
  cue('menu');
})();
