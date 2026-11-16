# Design: flight-joystick

## 1. Model and look
The stick is a rigkit family (`art/families/flight-joystick.json`): one hull `stick`, five slots (base, boot, stick,
grip, trigger), symmetric about x = 0, units = finished texels. The camera is the pilot's: behind and above, pitch 45.
Materials take the pad's colours (lib/main.dart `ConsolePainter`): slate housing, mint ring light and grip band, cyan
arrow lights, amber trigger, red fire button. The finish palette is the UI's slate, mint, amber and red ramps plus a
navy ramp (without it the painted navy grip quantised to the pad's own navy and vanished).

Head-reading guard (carrier lesson, styleguide §3.4): no pair of thumb keys under the grip cap (two dots under a dome
read as eyes); one hat switch only.

## 2. Tilt grid and the bake
`articulation` in the family: pivot at the gimbal (z 10); the shaft, grip and trigger follow the tilt fully, the boot
leans by 0.45 about its own foot. 25 poses: rest, then 8 directions (0 = right, 90 = forward / screen up) × 9°, 18°,
27°. One hero is painted from the rest-pose control; `bake.py --poses 1` renders every pose with the hero projected in
object coordinates, so the paint moves with the parts. Surfaces the hero never saw (the back of a grip tilted toward
the pilot, the trigger) take the family fill under the key light.

The Lightning edit re-framed the small subject (taller, higher than the control). `rigsheet fit … bbox` registers the
raw's non-key box to the clay silhouette box (independent x/y scale and offset) before the mask; a raw that kept the
framing is unchanged.

## 3. Atlas
`rigsheet poseatlas` finishes each pose at texel 1.0 (palette + ink), trims all poses to the union of their alpha boxes
(52 × 66, so the static base never jumps), packs them row-major 5 per row, and writes the generated
`lib/widgets/flight_joystick_atlas.dart`. Page 260 × 330: 25.6 KB PNG, 0.34 MB resident. The manifest stays in the
bake cache; the page ships alone.

## 4. Runtime
- **Target** `flightJoystickTarget(model, boost:)`: x = `shipVx` / 360; y = (worldSpeed × flowBoost − 1) / 1.2,
  clamped to [0, 1]. worldSpeed is the flyover's own factor (flow `speed` beat, level-clear run-out). At cruise with
  the ship still the target is zero. The ship only moves sideways while piloting, so the forward lean comes from flight
  speed: the carrier climb (flowBoost up to 2.2) and sector climbs.
- **Frame** `flightJoystickCell(v)`: dead zone 0.06; step = round(|v| × 3) in 1..3; direction = nearest of 8.
- **Ease**: an exponential follow on a ticker, rate 14/s out and 9/s back to rest (a spring-loaded gimbal); the ticker
  stops when settled, so an idle stick costs nothing. The widget repaints only when the cell changes.
- **Reduced motion** (platform setting or `model.reducedMotion`): no easing, and the lean is limited to the first
  step (9°): direction stays readable with the least motion.
- **Pixels**: nearest sampling at the largest whole number of device pixels per texel that fits the box (66 CSS px
  tall at DPR 1, 2 and 3 in the 108 px pad), top-left snapped to the device grid.
- **Affordance**: a flat mint under-glow ellipse under the base, brighter while touching. No idle wiggle: the operator
  asked for the stick to rest when idle.
- **Layout**: powers | stick | guidance with equal side flex, so the stick sits at the pad centre under the arena.
  The whole pad stays the touch target (`IgnorePointer` content).

## 5. Rejected
- Rugged look (chipped paint, stencils): painted rust, stencilled text and an extra button on the base.
- 16 directions: the ship mostly moves sideways; 8 directions land exactly on left/right and keep the page small.
- Crossfading neighbouring frames: ghosts a doubled stick.
- A full-model (40-step) repaint: at 52 × 66 texels the Lightning detail is already beyond the finish.
