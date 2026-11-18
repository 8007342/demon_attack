// bass-tone: measures the sampled bass's amp chain (adaptive-soundtrack design §12.12, plan/bass-tone-research.md)
// through the shipped players and the offline renderer. The candidates are data: art/music/bank/bass-tone.json
// (`candidates`, `pick`); the pick is copied into art/music/bank/recipe.json `roles.bass.tone`, which bank_build.lua
// writes into web/audio/bank/bank.json.
//
//   node tools/mix_meter/bass_tone.mjs sine [--tone NAME|clean] [--phone]
//     Each tone's chain alone on sine tones at the bass's notes (E1 41 Hz, A1 55, E2 82, A2 110) and in the driven band
//     (220, 440: the notes' upper partials) at three levels
//     (the DI's median, p95 and peak note level at the chain input, measured below): THD+N at every stage's output
//     (everything but the fundamental, re the stage's output, Blackman-Harris window), and the shaper's input peak.
//
//   node tools/mix_meter/bass_tone.mjs stages [--tone NAME|clean|all] [--cases k:B@3,c1:core@4] [--seconds 8] [--phone]
//     The bank's bass alone through each tone: per stage, peak, RMS (dBFS) and the energy in octave bands (dB re
//     the stage's total), the shaper's input peak and nonlinear residual (THD+N across the shaper on the music).
//
//   node tools/mix_meter/bass_tone.mjs match [--tone NAME] [--cases ...] [--solo bass|bass+drums|all] [--seconds 12]
//     Integrated loudness of the synth and of the bank with the tone, per case, and the median gap: the `output`
//     gain that puts the sampled bass at the synth's loudness (trims off in both modes).
//
//   node tools/mix_meter/bass_tone.mjs clips --out DIR [--tones synth,clean,subtle,classic,doom] [--cases ...] [--solo ...]
//        [--lufs -18]
//     float32 stereo renders (<case>.<solo>.<tone>.f32) for the A/B page, each scaled to --lufs integrated (one
//     loudness per strip), plus a TSV of their loudness, the gain applied and the resulting peak.
//
// The renderer ignores WaveShaperNode.oversample (offline-audio.mjs), so aliasing counts in the THD+N here: the
// browser's 2x/4x numbers are at most these. --phone builds the phone tier's variant (tone.phone overrides).
// Runs for minutes: wrap it in forge-guard.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { OfflineContext } from './offline-audio.mjs';
import { page, web } from './page.mjs';
import { loudness } from './loudness.mjs';

const args = process.argv.slice(2);
const mode = args[0];
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };
const phone = args.includes('--phone');
const toneFile = JSON.parse(await readFile(new URL('../../art/music/bank/bass-tone.json', import.meta.url), 'utf8'));
const tones = { synth: null, clean: null, ...toneFile.candidates };
const toneNames = name => (name === 'all' ? Object.keys(tones) : name.split(','));
const cases = option('cases', 'k:B@3,c1:core@4,h:A@4,k:A@1').split(',');
const seconds = Number(option('seconds', 8));
const dB = v => (v > 0 ? 20 * Math.log10(v) : -Infinity);
const fmt = v => (Number.isFinite(v) ? v.toFixed(1) : '-');

// --- a radix-2 FFT (in place, re/im Float64Array) and a Blackman-Harris window
function fft(re, im) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const a = -2 * Math.PI / len, wr = Math.cos(a), wi = Math.sin(a);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const ur = re[i + k], ui = im[i + k], j = i + k + len / 2;
        const vr = re[j] * cr - im[j] * ci, vi = re[j] * ci + im[j] * cr;
        re[i + k] = ur + vr; im[i + k] = ui + vi; re[j] = ur - vr; im[j] = ui - vi;
        const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
      }
    }
  }
}
const bh = n => Float64Array.from({ length: n }, (_, i) => { const x = 2 * Math.PI * i / (n - 1); return .35875 - .48829 * Math.cos(x) + .14128 * Math.cos(2 * x) - .01168 * Math.cos(3 * x); });
// Power spectrum of one block (mono).
function power(x, from, n, win) {
  const re = new Float64Array(n), im = new Float64Array(n);
  for (let i = 0; i < n; i++) re[i] = (x[from + i] || 0) * win[i];
  fft(re, im);
  const p = new Float64Array(n / 2);
  for (let k = 0; k < n / 2; k++) p[k] = re[k] * re[k] + im[k] * im[k];
  return p;
}
// THD+N of a steady sine: everything but the fundamental's main lobe (±4 bins of BH) and DC, re the total.
function thdn(x, f0, rate = 48000) {
  const n = 32768, p = power(x, x.length - n, n, bh(n)), k0 = Math.round(f0 * n / rate);
  let total = 0, fund = 0;
  for (let k = 3; k < p.length; k++) { total += p[k]; if (Math.abs(k - k0) <= 4) fund += p[k]; }
  return 10 * Math.log10(Math.max(1e-30, (total - fund) / total));
}
const BANDS = [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000];
// Welch-averaged octave-band energy (dB re the total) over a mono signal.
function bands(x, rate = 48000) {
  const n = 8192, win = bh(n), acc = new Float64Array(n / 2);
  for (let from = 0; from + n <= x.length; from += n / 2) { const p = power(x, from, n, win); for (let k = 0; k < acc.length; k++) acc[k] += p[k]; }
  let total = 0; for (let k = 1; k < acc.length; k++) total += acc[k];
  return BANDS.map(fc => {
    const lo = Math.round(fc / Math.SQRT2 * n / rate), hi = Math.round(fc * Math.SQRT2 * n / rate);
    let e = 0; for (let k = Math.max(1, lo); k < hi && k < acc.length; k++) e += acc[k];
    return 10 * Math.log10(Math.max(1e-30, e / Math.max(total, 1e-30)));
  });
}
const mono = t => Float32Array.from(t.L, (v, i) => .5 * (v + t.R[i]));
const stats = x => { let pk = 0, ss = 0; for (const v of x) { const a = Math.abs(v); if (a > pk) pk = a; ss += v * v; } return { peak: pk, rms: Math.sqrt(ss / Math.max(1, x.length)) }; };

// The shaper probe: input peak and the residual no linear gain of the input explains.
function probeShapers() {
  const proto = OfflineContext.prototype, make = proto.createWaveShaper, list = [];
  proto.createWaveShaper = function () {
    const s = make.call(this), process = s.process.bind(s);
    s.stat = { sxx: 0, sxy: 0, syy: 0, peak: 0 };
    s.process = () => {
      const x = s.input(), copy = x.map(ch => Float32Array.from(ch));
      s.input = () => x;
      const y = process();
      delete s.input;
      for (let c = 0; c < y.length; c++) for (let i = 0; i < y[c].length; i++) {
        const a = copy[c][i], b = y[c][i];
        s.stat.sxx += a * a; s.stat.sxy += a * b; s.stat.syy += b * b; s.stat.peak = Math.max(s.stat.peak, Math.abs(a));
      }
      return y;
    };
    list.push(s);
    return s;
  };
  return list;
}
const residual = st => (st && st.syy > 1e-12 ? 10 * Math.log10(Math.max(1e-30, st.syy - st.sxy * st.sxy / Math.max(st.sxx, 1e-30)) / st.syy) : null);

const withTone = tone => bank => {
  const roles = { ...bank.roles, bass: { ...bank.roles.bass } };
  if (tone) roles.bass.tone = tone; else delete roles.bass.tone;
  return { ...bank, roles };
};
const soloFilter = solo => {
  const roles = solo === 'all' ? null : solo.split('+');
  if (!roles) return null;
  return map => {
    const keep = name => roles.includes(map.tracks[name]?.role);
    const list = l => (Array.isArray(l) ? l.filter(keep) : l);
    const masks = m => (m ? Object.fromEntries(Object.entries(m).map(([k, v]) => [k, list(v)])) : m);
    map.masks = masks(map.masks);
    for (const k of Object.keys(map.layers)) map.layers[k] = list(map.layers[k]);
    for (const song of Object.values(map.songs)) {
      song.masks = masks(song.masks);
      for (const s of Object.values(song.sections)) { s.masks = masks(s.masks); s.tracks = list(s.tracks); }
    }
    return map;
  };
};
// One case through the shipped players; `taps(p, frames)` picks nodes to listen to after the page is built.
async function renderCase(key, { bank, tone, solo = 'bass', secs = seconds, taps = null, trims = true }) {
  const [song, rest] = key.split(':'), [section, tier] = rest.split('@');
  const p = await page({ music: 'full', speech: 'full' }, { bank, trims, scoreFilter: soloFilter(solo), bankFilter: bank ? withTone(tone) : null, phone });
  p.audio.song({ song, section, at: -1, quantum: 'bar', enter: 'start', tier: Number(tier || 4), reason: 'bass-tone' });
  const frames = Math.round((secs + .5) * 48000 / 128) * 128;
  const tapped = taps ? taps(p, frames) : {};
  const out = await p.render(secs + .5);
  const from = Math.round(.5 * 48000);
  const cut = t => ({ L: t.L.subarray(from), R: t.R.subarray(from) });
  return { p, out: cut(out), taps: Object.fromEntries(Object.entries(tapped).map(([k, t]) => [k, cut(t)])) };
}
const STAGES = ['input', 'comp', 'low', 'grindIn', 'pre', 'shaper', 'grind', 'output'];

if (mode === 'stages') {
  console.log(['tone', 'case', 'stage', 'peak_dbfs', 'rms_dbfs', ...BANDS.map(b => `oct${b}`), 'shaper_in_peak', 'shaper_residual_db'].join('\t'));
  for (const name of toneNames(option('tone', 'all'))) {
    for (const key of cases) {
      const shapers = probeShapers();
      const r = await renderCase(key, { bank: name !== 'synth', tone: tones[name], taps: (p, frames) => {
        const g = p.audio.graph.bassTone;
        if (!g) return { output: p.context.tap(p.audio.graph.master, frames) };
        return Object.fromEntries(STAGES.filter(s => g.stages[s]).map(s => [s, p.context.tap(g.stages[s], frames)]));
      } });
      const sh = shapers.find(s => s.curve && r.p.audio.graph.bassTone?.stages.shaper === s);
      for (const [stage, t] of Object.entries(r.taps)) {
        const x = mono(t), s = stats(x);
        console.log([name, key, tones[name] ? stage : 'master', fmt(dB(s.peak)), fmt(dB(s.rms)), ...bands(x).map(fmt),
          stage === 'shaper' && sh ? sh.stat.peak.toFixed(3) : '-', stage === 'shaper' && sh ? fmt(residual(sh.stat)) : '-'].join('\t'));
      }
    }
  }
  process.exit(0);
}

if (mode === 'sine') {
  // The DI's note levels at the chain input (`input` stage with input gain 1 would be the bus): from toneFile.levels.
  const levels = toneFile.levels;   // { median, p95, peak } of the chain's input, measured by `stages` on the clean bus
  const builder = (await page()).window.demonScore.bassTone;
  console.log(['tone', 'hz', 'level', 'amp', 'shaper_in_peak', ...STAGES.map(s => `thdn_${s}`)].join('\t'));
  for (const name of toneNames(option('tone', 'all')).filter(n => tones[n])) {
    for (const hz of [41.2, 55, 82.4, 110, 220, 440]) {
      for (const [label, amp] of Object.entries(levels)) {
        const ctx = new OfflineContext({ sampleRate: 48000 });
        const shapers = probeShapers();
        const g = builder(ctx, tones[name], { phone });
        const osc = ctx.createOscillator(); osc.type = 'sine'; osc.frequency.value = hz;
        const a = ctx.createGain(); a.gain.value = amp; osc.connect(a); a.connect(g.input); osc.start(0);
        g.output.connect(ctx.destination);
        const frames = 128 * 563, taps = Object.fromEntries(STAGES.filter(s => g.stages[s]).map(s => [s, ctx.tap(g.stages[s], frames)]));
        const L = new Float32Array(frames), R = new Float32Array(frames);
        for (let f = 0; f < frames; f += 128) ctx.renderQuantum(L, R, f);
        const sh = shapers[0];
        console.log([name, hz, label, amp, sh ? sh.stat.peak.toFixed(3) : '-', ...STAGES.map(s => (taps[s] ? fmt(thdn(taps[s].L, hz)) : '-'))].join('\t'));
      }
    }
  }
  process.exit(0);
}

if (mode === 'match') {
  const solo = option('solo', 'bass');
  const name = option('tone', toneFile.pick);
  const secs = Number(option('seconds', 12));
  console.log(['case', 'solo', 'synth_lufs', `bank_${name}_lufs`, 'gap_db', 'synth_peak', 'bank_peak'].join('\t'));
  const gaps = [];
  for (const key of cases) {
    // Trims off: each mode's trims would move its level (the role match is made before the trims, design §12.11).
    const s = await renderCase(key, { bank: false, solo, secs, trims: false });
    const b = await renderCase(key, { bank: true, tone: tones[name], solo, secs, trims: false });
    const ls = loudness([s.out.L, s.out.R]), lb = loudness([b.out.L, b.out.R]);
    gaps.push(ls.integrated - lb.integrated);
    console.log([key, solo, ls.integrated.toFixed(2), lb.integrated.toFixed(2), (ls.integrated - lb.integrated).toFixed(2), ls.peakDbfs.toFixed(2), lb.peakDbfs.toFixed(2)].join('\t'));
  }
  gaps.sort((x, y) => x - y);
  console.log(`median gap ${gaps[Math.floor(gaps.length / 2)].toFixed(2)} dB`);
  process.exit(0);
}

if (mode === 'clips') {
  const outDir = option('out', null);
  if (!outDir) { console.error('clips needs --out DIR'); process.exit(2); }
  await mkdir(outDir, { recursive: true });
  const solo = option('solo', 'bass');
  const secs = Number(option('seconds', 12));
  const list = option('tones', 'synth,clean,subtle,classic,doom').split(',');
  const target = Number(option('lufs', -18));
  console.log(['case', 'solo', 'mode', 'lufs', 'peak_dbfs', 'gain_db', 'peak_after_dbfs'].join('\t'));
  for (const key of cases) {
    for (const name of list) {
      const r = name === 'synth' ? await renderCase(key, { bank: false, solo, secs }) : await renderCase(key, { bank: true, tone: tones[name], solo, secs });
      const m = loudness([r.out.L, r.out.R]);
      const gain = 10 ** ((target - m.integrated) / 20);
      console.log([key, solo, name, m.integrated.toFixed(2), m.peakDbfs.toFixed(2), (target - m.integrated).toFixed(2), (m.peakDbfs + target - m.integrated).toFixed(2)].join('\t'));
      const buf = new Float32Array(r.out.L.length * 2);
      for (let i = 0; i < r.out.L.length; i++) { buf[2 * i] = r.out.L[i] * gain; buf[2 * i + 1] = r.out.R[i] * gain; }
      await writeFile(`${outDir}/${key.replace(/[:@]/g, '_')}.${solo.replace(/\+/g, '-')}.${name}.f32`, Buffer.from(buf.buffer));
    }
  }
  process.exit(0);
}
console.error('usage: node tools/mix_meter/bass_tone.mjs sine|stages|match|clips [options]');
process.exit(2);
