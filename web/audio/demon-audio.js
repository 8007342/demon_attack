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
  // music: the bus the comms layer ducks (demonAudio.graph); drop: the
  // life-loss dip under it, so the two never fight over one gain.
  // musicLevel: the player's music volume (Mute/Low/Full) after the duck;
  // bright: a high shelf that opens while a power-up pickup is falling;
  // limiter: a safety limiter on the master (Full music + stacked layers).
  let context, master, music, musicLevel, bright, limiter, drop, sidechain, effects, timer, pending, active, wanted, nextBeat = 0, beat = 0;
  let muted = false, paused = false, requested = 0;
  // The level whose music plays: its intro, then its tiers.
  const scene = { level: 0, tier: 1, section: null, phaseTier: 0 };
  const voices = new Set(), accentsLive = [], accentLog = [], lastAccent = new Map();
  // The scheduler grid follows the active cue's tempo. Each level runs at its
  // own BPM, defined by an integer number of samples per bar at 48 kHz
  // (tools/music_motifs.py BAR_SAMPLES, mirrored in manifest.json): L1 170,
  // L2 160, L3 180, L4 150, Carrier 190. Marches, alien victory and menu: 120.
  const levelBarSamples = { 1: 67765, 2: 72000, 3: 64000, 4: 76800, 5: 60632 };
  const levelBeat = level => levelBarSamples[level] / 48000 / 4;
  let beatSeconds = .5;
  const fileGain = .7;          // recorded cues are mastered to -18..-19 LUFS
  const bufferLimit = 14;       // decoded cues kept (a level is ~10: intro, 4 tiers, outro, accents, layers, power, clear)
  const masterGain = .65, effectsGain = 1;  // effects sit above the battle-metal mixes
  const sidechainDip = .8, sidechainTags = ['explosion', 'life', 'hit'];  // -2 dB music dip under big effects
  // Cue table (mirrors web/audio/music/manifest.json; checked by test-worker).
  const accentSlots = ['dive', 'laststand', 'hatch', 'reinforce', 'breakthrough', 'destroyed', 'gloat', 'respawn'];
  // Quantum in beats of the level's own grid: half-beat, beat, or a sixteenth for the hit.
  const accentQuantum = { dive: .5, reinforce: .5, laststand: 1, hatch: 1, breakthrough: 1, destroyed: .25, gloat: 1, respawn: 1 };
  const lifeLoss = ['destroyed', 'gloat', 'respawn'];
  const dropLevel = .15, dropBars = 2;  // life loss: music dips under the hit stinger for two bars
  const slotSeconds = 1.5;
  // --- audio round: player volume levels, composable dive layers, power layer.
  // Volume levels per channel, cycled Mute -> Low -> Full by the HUD
  // toggles and remembered per device. Music gains are relative to the
  // round-3 mix (music then sat at fileGain .7 x master .65): Full is +6 dB
  // louder than that, Low is 10 dB under Full. Speech gains live in
  // comms-audio.js. Effects keep their level unless both music and speech are
  // muted, which mutes everything (the old master mute).
  const levelNames = ['mute', 'low', 'full'];
  const dB = value => 10 ** (value / 20);
  const musicLevels = { mute: 0, low: dB(-4), full: dB(6) };
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
  // Dive accents compose: each dive tell adds a different layer of the level's
  // own recorded tiers (l<n>-layers: slices of the tier masters, so tempo and
  // key are the level's), quantized to its grid, at most `layerCap` at once.
  // role: hit / drums / tone; a new layer prefers a role not sounding yet.
  // quantum: grid unit in beats; beats: how long the layer sounds (its slot
  // is two bars and ends silent).
  const layerSlots = ['stab', 'swell', 'fill', 'gallop', 'lead', 'low'];
  const layerInfo = {
    stab: { role: 'hit', quantum: .5, beats: 7.5 },   // a tier-4 riff stab in a 3+3+2 figure over two bars
    swell: { role: 'hit', quantum: 1, beats: 5 },     // reversed tier-4 chord into its downbeat one beat later, ringing
    fill: { role: 'drums', quantum: 2, beats: 6 },    // the densest tier-4 drum half-bar, then the bar it lands on
    gallop: { role: 'drums', quantum: 2, beats: 7.5 },// two bars of tier-2/3 drums (kick gallop; backbeat stays on 2 and 4)
    lead: { role: 'tone', quantum: 4, beats: 7 },     // two bars of the tier-3 lead band from the next bar line
    low: { role: 'tone', quantum: 1, beats: 7 },      // low band of a tier-4 downbeat's two bars (bass weight)
  };
  const layerSlotBeats = 8, layerCap = 4;
  const stackGain = [1, dB(-2), dB(-3.5), dB(-5)];  // later layers sit lower; the limiter holds the sum
  const layersLive = [], layerLog = [];
  let lastLayer = null, layerSeed = 1982;
  const nextRandom = () => (layerSeed = (layerSeed * 16807) % 2147483647) / 2147483647;
  // Power-ups: while one is active, l<n>-power (the level's tier-4 drums above
  // 3 kHz: cymbals, snare crack) loops over the tiers at the same loop
  // position, louder with two or more; while a pickup is falling the music's
  // top end opens a little. Both change on bar lines.
  const powerGain = { 0: 0, 1: dB(-6), 2: dB(-3) };
  const brightDb = 3, brightHz = 3500;
  const power = { active: 0, falling: false, player: null, brightOn: false };
  function cueInfo(name) {
    const info = levelCueInfo(name);
    info.beatSeconds = info.level ? levelBeat(info.level) : .5;
    return info;
  }
  function levelCueInfo(name) {
    if (/^l[1-5]-t[1-4]$/.test(name)) return { kind: 'loop', beats: 32, level: +name[1], tier: +name[4] };
    if (/^l[1-5]-intro$/.test(name)) return { kind: 'tail', beats: 16, level: +name[1] };
    if (/^l[1-5]-outro$/.test(name)) return { kind: 'loop', beats: 16, level: +name[1] };
    if (/^l[1-5]-accents$/.test(name)) return { kind: 'sprite', beats: 0, level: +name[1] };
    if (/^l[1-5]-layers$/.test(name)) return { kind: 'sprite', beats: 0, level: +name[1] };
    if (/^l[1-5]-power$/.test(name)) return { kind: 'loop', beats: 32, level: +name[1], layer: true };
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
      const opening = info.beats * info.beatSeconds;
      const tail = info.kind === 'tail';
      return { name, info, buffer, loop: info.kind !== 'oneshot',
        loopStart: tail ? Math.min(opening, buffer.duration - info.beatSeconds) : 0,
        loopEnd: tail ? buffer.duration : Math.min(buffer.duration, opening) };
    }
    const track = await loadMidi(name);
    return track ? { name, info, track, loop: info.kind === 'loop', loopTail: info.kind === 'tail' } : null;
  }

  function voice(note, at, duration, output = drop) {
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
    source.connect(gain); gain.connect(drop);
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
    // From here the grid runs at this cue's tempo (the bar that just ended was the old one's).
    active = entry; beat = offsetBeats; beatSeconds = entry.info.beatSeconds;
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
      // Cues change on the active cue's bar line; a cue at another tempo then
      // starts its own grid there (the old bar is always finished first).
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
      if (beat % 4 === 0) syncPower(nextBeat);
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
    const names = [`l${level}-t1`, `l${level}-accents`, `l${level}-layers`, `l${level}-t2`, `l${level}-power`, `l${level}-t3`, `l${level}-t4`, `l${level}-outro`];
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
        for (const voice of voices) if (voice.output === drop) release(voice, context.currentTime);
        stopFile(active, context.currentTime, .09);
        stopPower(context.currentTime, .09);
      }
      pending = null;
      if (context) { nextBeat = context.currentTime + .02; beat = 0; restoreMusic(context.currentTime); }
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
    if (levels.music === 'mute' && !lifeLoss.includes(name)) return null;  // nothing to hear; the life-loss drop still applies
    // At most one per second each; dive layers compose, so dives may come every half second.
    if ((lastAccent.get(name) ?? -9) > context.currentTime - (name === 'dive' ? .5 : 1)) return null;
    if (name === 'dive') {
      const layered = diveLayer();
      if (layered !== undefined) { if (layered !== null) lastAccent.set(name, context.currentTime); return layered; }
    }
    lastAccent.set(name, context.currentTime);
    // Only an already-decoded sprite is used; otherwise start loading it and use the fallback.
    const key = `l${scene.level}-accents`, sprite = ready.get(key) || null;
    if (!sprite) loadBuffer(key);
    const now = context.currentTime;
    const quantum = accentQuantum[name] * beatSeconds;
    const lastBeat = nextBeat - beatSeconds;
    const at = lastBeat + quantum * Math.max(0, Math.ceil((now + .03 - lastBeat) / quantum - 1e-9));
    for (const live of accentsLive.splice(0)) if (live.end > now) accentsLive.push(live);
    // At most two accents at once, except the life-loss moments, which always play.
    if (accentsLive.length >= 2 && !lifeLoss.includes(name)) return null;
    const slot = accentSlots.indexOf(name);
    if (sprite) {
      const source = context.createBufferSource(), gain = context.createGain();
      // Accents bypass the life-loss drop (the hit must sound over it) but
      // stay on the ducked music bus.
      source.buffer = sprite; gain.gain.value = fileGain;
      source.connect(gain); gain.connect(music);
      source.start(at, slot * slotSeconds, slotSeconds);
      source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch { /* detached */ } };
    } else {
      // Fallback: a short synthesized figure with the same role.
      const pitches = { dive: [64, 67, 76], laststand: [52, 53, 65], hatch: [40, 46, 58], reinforce: [52, 55, 64], breakthrough: [52, 53, 52, 53],
        destroyed: [28, 40], gloat: [46, 45, 40], respawn: [52, 59, 64, 71] }[name];
      pitches.forEach((pitch, i) => voice({ pitch, velocity: 100, channel: 1 }, at + i * .125, .2, music));
    }
    // Life loss: the hit drops the music for two bars; the re-entry brings it
    // back on the respawn accent's downbeat (its crash, one beat into the slot).
    if (name === 'destroyed') dropMusic(at);
    else if (name === 'respawn') restoreMusic(at + beatSeconds);
    accentsLive.push({ name, at, end: at + slotSeconds });
    accentLog.push({ name, at, requestedAt: now, level: scene.level, source: sprite ? 'file' : 'synth' });
    if (accentLog.length > 16) accentLog.shift();
    return at;
  }
  // Grid time of the next multiple of `quantum` beats, at least 30 ms ahead.
  // Beat 0 is the active cue's start (a tier's loop start), so bar lines are
  // multiples of 4.
  function gridTime(quantum, now = context.currentTime) {
    const unit = quantum * beatSeconds, origin = nextBeat - beat * beatSeconds;
    return origin + unit * Math.max(0, Math.ceil((now + .03 - origin) / unit - 1e-9));
  }
  // Picks the next dive layer: never one already sounding, never the last
  // one again, a role that is not sounding yet if there is one; an empty
  // stack starts with a layer that lands within a beat.
  function pickLayer() {
    const live = new Set(layersLive.map(l => l.name)), roles = new Set(layersLive.map(l => layerInfo[l.name].role));
    const open = layerSlots.filter(n => !live.has(n) && n !== lastLayer);
    let pool = layersLive.length ? open.filter(n => !roles.has(layerInfo[n].role)) : open.filter(n => layerInfo[n].quantum <= 1);
    if (!pool.length) pool = open;
    return pool.length ? pool[Math.floor(nextRandom() * pool.length)] : null;
  }
  // undefined: no layer sprite decoded yet (use the single dive accent);
  // null: the stack is full; else the scheduled time.
  function diveLayer() {
    const key = `l${scene.level}-layers`, sprite = ready.get(key) || null;
    if (!sprite) { loadBuffer(key); return undefined; }
    const now = context.currentTime;
    for (const live of layersLive.splice(0)) if (live.end > now) layersLive.push(live);
    if (layersLive.length >= layerCap) return null;
    const name = pickLayer();
    if (!name) return null;
    const info = layerInfo[name], depth = layersLive.length;
    const at = gridTime(info.quantum, now), slot = layerSlots.indexOf(name), slotLength = layerSlotBeats * beatSeconds;
    const source = context.createBufferSource(), gain = context.createGain();
    source.buffer = sprite; gain.gain.value = fileGain * stackGain[depth];
    source.connect(gain); gain.connect(music);
    source.start(at, slot * slotLength, slotLength);
    source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch { /* detached */ } };
    lastLayer = name;
    layersLive.push({ name, at, end: at + info.beats * beatSeconds, depth });
    layerLog.push({ name, at, requestedAt: now, depth, level: scene.level });
    if (layerLog.length > 16) layerLog.shift();
    accentLog.push({ name: 'dive', layer: name, at, requestedAt: now, level: scene.level, source: 'layers' });
    if (accentLog.length > 16) accentLog.shift();
    return at;
  }
  // Power-up layer: what the game reports (active power count, a pickup in
  // the air); the scheduler applies it on the next bar line.
  function powerLayer(active = 0, falling = false) {
    power.active = Math.max(0, Math.round(Number(active) || 0));
    power.falling = !!falling;
    if (scene.level) loadBuffer(`l${scene.level}-power`);
    return { active: power.active, falling: power.falling };
  }
  function stopPower(at, seconds = beatSeconds) {
    const player = power.player;
    power.player = null;
    if (!player) return;
    player.gain.gain.cancelScheduledValues?.(at);
    player.gain.gain.setTargetAtTime(0, at, seconds / 3);
    try { player.source.stop(at + seconds + .05); } catch { /* not started */ }
  }
  // Runs on every bar line of the scheduler (at = that bar's time).
  function syncPower(at) {
    const tiers = scene.section === 'tiers' && active?.info.tier && active.info.level === scene.level;
    const want = tiers && levels.music !== 'mute' ? Math.min(2, power.active) : 0;
    const name = `l${scene.level}-power`, buffer = want ? ready.get(name) : null;
    if (power.player && (power.player.name !== name || !want)) stopPower(at);
    if (want && buffer && !power.player) {
      const source = context.createBufferSource(), gain = context.createGain();
      source.buffer = buffer; source.loop = true; source.loopStart = 0; source.loopEnd = Math.min(buffer.duration, 32 * beatSeconds);
      gain.gain.setValueAtTime(0, at); gain.gain.linearRampToValueAtTime(fileGain * powerGain[want], at + .03);
      source.connect(gain); gain.connect(drop);
      const offset = (beat % 32) * beatSeconds;  // the tiers' loop position
      source.start(at, offset);
      source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch { /* detached */ } };
      power.player = { name, source, gain, at, offset, level: want };
    } else if (want && power.player && power.player.level !== want) {
      power.player.level = want;
      power.player.gain.gain.setTargetAtTime(fileGain * powerGain[want], at, .05);
    }
    const brighten = tiers && power.falling;
    if (bright && brighten !== power.brightOn) bright.gain.setTargetAtTime(brighten ? brightDb : 0, at, .08);
    power.brightOn = brighten;
  }
  function dropMusic(at) {
    if (!drop) return;
    drop.gain.cancelScheduledValues(at);
    drop.gain.setTargetAtTime(dropLevel, at, .03);
    drop.gain.setTargetAtTime(1, at + dropBars * 4 * beatSeconds, .2);  // restores itself if no respawn comes
    dropState = { at, until: at + dropBars * 4 * beatSeconds };
  }
  function restoreMusic(at) {
    if (!drop) return;
    drop.gain.cancelScheduledValues(at);
    drop.gain.setTargetAtTime(1, at, .05);
    if (dropState) dropState.until = at;
  }
  let dropState = null;
  // Master: silent when muted, or when both music and speech are set to Mute.
  function masterLevel() { return muted || (levels.music === 'mute' && levels.speech === 'mute') ? 0 : masterGain; }
  function applyLevels() {
    if (!context) return;
    const now = context.currentTime;
    master.gain.setTargetAtTime(masterLevel(), now, .03);
    musicLevel.gain.setTargetAtTime(musicLevels[levels.music], now, .03);
  }
  function mute(value = true) { muted = !!value; applyLevels(); return muted; }
  // setLevel('music' | 'speech', 'mute' | 'low' | 'full'): applies and remembers
  // the choice (storage may be unavailable; the choice then lasts the session).
  function setLevel(channel, value) {
    if (!(channel in levels) || !levelNames.includes(value)) return null;
    levels[channel] = value;
    const stored = writeLevel(channel, value);
    applyLevels();
    if (channel === 'speech') window.commsAudio?.setLevel?.(value);
    return { ...levels, stored };
  }
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
    if (sidechainTags.includes(tag) && sidechain?.gain.setTargetAtTime) {
      // Sidechain: the music bows briefly under explosions and hits.
      sidechain.gain.cancelScheduledValues(now);
      sidechain.gain.setTargetAtTime(sidechainDip, now, .01);
      sidechain.gain.setTargetAtTime(1, now + .08, .06);
    }
    voice({ pitch, velocity, channel: name==='explosion' ? 9 : 0, tag }, now, duration, effects);
    if (name === 'explosion') noiseBurst(now, .32, .12, 2400);
    else if (name === 'life') noiseBurst(now, .45, .08, 900);
  }
  document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
  window.demonAudio = Object.freeze({ unlock, cue, intensity, accent, fleetIntact, mute, pause, resume, sfx, setLevel, powerLayer, get muted() { return muted; },
    get levels() { return { ...levels }; },
    get graph() { return { context, master, music, effects }; }, // shared with comms-audio.js
    // Read-only diagnostics for browser checks.
    get state() { return { context: context?.state ?? 'none', time: context?.currentTime ?? 0, nextBeat, beat, active: active?.name ?? null, pending: pending?.name ?? null, source: active ? (active.buffer ? 'file' : 'midi') : null, startedAt: active?.player?.startedAt ?? null, offset: active?.player?.offset ?? null, duration: active?.buffer?.duration ?? null, loopStart: active?.loopStart ?? null, loopEnd: active?.loopEnd ?? null, paused, muted, voices: voices.size, sounding: [...voices].filter(v => !v.released).length, decoded: [...bufferCache.keys()], formats, scene: { ...scene }, accents: accentLog.slice(), fleetIntact: fleetIntactFlag,
      bpm: 60 / beatSeconds, beatSeconds, drop: dropState ? { ...dropState } : null,
      levels: { ...levels }, masterGain: master?.gain.value ?? null, musicLevel: musicLevel?.gain.value ?? null, limiter: !!limiter,
      layers: layersLive.filter(l => l.end > (context?.currentTime ?? 0)).map(l => ({ ...l })), layerLog: layerLog.slice(),
      power: { active: power.active, falling: power.falling, playing: power.player ? { ...power.player, source: undefined, gain: undefined } : null, bright: power.brightOn } }; } });
  // Unlock from real DOM gestures, including Flutter canvas input.
  for (const type of ['pointerdown','keydown']) window.addEventListener(type, unlock, { once: true, capture: true });
  cue('menu');
})();
