import 'dart:math' as math;

enum Difficulty { easy, normal, hard }

/// One bounded encounter curve. Arrival timing does not create new enemy tiers.
/// See plan/difficulty-calibration.md for research, formulas and audit limits.
class DifficultyPolicy {
  const DifficultyPolicy(this.difficulty);
  final Difficulty difficulty;

  int get startingLives => difficulty == Difficulty.easy ? 5 : 3;
  double get hostileRate => switch (difficulty) {
    Difficulty.easy => .9,
    Difficulty.normal => 1,
    Difficulty.hard => 1.05,
  };
  double get enemyPoints => difficulty == Difficulty.easy ? .75 : 1;
  double get density => switch (difficulty) {
    Difficulty.easy => .8,
    Difficulty.normal => 1,
    Difficulty.hard => 1.2,
  };
  double get heartDropChance => switch (difficulty) {
    Difficulty.easy => .012,
    Difficulty.normal => .008,
    Difficulty.hard => 0,
  };

  // --- wave pressure: the next wave closes in out of the horizon fog once
  // the current one is down to its last few, so the player feels the clock
  // (plan/difficulty-calibration.md: timing beats, never extra HP).
  // The threshold never exceeds the smallest reinforcement group, so
  // stragglers + a fresh roster stay inside the calibrated occupancy bound.

  /// At most this many live enemies (all reinforcements in) starts the
  /// next wave's approach.
  int get pressureThreshold => switch (difficulty) {
    Difficulty.easy => 2,
    Difficulty.normal => 3,
    Difficulty.hard => 4,
  };

  /// Seconds (at hostile rate) the approaching wave takes to reach the
  /// fight if the stragglers are not finished first.
  double get incomingSeconds => switch (difficulty) {
    Difficulty.easy => 10,
    Difficulty.normal => 8,
    Difficulty.hard => 6,
  };

  // --- continuous swarm (openspec/changes/continuous-swarm design §2.4):
  // timing, never HP. None of these touch counts, HP or the elite budget
  // (plan/difficulty-calibration.md); they only decide when a wave's
  // skeins leave the fog and how fast its squads fly.

  /// Base gap (s, hostile rate) between two roster skeins of a wave; it
  /// shrinks to half while few of the wave are left alive.
  double get skeinGap => switch (difficulty) {
    Difficulty.easy => 1.3,
    Difficulty.normal => 1.1,
    Difficulty.hard => .95,
  };

  /// Floor of the next wave's approach factor q after a fast clear.
  double get paceFloor => switch (difficulty) {
    Difficulty.easy => .65,
    Difficulty.normal => .55,
    Difficulty.hard => .5,
  };

  /// Angular and lateral speed factor of the squads' fighting patterns,
  /// times the route's movement growth 1 + 0.04 r.
  // --- demon intelligence (openspec/changes/demon-intelligence §7):
  // the skill level's cap; skill only sharpens decisions, never content.
  double get skillCap => switch (difficulty) {
    Difficulty.easy => .5,
    Difficulty.normal => .8,
    Difficulty.hard => 1.0,
  };

  /// The sentinel final rush (design §6): birth chance (+ up to 0.10
  /// with skill), rush shield, top speed (u/s at hostile rate), homing
  /// turn rate (°/s) and passes.
  ///
  /// playtest-fixes-3: rushes a little more often (was .20 / .35 / .45;
  /// Hard .55 cost the Average pilot +3.4 lives on route 1, so .50),
  /// and the rush shield is the super-powerful diving shield: only
  /// offensive powers and homing hits wear it (breaker damage), so it
  /// is about twice the old points (was 3 / 4 + route ÷ 2 / 5 + route ÷ 2).
  double get rushChance => switch (difficulty) {
    Difficulty.easy => .28,
    Difficulty.normal => .45,
    Difficulty.hard => .50,
  };
  int rushShieldFor(int route) => switch (difficulty) {
    Difficulty.easy => 6,
    Difficulty.normal => 8 + route ~/ 2,
    Difficulty.hard => 10 + route ~/ 2,
  };
  double get rushSpeed => switch (difficulty) {
    Difficulty.easy => 640,
    Difficulty.normal => 780,
    Difficulty.hard => 880,
  };
  double get rushTurnRate => switch (difficulty) {
    Difficulty.easy => 0,
    Difficulty.normal => 50,
    Difficulty.hard => 75,
  };
  int get rushPasses => switch (difficulty) {
    Difficulty.easy => 1,
    Difficulty.normal => 2,
    Difficulty.hard => 3,
  };

  double swarmTempo({required int route}) =>
      switch (difficulty) {
        Difficulty.easy => .85,
        Difficulty.normal => 1.0,
        Difficulty.hard => 1.1,
      } *
      (1 + .04 * route.clamp(0, 4));

  int reinforcementFlocks({required int route, required int sector}) =>
      difficulty == Difficulty.easy ? (route == 0 ? 0 : 1) : 2;

  int reinforcementSize({required int route, required int flock}) =>
      ((4 + route.clamp(0, 4) ~/ 2) * density).round() + flock.clamp(0, 1);

  int escortSize({required int route, required int sector}) =>
      12 + difficulty.index + route.clamp(0, 2);

  /// Shared by opening creatures, reinforcements and the sentinel's bodyguard.
  /// A species never gains HP just because it arrived in a later sub-wave.
  int ordinaryHealth({
    required int route,
    required int kind,
    required bool elite,
  }) => (1 + kind.clamp(0, 3) ~/ 2 + route.clamp(0, 4) ~/ 2 + (elite ? 1 : 0))
      .clamp(1, 5);

  /// Whole-wave birth budget, never renewed by a fresh reinforcement/escort.
  int eliteBudget({required int route}) =>
      route.clamp(0, 4) == 0 ? 0 : 1 + difficulty.index;

  // Preserve integer hit breakpoints and the advertised double-damage weapon.
  // Modes tune enemy budgets and area coverage rather than random partial hits.
  int weaponDamage({required bool powerful}) => powerful ? 2 : 1;
  double get largeBlastRadius => switch (difficulty) {
    Difficulty.easy => 32,
    Difficulty.normal => 30,
    Difficulty.hard => 28,
  };

  static const List<int> _normalBossShieldByRoute = [48, 68, 92, 116, 140];
  static const List<int> _normalBossCoreByRoute = [16, 24, 34, 44, 56];

  int bossHealth(int normal) =>
      math.max(1, (normal * (difficulty == Difficulty.easy ? .8 : 1)).round());

  int bossShieldForRoute(int route) =>
      bossHealth(_normalBossShieldByRoute[route.clamp(0, 4)]);

  int bossCoreForRoute(int route) =>
      bossHealth(_normalBossCoreByRoute[route.clamp(0, 4)]);

  int rosterCount({
    required int sector,
    required int wave,
    required int route,
  }) {
    final base =
        8 +
        2 * (sector.clamp(1, 4) - 1) +
        (wave.clamp(1, 7) - 1) +
        route.clamp(0, 4);
    final cap = switch (difficulty) {
      Difficulty.easy => 20,
      Difficulty.normal => 24,
      Difficulty.hard => 28,
    };
    return (base * density).round().clamp(4, cap);
  }
}
