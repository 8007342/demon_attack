# Arcade presentation

## ADDED Requirements

### Requirement: Boss overflight
During the boss arrival the boss SHALL fly in from behind the player: its belly and shadow SHALL sweep up the screen over the ship, shrink toward the horizon and sink into the far fog. The overflight SHALL be presentation only and SHALL never hide the ship at more than 55 percent opacity.

#### Scenario: Arrival
- **WHEN** the squadron arrives in the boss sector
- **THEN** a huge dark hull passes overhead from behind the ship, shrinks toward the horizon and disappears into the fog

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
