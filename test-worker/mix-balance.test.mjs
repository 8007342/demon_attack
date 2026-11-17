// mix-balance (operator round 5 M1): the radio sits clearly above the music at the default levels, and the music
// ducks under radio lines. The shipped players (demon-score.js, demon-audio.js, comms-audio.js) run in the offline
// renderer of tools/mix_meter (a Web Audio subset) and are metered with BS.1770; radio clips are a synthetic
// syllable-modulated noise normalised to the bank's -18 LUFS, so no decoder is needed.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { page } from '../tools/mix_meter/page.mjs';
import { loudness } from '../tools/mix_meter/loudness.mjs';

const dB = value => 10 ** (value / 20);
const toDb = gain => 20 * Math.log10(gain);
const SR = 48000;

// A mono "line": white noise under a 4 Hz syllable envelope, at `lufs` integrated (the comms bank's target).
function speechLike(seconds, lufs = -18) {
  const x = new Float32Array(Math.round(seconds * SR));
  let seed = 1103;
  for (let i = 0; i < x.length; i++) {
    seed = (seed * 16807) % 2147483647;
    x[i] = (seed / 1073741823.5 - 1) * (.5 - .5 * Math.cos(2 * Math.PI * 4 * i / SR));
  }
  const gain = dB(lufs - loudness([x]).integrated);
  const bytes = new Uint8Array(4 + x.length * 4), view = new DataView(bytes.buffer);
  bytes.set([0x46, 0x33, 0x32, 0x4d]);
  for (let i = 0; i < x.length; i++) view.setFloat32(4 + i * 4, x[i] * gain, true);
  return bytes.buffer;
}
const clips = { line: speechLike(2), growl: speechLike(2), whoop: speechLike(.6), other: speechLike(1.5) };
const clip = id => clips[id] ?? null;
const start = (p, song, section, tier) => p.audio.song({ song, section, at: -1, quantum: 'bar', enter: 'start', tier, reason: 'test' });
const meter = (out, skip = 1.5) => loudness([out.L.subarray(skip * SR), out.R.subarray(skip * SR)]).integrated;

test('default levels: the score sits 2-5 LU under the radio, the loudest 2-4 LU (measured end to end)', async () => {
  // Nothing saved: both channels at their defaults (Full).
  const speech = await page({}, { clip });
  let next = 0;
  const said = meter(await speech.render(6.5, t => { if (t >= next) { speech.comms.play(`line`, 5, false); next = t + 2.3; } }), 0);
  for (const [song, section, tier, low, high] of [['k', 'A', 3, 2, 5], ['c1', 'core', 4, 2, 4]]) {
    const p = await page({}, { clip });
    start(p, song, section, tier);
    const music = meter(await p.render(9));
    const gap = said - music;
    assert.ok(gap >= low && gap <= high, `${song}:${section}@${tier}: radio ${said.toFixed(1)} LUFS, music ${music.toFixed(1)} LUFS, gap ${gap.toFixed(1)} LU`);
  }
  // The master limiter rests under the music at Full: its peaks stay well under the -1.5 dBFS threshold.
  const p = await page({}, { clip });
  start(p, 'c1', 'core', 4);
  const out = await p.render(6);
  assert.ok(loudness([out.L, out.R]).peakDbfs < -4, 'the loudest carrier stays clear of the limiter');
});

test('levels: Full music is -14 dB, Low 10 dB under; saved choices are honoured, defaults are Full', async () => {
  const fresh = await page({}, { clip });
  assert.deepEqual({ ...fresh.audio.levels }, { music: 'full', speech: 'full' });
  assert.ok(Math.abs(fresh.audio.state.musicLevel - dB(-14)) < 1e-9);
  const saved = await page({ music: 'low', speech: 'low' }, { clip });
  assert.deepEqual({ ...saved.audio.levels }, { music: 'low', speech: 'low' }, 'a stored choice is read back as it was saved');
  assert.ok(Math.abs(saved.audio.state.musicLevel - dB(-24)) < 1e-9);
  assert.equal(saved.comms.state.level, 'low');
  const muted = await page({ music: 'mute', speech: 'full' }, { clip });
  assert.equal(muted.audio.state.musicLevel, 0);
});

// Records the duck stage's rendered gain (dB) on every 25 ms scheduler tick.
async function duckTrace(p, seconds, at = () => {}) {
  const trace = [];
  await p.render(seconds, t => { trace.push([t, toDb(p.audio.graph.duck.gain.value)]); at(t); });
  return trace;
}
const near = (trace, t) => trace.reduce((best, s) => (Math.abs(s[0] - t) < Math.abs(best[0] - t) ? s : best))[1];

test('a radio line ducks the music 3 dB with a short attack, holds, then releases smoothly', async () => {
  const p = await page({}, { clip });
  start(p, 'k', 'A', 3);
  let played = false;
  const trace = await duckTrace(p, 5, t => { if (!played && t >= 1) played = p.comms.play('line', 5, false); });
  const lineStart = trace.find(([t]) => t >= 1)[0];   // the clip starts on the next tick after decode, within ~30 ms
  assert.ok(Math.abs(near(trace, .9)) < .01, 'no duck before the line');
  assert.ok(Math.abs(near(trace, lineStart + .2) + 3) < .3, `down 3 dB within 200 ms (${near(trace, lineStart + .2).toFixed(2)})`);
  assert.ok(Math.abs(near(trace, lineStart + 2.1) + 3) < .3, 'held through the line and its hold');
  assert.ok(Math.abs(near(trace, lineStart + 2 + .25 + .6)) < .5, 'back within half a dB 0.6 s after the hold');
  assert.ok(Math.abs(near(trace, 4.9)) < .02, 'fully back');
  for (let i = 1; i < trace.length; i++) assert.ok(Math.abs(trace[i][1] - trace[i - 1][1]) < 2.5, `no step at ${trace[i][0].toFixed(3)} s`);
  assert.deepEqual({ attack: p.audio.state.duck.attack, release: p.audio.state.duck.release, hold: p.audio.state.duck.hold }, { attack: .03, release: .15, hold: .25 });
});

test('a brood growl or a short stinger ducks only 1.5 dB; overlapping lines hold the deepest', async () => {
  const growl = await page({}, { clip });
  start(growl, 'k', 'A', 3);
  let g = false;
  const gt = await duckTrace(growl, 2, t => { if (!g && t >= .5) g = growl.comms.play('growl', 5, true); });
  assert.ok(Math.abs(near(gt, 1.5) + 1.5) < .3, `demon line: 1.5 dB (${near(gt, 1.5).toFixed(2)})`);

  const whoop = await page({}, { clip });
  start(whoop, 'k', 'A', 3);
  let w = false;
  const wt = await duckTrace(whoop, 1.2, t => { if (!w && t >= .3) w = whoop.comms.play('whoop', 5, false); });
  assert.ok(Math.abs(near(wt, .7) + 1.5) < .3, `a clip under 1 s: 1.5 dB (${near(wt, .7).toFixed(2)})`);

  const both = await page({}, { clip });
  start(both, 'k', 'A', 3);
  let a = false, b = false;
  const bt = await duckTrace(both, 6, t => {
    if (!a && t >= .5) a = both.comms.play('growl', 5, true);        // 1.5 dB, .5 - 2.5 s
    if (!b && t >= 1) b = both.comms.play('other', 5, false);        // 3 dB, 1 - 2.5 s
  });
  assert.ok(Math.abs(near(bt, .9) + 1.5) < .3, 'the growl alone: 1.5 dB');
  assert.ok(Math.abs(near(bt, 1.8) + 3) < .3, 'the squad line on top: 3 dB');
  assert.ok(Math.abs(near(bt, 5.5)) < .05, 'both done: back to 0 dB');
});

test('a line cut early releases the duck early', async () => {
  const p = await page({}, { clip });
  start(p, 'k', 'A', 3);
  let played = false, cut = false;
  const trace = await duckTrace(p, 3, t => {
    if (!played && t >= .3) played = p.comms.play('line', 5, false);
    if (!cut && t >= .8) { p.comms.stop('line'); cut = true; }
  });
  assert.ok(Math.abs(near(trace, .7) + 3) < .3);
  assert.ok(Math.abs(near(trace, .8 + .04 + .25 + .7)) < .3, 'released after the cut and the hold, not at the clip end');
});

test('ducking never moves the score: bar-quantised moves land on the same times with or without the radio', async () => {
  const run = async talk => {
    const p = await page({}, { clip });
    start(p, 'k', 'A', 2);
    let moved = false, played = 0;
    await p.render(9, t => {
      if (talk && t >= 1.5 + played * 2.4 && played < 3) { p.comms.play(played % 2 ? 'other' : 'line', 5, false); played++; }
      if (!moved && t >= 3.1) { p.audio.song({ song: 'k', section: 'B', at: -1, quantum: 'bar', enter: 'same', tier: 3, reason: 'test' }); moved = true; }
    });
    const s = p.audio.state.score;
    // A JSON copy: the state comes from the page realm.
    return JSON.parse(JSON.stringify({ moves: s.moves.map(m => [m.section, +m.at.toFixed(6), m.entry]), audible: s.audible, slipped: s.slipped, music: p.audio.graph.music.gain.value }));
  };
  const quiet = await run(false), talking = await run(true);
  assert.deepEqual(talking, quiet);
  assert.equal(talking.moves.length, 2, 'the start and the move to B');
  assert.equal(talking.music, 1, 'the music bus itself stays at unity; the duck is its own stage');
});

// --- mix-retune: the score's section trims (web/audio/score/mix-trim.json, from tools/mix_meter/trim.mjs).
const trimFile = JSON.parse(await readFile(new URL('../web/audio/score/mix-trim.json', import.meta.url), 'utf8'));
const scoreMap = JSON.parse(await readFile(new URL('../web/audio/score/score.json', import.meta.url), 'utf8'));

test('the trim table covers every section and tier and narrows them to 2 LU', () => {
  const { measuredLufs: measured, trims, rule } = trimFile;
  for (const [song, spec] of Object.entries(scoreMap.songs)) for (const [section, s] of Object.entries(spec.sections)) {
    const keys = s.mask === 'all' ? [`${song}:${section}`] : [1, 2, 3, 4].map(t => `${song}:${section}@${t}`);
    for (const key of keys) assert.ok(Number.isFinite(measured[key]), `${key} measured (rerun node tools/mix_meter/trim.mjs after a score change)`);
  }
  assert.equal(Object.keys(measured).length, Object.values(scoreMap.songs).reduce((n, s) => n + Object.values(s.sections).reduce((m, x) => m + (x.mask === 'all' ? 1 : 4), 0), 0), 'no stale keys');
  const levels = Object.entries(measured).map(([key, L]) => L + (trims[key] ?? 0));
  for (const t of Object.values(trims)) assert.ok(t > 0 && t <= rule.maxTrim, `trim ${t} dB within 0-${rule.maxTrim}`);
  assert.ok(Math.max(...levels) - Math.min(...levels) <= 2.1, `trimmed spread (trims round to 0.1 dB) ${(Math.max(...levels) - Math.min(...levels)).toFixed(2)} LU`);
  assert.equal(trims[Object.entries(measured).sort((a, b) => b[1] - a[1])[0][0]], undefined, 'the loudest section keeps 0 dB');
});

test('rendered with trims, calm and loud sections sit within about 2 LU', async () => {
  const onePass = async (song, section, tier) => {
    const p = await page({}, { clip });
    start(p, song, section, tier);
    const s = scoreMap.songs[song], bars = s.sections[section].bars, seconds = bars * s.barSamples / SR;
    const out = await p.render(seconds + .6);
    const a = Math.round(p.audio.state.score.moves[0].at * SR), b = a + Math.round(seconds * SR);
    return loudness([out.L.subarray(a, b), out.R.subarray(a, b)]).integrated;
  };
  const levels = { 'k:A@1': await onePass('k', 'A', 1), 'c1:core@4': await onePass('c1', 'core', 4), 'k:arrival': await onePass('k', 'arrival', 4) };
  const spread = Math.max(...Object.values(levels)) - Math.min(...Object.values(levels));
  assert.ok(spread <= 2.3, `spread ${spread.toFixed(2)} LU: ${JSON.stringify(levels)}`);
});

test('trims follow the grid and never move the score: the same moves with or without them', async () => {
  const run = async trims => {
    const p = await page({}, { clip, trims });
    start(p, 'k', 'A', 1);
    let moved = false;
    await p.render(8, t => { if (!moved && t >= 3.1) { p.audio.song({ song: 'k', section: 'B', at: -1, quantum: 'bar', enter: 'same', tier: 3, reason: 'test' }); moved = true; } });
    const s = p.audio.state.score;
    return JSON.parse(JSON.stringify({ moves: s.moves.map(m => [m.section, +m.at.toFixed(6), m.entry]), audible: s.audible, slipped: s.slipped, trimDb: s.trimDb }));
  };
  const plain = await run(false), trimmed = await run(true);
  assert.deepEqual({ ...trimmed, trimDb: 0 }, { ...plain, trimDb: 0 });
  assert.equal(plain.trimDb, 0);
  assert.equal(trimmed.trimDb, trimFile.trims['k:B@3'] ?? 0, 'the section and tier now playing set the trim');
});
