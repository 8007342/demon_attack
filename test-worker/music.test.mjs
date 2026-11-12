import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import vm from 'node:vm';

// Each level's grid: integer samples per bar at 48 kHz (tools/music_motifs.py).
const BAR = { 1: 67765 / 48000, 2: 72000 / 48000, 3: 64000 / 48000, 4: 76800 / 48000, 5: 60632 / 48000 };
const BEAT = level => BAR[level] / 4;
// Decoded durations of the instrumented cues (seconds), as the pipeline builds them.
function seconds(name) {
  const level = +name[1];
  if (/^l\d-t\d$/.test(name)) return 8 * BAR[level];
  if (/-intro$/.test(name)) return 5 * BAR[level];
  if (/-outro$/.test(name)) return 4 * BAR[level];
  if (/-accents$/.test(name)) return 12;
  if (/-layers$/.test(name)) return 12 * BAR[level];  // six two-bar layer slots
  if (/-power$/.test(name)) return 8 * BAR[level];
  return { ending: 100, menu: 16, levelclear: 8, victory: 12, finale: 20, 'levelclear-fleet': 8, 'finale-fleet': 20, cackle: 4, alienwin: 16 }[name];
}

async function player({ missing = new Set(), localStorage } = {}) {
  let callback, ctx;
  const fetched = [], sources = [], voices = [];
  const parameter = () => ({ value: 1, events: [], cancelScheduledValues() {}, setValueAtTime(v, t) { this.events.push(['set', v, t]); }, linearRampToValueAtTime(v, t) { this.value = v; this.events.push(['ramp', v, t]); }, exponentialRampToValueAtTime() {}, setTargetAtTime(value) { this.value = value; } });
  class AudioContext {
    constructor() { ctx = this; this.currentTime = 0; this.state = 'suspended'; this.sampleRate = 48000; }
    createGain() { return { gain: parameter(), connect() {}, disconnect() {} }; }
    createOscillator() { return { frequency: parameter(), connect() {}, disconnect() {}, start() { voices.push(this); }, stop() {} }; }
    createBufferSource() { const s = { connect(to) { s.to = to; }, disconnect() {}, start(at, offset, duration) { s.at = at; s.offset = offset; s.duration = duration; sources.push(s); }, stop(at) { s.stoppedAt = at; } }; return s; }
    decodeAudioData(bytes) { const name = new TextDecoder().decode(new Uint8Array(bytes)); return Promise.resolve({ duration: seconds(name), name }); }
    async resume() { this.state = 'running'; }
    async suspend() { this.state = 'suspended'; }
  }
  const sandbox = { URL, Uint8Array, DataView, Map, Set, Math, Object, Promise, TextDecoder, window: { AudioContext, addEventListener() {}, ...(localStorage ? { localStorage } : {}) }, document: { baseURI: 'https://game.test/', addEventListener() {} }, setInterval(fn) { callback = fn; },
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
const near = (a, b) => Math.abs(a - b) < 1e-9;
const last = (sources, name) => sources.filter(s => s.buffer?.name === name).at(-1);

test('the ending retains its full arrangement and warm tail at 96 BPM', async () => {
  const { audio, sources, settle } = await player();
  await audio.unlock();
  await audio.cue('ending', 5);
  await settle();
  assert.equal(audio.state.active, 'ending');
  assert.equal(audio.state.asset, 'ending');
  assert.equal(audio.state.duration, 100);
  assert.equal(audio.state.beatSeconds, 60 / 96);
  const source = last(sources, 'ending');
  assert.equal(source.loopStart, 95, 'the full 38-bar resolution plays before the final two bars loop');
  assert.equal(source.loopEnd, 100);
});

test('unavailable new ending uses the existing resolution and identifies the actual asset', async () => {
  const { audio, sources, settle } = await player({ missing: new Set(['ending']) });
  await audio.unlock();
  await audio.cue('ending', 5);
  await settle();
  assert.equal(audio.state.active, 'ending');
  assert.equal(audio.state.asset, 'finale');
  assert.equal(audio.state.duration, 20);
  assert.ok(last(sources, 'finale'));
});

test('levels play intro then tiers of one motif at the level tempo: tier changes land on bars and keep the loop position', async () => {
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
  assert.ok(intro && onGrid(intro.at, grid, 2), 'intro starts on the bar line of the 120 BPM menu');
  assert.ok(near(intro.loopStart, 16 * BEAT(2)), 'intro loops its last bar after its 16-beat opening at 160 BPM');
  assert.ok(near(audio.state.beatSeconds, BEAT(2)), 'the grid now runs at the level tempo');
  // Gameplay begins mid-intro: the first tier waits for the intro's opening (16 beats).
  await audio.intensity(1); await settle();
  assert.equal(audio.state.pending, 'l2-t1');
  await step(40);
  const t1 = last(sources, 'l2-t1');
  assert.ok(near(t1.at, intro.at + 16 * BEAT(2)), 'tier 1 enters when the intro opening ends');
  assert.equal(t1.offset, 0);
  assert.equal(t1.loop, true); assert.ok(near(t1.loopEnd, 8 * BAR[2]));
  await step(5);
  await audio.intensity(3); await settle();
  assert.equal(audio.state.pending, 'l2-t3', 'tier change waits for the bar');
  await step(10);
  const t3 = last(sources, 'l2-t3');
  assert.ok(onGrid(t3.at, t1.at, BAR[2]), 'tier change lands on a bar line of the level grid');
  const expected = ((t3.at - t1.at) % (8 * BAR[2]));
  assert.ok(Math.abs(t3.offset - expected) < 1e-9 && t3.offset > 0, 'new tier continues at the same loop position');
  assert.ok(t1.stoppedAt >= t3.at && t1.stoppedAt <= t3.at + .1, 'rising tier: short crossfade at the bar');
  await audio.intensity(2); await settle(); await step(10);
  const t2 = last(sources, 'l2-t2');
  assert.ok(onGrid(t2.at, t1.at, BAR[2]));
  assert.ok(t3.stoppedAt >= t2.at + BEAT(2) * .9, 'falling tier: the old tier fades over a beat');
  assert.ok(Math.abs(t2.offset - ((t2.at - t1.at) % (8 * BAR[2]))) < 1e-9);
  // Accents: quantized to the half-beat (dive) or beat (hatch) of the grid; never in the past.
  ctx().currentTime += .07;
  const now = ctx().currentTime;
  const dive = await audio.accent('dive');
  assert.ok(dive >= now && dive - now <= BEAT(2) / 2 + .031 && onGrid(dive, t1.at, BEAT(2) / 2), `dive accent on the half-beat of the 160 BPM grid (${dive - now})`);
  // A dive plays one composable layer of the level's layer sprite (two-bar slots).
  const layerSource = sources.at(-1);
  assert.equal(layerSource.buffer.name, 'l2-layers'); assert.ok(near(layerSource.duration, 2 * BAR[2] - .04), 'the slot, minus its silent 40 ms guard');
  assert.ok(onGrid(layerSource.offset, 0, 2 * BAR[2]), 'a whole layer slot');
  assert.equal(audio.state.accents.at(-1).source, 'layers');
  const hatch = await audio.accent('hatch');
  assert.ok(hatch >= now && onGrid(hatch, t1.at, BEAT(2)), 'hatch accent on the beat');
  assert.equal(sources.at(-1).offset, 3, 'hatch slot of the sprite');
  assert.equal(await audio.accent('dive'), null, 'the same accent is not retriggered at once');
  ctx().currentTime += 1.9;  // past the two live accents (at most two at a time)
  const breakthrough = await audio.accent('breakthrough');
  assert.ok(onGrid(breakthrough, t1.at, BEAT(2)), 'ground breakthrough accent on the beat');
  assert.equal(sources.at(-1).offset, 6, 'breakthrough slot of the sprite');
  // Life loss: the hit lands on the next sixteenth and drops the music for two
  // bars; the gloat and the heroic re-entry follow on the beat, and the re-entry
  // restores the music on its downbeat.
  ctx().currentTime += 1.6;
  const hit = await audio.accent('destroyed');
  assert.ok(onGrid(hit, t1.at, BEAT(2) / 4) && hit - ctx().currentTime <= BEAT(2) / 4 + .031, 'hit stinger on the next sixteenth');
  assert.equal(sources.at(-1).offset, 7.5, 'destroyed slot');
  assert.ok(near(audio.state.drop.at, hit) && near(audio.state.drop.until, hit + 2 * BAR[2]), 'music drops for two bars');
  ctx().currentTime += .4;
  const gloat = await audio.accent('gloat');
  assert.ok(onGrid(gloat, t1.at, BEAT(2)) && sources.at(-1).offset === 9, 'demonic gloat on the beat');
  ctx().currentTime += .4;
  const back = await audio.accent('respawn');
  assert.ok(onGrid(back, t1.at, BEAT(2)) && sources.at(-1).offset === 10.5, 'heroic re-entry on the beat');
  assert.ok(near(audio.state.drop.until, back + BEAT(2)), 'the music returns on the re-entry downbeat');
  assert.equal(audio.state.active, 'l2-t2', 'accents never replace the music');
  // Stale loads: only the latest request wins.
  await Promise.all([audio.cue('level', 1), audio.cue('travel', 2)]);
  assert.equal(audio.state.pending, 'l2-outro', 'travel plays the cleared level\'s outro');
  await step(10);
  assert.equal(audio.state.active, 'l2-outro'); assert.ok(near(sources.at(-1).loopEnd, 4 * BAR[2]));
  const outro = last(sources, 'l2-outro');
  // Across tempos: the next level's intro starts on an L2 bar line (the old
  // bar is finished), then the grid runs at 180 BPM.
  await audio.cue('level', 3); await step(12);
  const intro3 = last(sources, 'l3-intro');
  assert.ok(intro3 && onGrid(intro3.at, outro.at, BAR[2]), 'cross-tempo change lands on the old grid\'s bar line');
  assert.ok(near(audio.state.beatSeconds, BEAT(3)), 'then the new cue keeps its own grid');
  assert.ok(onGrid(audio.state.nextBeat, intro3.at, BEAT(3)), 'beats now step at 180 BPM from the intro start');
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
  const layerSlots = ['stab', 'swell', 'fill', 'gallop', 'lead', 'low'];
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
    const bar = cue.barSamples || 96000;
    if (cue.loopEnd !== null) assert.equal(Math.round((cue.loopEnd - cue.loopStart) * 48000) % bar, 0, `${name} loop is whole bars`);
    if (kind === 'loop') assert.equal(Math.round(cue.seconds * 48000), cue.beats / 4 * bar, `${name} loop length is exact at its tempo`);
    if (kind === 'tail') assert.equal(Math.round(cue.loopStart * 48000), cue.beats / 4 * bar, `${name} tail opening`);
    if (kind === 'sprite' && name.endsWith('-accents')) assert.deepEqual(cue.slots, ['dive', 'laststand', 'hatch', 'reinforce', 'breakthrough', 'destroyed', 'gloat', 'respawn']);
    if (name.endsWith('-layers')) {
      // Composable dive layers: the player's table matches the sprite, two bars per slot.
      assert.deepEqual(cue.slots, layerSlots);
      assert.equal(Math.round(cue.slotSeconds * 48000), 2 * cue.barSamples);
      assert.equal(Math.round(cue.seconds * 48000), cue.slots.length * 2 * cue.barSamples);
      for (const layer of cue.slots) assert.ok(Math.abs(cue.layers[layer].hitOffsetMs) <= 12, `${name} ${layer} hits its grid point (${cue.layers[layer].hitOffsetMs} ms)`);
      for (const layer of ['stab', 'swell', 'lead', 'low']) assert.ok(cue.layers[layer].keyMatch >= .5, `${name} ${layer} agrees with the level's tier chroma`);
    }
    if (name.endsWith('-power')) assert.equal(cue.beats, 32, 'the power layer loops with the tiers');
    // The player's built-in table must agree with the manifest.
    assert.equal(seconds(name) !== undefined, true);
  }
  for (let level = 1; level <= 5; level++) for (const tier of [1, 2, 3, 4]) {
    assert.equal(manifest.cues[`l${level}-t${tier}`].tier, tier);
    assert.equal(manifest.cues[`l${level}-t${tier}`].beats, 32, 'tiers share one 8-bar loop length so a change keeps position');
  }
  assert.equal(manifest.cues.cackle.next, 'alienwin');
  // The player's bar table matches the pipeline's (manifest) for every level.
  const js = await readFile(new URL('../web/audio/demon-audio.js', import.meta.url), 'utf8');
  assert.deepEqual(JSON.parse(js.match(/const layerSlots = (\[[^\]]+\])/)[1].replace(/'/g, '"')), layerSlots);
  const table = JSON.parse(js.match(/levelBarSamples = (\{[^}]+\})/)[1].replace(/(\d+):/g, '"$1":'));
  for (let level = 1; level <= 5; level++) {
    assert.equal(table[level], manifest.motifs[level].barSamples, `level ${level} grid`);
    assert.equal(table[level], Math.round(BAR[level] * 48000));
    for (const part of ['t1', 'intro', 'outro']) assert.equal(manifest.cues[`l${level}-${part}`].barSamples, table[level]);
  }
  // Metal-v2: the recorded cues are ACE's own band/orchestra takes, not
  // re-performed synth guides (round 3 measured 0.09 flatness at 1-5 kHz).
  for (const [name, cue] of Object.entries(manifest.cues)) {
    if (cue.kind === 'sprite' || name === 'cackle' || cue.mode === 'stems') continue;
    assert.ok(['text', 'a2a'].includes(cue.mode), `${name} is a recorded take`);
    assert.ok(cue.flat15 >= 0.16, `${name} has distorted-band timbre (1-5 kHz flatness ${cue.flat15})`);
    // Battle tiers must be far from the synth guide's long-term spectrum (round 3: 0.56 at best,
    // yet tonal); orchestral cues share its broad balance, so only the tiers are held to it.
    if (cue.tier) assert.ok(cue.guideDistance >= 0.3, `${name} is far from the synth guide (${cue.guideDistance})`);
    if (cue.variantOf) assert.equal(manifest.cues[cue.variantOf].beats, cue.beats, `${name} is the same march bar for bar`);
  }
  assert.ok(opus < 8 * 1024 * 1024, `Opus set stays under 8 MB (${opus} bytes)`);
  for (const [level, bytes] of Object.entries(perLevel)) assert.ok(bytes < 1.4 * 1024 * 1024, `level ${level} set loads lazily in a modest chunk (${bytes})`);
});

// --- audio round: composable dive layers and the power-up layer.
async function inTiers(level = 1, options) {
  const h = await player(options);
  await h.audio.unlock();
  await h.audio.cue('level', level); await h.step(12);
  await h.audio.intensity(2); await h.step(40);
  assert.equal(h.audio.state.active, `l${level}-t2`);
  return h;
}
const layerSlots = ['stab', 'swell', 'fill', 'gallop', 'lead', 'low'];
const layerQuantum = { stab: .5, swell: 1, fill: 2, gallop: 2, lead: 4, low: 1 };
const layerRole = { stab: 'hit', swell: 'hit', fill: 'drums', gallop: 'drums', lead: 'tone', low: 'tone' };

test('dive accents compose: each adds a different layer on the grid, never the same twice in a row, at most four', async () => {
  const { audio, ctx, sources, step } = await inTiers(1);
  const t2 = last(sources, 'l1-t2');
  const names = [], gains = [];
  for (let i = 0; i < 4; i++) {
    const now = ctx().currentTime;
    const at = await audio.accent('dive');
    assert.ok(at >= now + .03 - 1e-9, 'never in the past');
    const source = sources.at(-1), live = audio.state.layers;
    assert.equal(source.buffer.name, 'l1-layers');
    const name = live.at(-1).name;
    names.push(name); gains.push(source.to.gain.value);
    assert.ok(onGrid(at, t2.at, layerQuantum[name] * BEAT(1)), `${name} lands on its ${layerQuantum[name]}-beat grid`);
    assert.ok(near(source.offset, layerSlots.indexOf(name) * 2 * BAR[1]), 'its own slot');
    assert.equal(live.length, i + 1, 'the earlier layers still ring: the new one composes over them');
    assert.equal(live.at(-1).depth, i);
    if (i === 0) assert.ok(layerQuantum[name] <= 1, 'an empty stack starts with a layer that lands within a beat');
    ctx().currentTime += .3;
    assert.equal(await audio.accent('dive'), null, 'at most one dive layer per half second');
    ctx().currentTime += i < 3 ? .46 : .21;  // the director spaces dive tells .75 s apart
  }
  assert.equal(new Set(names).size, 4, `four different layers (${names})`);
  assert.equal(new Set(names.slice(0, 3).map(n => layerRole[n])).size, 3, `the first three cover the three roles (${names})`);
  for (let i = 1; i < gains.length; i++) assert.ok(gains[i] < gains[i - 1], 'deeper layers sit lower');
  // When dives stop the stack decays; the next dive starts a new stack.
  await step(16);
  assert.equal(audio.state.layers.length, 0, 'the stack has decayed');
  const sequence = [names.at(-1)];
  for (let i = 0; i < 20; i++) { await audio.accent('dive'); sequence.push(audio.state.layerLog.at(-1).name); await step(16); }
  for (let i = 1; i < sequence.length; i++) assert.notEqual(sequence[i], sequence[i - 1], `no variant twice in a row (${sequence})`);
  assert.ok(new Set(sequence.slice(1)).size >= 3, `the opening layer varies (${sequence})`);
  assert.equal(audio.state.active, 'l1-t2', 'layers never replace the tier');
});

test('the layer stack is capped at four, and a full stack still lets life-loss accents through', async () => {
  const { audio, ctx } = await inTiers(4);
  for (let i = 0; i < 4; i++) { assert.ok(await audio.accent('dive') !== null, `layer ${i + 1}`); ctx().currentTime += .51; }
  assert.equal(audio.state.layers.length, 4);
  assert.equal(await audio.accent('dive'), null, 'cap of four layers');
  assert.ok(await audio.accent('destroyed') !== null);
});

test('without a decoded layer sprite a dive falls back to the single dive accent', async () => {
  const { audio, sources } = await inTiers(2, { missing: new Set(['l2-layers']) });
  await audio.accent('dive');
  assert.equal(sources.at(-1).buffer.name, 'l2-accents');
  assert.equal(sources.at(-1).offset, 0);
});

test('a muted music channel plays no dive layers; the life-loss drop still applies', async () => {
  const { audio } = await inTiers(3);
  audio.setLevel('music', 'mute');
  assert.equal(await audio.accent('dive'), null);
  assert.ok(await audio.accent('destroyed') !== null);
});

test('power-ups add the level\'s power layer on the next bar at the tiers\' loop position, and remove it on a bar', async () => {
  const { audio, sources, step } = await inTiers(4);
  const t2 = last(sources, 'l4-t2');
  audio.powerLayer(1, false); await step(8);
  const layer = last(sources, 'l4-power');
  assert.ok(layer, 'power layer plays');
  assert.ok(onGrid(layer.at, t2.at, BAR[4]), 'it starts on a bar line');
  assert.ok(Math.abs(layer.offset - ((layer.at - t2.at) % (8 * BAR[4]))) < 1e-9, 'at the tiers\' loop position');
  assert.equal(layer.loop, true);
  assert.equal(audio.state.power.playing.level, 1);
  audio.powerLayer(3, true); await step(8);
  assert.equal(audio.state.power.playing.level, 2, 'two or more powers: the louder level');
  assert.equal(audio.state.power.bright, true, 'a falling pickup opens the top end');
  // A tier change keeps the layer (same grid, same loop position).
  await audio.intensity(4); await step(8);
  assert.equal(audio.state.active, 'l4-t4');
  assert.equal(last(sources, 'l4-power'), layer, 'no restart on a tier change');
  audio.powerLayer(0, false); await step(8);
  assert.equal(audio.state.power.playing, null, 'removed when the powers end');
  assert.ok(layer.stoppedAt !== undefined && onGrid(layer.stoppedAt - BEAT(4) - .05, t2.at, BAR[4]), 'faded out from a bar line');
  assert.equal(audio.state.power.bright, false);
  // Leaving the level (travel) stops it too.
  audio.powerLayer(1, false); await step(8);
  assert.ok(audio.state.power.playing);
  await audio.cue('travel', 4); await step(12);
  assert.equal(audio.state.active, 'l4-outro');
  assert.equal(audio.state.power.playing, null);
});
