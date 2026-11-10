// Audio round: the HUD's Music and Speech toggles (Mute / Low / Full),
// their gains, per-device persistence and the storage fallback.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const dB = value => 10 ** (value / 20);
const close = (a, b) => Math.abs(a - b) < 1e-9;

function memoryStorage(initial = {}) {
  const values = { ...initial };
  return { values, getItem: key => (key in values ? values[key] : null), setItem: (key, value) => { values[key] = String(value); } };
}
const brokenStorage = { getItem() { throw new Error('SecurityError'); }, setItem() { throw new Error('QuotaExceededError'); } };

async function harness({ storage, storageThrows = false, compressor = true } = {}) {
  let ctx;
  const sources = [];
  const parameter = (value = 1) => ({ value, cancelScheduledValues() {}, setValueAtTime(v) { this.value = v; }, linearRampToValueAtTime(v) { this.value = v; }, exponentialRampToValueAtTime() {}, setTargetAtTime(v) { this.value = v; } });
  const node = extra => ({ connect(to) { this.to = to; return to; }, disconnect() {}, ...extra });
  class AudioContext {
    constructor() { ctx = this; this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; this.destination = { name: 'destination' }; }
    createGain() { const n = node({ gain: parameter() }); n.connect = function (to) { this.to = to; }; return n; }
    createOscillator() { return { frequency: parameter(), connect() {}, disconnect() {}, start() {}, stop() {} }; }
    createBiquadFilter() { const n = { type: '', frequency: parameter(), gain: parameter(0), connect(to) { this.to = to; }, disconnect() {} }; return n; }
    createBufferSource() { const s = { connect(to) { s.to = to; }, disconnect() {}, start(at) { s.at = at; sources.push(s); }, stop() {} }; return s; }
    decodeAudioData(bytes) { return Promise.resolve({ duration: 1.5, name: new TextDecoder().decode(new Uint8Array(bytes)) }); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  if (compressor) AudioContext.prototype.createDynamicsCompressor = function () {
    return { threshold: parameter(0), knee: parameter(0), ratio: parameter(1), attack: parameter(0), release: parameter(0), connect(to) { this.to = to; }, disconnect() {} };
  };
  const window = { AudioContext, addEventListener() {} };
  if (storageThrows) Object.defineProperty(window, 'localStorage', { get() { throw new Error('SecurityError'); } });
  else if (storage) window.localStorage = storage;
  const sandbox = { URL, Uint8Array, DataView, Map, Set, Math, Object, Promise, Number, TextDecoder, encodeURIComponent, window, document: { baseURI: 'https://game.test/', addEventListener() {} },
    setInterval() {}, setTimeout() { return {}; }, clearTimeout() {},
    async fetch(url) {
      const clip = url.pathname.match(/^\/audio\/comms\/(.+)\.(ogg|m4a)$/);
      if (clip) { const bytes = new TextEncoder().encode(decodeURIComponent(clip[1])); return { ok: true, async arrayBuffer() { return bytes.buffer; } }; }
      return { ok: false };
    } };
  vm.createContext(sandbox);
  for (const file of ['demon-audio.js', 'comms-audio.js']) vm.runInContext(await readFile(new URL(`../web/audio/${file}`, import.meta.url), 'utf8'), sandbox);
  const settle = () => new Promise(resolve => setImmediate(resolve));
  return { window, audio: window.demonAudio, comms: window.commsAudio, get ctx() { return ctx; }, sources, settle };
}

test('both channels start at Full; Full music is 6 dB louder than the previous mix, Low 10 dB under Full', async () => {
  const h = await harness();
  assert.deepEqual({ ...h.audio.levels }, { music: 'full', speech: 'full' });
  await h.audio.unlock();
  const { master, music } = h.audio.graph;
  assert.ok(close(h.audio.state.musicLevel, dB(6)), 'Full: +6 dB over the round-3 music level');
  assert.equal(h.audio.state.masterGain, .65, 'effects keep their level');
  assert.equal(h.audio.setLevel('music', 'low').music, 'low');
  assert.ok(close(h.audio.state.musicLevel, dB(-4)), 'Low: 10 dB under Full');
  h.audio.setLevel('music', 'mute');
  assert.equal(h.audio.state.musicLevel, 0);
  assert.equal(h.audio.state.masterGain, .65, 'muting music alone keeps effects and speech');
  assert.equal(music.gain.value, 1, 'the comms duck bus is separate from the music level');
  // Full music runs into a safety limiter on the master.
  assert.equal(h.audio.state.limiter, true);
  assert.equal(master.to.threshold.value, -1.5);
  assert.equal(master.to.to, h.ctx.destination);
  assert.equal(h.audio.setLevel('music', 'loud'), null, 'unknown levels are ignored');
  assert.equal(h.audio.setLevel('drums', 'low'), null, 'unknown channels are ignored');
});

test('without a compressor node the master connects straight to the output', async () => {
  const h = await harness({ compressor: false });
  await h.audio.unlock();
  assert.equal(h.audio.state.limiter, false);
  assert.equal(h.audio.graph.master.to, h.ctx.destination);
});

test('muting both music and speech mutes everything (the old master mute); master mute still works', async () => {
  const h = await harness();
  await h.audio.unlock();
  h.audio.setLevel('music', 'mute');
  h.audio.setLevel('speech', 'mute');
  assert.equal(h.audio.state.masterGain, 0, 'effects too');
  h.audio.setLevel('speech', 'low');
  assert.equal(h.audio.state.masterGain, .65);
  h.audio.mute(true);
  assert.equal(h.audio.state.masterGain, 0);
  assert.equal(h.audio.muted, true);
  h.audio.mute(false);
  assert.equal(h.audio.state.masterGain, .65);
});

test('choices are remembered per device and read back before the first sound', async () => {
  const storage = memoryStorage();
  const h = await harness({ storage });
  assert.equal(h.audio.setLevel('music', 'low').stored, true);
  h.audio.setLevel('speech', 'mute');
  assert.deepEqual(storage.values, { 'demonAttack.musicVolume': 'low', 'demonAttack.speechVolume': 'mute' });
  const again = await harness({ storage });
  assert.deepEqual({ ...again.audio.levels }, { music: 'low', speech: 'mute' });
  assert.equal(again.comms.state.level, 'mute', 'comms starts at the remembered speech level');
  await again.audio.unlock();
  assert.ok(close(again.audio.state.musicLevel, dB(-4)), 'the first music plays at the remembered level');
  const junk = await harness({ storage: memoryStorage({ 'demonAttack.musicVolume': 'eleven' }) });
  assert.equal(junk.audio.levels.music, 'full', 'unknown stored values fall back to Full');
});

test('unavailable or failing storage falls back to Full and still applies the choice for the session', async () => {
  for (const options of [{ storageThrows: true }, { storage: brokenStorage }, {}]) {
    const h = await harness(options);
    assert.deepEqual({ ...h.audio.levels }, { music: 'full', speech: 'full' });
    await h.audio.unlock();
    const result = h.audio.setLevel('music', 'low');
    assert.equal(result.music, 'low');
    assert.equal(result.stored, false);
    assert.ok(close(h.audio.state.musicLevel, dB(-4)));
  }
});

test('speech levels scale the voice bus; Low still ducks the music, Mute plays nothing and never ducks', async () => {
  const h = await harness();
  await h.audio.unlock();
  const music = h.audio.graph.music;
  h.comms.play('a', 5, false);
  for (let i = 0; i < 5; i++) await h.settle();
  const bus = h.sources.find(s => s.buffer?.name === 'a').to.to;
  assert.ok(close(bus.gain.value, 1.26), 'Full: the round-3 voice level');
  h.audio.setLevel('speech', 'low');
  assert.equal(h.comms.state.level, 'low', 'demonAudio forwards the speech level');
  assert.ok(close(bus.gain.value, 1.26 * dB(-8)), 'Low: 8 dB under Full');
  assert.equal(music.gain.value, .4, 'low speech still ducks the music');
  h.audio.setLevel('speech', 'mute');
  assert.equal(h.comms.state.voices.length, 0, 'muting speech stops live voices');
  assert.equal(h.comms.play('b', 9, false), false, 'muted speech plays nothing');
  assert.equal(h.comms.state.ducked, true, 'the duck releases after the last voice');
  // The duck release runs on a timer; nothing new ducks while muted.
  music.gain.value = 1;
  h.comms.play('c', 5, false);
  assert.equal(music.gain.value, 1, 'no ducking while speech is muted');
  // The squad-voice switch (setVolume) multiplies with the level.
  h.audio.setLevel('speech', 'full');
  h.comms.setVolume(0);
  assert.equal(h.comms.play('d', 5, false), false);
  h.comms.setVolume(1);
  assert.equal(h.comms.play('d', 5, false), true);
});
