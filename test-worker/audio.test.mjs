import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

test('MIDI player unlocks on gesture, schedules notes, switches cues and honors mute/pause', async () => {
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
  const sandbox = { URL, Uint8Array, DataView, Map, Set, Math, Object, window: { AudioContext, addEventListener() {} }, document: { baseURI: 'https://game.test/', addEventListener() {} }, setInterval(fn) { callback = fn; }, async fetch(url) { fetched.push(url.pathname); const bytes = await readFile(new URL(`../web${url.pathname}`, import.meta.url)); return { ok: true, async arrayBuffer() { return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset+bytes.byteLength); } }; } };
  vm.runInNewContext(await readFile(new URL('../web/audio/demon-audio.js', import.meta.url), 'utf8'), sandbox);
  const audio = sandbox.window.demonAudio;
  await audio.cue('level', 1);
  assert.equal(await audio.unlock(), true);
  assert.ok(voices.length > 0, 'actual MIDI note events reach synthesizer');
  await audio.cue('boss', 1, 3, 1);
  for (let step=0; step<12; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(fetched.includes('/audio/midi/boss-3-1.mid'));
  await audio.cue('boss', 1, 4, 0);
  for (let step=0; step<8; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(fetched.includes('/audio/midi/boss-4-0.mid'), 'fourth visual form has its own MIDI cue');
  await audio.cue('boss', 1, 4, 1);
  for (let step=0; step<8; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(fetched.includes('/audio/midi/boss-4-1.mid'), 'evolved fourth form has its own cue');
  const phase3 = await readFile(new URL('../web/audio/midi/boss-3-1.mid', import.meta.url));
  const phase4 = await readFile(new URL('../web/audio/midi/boss-4-1.mid', import.meta.url));
  assert.ok(phase4.length > phase3.length * 1.3, 'final form has substantially denser note events');
  audio.mute(true); assert.equal(audio.muted, true);
  audio.pause(); assert.equal(synthesizer.state, 'suspended');
  const count = voices.length; callback(); audio.sfx('shot'); assert.equal(voices.length, count);
  await audio.resume(); audio.sfx('explosion'); assert.ok(voices.length > count);
  await audio.cue('victory');
  assert.ok(fetched.includes('/audio/midi/victory.mid'));
  for (let step=0; step<24; step++) { synthesizer.currentTime += .5; callback(); }
  const afterOpening = voices.length;
  for (let step=0; step<8; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(voices.length > afterOpening, 'victory cadence continues after its opening while awaiting the next scene');
  await audio.cue('level', 2);
  for (let step=0; step<8; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(fetched.includes('/audio/midi/level-2.mid'), 'next level replaces victory on the shared bar grid');
  const beforeClear = voices.length;
  await audio.cue('levelclear');
  assert.ok(fetched.includes('/audio/midi/levelclear.mid'));
  assert.ok(voices.length > beforeClear, 'level-clear notes begin immediately, without waiting for the next bar');
  for (let step=0; step<12; step++) { synthesizer.currentTime += .5; callback(); }
  const clearTail = voices.length;
  for (let step=0; step<8; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(voices.length > clearTail, 'clear cadence fills delayed cutscene handoff');
  await audio.cue('travel');
  const beforeTravel = voices.length;
  for (let step=0; step<12; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(fetched.includes('/audio/midi/travel.mid'));
  assert.ok(voices.length > beforeTravel, 'travel interlude produces notes through cutscene');
  const beforeWave = voices.length; audio.sfx('wave');
  assert.equal(voices.length, beforeWave + 3, 'new-wave ascending stinger layers over music');
  await audio.cue('level', 3);
  const beforeLevel = voices.length;
  for (let step=0; step<8; step++) { synthesizer.currentTime += .5; callback(); }
  assert.ok(fetched.includes('/audio/midi/level-3.mid'));
  assert.ok(voices.length > beforeLevel, 'travel returns to next level without silent state');
});
