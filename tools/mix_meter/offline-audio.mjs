// A small offline Web Audio renderer for loudness measurement (mix-balance). It implements the subset of the
// Web Audio API that web/audio/demon-audio.js, demon-score.js and comms-audio.js use, rendered in 128-frame blocks
// on a pull graph, so the real players can be metered in Node without a browser.
//
// Fidelity notes (what is approximated, so numbers from it are "rendered estimates", not browser captures):
// - oscillators use PolyBLEP saw/square (browsers use band-limited wavetables); triangle and sine are exact;
// - biquad coefficients are updated once per block (k-rate), not per sample; formulas follow the Web Audio spec;
// - the wave shaper ignores `oversample`;
// - the convolver is a uniformly partitioned FFT convolution with one partition (2048 frames, ~43 ms) of extra
//   latency, normalised as the spec's `normalize = true`;
// - the dynamics compressor is a peak limiter with the node's threshold/ratio/attack/release, a 6 ms look-ahead
//   and Chromium's automatic make-up gain; the detector holds peaks for the look-ahead; Chromium's knee and
//   adaptive release are not reproduced.
const QUANTUM = 128;

class AudioBuffer {
  constructor(channels, length, sampleRate) {
    this.numberOfChannels = channels; this.length = length; this.sampleRate = sampleRate;
    this.duration = length / sampleRate;
    this._data = Array.from({ length: channels }, () => new Float32Array(length));
  }
  getChannelData(c) { return this._data[c]; }
}

class AudioParam {
  constructor(ctx, value) {
    this.ctx = ctx; this.cur = value; this.events = []; this.idx = 0; this.mode = 'hold';
    this.T0 = 0; this.V0 = value; this.target = value; this.tc = 1; this.rs = { t: 0, v: value }; this.sources = [];
    this.buf = new Float32Array(QUANTUM);
  }
  get value() { return this.cur; }
  set value(v) {
    if (this.idx >= this.events.length && this.mode === 'hold') { this.cur = v; this.rs = { t: this.ctx.currentTime, v }; }
    else this.setValueAtTime(v, this.ctx.currentTime);
  }
  insert(e) {
    let i = this.events.length;
    while (i > this.idx && this.events[i - 1].time > e.time) i--;
    this.events.splice(i, 0, e);
    return this;
  }
  setValueAtTime(value, time) { return this.insert({ type: 'set', value, time }); }
  linearRampToValueAtTime(value, time) { return this.insert({ type: 'lin', value, time }); }
  exponentialRampToValueAtTime(value, time) { return this.insert({ type: 'exp', value, time }); }
  setTargetAtTime(value, time, tc) { return this.insert({ type: 'target', value, time, tc: Math.max(tc, 1e-6) }); }
  cancelScheduledValues(time) {
    for (let i = this.events.length - 1; i >= this.idx; i--) if (this.events[i].time >= time - 1e-12) this.events.splice(i, 1);
    return this;
  }
  // Value at time t, advancing the event pointer (times only move forward).
  step(t) {
    for (;;) {
      const e = this.events[this.idx];
      if (!e) break;
      if (e.type === 'lin' || e.type === 'exp') {
        if (t >= e.time) { this.cur = e.value; this.mode = 'hold'; this.idx++; this.rs = { t: e.time, v: e.value }; continue; }
        const { t: t0, v: v0 } = this.rs;
        const span = e.time - t0, x = span > 0 ? (t - t0) / span : 1;
        if (e.type === 'lin') this.cur = v0 + (e.value - v0) * x;
        else this.cur = (v0 > 0 && e.value > 0) || (v0 < 0 && e.value < 0) ? v0 * (e.value / v0) ** x : v0;
        return this.cur;
      }
      if (e.time > t) break;
      if (e.type === 'set') { this.cur = e.value; this.mode = 'hold'; }
      else { this.mode = 'target'; this.T0 = e.time; this.V0 = this.cur; this.target = e.value; this.tc = e.tc; }
      this.idx++;
      this.rs = { t: e.time, v: this.cur };
    }
    if (this.mode === 'target') {
      this.cur = this.target + (this.V0 - this.target) * Math.exp(-(t - this.T0) / this.tc);
      if (Math.abs(this.cur - this.target) < 1e-7) { this.cur = this.target; this.mode = 'hold'; }
      this.rs = { t, v: this.cur };
    }
    return this.cur;
  }
  // The block's values; `constant` when nothing moves (the fast path).
  block() {
    const ctx = this.ctx, sr = ctx.sampleRate, f0 = ctx.frame;
    if (this.idx > 32) { this.events.splice(0, this.idx); this.idx = 0; }
    const next = this.events[this.idx], blockEnd = (f0 + QUANTUM) / sr;
    // A ramp moves from the moment it is the next event; a set or target only from its own time.
    const idle = this.mode === 'hold' && (!next || ((next.type === 'set' || next.type === 'target') && next.time >= blockEnd));
    let constant = idle && !this.sources.length;
    if (idle) this.buf.fill(this.cur);
    else for (let i = 0; i < QUANTUM; i++) this.buf[i] = this.step((f0 + i) / sr);
    for (const s of this.sources) {
      const out = s.output();
      const n = out.length;
      for (let i = 0; i < QUANTUM; i++) { let v = 0; for (let c = 0; c < n; c++) v += out[c][i]; this.buf[i] += v / n; }
    }
    return { values: this.buf, constant };
  }
}

class Node {
  constructor(ctx, { channelCount = 2, channelCountMode = 'max', channelInterpretation = 'speakers' } = {}) {
    this.ctx = ctx; this.inputs = []; this.outputs = []; this.channelCount = channelCount;
    this.channelCountMode = channelCountMode; this.channelInterpretation = channelInterpretation;
    this._block = -1; this._out = null;
  }
  connect(dest) {
    if (dest instanceof AudioParam) dest.sources.push(this);
    else dest.inputs.push(this);
    this.outputs.push(dest);
    return dest;
  }
  disconnect() {
    for (const d of this.outputs) {
      const list = d instanceof AudioParam ? d.sources : d.inputs;
      const i = list.indexOf(this); if (i >= 0) list.splice(i, 1);
    }
    this.outputs = [];
  }
  output() {
    if (this._block === this.ctx.block) return this._out;
    this._block = this.ctx.block;
    this._out = this.process();
    return this._out;
  }
  // The summed input, up/down-mixed per the node's channel rules.
  input() {
    const outs = this.inputs.map(n => n.output());
    let channels = 1;
    for (const o of outs) channels = Math.max(channels, o.length);
    if (this.channelCountMode === 'explicit') channels = this.channelCount;
    else if (this.channelCountMode === 'clamped-max') channels = Math.min(channels, this.channelCount);
    const mix = Array.from({ length: channels }, () => new Float32Array(QUANTUM));
    for (const o of outs) {
      if (o.length === channels) for (let c = 0; c < channels; c++) { const d = mix[c], s = o[c]; for (let i = 0; i < QUANTUM; i++) d[i] += s[i]; }
      else if (o.length === 1) for (let c = 0; c < channels; c++) { const d = mix[c], s = o[0]; for (let i = 0; i < QUANTUM; i++) d[i] += s[i]; }
      else if (channels === 1) { const d = mix[0], l = o[0], r = o[1]; for (let i = 0; i < QUANTUM; i++) d[i] += .5 * (l[i] + r[i]); }
    }
    return mix;
  }
  process() { return this.input(); }
}

class Gain extends Node {
  constructor(ctx) { super(ctx); this.gain = new AudioParam(ctx, 1); }
  process() {
    const x = this.input(), { values, constant } = this.gain.block();
    if (constant) { const g = values[0]; if (g !== 1) for (const ch of x) for (let i = 0; i < QUANTUM; i++) ch[i] *= g; }
    else for (const ch of x) for (let i = 0; i < QUANTUM; i++) ch[i] *= values[i];
    return x;
  }
}

class Scheduled extends Node {
  constructor(ctx) { super(ctx); this.startAt = Infinity; this.stopAt = Infinity; this.ended = false; this.onended = null; }
  start(at = 0) { this.startAt = Math.max(at, 0); this.ctx.live.add(this); }
  stop(at = 0) { this.stopAt = Math.min(this.stopAt, at); }
  finish() { if (this.ended) return; this.ended = true; this.ctx.live.delete(this); this.ctx.endedQueue.push(this); }
}

const blep = (t, dt) => {
  if (t < dt) { t /= dt; return t + t - t * t - 1; }
  if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; }
  return 0;
};
class Oscillator extends Scheduled {
  constructor(ctx) { super(ctx); this.type = 'sine'; this.frequency = new AudioParam(ctx, 440); this.detune = new AudioParam(ctx, 0); this.phase = 0; }
  process() {
    const out = new Float32Array(QUANTUM), sr = this.ctx.sampleRate, f0 = this.ctx.frame;
    const fq = this.frequency.block(), dt = this.detune.block();
    if (this.ended) return [out];
    for (let i = 0; i < QUANTUM; i++) {
      const t = (f0 + i) / sr;
      if (t < this.startAt) continue;
      if (t >= this.stopAt) { this.finish(); break; }
      const hz = fq.values[i] * (dt.constant && dt.values[0] === 0 ? 1 : 2 ** (dt.values[i] / 1200));
      const inc = Math.min(Math.abs(hz) / sr, .5), p = this.phase;
      let v;
      switch (this.type) {
        case 'sine': v = Math.sin(2 * Math.PI * p); break;
        case 'square': v = (p < .5 ? 1 : -1) + blep(p, inc) - blep((p + .5) % 1, inc); break;
        case 'sawtooth': v = 2 * ((p + .5) % 1) - 1 - blep((p + .5) % 1, inc); break;
        case 'triangle': v = p < .25 ? 4 * p : p < .75 ? 2 - 4 * p : 4 * p - 4; break;
        default: v = Math.sin(2 * Math.PI * p);
      }
      out[i] = v;
      this.phase = (p + inc) % 1;
    }
    return [out];
  }
}

class BufferSource extends Scheduled {
  constructor(ctx) { super(ctx); this.buffer = null; this.playbackRate = new AudioParam(ctx, 1); this.pos = 0; this.loop = false; this.loopStart = 0; this.loopEnd = 0; this.endPos = Infinity; }
  // start(when, offset, duration) as the spec: offset and duration in seconds of buffer content (the sample bank's
  // sprite zones); loop between loopStart and loopEnd (the whole buffer when loopEnd is 0).
  start(at = 0, offset = 0, duration) {
    super.start(at);
    const bsr = this.buffer?.sampleRate || this.ctx.sampleRate;
    this.pos = Math.max(0, offset) * bsr;
    if (duration !== undefined) this.endPos = this.pos + Math.max(0, duration) * bsr;
  }
  process() {
    const sr = this.ctx.sampleRate, f0 = this.ctx.frame, rate = this.playbackRate.block().values[0];
    const channels = this.buffer?.numberOfChannels || 1;
    const out = Array.from({ length: channels }, () => new Float32Array(QUANTUM));
    if (this.ended || !this.buffer) return out;
    const step = rate * this.buffer.sampleRate / sr, len = this.buffer.length, bsr = this.buffer.sampleRate;
    const loopA = this.loopStart * bsr, loopB = this.loopEnd > 0 ? Math.min(this.loopEnd * bsr, len - 1) : len - 1;
    for (let i = 0; i < QUANTUM; i++) {
      const t = (f0 + i) / sr;
      if (t < this.startAt) continue;
      if (this.loop && this.pos >= loopB && loopB > loopA) this.pos = loopA + (this.pos - loopB) % (loopB - loopA);
      if (t >= this.stopAt || this.pos >= len - 1 || (!this.loop && this.pos >= this.endPos)) { this.finish(); break; }
      const k = Math.floor(this.pos), fr = this.pos - k;
      for (let c = 0; c < channels; c++) { const d = this.buffer.getChannelData(c); out[c][i] = d[k] + (d[k + 1] - d[k]) * fr; }
      this.pos += step;
    }
    return out;
  }
}

class Biquad extends Node {
  constructor(ctx) {
    super(ctx); this.type = 'lowpass';
    this.frequency = new AudioParam(ctx, 350); this.Q = new AudioParam(ctx, 1); this.gain = new AudioParam(ctx, 0); this.detune = new AudioParam(ctx, 0);
    this.state = [];
  }
  coefficients() {
    const sr = this.ctx.sampleRate, nyq = sr / 2;
    const f = Math.min(Math.max(this.frequency.block().values[0], 0), nyq), Q = this.Q.block().values[0], G = this.gain.block().values[0];
    const w0 = 2 * Math.PI * f / sr, cos = Math.cos(w0), sin = Math.sin(w0), A = 10 ** (G / 40);
    let b0, b1, b2, a0, a1, a2;
    if (f >= nyq - 1e-6 && this.type === 'lowpass') return [1, 0, 0, 0, 0];
    switch (this.type) {
      case 'lowpass': { const al = sin / (2 * 10 ** (Q / 20)); b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = b0; a0 = 1 + al; a1 = -2 * cos; a2 = 1 - al; break; }
      case 'highpass': { const al = sin / (2 * 10 ** (Q / 20)); b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = b0; a0 = 1 + al; a1 = -2 * cos; a2 = 1 - al; break; }
      case 'bandpass': { const al = sin / (2 * Q); b0 = al; b1 = 0; b2 = -al; a0 = 1 + al; a1 = -2 * cos; a2 = 1 - al; break; }
      case 'peaking': { const al = sin / (2 * Q); b0 = 1 + al * A; b1 = -2 * cos; b2 = 1 - al * A; a0 = 1 + al / A; a1 = -2 * cos; a2 = 1 - al / A; break; }
      case 'highshelf': {
        const al = sin / 2 * Math.sqrt(2), s = 2 * Math.sqrt(A) * al;
        b0 = A * ((A + 1) + (A - 1) * cos + s); b1 = -2 * A * ((A - 1) + (A + 1) * cos); b2 = A * ((A + 1) + (A - 1) * cos - s);
        a0 = (A + 1) - (A - 1) * cos + s; a1 = 2 * ((A - 1) - (A + 1) * cos); a2 = (A + 1) - (A - 1) * cos - s; break;
      }
      case 'lowshelf': {
        const al = sin / 2 * Math.sqrt(2), s = 2 * Math.sqrt(A) * al;
        b0 = A * ((A + 1) - (A - 1) * cos + s); b1 = 2 * A * ((A - 1) - (A + 1) * cos); b2 = A * ((A + 1) - (A - 1) * cos - s);
        a0 = (A + 1) + (A - 1) * cos + s; a1 = -2 * ((A - 1) + (A + 1) * cos); a2 = (A + 1) + (A - 1) * cos - s; break;
      }
      default: return [1, 0, 0, 0, 0];
    }
    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
  }
  process() {
    const x = this.input(), [b0, b1, b2, a1, a2] = this.coefficients();
    for (let c = 0; c < x.length; c++) {
      const s = this.state[c] || (this.state[c] = [0, 0, 0, 0]), d = x[c];
      let [x1, x2, y1, y2] = s;
      for (let i = 0; i < QUANTUM; i++) {
        const v = d[i], y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
        x2 = x1; x1 = v; y2 = y1; y1 = Math.abs(y) < 1e-25 ? 0 : y; d[i] = y1;
      }
      s[0] = x1; s[1] = x2; s[2] = y1; s[3] = y2;
    }
    return x;
  }
}

class WaveShaper extends Node {
  constructor(ctx) { super(ctx); this.curve = null; this.oversample = 'none'; }
  process() {
    const x = this.input(), c = this.curve;
    if (!c) return x;
    const n = c.length, half = (n - 1) / 2;
    for (const d of x) for (let i = 0; i < QUANTUM; i++) {
      const v = half * (d[i] + 1);
      if (v <= 0) d[i] = c[0]; else if (v >= n - 1) d[i] = c[n - 1];
      else { const k = Math.floor(v), f = v - k; d[i] = c[k] + (c[k + 1] - c[k]) * f; }
    }
    return x;
  }
}

class StereoPanner extends Node {
  constructor(ctx) { super(ctx, { channelCountMode: 'clamped-max' }); this.pan = new AudioParam(ctx, 0); }
  process() {
    const x = this.input(), p = Math.max(-1, Math.min(1, this.pan.block().values[0]));
    const L = new Float32Array(QUANTUM), R = new Float32Array(QUANTUM);
    if (x.length === 1) {
      const a = (p + 1) / 2 * Math.PI / 2, gl = Math.cos(a), gr = Math.sin(a);
      for (let i = 0; i < QUANTUM; i++) { L[i] = x[0][i] * gl; R[i] = x[0][i] * gr; }
    } else if (p <= 0) {
      const a = (p + 1) * Math.PI / 2, gl = Math.cos(a), gr = Math.sin(a);
      for (let i = 0; i < QUANTUM; i++) { L[i] = x[0][i] + x[1][i] * gl; R[i] = x[1][i] * gr; }
    } else {
      const a = p * Math.PI / 2, gl = Math.cos(a), gr = Math.sin(a);
      for (let i = 0; i < QUANTUM; i++) { L[i] = x[0][i] * gl; R[i] = x[1][i] + x[0][i] * gr; }
    }
    return [L, R];
  }
}

// Delay: the output reads the ring written in earlier blocks, so feedback cycles through it terminate.
class Delay extends Node {
  constructor(ctx, max = 1) {
    super(ctx); this.delayTime = new AudioParam(ctx, 0);
    this.size = Math.ceil((max + .1) * ctx.sampleRate) + QUANTUM; this.ring = [new Float32Array(this.size), new Float32Array(this.size)]; this.w = 0;
    ctx.delays.push(this);
  }
  process() {
    const d = Math.max(QUANTUM, Math.round(this.delayTime.block().values[0] * this.ctx.sampleRate));
    const out = [new Float32Array(QUANTUM), new Float32Array(QUANTUM)];
    for (let c = 0; c < 2; c++) for (let i = 0; i < QUANTUM; i++) out[c][i] = this.ring[c][(this.w + i - d + this.size) % this.size];
    return out;
  }
  write() {
    const x = this.input();
    for (let c = 0; c < 2; c++) { const s = x[Math.min(c, x.length - 1)]; for (let i = 0; i < QUANTUM; i++) this.ring[c][(this.w + i) % this.size] = s[i]; }
    this.w = (this.w + QUANTUM) % this.size;
  }
}

function fft(re, im, inverse) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = 2 * Math.PI / len * (inverse ? 1 : -1), wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const a = i + k, b = a + len / 2;
        const tr = re[b] * cr - im[b] * ci, ti = re[b] * ci + im[b] * cr;
        re[b] = re[a] - tr; im[b] = im[a] - ti; re[a] += tr; im[a] += ti;
        const nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr;
      }
    }
  }
  if (inverse) for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
}

class Convolver extends Node {
  constructor(ctx) { super(ctx, { channelCountMode: 'clamped-max' }); this.buffer = null; this.normalize = true; this.P = 2048; this.ready = false; }
  setup() {
    const P = this.P, N = 2 * P, b = this.buffer, chans = b.numberOfChannels;
    let scale = 1;
    if (this.normalize) {
      let power = 0;
      for (let c = 0; c < chans; c++) { const d = b.getChannelData(c); for (let i = 0; i < d.length; i++) power += d[i] * d[i]; }
      power = Math.sqrt(power / (chans * b.length));
      if (!(power >= .000125)) power = .000125;
      scale = (1 / power) * .00125 * (44100 / b.sampleRate);
    }
    this.parts = Math.ceil(b.length / P);
    this.H = [];
    for (let c = 0; c < 2; c++) {
      const d = b.getChannelData(Math.min(c, chans - 1)), list = [];
      for (let k = 0; k < this.parts; k++) {
        const re = new Float64Array(N), im = new Float64Array(N);
        for (let i = 0; i < P && k * P + i < d.length; i++) re[i] = d[k * P + i] * scale;
        fft(re, im, false); list.push([re, im]);
      }
      this.H.push(list);
    }
    this.fdl = [[], []]; this.inBuf = [new Float32Array(P), new Float32Array(P)]; this.fill = 0;
    this.outBuf = [new Float32Array(P), new Float32Array(P)]; this.overlap = [new Float64Array(P), new Float64Array(P)]; this.read = 0;
    this.ready = true;
  }
  process() {
    const x = this.input();
    if (!this.buffer) return [new Float32Array(QUANTUM)];
    if (!this.ready) this.setup();
    const P = this.P, N = 2 * P, out = [new Float32Array(QUANTUM), new Float32Array(QUANTUM)];
    for (let c = 0; c < 2; c++) {
      const s = x[Math.min(c, x.length - 1)];
      this.inBuf[c].set(s, this.fill);
      out[c].set(this.outBuf[c].subarray(this.fill, this.fill + QUANTUM));
    }
    this.fill += QUANTUM;
    if (this.fill === P) {
      this.fill = 0;
      for (let c = 0; c < 2; c++) {
        const re = new Float64Array(N), im = new Float64Array(N);
        for (let i = 0; i < P; i++) re[i] = this.inBuf[c][i];
        fft(re, im, false);
        const fdl = this.fdl[c]; fdl.unshift([re, im]); if (fdl.length > this.parts) fdl.pop();
        const yr = new Float64Array(N), yi = new Float64Array(N);
        for (let k = 0; k < fdl.length; k++) {
          const [xr, xi] = fdl[k], [hr, hi] = this.H[c][k];
          for (let i = 0; i < N; i++) { yr[i] += xr[i] * hr[i] - xi[i] * hi[i]; yi[i] += xr[i] * hi[i] + xi[i] * hr[i]; }
        }
        fft(yr, yi, true);
        for (let i = 0; i < P; i++) { this.outBuf[c][i] = yr[i] + this.overlap[c][i]; this.overlap[c][i] = yr[P + i]; }
      }
    }
    return out;
  }
}

class Compressor extends Node {
  constructor(ctx) {
    super(ctx, { channelCountMode: 'clamped-max' });
    for (const [k, v] of Object.entries({ threshold: -24, knee: 30, ratio: 12, attack: .003, release: .25 })) this[k] = new AudioParam(ctx, v);
    this.env = 0; this.look = Math.round(.006 * ctx.sampleRate); this.ring = [new Float32Array(this.look + QUANTUM), new Float32Array(this.look + QUANTUM)]; this.w = 0;
    this.reduction = 0; this.maxReduction = 0; this.held = 0; this.holdLeft = 0;
  }
  process() {
    const x = this.input(), sr = this.ctx.sampleRate;
    const th = this.threshold.value, ratio = this.ratio.value;
    const att = Math.exp(-1 / (Math.max(this.attack.value, 1e-4) * sr)), rel = Math.exp(-1 / (Math.max(this.release.value, 1e-3) * sr));
    const curve = db => (db > th ? th + (db - th) / ratio : db);
    const makeup = (1 / 10 ** (curve(0) / 20)) ** .6;
    const out = [new Float32Array(QUANTUM), new Float32Array(QUANTUM)], size = this.ring[0].length;
    for (let i = 0; i < QUANTUM; i++) {
      let peak = 0;
      for (let c = 0; c < 2; c++) { const v = x[Math.min(c, x.length - 1)][i]; this.ring[c][this.w] = v; peak = Math.max(peak, Math.abs(v)); }
      // The detector holds a peak for the look-ahead time, so the gain is down before the peak leaves the delay.
      if (peak >= this.held || this.holdLeft-- <= 0) { this.held = peak; this.holdLeft = this.look; }
      const db = this.held > 1e-9 ? 20 * Math.log10(this.held) : -180, want = curve(db) - db;   // <= 0
      this.env = want < this.env ? att * this.env + (1 - att) * want : rel * this.env + (1 - rel) * want;
      const g = 10 ** (this.env / 20) * makeup, r = (this.w - this.look + size) % size;
      for (let c = 0; c < 2; c++) out[c][i] = this.ring[c][r] * g;
      this.w = (this.w + 1) % size;
      this.maxReduction = Math.min(this.maxReduction, this.env);
    }
    this.reduction = this.env;
    return out;
  }
}

class Destination extends Node {
  constructor(ctx) { super(ctx, { channelCountMode: 'explicit' }); this.channelCount = 2; this.maxChannelCount = 2; }
}

export class OfflineContext {
  constructor({ sampleRate = 48000 } = {}) {
    this.sampleRate = sampleRate; this.frame = 0; this.block = 0; this.state = 'suspended';
    this.destination = new Destination(this); this.delays = []; this.live = new Set(); this.endedQueue = [];
    this.taps = [];
  }
  get currentTime() { return this.frame / this.sampleRate; }
  createGain() { return new Gain(this); }
  createOscillator() { return new Oscillator(this); }
  createBufferSource() { return new BufferSource(this); }
  createBiquadFilter() { return new Biquad(this); }
  createWaveShaper() { return new WaveShaper(this); }
  createConvolver() { return new Convolver(this); }
  createStereoPanner() { return new StereoPanner(this); }
  createDelay(max = 1) { return new Delay(this, max); }
  createDynamicsCompressor() { return new Compressor(this); }
  createBuffer(channels, length, rate) { return new AudioBuffer(channels, length, rate); }
  // Bytes: little-endian float32 PCM at the context rate, prefixed by 'F32M' (mono) or 'F32S' (stereo, interleaved):
  // the meter's own decode.
  decodeAudioData(bytes, ok, fail) {
    try {
      const view = new DataView(bytes), tag = view.getUint32(0);
      if (tag !== 0x4633324d && tag !== 0x46333253) throw new Error('not F32M or F32S');
      const ch = tag === 0x46333253 ? 2 : 1, n = (bytes.byteLength - 4) / 4 / ch, buffer = new AudioBuffer(ch, n, this.sampleRate);
      for (let c = 0; c < ch; c++) { const d = buffer.getChannelData(c); for (let i = 0; i < n; i++) d[i] = view.getFloat32(4 + (i * ch + c) * 4, true); }
      ok?.(buffer); return Promise.resolve(buffer);
    } catch (error) { fail?.(error); return Promise.reject(error); }
  }
  async resume() { this.state = 'running'; }
  async suspend() { this.state = 'suspended'; }
  // Listen to a node's output (summed into stereo) as a named tap; returns the tap's {L, R} arrays.
  tap(node, frames) { const t = { node, L: new Float32Array(frames), R: new Float32Array(frames) }; this.taps.push(t); return t; }
  // Renders one quantum into `L`/`R` at frame offset `at`.
  renderQuantum(L, R, at) {
    const out = this.destination.output();
    L.set(out[0], at); R.set(out[out.length > 1 ? 1 : 0], at);
    for (const t of this.taps) { const o = t.node.output(); if (at + QUANTUM <= t.L.length) { t.L.set(o[0], at); t.R.set(o[o.length > 1 ? 1 : 0], at); } }
    for (const d of this.delays) d.write();
    // Sources the graph did not pull this block still end on time.
    const end = (this.frame + QUANTUM) / this.sampleRate;
    for (const s of [...this.live]) if (s.stopAt <= end) s.finish();
    this.frame += QUANTUM; this.block++;
    const ended = this.endedQueue; this.endedQueue = [];
    for (const s of ended) s.onended?.();
  }
}
export { QUANTUM };
