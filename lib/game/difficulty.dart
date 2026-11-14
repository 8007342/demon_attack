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
