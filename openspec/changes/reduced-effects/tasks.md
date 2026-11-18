# Tasks: reduced-effects

## 1. Setting
- [x] 1.1 `lib/game/reduced_effects.dart`: `ReducedEffectsMode`, `ReducedEffects.calm`, `budget`, `menuLabel`, `spoken`, listeners
- [x] 1.2 `FlashSafety.reduced` resolves the calm look; `?flash=low` still forces reduced flashing
- [x] 1.3 Persist `demonAttack.reducedEffects`; restore on page start

## 2. Rendering only
- [x] 2.1 `FlyoverBackground.reducedMotion` (calm) and `systemReducedMotion` (model, flight distance); binding dispatcher
- [x] 2.2 `DemonScene.calmLook` for painters that read `model.reducedMotion`; model gets the system setting only
- [x] 2.3 Bonus, crosswind, supply-run and lightning painters resolve the calm look

## 3. Calmer look
- [x] 3.1 `FrameBudget.calmed()` (eye candy capped at LITE, telegraphs kept) and `ReducedEffects.budget`
- [x] 3.2 Camera: no tilt, pitch or roll with the calm look; shakes and streaks follow it
- [x] 3.3 `ReducedEffectsScope` in the MaterialApp builder: widgets' `disableAnimations`

## 4. Menu
- [x] 4.1 `lib/widgets/reduced_effects_toggle.dart`: title toggle and pause row; `PerfGovernor.lowPower` note

## 5. Tests and gates
- [x] 5.1 `test/reduced_effects_test.dart`: persistence, Auto follows the system, On implies flash=low and the LITE cap, the model identical either way, the menu rows render
- [x] 5.2 §2 gates
- [ ] 5.3 Operator playtest: the calm look on a phone, the label's length in the pause menu
