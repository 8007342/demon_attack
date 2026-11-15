// Energy-based action scoring of demon-intelligence (openspec/changes/
// demon-intelligence design §3): the synthetic teacher that trained
// SwarmPolicy (scripts/train-policy.mjs), made exact and multi-shot. Each
// candidate manoeuvre is a displacement over a short duration; its energy
// sums time-to-collision danger against every visible player shot
// (Karamouzas et al. 2014), walls, crowding, a leash to the squad's
// pattern target, an attack reward (dive commit only) and hysteresis. The
// choice is a softmin from the planner's own seeded PRNG, so it never
// draws from the run's `random`. Pure Dart; allocation-free per decision.
import 'dart:math' as math;
import 'dart:typed_data';

import 'model.dart' show Shot;

/// Candidate manoeuvres (design §3 table).
enum Manoeuvre { hold, sideL, sideR, wideL, wideR, climb, thread }

/// Named weights of the energy terms. Danger 8 and leash 0.5 come from
/// the task 2.4 sweep (test/planner_sweep_test.dart, design.md §3); the
/// rest are the teacher's.
class PlannerWeights {
  const PlannerWeights({
    this.danger = 8,
    this.wall = 1,
    this.crowd = .4,
    this.leash = .5,
    this.attack = .8,
    this.change = 1,
  });
  final double danger, wall, crowd, leash, attack, change;
}

/// One tier's decision-making (design §4).
class PlannerConfig {
  const PlannerConfig({
    required this.candidates,
    required this.delay,
    required this.foresight,
    required this.temperature,
    this.side = 22,
    this.wide = 40,
    this.climb = 18,
    this.duration = .32,
    this.wallLo = 34,
    this.wallHi = 326,
    this.margin = 3,
    this.yScale = 1,
    this.weights = const PlannerWeights(),
  });

  final List<Manoeuvre> candidates;

  /// Perception delay δ (s), foresight τ0 (s) and softmin temperature T.
  final double delay, foresight, temperature;

  /// Spans (u, before the creature's scale) and the manoeuvre duration D.
  final double side, wide, climb, duration;

  /// Wall bounds of the end position.
  final double wallLo, wallHi;

  /// Collision radius = hit half width + [margin].
  final double margin;

  /// Vertical scale of the contact metric (1: a circle; the teacher's
  /// 0.85 makes it an ellipse taller than wide).
  final double yScale;
  final PlannerWeights weights;

  /// Danger horizon H = 1.5 τ0.
  double get horizon => 1.5 * foresight;

  /// T1 skirmisher: the veto check.
  static const skirmisher = PlannerConfig(
    candidates: [Manoeuvre.hold, Manoeuvre.sideL, Manoeuvre.sideR],
    delay: .22,
    foresight: .32,
    temperature: .25,
  );

  /// T2 hunter at skill [s] ∈ [0, 1]: δ 0.30 → 0.12, τ0 0.45 → 0.65,
  /// T 0.5 → 0.15. [dive] adds the thread (dive-commit) candidate.
  static PlannerConfig hunter(double s, {bool dive = false}) {
    final k = s.clamp(0.0, 1.0);
    double lerp(double a, double b) => a + (b - a) * k;
    return PlannerConfig(
      candidates: dive ? hunterDive : hunterEvade,
      delay: lerp(.30, .12),
      foresight: lerp(.45, .65),
      temperature: lerp(.5, .15),
    );
  }

  static const hunterEvade = [
    Manoeuvre.hold,
    Manoeuvre.sideL,
    Manoeuvre.sideR,
    Manoeuvre.wideL,
    Manoeuvre.wideR,
    Manoeuvre.climb,
  ];
  static const hunterDive = [...hunterEvade, Manoeuvre.thread];

  /// T3 sentinel: {hold, sideL, sideR} with today's 54-u span over 0.6 s,
  /// inside the sentinel's formation bounds.
  static const sentinel = PlannerConfig(
    candidates: [Manoeuvre.hold, Manoeuvre.sideL, Manoeuvre.sideR],
    delay: .25,
    foresight: .55,
    temperature: .2,
    side: 54,
    duration: .6,
    wallLo: 62,
    wallHi: 298,
  );

  /// Hunter dodge cooldown (s) at skill [s]: 1.6 → 1.1.
  static double hunterCooldown(double s) => 1.6 - .5 * s.clamp(0.0, 1.0);
}

/// What the planner sees of one creature.
class PlanState {
  double x = 0, y = 0;

  /// Size factor (spans scale with it) and hit half width.
  double scale = 1, halfWidth = 16;

  /// (right − left neighbours) / 4, clamped to [-1, 1] (as the teacher).
  double crowd = 0;

  /// The squad's pattern target x (leash).
  double leashX = 0;
  Manoeuvre last = Manoeuvre.hold;

  /// Thread candidate: where the dive would aim and its P_hit.
  double aimX = 180, aimP = 0;
}

class DemonPlanner {
  DemonPlanner(int seed) : _rng = math.Random(seed ^ 0x5eed1e);
  final math.Random _rng;

  /// Energies of the last decision, by [Manoeuvre.index].
  final Float64List energies = Float64List(Manoeuvre.values.length);

  /// Decisions taken (instrumentation).
  int decisions = 0;

  /// Displacement of [a] for [s] under [cfg].
  static (double, double) displacement(
    Manoeuvre a,
    PlanState s,
    PlannerConfig cfg,
  ) => switch (a) {
    Manoeuvre.hold => (0, 0),
    Manoeuvre.sideL => (-cfg.side * s.scale, 0),
    Manoeuvre.sideR => (cfg.side * s.scale, 0),
    Manoeuvre.wideL => (-cfg.wide * s.scale, 0),
    Manoeuvre.wideR => (cfg.wide * s.scale, 0),
    Manoeuvre.climb => (0, -cfg.climb),
    Manoeuvre.thread => (((s.aimX - s.x) * .4).clamp(-36.0, 36.0), 44),
  };

  /// Time to the first contact (≤ [h]) of a point moving at (vx, vy) from
  /// (rx, ry) relative to a circle of radius [r] at the origin, from t0;
  /// null if none in [t0, h].
  static double? _contact(
    double rx,
    double ry,
    double vx,
    double vy,
    double r,
    double t0,
    double h,
  ) {
    if (h < t0) return null;
    final c = rx * rx + ry * ry - r * r;
    if (c <= 0) return t0;
    final a = vx * vx + vy * vy;
    final b = rx * vx + ry * vy;
    if (a < 1e-9 || b >= 0) return null;
    final disc = b * b - a * c;
    if (disc < 0) return null;
    final t = (-b - math.sqrt(disc)) / a;
    return t0 + t <= h ? t0 + t : null;
  }

  /// Danger of the path from (px, py) at (vx, vy) that stops after
  /// [stopAfter] s (∞: keeps going), against the player shots in [shots]
  /// as perceived with [delay]: Σ 1/τ² e^(−τ/τ0) over contacts τ ≤ H.
  static double danger(
    double px,
    double py,
    double vx,
    double vy,
    double stopAfter,
    Iterable<Shot> shots, {
    required double radius,
    required double delay,
    required double foresight,
    double yScale = 1,
  }) {
    final h = 1.5 * foresight;
    final k = yScale;
    final split = math.min(stopAfter, h);
    var e = 0.0;
    for (final s in shots) {
      if (s.hostile || s.vy >= 0 || s.age < delay) continue;
      // Seen where it was δ ago.
      final sx = s.x - s.vx * delay, sy = s.y - s.vy * delay;
      var tau = _contact(
        sx - px,
        (sy - py) * k,
        s.vx - vx,
        (s.vy - vy) * k,
        radius,
        0,
        split,
      );
      if (tau == null && split < h) {
        final ex = px + vx * split, ey = py + vy * split;
        tau = _contact(
          sx + s.vx * split - ex,
          (sy + s.vy * split - ey) * k,
          s.vx,
          s.vy * k,
          radius,
          split,
          h,
        );
      }
      if (tau == null) continue;
      final t = math.max(tau, .01);
      e += math.exp(-t / foresight) / (t * t);
    }
    return e;
  }

  /// The x range the formation keeps a creature in.
  static const arenaLo = 20.0, arenaHi = 340.0;

  /// Danger of manoeuvre [a] alone (the T1 veto).
  static double dangerOf(
    Manoeuvre a,
    PlanState s,
    PlannerConfig cfg,
    Iterable<Shot> shots,
  ) {
    final (raw, dy) = displacement(a, s, cfg);
    // The formation keeps a creature inside the arena (x 20..340).
    final dx = (s.x + raw).clamp(arenaLo, arenaHi) - s.x;
    return danger(
      s.x,
      s.y,
      dx / cfg.duration,
      dy / cfg.duration,
      cfg.duration,
      shots,
      radius: s.halfWidth + cfg.margin,
      delay: cfg.delay,
      foresight: cfg.foresight,
      yScale: cfg.yScale,
    );
  }

  /// The full energy of [a] (design §3).
  static double energy(
    Manoeuvre a,
    PlanState s,
    PlannerConfig cfg,
    Iterable<Shot> shots,
  ) {
    final w = cfg.weights;
    final (dx, dy) = displacement(a, s, cfg);
    var e = w.danger * dangerOf(a, s, cfg, shots);
    // Walls: a move toward the edge pays for its intended end (teacher).
    final endX = s.x + dx;
    if (dx != 0) {
      e +=
          w.wall *
          1.9 *
          math.max(0, math.max(cfg.wallLo - endX, endX - cfg.wallHi));
    }
    e +=
        w.crowd *
        8 *
        switch (a) {
          Manoeuvre.sideL || Manoeuvre.wideL => math.max(0, -s.crowd),
          Manoeuvre.sideR || Manoeuvre.wideR => math.max(0, s.crowd),
          _ => 0,
        };
    if (a == Manoeuvre.thread) {
      e -= w.attack * s.aimP;
    } else {
      e += w.leash * .002 * (endX - s.leashX) * (endX - s.leashX);
    }
    if (a != s.last) e += w.change * .3;
    return e;
  }

  /// Chooses among [cfg]'s candidates: softmin p(a) ∝ exp(−E(a)/T) drawn
  /// from this planner's PRNG (argmin as T → 0; ties keep list order).
  Manoeuvre choose(PlanState s, PlannerConfig cfg, Iterable<Shot> shots) {
    decisions++;
    var best = cfg.candidates.first;
    var low = double.infinity;
    for (final a in cfg.candidates) {
      final e = energy(a, s, cfg, shots);
      energies[a.index] = e;
      if (e < low) {
        low = e;
        best = a;
      }
    }
    final t = cfg.temperature;
    if (t <= 1e-6) return best;
    var total = 0.0;
    for (final a in cfg.candidates) {
      total += math.exp(-(energies[a.index] - low) / t);
    }
    var u = _rng.nextDouble() * total;
    for (final a in cfg.candidates) {
      u -= math.exp(-(energies[a.index] - low) / t);
      if (u <= 0) return a;
    }
    return best;
  }

  /// Thread dive (design §5): the lateral velocity (u/s) from
  /// {−[lateral], 0, +[lateral]} minimising E_danger + 0.004 (x(t + 0.3) −
  /// x*_line(t + 0.3))² for a diver at (x, y) falling at [vy], with the
  /// straight line expected at [lineAhead] in 0.3 s.
  static double threadLateral({
    required double x,
    required double y,
    required double vy,
    required double lineAhead,
    required double lateral,
    required double radius,
    required double delay,
    required double foresight,
    required Iterable<Shot> shots,
  }) {
    var best = 0.0, low = double.infinity;
    for (var i = 0; i < 3; i++) {
      final v = i == 0 ? 0.0 : (i == 1 ? -lateral : lateral);
      final ahead = x + v * .3 - lineAhead;
      final e =
          danger(
            x,
            y,
            v,
            vy,
            double.infinity,
            shots,
            radius: radius,
            delay: delay,
            foresight: foresight,
          ) +
          .004 * ahead * ahead;
      if (e < low - 1e-9) {
        low = e;
        best = v;
      }
    }
    return best;
  }
}
