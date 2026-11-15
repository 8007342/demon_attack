# Arcade presentation

## ADDED Requirements

### Requirement: Alien rank insignia
Every flying creature above the lowest rank SHALL wear one alien rank insignia above its head, drawn in bone with a dark outline: one talon for skirmishers, two talons for veterans, a rayed eye (ocellus) for elites and a crown over an ocellus for sentinels. The boss's forms SHALL use the same ladder. Drones SHALL wear none, and the elite's dotted ring SHALL be removed.

#### Scenario: Mixed formation
- **WHEN** a formation of drones, skirmishers, veterans and an elite is on screen
- **THEN** each rank shows its own mark above its head and the drones show none

### Requirement: Insignia legibility at phone scale
Rank insignia, shield cells and status rims SHALL keep a fixed on-screen size regardless of creature scale or camera zoom, with strokes of about 2.7 CSS pixels and marks of at least 9 by 6 CSS pixels on a 360-pixel-wide arena. They SHALL stay on the creature in every flight pose and SHALL NOT appear on creatures still hidden in the fog.

#### Scenario: Zoomed-out boss fight
- **WHEN** the camera zooms out during a boss fight
- **THEN** the insignia of nearby creatures keep their size and remain distinguishable

### Requirement: Force shields read as shields
A force shield SHALL show one cyan hex cell per shield point in front of the creature, facing the player, with spent points kept as dark sockets, and a cyan rim around the creature while any point remains. A hit that removes a point SHALL break its cell into falling shards. Thermal dive shields SHALL keep their thermal colours, split into one segment per point.

#### Scenario: Sentinel shield worn down
- **WHEN** a sentinel with a five-point shield takes two shield hits
- **THEN** three cyan cells and two dark sockets are visible in front of it and its cyan rim remains

### Requirement: Health and state readouts
A wounded creature's whole hide SHALL warm in steps toward ember with each molt, an angry creature SHALL show an ember rim with its insignia turning gold, and a creature about to dive SHALL flash its insignia and rim white for the length of its warning. No numeric health pips SHALL be shown.

#### Scenario: Last hit point
- **WHEN** a multi-hit creature is reduced to its last hit point
- **THEN** it shows an ember rim and a gold insignia, and its hide is visibly warmer than when it was intact
