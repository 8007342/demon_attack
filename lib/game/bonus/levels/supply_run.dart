// --- bonus level #1: Supply Run (openspec/changes/bonus-levels design §6)
//
// A fleet supply convoy was shot down over the sector. Its crates come down
// on parachutes through a thin screen of brood scavengers: shoot a crate
// open and catch what falls. Kills drop nothing here; the crates carry
// every regular power and the two bonus-only ones.
import '../../model.dart' show Power;
import '../bonus_types.dart';

/// Falling pickups and heart pieces fly to the ship.
const salvageMagnet = BonusPowerDef(
  id: 'salvageMagnet',
  label: 'MAGNET',
  badge: 2, // the shield's U, recoloured: a horseshoe magnet
  tint: 0xFFFF7A5C,
  seconds: 12,
  magnet: 150,
);

/// Kill and crate points count twice.
const doubleScore = BonusPowerDef(
  id: 'doubleScore',
  label: 'DOUBLE',
  badge: 5, // the large shot's orb, as a pair of gold coins
  tint: 0xFFFFE27A,
  twin: true,
  seconds: 9,
  scoreScale: 2,
);

const supplyRun = BonusLevelDef(
  id: 'supplyRun',
  label: 'SUPPLY RUN',
  brief:
      'Crack the falling crates: three hits each. Kills drop nothing; '
      'the cargo drops everything.',
  weight: 1,
  waves: BonusWaves(
    count: 2,
    rosterScale: .6,
    reinforcementScale: .5,
    maxKind: 1,
  ),
  rules: PowerRules(killDrops: false),
  crates: BonusCrates(
    every: 4.5,
    first: 1.5,
    max: 3,
    total: 8,
    points: 150,
    powers: [
      Power.spread,
      Power.rapid,
      Power.shield,
      Power.powerful,
      Power.large,
    ],
    bonusPowers: ['salvageMagnet', 'doubleScore'],
    bonusPowerChance: .3,
  ),
  // Kills here pay a fraction of the replaced sector's; the awards
  // make a clean Supply Run worth about that sector (measured in
  // openspec/changes/bonus-levels/design.md §6).
  scoring: BonusScoring(clearPar: 1, flawlessPar: .3, capPar: 1.5),
  look: BonusLook(
    tint: 0xFFFFD79A, // a warm dawn over the sector's own backdrop
    strength: .22,
    glow: 0x66FFE2A0,
    fog: .06,
  ),
);
