# Arcade presentation

## ADDED Requirements

### Requirement: Adaptive quality tiers
The game SHALL pick one of three quality tiers (FULL, LEAN, LITE) from the frame intervals it measures. Sustained slow frames SHALL step down one tier at a time and a sustained calm SHALL step back up, with no oscillation. Lower tiers SHALL shed only ambient presentation (fog sheets, blur layers, rain, motes, sparks), never gameplay, and SHALL NOT overwrite the player's saved atmosphere choice.

#### Scenario: A steady phone stays rich
- **WHEN** a device runs at 60 Hz with 2 % of frames over 25 ms for one minute
- **THEN** the tier stays FULL and never changes

#### Scenario: A struggling or Low Power phone sheds load
- **WHEN** every frame takes 33 ms (Safari's 30 Hz Low Power Mode)
- **THEN** the tier reaches LEAN after the 2 s warm-up and one 120-frame window, and LITE after a second window

#### Scenario: No oscillation
- **WHEN** the tier climbs back to FULL after 20 s of calm and falls to LEAN again within 30 s
- **THEN** LEAN is the ceiling for the rest of the session

#### Scenario: Forced tier
- **WHEN** the page is opened with `?perf=lite`
- **THEN** the tier is LITE whatever the frame times

### Requirement: Per-frame caps on effects
Explosion sprites and deflect stars SHALL be capped per frame (the newest drawn), and each tier SHALL draw no more of any ambient effect than the tier above it. The simulation SHALL keep every effect; only drawing is capped.

#### Scenario: Caps by tier
- **WHEN** 30 explosions are alive
- **THEN** FULL draws at most 28, LEAN 20 and LITE 14, and the model still holds all 30

#### Scenario: Tier budgets
- **WHEN** LEAN or LITE is active
- **THEN** the fog draws its reduced slots, creature shadows draw one sharp layer, rain draws 60 % or 35 % of its drops, motes 75 % or 50 %, and LITE drops ricochet sparks and the eye-halo blur

### Requirement: Background without wasted work
The backdrop SHALL draw one world once the travel to a sector has settled, and per-draw blurs that never change SHALL be baked once instead of drawn as offscreen layers each frame.

#### Scenario: After a travel
- **WHEN** the backdrop's sector blend comes within 0.001 of the destination
- **THEN** it lands on the destination and draws one world's ground mesh and props

#### Scenario: The carrier's shadow on the fog
- **WHEN** the carrier fight draws its shadow on four fog banks
- **THEN** the frame has no per-draw blur for it, and the blurred look matches the before sheet

### Requirement: Steady stepping at the display rate
A frame interval within 2 ms of a whole number of 60 Hz steps SHALL step the fixed 1/60 s simulation exactly that many times. Other intervals SHALL pass through unchanged. The simulation step SHALL stay exactly 1/60 s.

#### Scenario: Jittered 60 Hz timestamps
- **WHEN** frame intervals alternate 16, 17 and 17 ms for 600 frames
- **THEN** every frame steps the model exactly once

#### Scenario: 30 Hz
- **WHEN** frame intervals alternate 33 and 34 ms
- **THEN** every frame steps the model exactly twice

### Requirement: Bullets drawn without strobing
Shots SHALL be drawn at their position interpolated to the frame, with a two-frame shimmer keyed to their age, and fast shots SHALL carry a faint motion smear one display frame long. Shot speeds and fire rates SHALL NOT change for rendering.

#### Scenario: Interpolated position
- **WHEN** a shot moving at (40, −390) px/s is drawn 0.01 s after the last step
- **THEN** it is drawn 0.4 px right and 3.9 px up of its model position, rounded to the pixel

#### Scenario: Shimmer rhythm
- **WHEN** a shot flies for 10 frames at 60 Hz
- **THEN** its sprite shows frame 0 for 5 frames and frame 1 for 5, whatever its height

#### Scenario: Reduced motion
- **WHEN** reduced motion is on
- **THEN** shots draw no smear

### Requirement: Batched bullet layer
All shot sprites SHALL be drawn in one atlas call and their wakes and smears in one path per colour, so the layer's draw calls do not grow with the number of shots.

#### Scenario: A big fight
- **WHEN** a frame holds 200 shots
- **THEN** the shots layer issues at most 16 draw calls, the same as for 10 shots
