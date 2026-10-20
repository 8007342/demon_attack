/* Original MIDI scores rendered locally by a small Web Audio synthesizer.
   API calls are safe before the first user gesture and when audio is unavailable. */
(() => {
  'use strict';
  const root = new URL('./audio/midi/', document.baseURI);
  const cache = new Map();
  let context, master, music, effects, timer, pending, active, nextBeat = 0, beat = 0;
  let muted = false, paused = false, requested = 0;
  const voices = new Set();
  const beatSeconds = .5;
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
  async function load(name) {
    if (!cache.has(name)) cache.set(name, fetch(new URL(`${name}.mid`, root)).then(response => { if (!response.ok) throw new Error('MIDI unavailable'); return response.arrayBuffer(); }).then(parseMidi).catch(() => { cache.delete(name); return null; }));
    return cache.get(name);
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
    voices.add(oscillator);
    oscillator.onended = () => { voices.delete(oscillator); oscillator.disconnect(); gain.disconnect(); };
  }
  function schedule() {
    if (!context || paused || context.state !== 'running') return;
    while (nextBeat < context.currentTime + .12) {
      // All cues share 120 BPM; switching on a bar preserves pulse and release tails.
      if (pending && beat % 4 === 0) { active = pending; pending = null; beat = 0; }
      if (active) {
        const local = active.loopTail && beat >= active.track.length
          ? active.track.length - 4 + ((beat - active.track.length) % 4)
          : beat % active.track.length;
        if (active.loop || active.loopTail || beat < active.track.length) for (const note of active.track.notes) if (note.beat >= local && note.beat < local+1) voice(note, nextBeat + (note.beat-local)*beatSeconds, note.duration*beatSeconds);
      }
      beat++; nextBeat += beatSeconds;
    }
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
      }
      await context.resume(); schedule(); return true;
    } catch { return false; }
  }
  async function cue(mode, level = 1, phase = 1, cycle = 0) {
    const ticket = ++requested;
    const name = mode === 'level' ? `level-${Math.min(4,Math.max(1,Math.round(level)))}` : mode === 'boss' ? `boss-${Math.min(4,Math.max(1,Math.round(phase)))}-${cycle > 0 ? 1 : 0}` : ['menu','victory','gameover'].includes(mode) ? mode : 'menu';
    const track = await load(name);
    if (ticket !== requested || !track) return;
    const entry = { name, track, loop: !['victory','gameover'].includes(name), loopTail: name === 'victory' };
    if (active?.name === name || pending?.name === name) return;
    if (!active) { active = entry; beat = 0; if (context) nextBeat = context.currentTime + .04; }
    else pending = entry;
  }
  function mute(value = true) { muted = !!value; if (master) master.gain.setTargetAtTime(muted ? 0 : .65, context.currentTime, .03); return muted; }
  function pause() { paused = true; if (context) context.suspend().catch(() => {}); }
  async function resume() { paused = false; if (context) { await context.resume().catch(() => {}); nextBeat = context.currentTime + .04; } }
  function sfx(name) {
    if (!context || paused || context.state !== 'running') return;
    const shapes = { shot: [82, .055, 35], explosion: [35, .24, 95], hit: [47, .12, 85], powerup: [84,.3,80], life: [43,.4,90] };
    const [pitch, duration, velocity] = shapes[name] || shapes.hit;
    voice({ pitch, velocity, channel: name==='explosion' ? 9 : 0 }, context.currentTime+.005, duration, effects);
  }
  document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); else resume(); });
  window.demonAudio = Object.freeze({ unlock, cue, mute, pause, resume, sfx, get muted() { return muted; } });
  // Unlock from real DOM gestures, including Flutter canvas input.
  for (const type of ['pointerdown','keydown']) window.addEventListener(type, unlock, { once: true, capture: true });
  cue('menu');
})();
