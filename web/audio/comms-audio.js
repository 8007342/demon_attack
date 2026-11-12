/* Squad comms voice playback: radio clips from web/audio/comms/ (built by
   tools/comms_pipeline.py). Shares demon-audio.js's AudioContext and master
   gain through window.demonAudio.graph, so master mute and pause (context
   suspend) apply to voices too. Ducks the music bus while a voice sounds and
   caps simultaneous voices (3; only an urgent line, priority >= 8, may cut
   one that is playing; anything else beyond the cap is dropped). Every call is a safe no-op before the first
   gesture has created the context.
   Speech level (audio round): the HUD's speech toggle (Mute / Low / Full,
   remembered by demon-audio.js) scales the voice bus; Mute stops voices and
   never ducks the music. setVolume (the squad-voice switch) multiplies with it. */
(() => {
  'use strict';
  const root = new URL('./audio/comms/', document.baseURI);
  const cap = 3;                 // voices sounding at once (a regroup chorus may overlap)
  const urgent = 8;              // only this priority may cut a playing voice
  const duckGain = .4;           // music bus level under speech
  const duckAttack = .06;        // setTargetAtTime constants (s)
  const duckRelease = .12;
  const releaseDelay = .3;       // hold the duck this long after the last voice
  const voiceGain = 1.26;        // +2 dB: clips are mastered to -18 LUFS with codec headroom
  // Speech levels: Full is the round-3 voice level, Low 8 dB under it (a little
  // less than music's 10 dB, so low speech still clears the ducked music).
  const speechLevels = { mute: 0, low: 10 ** (-8 / 20), full: 1 };
  const bytesCache = new Map(), bufferCache = new Map();
  const live = [];               // { id, priority, demon, source, gain, startedAt, order }
  let bus, graphContext, volume = 1, played = 0, dropped = 0, maxConcurrent = 0, order = 0;
  let ducked = false, releaseTimer = null;
  let level = speechLevels[window.demonAudio?.levels?.speech] !== undefined ? window.demonAudio.levels.speech : 'full';
  const busGain = () => volume * speechLevels[level] * voiceGain;
  // Current-browser PWA delivery: one high-quality Opus bank.
  const formats = ['ogg'];

  function graph() {
    const g = window.demonAudio?.graph;
    if (!g?.context || !g.master) return null;
    if (graphContext !== g.context) {
      graphContext = g.context;
      bus = g.context.createGain();
      bus.gain.value = busGain();
      bus.connect(g.master);
      bufferCache.clear();
    }
    return g;
  }
  function fetchBytes(id, format) {
    const key = `${id}.${format}`;
    if (!bytesCache.has(key)) bytesCache.set(key, fetch(new URL(encodeURIComponent(id) + `.${format}`, root)).then(r => { if (!r.ok) throw new Error('clip unavailable'); return r.arrayBuffer(); }).catch(() => { bytesCache.delete(key); return null; }));
    return bytesCache.get(key);
  }
  function decode(context, bytes) {
    return new Promise((resolve, reject) => {
      try {
        const result = context.decodeAudioData(bytes.slice(0), resolve, reject);
        if (result?.then) result.then(resolve, reject);
      } catch (error) { reject(error); }
    });
  }
  function loadBuffer(id) {
    const g = graph();
    if (!g?.context?.decodeAudioData) return Promise.resolve(null);
    if (!bufferCache.has(id)) {
      bufferCache.set(id, (async () => {
        for (const format of formats) {
          const bytes = await fetchBytes(id, format);
          if (!bytes) continue;
          try { const buffer = await decode(g.context, bytes); if (buffer?.duration > 0) return buffer; } catch { /* next format */ }
        }
        return null;
      })().then(buffer => { if (!buffer) bufferCache.delete(id); return buffer; }));
    }
    return bufferCache.get(id);
  }
  // Compressed bytes may be fetched before the gesture; decoding waits for the context.
  function prefetch(ids) {
    for (const id of ids || []) {
      if (graph()) loadBuffer(id); else fetchBytes(id, formats[0]);
    }
  }

  function duck(on) {
    const g = graph();
    if (!g?.music) return;
    const now = g.context.currentTime;
    if (on) {
      if (releaseTimer) { clearTimeout(releaseTimer); releaseTimer = null; }
      if (!ducked) { ducked = true; g.music.gain.cancelScheduledValues?.(now); g.music.gain.setTargetAtTime(duckGain, now, duckAttack); }
    } else if (ducked && !releaseTimer) {
      releaseTimer = setTimeout(() => {
        releaseTimer = null;
        if (live.length) return;
        ducked = false;
        const t = g.context.currentTime;
        g.music.gain.cancelScheduledValues?.(t);
        g.music.gain.setTargetAtTime(1, t, duckRelease);
      }, releaseDelay * 1000);
    }
  }
  function remove(entry) {
    const index = live.indexOf(entry);
    if (index >= 0) live.splice(index, 1);
    if (!live.length) duck(false);
  }
  function release(entry, seconds = .04) {
    const g = graph();
    remove(entry);
    if (!g) return;
    const now = g.context.currentTime;
    try {
      entry.gain.gain.cancelScheduledValues?.(now);
      entry.gain.gain.setTargetAtTime(0, now, seconds / 3);
      entry.source.stop(now + seconds);
    } catch { /* already stopped */ }
  }
  // Returns true when the clip was accepted (it then starts as soon as it is decoded).
  function play(id, priority = 0, demon = false) {
    const g = graph();
    if (!g || volume <= 0 || level === 'mute' || !id) return false;
    if (live.some(v => v.id === id)) return false;
    if (live.length >= cap) {
      // A playing voice is never cut, except by an urgent (priority >= 8)
      // warning: that steals the lowest-priority (then oldest) voice it outranks or equals.
      const victim = [...live].sort((a, b) => a.priority - b.priority || a.order - b.order)[0];
      if (priority < urgent || victim.priority > priority) { dropped++; return false; }
      release(victim);
    }
    const entry = { id, priority, demon: !!demon, order: ++order, source: null, gain: null, startedAt: null, cancelled: false };
    entry.gain = g.context.createGain();
    entry.gain.gain.value = 1;
    entry.gain.connect(bus);
    live.push(entry);
    maxConcurrent = Math.max(maxConcurrent, live.length);
    duck(true);
    loadBuffer(id).then(buffer => {
      if (!live.includes(entry)) return;
      if (!buffer) { remove(entry); return; }
      const source = g.context.createBufferSource();
      source.buffer = buffer;
      source.connect(entry.gain);
      entry.source = source;
      entry.startedAt = g.context.currentTime;
      source.onended = () => { remove(entry); try { source.disconnect(); entry.gain.disconnect(); } catch { /* detached */ } };
      source.start(g.context.currentTime + .005);
      played++;
    });
    return true;
  }
  function stop(id) { for (const entry of [...live]) if (entry.id === id) release(entry); }
  function stopAll() { for (const entry of [...live]) release(entry); }
  function setVolume(value) {
    volume = Math.min(1, Math.max(0, Number(value) || 0));
    const g = graph();
    if (bus && g) bus.gain.setTargetAtTime(busGain(), g.context.currentTime, .03);
    if (volume <= 0) stopAll();
    return volume;
  }
  // 'mute' | 'low' | 'full' (demonAudio.setLevel('speech', ...) forwards here).
  function setLevel(value) {
    if (speechLevels[value] === undefined) return level;
    level = value;
    const g = graph();
    if (bus && g) bus.gain.setTargetAtTime(busGain(), g.context.currentTime, .03);
    if (level === 'mute') stopAll();  // releases the duck too
    return level;
  }

  window.commsAudio = Object.freeze({ prefetch, play, stop, stopAll, setVolume, setLevel,
    // Read-only diagnostics for browser checks.
    get state() {
      const g = window.demonAudio?.graph;
      return { context: g?.context?.state ?? 'none', voices: live.map(v => ({ id: v.id, priority: v.priority, demon: v.demon, started: v.startedAt !== null })),
        ducked, duckGain, musicGain: g?.music?.gain?.value ?? null, volume, level, busGain: bus?.gain?.value ?? null, loaded: [...bufferCache.keys()], played, dropped, maxConcurrent, cap, formats };
    } });
})();
