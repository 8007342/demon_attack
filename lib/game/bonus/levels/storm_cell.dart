/// The storm of bonus level #2, "Stormfront" (openspec/changes/bonus-levels,
/// specs/bonus-level-stormfront): a seeded schedule of lightning strikes.
///
/// Pure Dart with its own PRNG: it never reads the model and never draws
/// from `ArcadeModel.random`. The level's mechanic (`stormfront.dart`) feeds
/// it the ship and the swarm each step and applies the strikes it returns.
///
/// One strike is a **tell** (a leader flickers down a column and a marker
/// blinks on the ship's row, at least [StormTuning.tell] seconds of real
/// time), the **bolt** (one step: everything in the column is hit) and an
/// **afterglow** (presentation only). Most tells sample the ship's x once,
/// when they start, and never follow it: the player baits a bolt under the
/// swarm and slides away.
library;

import 'dart:math' as math;

/// What a tell was aimed at when it started.
enum StrikeAim {
  /// The ship's x, sampled once (the bait).
  ship,

  /// The densest column of the swarm (the storm helps).
  swarm,

  /// A fork beside another tell: it closes one side of the dodge.
  fork,
}

class StormTuning {
  const StormTuning({
    this.first = 3.2,
    this.gapMin = 2.5,
    this.gapMax = 3.7,
    this.tell = 1.15,
    this.glow = .42,
    this.shipShare = .68,
    this.forkChance = 0,
    this.forkMin = 64,
    this.forkMax = 104,
    this.column = 34,
    this.core = 13,
    this.damage = 2,
    this.rodColumn = 52,
  });

  /// Seconds of combat before the level's first tell.
  final double first;

  /// Seconds between one bolt and the next tell (divided by the hostile
  /// rate: Easy's storm is slower).
  final double gapMin, gapMax;

  /// Seconds from the tell to the bolt. Real time, never scaled, never
  /// under one second (the project's rule for every lethal tell).
  final double tell;

  /// Seconds the bolt's afterglow stays on screen.
  final double glow;

  /// Share of tells aimed at the ship; the rest pick the swarm's densest
  /// column.
  final double shipShare;

  /// Chance a ship-aimed tell forks: a second column [forkMin]-[forkMax]
  /// units to one side, struck at the same instant.
  final double forkChance, forkMin, forkMax;

  /// Half-width of the column that hits creatures.
  final double column;

  /// Half-width of the column that hits the ship (narrower than the marker
  /// that is drawn: a near miss is survivable).
  final double core;

  /// Damage a bolt does to a creature (a homing missile's heavy hit).
  /// fire-rate-tune: 2 (was 3). Dive shields lost a point, so a bolt of 3
  /// broke through divers it used to stop at, and the storm ran a fifth
  /// easier than the sector it replaces.
  final int damage;

  /// [column] while the ship carries the lightning rod.
  final double rodColumn;

  static const easy = StormTuning(first: 4, gapMin: 3, gapMax: 4.2);
  // bonus-balance: Normal and Hard strike less often than first built
  // (2.5-3.7 s and 2.2-3.2 s, fork .35): the storm cleared the swarm too fast,
  // so the level ran 17-26 % shorter than the sector it replaces.
  static const normal = StormTuning(gapMin: 3.1, gapMax: 4.5, forkChance: .2);
  static const hard = StormTuning(gapMin: 3.3, gapMax: 4.7, forkChance: .3);

  /// Later routes fork a little more often (never faster tells) and, so
  /// the storm does not clear their bigger swarms ahead of the pilot,
  /// strike a tenth less often per route (bonus-balance).
  StormTuning forRoute(int route) => StormTuning(
    first: first,
    gapMin: gapMin * (1 + .1 * route.clamp(0, 4)),
    gapMax: gapMax * (1 + .1 * route.clamp(0, 4)),
    tell: tell,
    glow: glow,
    shipShare: shipShare,
    forkChance: forkChance == 0
        ? 0
        : math.min(.5, forkChance + .05 * route.clamp(0, 4)),
    forkMin: forkMin,
    forkMax: forkMax,
    column: column,
    core: core,
    damage: damage,
    rodColumn: rodColumn,
  );
}

/// One strike, from its tell to the end of its afterglow.
class StormStrike {
  StormStrike(this.index, this.x, this.aim, this.tellTotal, this.shape)
    : tellLeft = tellTotal;

  /// Order in the level (0-based), stable for a seed.
  final int index;

  /// The column, fixed when the tell starts.
  final double x;
  final StrikeAim aim;
  final double tellTotal;

  /// Seed of the bolt's drawn shape (presentation).
  final int shape;
  double tellLeft;

  /// Afterglow left; meaningful once [landed].
  double glowLeft = 0;
  bool landed = false;

  /// The tell was cut short (the ship was lost or the fight ended): no bolt.
  bool fizzled = false;

  /// The ship carried the rod when this tell started: a wider column.
  bool rod = false;

  /// Half-width that hits creatures (set from the tuning at the tell).
  double column = 0;

  /// Creatures this bolt destroyed, and whether it met the ship (written by
  /// the mechanic; read by the painter and the tests).
  int kills = 0;
  bool hitShip = false, grounded = false;

  bool get telling => !landed && !fizzled;

  /// 0 at the tell's start, 1 at the bolt.
  double get tellProgress =>
      tellTotal <= 0 ? 1 : (1 - tellLeft / tellTotal).clamp(0.0, 1.0);
}

/// The seeded storm of one bonus level.
class StormCell {
  StormCell(this.seed, {this.tuning = StormTuning.normal})
    : _random = math.Random(seed),
      _next = tuning.first;

  final int seed;
  final StormTuning tuning;
  final math.Random _random;

  /// Tells, bolts and afterglows on screen, oldest first.
  final List<StormStrike> strikes = [];
  double _next;
  int _count = 0;

  /// Tells started, bolts landed.
  int get started => _count;
  int landed = 0;

  /// Seconds until the next tell may start (the painter's build-up hum).
  double get nextIn => _next;

  /// Whether any tell is running.
  bool get telling => strikes.any((s) => s.telling);

  /// Advances the storm by [dt].
  ///
  /// [active]: combat with the ship in play. While false no tell starts and
  /// running tells fizzle (the life-loss regroup and every cinematic phase
  /// are safe); afterglows still fade. [swarm]: x of every creature a bolt
  /// can hit. [rate]: the hostile rate (slows the gaps on Easy). [rod]: the
  /// ship carries the lightning rod, so every tell is drawn to it.
  ///
  /// Returns the strikes whose bolt lands in this step.
  List<StormStrike> step(
    double dt, {
    required double shipX,
    required List<double> swarm,
    bool active = true,
    double rate = 1,
    bool rod = false,
  }) {
    final out = <StormStrike>[];
    for (final s in strikes) {
      if (s.landed) {
        s.glowLeft -= dt;
      } else if (!s.fizzled) {
        if (!active) {
          s.fizzled = true;
          continue;
        }
        s.tellLeft -= dt;
        if (s.tellLeft <= 0) {
          s
            ..landed = true
            ..glowLeft = tuning.glow;
          landed++;
          out.add(s);
        }
      }
    }
    strikes.removeWhere((s) => s.fizzled || (s.landed && s.glowLeft <= 0));
    if (!active || dt <= 0) return out;
    // The gap runs from the bolt: no new tell while one is running.
    if (strikes.any((s) => s.telling)) return out;
    _next -= dt * rate;
    if (_next <= 0) {
      _begin(shipX: shipX, swarm: swarm, rod: rod);
      _next =
          tuning.gapMin +
          _random.nextDouble() * (tuning.gapMax - tuning.gapMin);
    }
    return out;
  }

  void _begin({
    required double shipX,
    required List<double> swarm,
    required bool rod,
  }) {
    // Always four draws per tell, whatever they decide: the schedule of a
    // seed does not depend on what the player or the swarm did before.
    final aimRoll = _random.nextDouble();
    final forkRoll = _random.nextDouble();
    final forkOffset = _random.nextDouble();
    final shape = _random.nextInt(1 << 30);
    final atShip = rod || aimRoll < tuning.shipShare || swarm.isEmpty;
    final x = atShip ? shipX.clamp(18.0, 342.0) : densest(swarm, tuning.column);
    final column = rod ? tuning.rodColumn : tuning.column;
    strikes.add(
      StormStrike(
          _count++,
          x,
          atShip ? StrikeAim.ship : StrikeAim.swarm,
          tuning.tell,
          shape,
        )
        ..rod = rod
        ..column = column,
    );
    if (atShip && !rod && forkRoll < tuning.forkChance) {
      final d = tuning.forkMin + forkOffset * (tuning.forkMax - tuning.forkMin);
      // Toward the roomier side, so the fork is always on screen and the
      // other side is always open.
      final side = x < 180 ? 1 : -1;
      strikes.add(
        StormStrike(
          _count++,
          (x + side * d).clamp(18.0, 342.0),
          StrikeAim.fork,
          tuning.tell,
          shape ^ 0x2f6b,
        )..column = column,
      );
    }
  }

  /// The x of the creature with the most neighbours within [reach] (the
  /// first such creature in list order on a tie): the swarm's densest
  /// column.
  static double densest(List<double> xs, double reach) {
    var best = xs.first;
    var bestCount = -1;
    for (final x in xs) {
      var n = 0;
      for (final o in xs) {
        if ((o - x).abs() <= reach) n++;
      }
      if (n > bestCount) {
        bestCount = n;
        best = x;
      }
    }
    return best;
  }
}
