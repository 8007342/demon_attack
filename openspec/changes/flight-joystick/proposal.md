# Proposal: flight-joystick (a hero flight stick in the control pad)

## Why
Operator playtest, 2026-11-16 (plan/operator-feedback-2026-11-16.md, J1): the control pad below the ship only says
where to drag. Put a flight-joystick hero render there, where "drag to pilot" is, that tilts with the ship's direction
and speed, so that looking at it makes players want to touch and drag there.

## What Changes
- **Art**: a 3D flight stick (octagonal base with a mint ring light and left/right arrow lights, bellows boot, steel
  shaft, moulded grip with a fire button and hat switch, amber trigger paddle), built as a rigkit family
  (`art/families/flight-joystick.json`), painted once with the committed Qwen-Image-Edit workflow from a clay control,
  and projection-baked onto 25 tilt poses (rest + 8 directions × 9°/18°/27°) so every frame carries the same paint.
  Finished as pixel art in the UI palette and packed into one 260 × 330 page (`assets/images/flight-joystick.png`,
  25.6 KB).
- **Runtime**: `FlightJoystick` in `PilotConsoleContent`, centred in the pad between the power glyph and the guidance.
  It picks the frame from the ship's velocity (lateral `shipVx` / 360, forward surge from the world's flight speed and
  the carrier climb's flow boost), eases toward it, rests when idle and respects reduced motion.
- **Hint**: the guidance becomes `DRAG TO PILOT` without the `◀ ▶` glyphs (the stick's base carries the arrows).
- **Shared libraries** (generic, no joystick constants): rigkit articulation (`poses`, `pose_matrix`, `apply_pose`;
  `rig.py --pose-passes`, `bake.py --poses 1`, `bake_poses.lua`), rigsheet `fit … bbox` registration, `poseatlas`,
  `posesheet`, `posecands`.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: the control pad gains the flight stick and its tilt behaviour.

## Impact
- `lib/widgets/flight_joystick.dart` (new), `lib/widgets/flight_joystick_atlas.dart` (generated),
  `lib/widgets/pilot_console_content.dart`, `lib/main.dart` (two arguments).
- Tests: `test/flight_joystick_test.dart`, `test/flight_joystick_review_test.dart`; the guidance text in four tests.
- Ledger: `plan/render-runs/flight-joystick.md`; runs: `art/families/flight-joystick-runs.json`.
