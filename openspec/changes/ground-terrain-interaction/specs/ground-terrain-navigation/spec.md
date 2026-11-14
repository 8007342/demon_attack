# Ground terrain navigation

## ADDED Requirements

### Requirement: Movement classes
Every ground unit and ally SHALL belong to exactly one movement class: infantry, light vehicle, heavy vehicle or walker. Each class SHALL have a walk slope limit, a climb slope limit and a set of crossing links it may use (infantry 0.45 / 2.5; light vehicle 0.35 / 0.75; heavy vehicle 0.30 / 0.60; walker 0.50 / 1.6, in displayed texels per texel). One mapping function SHALL assign the class, and no faction-specific movement code SHALL exist outside it.

#### Scenario: Existing forces map to classes
- **WHEN** the mapping is queried for demon grunts, rocket brutes, the heavy tank, each sector vehicle and each allied variant
- **THEN** grunts, rocket brutes and allied squads are infantry; buggy, rover, APC and half-track are light vehicles; crawler, tower, heavy tank, MBT, SPG and heavy are heavy vehicles; and beast and mech are walkers

### Requirement: Terrain tags from the generator
The navigation field SHALL tag cells as ravine, cliff, plateau, valley floor, crest, brush or lane from the generator's feature records, deterministically for a given sector, route, camera position and screen point.

#### Scenario: Canyon is tagged as a ravine
- **WHEN** a cell lies inside a canyon's footprint (`t < 1.05`) away from its shallow ends (`ends > 0.25`)
- **THEN** it carries the ravine tag, even though its floor slope is near zero

#### Scenario: Deterministic tags
- **WHEN** the same sector, route, camera position and lattice are sampled twice
- **THEN** every height, slope, tag and next column is identical

### Requirement: Ravines are crossed only at links
Skirmish units and allies SHALL never occupy a ravine cell except on a bridge or ford link their class may use. Threat units SHALL occupy a ravine cell without a link only when every cell of their side band at that depth is impassable for their class.

#### Scenario: Troops never path through ravine cells
- **WHEN** sectors 2, 3 and 5 (which have canyons) are flown with a headless relief for 120 s at many camera positions, on every difficulty
- **THEN** no skirmish unit or ally is ever on a ravine cell that has no link, and every threat unit found on one has its whole band row impassable

#### Scenario: Ravines no longer attract units
- **WHEN** a unit's lateral goal is chosen at a depth where a canyon lies within its reach
- **THEN** the goal is never inside the canyon footprint unless it is a link cell

### Requirement: Slope limits per class
A cell whose slope exceeds a class's climb limit SHALL be impassable for that class, except on a link the class owns. A slope between the walk and climb limits SHALL be passable at a reduced pace, in the climb or descend state.

#### Scenario: Steep slopes block vehicles but not infantry
- **WHEN** a ridge flank with slope 0.9 lies ahead of an infantry squad and of a light vehicle
- **THEN** the squad crosses it in the climb state, and the light vehicle's goal moves to a column whose slope is at most 0.75 (the lane saddle) if one is reachable

#### Scenario: Heavy vehicles never climb mesas
- **WHEN** a heavy vehicle's route meets a mesa
- **THEN** it never enters a cliff or plateau cell, and it turns away before the mesa's edge reaches its depth

### Requirement: Look-ahead routing
Lateral goals SHALL come from a per-class lateral flow field that integrates terrain cost along each unit's direction of travel relative to the scrolling ground: toward the camera for demons and up the plane for allies. A unit SHALL start avoiding an obstacle before the obstacle reaches its depth.

#### Scenario: Early swerve
- **WHEN** a mesa approaches a holding heavy vehicle in its column
- **THEN** its lateral goal moves off the mesa's columns at least 1.5 s before the mesa's edge reaches the vehicle's depth

### Requirement: Links have capacity
Bridges SHALL hold one unit and fords two. A unit refused by a full link SHALL wait in a queue on its approach. A queue of 2 to 4 units SHALL form a column without overlapping sprites. After 3 s a waiting skirmish unit SHALL fall back to the cheapest non-link cell.

#### Scenario: Convoy bunches at a bridge
- **WHEN** three allies must cross the same canyon at its bridge
- **THEN** they cross one at a time, the others hold in a column at the approach, and `convoyBridge` fires once

### Requirement: Rules stay on depth
Navigation SHALL never change a threat unit's depth, depth speed, fire range, breakthrough or missile timing, and SHALL never draw from `model.random` or the skirmish random stream. With no relief installed, behaviour SHALL be identical to before this change.

#### Scenario: Threat parity with navigation
- **WHEN** every sector and difficulty is flown by the same deterministic pilot, with a headless relief and navigation on and off
- **THEN** breakthroughs, ground missiles fired at the player and their launch times are equal, and the pilot's hit rate differs by at most 5%

#### Scenario: Flat ground unchanged
- **WHEN** `ground.relief` is null
- **THEN** unit positions match the previous build exactly for the whole of `ground_war_v4_sim_test`

### Requirement: Navigation budget
Navigation SHALL add at most 0.25 ms per frame to the busy ground war at 1080 × 2340 and SHALL allocate no memory per step.

#### Scenario: Frame cost
- **WHEN** `ground_war_v4_visual_test` runs a busy ground war in every sector with navigation on
- **THEN** the measured navigation share stays within budget and the total frame cost stays below 16 ms
