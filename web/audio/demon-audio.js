/* Original game music: recorded ACE-Step loops (web/audio/music/, built by
   tools/music_pipeline.py) on a shared 120 BPM audio-clock grid, with the
   original MIDI scores and Web Audio synthesizer as fallback and for effects.
   API calls are safe before the first user gesture and when audio is unavailable. */
(() => {
  'use strict';
  const midiRoot = new URL('./audio/midi/', document.baseURI);
  const musicRoot = new URL('./audio/music/', document.baseURI);
  const midiCache = new Map(), bytesCache = new Map(), bufferCache = new Map();
  let context, master, music, effects, timer, pending, active, wanted, nextBeat = 0, beat = 0;
  let muted = false, paused = false, requested = 0;
  const voices = new Set();
  const beatSeconds = .5;
  const fileGain = .7;          // recorded cues are mastered to -18 LUFS
  const bufferLimit = 6;        // decoded cues kept in memory (each ~6 MB)
  const finite = ['victory', 'gameover', 'levelclear'];
  const tails = ['victory', 'levelclear'];
  // Beats per cue: loopStart for a tail cue is its opening length.
  const cueBeats = name => name === 'travel' ? 16 : finite.includes(name) ? 8 : 32;
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
      })().then(buffer => { if (!buffer) bufferCache.delete(name); return buffer; }));
      // Evict the oldest decoded cue that is not in use.
      for (const key of bufferCache.keys()) {
        if (bufferCache.size <= bufferLimit) break;
        if (![active?.name, pending?.name, name, 'levelclear', 'travel'].includes(key)) bufferCache.delete(key);
      }
    }
    return bufferCache.get(name);
  }
  async function resolveCue(name) {
    const buffer = await loadBuffer(name);
    if (buffer) {
      const opening = cueBeats(name) * beatSeconds;
      return { name, buffer, loop: !finite.includes(name) || tails.includes(name),
        loopStart: tails.includes(name) ? Math.min(opening, buffer.duration - beatSeconds) : 0,
        loopEnd: tails.includes(name) ? buffer.duration : Math.min(buffer.duration, opening) };
    }
    const track = await loadMidi(name);
    return track ? { name, track, loop: !finite.includes(name), loopTail: tails.includes(name) } : null;
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
  // Recorded cue playback: one buffer source per cue, started on a bar boundary.
  function startFile(entry, at) {
    const source = context.createBufferSource(), gain = context.createGain();
    source.buffer = entry.buffer;
    source.loop = entry.loop;
    if (entry.loop) { source.loopStart = entry.loopStart; source.loopEnd = entry.loopEnd; }
    gain.gain.value = fileGain;
    source.connect(gain); gain.connect(music);
    source.start(at, 0);
    entry.player = { source, gain, startedAt: at };
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
  function activate(entry, at) {
    active = entry; beat = 0;
    if (entry.buffer) startFile(entry, at);
  }
  function schedule() {
    if (!context || paused || context.state !== 'running') return;
    while (nextBeat < context.currentTime + .12) {
      // All cues share 120 BPM; switching on a bar preserves pulse and release tails.
      if (pending && beat % 4 === 0) { stopFile(active, nextBeat, .12); const entry = pending; pending = null; activate(entry, nextBeat); }
      if (active?.track) {
        const local = active.loopTail && beat >= active.track.length
          ? active.track.length - 4 + ((beat - active.track.length) % 4)
          : beat % active.track.length;
        if (active.loop || active.loopTail || beat < active.track.length) for (const note of active.track.notes) if (note.beat >= local && note.beat < local+1) voice(note, nextBeat + (note.beat-local)*beatSeconds, note.duration*beatSeconds);
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
        master.gain.value = muted ? 0 : .65; effects.gain.value = .7;
        music.connect(master); effects.connect(master); master.connect(context.destination);
        nextBeat = context.currentTime + .04;
        timer = setInterval(schedule, 25);
        await context.resume();
        if (wanted && !active) await start(wanted.name, ++requested);
        loadBuffer('levelclear'); loadBuffer('travel');
      } else await context.resume();
      realign(); schedule(); return true;
    } catch { return false; }
  }
  function prefetch(name) { for (const format of formats.slice(0, 1)) fetchBytes(name, format); }
  async function start(name, ticket) {
    const entry = await resolveCue(name);
    if (ticket !== requested || !entry) return;
    if (active?.name === name || pending?.name === name) return;
    if (!active || name === 'levelclear') {
      // Clear feedback must follow the final kill, rather than wait up to a bar.
      // Release current/future scheduled music voices over 90ms; effects survive.
      if (context && name === 'levelclear') {
        for (const voice of voices) if (voice.output === music) release(voice, context.currentTime);
        stopFile(active, context.currentTime, .09);
      }
      pending = null;
      if (context) nextBeat = context.currentTime + .02;
      activate(entry, nextBeat);
      schedule();
    } else pending = entry;
  }
  async function cue(mode, level = 1, phase = 1, cycle = 0) {
    const ticket = ++requested;
    const name = mode === 'level' ? `level-${Math.min(4,Math.max(1,Math.round(level)))}` : mode === 'boss' ? `boss-${Math.min(4,Math.max(1,Math.round(phase)))}-${cycle > 0 ? 1 : 0}` : ['menu','victory','gameover','levelclear','travel'].includes(mode) ? mode : 'menu';
    wanted = { name };
    // Fetch likely successors early; decoding still waits until they are cued.
    if (name.startsWith('level-')) prefetch(`boss-1-${cycle > 0 ? 1 : 0}`);
    else if (name.startsWith('boss-') && phase < 4) prefetch(`boss-${Math.round(phase) + 1}-${cycle > 0 ? 1 : 0}`);
    if (!context) { formats.slice(0, 1).forEach(format => fetchBytes(name, format)); return; }
    await start(name, ticket);
  }
  function mute(value = true) { muted = !!value; if (master) master.gain.setTargetAtTime(muted ? 0 : .65, context.currentTime, .03); return muted; }
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
  window.demonAudio = Object.freeze({ unlock, cue, mute, pause, resume, sfx, get muted() { return muted; },
    get graph() { return { context, master, music, effects }; }, // shared with comms-audio.js
    // Read-only diagnostics for browser checks.
    get state() { return { context: context?.state ?? 'none', time: context?.currentTime ?? 0, nextBeat, beat, active: active?.name ?? null, pending: pending?.name ?? null, source: active ? (active.buffer ? 'file' : 'midi') : null, startedAt: active?.player?.startedAt ?? null, duration: active?.buffer?.duration ?? null, loopStart: active?.loopStart ?? null, loopEnd: active?.loopEnd ?? null, paused, muted, voices: voices.size, sounding: [...voices].filter(v => !v.released).length, decoded: [...bufferCache.keys()], formats }; } });
  // Unlock from real DOM gestures, including Flutter canvas input.
  for (const type of ['pointerdown','keydown']) window.addEventListener(type, unlock, { once: true, capture: true });
  cue('menu');
})();
