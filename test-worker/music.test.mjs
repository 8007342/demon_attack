import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

test('recorded cues start on bar boundaries, loop exactly, fall back to MIDI and keep the grid through pause', async () => {
  let callback, ctx;
  const fetched = [], sources = [], voices = [];
  const seconds = { 'menu': 16, 'level-1': 16, 'level-2': 16, 'boss-1-0': 16, 'levelclear': 6, 'victory': 6, 'gameover': 4.6, 'travel': 8 };
  const parameter = () => ({ value: 1, cancelScheduledValues() {}, setValueAtTime() {}, linearRampToValueAtTime(v) { this.value = v; }, exponentialRampToValueAtTime() {}, setTargetAtTime(value) { this.value = value; } });
  class AudioContext {
    constructor() { ctx = this; this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; }
    createGain() { return { gain: parameter(), connect() {}, disconnect() {} }; }
    createOscillator() { return { frequency: parameter(), connect() {}, disconnect() {}, start() { voices.push(this); }, stop() {} }; }
    createBufferSource() { const s = { connect() {}, disconnect() {}, start(at, offset) { s.at = at; s.offset = offset; sources.push(s); }, stop(at) { s.stoppedAt = at; } }; return s; }
    decodeAudioData(bytes) { const name = new TextDecoder().decode(new Uint8Array(bytes)); return Promise.resolve({ duration: seconds[name], name }); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  const missing = new Set(['boss-1-0']);
  const sandbox = { URL, Uint8Array, DataView, Map, Set, Math, Object, Promise, TextDecoder, window: { AudioContext, addEventListener() {} }, document: { baseURI: 'https://game.test/', addEventListener() {} }, setInterval(fn) { callback = fn; },
    async fetch(url) {
      fetched.push(url.pathname);
      const music = url.pathname.match(/^\/audio\/music\/(.+)\.(ogg|m4a)$/);
      if (music) {
        if (missing.has(music[1])) return { ok: false };
        const bytes = new TextEncoder().encode(music[1]);
        return { ok: true, async arrayBuffer() { return bytes.buffer; } };
      }
      const bytes = await readFile(new URL(`../web${url.pathname}`, import.meta.url));
      return { ok: true, async arrayBuffer() { return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength); } };
    } };
  vm.runInNewContext(await readFile(new URL('../web/audio/demon-audio.js', import.meta.url), 'utf8'), sandbox);
  const audio = sandbox.window.demonAudio;
  const step = (n) => { for (let i = 0; i < n; i++) { ctx.currentTime += .25; callback(); } };
  await audio.cue('menu');
  assert.ok(fetched.some(p => p.startsWith('/audio/music/menu.')), 'menu bytes fetched before the gesture');
  assert.equal(sources.length, 0, 'silent until the first gesture');
  assert.equal(await audio.unlock(), true);
  assert.equal(sources.length, 1); assert.equal(sources[0].buffer.name, 'menu');
  assert.equal(sources[0].loop, true); assert.equal(sources[0].loopStart, 0); assert.equal(sources[0].loopEnd, 16);
  assert.equal(audio.state.source, 'file');
  const grid = sources[0].at;
  step(3);
  await audio.cue('level', 2);
  assert.equal(audio.state.pending, 'level-2', 'level change waits for the next bar');
  step(12);
  const level = sources.at(-1);
  assert.equal(level.buffer.name, 'level-2');
  const bars = (level.at - grid) / 2;
  assert.ok(Math.abs(bars - Math.round(bars)) < 1e-9 && bars >= 1, 'new cue starts on the shared bar grid');
  assert.ok(sources[0].stoppedAt >= level.at && sources[0].stoppedAt < level.at + .2, 'old cue releases across the bar line');
  // Stale loads: only the latest request wins.
  await Promise.all([audio.cue('level', 1), audio.cue('travel')]);
  assert.equal(audio.state.pending, 'travel');
  step(10);
  assert.equal(audio.state.active, 'travel'); assert.equal(sources.at(-1).loopEnd, 8);
  // Pause/resume keeps phase.
  const before = audio.state.nextBeat; audio.pause(); assert.equal(ctx.state, 'suspended');
  await audio.resume(); assert.equal(audio.state.nextBeat, before, 'resume keeps the bar grid');
  // Level clear is immediate with a short crossfade.
  const now = ctx.currentTime; await audio.cue('levelclear');
  const clear = sources.at(-1);
  assert.equal(clear.buffer.name, 'levelclear');
  assert.ok(clear.at <= now + .03, 'level clear starts immediately');
  assert.ok(sources.at(-2).stoppedAt <= now + .11, 'previous cue fades within ~90 ms');
  assert.equal(clear.loop, true); assert.equal(clear.loopStart, 4); assert.equal(clear.loopEnd, 6);
  step(8);
  // A missing file falls back to the MIDI synthesizer.
  await audio.cue('boss', 1, 1, 0); step(12);
  assert.equal(audio.state.active, 'boss-1-0'); assert.equal(audio.state.source, 'midi');
  const midiVoices = voices.length; step(4); assert.ok(voices.length > midiVoices, 'fallback MIDI notes play');
  await audio.cue('gameover'); step(12);
  assert.equal(sources.at(-1).buffer.name, 'gameover'); assert.equal(sources.at(-1).loop, false, 'game over ends');
  audio.mute(true); assert.equal(audio.muted, true);
});

test('every cue ships Opus and AAC files that are exact bar multiples', async () => {
  const manifest = JSON.parse(await readFile(new URL('../web/audio/music/manifest.json', import.meta.url), 'utf8'));
  const names = ['menu', 'level-1', 'level-2', 'level-3', 'level-4', 'travel', 'victory', 'levelclear', 'gameover'];
  for (let phase = 1; phase <= 4; phase++) names.push(`boss-${phase}-0`, `boss-${phase}-1`);
  let total = 0;
  for (const name of names) {
    const cue = manifest.cues[name];
    assert.ok(cue, `${name} is in the manifest`);
    for (const format of ['ogg', 'm4a']) total += format === 'ogg' ? (await stat(new URL(`../web/audio/music/${name}.${format}`, import.meta.url))).size : 0;
    if (cue.loopEnd !== null) assert.equal(((cue.loopEnd - cue.loopStart) * 2) % 4, 0, `${name} loop is whole bars`);
    if (cue.kind === 'loop') assert.equal(cue.seconds, cue.beats / 2, `${name} loop length`);
  }
  assert.ok(total < 4 * 1024 * 1024, `Opus set stays modest (${total} bytes)`);
});
