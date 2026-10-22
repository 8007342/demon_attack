import 'dart:math' as math;

enum Difficulty { easy, normal, hard }

/// Balance knobs for hostile actors; player movement and firing stay identical.
class DifficultyPolicy {
  const DifficultyPolicy(this.difficulty);
  final Difficulty difficulty;

  int get startingLives => difficulty == Difficulty.easy ? 5 : 3;
  double get hostileRate => difficulty == Difficulty.easy ? .9 : 1;
  double get enemyPoints => difficulty == Difficulty.easy ? .75 : 1;
  double get heartDropChance => switch (difficulty) {
    Difficulty.easy => .012,
    Difficulty.normal => .008,
    Difficulty.hard => 0,
  };
  int reinforcementFlocks({required int route, required int sector}) =>
      switch (difficulty) {
        Difficulty.easy => route == 0 ? 0 : 2,
        Difficulty.normal => (2 + route ~/ 3).clamp(2, 3),
        Difficulty.hard => (2 + route).clamp(2, 4),
      };
  int reinforcementSize({required int route, required int flock}) =>
      (switch (difficulty) {
        Difficulty.easy => 4 + flock,
        Difficulty.normal => 6 + flock * 2,
        Difficulty.hard => 8 + flock * 2,
      }) +
      route.clamp(0, 4) ~/ 2;
  int escortSize({required int route, required int sector}) => math.max(
    12,
    reinforcementSize(
          route: route,
          flock: math.max(
            0,
            reinforcementFlocks(route: route, sector: sector) - 1,
          ),
        ) +
        4,
  );
  int reinforcementHealth({required int route, required int flock}) =>
      2 + route.clamp(0, 3) + flock * 2 + difficulty.index;
  int bossHealth(int normal) =>
      math.max(1, (normal * (difficulty == Difficulty.easy ? .8 : 1)).round());
  int rosterCount({
    required int sector,
    required int wave,
    required int route,
  }) {
    final base = 6 + sector * 2 + (wave - 1) * 2;
    final multiplier = switch (difficulty) {
      Difficulty.easy => .8,
      Difficulty.normal => 1.0,
      Difficulty.hard => 1.2,
    };
    final growth = switch (difficulty) {
      Difficulty.easy => 1,
      Difficulty.normal => 3,
      Difficulty.hard => 4,
    };
    final cap = switch (difficulty) {
      Difficulty.easy => 24,
      Difficulty.normal => 30,
      Difficulty.hard => 36,
    };
    return ((base * multiplier).round() + route.clamp(0, 4) * growth).clamp(
      4,
      cap,
    );
  }
}
