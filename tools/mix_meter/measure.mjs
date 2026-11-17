// mix-balance: meters the game's music against its radio at the default levels, end to end. It loads the shipped
// players (web/audio/demon-score.js, demon-audio.js, comms-audio.js) into the offline renderer (offline-audio.mjs),
// plays the score and radio clips through the real graph (buses, music level, master, limiter) and measures the
// output with BS.1770 (loudness.mjs). Clips are decoded by ffmpeg.
//
//   node tools/mix_meter/measure.mjs [--seconds 24] [--music-level full] [--speech-level full] [--only k,c1]
//
// Prints one line per case and a JSON summary on the last line. Numbers are rendered estimates: see the fidelity
// notes in offline-audio.mjs. The whole run takes a few minutes; run it under forge-guard.
import { readFile } from 'node:fs/promises';
import { QUANTUM } from './offline-audio.mjs';
import { page, web } from './page.mjs';
import { loudness } from './loudness.mjs';

const args = process.argv.slice(2);
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };
const SECONDS = Number(option('seconds', 24));
const levels = { music: option('music-level', 'full'), speech: option('speech-level', 'full') };
const only = option('only', null)?.split(',') || null;
const comms = JSON.parse(await readFile(web('audio/comms/manifest.json'), 'utf8'));

const fmt = v => (Number.isFinite(v) ? v.toFixed(1) : '-inf');
const results = { levels, seconds: SECONDS, music: {}, speech: {}, mix: null };

// --- music: each case is a section at a mask tier, metered after a 1.5 s settle.
const cases = [];
for (const song of ['k', 'r', 'e', 'h']) for (const tier of [1, 2, 3, 4]) cases.push({ song, section: 'A', tier });
for (const song of ['c1', 'c2', 'c3', 'c4', 'c5']) cases.push({ song, section: 'core', tier: 4 });
cases.push({ song: 'menu', section: 'overture', tier: 4 }, { song: 'defeat', section: 'cackle', tier: 4 }, { song: 'coda', section: 'reprise', tier: 4 });
for (const c of cases) {
  if (only && !only.includes(c.song)) continue;
  const p = await page(levels);
  p.audio.song({ song: c.song, section: c.section, at: -1, quantum: 'bar', enter: 'start', tier: c.tier, reason: 'meter' });
  const out = await p.render(SECONDS);
  const skip = 1.5 * 48000;
  const m = loudness([out.L.subarray(skip), out.R.subarray(skip)]);
  const key = `${c.song}:${c.section}@${c.tier}`;
  results.music[key] = { integrated: +m.integrated.toFixed(2), shortTermMax: +m.shortTermMax.toFixed(2), peakDbfs: +m.peakDbfs.toFixed(2) };
  console.log(`music  ${key.padEnd(18)} I ${fmt(m.integrated)} LUFS  S-max ${fmt(m.shortTermMax)}  peak ${fmt(m.peakDbfs)} dBFS`);
}

// --- speech: a fixed sample of the bank (every 12th clip), back to back with 0.4 s gaps, through the radio bus.
const ids = Object.keys(comms.clips).sort().filter((_, i) => i % 12 === 0);
if (!only || only.includes('speech')) {
  const p = await page(levels);
  let next = 0, i = 0;
  const total = ids.reduce((s, id) => s + comms.clips[id].duration + .4, .5);
  const out = await p.render(total, t => {
    if (i < ids.length && t >= next) { const id = ids[i++]; p.comms.play(id, 5, comms.clips[id].kind === 'demon'); next = t + comms.clips[id].duration + .4; }
  });
  const m = loudness([out.L, out.R]);
  const mono = loudness([out.L]);
  results.speech = { clips: ids.length, integrated: +m.integrated.toFixed(2), integratedMonoChannel: +mono.integrated.toFixed(2), peakDbfs: +m.peakDbfs.toFixed(2),
    manifestMeanLufs: +(ids.reduce((s, id) => s + comms.clips[id].lufs, 0) / ids.length).toFixed(2) };
  console.log(`speech ${ids.length} clips  I ${fmt(m.integrated)} LUFS (stereo out; one channel ${fmt(mono.integrated)})  peak ${fmt(m.peakDbfs)} dBFS`);
}

// --- mix: Krybor A at tier 3 with a radio line every 4 s; the music bus is tapped to trace the duck.
if (!only || only.includes('mix')) {
  const p = await page(levels);
  p.audio.song({ song: 'k', section: 'A', at: -1, quantum: 'bar', enter: 'start', tier: 3, reason: 'meter' });
  const graph = p.audio.graph;
  const tapNode = graph.duck || graph.music;
  const frames = Math.round(SECONDS * 48000 / QUANTUM) * QUANTUM;
  const tap = p.context.tap(tapNode, frames);
  const line = ids.find(id => comms.clips[id].kind !== 'demon' && comms.clips[id].duration > 1.5);
  const lines = [];
  const out = await p.render(SECONDS, t => {
    if (t >= 4 * (lines.length + 1) && lines.length < Math.floor(SECONDS / 4) - 1) { p.comms.play(line, 5, false); lines.push(t); }
  });
  const m = loudness([out.L.subarray(48000 * 1.5), out.R.subarray(48000 * 1.5)]);
  const trace = loudness([tap.L, tap.R]).momentary;
  results.mix = { line, duration: comms.clips[line].duration, lineStarts: lines.map(t => +t.toFixed(3)), integrated: +m.integrated.toFixed(2),
    musicMomentary: trace.map(v => +v.toFixed(1)), duckState: p.audio.state.duck ?? null };
  console.log(`mix    k:A@3 + "${line}" every 4 s  I ${fmt(m.integrated)} LUFS; music-bus momentary (100 ms steps): ${trace.slice(0, 80).map(v => fmt(v)).join(' ')}`);
}
console.log(JSON.stringify(results));
