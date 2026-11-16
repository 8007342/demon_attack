# Arcade presentation

## MODIFIED Requirements

### Requirement: Boss swerve and pitch views
The carrier SHALL be drawn from a single viewing angle and SHALL NOT switch between discrete pitch or yaw views. Its turning, banking and gliding SHALL be shown by a continuous runtime bend of that one view: a heading lean of at most 3 degrees, a bank of at most 2.5 degrees and a pitch change of at most 2 degrees (3 degrees during the take-off beat), each eased by a heavy spring so the hull never snaps. The bend SHALL be pivoted on the hangar deck so that the carrier's core, bays and turrets stay within 3 arena units of their hit areas at every bend, and outer wings and arms MAY lag the hull's bend by a fraction of a second. Hulls that are not carriers keep their frontal view.

#### Scenario: Changing direction
- **WHEN** the carrier reverses its horizontal direction at full speed
- **THEN** its hull leans gradually through upright to at most 3 degrees the other way, with no visible cut or crossfade between views, and its core window stays on its hit area

#### Scenario: Gliding
- **WHEN** the carrier glides from the top to the bottom of its glide band
- **THEN** its pitch changes by no more than 2 degrees and the same art is drawn throughout

### Requirement: Carrier camera framing
When the boss is a carrier hull larger than the arena, the boss camera SHALL frame the play area between 86 percent and the tour's minimum: 70 percent on the first tour, 68 on the second, 66 on the third, 64 on the fourth and 62 on the fifth and later tours. It SHALL ease to 86 percent as the carrier closes in, and the same range, swerve and climb terms SHALL take it toward the tour's minimum, at the same rate limit and about the same pivot. During threat holds it SHALL ease back toward 86 percent.

#### Scenario: Carrier fight on a phone
- **WHEN** a first-tour carrier fight has climbed and the carrier sweeps wide on a 360 by 640 phone
- **THEN** the play area is framed at no less than 70 percent, the carrier spills off the top and both sides, and the HUD and controls keep their size

#### Scenario: A later carrier
- **WHEN** the fourth tour's carrier fight has climbed
- **THEN** the play area frames down to 64 percent, wider than any earlier tour's carrier, and the minimum on-screen sizes still hold

### Requirement: Carrier draw-size floors
Where the carrier framing would draw a creature below 34 CSS pixels or the ship below 36, it SHALL be drawn larger to keep the floor, while its hitbox stays unchanged. Enemy bullets SHALL stay at least 3 CSS pixels at every tour's minimum framing.

#### Scenario: Smallest carrier framing
- **WHEN** the carrier framing reaches the fifth tour's 62 percent
- **THEN** the far-row creature is drawn at least 34 CSS pixels, the ship at least 36 and enemy bullets at least 3, and a scripted fight is identical to the fight at full zoom

## ADDED Requirements

### Requirement: Hull-conforming carrier force field
The carrier's force field SHALL be drawn as a membrane that follows the carrier's whole silhouette, including the parts that spill off-screen, at an offset that tightens as the shield wears, and it SHALL bend with the hull.

#### Scenario: Full shield
- **WHEN** a carrier engages with its shield full
- **THEN** a rim of the field outlines its hull, prongs and arms out to the screen edges, not an arc under its deck

### Requirement: Force field depletion by region
The field SHALL be divided into twelve regions, one per shield cell, that go dark one by one from the outer arms inward, so that the region over the prow is the last to fail.

#### Scenario: Shield worn down
- **WHEN** the player wears the carrier's shield from full to half
- **THEN** six regions on the outer arms and wings have gone dark, each with a white flash and falling shards, and the prow's region is still lit

### Requirement: Force field hits on the gameplay surface
Hits SHALL show a local flash of the hex lattice and a ripple at the impact, and within the field's gameplay band its front lip SHALL be drawn exactly on the surface where player shots are stopped.

#### Scenario: A shot on the field
- **WHEN** a player shot is stopped by the shield
- **THEN** the stop is drawn on the field's lit front lip, with a ripple there

### Requirement: Carrier approach presentation
While the carrier approaches, it SHALL be drawn far ahead, small and hazed toward the fog colour, and SHALL grow, sharpen and move to its fight row as it closes, passing nearer fog banks as it comes. The scale SHALL follow the distance (a quarter of its fight size at the start of the approach). It SHALL never be drawn with full contrast before it is in range.

#### Scenario: The approach begins
- **WHEN** the boss level begins after the overflight
- **THEN** the carrier is seen far ahead at about a quarter of its fight size, faded toward the fog, with its running lights blinking

#### Scenario: Closing in
- **WHEN** a launch wave is cleared
- **THEN** the carrier visibly comes closer: larger, clearer, lower on the screen

### Requirement: Carrier gate launches presentation
Every creature the carrier launches SHALL visibly come out of a gate or compartment on its hull: the gate SHALL telegraph with lights for about a second before its doors open, its launch rail SHALL light toward the opening, the creatures SHALL eject from the opening along its direction and the doors SHALL close after the last one. A gate on a part of the hull that is off-screen SHALL NOT launch.

#### Scenario: A volley
- **WHEN** the carrier launches a group of creatures
- **THEN** the player sees the gate's lights, its doors opening and the creatures streaming out of it before they join the fight

### Requirement: Carrier take-off and climb
When the carrier comes in range, it SHALL take off: in a beat of about two and a half seconds the world SHALL pitch as the fog rushes past, the carrier's nose SHALL lift slightly, and the camera SHALL follow the climb so that the ground battle drops lower and smaller and the play area zooms out to the tour's carrier framing. The player's ship SHALL stay where the player put it.

#### Scenario: Take-off
- **WHEN** the carrier reaches the hittable distance
- **THEN** the view climbs with it, the ground falls away and the play area eases out, while the ship stays under the player's finger

### Requirement: Ultra-fast carrier motion cues
During the climbed carrier fight, speed SHALL be shown around the carrier rather than by moving it quickly: streaks in the fog layers, cloud layers flowing faster the nearer they are, vortex trails from its prong and wing tips, cloud wisps torn over the off-screen hull, and a slow low buffet in the hull's bend.

#### Scenario: Climbed fight
- **WHEN** the carrier fight has climbed
- **THEN** fog streaks and near cloud layers stream past faster than far ones and trails pour from the carrier's tips, while the hull itself moves heavily and slowly

### Requirement: Restraint of carrier motion cues
Screen shake SHALL be used only on the take-off, a module loss, the core exposed and the collapse, and the motion cues SHALL NOT be drawn over the player's ship, its bullets or enemy bullets, nor in white-hot or cyan.

#### Scenario: Steady fire
- **WHEN** the carrier fight runs without a take-off, module loss, core exposure or collapse
- **THEN** the screen does not shake, and no streak or trail crosses the ship or a bullet

### Requirement: Reduced motion in the carrier fight
With reduced motion enabled, the carrier SHALL be drawn without bend, buffet, streaks, vortex trails, shake or world pitch; the approach, the take-off and the climb SHALL be shown as gentle ramps, and the fog SHALL keep its normal speed.

#### Scenario: Reduced-motion take-off
- **WHEN** reduced motion is enabled and the carrier comes in range
- **THEN** the ground recedes and the framing eases out over about a second, with no pitch, shake or streaks
