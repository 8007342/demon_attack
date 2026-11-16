# Arcade presentation

## ADDED Requirements

### Requirement: Boss overflight
During the boss arrival the boss SHALL fly in from behind the player: its belly and shadow SHALL sweep up the screen over the ship, shrink toward the horizon and sink into the far fog. Where the boss art provides a baked underside, the overflight SHALL show that underside; otherwise it SHALL show the hull. The overflight SHALL be presentation only and SHALL never hide the ship at more than 55 percent opacity.

#### Scenario: Arrival
- **WHEN** the squadron arrives in the boss sector
- **THEN** a huge dark hull passes overhead from behind the ship, shrinks toward the horizon and disappears into the fog

#### Scenario: Baked underside
- **WHEN** the run's carrier has a baked belly view
- **THEN** the overflight shows its armoured underside rather than its top

### Requirement: Boss fight altitude
When the boss reaches the front the fight SHALL climb: the ground below SHALL appear farther away, with terrain, ground units and shadows smaller and their parallax slower, easing smoothly and never stepping. Ground combat ranges and outcomes SHALL be unchanged.

#### Scenario: Climbing fight
- **WHEN** the boss settles at the front
- **THEN** within a few seconds the ground recedes and scrolls more slowly beneath the fight

### Requirement: Dynamic boss camera zoom
During the boss fight the play area SHALL zoom out by at most 14 percent and back in, smoothly, following the boss's range of motion, about a pivot on the ship's row. The HUD, the comms dock, the pause control, the cockpit panel and touch controls SHALL never be zoomed.

#### Scenario: Wide swerve
- **WHEN** the boss sweeps across the arena and turns
- **THEN** the play area eases out a little to show its range and eases back in as it slows

### Requirement: Carrier camera framing
When the boss is a carrier hull larger than the arena, the boss camera SHALL frame the play area between 86 and 70 percent instead: it SHALL ease to 86 percent as the carrier rises, and the same range, swerve and climb terms SHALL take it toward 70 percent at the same rate limit and pivot. During threat holds it SHALL ease back toward 86 percent.

#### Scenario: Carrier fight on a phone
- **WHEN** a carrier fight has climbed and the carrier sweeps wide on a 360 by 640 phone
- **THEN** the play area is framed at no less than 70 percent, the carrier spills off the top and both sides, and the HUD and controls keep their size

### Requirement: Carrier draw-size floors
Where the carrier framing would draw a creature below 34 CSS pixels or the ship below 36, it SHALL be drawn larger to keep the floor, while its hitbox stays unchanged.

#### Scenario: Smallest carrier framing
- **WHEN** the carrier framing reaches 70 percent
- **THEN** the far-row creature is drawn at least 34 CSS pixels and the ship at least 36, and a scripted fight is identical to the fight at full zoom

### Requirement: Camera zoom gameplay safety
Camera zoom SHALL NOT change any hitbox, collision, spawn or firing outcome, and touch input SHALL map through the zoom so the ship follows the finger exactly. At the smallest zoom, creatures SHALL stay at least 34 CSS pixels, the ship 36 and enemy bullets 3. The zoom SHALL hold during dive warnings, rush locks and ground-missile warnings. With reduced motion the zoom SHALL be static.

#### Scenario: Same fight at two zooms
- **WHEN** a scripted boss fight is replayed at full zoom and at the smallest zoom
- **THEN** every hit, miss, spawn and shot is identical

#### Scenario: Reduced motion
- **WHEN** reduced motion is enabled
- **THEN** the boss fight uses one fixed framing with no dynamic zoom or camera follow

### Requirement: Boss camera follow
The ground and sky below the boss fight SHALL pan sideways and shift their horizon to follow the boss, with far layers moving less than near layers, so that the perspective of the ground far below shifts with the fight. Creatures, the ship, bullets and the boss SHALL NOT be panned by the follow.

#### Scenario: Boss glides to one side
- **WHEN** the boss glides toward the left edge and dips
- **THEN** the ground pans with it and its horizon shifts, while the player's ship stays where the player put it

### Requirement: Boss swerve and pitch views
The boss SHALL be shown from slightly different viewing angles as it moves: steeper or shallower pitch (such as 38, 45 and 52 degrees) as it glides down or up, and a yaw toward its direction of travel as it swerves. View changes SHALL blend without pops, and the boss's core, bays and turrets SHALL stay where they can be hit in every view.

#### Scenario: Changing direction
- **WHEN** the boss reverses its horizontal direction
- **THEN** it swerves through its frontal view to the opposite angled view, and its core window stays aligned with its hit area

### Requirement: Staged boss damage and collapse
The boss SHALL show its decay in stages: shield cells going dark one by one, scorching, armour plates peeling off with fires, modules breaking away at each form change, and finally a collapse in which the hull breaks into wrecks that fall into the fog with their shadows. These stages SHALL be presentation only.

#### Scenario: Form change
- **WHEN** the boss's core damage moves it into its next form
- **THEN** one of its modules breaks off and falls away, and the hull lists

#### Scenario: Collapse
- **WHEN** the boss's core is destroyed
- **THEN** its modules detonate in order and their wrecks fall into the fog before the victory pursuit

### Requirement: Runtime decay overlay
The scorched stage SHALL be a runtime overlay on the intact art: darkening, crystal flicker and ember cracks. Where a hull's art has no look for a later stage, that stage SHALL be shown as the intact art under a heavier overlay, and modules that broke away SHALL be left as charred stumps, never as holes.

#### Scenario: A later tour without stage art
- **WHEN** a tour-three carrier, whose art has only its intact look, loses its shield and then a module
- **THEN** it darkens with glowing ember cracks, and the lost module's place is a charred stump while its wreck falls with its shadow

### Requirement: Wreck shadows and a whole hull to the end
Each falling wreck SHALL throw a shadow shaped by its own sprite's silhouette onto the fog below, and in the collapse the hull SHALL keep its shape until each piece breaks away, the carapace sinking last.

#### Scenario: Collapse of a carrier
- **WHEN** a carrier's core is destroyed
- **THEN** its pieces break away one by one from the intact hull, each sinking into the fog with a matching shadow

### Requirement: Giant boss hull beyond the screen
The boss art MAY be larger than the screen and spill off its edges; its hit areas and weak points SHALL stay on the shared on-screen geometry at every zoom.

#### Scenario: A hull wider than the arena
- **WHEN** a packed hull's layers extend beyond the arena
- **THEN** they are drawn partly off-screen while the core, bays and turrets stay where they can be hit

### Requirement: Faster fog and fog-bank shadows in the boss fight
As the boss fight climbs, the fog SHALL flow faster past it while the ground below slows, and the fighting boss SHALL throw its shadow onto the intermediate fog layers. Reduced motion SHALL keep the fog's normal speed.

#### Scenario: Climbing fight in the fog
- **WHEN** the boss fight has climbed
- **THEN** the fog banks stream faster and darken under the boss's shadow

### Requirement: Per-run boss module sets
Each run's boss SHALL be one of its tour's baked set combinations (three on the first tour), picked deterministically from the run's seed; a run without a seed SHALL draw the first combination. Each tour SHALL add more guns, spikes and barriers. These choices SHALL be visual only.

#### Scenario: Two runs, same tour
- **WHEN** two runs with different seeds reach the same tour's boss
- **THEN** their bosses may use different module sets while their hit areas and endurance follow the same rules

#### Scenario: Same seed
- **WHEN** a run is replayed with the same seed
- **THEN** its carrier is drawn with the same set combination

### Requirement: Faceless carrier deck
The carrier's hangar deck SHALL never read as a face: the deck furniture drawn over the art at the core, bays and turrets SHALL use plain hatch leaves without teeth, weak-point glows in vertical slits, solid bulkheads that split the deck into separate hatches, and dark gun barrels with ember muzzles; art features near the deck that read as eyes or fangs SHALL be toned down to the hull's value.

#### Scenario: Engaged carrier
- **WHEN** a carrier engages at its widest framing on a phone
- **THEN** its prow reads as a hangar deck of three hatches between gun blisters, with no eyes, mouth or teeth
