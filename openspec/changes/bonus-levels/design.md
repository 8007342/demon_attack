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

## Bonus level #2: Stormfront (agent B)

Requirements: `specs/bonus-level-stormfront/spec.md`. Code: `lib/game/bonus/levels/storm_cell.dart` (the seeded
schedule, pure), `stormfront.dart` (the level, the rod, the mechanic), `stormfront_painter.dart` (drawing);
`lib/game/bonus/bonus_mechanic.dart` and `bonus_painters.dart` (the two framework additions it needed). Blockers:
`plan/bonus-levels-blockers-b.md`.

### Fantasy and contrast
The brood runs into a thunderstorm and the squadron follows. Where the Supply Run is bright, greedy and safe (crates,
a magnet, double score, a dawn grade), Stormfront is dark, loud and dangerous: the sky itself is a weapon and it does
not take sides. The Supply Run changes what drops; Stormfront adds a rule of play.

### The mechanic: bait the lightning
- **A strike** is a tell (1.15 s of real time, never scaled, never under 1 s), a bolt (one step) and an afterglow
  (0.42 s, drawing only). The column is fixed when the tell begins.
- **Aim.** 68 % of tells take the ship's x at that moment (clamped to 18-342); the rest take the swarm's densest
  column (the creature with the most neighbours within 34 units). With no creature present every tell takes the ship.
- **The bolt** hits every targetable creature within 34 units of the column for 3 (a homing missile's heavy hit,
  through `hitDemon(homing: true)`, so it breaks a dive shield), and the ship when it is within 13 units: an ordinary
  `hitPlayer()` (the shield absorbs it, protection ignores it). Creatures still entering are not hit.
- **So the player baits it:** wait under a group, let the tell begin, slide out. From a standstill the ship clears the
  13-unit core in well under half the tell, so a ship that moves always escapes; one that sits still is hit.
- **Forks** (Normal 20 %, Hard 35 %, +5 % per route, at most 50 %; never on Easy): a second column 64-104 units toward
  the roomier side, struck at the same instant. One side of the dodge is always open.
- **Pace.** The next tell begins 2.5-3.7 s after the bolt (Hard 2.2-3.2, Easy 3-4.2), divided by the hostile rate; the
  first after 3.2 s of combat (Easy 4). One tell group at a time, so bolts land at most once a second.
- **Safety.** No tell begins and a running tell ends without a bolt while the ship is away, in the life-loss regroup
  and in every cinematic phase (`BonusMechanic.idle`).
- **Score.** Storm kills are ordinary kills. A bolt drawn to the ship that destroys creatures and misses the ship adds
  100 × (route + 1) per creature through `bonusAward`. Awards are shares of the sector's par (§6.1): clear 0.8,
  flawless +0.4, cap 1.6 (bait bonus included).

Measured like §6.1 (Normal; a weaving, auto-firing, protected pilot that does not bait on purpose; regular sector
against a flawless Stormfront):

| Route, sector | Regular: time, score | Stormfront: time, score | Bolts / storm kills / baited | Share |
|---|---|---|---|---|
| 1, 2 | 38 s, 11 515 | 24 s, 11 531 | 5 / 4 / 1 | 100 % |
| 1, 3 | 88 s, 28 326 | 33 s, 30 303 | 9 / 8 / 6 | 107 % |
| 1, 4 | 100 s, 38 877 | 41 s, 42 263 | 10 / 7 / 6 | 109 % |
| 2, 2 | 166 s, 59 725 | 22 s, 43 575 | 6 / 8 / 7 | 73 % |
| 2, 3 | 136 s, 83 550 | 18 s, 60 125 | 5 / 5 / 5 | 72 % |
| 2, 4 | 87 s, 92 375 | 27 s, 68 500 | 8 / 15 / 11 | 74 % |

A flawless storm is worth about the sector it replaces on the first tour and three quarters of it on the second, in
a third of the time; a lost ship costs the 0.4 share. A first version with flat awards (800 + 1200, cap 4000, ×
route) paid 20-65 % of the sector, as §6.1 found for level #1.

### The lightning rod (bonus-only powerup)
The first baited kill of each wave drops one where the creature fell (two per level at most; none while one is
falling or carried). For 9 s every tell is drawn to the ship, its column widens from 34 to 52 units, there is no
fork, and the bolt is grounded: it ends on the ship and does no harm. The inversion is the reward: now the pilot
parks under the swarm and stays. The framework runs the timer, the pickup, the badge (the rapid-fire bolt in
lavender) and `bonusPickup.lightningRod`; the effect lives in the mechanic, because no power primitive describes it.

### Waves, drops, look
`BonusWaves(count: 2, rosterScale: .85, reinforcementScale: .5)`, no sentinel, no elite.
`PowerRules(chances: [PowerChance(Power.shield, .5)])`: half the kill drops are shields ("a certain percentage of a
chance"), which makes a mistimed bait forgivable. `BonusLook`: storm-dark blue wash (0xFF0B1030 at .46), a pale
violet horizon glow, haze .14. Drawing is procedural, no atlas: rain (44 streaks), the tell (a faint amber band over
the column, a leader that reaches down and re-forks twelve times a second, a stepped amber bracket on the ship's row
as wide as the core, closing ticks), the bolt (stepped zigzag, white core, violet-white halo, two branches, impact
glow) and a whole-screen flash of at most 10 % white for 0.12 s. Reduced motion: no rain, no flicker, no branches, no
flash; a steady leader and a straight bolt.

### Determinism
`StormCell` has its own `Random(levelSeed ^ 0x570f)`, where `levelSeed` is `BonusPlan.levelSeed(runSeed, route,
sector)`. Every tell draws exactly four numbers (aim, fork, fork offset, shape) and the gap one, whatever they decide,
so the times of a seed's tells do not depend on the player; the columns do, by design (they sample the ship). Nothing
draws from `ArcadeModel.random` (`test/bonus_stormfront_test.dart`, "the storm never draws from the simulation
stream").

### Radio and sound
| Moment | Trigger | Borrowed clip until #1103 |
|---|---|---|
| Transition slot into the storm | `bonusEntry.stormfront` (3) | `sectorStart.h5`, `diveWarning.h6`, `sectorStart.h0` |
| Combat begins | `bonusStart.stormfront` (2) | `diveWarning.h2`, `groundForceInRange.h4` |
| A tell on the unprotected ship | `stormStrike` (2), ends on the bolt (`endIn`) | `sentinelDive.h3`, `diveWarning.h6` |
| A baited bolt | `stormBait` (3 squad, 3 brood) | `skirmishWon.h4`, `broodTaunt.h7`, `allySaved.h4`; `broodTaunt.d6`, `broodChatter.d24`, `levelClear.d0` |
| The rod is collected | `bonusPickup.lightningRod` (2) | `shieldCollected.h3`, `shieldCollected.h0` |
| Last kill | `bonusCleared.stormfront` (3) | `levelClear.h7`, `levelClear.h1`, `levelClear.h6` |

Eighteen lines, all pending the voice batch. Raw events `stormTell` and `stormBolt` play two synthesised effects
(`web/audio/demon-audio.js`: a rising crackle, a crack with a low roll) and reach the event queue for the music.

### Framework additions (neutral defaults; a data-only level is unchanged)
- `BonusLevelDef.mechanic` → `BonusMechanic` (`step`, `idle`), one per visit, from `BonusMechanicContext` (level
  seed, route, sector, difficulty). `ArcadeBonus.bonusMechanic`, `bonusEvent`, `bonusAward`; `BonusPlan.levelSeed`.
- `BonusPainters` (scene side, by level id): `under` after the grade, `over` after the fight.
- `CommsDirector`: any event with `endIn` gets its squad line end-aligned (was a fixed list of event names).
- `GameEventObserver`: a bonus pickup is not announced as the regular power in its `power` field.

### Review
`test/bonus_stormfront_review_test.dart` → `art/contact/bonus-level-b-stormfront.png` (twelve phone frames: Pursuit,
Descent into the storm, arrival, early and late tell, a baited bolt, the rod falling, a fork, the rod's tell, a
grounded bolt, a swarm bolt, the way out) and `bonus-level-b-reduced.png` (four frames with reduced motion).

### Open
- Balance is uncalibrated: no tool measures a bonus level (blocker log §6).
- The storm has no music cue and no art of its own; both can be added without touching the mechanic.
