/* The game's audio engine: one Web Audio context, the music and effects buses, the player's volume levels, and the
   synthesized effects. The music is the MIDI-first score (web/audio/score/, played by demon-score.js inside this
   file's 25 ms scheduler): SongDirector (lib/game/song_director.dart) moves it with song(move), and game accents
   become stingers in the score's key on its grid. There is no recorded music (adaptive-soundtrack design §12.8):
   the score plays the overture, every sector and carrier, the bridges, the defeat and the coda.
   API calls are safe before the first user gesture and when audio is unavailable. */
(() => {
  'use strict';
  // music: the music bus (demonAudio.graph). Effects never side-chain it and the life loss no longer dips it.
  // drop is a fixed unity-gain stage of the music chain (comms-audio.js shares the graph).
  // sidechain: the speech duck (mix-balance, operator round 5 M1): a few dB down while a radio line plays, on
  // its own gain stage, so the score's track gains, masks and bar-quantised moves never see it.
  // musicLevel: the player's music volume (Mute/Low/Full);
  // bright: a high shelf that opens while a power-up pickup is falling;
  // limiter: a safety limiter on the master (Full music + stacked layers).
  let context, master, music, musicLevel, bright, limiter, drop, sidechain, effects, timer;
  let muted = false, paused = false;
  const voices = new Set();
  const masterGain = .65, effectsGain = 1;
  // The accents that always play, even over two live stingers or with the music muted (the life loss).
  const lifeLoss = ['destroyed', 'gloat', 'respawn'];
  // --- audio round: player volume levels.
  // Volume levels per channel, cycled Mute -> Low -> Full by the HUD toggles and remembered per device. Speech
  // gains live in comms-audio.js. Effects keep their level unless both music and speech are muted, which mutes
  // everything (the old master mute).
  // --- mix-balance / mix-retune: Full music is -14 dB on the music level, Low 10 dB under Full. Metered with
  // tools/mix_meter/measure.mjs (and the score's section trims, web/audio/score/mix-trim.json, which hold every section
  // within 2 LU), this puts the score 2.5-4.5 LU under the radio at Full/Full. History: +6 dB sat 6-8 LU OVER the radio
  // and drove the master limiter; -20 dB (mix-balance) was too quiet. Stored choices keep their names.
  const levelNames = ['mute', 'low', 'full'];
  const dB = value => 10 ** (value / 20);
  const musicFullDb = -14;
  const musicLevels = { mute: 0, low: dB(musicFullDb - 10), full: dB(musicFullDb) };
  const storageKeys = { music: 'demonAttack.musicVolume', speech: 'demonAttack.speechVolume' };
  function storage() { try { return window.localStorage || null; } catch { return null; } }
  function readLevel(channel) {
    try { const value = storage()?.getItem(storageKeys[channel]); return levelNames.includes(value) ? value : 'full'; } catch { return 'full'; }
  }
  function writeLevel(channel, value) {
    try { const store = storage(); if (!store) return false; store.setItem(storageKeys[channel], value); return true; } catch { return false; }  // private mode / denied storage
  }
  const levels = { music: readLevel('music'), speech: readLevel('speech') };
  const limiterSettings = { threshold: -1.5, knee: 0, ratio: 20, attack: .002, release: .12 };
  // Power-ups: the score's power layer (ride and double kick) follows the active powers on its next bar line;
  // while a pickup is falling the music's top end opens a little.
  const brightDb = 3, brightHz = 3500;
  const power = { active: 0, falling: false, brightOn: false };

  // --- mix-balance: the speech duck. comms-audio.js calls duck(key, depthDb, from, until) when a radio line starts
  // (audio-clock times of its first and last sample) and unduck(key, at) when a line is cut early. The duck gain
  // follows the deepest line sounding: down with an attack time constant, held for `hold` after the last line ends,
  // then back with a release time constant (setTargetAtTime: about 3 time constants to settle). The plan is kept here
  // so a change mid-ramp starts from the exact scheduled value, without reading AudioParam.value.
  const duckTiming = { attack: .03, release: .15, hold: .25 };
  const duckHolders = new Map();   // key -> { depth, from, until }
  let duckPlan = { at: 0, value: 1, steps: [] };   // value at `at`, then setTargetAtTime steps { at, target, tau }
  function duckValueAt(t) {
    let value = duckPlan.value, from = duckPlan.at, target = null, tau = 1;
    for (const step of duckPlan.steps) {
      if (step.at > t) break;
      if (target !== null) value = target + (value - target) * Math.exp(-(step.at - from) / tau);
      from = step.at; target = step.target; tau = step.tau;
    }
    return target === null ? value : target + (value - target) * Math.exp(-(t - from) / tau);
  }
  function duckDepthAt(t) {
    let depth = 0;
    for (const h of duckHolders.values()) if (h.from <= t + 1e-9 && t < h.until + duckTiming.hold - 1e-9) depth = Math.max(depth, h.depth);
    return depth;
  }
  function planDuck() {
    if (!context || !sidechain) return;
    const now = context.currentTime;
    for (const [key, h] of duckHolders) if (h.until + duckTiming.hold < now) duckHolders.delete(key);
    const value = duckValueAt(now), times = new Set([now]);
    for (const h of duckHolders.values()) for (const t of [h.from, h.until + duckTiming.hold]) if (t > now) times.add(t);
    // One step now toward the depth that holds now (unless already there), then one per change of depth.
    const steps = [];
    let previous = null;
    for (const at of [...times].sort((a, b) => a - b)) {
      const target = dB(-duckDepthAt(at)), from = previous ?? value;
      if (Math.abs(target - from) > 1e-6) steps.push({ at, target, tau: target < from ? duckTiming.attack : duckTiming.release });
      previous = target;
    }
    const gain = sidechain.gain;
    gain.cancelScheduledValues(now);
    gain.setValueAtTime(value, now);
    for (const step of steps) gain.setTargetAtTime(step.target, step.at, step.tau);
    duckPlan = { at: now, value, steps };
  }
  function duck(key, depthDb, from, until) {
    if (!context || key === undefined || key === null) return false;
    const depth = Math.max(0, Math.min(12, Number(depthDb) || 0));
    if (!depth || !(until > from)) { duckHolders.delete(key); planDuck(); return false; }
    duckHolders.set(key, { depth, from: Math.max(from, context.currentTime), until });
    planDuck();
    return true;
  }
  function unduck(key, at) {
    const h = duckHolders.get(key);
    if (!h || !context) return false;
    h.until = Math.max(h.from, Math.min(h.until, Number.isFinite(at) ? at : context.currentTime));
    planDuck();
    return true;
  }

  // --- the score (demon-score.js, loaded first; absent in older pages and tests).
  const score = window.demonScore?.create({ input: () => drop, lifeLoss }) || null;

  function schedule() {
    if (!context || paused || context.state !== 'running') return;
    score?.tick(context.currentTime + window.demonScore.LOOKAHEAD);
  }
  async function unlock() {
    try {
      if (!context) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return false;
        context = new AudioContext();
        master = context.createGain(); music = context.createGain(); musicLevel = context.createGain(); drop = context.createGain(); sidechain = context.createGain(); effects = context.createGain();
        master.gain.value = masterLevel(); effects.gain.value = effectsGain; musicLevel.gain.value = musicLevels[levels.music];
        bright = context.createBiquadFilter?.() || null;
        if (bright) { bright.type = 'highshelf'; bright.frequency.value = brightHz; bright.gain.value = 0; }
        limiter = context.createDynamicsCompressor?.() || null;
        if (limiter) for (const [key, value] of Object.entries(limiterSettings)) if (limiter[key]) limiter[key].value = value;
        drop.connect(sidechain);
        if (bright) { sidechain.connect(bright); bright.connect(music); } else sidechain.connect(music);
        music.connect(musicLevel); musicLevel.connect(master); effects.connect(master);
        if (limiter) { master.connect(limiter); limiter.connect(context.destination); } else master.connect(context.destination);
        score?.attach(context);
        timer = setInterval(schedule, 25);
        await context.resume();
      } else await context.resume();
      schedule(); return true;
    } catch { return false; }
  }

  // Effects voices: a short oscillator with an envelope.
  function voice(note, at, duration, output = effects) {
    if (!context || paused || at < context.currentTime - .1) return;
    const oscillator = context.createOscillator(), gain = context.createGain();
    const percussion = note.channel === 9;
    oscillator.type = percussion ? 'triangle' : note.channel === 1 ? 'sawtooth' : note.channel === 2 ? 'sine' : 'square';
    oscillator.frequency.setValueAtTime(440 * 2 ** ((note.pitch - 69) / 12), at);
    if (percussion) oscillator.frequency.exponentialRampToValueAtTime(35, at + .08);
    const volume = (note.velocity / 127) * (percussion ? .16 : note.channel === 2 ? .1 : .055);
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

  // Music intensity and the fleet's survival reach the score through SongDirector's masks (the game's shared
  // event bridge); these stay for callers of the old API and only report.
  function intensity(tier) { return Math.min(4, Math.max(1, Math.round(tier) || 1)); }
  function fleetIntact() { return !!score; }
  // Accents: a stinger in the playing section's key on its grid; never delays the caller.
  function accent(name) {
    if (!score || !context || paused || context.state !== 'running') return null;
    if (levels.music === 'mute' && !lifeLoss.includes(name)) return null;  // nothing to hear
    return score.accent(name);
  }
  // Power-up layer: what the game reports (active power count, a pickup in the air), applied on the next bar line.
  function powerLayer(active = 0, falling = false) {
    power.active = Math.max(0, Math.round(Number(active) || 0));
    power.falling = !!falling;
    score?.power(power.active);
    if (context && bright && power.falling !== power.brightOn) {
      const at = score?.playing ? score.nextBar(context.currentTime + .03) : context.currentTime;
      bright.gain.setTargetAtTime(power.falling ? brightDb : 0, at, .08);
      power.brightOn = power.falling;
    }
    return { active: power.active, falling: power.falling };
  }
  // Master: silent when muted, or when both music and speech are set to Mute.
  function masterLevel() { return muted || (levels.music === 'mute' && levels.speech === 'mute') ? 0 : masterGain; }
  function applyLevels() {
    if (!context) return;
    const now = context.currentTime;
    master.gain.setTargetAtTime(masterLevel(), now, .03);
    musicLevel.gain.setTargetAtTime(musicLevels[levels.music], now, .03);
  }
  function mute(value = true) { muted = !!value; applyLevels(); return muted; }
  // setLevel('music' | 'speech', 'mute' | 'low' | 'full'): applies and remembers the choice (storage may be
  // unavailable; the choice then lasts the session).
  function setLevel(channel, value) {
    if (!(channel in levels) || !levelNames.includes(value)) return null;
    levels[channel] = value;
    const stored = writeLevel(channel, value);
    applyLevels();
    if (channel === 'speech') window.commsAudio?.setLevel?.(value);
    return { ...levels, stored };
  }
  function pause() { paused = true; if (context) context.suspend().catch(() => {}); }
  async function resume() { paused = false; if (context) { await context.resume().catch(() => {}); schedule(); } }

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
    // --- bonus levels: Stormfront (a rising static crackle, then thunder)
    if (name === 'stormTell') { sweep(now, 1.05, 240, 2600, .022, 'square'); noiseBurst(now + .6, .45, .035, 6200); return true; }
    if (name === 'stormBolt') { limitVoices('explosion'); noiseBurst(now, .12, .2, 7000); voice({ pitch: 28, velocity: 110, channel: 9, tag: 'explosion' }, now + .03, .5, effects); noiseBurst(now + .05, .5, .13, 420); noiseBurst(now + .45, .5, .08, 260); return true; }
    // --- lightning-rework: a stun's crackle, the ship's zap (a hard buzz and a falling sweep: the powers are gone, never the ship), a rod drinking a bolt (a rising whine).
    if (name === 'stormStun') { noiseBurst(now, .09, .09, 5200); noiseBurst(now + .1, .07, .07, 4600); sweep(now + .02, .35, 1800, 420, .02, 'square'); return true; }
    if (name === 'shipZapped') { limitVoices('life'); noiseBurst(now, .25, .16, 6800); sweep(now, .5, 1600, 180, .035, 'sawtooth'); noiseBurst(now + .28, .3, .06, 900); return true; }
    // --- spear-bearers: the wind-up's glint (a bright ting), the throw (an airy whoosh), the buckler struck (a dull clang) and knocked away (a clang and a falling rattle).
    if (name === 'spearGlint') { sweep(now, .16, 2400, 3600, .018, 'sine'); sweep(now + .08, .2, 3200, 4200, .012, 'sine'); return true; }
    if (name === 'spearRelease') { noiseBurst(now, .28, .07, 2600); sweep(now, .25, 900, 260, .02, 'triangle'); return true; }
    if (name === 'bucklerClang') { limitVoices('hit'); sweep(now, .18, 520, 380, .035, 'square'); noiseBurst(now, .08, .06, 3800); return true; }
    if (name === 'bucklerOff') { limitVoices('hit'); sweep(now, .22, 600, 300, .04, 'square'); noiseBurst(now + .05, .4, .05, 1400); sweep(now + .12, .45, 300, 90, .015, 'triangle'); return true; }
    if (name === 'demonCharged') { sweep(now, .45, 300, 1900, .02, 'square'); noiseBurst(now + .35, .12, .05, 5600); return true; }
    if (name === 'groundExplosion') {
 limitVoices('explosion'); voice({ pitch: 31, velocity: 100, channel: 9, tag: 'explosion' }, now, .3, effects); noiseBurst(now, .7, .16, 1500); return true; }
    return false;
  }
  function sfx(name) {
    if (!context || paused || context.state !== 'running') return;
    const now = context.currentTime + .005;
    if (name === 'extraLife' || name === 'wave') {
      limitVoices(name);
      const [pitches, step, length, velocity] = name === 'extraLife' ? [[76, 81, 88], .09, .3, 75] : [[72, 79, 84], .1, .22, 60];
      pitches.forEach((pitch, index) => voice({ pitch, velocity, channel: 0, tag: name }, now + index * step, length, effects));
      return;
    }
    if (name === 'fleetIntact') return;  // a music event, not an effect
    // --- mission-medals: a bonus crate shot open (a wooden pop and a bright three-note chime).
    if (name === 'crateOpen') {
      limitVoices('wave');
      noiseBurst(now, .16, .07, 1800);
      [79, 86, 91].forEach((pitch, index) => voice({ pitch, velocity: 62, channel: 0, tag: 'wave' }, now + .03 + index * .055, .14, effects));
      return;
    }
    // --- ground war sfx (missile whoosh, incoming whistle, homing lock, ground blast) ---
    if (groundSfx(name, now)) return;
    const shapes = { shot: [82, .055, 35], explosion: [35, .24, 95], hit: [47, .12, 85], powerup: [84, .3, 80], heart: [88, .16, 65], life: [43, .4, 90] };
    const [pitch, duration, velocity] = shapes[name] || shapes.hit;
    const tag = shapes[name] ? name : 'hit';
    limitVoices(tag);
    voice({ pitch, velocity, channel: name === 'explosion' ? 9 : 0, tag }, now, duration, effects);
    if (name === 'explosion') noiseBurst(now, .32, .12, 2400);
    else if (name === 'life') noiseBurst(now, .45, .08, 900);
  }
  document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
  // --- adaptive-soundtrack: SongDirector's moves (see demon-score.js move()); returns the landing time, -1 while
  // loading or before the first gesture (the move runs once ready), -2 when the score failed to load.
  function song(move) { return score ? score.move(move || {}) : -2; }
  // --- sample-bank: the score's sample-bank switch (off by default until approved; /console's music panel, ?bank=1).
  function setScoreBank(on) { return score ? score.setBank(!!on) : false; }
  window.demonAudio = Object.freeze({ unlock, intensity, accent, fleetIntact, mute, pause, resume, sfx, setLevel, powerLayer, song, duck, unduck, setScoreBank, get muted() { return muted; },
    get scoreBank() { return !!score?.bankOn; },
    get time() { return context?.currentTime ?? -1; },
    get scorePosition() { return score?.position ?? null; },
    get scoreLoading() { return score?.loading ?? Promise.resolve(); },
    get bankLoading() { return score?.bankLoading ?? Promise.resolve(); },
    get levels() { return { ...levels }; },
    get graph() { return { context, master, music, effects, duck: sidechain }; }, // shared with comms-audio.js
    // Read-only diagnostics for browser checks.
    get state() { return { context: context?.state ?? 'none', time: context?.currentTime ?? 0, paused, muted, voices: voices.size, sounding: [...voices].filter(v => !v.released).length,
      levels: { ...levels }, masterGain: master?.gain.value ?? null, musicLevel: musicLevel?.gain.value ?? null, limiter: !!limiter,
      power: { ...power }, score: score?.state ?? null,
      duck: { gain: context ? duckValueAt(context.currentTime) : 1, depthDb: context ? duckDepthAt(context.currentTime) : 0, lines: duckHolders.size, ...duckTiming } }; } });
  // Unlock from real DOM gestures, including Flutter canvas input.
  for (const type of ['pointerdown', 'keydown']) window.addEventListener(type, unlock, { once: true, capture: true });
})();
