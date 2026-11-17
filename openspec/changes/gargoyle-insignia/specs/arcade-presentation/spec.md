# Arcade presentation

## MODIFIED Requirements

### Requirement: Alien rank insignia
Every flying creature above the lowest rank SHALL wear one gargoyle rank insignia above its head, in bone with a dark outline, built from fangs and wings: one fang for skirmishers, twin fangs for veterans, a winged fang for elites and a winged crown of fangs for sentinels. The boss's forms SHALL use the same ladder. Drones SHALL wear none, and the elite's dotted ring SHALL be removed.

#### Scenario: Mixed formation
- **WHEN** a formation of drones, skirmishers, veterans and an elite is on screen
- **THEN** each rank shows its own mark above its head and the drones show none

#### Scenario: The ladder escalates at a glance
- **WHEN** the four marks are drawn side by side at their in-game size
- **THEN** each rank's mark is wider than the one below it (fang 7, twin fangs 10, winged fang 13, winged crown 15 glyph pixels), and only the two winged marks carry the ember core

#### Scenario: Carrier forms
- **WHEN** the carrier is in its first, second, third or fourth form
- **THEN** its brood sigil shows the fang, the twin fangs, the winged fang or the winged crown respectively, at twice the size

## ADDED Requirements

### Requirement: Rank marks never read as hearts, smiles or faces
A rank insignia SHALL NOT read as a heart, a smile, a face or a mouth with teeth at in-game size. Single and paired fangs SHALL be asymmetric and never mirrored into a pair; a mirror-symmetric mark SHALL be at least 1.4 times wider than tall and SHALL carry at most one ember dot.

#### Scenario: Twin fangs are not a pair of teeth
- **WHEN** a veteran's twin fangs are drawn
- **THEN** both fangs lean the same way, the second sits one glyph pixel lower, and at least one empty glyph pixel separates them on every row

#### Scenario: Lookalike scores
- **WHEN** `go run . gargoyle` in `tools/alien_insignia` scores the shipped marks against a pixel heart, smile and face
- **THEN** no mark scores above 0.5 against any of them (the retired talon scored 0.76 against the heart)

#### Scenario: Officers wear one eye at most
- **WHEN** a hunter's or sentinel's mark is drawn
- **THEN** it shows exactly one ember pixel cluster on its centre line, never two side by side
