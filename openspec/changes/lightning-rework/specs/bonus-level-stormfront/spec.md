# Bonus level: Stormfront (lightning rework)

## MODIFIED Requirements

### Requirement: Stormfront replaces a sector with a thunderstorm
The bonus level `stormfront` SHALL replace one regular sector's content with a fight inside a thunderstorm over that sector's own backdrop: the sector's waves, sentinels and elites, each opening roster 7 % smaller (the storm stuns and the pilot shoots every creature), under a dark storm grade. It SHALL be entered and left through the ordinary fog transition, and it SHALL NOT show any card, title or text over the play area.

#### Scenario: Entering the storm
- **WHEN** a run's bonus slot holds `stormfront` and the previous sector is cleared
- **THEN** the usual Rout, Pursuit and Descent play, and the sector arrives dark and stormy with the level's first wave

#### Scenario: Leaving the storm
- **WHEN** the level's last creature falls
- **THEN** the ordinary sector change to the next sector begins

#### Scenario: As long as the sector
- **WHEN** the storm replaces a sector that has five waves
- **THEN** it plays five waves, each opening roster 93 % of the sector's

### Requirement: Lightning does not take sides
A bolt SHALL stun every targetable creature inside its column (storm-lightning) and SHALL zap the ship when the ship is inside the bolt's narrower core: every shield and power-up stripped, never a life. Protection ignores it. A ship that leaves the column after the tell begins SHALL always escape.

#### Scenario: Baiting the storm
- **WHEN** the player waits under a group of creatures until a tell begins there, then moves away
- **THEN** the bolt stuns those creatures and misses the ship

#### Scenario: Standing still
- **WHEN** the ship stays in the core of a tell until the bolt
- **THEN** the ship loses its shields and power-ups and keeps its lives

### Requirement: Storm kills score as kills, baited kills earn a capped bonus
Lightning SHALL NOT destroy creatures. A creature shot down while stunned by a bolt that was aimed at the ship and missed it SHALL score its ordinary points plus a bait bonus, and the level's bonuses SHALL stay inside the level's score cap.

#### Scenario: A baited bolt
- **WHEN** a bolt aimed at the ship stuns two creatures and misses the ship, and the player shoots both while they fall
- **THEN** both score their ordinary points and the bait bonus is added once per creature, up to the level's cap

### Requirement: The lightning rod
Stormfront SHALL offer a bonus-only powerup, the lightning rod. The first creature of each wave shot down while stunned by a baited bolt SHALL drop one. While it is active, every tell SHALL be drawn to the ship, its bolt SHALL stun a wider column of creatures, and it SHALL NOT zap the ship.

#### Scenario: Grounded
- **WHEN** the ship carries the lightning rod and a bolt lands on it
- **THEN** the creatures above the ship are stunned and the ship loses nothing

### Requirement: The storm speaks by radio
Stormfront SHALL be announced and narrated only by radio: a storm warning in the transition's radio slot, a call when combat begins, a warning for a tell on the ship (every other one "Avoid lightning!"), a cue from the squad and yelps from the brood when a baited bolt stuns, reassurance after a zap, a call for the rod and a call when the level is cleared. An unrecorded line SHALL play a recorded placeholder or show its own words.

#### Scenario: Storm warning
- **WHEN** the transition into Stormfront reaches its radio slot
- **THEN** a storm warning plays on the comms dock, or a recorded placeholder with its own subtitle

#### Scenario: The first tell on the ship
- **WHEN** the level's first tell begins on the ship
- **THEN** a written "Avoid lightning!" line is shown and ends on the bolt

### Requirement: Stormfront pays and strikes like its sector
Kills in Stormfront SHALL pay 77 % of their points. The clear award SHALL be 0.15 of the sector's par score and the flawless award a further 0.1; the clear, flawless and bait awards together SHALL stay within 0.3 of it. The storm SHALL strike every 3.4-4.6 s on Easy, 3.3-4.7 s on Normal and 3.4-4.8 s on Hard (divided by the hostile rate), a tenth less often per route.

#### Scenario: A clean storm
- **WHEN** the last creature falls and no ship was lost
- **THEN** the level adds a quarter of the sector's par score, within its cap
