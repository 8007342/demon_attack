// bank-fidelity: the sample bank's runtime audit (adaptive-soundtrack design §12.11, step 5). Two modes:
//
//   node tools/mix_meter/bank_fidelity.mjs rates [--web-root DIR]
//     Every note of every section that the bank would play, in plan order (desktop tier): the playbackRate each zone
//     is played at (semitones from its root, weighted by notes), and the notes held longer than an unlooped zone lasts.
//
//   node tools/mix_meter/bank_fidelity.mjs render [--web-root DIR] [--mode synth|bank] [--cases k:B@3,c1:core@4]
//        [--solo all|ROLE[+ROLE]] [--seconds 12] [--trims 1|0] [--out DIR]
//     Renders each case offline through the shipped players (page.mjs; each mode with its own trims) and prints, per
//     case: integrated LUFS and peak at the output, the master bus before the limiter (peak, samples over 0 dBFS),
//     the limiter (deepest gain reduction, share of time reducing more than 0.5 dB) and the bass bus's wave shaper
//     (input peak, and its nonlinear residual: the output energy that no linear gain of the input explains, in dB re
//     the output, i.e. THD+N across that stage). --out writes each render as float32 stereo (<case>.f32) for the A/B page.
//
// --web-root DIR serves the players, score and bank from another tree (an earlier build checked out with
// `git archive`), so the old and the new bank render through their own code. Runs for minutes: use forge-guard.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { OfflineContext } from './offline-audio.mjs';
import { page, web } from './page.mjs';
import { loudness } from './loudness.mjs';

const args = process.argv.slice(2);
const mode = args[0];
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };
const rootDir = option('web-root', null);
const webRoot = rootDir ? pathToFileURL(rootDir.endsWith('/') ? rootDir : `${rootDir}/`) : null;
const read = path => readFile(webRoot ? new URL(path, webRoot) : web(path), 'utf8');

if (mode === 'rates') {
  const map = JSON.parse(await read('audio/score/score.json'));
  const bank = JSON.parse(await read('audio/bank/bank.json'));
  const p = await page({ music: 'full', speech: 'full' }, { webRoot });
  const parse = p.window.demonScore.parseScore;
  const insts = bank.instruments.map(inst => ({ ...inst, byPitch: new Map() }));
  const byId = new Map(insts.map(i => [i.id, i]));
  for (const z of bank.zones) {
    const inst = byId.get(z.inst);
    const keys = z.keys || Array.from({ length: z.hi - z.lo + 1 }, (_, i) => z.lo + i);
    for (const k of keys) { if (!inst.byPitch.has(k)) inst.byPitch.set(k, []); inst.byPitch.get(k).push(z); }
  }
  const instrumentFor = (role, pitch, vel, seconds) => {
    const tones = role === 'drums' ? [0] : bank.roles[role]?.chord || [0];
    for (const inst of insts) {
      if (!inst.roles.includes(role)) continue;
      const w = inst.when;
      if (w && ((w.velMax != null && vel > w.velMax) || (w.durMax != null && seconds > w.durMax))) continue;
      if (tones.every(t => inst.byPitch.has(pitch + t))) return inst;
    }
    return null;
  };
  const stats = new Map();   // inst -> { notes, hist: Map(semitones rounded -> n), truncated, maxShift }
  for (const [songId, song] of Object.entries(map.songs)) {
    const bs = song.barSamples / 48000 / 4;
    for (const s of Object.values(song.sections)) {
      const score = parse((await readFile(webRoot ? new URL(`audio/score/${s.file}`, webRoot) : web(`audio/score/${s.file}`))).buffer);
      for (const [name, notes] of Object.entries(score.tracks)) {
        const role = map.tracks[name]?.role;
        if (!role || !bank.roles[role]) continue;
        // The player samples a track only if every note is covered.
        const plan = notes.map(n => instrumentFor(role, n.pitch, n.vel, n.len * bs));
        if (plan.some(i => !i)) continue;
        notes.forEach((n, k) => {
          const inst = plan[k], tones = role === 'drums' ? [0] : bank.roles[role]?.chord || [0];
          const st = stats.get(inst.id) || { notes: 0, hist: new Map(), truncated: 0, maxShift: 0, abs: 0 };
          stats.set(inst.id, st);
          for (const t of tones) {
            const zones = inst.byPitch.get(n.pitch + t);
            const z = zones.find(z => n.vel >= z.vlo && n.vel <= z.vhi) || zones[0];
            const shift = z.keys ? 0 : n.pitch + t - z.root;
            st.notes++;
            st.hist.set(shift, (st.hist.get(shift) || 0) + 1);
            st.abs += Math.abs(shift);
            st.maxShift = Math.max(st.maxShift, Math.abs(shift));
            const rate = 2 ** (shift / 12);
            if (inst.art !== 'hit' && !z.loop && n.len * bs > z.length / rate) st.truncated++;
          }
        });
      }
    }
  }
  console.log('inst\tnotes\tmean_abs_semitones\tshare_within_1.5\tshare_beyond_3\tmax_semitones\ttruncated_notes\thistogram');
  for (const [id, st] of stats) {
    let within = 0, beyond = 0;
    for (const [s, n] of st.hist) { if (Math.abs(s) <= 1.5) within += n; if (Math.abs(s) > 3) beyond += n; }
    const hist = [...st.hist].sort((a, b) => a[0] - b[0]).map(([s, n]) => `${s}:${n}`).join(' ');
    console.log([id, st.notes, (st.abs / st.notes).toFixed(2), (within / st.notes).toFixed(3), (beyond / st.notes).toFixed(3), st.maxShift, st.truncated, hist].join('\t'));
  }
  process.exit(0);
}

if (mode === 'render') {
  const bankOn = option('mode', 'bank') === 'bank';
  const solo = option('solo', 'all');
  const seconds = Number(option('seconds', 12));
  const outDir = option('out', null);
  const cases = option('cases', 'k:A@1,k:B@3,c1:core@4,h:A@4,k:clear,menu:overture').split(',');
  if (outDir) await mkdir(outDir, { recursive: true });
  // Probes on the offline renderer: every wave shaper (the score's first is the bass bus's) and the limiter.
  const probe = { shapers: [], limiter: null };
  const proto = OfflineContext.prototype;
  const makeShaper = proto.createWaveShaper, makeLimiter = proto.createDynamicsCompressor;
  proto.createWaveShaper = function () {
    const s = makeShaper.call(this);
    const process = s.process.bind(s);
    s.stat = { sxx: 0, sxy: 0, syy: 0, peak: 0 };
    s.process = () => {
      const x = s.input();
      const copy = x.map(ch => Float32Array.from(ch));
      s.input = () => x;          // process() pulls the same block once
      const y = process();
      delete s.input;
      for (let c = 0; c < y.length; c++) for (let i = 0; i < y[c].length; i++) {
        const a = copy[c][i], b = y[c][i];
        s.stat.sxx += a * a; s.stat.sxy += a * b; s.stat.syy += b * b; s.stat.peak = Math.max(s.stat.peak, Math.abs(a));
      }
      return y;
    };
    probe.shapers.push(s);
    return s;
  };
  proto.createDynamicsCompressor = function () {
    const c = makeLimiter.call(this);
    const process = c.process.bind(c);
    c.stat = { blocks: 0, reducing: 0 };
    c.process = () => { const y = process(); c.stat.blocks++; if (c.env < -.5) c.stat.reducing++; return y; };
    probe.limiter = c;
    return c;
  };
  // Solo: keep only the tracks of the soloed roles in every mask and track list (the player schedules nothing else).
  const roles = solo === 'all' ? null : solo.split('+');
  const scoreFilter = roles ? map => {
    const keep = name => roles.includes(map.tracks[name]?.role);
    const filterList = list => (Array.isArray(list) ? list.filter(keep) : list);
    const filterMasks = masks => (masks ? Object.fromEntries(Object.entries(masks).map(([k, v]) => [k, filterList(v)])) : masks);
    map.masks = filterMasks(map.masks);
    for (const k of Object.keys(map.layers)) map.layers[k] = filterList(map.layers[k]);
    for (const song of Object.values(map.songs)) {
      song.masks = filterMasks(song.masks);
      for (const s of Object.values(song.sections)) { s.masks = filterMasks(s.masks); s.tracks = filterList(s.tracks); }
    }
    return map;
  } : null;
  const dB = v => (v > 0 ? 20 * Math.log10(v) : -Infinity);
  console.log('case\tmode\tsolo\tlufs\tpeak_dbfs\tmaster_peak_dbfs\tmaster_overs\tlimiter_max_gr_db\tlimiter_active_share\tbass_shaper_in_peak\tbass_shaper_residual_db\tsampled_notes');
  for (const key of cases) {
    probe.shapers = []; probe.limiter = null;
    const [song, rest] = key.split(':'), [section, tier] = rest.split('@');
    const p = await page({ music: 'full', speech: 'full' }, { bank: bankOn, webRoot, scoreFilter, trims: option('trims', '1') !== '0' });
    const shapers = probe.shapers.slice(), limiter = probe.limiter;
    for (const s of shapers) Object.assign(s.stat, { sxx: 0, sxy: 0, syy: 0, peak: 0 });
    p.audio.song({ song, section, at: -1, quantum: 'bar', enter: 'start', tier: Number(tier || 4), reason: 'audit' });
    const frames = Math.round((seconds + .5) * 48000 / 128) * 128;
    const tap = p.context.tap(p.audio.graph.master, frames);
    const out = await p.render(seconds + .5);
    const from = Math.round(.5 * 48000);
    const L = out.L.subarray(from), R = out.R.subarray(from);
    const m = loudness([L, R]);
    let mpeak = 0, overs = 0;
    for (const ch of [tap.L, tap.R]) for (let i = from; i < ch.length; i++) { const a = Math.abs(ch[i]); if (a > mpeak) mpeak = a; if (a > 1) overs++; }
    const bassShaper = shapers[0];
    const st = bassShaper?.stat;
    // Nonlinear residual: syy - sxy^2/sxx is what no linear gain of the input explains.
    const residual = st && st.peak > 1e-4 && st.syy > 1e-12 ? 10 * Math.log10(Math.max(1e-30, st.syy - st.sxy * st.sxy / Math.max(st.sxx, 1e-30)) / st.syy) : null;
    const state = p.audio.state.score;
    console.log([key, bankOn ? 'bank' : 'synth', solo, m.integrated.toFixed(2), m.peakDbfs.toFixed(2), dB(mpeak).toFixed(2), overs,
      limiter ? limiter.maxReduction.toFixed(2) : '-', limiter ? (limiter.stat.reducing / Math.max(1, limiter.stat.blocks)).toFixed(3) : '-',
      st && st.peak > 1e-4 ? st.peak.toFixed(2) : '-', residual === null ? '-' : residual.toFixed(1), state.bank?.sampled ?? 0].join('\t'));
    if (outDir) {
      const buf = new Float32Array(L.length * 2);
      for (let i = 0; i < L.length; i++) { buf[2 * i] = L[i]; buf[2 * i + 1] = R[i]; }
      await writeFile(`${outDir}/${key.replace(/[:@]/g, '_')}.f32`, Buffer.from(buf.buffer));
    }
  }
  process.exit(0);
}
console.error('usage: node tools/mix_meter/bank_fidelity.mjs rates|render [options]');
process.exit(2);
