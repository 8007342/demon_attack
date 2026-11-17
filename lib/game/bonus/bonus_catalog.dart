// --- bonus levels: the catalogues (plan/bonus-levels-interface.md §2)
//
// Append only. The selection draws by index and weight in list order, so a
// new entry at the END never changes what an old run seed selects among the
// earlier entries' slots (bonus_plan.dart).
import '../model.dart' show Power;
import 'bonus_types.dart';
import 'levels/crosswind.dart';
import 'levels/stormfront.dart';
import 'levels/supply_run.dart';

export 'levels/crosswind.dart';
export 'levels/stormfront.dart';
export 'levels/supply_run.dart';

const bonusLevels = <BonusLevelDef>[
  supplyRun,
  // --- bonus level B: add yours below this line
  stormfront,
  crosswind, // --- crosswind: bonus level #3
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
    brief: 'No shield modules this run.',
    label: 'NO SHIELDS',
  ),
  // "Or a certain powerup only."
  RunModifierDef(
    id: 'spreadOnly',
    chance: .03,
    rules: PowerRules(only: Power.spread),
    brief: 'Spread modules only this run.',
    label: 'SPREAD ONLY',
  ),
  // "A certain percentage of a chance to happen."
  RunModifierDef(
    id: 'heavyOrdnance',
    chance: .05,
    rules: PowerRules(chances: [PowerChance(Power.large, .35)]),
    brief: 'Extra blast rounds in the drops this run.',
    label: 'HEAVY ORDNANCE',
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

/// bonus-balance: the display name of a run record's modifier id (a bonus
/// level or a run modifier); an id this build does not know (a newer
/// record) is spelled out from its camelCase.
String runTagLabel(String id) {
  final level = bonusLevelById(id);
  if (level != null) return level.label;
  final rule = runModifierById(id);
  if (rule != null && rule.label.isNotEmpty) return rule.label;
  return id
      .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .toUpperCase();
}
