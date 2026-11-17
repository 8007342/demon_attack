// mix-retune: writes web/audio/score/mix-trim.json, the score's per-section level trims (a generated file: rerun
// after tools/score/score_gen.lua changes the score).
//
//   node tools/mix_meter/trim.mjs [--check]
//
// It renders every section of web/audio/score/score.json without trims through the shipped players (page.mjs),
// at Full music: each tier-masked loop at tiers 1-4, each fixed-mask section (tails, bridges, the menu and coda
// loops) once, for one pass of its bars (loops: at least 8 s, at most 16 s). Then it narrows the spread to SPREAD LU,
// keeping the order: L' = max(top - SPREAD, top - (top - L) * k), k = min(1, SPREAD / (top - floor)), where top is
// the loudest case and floor the 5th percentile, and each trim (L' - L) is capped at MAX_TRIM dB. The loudest case
// keeps 0 dB, so the music's absolute level stays with demon-audio.js's music level. Levels are stored relative to a
// 0 dB music level (measuredLufs: rendered at Full, minus Full's gain).
// The renderer is deterministic (fixed noise seeds), so a rerun on the same score reproduces the file; --check
// compares instead of writing. Takes several minutes: run it under forge-guard.
import { readFile, writeFile } from 'node:fs/promises';
import { page, web } from './page.mjs';
import { loudness } from './loudness.mjs';

const SPREAD = 2, MAX_TRIM = 8, FLOOR_PERCENTILE = .05;
const check = process.argv.includes('--check');
const map = JSON.parse(await readFile(web('audio/score/score.json'), 'utf8'));
const target = web('audio/score/mix-trim.json');

const cases = [];
for (const [song, spec] of Object.entries(map.songs)) {
  const bar = spec.barSamples / 48000;
  for (const [section, s] of Object.entries(spec.sections)) {
    const length = s.bars * bar;
    const seconds = s.kind === 'loop' ? Math.min(16, Math.max(8, length)) : length;
    if (s.mask === 'all') cases.push({ key: `${song}:${section}`, song, section, tier: 4, seconds });
    else for (const tier of [1, 2, 3, 4]) cases.push({ key: `${song}:${section}@${tier}`, song, section, tier, seconds });
  }
}

const measured = {};
for (const c of cases) {
  const p = await page({ music: 'full', speech: 'full' }, { trims: false });
  p.audio.song({ song: c.song, section: c.section, at: -1, quantum: 'bar', enter: 'start', tier: c.tier, reason: 'trim' });
  const out = await p.render(c.seconds + .6);
  const start = p.audio.state.score.moves[0]?.at ?? .25;
  const from = Math.round(start * 48000), to = Math.min(out.L.length, from + Math.round(c.seconds * 48000));
  // Stored as if the music level were 0 dB (the limiter rests at Full), so the file changes only with the score.
  const level = 20 * Math.log10(p.audio.state.musicLevel);
  measured[c.key] = +(loudness([out.L.subarray(from, to), out.R.subarray(from, to)]).integrated - level).toFixed(2);
  process.stderr.write(`${c.key.padEnd(20)} ${measured[c.key]} LUFS\n`);
}

const values = Object.values(measured).filter(Number.isFinite).sort((a, b) => a - b);
const top = values[values.length - 1], floor = values[Math.floor(FLOOR_PERCENTILE * (values.length - 1))];
const k = Math.min(1, SPREAD / Math.max(1e-9, top - floor));
const trims = {};
for (const [key, L] of Object.entries(measured)) {
  if (!Number.isFinite(L)) continue;
  const narrowed = Math.max(top - SPREAD, top - (top - L) * k);
  const trim = Math.min(MAX_TRIM, Math.max(0, narrowed - L));
  if (trim >= .05) trims[key] = +trim.toFixed(1);
}
const json = JSON.stringify({
  generator: 'node tools/mix_meter/trim.mjs',
  rule: { spread: SPREAD, maxTrim: MAX_TRIM, floorPercentile: FLOOR_PERCENTILE, top, floor: +floor.toFixed(2), k: +k.toFixed(4) },
  measuredLufs: measured,
  trims,
}, null, 1) + '\n';
if (check) {
  const committed = await readFile(target, 'utf8').catch(() => '');
  if (committed !== json) {
    const old = committed ? JSON.parse(committed) : { measuredLufs: {}, trims: {} };
    for (const key of Object.keys(measured)) if (old.measuredLufs[key] !== measured[key] || old.trims[key] !== trims[key]) console.error(`${key}: ${old.measuredLufs[key]} -> ${measured[key]} LUFS, trim ${old.trims[key]} -> ${trims[key]}`);
    console.error('mix-trim.json is stale: rerun node tools/mix_meter/trim.mjs');
    process.exit(1);
  }
  console.log('mix-trim.json is up to date');
} else {
  await writeFile(target, json);
  console.log(`wrote ${target.pathname}: ${Object.keys(trims).length} trims of ${cases.length} cases; top ${top} LUFS, floor ${floor.toFixed(2)}, k ${k.toFixed(3)}`);
}
