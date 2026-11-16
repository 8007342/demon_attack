# Ground blocks runtime presentation

## ADDED Requirements

### Requirement: Per-sector ground block atlases
The game SHALL draw reworked ground units from the current sector's three block atlases (Fleet, Host,
infantry), resolved through the generated block metadata, and SHALL keep only one sector's block atlases
resident. A unit with no block in the loaded sector SHALL be drawn with the previous ground atlases.

#### Scenario: Sector change
- **WHEN** the run moves from Ringfall to Ember
- **THEN** the Ember Fleet, Host and infantry atlases are loaded, the Ringfall ones are released, and any
  Ringfall unit still on screen keeps drawing from the previous ground atlases

### Requirement: Headings follow travel
A ground unit's hull heading SHALL follow its direction of travel through the turn tracker, one authored
heading at a time with the class's rate limit, hysteresis and minimum hold, mirrored for the other half. A
convoy vehicle falling back SHALL keep its nose up the plane and run its treads backward.

#### Scenario: Skirmish vehicle swerves
- **WHEN** a Host vehicle advancing toward the camera turns to cross the plane to screen left
- **THEN** it shows 180°, −157.5°, −135°, −112.5° and −90° in order, never skipping one

### Requirement: Articulated layer aims independently
A unit with an articulated layer SHALL draw it at its own angle toward its foe, seated on the hull's
per-heading pivot, with recoil along its angle; the friendly tracer SHALL leave from that angle's muzzle.

#### Scenario: Convoy tank engages
- **WHEN** a Lodestar drives up the plane while its foe is to the right
- **THEN** its turret turns through the angle steps toward the foe while the hull keeps its heading, and its
  tracer starts at the muzzle of the shown angle

### Requirement: Ground unit states and overlays
Ground units SHALL show move, idle, aim and fire, hit, damage, wreck and rubble (Host), totalled and pod
(Fleet), pitch on slopes, walker bob and the infantry action set from their blocks. Sparse overlays (channel
fill, lights, damage) SHALL be drawn over the cell they belong to; a missing overlay SHALL draw nothing.
Beyond depth 900 only the `lights` overlay SHALL be drawn and the layer SHALL snap to every other angle.

#### Scenario: Far unit
- **WHEN** a damaged Host tank winds up at depth 1000
- **THEN** its lights overlay is drawn but its fill and damage overlays are not

#### Scenario: Very far unit
- **WHEN** a five-heading unit is beyond depth 1200
- **THEN** it shows every other heading and its articulated layer follows the hull

### Requirement: Threat telegraph timing unchanged
The four threat vehicles SHALL show their telegraph on the block's special frames (launcher raised, glow,
launch flash, smoking) at exactly the times the previous atlas columns were shown, and the warning bracket
SHALL be unchanged.

#### Scenario: Launch tell
- **WHEN** a threat vehicle is 50 % through its telegraph
- **THEN** it alternates between the raised and glowing special frames at the same rate as before

### Requirement: Presentation only, with a fallback
Drawing from the blocks SHALL NOT change any simulation state or random stream. A switch SHALL restore the
previous ground atlases for every unit.

#### Scenario: Switch off
- **WHEN** `GroundPainter.useBlocks` is false
- **THEN** every ground unit is drawn exactly as before this change
