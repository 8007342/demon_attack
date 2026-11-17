// --- bonus level #1: Supply Run (openspec/changes/bonus-levels design §6)
//
// A fleet supply convoy was shot down over the sector. Its crates come down
// on parachutes through a thin screen of brood scavengers: shoot a crate
// open and catch what falls. Kills drop nothing here; the crates carry
// every regular power and the two bonus-only ones.
import '../../model.dart' show Power;
import '../bonus_types.dart';
import 'supply_run_cues.dart';

export 'supply_run_cues.dart';

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
  // mission-medals: one short sentence on the goal (the operator did not
  // understand the old two-clause rule); the crate's cracks and the radio
  // carry the rest in the level.
  brief: 'Shoot the falling crates open and catch the cargo.',
  // mission-medals: no rule of play, only the cues (supply_run_cues.dart).
  mechanic: SupplyRunCues.new,
  weight: 1,
  waves: BonusWaves(),
  rules: PowerRules(killDrops: false),
  // fire-rate-tune: every 3 s (was 3.5): with no kill drops the crates
  // are the level's only powers, and the gun is 23 % slower.
  crates: BonusCrates(
    every: 3,
    first: 2,
    max: 3,
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
  // bonus-balance: kills pay 60 %; crates, the clear and a flawless run
  // pay the rest, up to the cap, so a perfect Supply Run is worth about
  // the sector it replaces (plan/calibration-current.md, Bonus balance).
  scoring: BonusScoring(
    pointsScale: .6,
    clearPar: .25,
    flawlessPar: .1,
    capPar: .45,
  ),
  look: BonusLook(
    tint: 0xFFFFD79A, // a warm dawn over the sector's own backdrop
    strength: .22,
    glow: 0x66FFE2A0,
    fog: .06,
  ),
);
