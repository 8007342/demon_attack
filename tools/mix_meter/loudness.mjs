// ITU-R BS.1770-4 loudness of 48 kHz audio: K-weighting (the standard's 48 kHz coefficients), 400 ms blocks with
// 75 % overlap, the -70 LUFS absolute gate and the -10 LU relative gate. Channels are summed with weight 1 (L, R).
// Also the maximum momentary (400 ms) and short-term (3 s) loudness and the sample peak.
const SHELF = { b: [1.53512485958697, -2.69169618940638, 1.19839281085285], a: [-1.69065929318241, 0.73248077421585] };
const HIGHPASS = { b: [1, -2, 1], a: [-1.99004745483398, 0.99007225036621] };

function biquad(x, { b, a }) {
  const y = new Float64Array(x.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const v = x[i], o = b[0] * v + b[1] * x1 + b[2] * x2 - a[0] * y1 - a[1] * y2;
    x2 = x1; x1 = v; y2 = y1; y1 = o; y[i] = o;
  }
  return y;
}
const toLufs = power => (power > 0 ? -0.691 + 10 * Math.log10(power) : -Infinity);

// channels: Float32Array[] at 48 kHz.
export function loudness(channels, sampleRate = 48000) {
  if (sampleRate !== 48000) throw new Error('loudness(): 48 kHz only');
  const weighted = channels.map(c => biquad(biquad(c, SHELF), HIGHPASS));
  const n = channels[0].length, step = sampleRate / 10;
  // Mean square per 100 ms step, summed over channels.
  const steps = [];
  for (let s = 0; s + step <= n; s += step) {
    let sum = 0;
    for (const w of weighted) for (let i = s; i < s + step; i++) sum += w[i] * w[i];
    steps.push(sum / step);
  }
  const blocks = [];
  for (let i = 0; i + 4 <= steps.length; i++) blocks.push((steps[i] + steps[i + 1] + steps[i + 2] + steps[i + 3]) / 4);
  const shortTerm = [];
  for (let i = 0; i + 30 <= steps.length; i++) { let s = 0; for (let k = 0; k < 30; k++) s += steps[i + k]; shortTerm.push(s / 30); }
  const absolute = blocks.filter(p => toLufs(p) > -70);
  const mean = list => list.reduce((a, b) => a + b, 0) / (list.length || 1);
  const relative = toLufs(mean(absolute)) - 10;
  const gated = absolute.filter(p => toLufs(p) > relative);
  let peak = 0;
  for (const c of channels) for (let i = 0; i < c.length; i++) peak = Math.max(peak, Math.abs(c[i]));
  return {
    integrated: gated.length ? toLufs(mean(gated)) : -Infinity,
    momentaryMax: blocks.length ? toLufs(Math.max(...blocks)) : -Infinity,
    shortTermMax: shortTerm.length ? toLufs(Math.max(...shortTerm)) : -Infinity,
    peakDbfs: peak > 0 ? 20 * Math.log10(peak) : -Infinity,
    // Momentary loudness per 100 ms step (for the duck trace).
    momentary: blocks.map(toLufs),
  };
}
