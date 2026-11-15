# Tasks

## 1. Contract first
- [x] 1.1 `plan/bonus-levels-interface.md`: data classes, selection, model surface, events, radio recipe, the rules a level inherits; pushed as the first commit of `work/bonus-levels-a` for the parallel bonus level

## 2. Framework
- [x] 2.1 `lib/game/bonus/bonus_types.dart`: `PowerRules` (ban, only, chances, kill drops, merge, resolve), `RunModifierDef`, `BonusPowerDef`, `BonusWaves`, `BonusCrates`, `BonusScoring`, `BonusLook`, `BonusLevelDef`
- [x] 2.2 `lib/game/bonus/bonus_plan.dart`: `BonusTuning`, `BonusPlan.forRun` with its own PRNG and fixed draw order, `levelRng`
- [x] 2.3 `lib/game/bonus/bonus_catalog.dart`: levels, bonus powers, three run modifiers (`noShield`, `spreadOnly`, `heavyOrdnance`)
- [x] 2.4 `lib/game/model_bonus.dart` and the hooks in `model.dart` and `model_flow.dart` (design §5); `start(runSeed:)`, `startAt(bonus:, modifier:)`, checkpoint `runSeed`
- [x] 2.5 `GameEventNames`: `runModifier`, `bonusStart`, `bonusCrate`, `bonusPickup`, `bonusCleared`
- [x] 2.6 `lib/main.dart`: `arcadeRunSeed`; `test/flutter_test_config.dart`: page tests start unseeded runs
- [x] 2.7 `/console`: the BONUS LEVEL row (`ConsoleStart.bonus`)

## 3. Radio
- [x] 3.1 `RadioCategory.bonusEntry`, `InterludeContext.bonus`; the transition slot asks for `bonusEntry.<id>`, then `bonusEntry`, ahead of the front-line call
- [x] 3.2 `art/comms/lines.json`: `bonusEntry`, `bonusEntry.supplyRun`, `bonusStart.supplyRun`, `bonusCrate.supplyRun`, `bonusPickup.salvageMagnet`, `bonusPickup.doubleScore`, `bonusCleared.supplyRun`, `runModifier.noShield`, `runModifier.spreadOnly`, `runModifier.heavyOrdnance` (23 lines, each with a recorded placeholder)
- [x] 3.3 Regenerate `lib/comms/comms_bank.dart` and `plan/audio-studio/voice-batch-pending.md` with `python3 -I tools/comms_pipeline.py dart` (23 new pending entries)

## 4. Presentation
- [x] 4.1 `lib/game/bonus/bonus_look.dart` and its two calls in `scene.dart` (advance, paint after the backdrop)
- [x] 4.2 Bonus badges on pickups and crates, the tinted parachute, the active-power rings beside the ship

## 5. Supply Run
- [x] 5.1 `lib/game/bonus/levels/supply_run.dart`: the level, `salvageMagnet`, `doubleScore` (design §6)

## 6. Tests and review
- [x] 6.1 `test/bonus_levels_test.dart`: selection odds and determinism, catalogue growth, power rules, run modifiers in play, the radio slot, the bank's bonus lines, checkpoints, and the safety traces (design §8)
- [x] 6.2 `test/bonus_supply_run_test.dart`: waves, no kill drops, crate clock and bounds, crate points and pickup, both bonus powers, the cap, the clear and flawless awards, the way out
- [x] 6.3 `test/bonus_supply_run_review_test.dart` → `art/contact/bonus-level-a-story.png`, `bonus-level-a-look.png`; checked by eye at phone size
- [x] 6.4 `test/comms_director_test.dart`: the borrowed-line count (29 → 52)
- [x] 6.5 `flutter analyze` clean, `flutter test` green, `openspec validate bonus-levels --strict`

## 7. Hand-over
- [x] 7.1 `plan/bonus-levels-blockers-a.md`: what the docs, specs and tools did not cover
- [x] 7.2 `plan/roadmap.md`: what is left

## Workflow follow-up
- Integrate bonus level #2 (`work/bonus-levels-b`): one catalogue line, its `lines.json` block, regenerate the bank, add its lines to the borrowed-line count.
- Voice batch: record the 23 lines when tillandsias#1103 unblocks; the placeholders fall away with no code change.
- Operator phone playtest through `/console` → BONUS LEVEL, then a calibration pass of the bonus level and the modifier chances, then `openspec archive bonus-levels`.
