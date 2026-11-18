// mix-retune: writes web/audio/score/mix-trim.json, the score's per-section level trims (a generated file: rerun
// after tools/score/score_gen.lua changes the score, or tools/bank/bank_build.lua rebuilds the sample bank).
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
// --- sample-bank: when web/audio/bank/bank.json exists, every case is rendered a second time with the bank on (the
// desktop tier: every sprite) into `bank`: the same narrowing, then every trim offset by (synth top - bank top) so the
// sampled score's loudest case lands on the synth's, and the radio balance holds in both modes. Bank trims may be
// negative (the sampled score is louder) and are capped at ±MAX_TRIM. demon-score.js uses `bank.trims` while the
// bank is switched on, else `trims`.
// The renderer is deterministic (fixed noise seeds), so a rerun on the same score reproduces the file; --check
// compares instead of writing. Takes several minutes (twice that with a bank): run it under forge-guard.
import { readFile, writeFile, stat } from 'node:fs/promises';
import { page, web } from './page.mjs';
import { loudness } from './loudness.mjs';

const SPREAD = 2, MAX_TRIM = 8, FLOOR_PERCENTILE = .05;
const check = process.argv.includes('--check');
const map = JSON.parse(await readFile(web('audio/score/score.json'), 'utf8'));
const target = web('audio/score/mix-trim.json');
const hasBank = await stat(web('audio/bank/bank.json')).then(() => true, () => false);

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

async function measure(bank) {
  const measured = {};
  for (const c of cases) {
    const p = await page({ music: 'full', speech: 'full' }, { trims: false, bank });
    p.audio.song({ song: c.song, section: c.section, at: -1, quantum: 'bar', enter: 'start', tier: c.tier, reason: 'trim' });
    const out = await p.render(c.seconds + .6);
    const start = p.audio.state.score.moves[0]?.at ?? .25;
    const from = Math.round(start * 48000), to = Math.min(out.L.length, from + Math.round(c.seconds * 48000));
    // Stored as if the music level were 0 dB (the limiter rests at Full), so the file changes only with the score.
    const level = 20 * Math.log10(p.audio.state.musicLevel);
    measured[c.key] = +(loudness([out.L.subarray(from, to), out.R.subarray(from, to)]).integrated - level).toFixed(2);
    process.stderr.write(`${bank ? 'bank ' : ''}${c.key.padEnd(20)} ${measured[c.key]} LUFS\n`);
  }
  return measured;
}
// The narrowing; `anchor` (the synth's top) shifts every trim so this set's top lands there.
function narrow(measured, anchor = null) {
  const values = Object.values(measured).filter(Number.isFinite).sort((a, b) => a - b);
  const top = values[values.length - 1], floor = values[Math.floor(FLOOR_PERCENTILE * (values.length - 1))];
  const k = Math.min(1, SPREAD / Math.max(1e-9, top - floor));
  const offset = anchor == null ? 0 : anchor - top;
  const trims = {};
  for (const [key, L] of Object.entries(measured)) {
    if (!Number.isFinite(L)) continue;
    const narrowed = Math.max(top - SPREAD, top - (top - L) * k);
    const trim = anchor == null ? Math.min(MAX_TRIM, Math.max(0, narrowed - L)) : Math.min(MAX_TRIM, Math.max(-MAX_TRIM, narrowed - L + offset));
    if (Math.abs(trim) >= .05) trims[key] = +trim.toFixed(1);
  }
  const rule = { spread: SPREAD, maxTrim: MAX_TRIM, floorPercentile: FLOOR_PERCENTILE, top, floor: +floor.toFixed(2), k: +k.toFixed(4) };
  if (anchor != null) rule.offset = +offset.toFixed(2);
  return { rule, trims };
}

const measured = await measure(false);
const synth = narrow(measured);
const file = { generator: 'node tools/mix_meter/trim.mjs', rule: synth.rule, measuredLufs: measured, trims: synth.trims };
if (hasBank) {
  const bankMeasured = await measure(true);
  const b = narrow(bankMeasured, synth.rule.top);
  file.bank = { rule: b.rule, measuredLufs: bankMeasured, trims: b.trims };
}
const json = JSON.stringify(file, null, 1) + '\n';
if (check) {
  const committed = await readFile(target, 'utf8').catch(() => '');
  if (committed !== json) {
    const old = committed ? JSON.parse(committed) : { measuredLufs: {}, trims: {} };
    for (const [label, now, before] of [['', file, old], ['bank ', file.bank, old.bank]]) {
      if (!now) continue;
      for (const key of Object.keys(now.measuredLufs)) if (before?.measuredLufs?.[key] !== now.measuredLufs[key] || before?.trims?.[key] !== now.trims[key]) console.error(`${label}${key}: ${before?.measuredLufs?.[key]} -> ${now.measuredLufs[key]} LUFS, trim ${before?.trims?.[key]} -> ${now.trims[key]}`);
    }
    console.error('mix-trim.json is stale: rerun node tools/mix_meter/trim.mjs');
    process.exit(1);
  }
  console.log('mix-trim.json is up to date');
} else {
  await writeFile(target, json);
  console.log(`wrote ${target.pathname}: ${Object.keys(synth.trims).length} trims of ${cases.length} cases; top ${synth.rule.top} LUFS, floor ${synth.rule.floor}, k ${synth.rule.k}`
    + (file.bank ? `; bank: ${Object.keys(file.bank.trims).length} trims, top ${file.bank.rule.top} LUFS (offset ${file.bank.rule.offset} dB), floor ${file.bank.rule.floor}, k ${file.bank.rule.k}` : ''));
}
