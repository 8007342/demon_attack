# Tasks

## 1. Pipeline
- [x] 1.1 rigkit articulation: poses, pose_matrix, apply_pose; pose-aware frame; rig.py --pose-passes; bake.py --poses
- [x] 1.2 rigsheet: fit bbox registration, poseatlas (+ generated Dart), posesheet, posecands
- [x] 1.3 bake_poses.lua: the no-GPU rebuild from the committed pick

## 2. Art
- [x] 2.1 Family `flight-joystick`: base, boot, stick, grip, trigger; clay previews per pose
- [x] 2.2 Hero candidates (Lightning, 14 images, 3 jobs); pick 7030005, raw committed
- [x] 2.3 Projection bake of 25 poses; atlas 260 × 330, 25.6 KB

## 3. Runtime
- [x] 3.1 `FlightJoystick`: target from ship velocity and flight speed, cell pick, ease, rest when idle, reduced motion
- [x] 3.2 Pilot console: stick centred between powers and guidance; `DRAG TO PILOT`
- [x] 3.3 Tests: cell, target, ease, reduced motion, layout; in-game review frames

## 4. Review
- [x] 4.1 Contact sheets: candidates, tilt grid, in-game (rest, left, up-right fast) at 360 × 780, DPR 2
