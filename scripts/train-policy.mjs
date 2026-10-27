// Offline, dependency-free deterministic synthetic imitation training for
// Demon Attack's Swarm JEV (Joint Evasion & Vectoring) action prior.
import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const clamp = (x, lo = -1, hi = 1) => Math.max(lo, Math.min(hi, x));

function rng(seed) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const actions = ['hold', 'evade_left', 'evade_right', 'dive_commit'];
const IN = 10, H = 16, OUT = 4;

function encode(s) {
  return [
    clamp((s.demonX - 180) / 160),
    clamp((s.demonY - 140) / 100),
    clamp((s.shotX - s.demonX) / 72),
    clamp((s.demonY - s.shotY) / 160),
    clamp(s.shotVx / 90),
    clamp((s.shipX - s.demonX) / 180),
    clamp(s.shipVx / 350),
    clamp(s.crowdBalance),
    clamp(2 * s.healthRatio - 1),
    clamp(s.tierFactor),
  ];
}

function evaluateTeacherUtility(s, actionIndex) {
  const duration = 0.32;
  const shotVy = -385;
  const leadShipX = clamp(s.shipX + s.shipVx * 0.22, 24, 336);
  const dx =
    actionIndex === 0
      ? 0
      : actionIndex === 1
        ? -26
        : actionIndex === 2
          ? 26
          : clamp((leadShipX - s.demonX) * 0.4, -36, 36);
  const dy = actionIndex === 3 ? 44 : 0;

  let minShotDist = Infinity;
  for (let i = 1; i <= 10; i++) {
    const p = i / 10;
    const t = p * duration;
    const ease = p * p * (3 - 2 * p);
    const cx = clamp(s.demonX + dx * ease, 20, 340);
    const cy = s.demonY + dy * ease;
    const sx = s.shotX + s.shotVx * t;
    const sy = s.shotY + shotVy * t;
    const d = Math.hypot(cx - sx, (cy - sy) * 0.85);
    if (d < minShotDist) minShotDist = d;
  }

  // Also check if holding position is threatened by the incoming shot.
  let holdShotDist = Infinity;
  for (let i = 1; i <= 10; i++) {
    const t = (i / 10) * duration;
    const sx = s.shotX + s.shotVx * t;
    const sy = s.shotY + shotVy * t;
    const d = Math.hypot(s.demonX - sx, (s.demonY - sy) * 0.85);
    if (d < holdShotDist) holdShotDist = d;
  }

  const endX = s.demonX + dx;
  const wallPenalty =
    endX < 34 ? (34 - endX) * 1.9 : endX > 326 ? (endX - 326) * 1.9 : 0;

  // Positive crowdBalance means more neighbors on the right than on the left.
  const crowdPenalty =
    actionIndex === 1
      ? Math.max(0, -s.crowdBalance) * 8.0
      : actionIndex === 2
        ? Math.max(0, s.crowdBalance) * 8.0
        : 0;

  const shotDanger = minShotDist < 24 ? (24 - minShotDist) * 3.8 : 0;
  const interceptErr = Math.abs(s.demonX - leadShipX);
  const canDive =
    holdShotDist > 26 &&
    minShotDist > 24 &&
    interceptErr < 68 &&
    (s.tierFactor > 0 || s.healthRatio < 0.55);

  if (actionIndex === 0) {
    return holdShotDist > 24 && !canDive ? 18.0 - shotDanger : -shotDanger - 6.0;
  }
  if (actionIndex === 1 || actionIndex === 2) {
    return holdShotDist <= 24
      ? 14.0 + minShotDist * 0.45 - shotDanger - wallPenalty - crowdPenalty
      : -4.0 - wallPenalty - crowdPenalty;
  }
  // actionIndex === 3 (dive_commit)
  return canDive
    ? 22.0 + (68 - interceptErr) * 0.14 + s.tierFactor * 2.5 - shotDanger - wallPenalty
    : -14.0 - shotDanger;
}

function dataset(seed, n) {
  const r = rng(seed), out = [];
  while (out.length < n) {
    const demonX = 28 + r() * 304;
    const demonY = 64 + r() * 160;
    const modeRoll = r();
    const tti = 0.08 + r() * 0.24;
    const shotVx = (r() * 2 - 1) * 90;
    // Sample a balanced mix of threatened states (near-hit shot) and clear states.
    const shotX =
      modeRoll < 0.56
        ? clamp(demonX - shotVx * tti + (r() * 2 - 1) * 18, 18, 342)
        : clamp(demonX + (r() < 0.5 ? -1 : 1) * (36 + r() * 80), 18, 342);
    const shotY = clamp(demonY + 385 * tti, demonY + 24, 480);
    const shipVx = (r() * 2 - 1) * 350;
    const shipX =
      modeRoll >= 0.56 && r() < 0.55
        ? clamp(demonX - shipVx * 0.22 + (r() * 2 - 1) * 48, 24, 336)
        : 24 + r() * 312;
    const crowdBalance = r() * 2 - 1;
    const healthRatio = 0.25 + r() * 0.75;
    const tierRoll = r();
    const tierFactor = tierRoll < 0.45 ? -0.75 : tierRoll < 0.78 ? 0.35 : 1.0;

    const s = {
      demonX,
      demonY,
      shotX,
      shotY,
      shotVx,
      shipX,
      shipVx,
      crowdBalance,
      healthRatio,
      tierFactor,
    };
    const utilities = actions.map((_, a) => evaluateTeacherUtility(s, a));
    const sorted = [...utilities].sort((a, b) => b - a);
    if (sorted[0] - sorted[1] < 1.5) continue;
    const y = utilities.indexOf(sorted[0]);
    out.push({x: encode(s), y});
  }
  return out;
}

const config = {
  trainSeed: 1724,
  testSeed: 90421,
  weightSeed: 731,
  trainCount: 24000,
  testCount: 4000,
  epochs: 95,
  learningRate: 0.024,
};

const train = dataset(config.trainSeed, config.trainCount);
const test = dataset(config.testSeed, config.testCount);
const r = rng(config.weightSeed);

const w = Array.from({length: IN * H}, () => (r() * 2 - 1) * 0.25);
const b = Array(H).fill(0);
const v = Array.from({length: OUT * H}, () => (r() * 2 - 1) * 0.25);
const c = Array(OUT).fill(0);

function forward(x) {
  const h = b.map((z, j) =>
    Math.tanh(z + x.reduce((s, q, i) => s + q * w[j * IN + i], 0)),
  );
  const z = c.map((q, k) => q + h.reduce((s, t, j) => s + t * v[k * H + j], 0));
  const m = Math.max(...z);
  const e = z.map((q) => Math.exp(q - m));
  const total = e.reduce((a, b) => a + b);
  return {h, p: e.map((q) => q / total)};
}

for (let epoch = 0; epoch < config.epochs; epoch++) {
  for (let i = train.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [train[i], train[j]] = [train[j], train[i]];
  }
  const lr = config.learningRate / (1 + epoch / 45);
  for (const {x, y} of train) {
    const {h, p} = forward(x);
    const d = p.map((q, k) => q - (k === y ? 1 : 0));
    const dh = h.map(
      (q, j) =>
        (1 - q * q) * d.reduce((s, t, k) => s + t * v[k * H + j], 0),
    );
    for (let k = 0; k < OUT; k++) {
      c[k] -= lr * d[k];
      for (let j = 0; j < H; j++) v[k * H + j] -= lr * d[k] * h[j];
    }
    for (let j = 0; j < H; j++) {
      b[j] -= lr * dh[j];
      for (let i = 0; i < IN; i++) w[j * IN + i] -= lr * dh[j] * x[i];
    }
  }
}

// Evaluate exact rounded 6-decimal constants exported to Dart.
for (const a of [w, b, v, c]) {
  for (let i = 0; i < a.length; i++) a[i] = Number(a[i].toFixed(6));
}

const confusion = Array.from({length: OUT}, () => Array(OUT).fill(0));
let correct = 0;
for (const {x, y} of test) {
  const {p} = forward(x);
  const pred = p.indexOf(Math.max(...p));
  confusion[y][pred]++;
  if (pred === y) correct++;
}

const counts = confusion.map((row) => row.reduce((a, b) => a + b));
const payload = JSON.stringify({w, b, v, c});
const parameters = IN * H + H + OUT * H + OUT;

const dart = `// Generated by node scripts/train-policy.mjs; do not edit weights by hand.
import 'dart:math' as math;

/// Tiny offline synthetic geometric imitation prior (JEV) for Demon Attack
/// swarm shot evasion and predatory dive vectoring.
/// Compiled as pure Dart constants: zero runtime downloads or external deps.
class SwarmPolicy {
  static const actions = ['hold', 'evade_left', 'evade_right', 'dive_commit'];
  static const int inputs = ${IN};
  static const int hidden = ${H};

  static double _clip(double x) => x.clamp(-1.0, 1.0).toDouble();

  static List<double> encode({
    required double demonX,
    required double demonY,
    required double shotX,
    required double shotY,
    required double shotVx,
    required double shipX,
    required double shipVx,
    required double crowdBalance,
    required double healthRatio,
    required double tierFactor,
  }) {
    final raw = [
      demonX,
      demonY,
      shotX,
      shotY,
      shotVx,
      shipX,
      shipVx,
      crowdBalance,
      healthRatio,
      tierFactor,
    ];
    if (raw.any((x) => !x.isFinite)) return List.filled(inputs, double.nan);
    return [
      (demonX - 180.0) / 160.0,
      (demonY - 140.0) / 100.0,
      (shotX - demonX) / 72.0,
      (demonY - shotY) / 160.0,
      shotVx / 90.0,
      (shipX - demonX) / 180.0,
      shipVx / 350.0,
      crowdBalance,
      2.0 * healthRatio - 1.0,
      tierFactor,
    ].map(_clip).toList();
  }

  static String suggest({
    required double demonX,
    required double demonY,
    required double shotX,
    required double shotY,
    required double shotVx,
    required double shipX,
    required double shipVx,
    required double crowdBalance,
    required double healthRatio,
    required double tierFactor,
  }) =>
      choose(
        encode(
          demonX: demonX,
          demonY: demonY,
          shotX: shotX,
          shotY: shotY,
          shotVx: shotVx,
          shipX: shipX,
          shipVx: shipVx,
          crowdBalance: crowdBalance,
          healthRatio: healthRatio,
          tierFactor: tierFactor,
        ),
      );

  static String choose(List<double> features) {
    final p = scores(features);
    var best = 0;
    for (var k = 1; k < actions.length; k++) {
      if (p[k] > p[best]) best = k;
    }
    return actions[best];
  }

  /// Probabilities in [hold, evade_left, evade_right, dive_commit] order.
  /// Invalid inputs fall back to [1, 0, 0, 0] ('hold').
  static List<double> scores(List<double> features) {
    if (features.length != inputs || features.any((x) => !x.isFinite)) {
      return const [1, 0, 0, 0];
    }
    final x = features.map(_clip).toList();
    final h = List<double>.generate(hidden, (j) {
      var z = _b[j];
      for (var i = 0; i < inputs; i++) {
        z += x[i] * _w[j * inputs + i];
      }
      final e = math.exp(-2 * z.abs());
      return (z < 0 ? -1.0 : 1.0) * (1 - e) / (1 + e);
    });
    final z = List<double>.generate(${OUT}, (k) {
      var s = _c[k];
      for (var j = 0; j < hidden; j++) {
        s += h[j] * _v[k * hidden + j];
      }
      return s;
    });
    if (z.any((x) => !x.isFinite)) return const [1, 0, 0, 0];
    final m = z.reduce(math.max);
    final p = z.map((q) => math.exp(q - m)).toList();
    final total = p.reduce((a, b) => a + b);
    if (!total.isFinite || total <= 0) return const [1, 0, 0, 0];
    return p.map((q) => q / total).toList();
  }

${[['w', w], ['b', b], ['v', v], ['c', c]].map(([n, a]) => `  static const _${n} = <double>[${a.join(',')}];`).join('\n')}
}
`;

if (Buffer.byteLength(payload) >= 5000) throw Error('Weight budget exceeded');
mkdirSync(root + 'assets/policy', {recursive: true});
writeFileSync(root + 'lib/game/swarm_policy.dart', dart);
const manifest = {
  schemaVersion: 1,
  kind: 'synthetic imitation action prior (Swarm JEV: evasion & dive vectoring)',
  architecture: [IN, H, OUT],
  activation: 'tanh / softmax',
  actions,
  parameters,
  weightDecimals: 6,
  weightPayloadBytes: Buffer.byteLength(payload),
  runtime: 'Dart core only; weights compiled into lib/game/swarm_policy.dart',
  training: config,
  teacher: {
    duration: 0.32,
    shotVy: -385,
    samples: 10,
    evadeDeltaX: 26,
    safeShotClearance: 24,
  },
  heldOut: {
    correct,
    total: test.length,
    accuracy: correct / test.length,
    majorityBaseline: Math.max(...counts) / test.length,
    confusionRowsTeacherColumnsPrediction: confusion,
  },
  parityCases: test.slice(0, 5).map(({x}) => ({features: x, scores: forward(x).p})),
};
writeFileSync(root + 'assets/policy/manifest.json', JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify({parameters, payload: Buffer.byteLength(payload), heldOut: manifest.heldOut}, null, 2));
