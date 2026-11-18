# Proposal: reduced effects

## Why
weather-everywhere added a reduced-flashing mode with no in-game toggle (its design §3 and open question 2): it
follows the system's reduced motion or `?flash=low` in the address. The operator approved an in-game toggle on
2026-11-18 and added, verbatim: "Reduced flashing might also run reduced animations, friendly for low end devices as
well."

## What Changes
- **One menu setting, "Reduced effects"** (reduced flashing and motion), three states: **Auto** (follows the
  system's reduced-motion setting), **On** and **Off**. The title has a 38 px toggle beside Music and Speech; the
  pause menu has the row `REDUCED EFFECTS: AUTO`. Remembered per device (`demonAttack.reducedEffects` in local
  storage). `?flash=low` keeps forcing reduced flashing whatever the menu says.
- **On** (or Auto with the system asking):
  - no lightning wash, no cloud glow, no ship flicker (what `?flash=low` does), steady storm tells and markers;
  - every existing reduced-motion look: still backdrop sway, flyers, critter leaps, fog drift, smoke, carrier bend,
    insignia tells steady, no screen shake (last kill, carrier trauma, sentinel rush), no transition streaks or
    camera tilt, pitch and roll;
  - the eye-candy budgets capped at the LITE tier: rain, wind wisps, motes and explosion sprites at most LITE's
    share, no ricochet sparks, no blur, reduced fog, no hatch emergence frames; hatch lurkers and pulse rings keep
    the tier's own (they are telegraphs);
  - every widget's reduced-motion path (comms page-jumps instead of scrolls, badge states without motion,
    transitions and the ending cut instead of fade) through one `MediaQuery.disableAnimations` override above every
    route.
- **Off** draws the full look even when the system asks for reduced motion (except what `?flash=low` asks).
- **Low-end devices**: when the frame-budget governor has stepped down to LITE by itself, the row says
  `REDUCED EFFECTS: AUTO (LOW-POWER)`. The setting is never forced on.
- **Rendering only.** The simulation's own `reducedMotion` (the shorter cinematic plans) and the flight distance
  that places the ground units on the relief follow the system setting alone, never the player's choice. A test
  steps two runs of one seed, one On and one Off, and compares the whole model state.

## Impact
- Code: new `lib/game/reduced_effects.dart` (pure Dart), `lib/widgets/reduced_effects_toggle.dart`; small hooks
  (`// --- reduced-effects`) in `scene.dart`, `main.dart`, `flyover_background.dart`, `perf/frame_budget.dart`,
  `weather/storm_layer.dart`, `weather/lightning_painter.dart` and three bonus painters.
- Tests: `test/reduced_effects_test.dart`.
- No rule, timing or balance change; the calibration gates are unchanged.
