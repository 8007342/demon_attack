# Design: bonus levels and run modifiers

Sources: `plan/operator-feedback-2026-11-15b.md` (R9, R10); `cinematic-flow` design §2 (the transition's one clock
and its one radio slot) and §10.3 (transitions speak only by radio); `transition-ascent` design §4 (the slot's
front-line call); `combine-powerups` (independent power timers); `demon-intelligence` design §8 (placeholder clips);
`plan/difficulty-calibration.md` (what must not move). The contract for the second bonus level is
`plan/bonus-levels-interface.md`; what the documentation and tools did not cover is in
`plan/bonus-levels-blockers-a.md`.

## 1. Shape

```
lib/game/bonus/
  bonus_types.dart     const data: PowerRules, RunModifierDef, BonusPowerDef, BonusWaves, BonusCrates,
                       BonusScoring, BonusLook, BonusLevelDef            (pure Dart)
  bonus_plan.dart      BonusTuning, BonusSlot, BonusPlan.forRun          (pure Dart, own PRNG)
  bonus_catalog.dart   bonusLevels, bonusPowers, runModifiers            (append only)
  bonus_look.dart      BonusLookLayer: the scene's grade                 (dart:ui)
  levels/<id>.dart     one file per bonus level
lib/game/model_bonus.dart   part of model.dart: BonusRun (state) and every hook
```

- **A level is data.** A new level is one `const BonusLevelDef`, one catalogue line, radio lines and tests. The model
  reads the definition through hooks; no level has code of its own in `model.dart`.
- **One state object.** `ArcadeModel.bonusRun` (`BonusRun`) holds the run seed, the plan, the level being played,
  the rules in force, the in-level PRNG, bonus power timers and per-level counters.
- **Hooks are identity without a plan.** Each hook in `model.dart` is one call (`_bonusRoster(n)`,
  `_bonusDrop(power)`, `_bonusKillPoints(points)`, …) that returns its input when `bonusRun.level == null` and
  `bonusRun.rules.isNone`. That is the whole safety argument of §8.
- **Growth (R10).** The definition has slots for what does not exist yet: `BonusLook.cue` (a music cue of its own),
  radio triggers per level id, a badge per bonus power. Filling a slot is data plus the asset; see §9.

## 2. The run seed and the plan

- `ArcadeModel.start({difficulty, int? runSeed})`. `runSeed == null`: `BonusPlan.none`.
- `lib/main.dart` gives each new run `arcadeRunSeed()`: by default the clock's microseconds (30 bits).
  `test/flutter_test_config.dart` sets it to `() => null`, so page-level tests keep the calibrated campaign.
- `BonusPlan.forRun(runSeed, tuning, levels, modifiers)` uses `Random(runSeed ^ 0xB0705)` and nothing else.

| Draw (fixed order, always drawn) | Use |
|---|---|
| 1 | the run has a bonus level when `u < runChance` (0.85) |
| 2, 3, 4 per slot (`maxPerRun` = 1) | route by `routeWeights` [5, 3, 1, 1, 0]; sector uniform in {2, 3, 4}; level by `weight` among those that `fit` |
| one per modifier, in catalogue order | the first with `u < chance · modifierScale` is the run's modifier |

- Every draw is made whether or not it is used, and the route and sector are drawn before the level, so appending a
  level or a modifier never moves an old seed's slot (tested).
- Route weights put half of the bonus levels in the first tour and 30 % in the second, because most runs end there;
  the fifth tour (the finale) never has one. Sector 1 is excluded (the opening teaches the game; later it is where
  the front-line call lands), sector 5 is the carrier.
- In-level draws (crate position and content, chance rules) come from
  `Random(runSeed ^ 0xB0705 ^ (route · 64 + sector) · 7919)`, reseeded at each level start. A resumed wave therefore
  restarts that level's stream (the wave restarts too).
- Shipped modifiers and chances: `noShield` 5 %, `spreadOnly` 3 %, `heavyOrdnance` 5 % (35 % of drops become blast
  rounds). About 12 % of seeded runs have one.

## 3. Powerup rules

`PowerRules { banned, only, chances, killDrops }`, `merge(inner)`, `resolve(candidate, roll)`.

- Sources gated: the kill drop (every eighth kill, or a sentinel shot down in a dive) and the carrier's supply
  crates; in bonus levels also the level's crates and a bonus power's `grants`.
- `resolve`: chances in order (each draws once), then `only`, then the ban (next allowed power of the regular
  cycle, no draw; nothing when all are banned).
- The regular kill-drop cycle and the carrier crate's roll are computed exactly as before, **then** resolved; with
  `isNone` nothing is drawn and the candidate is returned.
- Not gated (see the blocker log): the ground war's homing-missile pickup, which is not a `Power`.

## 4. Bonus-only powerups

- `BonusPowerDef`: id, label, badge column, tint, twin, seconds, and the primitives `scoreScale`, `magnet`,
  `fireScale`, `grants`.
- They are **not** members of `enum Power`. The regular cycle indexes `Power.values`; adding a value would change
  every run's drops, the ship's module rows, the HUD glyphs and the saved power names. They live beside it:
  `Pickup.bonus` and `SupplyCrate.bonus`, `bonusRun.timers[id]`.
- Timers run only in combat and not while the ship is away (as regular powers). They are cleared when a regular
  sector begins.
- A new effect is a new primitive: a field with a neutral default, one line where the model applies it.

## 5. A bonus level in the model

| Moment | Hook | Effect |
|---|---|---|
| `_beginLevel`, `restoreCheckpoint` | `_bonusBeginLevel` | `bonusRun.level = plan.at(route, sector)`; rules merged; level PRNG seeded; counters reset; bonus timers cleared in a regular sector |
| `wavesPerLevel` | getter | `level.waves.count` |
| `_buildRoster`, `_preloadSide` | `_bonusRoster` | `max(3, round(n · rosterScale))` |
| `_resetWaveEnemies` | `_bonusReinforcements` | `round(n · reinforcementScale)` |
| `sentinelFor`, `_ordinaryProfile` | `_bonusNoSentinels`, `_bonusNoElites`, `_bonusKind` | none; species capped |
| combat step | `_bonusStep` | `runModifier` and `bonusStart` events once; bonus timers; magnet; crate clock |
| kill | `_bonusDrop`, `_bonusKillPoints` | rules; `points · pointsScale · active scoreScale`, the excess against the cap |
| crate destroyed | `_bonusCrateOpened` | crate points (capped), `bonusCrate` event |
| last kill | `_bonusClear` | clear and flawless awards (capped), `bonusCleared` event, leftover crates burst |
| `hitPlayer` | counter | `shipsLost` |

- Crates reuse `SupplyCrate` (three hits, parachute, the existing collision and painter). Each crate makes four
  draws (x, bonus roll, bonus index, power index) whatever it becomes.
- Events: `runModifier`, `bonusStart`, `bonusCrate`, `bonusPickup`, `bonusCleared` in `GameEventNames.bonus`, each
  with `variant` = the id, so the comms bank's `name.variant` lookup applies. They go through the same queue as the
  ground war's events, so the future dynamic music engine receives them too.
- Checkpoint: optional `runSeed`. The plan is recomputed from it; a slot is a position, so nothing else is saved.
- Console and tests: `startAt(bonus: id, modifier: id)` forces a level at that sector and a modifier on the run.

## 6. Bonus level #1: Supply Run

Fantasy: a fleet supply convoy was shot down over the sector. Its crates come down on parachutes through a thin
screen of brood scavengers. Shoot a crate open, catch what falls.

| | |
|---|---|
| Waves | 2; roster × 0.6 (min 3); reinforcements × 0.5; no sentinel, no elite; species ≤ 1 |
| Rules | `killDrops: false`: kills drop nothing, the crates carry everything |
| Crates | first at 1.5 s, then every 4.5 s; ≤ 3 in the air; ≤ 8 in the level; 150 points × route |
| Contents | 70 %: one of the five regular powers, uniform; 30 %: `salvageMagnet` or `doubleScore` |
| `salvageMagnet` | 12 s; pickups and heart pieces within 150 u fly to the ship at 260 u/s. Badge: the shield's U, coral (a horseshoe magnet) |
| `doubleScore` | 9 s; kill and crate points × 2. Badge: the large shot's orb, gold, doubled (two coins) |
| Scoring | clear 1.0 × sector par, flawless +0.3 × par, cap 1.5 × par (par: §6.1) |
| Look | warm dawn: wash `FFD79A` at 0.22, horizon light `FFE2A0` at 40 %, haze 0.06 |
| Radio | `bonusEntry.supplyRun` (3), `bonusStart.supplyRun` (2), `bonusCrate.supplyRun` (3, 40 % chance, loot group), `bonusPickup.salvageMagnet` (2), `bonusPickup.doubleScore` (2), `bonusCleared.supplyRun` (3) |

- Why it is a reward: fewer and weaker creatures, no sentinel, a guaranteed stream of powers, and a short level.
  Why it is still a level: a hit costs a ship, and a crate that is not shot falls away.

### 6.1 Score: the sector's par

A first version paid flat awards (1000 + 1000, cap 4000, × route). Measured, it made the "bonus" a loss: the Supply
Run paid 6-7 k where the replaced sector pays 10-40 k on route 0, and 12-17 k against 62-92 k on route 1. Flat
numbers cannot follow a campaign whose sectors differ sixfold, so awards are shares of the replaced sector's **par**:

`sectorPar` = Σ over the regular sector's waves of `rosterCount` × the mean kill points of its species at this
route's health × (route + 1) × the difficulty's enemy points. It counts opening rosters only (no reinforcements,
sentinels or dive bonuses), so a real clear pays about 1.7-2.6 × par.

Measured with a weaving, auto-firing, invulnerable pilot (Normal; regular sector against a flawless Supply Run):

| Route, sector | Regular: time, score | Supply Run: time, score | Crates opened / dropped | Share |
|---|---|---|---|---|
| 1, 2 | 35 s, 10 388 | 27 s, 11 771 | 4 / 6 | 113 % |
| 1, 3 | 59 s, 27 050 | 26 s, 26 224 | 5 / 6 | 97 % |
| 1, 4 | 42 s, 39 527 | 18 s, 35 038 | 2 / 4 | 89 % |
| 2, 2 | 83 s, 62 200 | 23 s, 39 250 | 4 / 5 | 63 % |
| 2, 3 | 86 s, 86 575 | 28 s, 58 838 | 5 / 6 | 68 % |
| 2, 4 | 84 s, 92 350 | 24 s, 65 438 | 4 / 5 | 71 % |

- A flawless Supply Run is worth about the sector it replaces on the first tour and about two thirds of it on the
  second, in a third of the time; losing a ship costs the 0.3 share. It never pays more than kills + 1.5 × par.
- The level lasts 18-28 s for this pilot, so four to six of its eight crates come down. That is short; `waves.count`
  3 or a slower scavenger roster are the first knobs for the operator's playtest.
- This pilot is not the calibrated protected pilot of `plan/difficulty-calibration.md`; see the blocker log.

## 7. Presentation

- **Entry and exit.** Nothing new. `_completeWave` starts the Rout as for any sector; `bonusAhead` (the plan at the
  flow's destination) only tells the transition's radio slot which line to ask for. `_finishTravel` → `_beginLevel`
  sets `model.bonus` at the Descent's first frame.
- **Radio only.** No title, caption, card or toast. The entry call fills the transition's one slot
  (`RadioCategory.bonusEntry`: `bonusEntry.<id>`, then `bonusEntry`; it must fit the slot's window like any line).
  The award is not shown as text: the HUD's score counts it and the `bonusCleared` line says it.
- **Look.** `BonusLookLayer` follows `model.bonus?.look` with a 0.35 s crossfade. `model.bonus` only changes at the
  Descent's first frame, when the cloud cover is at its peak, so the fade is hidden (measured: cloud 1.00 while the
  grade is part-way). The layer draws after the backdrop and before ground units: a soft-light wash plus 25 % plain
  wash, a horizon gradient, a haze band. The same with reduced motion.
- **Badges.** `_bonusBadge` draws the atlas's pickup badge with a modulate tint (twice, offset, for `twin`); the
  falling pickup adds a pulsing halo in the tint; a bonus crate's parachute stripe takes the tint.
- **Active bonus powers.** Badge and countdown ring beside the ship (left, then right), blinking in the last 2 s.
  The cabinet's power-status row is unchanged (it is keyed on `enum Power`).
- **Review.** `test/bonus_supply_run_review_test.dart` renders `art/contact/bonus-level-a-story.png` (12 frames at
  360 × 780, arena cropped) and `bonus-level-a-look.png` (sectors 2-4 plain and graded) and asserts the hidden fade,
  a visible grade and no darkening.

## 8. Calibration and safety

- **Unseeded = calibrated.** `start()` without a seed gives `BonusPlan.none`; every hook is identity; nothing draws.
  Tests: plan-less trace equality for 150 s against a seeded run with an empty plan; a seeded run matches the
  unseeded one through the sectors before its bonus level; a run modifier leaves the simulation's PRNG in step.
- **Own streams.** Plan and in-level draws never touch `ArcadeModel.random`, the planner's or the stream's PRNG.
- **Determinism.** Same seed and inputs: same run, crates included (tested over 90 s of a bonus level).
- **Existing tools.** `tools/analyze_difficulty.dart` and `tools/profile_difficulty.dart` start unseeded runs and
  measure the same campaign. A calibration pass *of* bonus levels is future work (blocker log).
- **Score boards.** The cap bounds what a bonus level adds. Run modifiers can make a run harder or easier; they are
  rare (12 %) and not recorded with the score (open question below).

## 9. Organic growth (R10)

| To add | Do | Pipeline |
|---|---|---|
| a bonus level | `levels/<id>.dart`, one catalogue line, `bonusEntry.<id>` lines, tests, a review strip | none new |
| a run modifier | one `RunModifierDef`, `runModifier.<id>` lines | comms |
| a bonus power | one `BonusPowerDef` (+ a primitive if its effect is new) | none (recoloured badge) or a new atlas column |
| recorded voices | run the voice batch; placeholders fall away | `tools/comms_pipeline.py` (blocked, tillandsias#1103) |
| a music cue per level | set `BonusLook.cue`; teach `main.dart`'s `level` cue to prefer it | `tools/music_pipeline.py` (not wired yet) |
| a backdrop per level | a `BonusLook` field naming a flyover set | `tools/flyover_assets.py` (not wired yet) |

## 10. Decisions and open questions

- **Decided:** the bonus level replaces a sector in place (the campaign keeps 20 sectors and 5 carriers), rather than
  being inserted between two sectors. It keeps medals, route length and the calibration of every other sector.
- **Decided:** lives are at stake in a bonus level. A no-death bonus would need a second life-loss path.
- **Decided:** the run seed is the clock. The operator can later make it a daily seed or a shared seed; the plan API
  does not care.
- **Open:** should the score board record the run's modifier (a badge on the row)? Not done: it changes the score
  API and the Durable Object's schema.
- **Open:** should a resumed run tell the player again which modifier it has? Today the announcement repeats on
  resume, because the announcement flag is not saved.
