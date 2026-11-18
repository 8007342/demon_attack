// bass-tone (adaptive-soundtrack design §12.12): the sampled bass's amp chain. The synth path is byte for byte what
// it was with the bank off; the chain's data is clamped; with the bank on, the chain is installed on the sampled bass
// bus only, its shaper never sees more than full scale, and the sampled bass sits at the synth's loudness and crest.
// The shipped players run in the offline renderer (tools/mix_meter).
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { page, web } from '../tools/mix_meter/page.mjs';
import { loudness } from '../tools/mix_meter/loudness.mjs';
import { OfflineContext } from '../tools/mix_meter/offline-audio.mjs';

const hasFfmpeg = (() => { try { execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' }); return true; } catch { return false; } })();
const bankJson = JSON.parse(await readFile(web('audio/bank/bank.json'), 'utf8'));
const toneFile = JSON.parse(await readFile(new URL('../art/music/bank/bass-tone.json', import.meta.url), 'utf8'));
const recipe = JSON.parse(await readFile(new URL('../art/music/bank/recipe.json', import.meta.url), 'utf8'));

// sha256 of 4 s of the full mix with the bank off, rendered from origin/game at b9379267 (before bass-tone) through
// the same renderer. A deliberate change to the synth's sound changes these: re-record them from that change's tree.
const SYNTH = {
  'k:B@3': '10a4211eae3c56ce8262c8ee9b25312396e7d46a5c075814847394cab208d821',
  'c1:core@4': 'f3a6697879d73af2629a6bfd3a6e568af48ec85972af3d9fa5a8fcfb49a99c7d',
};

async function render(key, { bank = false, seconds = 4, solo = null, trims = true } = {}) {
  const [song, rest] = key.split(':'), [section, tier] = rest.split('@');
  const scoreFilter = solo ? map => {
    const keep = name => map.tracks[name]?.role === solo;
    const list = l => (Array.isArray(l) ? l.filter(keep) : l);
    const masks = m => (m ? Object.fromEntries(Object.entries(m).map(([k, v]) => [k, list(v)])) : m);
    map.masks = masks(map.masks);
    for (const k of Object.keys(map.layers)) map.layers[k] = list(map.layers[k]);
    for (const s of Object.values(map.songs)) { s.masks = masks(s.masks); for (const x of Object.values(s.sections)) { x.masks = masks(x.masks); x.tracks = list(x.tracks); } }
    return map;
  } : null;
  const p = await page(undefined, { bank, scoreFilter, trims });
  p.audio.song({ song, section, at: -1, quantum: 'bar', enter: 'start', tier: Number(tier), reason: 'test' });
  return { p, out: await p.render(seconds) };
}
const sha = ({ L, R }) => createHash('sha256').update(Buffer.from(L.buffer)).update(Buffer.from(R.buffer)).digest('hex');

test('bass-tone: with the bank off the synth renders byte for byte as before, and no tone chain is built', async () => {
  for (const [key, digest] of Object.entries(SYNTH)) {
    const { p, out } = await render(key);
    assert.equal(sha(out), digest, `${key}: the synth path changed`);
    assert.equal(p.audio.graph.bassTone, null, 'no bass chain without the bank');
    assert.equal(p.audio.state.score.bank.tone, null);
  }
});

test('bass-tone: the tone is data (the pick, copied into the recipe and bank.json), and its values are clamped', async () => {
  const pick = toneFile.candidates[toneFile.pick];
  assert.ok(pick, `the pick ${toneFile.pick} is a candidate`);
  assert.deepEqual(recipe.roles.bass.tone, pick, 'recipe.json carries the pick');
  assert.deepEqual(bankJson.roles.bass.tone, pick, 'bank.json carries the pick (rerun bank_build.lua)');
  const { p } = await render('k:B@3', { seconds: .1 });
  const spec = p.window.demonScore.toneSpec;
  const wild = JSON.parse(JSON.stringify(spec({ input: 9, drive: 400, grind: -3, output: 99, split: 5, order: 3, comp: { ratio: 900, threshold: 10 },
    cab: [['lowpass', 3000, -40], ['peaking', 1e6, 0, 40]], phone: { oversample: 'x8' } }, true)));  // out of the page's realm
  assert.equal(wild.input, 1);
  assert.equal(wild.drive, 30);
  assert.equal(wild.grind, 0);
  assert.equal(wild.output, 16);
  assert.equal(wild.split, 40);
  assert.equal(wild.order, 4);
  assert.deepEqual([wild.comp.ratio, wild.comp.threshold], [20, 0]);
  assert.deepEqual(wild.cab, [['lowpass', 3000, -12, 0], ['peaking', 20000, .1, 12]], 'pass Q in dB, others linear');
  assert.equal(wild.oversample, '2x', 'the phone tier falls back to 2x');
  assert.equal(spec(pick, true).order, pick.phone?.order ?? 4, 'phone overrides apply on the phone tier');
  assert.equal(spec(null), null);
});

test('bass-tone: the chain on a sine: the clean band stays clean, the shaper input stays under full scale', async () => {
  const { p } = await render('k:B@3', { seconds: .1 });
  const tone = toneFile.candidates[toneFile.pick];
  for (const amp of [toneFile.levels.median, toneFile.levels.peak]) {
    const ctx = new OfflineContext({ sampleRate: 48000 });
    const g = p.window.demonScore.bassTone(ctx, tone);
    const osc = ctx.createOscillator(); osc.frequency.value = 55;
    const a = ctx.createGain(); a.gain.value = amp; osc.connect(a); a.connect(g.input); osc.start(0);
    g.output.connect(ctx.destination);
    const frames = 128 * 300, grindIn = ctx.tap(g.stages.grindIn, frames), low = ctx.tap(g.stages.low, frames);
    const L = new Float32Array(frames), R = new Float32Array(frames);
    for (let f = 0; f < frames; f += 128) ctx.renderQuantum(L, R, f);
    const peak = x => x.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
    assert.ok(peak(grindIn.L) <= 1, `shaper input peak ${peak(grindIn.L)} at amp ${amp}`);
    assert.ok(peak(L) > 0 && Number.isFinite(peak(L)));
    assert.ok(peak(low.L) > 0, 'the clean band passes the fundamental');
  }
});

test('bass-tone: with the bank on, the sampled bass plays through the chain at the synth\'s loudness and crest', { skip: !hasFfmpeg && 'needs ffmpeg' }, async () => {
  const synth = await render('k:B@3', { seconds: 8, solo: 'bass', trims: false });
  const bank = await render('k:B@3', { bank: true, seconds: 8, solo: 'bass', trims: false });
  const g = bank.p.audio.graph.bassTone;
  assert.ok(g && g.stages.shaper && g.stages.comp, 'the chain is installed (compressor, shaper)');
  assert.equal(bank.p.audio.state.score.bank.tone, toneFile.pick);
  assert.ok(bank.p.audio.state.score.bank.sampled > 20, 'the bass is sampled');
  const cut = ({ L, R }) => [L.subarray(24000), R.subarray(24000)];
  const ls = loudness(cut(synth.out)), lb = loudness(cut(bank.out));
  assert.ok(Math.abs(ls.integrated - lb.integrated) < 1, `loudness: synth ${ls.integrated.toFixed(2)}, bank ${lb.integrated.toFixed(2)} LUFS`);
  // The clean DI peaked 9 dB over the synth at one loudness (design §12.11); through the chain it is within 3 dB.
  assert.ok(lb.peakDbfs - ls.peakDbfs < 3, `peaks: synth ${ls.peakDbfs.toFixed(2)}, bank ${lb.peakDbfs.toFixed(2)} dBFS`);
});

test('bass-tone: the Linkwitz-Riley split sums flat (LR4, and LR2 with its low band inverted) when nothing drives it', async () => {
  const { p } = await render('k:B@3', { seconds: .1 });
  for (const order of [4, 2]) for (const hz of [50, 120, 200, 330, 800]) {
    const ctx = new OfflineContext({ sampleRate: 48000 });
    const g = p.window.demonScore.bassTone(ctx, { input: 1, comp: null, split: 200, order, low: 1, drive: 1, grind: 1, output: 1 });
    const o = ctx.createOscillator(); o.frequency.value = hz;
    const a = ctx.createGain(); a.gain.value = .001; o.connect(a); a.connect(g.input); o.start(0);
    g.output.connect(ctx.destination);
    const n = 128 * 400, L = new Float32Array(n), R = new Float32Array(n);
    for (let f = 0; f < n; f += 128) ctx.renderQuantum(L, R, f);
    let m = 0; for (let i = n / 2; i < n; i++) m = Math.max(m, Math.abs(L[i]));
    assert.ok(Math.abs(20 * Math.log10(m / .001)) < .05, `LR${order} at ${hz} Hz: ${(20 * Math.log10(m / .001)).toFixed(3)} dB`);
  }
});
