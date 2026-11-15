# Bonus levels: framework interface (agent A -> agent B)

Change: `openspec/changes/bonus-levels` (R9, R10). Branch: `work/bonus-levels-a`. This note is the contract; the code
lands on the same branch right after it. Re-fetch (`git fetch origin work/bonus-levels-a`) before you integrate: the
last section, "Changes since the first commit", lists anything that moved.

**A bonus level is data.** You add one Dart file with one `const BonusLevelDef`, one line in the catalogue, radio lines
in `art/comms/lines.json`, and tests. You do not edit `lib/game/model.dart`, `scene.dart` or `main.dart`. If your level
needs a rule the framework does not have, add a field with a neutral default to the data class and one hook in
`lib/game/model_bonus.dart`, and write it into your blocker log.

## 1. What a bonus level is

- It **replaces one regular sector** (sector 2, 3 or 4 of a route; never sector 1 of route 0, never the carrier,
  sector 5). The sector index, the route, the sector's backdrop, ground war and music stay; the *content* is the
  bonus level's: its waves, its powerup rules, its bonus powerups, its crates, its scoring, its radio, its look.
- The run reaches it and leaves it through the ordinary sector change (Rout, Pursuit, Descent in the fog). No title,
  no floating text: the bonus is announced by radio, through its "URGENT MISSION!" radio card on the comms dock (see
  "Urgent-mission card" at the end).
- About once per run: the run's plan is drawn at `start(runSeed: …)` from the plan's own PRNG. **A run started
  without a run seed has no bonus level and no run modifier**: that is the calibrated campaign every existing test
  and tool measures.

## 2. Files

| File | Owner | What |
|---|---|---|
| `lib/game/bonus/bonus_types.dart` | A | the data classes below (pure Dart) |
| `lib/game/bonus/bonus_plan.dart` | A | `BonusTuning`, `BonusPlan.forRun`, selection |
| `lib/game/bonus/bonus_catalog.dart` | A, **B adds one line** | `bonusLevels`, `bonusPowers`, `runModifiers` |
| `lib/game/bonus/levels/supply_run.dart` | A | bonus level #1 |
| `lib/game/bonus/levels/<your_id>.dart` | **B** | bonus level #2 |
| `lib/game/model_bonus.dart` | A | `part of 'model.dart'`: every model hook |
| `lib/game/bonus/bonus_look.dart` | A | the scene's colour grade for a bonus level |
| `test/bonus_levels_test.dart`, `test/bonus_supply_run_test.dart` | A | framework and level #1 |
| `test/bonus_<your_id>_test.dart` | **B** | level #2 |

Catalogue line (append yours after the marker; that one line is the only shared edit):

```dart
const bonusLevels = <BonusLevelDef>[
  supplyRun,
  // --- bonus level B: add yours below this line
];
```

## 3. Data classes (`bonus_types.dart`)

```dart
/// Which powers may drop. Applies to kill drops and supply crates (regular and bonus).
class PowerRules {
  const PowerRules({this.banned = const {}, this.only, this.chances = const [], this.killDrops = true});
  final Set<Power> banned;         // never drop
  final Power? only;               // every drop becomes this one (wins over banned)
  final List<PowerChance> chances; // per drop: with `chance`, the drop becomes `power` (plan PRNG, in list order)
  final bool killDrops;            // false: kills drop no powers (crates still do)
  static const none = PowerRules();
  PowerRules merge(PowerRules inner); // run modifier (outer) + level (inner): bans union, inner.only ?? outer.only,
                                      // chances outer then inner, killDrops and-ed
}
class PowerChance { const PowerChance(this.power, this.chance); final Power power; final double chance; }

/// A run-wide rule, rolled once per run.
class RunModifierDef {
  const RunModifierDef({required this.id, required this.chance, required this.rules, this.minRoute = 0});
  final String id;      // radio trigger `runModifier.<id>`
  final double chance;  // probability per run; at most one modifier fires (first hit in catalogue order)
  final PowerRules rules;
}

/// A powerup that exists only inside bonus levels. Its effect is a sum of primitives.
class BonusPowerDef {
  const BonusPowerDef({required this.id, required this.label, required this.badge, required this.tint,
      this.twin = false, this.seconds = 9, this.scoreScale = 1, this.magnet = 0, this.grants = const [],
      this.fireScale = 1});
  final String id;         // radio variant `bonusPickup.<id>`
  final String label;      // console/review name, upper case (never drawn over the play area)
  final bool twin;         // draw the badge as an overlapping pair
  final int badge;         // column in combat.png's pickup row (0 spread, 1 rapid, 2 shield, 3 heart, 4 powerful, 5 large)
  final int tint;          // ARGB the badge is tinted with, so it never reads as the regular power
  final double seconds;    // own timer; freezes outside combat like regular powers
  final double scoreScale; // kill and crate points x this while active
  final double magnet;     // pickups within this many units fly to the ship (0: off)
  final List<Power> grants;// regular powers collected with it (normal exclusions apply)
  final double fireScale;  // player fire interval x this (< 1 is faster)
}

class BonusWaves {
  const BonusWaves({this.count = 2, this.rosterScale = 1, this.reinforcementScale = 1,
      this.sentinels = false, this.elites = false, this.maxKind});
  final int count;                 // waves in the level (regular sectors: 3-7)
  final double rosterScale;        // x the sector's calibrated roster (min 3 creatures)
  final double reinforcementScale; // x the sector's finite reinforcement groups
  final bool sentinels, elites;    // false: none in this level
  final int? maxKind;              // cap the species (0-3); null: the sector's own
}

/// Parachute supply crates during the level (the carrier fight's `SupplyCrate`, 3 hits, drops its pickup).
class BonusCrates {
  const BonusCrates({this.every = 0, this.first = 2, this.max = 2, this.total = 0, this.points = 0,
      this.powers = const [], this.bonusPowers = const [], this.bonusPowerChance = .25});
  final double every, first; // seconds between drops (0: no crates) and before the first
  final int max, total; // on screen at once; in the whole level (0: unlimited)
  final int points;     // per crate opened, x (route + 1)
  final List<Power> powers;       // drawn uniformly (plan PRNG), then filtered by PowerRules
  final List<String> bonusPowers; // ids; each crate is a bonus power with probability bonusPowerChance
  final double bonusPowerChance;  // default .25
}

class BonusScoring {
  const BonusScoring({this.pointsScale = 1, this.clearBonus = 0, this.flawlessBonus = 0, this.cap = 0,
      this.clearPar = 0, this.flawlessPar = 0, this.capPar = 0});
  final double pointsScale; // kill points x this inside the level
  final int clearBonus;     // on the level's last kill, x (route + 1)
  final int flawlessBonus;  // added when no ship was lost in the level, x (route + 1)
  final int cap;            // most the level may add beyond ordinary kill points, x (route + 1); 0: uncapped
  final double clearPar, flawlessPar, capPar; // the same three as shares of `model.sectorPar`. PREFER THESE:
                            // flat numbers made level #1 pay a third of the sector it replaced (design §6.1)
}

/// Presentation-only colour grade over the sector's own backdrop (no new art).
class BonusLook {
  const BonusLook({this.tint = 0x00000000, this.strength = 0, this.glow = 0x00000000, this.fog = 0, this.cue});
  final int tint;        // ARGB wash over the backdrop (under ground units, creatures, ship, shots, HUD)
  final double strength; // 0-1
  final int glow;        // ARGB light along the horizon (alpha 0: none)
  final double fog;      // extra mid-fog cover 0-.5
  final String? cue;     // music cue name when its own exists (none yet: the sector's cue plays)
}

class BonusLevelDef {
  const BonusLevelDef({required this.id, required this.label, required this.weight, this.sectors = const {2, 3, 4},
      this.minRoute = 0, this.maxRoute = 4, this.waves = const BonusWaves(), this.rules = PowerRules.none,
      this.crates = const BonusCrates(), this.scoring = const BonusScoring(), this.look = const BonusLook()});
  final String id;     // camelCase; radio triggers key on it
  final String label;  // the /console BONUS LEVEL button, upper case
  final double weight; // relative odds among the levels eligible for the drawn slot
  …
}
```

## 4. Selection (`bonus_plan.dart`)

```dart
class BonusTuning {            // one const, `BonusTuning.standard`; tests pass their own
  final double runChance;      // .85  a run has a bonus level at all
  final List<double> routeWeights; // [5, 3, 1, 1, 0]: early, so most players meet it; never on the last tour
  final Set<int> sectors;      // {2, 3, 4}
  final int maxPerRun;         // 1
  final double modifierScale;  // 1  x every RunModifierDef.chance (0 switches modifiers off)
}
class BonusSlot { final int route, sector; final BonusLevelDef level; }
class BonusPlan {
  static const BonusPlan none;
  static BonusPlan forRun(int runSeed, {BonusTuning tuning, List<BonusLevelDef> levels, List<RunModifierDef> modifiers});
  final List<BonusSlot> slots; final RunModifierDef? modifier;
  BonusLevelDef? at(int route, int sector);
}
```

- PRNG: `Random(runSeed ^ 0xB0705)`, used only for the plan; in-level draws (crates, chances) use
  `BonusPlan.levelRng(runSeed, route, sector)`, reseeded at each level start. **Nothing in the framework draws from `ArcadeModel.random`.**
- Order of draws is fixed (run chance, route, sector, level, then each modifier), so adding a level or a modifier at
  the END of a catalogue list never changes which slot an old seed gets.

## 5. Model surface (`model_bonus.dart`, all additive)

```dart
model.start(difficulty: d, runSeed: 12345);       // null/omitted: BonusPlan.none
model.startAt(…, bonus: 'supplyRun');             // console and tests: that sector IS the bonus level
model.startAt(…, modifier: 'noShield');           // console and tests: the run has that modifier
model.bonusTuning = const BonusTuning(…);         // the odds a seeded run's plan is drawn with
model.runSeed;  model.bonusPlan;                  // the run's plan
model.bonus;                                      // BonusLevelDef? of the level being played
model.bonusAhead;                                 // BonusLevelDef? of the sector the transition flies to
model.powerRules;                                 // run modifier merged with the level's rules
model.bonusPowerTimers;                           // Map<String, double> (id -> seconds left)
model.hasBonusPower(id);  model.collectBonus(def);
model.activeBonusPowers;                          // Iterable<BonusPowerDef>
model.bonusRun;                                   // state: cratesDropped, cratesOpened, shipsLost, extra, award, crateLeft
checkpoint(): adds 'runSeed' (optional; an old snapshot restores a run without a plan)
```

Pickups: `Pickup.bonus` (a `BonusPowerDef?`) beside `Pickup.power`; `SupplyCrate.bonus` likewise.

## 6. Events and radio

Model `GameEvent`s (names in `GameEventNames`), each with `variant: <id>`:

| Event | When | Radio trigger looked up |
|---|---|---|
| `runModifier` | first combat frame of a run with a modifier | `runModifier.<id>`, then `runModifier` |
| `bonusStart` | the bonus level's first wave begins combat | `bonusStart.<id>`, then `bonusStart` |
| `bonusCrate` | a bonus crate is opened | `bonusCrate.<id>`, then `bonusCrate` |
| `bonusPickup` | a bonus power is collected (variant = power id) | `bonusPickup.<powerId>`, then `bonusPickup` |
| `bonusCleared` | the level's last kill (data: `award`, `flawless`) | `bonusCleared.<id>`, then `bonusCleared` |

The transition INTO a bonus level fills its one radio slot with `bonusEntry.<id>`, then `bonusEntry`
(`RadioCategory.bonusEntry`, ahead of the front-line call and the mission line). The transition OUT keeps the ordinary
slot of the next sector.

**Adding lines** (`art/comms/lines.json`, append triggers at the end, never reorder): give every line a
`"placeholder": "<recorded clip id>"` of the same kind (human/demon). Voice generation is blocked on
tillandsias#1103, so until the batch runs the game plays the placeholder clip **with the placeholder's own subtitle**:
pick a clip whose words fit your moment. Then run `python3 -I tools/comms_pipeline.py dart`: it regenerates
`lib/comms/comms_bank.dart` and `plan/audio-studio/voice-batch-pending.md` (your pending entries appear there; do not
hand-edit either file). Both of us append triggers to `lines.json` and regenerate, so expect a conflict in the two
generated files at integration: resolve `lines.json` by keeping both blocks, then regenerate.

Trigger specs A uses (copy them): `{"priority": 5, "cooldown": 45, "ttl": 3, "mood": "happy"}` for `bonusEntry.*`
(the same as `frontCall`; the transition slot picks the line itself, so the spec only matters for the dock);
`{"priority": 5, "cooldown": 20, "ttl": 4, "mood": "happy"}` for `bonusStart.*`, `bonusPickup.*`, `bonusCleared.*`;
`{"priority": 3, "cooldown": 12, "ttl": 2, "mood": "happy", "chance": 0.4, "group": "loot"}` for `bonusCrate.*`.
A `bonusEntry` line must fit the slot: keep the placeholder clip at or under about 4 s.

`test/comms_director_test.dart` counts the borrowed lines (`expect(borrowed, 52)`): add your line count to it. That
number is the second shared edit; at integration the two counts add up.

## 7. Rules your level inherits

- Lives: a hit costs a ship as usual. Hearts, medals, time and checkpoints work as in any sector.
- Resume restarts the saved wave of the bonus level (the checkpoint carries the run seed).
- Score: kill points x `scoring.pointsScale`, crate points, clear and flawless bonuses; everything except kill
  points counts against `scoring.cap`.
- No text over the play area. An active bonus power shows as its badge inside a countdown ring beside the ship
  (drawn by the scene from `badge`, `tint`, `twin`); the cabinet's power-status row is unchanged.
- Page-level tests run unseeded (`test/flutter_test_config.dart` sets `arcadeRunSeed = () => null`), so no existing
  test meets a bonus level. Model tests force yours with `startAt(sector: 2, bonus: '<id>')`.
- Reduced motion: the look is a plain crossfade inside the cloud; no extra motion.
- Review strip: `test/bonus_<id>_review_test.dart` writes `art/contact/bonus-level-<a|b>-*.png` (copy
  `test/bonus_supply_run_review_test.dart`).

## 8. Level #1, so we do not collide

`supplyRun` ("Supply Run"): a shot-down fleet convoy's crates parachute through the fog; thin scavenger skeins
(drones, no sentinel, no elites); kills drop nothing, crates drop everything; bonus powers `salvageMagnet` and
`doubleScore`; mint-gold dawn grade. Please pick a different fantasy (for example a modifier-led one: one weapon
only, or a dense-fog hunt).

## Changes since the first commit

Second commit (`d83fe73f`, the framework) and later:

- `BonusPowerDef.twin`, `BonusLook.glow`, `BonusCrates.first` and `bonusPowerChance`, `BonusLevelDef.label` (required)
  were added. `label` is the `/console` button, not a HUD chip.
- The checkpoint carries only `runSeed` (no `bonusPlayed`: a slot is a position in the run).
- Per-level state is `model.bonusRun` (not `bonusState`).
- `bonusEntry.*` triggers use the `frontCall` spec without `"transmission": true`.
- `startAt(modifier:)` and `model.bonusTuning` exist.
- `test/comms_director_test.dart`'s borrowed-line count is a shared edit (see §6).
- Scoring by par: `BonusScoring.clearPar`, `flawlessPar`, `capPar` and `model.sectorPar` (what the replaced sector's
  rosters pay in kill points on that route and difficulty; a real clear pays about 2 x par). Measure your level
  against the regular sector on routes 0 and 1 before you fix its numbers.
- `/console` has a BONUS LEVEL row built from `bonusLevels`: your level appears there once it is in the catalogue.
- On the level's last kill, crates still in the air burst open (no points) so their pickups fall through the salvage
  window.
- Review strip to copy: `test/bonus_supply_run_review_test.dart` (`--dart-define=BONUS_CONTACT=true` writes
  `art/contact/`; rename the output prefix to `bonus-level-b-`).

## Additions by bonus level #2 (agent B, `work/bonus-levels-b`)

Stormfront needed a rule of play that data could not say. All of it has neutral defaults; a data-only level is
unchanged. Why and what else was missing: `plan/bonus-levels-blockers-b.md`.

- **A level's own mechanic.** `BonusLevelDef.mechanic` (a constructor tear-off, default null) makes one
  `BonusMechanic` per visit from a `BonusMechanicContext` (level seed, route, sector, difficulty). The model calls
  `step(model, dt)` every combat step and `idle(model, dt)` in every cinematic phase. Rules a mechanic keeps are in
  the header of `lib/game/bonus/bonus_mechanic.dart` (own PRNG, public model surface only, capped awards, tells of
  at least a second, pure Dart).
- **Model surface for a mechanic:** `model.bonusMechanic`, `model.bonusEvent(name, data)` (queues a `GameEvent`),
  `model.bonusAward(points)` (adds score inside the level's cap, returns what was granted),
  `BonusPlan.levelSeed(runSeed, route, sector)`.
- **Drawing a mechanic:** `lib/game/bonus/bonus_painters.dart`, `BonusPainters.byLevel[<id>]` with `under` (after
  the grade) and `over` (after the fight). Painters stay out of the model's imports: `dart run` tools load the model
  without `dart:ui`.
- **Timed radio warnings:** any event whose data carries `endIn` (seconds) gets its squad line end-aligned by
  `CommsDirector`, or dropped when it cannot fit.
- **Sound:** a raw string event (`model.events.add('<name>')`) reaches `audioSfx(name)` and is forwarded as a plain
  `GameEvent` of the same name. Do not also queue a structured event under that name.
- **Fixed:** a bonus pickup is no longer announced as the regular power in its `power` field (`shieldSpotted`).
- **Level #2, so the next one does not collide:** `stormfront` ("Stormfront"): a thunderstorm; lightning strikes
  telegraphed columns and hits both sides; bonus power `lightningRod`; half the kill drops are shields; storm-dark
  grade. Events `stormStrike`, `stormBait`; raw `stormTell`, `stormBolt`.

## Urgent-mission card (`work/bonus-briefing`)

The operator decided blocker A11: the transition into a bonus level opens an "URGENT MISSION!" radio card heading the
comms dock (design section "Urgent-mission card and banter"). What a new level adds for it:

- `brief:` on its `BonusLevelDef`: the twist in one or two short lines (under about 110 characters).
- Radio, appended to `art/comms/lines.json` with `"pending": "text"` (written lines: shown with their own words and
  no audio until recorded, never a borrowed clip):
  - `bonusEntry.<id>`: invites, at most about 11 words each (the slot's window);
  - `bonusDare.<id>`: squad dares and a `demon` part with the brood's retorts (cover the officers of the sectors the
    level may replace, plus a minion or two);
  - `bonusMidway.<id>` with `"exchange": "human"`: the second wave's squad tease and brood answer.
  Without its own `bonusDare` / `bonusEntry` lines a level gets the general ones.
- A `RunModifierDef` gets `brief:` too (the card's run rule).
- Nothing else: the card, its timing, the dismiss and the layout are the framework's (`lib/comms/comms_briefing.dart`).
- `test/comms_director_test.dart`'s borrowed count does not change for written lines (they borrow nothing).

