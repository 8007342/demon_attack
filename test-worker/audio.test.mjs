import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

test('MIDI fallback: unlocks on gesture, plays every level part from the motif scores, honors mute/pause', async () => {
  let callback, synthesizer;
  const fetched = [];
  const voices = [];
  const parameter = () => ({ value: 0, cancelScheduledValues() {}, setValueAtTime() {}, linearRampToValueAtTime() {}, exponentialRampToValueAtTime() {}, setTargetAtTime(value) { this.value = value; } });
  class AudioContext {
    constructor() { synthesizer = this; this.currentTime = 0; this.state = 'suspended'; }
    createGain() { return { gain: parameter(), connect() {}, disconnect() {} }; }
    createOscillator() { const osc = { frequency: parameter(), connect() {}, disconnect() {}, start(at) { assert.ok(Number.isFinite(at)); voices.push(this); }, stop() {} }; return osc; }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  // No decodeAudioData: recorded cues are unavailable, so every cue uses MIDI.
  const sandbox = { URL, Uint8Array, DataView, Map, Set, Math, Object, Promise, window: { AudioContext, addEventListener() {} }, document: { baseURI: 'https://game.test/', addEventListener() {} }, setInterval(fn) { callback = fn; }, async fetch(url) { fetched.push(url.pathname); const bytes = await readFile(new URL(`../web${url.pathname}`, import.meta.url)); return { ok: true, async arrayBuffer() { return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset+bytes.byteLength); } }; } };
  vm.runInNewContext(await readFile(new URL('../web/audio/demon-audio.js', import.meta.url), 'utf8'), sandbox);
  const audio = sandbox.window.demonAudio;
  const run = async (beats) => { for (let step = 0; step < beats; step++) { synthesizer.currentTime += .5; callback(); await new Promise(resolve => setTimeout(resolve, 1)); } };
  await audio.cue('level', 1);
  assert.equal(await audio.unlock(), true);
  assert.ok(fetched.includes('/audio/midi/l1-intro.mid'));
  assert.ok(voices.length > 0, 'actual MIDI note events reach synthesizer');
  for (const tier of [1, 2, 3, 4]) {
    await audio.intensity(tier); await run(20);
    assert.ok(fetched.includes(`/audio/midi/l1-t${tier}.mid`), `tier ${tier} score`);
    assert.equal(audio.state.active, `l1-t${tier}`);
  }
  const t1 = await readFile(new URL('../web/audio/midi/l3-t1.mid', import.meta.url));
  const t4 = await readFile(new URL('../web/audio/midi/l3-t4.mid', import.meta.url));
  assert.ok(t4.length > t1.length * 1.3, 'the peril tier has substantially denser note events');
  await audio.cue('boss', 5, 1, 0); await run(8);
  assert.ok(fetched.includes('/audio/midi/l5-intro.mid'), 'the carrier has its own intro');
  await audio.intensity(4); await run(20);
  assert.ok(fetched.includes('/audio/midi/l5-t4.mid'), 'final carrier form');
  audio.mute(true); assert.equal(audio.muted, true);
  audio.pause(); assert.equal(synthesizer.state, 'suspended');
  const count = voices.length; callback(); audio.sfx('shot'); assert.equal(voices.length, count);
  await audio.resume(); audio.sfx('explosion'); assert.ok(voices.length > count);
  await audio.cue('victory', 5, 1, 0);
  assert.ok(fetched.includes('/audio/midi/victory.mid'));
  await run(24);
  const afterOpening = voices.length;
  await run(8);
  assert.ok(voices.length > afterOpening, 'victory cadence continues after its opening while awaiting the next scene');
  await audio.cue('travel', 5); await run(8);
  assert.ok(fetched.includes('/audio/midi/l5-outro.mid'), 'travel after the carrier plays its outro');
  await audio.cue('level', 2); await run(8);
  assert.ok(fetched.includes('/audio/midi/l2-intro.mid'), 'next level replaces travel on the shared bar grid');
  const beforeClear = voices.length;
  await audio.cue('levelclear');
  assert.ok(fetched.includes('/audio/midi/levelclear.mid'));
  assert.ok(voices.length > beforeClear, 'level-clear notes begin immediately, without waiting for the next bar');
  await run(12);
  const clearTail = voices.length;
  await run(8);
  assert.ok(voices.length > clearTail, 'clear cadence fills delayed cutscene handoff');
  const beforeWave = voices.length; audio.sfx('wave');
  assert.equal(voices.length, beforeWave + 3, 'new-wave ascending stinger layers over music');
  const beforeAccent = voices.length;
  await audio.cue('level', 3); await run(4);
  assert.notEqual(await audio.accent('dive'), null);
  assert.ok(voices.length >= beforeAccent + 3, 'without a sprite the accent falls back to synthesized notes');
  await audio.cue('gameover'); await run(12);
  assert.ok(fetched.includes('/audio/midi/cackle.mid') && fetched.includes('/audio/midi/alienwin.mid'), 'game over: cackle, then the alien victory theme');
  assert.equal(audio.state.active, 'alienwin');
});
