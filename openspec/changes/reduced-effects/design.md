# Design: reduced effects

The operator's words are quoted in `proposal.md`. Builds on weather-everywhere (§3 flash safety, `FlashSafety`),
phone-performance (the FULL / LEAN / LITE frame budgets in `lib/game/perf/frame_budget.dart`) and the reduced-motion
paths every earlier change added (cinematic-flow, ground-terrain-interaction, carrier-v3, comms-pacing,
bonus-challenges). No new research: the flash thresholds and their sources stay in weather-everywhere design §3.

## 1. The setting (`lib/game/reduced_effects.dart`)
Pure Dart, outside the model's import graph. `ReducedEffectsMode { auto, on, off }`, cycled Auto -> On -> Off by a
tap; `ReducedEffects.mode` is one static per page view (like `FlashSafety.override`), restored in
`_ArcadePageState.initState` from `demonAttack.reducedEffects` and written on every change (a store that throws is
ignored, as for the atmosphere toggle).

`ReducedEffects.calm(system)` resolves the calm look: On -> true, Off -> false, Auto -> `system`. It is idempotent
(`calm(calm(x)) == calm(x)`), so a painter handed an already-resolved flag may resolve it again; that lets every
painter that read `model.reducedMotion` call `ReducedEffects.calm(model.reducedMotion)` without knowing where the
flag came from (the scene, or a review harness that set it by hand).

`FlashSafety.reduced` becomes `override ?? (calm(reducedMotion) || ?flash=low)`: the address still forces reduced
flashing whatever the menu says (Off included); it never forces the rest of the calm look.

## 2. Rendering only
Two things the presentation hands the model already depended on the system's reduced motion:
- `model.reducedMotion` picks the shorter cinematic plans (`FlowPlan.sectorChange(reduced:)`, the outros): timing.
- `FlyoverBackground.advance` stopped the flight distance under reduced motion, and the distance places the relief
  camera that ground units ride (`model.ground.relief`, `GroundUnit.pose`, the v4 pathing cost): positions.

Both now read `FlyoverBackground.systemReducedMotion` (the test override, else the platform's setting), never the
player's choice. `FlyoverBackground.reducedMotion` (what the painters read) is `override ?? calm(platform)`. So On
with the system off keeps the full-length transitions and the flying ground, drawn calm; Off with the system on keeps
the short plans (the system asked) and draws the full look. `DemonScene.calmLook` is the painters' flag for code that
read `model.reducedMotion`. The platform read goes through `WidgetsBinding.instance.platformDispatcher` when a
binding exists, so tests can fake the system setting.

Test: two runs of seed 1982 from sector 2, one On and one Off, stepped frame by frame through the scene's
presentation and the model for 150 s (combat, a sector change, the next sector), painted every 30 frames; the
checkpoint, ship, demons, shots, ground units, flow clock and the events must match on every compared frame. The
test fails at frame 397 if the flight distance follows the player's setting (checked by mutation).

## 3. What On changes

| Area | On | Kept (gameplay, telegraphs) |
|---|---|---|
| Lightning | no wash, no cloud glow, no ship flicker, steady leader and marker | bolts, tells, stun, zap |
| Motion | every existing reduced-motion path: backdrop sway, flyers, leaps, fog drift, smoke, carrier bend, insignia tells steady | creature, shot and ship motion |
| Camera | no shake (last kill, carrier trauma, sentinel rush), no streaks, no transition tilt / pitch / roll (`still` gain in `scene.dart`) | the flow's beats and their timing |
| Budgets | `FrameBudget.calmed()`: rain, wind, motes ≤ LITE share (.35 / .35 / .5), blasts ≤ 14, no sparks, no blur, reduced fog, no emergence frames | hatch lurkers and pulse rings at the tier's own |
| Widgets | `MediaQuery.disableAnimations` = calm above every route (`ReducedEffectsScope` in the MaterialApp builder): comms page-jumps, badge states, transition cuts, ending | |

`ReducedEffects.budget(tier, calm:)` caches one calmed budget per tier (the scene reads `budget` many times a frame).
The cap is applied after the governor's tier, so a LITE device stays LITE and a FULL device sheds only eye candy.

## 4. Menu and low power
- Title: a 38 × 44 px toggle beside Music and Speech (flash icon, AUTO / ON / OFF) so the choice can be made before
  the first storm.
- Pause: the row `REDUCED EFFECTS: <MODE>` under ATMOSPHERE, with `(SYSTEM)` when Auto is on because the system asks
  and `(LOW-POWER)` when `PerfGovernor.lowPower` (the governor itself stepped down to LITE, not `?perf=`) and the mode
  is not On. Screen readers hear "Reduced flashing and motion: automatic, on from the system setting; this device is
  running at low power".
- The setting is never switched on by low power: LITE already trims the same budgets, and the flash rules hold on
  every tier.

## 5. Open questions
1. With On and the system off, the flight still scrolls (the flight distance places the ground units, §2), while the
   system's reduced motion freezes it. Decoupling the relief camera from the drawn distance would let On freeze the
   ground too; that is a model-side change, left for an OpenSpec task.
2. Off overrides the system's reduced motion for the look but not for the model's shorter transitions. If the
   operator wants Off to mean "full motion everywhere", the model would need the setting (a rule change, out of scope).
3. At archive (after weather-everywhere): fold the in-game toggle into weather-everywhere's "Reduced flashing"
   requirement, or keep this change's requirements beside it.
