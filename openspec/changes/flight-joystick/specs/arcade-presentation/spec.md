# arcade-presentation updates

## ADDED Requirements

### Requirement: Flight stick in the control pad
The control pad SHALL show a pixel-art flight stick centred between the power glyph and the guidance label. Its frames SHALL come from one baked pose atlas (a rest pose and eight directions at three tilt magnitudes) drawn with nearest sampling at a whole number of device pixels per texel. The guidance SHALL read `DRAG TO PILOT`, and the whole pad SHALL remain the touch target.

#### Scenario: Pad layout
- **WHEN** a run is playing at any pad width
- **THEN** the power glyph, the stick and the guidance sit left to right inside the pad and a drag anywhere on it pilots the ship

#### Scenario: Consistent paint across poses
- **WHEN** any two pose frames are compared
- **THEN** the base is identical and the moving parts carry the same painted hero, projected from one picked render

### Requirement: Flight stick follows the ship
The stick SHALL tilt toward the ship's motion: sideways in proportion to the ship's lateral speed over its top speed, and forward in proportion to the flight speed above cruise (sector climbs, the level-clear run-out and the carrier climb's flow boost). It SHALL ease toward its target and SHALL rest, with no animation running, when the ship is still at cruise.

#### Scenario: Idle
- **WHEN** the ship is still at cruise speed
- **THEN** the stick shows its rest pose and no animation runs

#### Scenario: Strafing left at full speed
- **WHEN** the player drags so the ship moves left at its top speed
- **THEN** the stick eases over to its full left tilt, and back to rest when the ship stops

#### Scenario: Climbing with the carrier while strafing right
- **WHEN** the ship moves right at speed during the carrier climb
- **THEN** the stick leans forward and to the right

### Requirement: Flight stick under reduced motion
When the platform or the game asks for reduced motion, the stick SHALL change frame without easing and SHALL never lean past the first tilt step.

#### Scenario: Reduced motion
- **WHEN** reduced motion is on and the ship strafes at full speed
- **THEN** the stick snaps to the first tilt step in that direction
