// --- bonus levels: a level's own rule of play (openspec/changes/
// bonus-levels, specs/bonus-level-stormfront; added for bonus level #2)
//
// `BonusLevelDef` is data: waves, powerup rules, crates, scoring, a look.
// A level whose fantasy needs a rule that data cannot say (a storm, a
// hazard, a timer) adds a [BonusMechanic]: one live object per visit of
// the level, made by `BonusLevelDef.mechanic`, stepped by the model
// (`lib/game/model_bonus.dart`) and read by the level's painter
// (`lib/game/bonus/bonus_painters.dart`).
//
// Rules for a mechanic (they keep a seeded run replayable and the
// calibrated campaign untouched):
// - it draws only from a PRNG seeded with [BonusMechanicContext.seed],
//   never from `ArcadeModel.random`;
// - it acts on the model through its public surface (`hitDemon`,
//   `hitPlayer`, `pickups`, `bonusEvent`, `bonusAward`);
// - bonus score goes through `bonusAward`, which enforces the level's cap;
// - every lethal tell lasts at least one second of real time, and nothing
//   starts while the ship is away;
// - pure Dart, no `dart:ui`: the model is also run by `dart run` tools.
import '../model.dart' show ArcadeModel, Difficulty;

/// What a mechanic is made from: one visit of one level.
class BonusMechanicContext {
  const BonusMechanicContext({
    required this.seed,
    required this.route,
    required this.sector,
    required this.difficulty,
  });

  /// The level's own seed (run seed, route and sector): the same visit
  /// always gets the same one.
  final int seed;

  /// Zero-based route and the replaced sector (2-4).
  final int route, sector;
  final Difficulty difficulty;
}

/// A bonus level's own rule of play.
abstract class BonusMechanic {
  /// One fixed combat step (1/60 s), also while the ship is away.
  void step(ArcadeModel model, double dt);

  /// One fixed step outside combat (wave entrances, the Rout, the
  /// Pursuit): finish what is on screen, start nothing.
  void idle(ArcadeModel model, double dt) {}
}

typedef BonusMechanicFactory = BonusMechanic Function(BonusMechanicContext);
