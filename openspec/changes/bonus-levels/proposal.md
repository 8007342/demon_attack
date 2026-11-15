# Proposal: bonus levels and run modifiers (R9, R10)

## Why
From the operator's second playtest on 2026-11-15 (`plan/operator-feedback-2026-11-15b.md`, R9 and R10):
- "Random 'bonus levels' replace a regular level during a run randomly from time to time, maybe once per run, having
  special radio comms, or even special powerups only for those levels."
- "Some runs don't have certain powerups, or a certain powerup only, maybe even give them certain percentage of a
  chance to happen each run."
- Asset complexity (art, music, radio) must be able to grow organically, through reusable pipelines.

What the game has today:
- Every run is the same campaign: five routes of four sectors and a carrier, with the same waves, the same kill-drop
  cycle of five powers and the same radio triggers. `ArcadeModel` is built with one fixed seed and a run has no seed
  of its own.
- A sector's content is spread through `lib/game/model.dart` (waves, rosters, drops) and `DifficultyPolicy`; nothing
  describes a level as data.
- Two agents build one bonus level each, in parallel and from the documentation alone. The second one must be able to
  add a level without editing the model.

## What Changes
- **A run seed and a run plan.** A run MAY start with a run seed. From it, and only from it, the run's plan is drawn
  with its own PRNG: at most one bonus level (which route, which sector, which level) and at most one run modifier.
  A run without a run seed has no plan and plays today's campaign unchanged.
- **Bonus levels as data.** A bonus level replaces one regular sector (2-4; never the opening sector, never a
  carrier). It keeps the sector's place, backdrop, ground war and music and brings its own waves, powerup rules,
  bonus-only powerups, supply crates, scoring and radio lines. One `const BonusLevelDef` and one catalogue line add a
  level.
- **Run modifiers.** Run-wide powerup rules, each with its own chance per run: a ban ("no shields"), only-X
  ("spread only") and chance rules ("35 % of drops are blast rounds"). One rule engine (`PowerRules`) serves both run
  modifiers and bonus levels and gates every power source.
- **Bonus-only powerups.** Powerups that exist only inside bonus levels, built from a few effect primitives (score
  scale, pickup magnet, fire rate, granted regular powers) and drawn with recoloured badges from the existing atlas.
- **Radio.** The transition into a bonus level carries that level's entry call in its one radio slot. In-level
  moments (start, crate opened, bonus power, cleared) and the run modifier are events with their own triggers. Every
  new line borrows a recorded clip until the voice batch runs (tillandsias#1103) and is listed in
  `plan/audio-studio/voice-batch-pending.md`.
- **Presentation.** Entry and exit are the existing fog transition (`cinematic-flow`, `transition-ascent`): nothing
  new is drawn over the play area and no text announces the level. A bonus level grades the sector's backdrop (colour
  wash, horizon light, haze); the grade changes only inside the cloud.
- **Scoring and progression.** A bonus level counts as its sector. Its extra score (crates, clear and flawless
  awards, score-scale powers) is capped per level so boards stay comparable between runs with and without one.
- **Bonus level #1, Supply Run.** A shot-down convoy's crates parachute through a thin screen of scavengers. Kills
  drop nothing; crates carry every power and two bonus-only ones (a salvage magnet, double score).
- **Console.** `/console` can launch any sector 1-4 as a bonus level.

## Capabilities
### New Capabilities
(none)

### Modified Capabilities
- `arcade-progression`: ADDED requirements for the seeded run plan, the replaced sector, scoring and persistence, and
  the unchanged campaign.
- `arcade-combat`: ADDED requirements for powerup rules and run modifiers, bonus-only powerups, bonus-level waves and
  supply crates, and the Supply Run.
- `arcade-presentation`: ADDED requirements for entry and exit through the fog, the backdrop grade and the bonus
  power's badge.
- `squad-comms`: ADDED requirements for bonus-level radio lines and their borrowed clips.

## Impact
- **New:**
  - `lib/game/bonus/bonus_types.dart`, `bonus_plan.dart`, `bonus_catalog.dart`, `bonus_look.dart`;
  - `lib/game/bonus/levels/supply_run.dart`;
  - `lib/game/model_bonus.dart` (`part of model.dart`: every model hook);
  - `test/bonus_levels_test.dart`, `test/bonus_supply_run_test.dart`, `test/bonus_supply_run_review_test.dart`;
  - `test/flutter_test_config.dart` (page tests start unseeded runs);
  - `plan/bonus-levels-interface.md` (the contract for the second bonus level), `plan/bonus-levels-blockers-a.md`.
- **Changed, by small hooks only:**
  - `lib/game/model.dart`: `start(runSeed:)`, `startAt(bonus:, modifier:)`, the checkpoint's optional `runSeed`,
    and one-line calls into `model_bonus.dart` at the level start, roster, reinforcement plan, sentinel choice, kill
    drop, carrier crate, kill score, fire interval, pickup collection and last kill;
  - `lib/game/model_flow.dart`: the preloaded side uses the bonus level's first roster;
  - `lib/game/game_events.dart`: five event names;
  - `lib/game/interlude.dart`, `lib/widgets/transition_overlay.dart`: `RadioCategory.bonusEntry`;
  - `lib/game/scene.dart`: the grade layer, bonus badges on pickups and crates, the bonus power rings by the ship;
  - `lib/main.dart`: a new run gets a clock run seed (`arcadeRunSeed`);
  - `lib/widgets/dev_console.dart`: the BONUS LEVEL row.
- **Data:** `art/comms/lines.json` (+10 triggers, 23 lines, all with recorded placeholders);
  `lib/comms/comms_bank.dart` and `plan/audio-studio/voice-batch-pending.md` regenerated.
- **Not changed:** `DifficultyPolicy`, the wave calibration, the carrier fight, the ground war, the music engine, the
  score API, any atlas.
- **Depends on** `cinematic-flow` and `transition-ascent` (the fog transition and its radio slot), `combine-powerups`
  (power timers) and the placeholder mechanism of `demon-intelligence` §8.
