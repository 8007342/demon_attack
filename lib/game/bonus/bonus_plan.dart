// --- bonus levels: the run's plan (openspec/changes/bonus-levels design §2)
//
// Drawn once per run from the run seed with its own PRNG: nothing here (or
// in model_bonus.dart) ever draws from `ArcadeModel.random`, so a run
// without a plan is the calibrated campaign, draw for draw.
import 'dart:math' as math;

import 'bonus_catalog.dart';
import 'bonus_types.dart';

/// The odds. `standard` ships; tests and tools pass their own.
class BonusTuning {
  const BonusTuning({
    this.runChance = .85,
    this.routeWeights = const [5, 3, 1, 1, 0],
    this.sectors = const {2, 3, 4},
    this.maxPerRun = 1,
    this.modifierScale = 1,
  });

  /// Probability that a run has a bonus level at all.
  final double runChance;

  /// Relative odds of each route 0-4 holding it: early, so most players
  /// meet it; never on the last tour, which belongs to the finale.
  final List<double> routeWeights;

  /// Sectors it may replace (never 1 on route 0, never the carrier's 5).
  final Set<int> sectors;

  /// Bonus levels per run (each on a different route).
  final int maxPerRun;

  /// × every [RunModifierDef.chance]; 0 switches modifiers off.
  final double modifierScale;

  static const standard = BonusTuning();

  /// No bonus level and no modifier, whatever the seed.
  static const off = BonusTuning(runChance: 0, modifierScale: 0);
}

class BonusSlot {
  const BonusSlot(this.route, this.sector, this.level);
  final int route, sector;
  final BonusLevelDef level;

  @override
  String toString() => 'BonusSlot(route $route, sector $sector, ${level.id})';
}

class BonusPlan {
  const BonusPlan(this.slots, this.modifier);
  final List<BonusSlot> slots;
  final RunModifierDef? modifier;

  static const none = BonusPlan([], null);

  /// Mixed into the run seed for the plan's own streams.
  static const salt = 0xB0705;

  BonusLevelDef? at(int route, int sector) {
    for (final s in slots) {
      if (s.route == route && s.sector == sector) return s.level;
    }
    return null;
  }

  /// A plan with [level] at ([route], [sector]) and nothing else (console
  /// and tests).
  factory BonusPlan.forced(
    BonusLevelDef level, {
    required int route,
    required int sector,
    RunModifierDef? modifier,
  }) => BonusPlan([BonusSlot(route, sector, level)], modifier);

  /// The plan of run [runSeed]. Draw order is fixed and every draw is made
  /// whether or not it is used: run chance, then per slot (route, sector,
  /// level), then one draw per modifier in catalogue order.
  factory BonusPlan.forRun(
    int runSeed, {
    BonusTuning tuning = BonusTuning.standard,
    List<BonusLevelDef> levels = bonusLevels,
    List<RunModifierDef> modifiers = runModifiers,
  }) {
    final rng = math.Random(runSeed ^ salt);
    final fires = rng.nextDouble() < tuning.runChance;
    final slots = <BonusSlot>[];
    final sectors = tuning.sectors.toList()..sort();
    final weights = List<double>.of(tuning.routeWeights);
    for (var n = 0; n < tuning.maxPerRun; n++) {
      final ru = rng.nextDouble(), su = rng.nextDouble(), lu = rng.nextDouble();
      if (!fires || sectors.isEmpty) continue;
      final route = _weighted(weights, ru);
      if (route == null) continue;
      weights[route] = 0; // at most one per route
      final sector = sectors[(su * sectors.length).floor() % sectors.length];
      final fit = [
        for (final l in levels)
          if (l.weight > 0 && l.fits(route, sector)) l,
      ];
      final pick = _weighted([for (final l in fit) l.weight], lu);
      if (pick != null) slots.add(BonusSlot(route, sector, fit[pick]));
    }
    RunModifierDef? modifier;
    for (final m in modifiers) {
      final u = rng.nextDouble();
      if (modifier == null && u < m.chance * tuning.modifierScale) modifier = m;
    }
    if (slots.isEmpty && modifier == null) return none;
    return BonusPlan(List.unmodifiable(slots), modifier);
  }

  static int? _weighted(List<double> weights, double u) {
    final total = weights.fold(0.0, (a, b) => a + math.max(0, b));
    if (total <= 0) return null;
    var roll = u * total;
    int? last;
    for (var i = 0; i < weights.length; i++) {
      if (weights[i] <= 0) continue;
      last = i;
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return last;
  }

  /// The stream of in-level draws (crates, chance rules) for a sector.
  static math.Random levelRng(int runSeed, int route, int sector) =>
      math.Random(runSeed ^ salt ^ (route * 64 + sector) * 7919);

  @override
  String toString() =>
      'BonusPlan(${slots.join(', ')}${modifier == null ? '' : ', ${modifier!.id}'})';
}
