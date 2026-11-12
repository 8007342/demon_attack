import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

async function harness() {
  let ctx;
  const timers = [], sources = [], fetched = [], decoded = [];
  const parameter = (value = 1) => ({ value, targets: [], cancelScheduledValues() {}, setValueAtTime(v) { this.value = v; }, linearRampToValueAtTime(v) { this.value = v; }, exponentialRampToValueAtTime() {}, setTargetAtTime(v, at, k) { this.value = v; this.targets.push([v, at, k]); } });
  class AudioContext {
    constructor() { ctx = this; this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; this.destination = {}; }
    createGain() { return { gain: parameter(), connect(to) { this.to = to; }, disconnect() {} }; }
    createOscillator() { return { frequency: parameter(), connect() {}, disconnect() {}, start() {}, stop() {} }; }
    createBufferSource() { const s = { connect(to) { s.to = to; }, disconnect() {}, start(at) { s.at = at; sources.push(s); }, stop(at) { s.stoppedAt = at; } }; return s; }
    decodeAudioData(bytes) { const name = new TextDecoder().decode(new Uint8Array(bytes)); decoded.push(name); return Promise.resolve({ duration: 1.5, length: 72000, sampleRate: 48000, numberOfChannels: 1, name }); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  const window = { AudioContext, addEventListener() {} };
  const sandbox = { URL, Uint8Array, DataView, Map, Set, Math, Object, Promise, Number, TextDecoder, encodeURIComponent, window, document: { baseURI: 'https://game.test/', addEventListener() {} },
    setInterval() {}, setTimeout(fn, ms) { const t = { fn, ms }; timers.push(t); return t; }, clearTimeout(t) { const i = timers.indexOf(t); if (i >= 0) timers.splice(i, 1); },
    async fetch(url) {
      fetched.push(url.pathname);
      const clip = url.pathname.match(/^\/audio\/comms\/(.+)\.(ogg|m4a)$/);
      if (clip) { if (clip[1] === 'missing') return { ok: false }; const bytes = new TextEncoder().encode(decodeURIComponent(clip[1])); return { ok: true, async arrayBuffer() { return bytes.buffer; } }; }
      return { ok: false };
    } };
  vm.createContext(sandbox);
  for (const file of ['demon-audio.js', 'comms-audio.js']) vm.runInContext(await readFile(new URL(`../web/audio/${file}`, import.meta.url), 'utf8'), sandbox);
  const settle = () => new Promise(resolve => setImmediate(resolve));
  const flushTimers = () => { while (timers.length) timers.shift().fn(); };
  return { sandbox, window, get ctx() { return ctx; }, sources, fetched, decoded, timers, settle, flushTimers };
}

test('a full roster stays compressed; decoded speech is bounded without evicting a live conversation', async () => {
  const h = await harness();
  const comms = h.window.commsAudio;
  await h.window.demonAudio.unlock();
  comms.prefetch(Array.from({ length: 400 }, (_, i) => `roster-${i}`));
  await h.settle();
  assert.equal(h.decoded.filter(id => id.startsWith('roster-')).length, 0, 'sector prefetch never expands the bank into PCM');
  comms.play('anchor', 4);
  await h.settle();
  for (let i = 0; i < 80; i++) {
    const id = `line-${i}`;
    assert.equal(comms.play(id, 4), true);
    await h.settle();
    h.sources.find(s => s.buffer?.name === id).onended();
  }
  assert.ok(comms.state.decodedBytes <= comms.state.decodedLimit, 'PCM is bounded over a long campaign');
  assert.ok(comms.state.loaded.includes('anchor'), 'the opener still playing stays available');
  assert.ok(!comms.state.loaded.includes('line-0'), 'old finished speech is evicted');
  comms.play('line-0', 4);
  await h.settle();
  assert.equal(h.decoded.filter(id => id === 'line-0').length, 2, 'evicted speech can decode again from its compressed cache');
});

test('comms voices are silent before the gesture, then share the context and master', async () => {
  const h = await harness();
  const comms = h.window.commsAudio, audio = h.window.demonAudio;
  assert.equal(comms.play('reinforcements.h0', 6, false), false, 'no-op before the context exists');
  comms.prefetch(['reinforcements.h0']);
  await h.settle();
  assert.ok(h.fetched.some(p => p.startsWith('/audio/comms/reinforcements.h0.')), 'bytes may be fetched before the gesture');
  assert.equal(h.sources.length, 0);
  assert.equal(await audio.unlock(), true);
  assert.equal(comms.play('reinforcements.h0', 6, false), true);
  for (let i = 0; i < 5; i++) await h.settle();
  const clip = h.sources.find(s => s.buffer?.name === 'reinforcements.h0');
  assert.ok(clip, 'clip decoded and started');
  const voiceGain = clip.to, bus = voiceGain.to;
  assert.equal(bus.to, audio.graph.master, 'voice bus feeds the shared master (mute applies)');
  assert.equal(comms.state.context, 'running');
  assert.equal(comms.play('reinforcements.h0', 6, false), false, 'same clip does not double-play');
});

test('music ducks under speech and recovers after the last voice', async () => {
  const h = await harness();
  const comms = h.window.commsAudio, audio = h.window.demonAudio;
  await audio.unlock();
  const music = audio.graph.music;
  comms.play('a', 5, false);
  for (let i = 0; i < 5; i++) await h.settle();
  assert.equal(comms.state.ducked, true);
  assert.equal(music.gain.targets.at(-1)[0], comms.state.duckGain, 'music bus ramps down to the duck level');
  const source = h.sources.find(s => s.buffer?.name === 'a');
  source.onended();
  assert.equal(comms.state.voices.length, 0);
  assert.equal(comms.state.ducked, true, 'duck holds briefly after the last voice');
  h.flushTimers();
  assert.equal(comms.state.ducked, false);
  assert.equal(music.gain.targets.at(-1)[0], 1, 'music bus ramps back to unity');
  audio.mute(true);
  assert.equal(audio.graph.master.gain.value, 0, 'mute stays on master, untouched by ducking');
});

test('at most three voices: only an urgent line cuts a playing one, anything else beyond the cap is dropped', async () => {
  const h = await harness();
  const comms = h.window.commsAudio, audio = h.window.demonAudio;
  await audio.unlock();
  assert.equal(comms.state.cap, 3);
  assert.equal(comms.play('chatter', 2, false), true);
  assert.equal(comms.play('grunt', 4, true), true);
  assert.equal(comms.play('cheer', 5, true), true, 'a third voice overlaps (regroup chorus)');
  for (let i = 0; i < 5; i++) await h.settle();
  assert.equal(comms.play('weapon', 1, false), false, 'lower priority beyond the cap: dropped');
  assert.equal(comms.play('praise', 7, false), false, 'even a higher non-urgent priority never cuts a playing voice');
  assert.equal(comms.state.dropped, 2);
  assert.ok(h.sources.every(s => s.stoppedAt === undefined), 'nothing was cut');
  assert.equal(comms.play('dive', 9, false), true, 'urgent warning cuts the lowest-priority voice');
  for (let i = 0; i < 5; i++) await h.settle();
  assert.deepEqual([...comms.state.voices.map(v => v.id)].sort(), ['cheer', 'dive', 'grunt']);
  assert.ok(h.sources.find(s => s.buffer?.name === 'chatter').stoppedAt !== undefined, 'the cut voice is released');
  assert.equal(comms.state.maxConcurrent, 3, 'never more than the cap');
  assert.equal(comms.play('shield', 8, false), true, 'urgent again: cuts the oldest of the lowest');
  assert.deepEqual([...comms.state.voices.map(v => v.id)].sort(), ['cheer', 'dive', 'shield']);
  assert.equal(comms.play('mayday', 8, false), true);
  assert.equal(comms.play('boss', 8, false), true);
  assert.equal(comms.play('late', 8, false), true, 'urgent equal priority cuts the oldest urgent');
  assert.deepEqual([...comms.state.voices.map(v => v.id)].sort(), ['boss', 'dive', 'late'], 'urgent lines never cut a higher-priority one');
  assert.equal(comms.play('quiet', 9, false), true);
  assert.equal(comms.play('low', 7, false), false, 'all live voices urgent: non-urgent dropped');
  comms.stopAll();
  assert.equal(comms.state.voices.length, 0);
  comms.setVolume(0);
  assert.equal(comms.play('x', 9, false), false, 'voice volume 0 mutes comms');
  comms.setVolume(.5);
  assert.equal(comms.state.volume, .5);
  assert.equal(comms.play('missing', 3, false), true);
  for (let i = 0; i < 8; i++) await h.settle();
  assert.equal(comms.state.voices.length, 0, 'an unavailable clip frees its slot');
});

test('every bank clip ships Opus inside a modest budget; modern banks omit AAC', async () => {
  let manifest;
  try { manifest = JSON.parse(await readFile(new URL('../web/audio/comms/manifest.json', import.meta.url), 'utf8')); } catch { return; }
  const clips = Object.entries(manifest.clips);
  assert.ok(clips.length > 100);
  for (const [id, clip] of clips) {
    for (const ext of ['ogg']) {
      const info = await stat(new URL(`../web/audio/comms/${id}.${ext}`, import.meta.url));
      assert.equal(info.size, clip[`${ext}_bytes`], `${id}.${ext} size matches the manifest`);
    }
    assert.ok(clip.duration > .4 && clip.duration < 8, `${id} duration`);
    // Frames as 48 + CommsFrame index: 0-7 and the v4 talk wide (<) and ee (=).
    assert.match(clip.mouth, /^[0-7<=]+$/);
    assert.match(clip.vis, /^[-oe]+$/);
    assert.equal(clip.vis.length, clip.mouth.length);
  }
  const modern = manifest.schema === 'demon-attack.comms-bank/v2';
  assert.ok(manifest.totals.ogg_bytes < (modern ? 16e6 : 3.4e6), 'complete Opus bank stays within its delivery budget');
  if (manifest.schema === 'demon-attack.comms-bank/v2') {
    assert.equal(manifest.complete, true, 'a partial development bank must not ship');
    assert.deepEqual(manifest.formats, ['ogg']);
    const { readdir } = await import('node:fs/promises');
    const files = await readdir(new URL('../web/audio/comms/', import.meta.url));
    assert.ok(!files.some(name => name.endsWith('.m4a')), 'modern delivery removes duplicate legacy audio');
  }
});
