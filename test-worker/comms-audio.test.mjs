import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

async function harness() {
  let ctx;
  const timers = [], sources = [], fetched = [];
  const parameter = (value = 1) => ({ value, targets: [], cancelScheduledValues() {}, setValueAtTime(v) { this.value = v; }, linearRampToValueAtTime(v) { this.value = v; }, exponentialRampToValueAtTime() {}, setTargetAtTime(v, at, k) { this.value = v; this.targets.push([v, at, k]); } });
  class AudioContext {
    constructor() { ctx = this; this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; this.destination = {}; }
    createGain() { return { gain: parameter(), connect(to) { this.to = to; }, disconnect() {} }; }
    createOscillator() { return { frequency: parameter(), connect() {}, disconnect() {}, start() {}, stop() {} }; }
    createBufferSource() { const s = { connect(to) { s.to = to; }, disconnect() {}, start(at) { s.at = at; sources.push(s); }, stop(at) { s.stoppedAt = at; } }; return s; }
    decodeAudioData(bytes) { return Promise.resolve({ duration: 1.5, name: new TextDecoder().decode(new Uint8Array(bytes)) }); }
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
  return { sandbox, window, get ctx() { return ctx; }, sources, fetched, timers, settle, flushTimers };
}

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

test('at most two voices: a higher or equal priority steals the lowest, a lower one is dropped', async () => {
  const h = await harness();
  const comms = h.window.commsAudio, audio = h.window.demonAudio;
  await audio.unlock();
  assert.equal(comms.play('chatter', 2, false), true);
  assert.equal(comms.play('grunt', 4, true), true);
  assert.equal(comms.play('weapon', 1, false), false, 'lower priority than everything live: dropped');
  assert.equal(comms.state.dropped, 1);
  assert.equal(comms.play('dive', 9, false), true, 'critical warning steals the lowest-priority voice');
  for (let i = 0; i < 5; i++) await h.settle();
  const ids = [...comms.state.voices.map(v => v.id)].sort();
  assert.deepEqual(ids, ['dive', 'grunt']);
  assert.equal(comms.state.maxConcurrent, 2, 'never more than the cap');
  assert.equal(h.sources.some(s => s.buffer?.name === 'chatter'), false, 'stolen clip never starts');
  assert.equal(comms.play('second', 4, false), true, 'equal priority steals the oldest of the lowest');
  assert.deepEqual([...comms.state.voices.map(v => v.id)].sort(), ['dive', 'second']);
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

test('every bank clip ships Opus and AAC inside a modest budget', async () => {
  let manifest;
  try { manifest = JSON.parse(await readFile(new URL('../web/audio/comms/manifest.json', import.meta.url), 'utf8')); } catch { return; }
  const clips = Object.entries(manifest.clips);
  assert.ok(clips.length > 100);
  for (const [id, clip] of clips) {
    for (const ext of ['ogg', 'm4a']) {
      const info = await stat(new URL(`../web/audio/comms/${id}.${ext}`, import.meta.url));
      assert.equal(info.size, clip[`${ext}_bytes`], `${id}.${ext} size matches the manifest`);
    }
    assert.ok(clip.duration > .4 && clip.duration < 8, `${id} duration`);
    assert.match(clip.mouth, /^[0-7]+$/);
  }
  assert.ok(manifest.totals.ogg_bytes < 2.5e6, 'Opus budget');
  assert.ok(manifest.totals.m4a_bytes < 4e6, 'AAC budget');
});
