// --- bonus levels: the catalogues (plan/bonus-levels-interface.md §2)
//
// Append only. The selection draws by index and weight in list order, so a
// new entry at the END never changes what an old run seed selects among the
// earlier entries' slots (bonus_plan.dart).
import '../model.dart' show Power;
import 'bonus_types.dart';
import 'levels/stormfront.dart';
import 'levels/supply_run.dart';

export 'levels/stormfront.dart';
export 'levels/supply_run.dart';

const bonusLevels = <BonusLevelDef>[
  supplyRun,
  // --- bonus level B: add yours below this line
  stormfront,
];

/// Every bonus-only powerup, by id (crates name them by id).
const bonusPowers = <BonusPowerDef>[
  salvageMagnet,
  doubleScore,
  // --- bonus level B: add yours below this line
  lightningRod,
];

/// Run-wide rules; at most one fires per run, the first hit in this order.
const runModifiers = <RunModifierDef>[
  // "Some runs don't have certain powerups."
  RunModifierDef(
    id: 'noShield',
    chance: .05,
    rules: PowerRules(banned: {Power.shield}),
  ),
  // "Or a certain powerup only."
  RunModifierDef(
    id: 'spreadOnly',
    chance: .03,
    rules: PowerRules(only: Power.spread),
  ),
  // "A certain percentage of a chance to happen."
  RunModifierDef(
    id: 'heavyOrdnance',
    chance: .05,
    rules: PowerRules(chances: [PowerChance(Power.large, .35)]),
  ),
];

BonusLevelDef? bonusLevelById(String id) {
  for (final l in bonusLevels) {
    if (l.id == id) return l;
  }
  return null;
}

BonusPowerDef? bonusPowerById(String id) {
  for (final p in bonusPowers) {
    if (p.id == id) return p;
  }
  return null;
}

RunModifierDef? runModifierById(String id) {
  for (final m in runModifiers) {
    if (m.id == id) return m;
  }
  return null;
}
