# Arcade presentation

## ADDED Requirements

### Requirement: Boss hero art view set
Each boss hull SHALL have original hero art drawn from nine viewing angles (three pitches by three yaws), with identical materials, colours and silhouette proportions in every view, so that a change of view reads as the same ship turning or gliding. Its core, bays, turrets and solid body SHALL project within 3 arena units of the shared hit geometry in every view.

#### Scenario: Swerve sequence
- **WHEN** the boss's views are played in order through a swerve and a glide
- **THEN** the ship reads as one object turning, with no change of materials or detail between views and its core window on its hit area

### Requirement: Boss module, damage and wreck art
Each boss hull SHALL have separate art for its spine and each of its modules in every view, damage art for its scorched, exposed and breaking stages, and a falling wreck for each module, all derived from one approved hero image per hull so that every stage matches the intact ship.

#### Scenario: Module breaks away
- **WHEN** a module detaches during the fight
- **THEN** the hull behind it and the falling wreck both match the ship's established look

### Requirement: Boss art budgets
Only one boss hull's art SHALL be resident at a time, at no more than 16 MB of RGBA texture memory, in atlas pages no larger than 4096 by 2048 pixels, and loaded lazily as today.

#### Scenario: Largest hull
- **WHEN** the fifth tour's dreadnought is loaded on a phone
- **THEN** its resident boss art stays within 16 MB and no other hull's art is resident

### Requirement: Reproducible boss art provenance
Every boss art asset SHALL be reproducible from committed inputs: the hull grammar, the rig scripts, the workflows, the prompts and seeds, the model hashes, and the selected raw images committed to the repository, with every run (including rejected ones) logged.

#### Scenario: Rebuild after a cache wipe
- **WHEN** the forge cache is wiped by a host reset
- **THEN** the boss atlases can be rebuilt byte-identically from the repository without any GPU job
