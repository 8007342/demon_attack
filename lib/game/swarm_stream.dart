import 'dart:math' as math;

/// The continuous swarm's scheduler (openspec/changes/continuous-swarm
/// design §1-§2, plan/swarm-research.md §3.4).
///
/// A wave stays the accounting unit (roster, finite groups, escort, elite
/// budget, checkpoint, wave number), exactly as calibrated in
/// plan/difficulty-calibration.md. What this file decides is *when and how*
/// a wave's members reach the screen: as a stream of **skeins** (3-6
/// creatures) that leave the deep fog one after another, faster when the
/// player clears faster (a rubber band on timing, never on content).
///
/// Pure Dart, no Flutter. Seeded per (run seed, sector, route, wave, salt)
/// with its own PRNG: it never draws from the model's `random`, so every
/// other random draw of a run keeps its sequence.

/// Where a member of the swarm is in its life (design §2.1). The fog
/// (fog-restoration, W2) reads it to decide how to veil a creature.
enum SwarmState {
  /// Born, waiting veiled in the deep fog: untargetable, silent, no gear,
  /// not counted for clearing or occupancy (reinforcement groups) or
  /// parked until its skein is released (a roster's later skeins).
  reserve,

  /// Flying its skein's parabolic swoop out of the fog: untargetable.
  approaching,

  /// In the fight: targetable, fires, dives, flies its squad's pattern.
  present,

  /// On a dive.
  diving,

  /// Out of the bottom after a dive, swooping back from a deep gate.
  reentering,
}

/// The gates a skein's swoop sets out from (design §3): either side, the
/// centre, and two "deep" gates under the far banks.
enum SwarmGate { left, right, centre, deepLeft, deepRight }

extension SwarmGateGeometry on SwarmGate {
  /// Side of the arena, -1 left, 0 centre, 1 right.
  int get side => switch (this) {
    SwarmGate.left || SwarmGate.deepLeft => -1,
    SwarmGate.right || SwarmGate.deepRight => 1,
    SwarmGate.centre => 0,
  };

  bool get deep => this == SwarmGate.deepLeft || this == SwarmGate.deepRight;

  /// Nearness the swoop leaves from: deep gates are under the far banks.
  double get nearness => deep ? .12 : .2;

  /// Screen x the swoop leaves from.
  double get screenX => 180 + side * (deep ? 70.0 : 150.0);
}

/// One small stream of creatures: indices into its cohort's member list
/// (roster order is kept inside a skein).
class Skein {
  Skein(this.id, this.members, this.gate);
  final int id;
  final List<int> members;
  final SwarmGate gate;

  /// Released from the reserve (it is flying, or has arrived).
  bool released = false;
}

/// Plans returned to the transitions of `cinematic-flow` (W5b, design §6.4).
/// W3 ships them as stubs that describe what would happen; W5b drives them.
class DrainPlan {
  const DrainPlan(this.pendingSkeins);

  /// Skeins that will no longer be released.
  final int pendingSkeins;
}

class RoutPlan {
  const RoutPlan(this.direction, this.seconds);

  /// -1 flee left, 1 flee right (a parallel stream into the fog).
  final int direction;
  final double seconds;
}

class PreloadPlan {
  const PreloadPlan(this.skeins);

  /// The next sector's first cohort as reserve silhouettes.
  final List<Skein> skeins;
}

/// Seeded Lévy-flight drift of a reserve member around its skein's point
/// (design §2.1: mu = 2, l_min 6, l_max 60 world units, one step every
/// 0.6-1.4 s; Viswanathan et al. 1999, used as an aesthetic).
class LevyDrift {
  LevyDrift(this._rng);
  final math.Random _rng;
  static const lMin = 6.0, lMax = 60.0, mu = 2.0;

  /// Current offset (world units) and the step target it eases toward.
  double x = 0, z = 0, _tx = 0, _tz = 0, _left = 0;

  void update(double dt) {
    _left -= dt;
    if (_left <= 0) {
      _left = .6 + .8 * _rng.nextDouble();
      final u = math.max(1e-6, _rng.nextDouble());
      final l = math.min(lMax, lMin * math.pow(u, -1 / (mu - 1)).toDouble());
      final a = _rng.nextDouble() * 2 * math.pi;
      // Steps are taken from where it is, leashed to the skein's point.
      _tx = (x + math.cos(a) * l).clamp(-90.0, 90.0);
      _tz = (z + math.sin(a) * l * .6).clamp(-60.0, 60.0);
    }
    final k = 1 - math.exp(-2.2 * dt);
    x += (_tx - x) * k;
    z += (_tz - z) * k;
  }
}

/// The fog's depth bands as the swarm knows them (continuous-swarm design
/// §0): the nearness of every depth-sorted air layer, far to near. It
/// mirrors `Atmosphere.bandNearness` (fog-restoration owns the layers; a
/// test keeps the two equal) so this pure-Dart file needs no Flutter.
const swarmFogBands = [.26, .335, .43, .5, .565];

/// The sentinel's rise (design §6.3): from its foreshadow silhouette's
/// nearness [from] to its station's [to] over the rise, crossing every
/// fog band slowly (an equal share of the middle of the rise per band
/// gap, at least 0.6 s each over 3.2 s), easing in and out at the ends.
/// [p] is the rise progress 0-1.
double sentinelRiseNearness(double p, double from, double to) {
  final knots = <double>[
    from,
    for (final b in swarmFogBands)
      if (b > from + 1e-3 && b < to - 1e-3) b,
    to,
  ];
  final segments = knots.length - 1;
  if (segments <= 0) return to;
  // Ends take an eighth each (eased); the band gaps share the middle.
  const end = .125;
  final middle = segments <= 2 ? 0 : segments - 2;
  final times = <double>[
    for (var i = 0; i < segments; i++)
      segments <= 2
          ? 1 / segments
          : (i == 0 || i == segments - 1)
          ? end
          : (1 - 2 * end) / middle,
  ];
  var t = p.clamp(0.0, 1.0);
  for (var i = 0; i < segments; i++) {
    if (t <= times[i] || i == segments - 1) {
      var u = (t / times[i]).clamp(0.0, 1.0);
      if (i == 0 && segments > 1) u = u * u; // ease in
      if (i == segments - 1 && segments > 1) u = 1 - (1 - u) * (1 - u);
      return knots[i] + (knots[i + 1] - knots[i]) * u;
    }
    t -= times[i];
  }
  return to;
}

/// Rise length of a foreshadowed sentinel (s).
const sentinelRiseSeconds = 3.2;

/// The scheduler state of one run, owned by the model.
class SwarmStream {
  SwarmStream({this.seed = 0});
  int seed;

  /// Members per skein (design §1).
  static const minSkein = 3, maxSkein = 6;

  /// Baseline sustained damage (hits/s, plan/difficulty-calibration.md) and
  /// the fitted efficiency of the campaign pilot (task 1.3).
  static const sustainedHits = 4.35, efficiency = .763;

  /// The next wave's pacing factor q (1 = unaccelerated).
  double q = 1;

  /// A life was lost during this cohort: the next one is unaccelerated.
  bool relaxed = false;

  /// Combat seconds since the current cohort started (T_actual).
  double cohortClock = 0;

  /// Seconds until the next roster skein of the current cohort leaves.
  double releaseLeft = 0;

  /// True while releases are stopped (W5b's drain).
  bool drained = false;

  math.Random rngFor({
    required int sector,
    required int route,
    required int wave,
    int salt = 0,
  }) => math.Random(
    (seed * 2246822519) ^
        (sector * 3266489917) ^
        (route * 668265263) ^
        (wave * 374761393) ^
        (salt * 1013904223),
  );

  /// Skein count of a roster of [count] (design §1: ceil(roster / 5)).
  static int skeinCount(int count) =>
      count <= 0 ? 0 : math.max(1, (count / 5).ceil());

  /// Splits a roster into skeins by formation column band: members sorted
  /// by (column x, roster index) and cut into near-equal contiguous runs of
  /// 3-6; inside a skein the roster order is kept. Returns roster indices.
  static List<List<int>> splitRoster(List<double> homeX) {
    final n = homeX.length;
    if (n == 0) return const [];
    final m = skeinCount(n);
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final c = homeX[a].compareTo(homeX[b]);
        return c != 0 ? c : a.compareTo(b);
      });
    final out = <List<int>>[];
    var start = 0;
    for (var s = 0; s < m; s++) {
      final end = ((s + 1) * n / m).round();
      out.add(order.sublist(start, end)..sort());
      start = end;
    }
    return out;
  }

  /// A reinforcement group of [count] (4-7) flies as one skein up to six,
  /// as two otherwise.
  static List<List<int>> splitGroup(int count) {
    if (count <= 0) return const [];
    if (count <= maxSkein) return [List<int>.generate(count, (i) => i)];
    final half = (count / 2).ceil();
    return [
      List<int>.generate(half, (i) => i),
      List<int>.generate(count - half, (i) => half + i),
    ];
  }

  /// Gates for [skeins] skeins: seeded, consecutive skeins on alternating
  /// sides so the stream keeps crossing the arena (banked renders).
  static List<SwarmGate> gates(int skeins, math.Random rng) {
    final out = <SwarmGate>[];
    var side = rng.nextBool() ? -1 : 1;
    for (var i = 0; i < skeins; i++) {
      final r = rng.nextDouble();
      out.add(
        r < .18
            ? SwarmGate.centre
            : r < .5
            ? (side < 0 ? SwarmGate.deepLeft : SwarmGate.deepRight)
            : (side < 0 ? SwarmGate.left : SwarmGate.right),
      );
      side = -side;
    }
    return out;
  }

  /// Gap before the next roster skein (design §2.2): g = g_base ·
  /// clamp(live / target, 0.5, 1), target = 0.6 · roster.
  static double skeinGap(
    double gBase, {
    required int live,
    required int roster,
  }) {
    final target = math.max(1.0, .6 * roster);
    return gBase * (live / target).clamp(.5, 1.0);
  }

  /// Expected clear time of a cohort of total ordinary [hp] (design §2.3).
  static double expectedClear(int hp) => 2 + hp / (sustainedHits * efficiency);

  /// The pacing factor q = clamp(T_actual / T_expected, floor, 1).
  static double pace(double actual, double expected, double floor) =>
      expected <= 0 ? 1 : (actual / expected).clamp(floor, 1.0);

  /// The lull an early-finished cohort holds at the fog front.
  static double lull(double q) => math.max(.8, 1.4 * q);

  /// Sets q for the next cohort from this one's clear: unaccelerated after
  /// a lost life (Zanac's ALC relaxation), then the clock starts afresh.
  double paceNext({required int cohortHp, required double floor}) {
    q = relaxed ? 1 : pace(cohortClock, expectedClear(cohortHp), floor);
    return q;
  }

  /// A new cohort starts (a wave number becomes current).
  void startCohort() {
    cohortClock = 0;
    releaseLeft = 0;
    relaxed = false;
  }

  void lifeLost() {
    relaxed = true;
    q = 1;
  }

  // --- hooks for cinematic-flow (W5b, design §6.4) -------------------------

  /// Stops releases; returns how many roster skeins will stay unreleased.
  DrainPlan drain({int pendingSkeins = 0}) {
    drained = true;
    return DrainPlan(pendingSkeins);
  }

  /// All present and reserve members switch to a parallel flee into the
  /// fog toward [direction]; W5b runs it.
  RoutPlan rout(int direction) =>
      RoutPlan(direction.sign == 0 ? 1 : direction.sign, 2.4);

  /// The next sector's first cohort as reserve silhouettes.
  PreloadPlan preload(List<double> homeX, math.Random rng) {
    final split = splitRoster(homeX);
    final g = gates(split.length, rng);
    return PreloadPlan([
      for (var i = 0; i < split.length; i++) Skein(i, split[i], g[i]),
    ]);
  }
}
