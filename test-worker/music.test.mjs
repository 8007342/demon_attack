import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

// Decoded durations of the instrumented cues (seconds), as the pipeline builds them.
function seconds(name) {
  if (/^l\d-t\d$/.test(name)) return 16;
  if (/-intro$/.test(name)) return 10;
  if (/-outro$/.test(name)) return 8;
  if (/-accents$/.test(name)) return 7.5;
  return { menu: 16, levelclear: 8, victory: 12, finale: 20, 'levelclear-fleet': 8, 'finale-fleet': 20, cackle: 4, alienwin: 16 }[name];
}

async function player({ missing = new Set() } = {}) {
  let callback, ctx;
  const fetched = [], sources = [], voices = [];
  const parameter = () => ({ value: 1, events: [], cancelScheduledValues() {}, setValueAtTime(v, t) { this.events.push(['set', v, t]); }, linearRampToValueAtTime(v, t) { this.value = v; this.events.push(['ramp', v, t]); }, exponentialRampToValueAtTime() {}, setTargetAtTime(value) { this.value = value; } });
  class AudioContext {
    constructor() { ctx = this; this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; }
    createGain() { return { gain: parameter(), connect() {}, disconnect() {} }; }
    createOscillator() { return { frequency: parameter(), connect() {}, disconnect() {}, start() { voices.push(this); }, stop() {} }; }
    createBufferSource() { const s = { connect() {}, disconnect() {}, start(at, offset, duration) { s.at = at; s.offset = offset; s.duration = duration; sources.push(s); }, stop(at) { s.stoppedAt = at; } }; return s; }
    decodeAudioData(bytes) { const name = new TextDecoder().decode(new Uint8Array(bytes)); return Promise.resolve({ duration: seconds(name), name }); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
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
  const settle = async () => { for (let i = 0; i < 40; i++) await Promise.resolve(); };
  const step = async (n) => { for (let i = 0; i < n; i++) { ctx.currentTime += .25; callback(); await settle(); } };
  return { audio, ctx: () => ctx, sources, voices, fetched, step, settle };
}

const onGrid = (t, origin, unit) => { const k = (t - origin) / unit; return Math.abs(k - Math.round(k)) < 1e-6; };
const last = (sources, name) => sources.filter(s => s.buffer?.name === name).at(-1);

test('levels play intro then tiers of one motif: tier changes land on bars and keep the loop position', async () => {
  const { audio, ctx, sources, fetched, step, settle } = await player();
  await audio.cue('menu');
  assert.ok(fetched.some(p => p.startsWith('/audio/music/menu.')), 'menu bytes fetched before the gesture');
  assert.equal(sources.length, 0, 'silent until the first gesture');
  assert.equal(await audio.unlock(), true);
  const grid = sources[0].at;
  assert.equal(sources[0].buffer.name, 'menu');
  await step(3);
  await audio.cue('level', 2);
  assert.equal(audio.state.pending, 'l2-intro', 'arrival waits for the next bar');
  assert.ok(['l2-t1', 'l2-t2', 'l2-t3', 'l2-t4', 'l2-outro', 'l2-accents'].every(n => fetched.includes(`/audio/music/${n}.${audio.state.formats[0]}`)), 'the level set loads lazily when the level is cued');
  assert.ok(!fetched.some(p => p.includes('/l3-')), 'other levels are not fetched');
  await step(8);
  const intro = last(sources, 'l2-intro');
  assert.ok(intro && onGrid(intro.at, grid, 2), 'intro starts on the bar grid');
  assert.equal(intro.loopStart, 8, 'intro loops its last bar after the opening');
  // Gameplay begins mid-intro: the first tier waits for the intro's opening (16 beats).
  await audio.intensity(1); await settle();
  assert.equal(audio.state.pending, 'l2-t1');
  await step(40);
  const t1 = last(sources, 'l2-t1');
  assert.ok(Math.abs(t1.at - (intro.at + 8)) < 1e-9, 'tier 1 enters when the intro opening ends');
  assert.equal(t1.offset, 0);
  assert.equal(t1.loop, true); assert.equal(t1.loopEnd, 16);
  await step(5);
  await audio.intensity(3); await settle();
  assert.equal(audio.state.pending, 'l2-t3', 'tier change waits for the bar');
  await step(10);
  const t3 = last(sources, 'l2-t3');
  assert.ok(onGrid(t3.at, grid, 2), 'tier change lands on a bar line');
  const expected = ((t3.at - t1.at) % 16);
  assert.ok(Math.abs(t3.offset - expected) < 1e-9 && t3.offset > 0, 'new tier continues at the same loop position');
  assert.ok(t1.stoppedAt >= t3.at && t1.stoppedAt <= t3.at + .1, 'rising tier: short crossfade at the bar');
  await audio.intensity(2); await settle(); await step(10);
  const t2 = last(sources, 'l2-t2');
  assert.ok(onGrid(t2.at, grid, 2));
  assert.ok(t3.stoppedAt >= t2.at + .45, 'falling tier: the old tier fades over a beat');
  assert.ok(Math.abs(t2.offset - ((t2.at - t1.at) % 16)) < 1e-9);
  // Accents: quantized to the half-beat (dive) or beat (hatch) of the grid; never in the past.
  ctx().currentTime += .07;
  const now = ctx().currentTime;
  const dive = await audio.accent('dive');
  assert.ok(dive >= now && dive - now <= .28 && onGrid(dive, grid, .25), `dive accent on the half-beat (${dive - now})`);
  const spriteSource = sources.at(-1);
  assert.equal(spriteSource.buffer.name, 'l2-accents'); assert.equal(spriteSource.offset, 0); assert.equal(spriteSource.duration, 1.5);
  const hatch = await audio.accent('hatch');
  assert.ok(hatch >= now && onGrid(hatch, grid, .5), 'hatch accent on the beat');
  assert.equal(sources.at(-1).offset, 3, 'hatch slot of the sprite');
  assert.equal(await audio.accent('dive'), null, 'the same accent is not retriggered within a second');
  ctx().currentTime += 1.9;  // past the two live accents (at most two at a time)
  const breakthrough = await audio.accent('breakthrough');
  assert.ok(onGrid(breakthrough, grid, .5), 'ground breakthrough accent on the beat');
  assert.equal(sources.at(-1).offset, 6, 'breakthrough slot of the sprite');
  assert.equal(audio.state.active, 'l2-t2', 'accents never replace the music');
  // Stale loads: only the latest request wins.
  await Promise.all([audio.cue('level', 1), audio.cue('travel', 2)]);
  assert.equal(audio.state.pending, 'l2-outro', 'travel plays the cleared level\'s outro');
  await step(10);
  assert.equal(audio.state.active, 'l2-outro'); assert.equal(sources.at(-1).loopEnd, 8);
  // Pause/resume keeps phase.
  const before = audio.state.nextBeat; audio.pause(); assert.equal(ctx().state, 'suspended');
  await audio.resume(); assert.equal(audio.state.nextBeat, before, 'resume keeps the bar grid');
  audio.mute(true); assert.equal(audio.muted, true); audio.mute(false);
});

test('clear, victory, finale and the game-over cackle are immediate; the alien theme follows on the grid', async () => {
  const { audio, ctx, sources, step } = await player({ missing: new Set(['l1-t3']) });
  await audio.unlock();
  await audio.cue('level', 1); await step(12);
  await audio.intensity(1); await step(40);
  assert.equal(audio.state.active, 'l1-t1');
  // A missing tier falls back to its MIDI score through the synthesizer.
  await audio.intensity(3); await step(12);
  assert.equal(audio.state.active, 'l1-t3'); assert.equal(audio.state.source, 'midi');
  // main.dart order in one tick: the clear cue, then the fleetIntact game event
  // while the normal march is still loading. The bigger variant starts at once.
  let now = ctx().currentTime;
  const clearing = audio.cue('levelclear');
  await audio.fleetIntact(); await clearing;
  assert.equal(sources.at(-1).buffer.name, 'levelclear-fleet');
  assert.ok(!sources.some(s => s.buffer?.name === 'levelclear'), 'the normal march never sounded');
  assert.ok(sources.at(-1).at <= now + .03);
  await audio.cue('level', 2); await step(10);
  assert.equal(audio.state.fleetIntact, false, 'the flag does not outlive its celebration');
  now = ctx().currentTime; await audio.cue('levelclear');
  const clear = sources.at(-1);
  assert.equal(clear.buffer.name, 'levelclear', 'without the event the normal march plays');
  assert.ok(clear.at <= now + .03, 'level clear starts immediately');
  assert.equal(clear.loopStart, 6); assert.equal(clear.loopEnd, 8);
  await step(8);
  await audio.cue('boss', 5, 1, 4); await step(10);
  assert.equal(audio.state.active, 'l5-intro');
  await audio.cue('boss', 5, 2, 4); await step(2);
  assert.equal(audio.state.active, 'l5-intro', 'carrier phase events do not restart its intro');
  now = ctx().currentTime; await audio.cue('victory', 5, 1, 4);
  assert.equal(sources.at(-1).buffer.name, 'finale', 'the last route ends on the campaign finale');
  assert.ok(sources.at(-1).at <= now + .03, 'finale starts immediately');
  assert.equal(sources.at(-1).loopStart, 18);
  await audio.cue('victory', 5, 1, 4); assert.equal(audio.state.active, 'finale', 'completion does not restart it');
  // The whole fleet survived, reported after the finale began: switch in place on the next bar.
  await step(5);
  const finale = sources.at(-1);
  assert.equal(await audio.fleetIntact(), true);
  assert.equal(audio.state.pending, 'finale-fleet');
  await step(8);
  const big = last(sources, 'finale-fleet');
  assert.ok(big, 'fleet variant plays');
  assert.ok(Math.abs(((big.at - finale.at) / 2) - Math.round((big.at - finale.at) / 2)) < 1e-9, 'switch lands on a bar of the finale');
  assert.ok(Math.abs(big.offset - (big.at - finale.at)) < 1e-9, 'and continues at the same position');
  await audio.cue('victory', 5, 1, 4); assert.equal(audio.state.active, 'finale-fleet', 'a repeated victory keeps the fleet finale');
  await audio.cue('victory', 5, 1, 1); assert.equal(audio.state.active, 'victory', 'earlier routes get the carrier victory march');
  await step(4);
  now = ctx().currentTime; await audio.cue('gameover');
  const cackle = sources.at(-1);
  assert.equal(cackle.buffer.name, 'cackle'); assert.ok(cackle.at <= now + .03, 'the cackle is immediate');
  assert.equal(cackle.loop, false, 'the cackle plays once');
  await step(2);
  await audio.cue('gameover'); assert.equal(audio.state.active, 'cackle', 'a second game-over notice does not restart it');
  await step(20);
  const theme = sources.at(-1);
  assert.equal(theme.buffer.name, 'alienwin');
  assert.ok(Math.abs(theme.at - (cackle.at + 4)) < 1e-9, 'the alien victory theme follows the cackle on its bar line');
  assert.equal(theme.loop, true);
  await audio.cue('gameover'); assert.equal(audio.state.active, 'alienwin');
});

test('every cue ships Opus and AAC files with whole-bar loops inside the download budget', async () => {
  const manifest = JSON.parse(await readFile(new URL('../web/audio/music/manifest.json', import.meta.url), 'utf8'));
  const spec = JSON.parse(await readFile(new URL('../art/workflows/music/cues.json', import.meta.url), 'utf8'));
  let opus = 0;
  const perLevel = {};
  for (const { name, kind } of spec.cues) {
    const cue = manifest.cues[name];
    assert.ok(cue, `${name} is in the manifest`);
    assert.equal(cue.kind, kind);
    const size = (await stat(new URL(`../web/audio/music/${name}.ogg`, import.meta.url))).size;
    await stat(new URL(`../web/audio/music/${name}.m4a`, import.meta.url));
    assert.equal(size, cue.bytes.ogg);
    opus += size;
    const level = name.match(/^l(\d)-/)?.[1];
    if (level) perLevel[level] = (perLevel[level] || 0) + size;
    if (cue.loopEnd !== null) assert.equal(((cue.loopEnd - cue.loopStart) * 2) % 4, 0, `${name} loop is whole bars`);
    if (kind === 'loop') assert.equal(cue.seconds, cue.beats / 2, `${name} loop length`);
    if (kind === 'tail') assert.equal(cue.loopStart, cue.beats / 2, `${name} tail opening`);
    if (kind === 'sprite') assert.deepEqual(cue.slots, ['dive', 'laststand', 'hatch', 'reinforce', 'breakthrough']);
    // The player's built-in table must agree with the manifest.
    assert.equal(seconds(name) !== undefined, true);
  }
  for (let level = 1; level <= 5; level++) for (const tier of [1, 2, 3, 4]) {
    assert.equal(manifest.cues[`l${level}-t${tier}`].tier, tier);
    assert.equal(manifest.cues[`l${level}-t${tier}`].beats, 32, 'tiers share one 8-bar loop length so a change keeps position');
  }
  assert.equal(manifest.cues.cackle.next, 'alienwin');
  assert.ok(opus < 8 * 1024 * 1024, `Opus set stays under 8 MB (${opus} bytes)`);
  for (const [level, bytes] of Object.entries(perLevel)) assert.ok(bytes < 1.4 * 1024 * 1024, `level ${level} set loads lazily in a modest chunk (${bytes})`);
});
