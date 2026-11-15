# Bonus level: Stormfront

## ADDED Requirements

### Requirement: Stormfront replaces a sector with a thunderstorm
The bonus level `stormfront` SHALL replace one regular sector's content with a fight inside a thunderstorm over that sector's own backdrop: two thinned waves without sentinels, under a dark storm grade. It SHALL be entered and left through the ordinary fog transition, and it SHALL NOT show any card, title or text over the play area.

#### Scenario: Entering the storm
- **WHEN** a run's bonus slot holds `stormfront` and the previous sector is cleared
- **THEN** the usual Rout, Pursuit and Descent play, and the sector arrives dark and stormy with the level's first wave

#### Scenario: Leaving the storm
- **WHEN** the level's last creature falls
- **THEN** the ordinary sector change to the next sector begins

### Requirement: Lightning strikes a telegraphed column
During Stormfront combat, lightning SHALL strike columns of the arena. Every strike SHALL be telegraphed for at least one second of real time by a leader flickering down its column and a marker on the ship's row, and its column SHALL NOT move after the tell begins. Most tells SHALL take the ship's position at the moment they begin; the others SHALL take the swarm's densest column. No tell SHALL begin, and a running tell SHALL end without a bolt, while the ship is away or outside combat.

#### Scenario: A tell on the ship
- **WHEN** a tell begins on the ship's position
- **THEN** the leader and the marker stay on that column for at least one second before the bolt, wherever the ship flies

#### Scenario: The ship is lost during a tell
- **WHEN** the ship is destroyed while a tell is running
- **THEN** that tell ends without a bolt and no tell begins until the reserve ship is in play

### Requirement: Lightning does not take sides
A bolt SHALL hit every targetable creature inside its column with a heavy hit, and SHALL cost the ship a life when the ship is inside the bolt's narrower core, exactly as an ordinary hostile hit (a shield absorbs it; protection ignores it). A ship that leaves the column after the tell begins SHALL always escape.

#### Scenario: Baiting the storm
- **WHEN** the player waits under a group of creatures until a tell begins there, then moves away
- **THEN** the bolt hits those creatures and not the ship

#### Scenario: Standing still
- **WHEN** the ship stays in the core of a tell until the bolt
- **THEN** the ship takes an ordinary hit

### Requirement: Storm kills score as kills, baited kills earn a capped bonus
Creatures destroyed by lightning SHALL count as ordinary kills. A bolt that was aimed at the ship and destroys creatures SHALL add a bait bonus per creature, and the level's bonuses SHALL stay inside the level's score cap.

#### Scenario: A baited bolt
- **WHEN** a bolt aimed at the ship destroys two creatures and misses the ship
- **THEN** both score their ordinary points and the bait bonus is added once per creature, up to the level's cap

### Requirement: The lightning rod
Stormfront SHALL offer a bonus-only powerup, the lightning rod. The first baited kill of each wave SHALL drop one. While it is active, every tell SHALL be drawn to the ship, its bolt SHALL hit a wider column of creatures, and it SHALL NOT harm the ship.

#### Scenario: Grounded
- **WHEN** the ship carries the lightning rod and a bolt lands on it
- **THEN** the creatures above the ship are hit and the ship loses nothing

### Requirement: Storm shielding
Inside Stormfront a kill's power drop SHALL have an even chance of being a shield instead of the rotation's next power.

#### Scenario: A drop in the storm
- **WHEN** a kill drops a power in Stormfront
- **THEN** it is a shield about half the time

### Requirement: The storm speaks by radio
Stormfront SHALL be announced and narrated only by radio: a storm warning in the transition's radio slot, a call when combat begins, a warning for a tell on the ship, remarks from the squad and the brood on a baited bolt, a call for the rod and a call when the level is cleared. Until a line has its own recording it SHALL play a recorded line with that line's own subtitle and speaker.

#### Scenario: Storm warning
- **WHEN** the transition into Stormfront reaches its radio slot
- **THEN** a storm warning plays on the comms dock, or a recorded placeholder with its own subtitle

### Requirement: The storm is deterministic
For one run seed, route and sector, the storm SHALL draw the same sequence of gaps, aims and forks from its own random stream, and SHALL NOT draw from the simulation's random stream.

#### Scenario: Same seed, same storm
- **WHEN** the level is played twice from the same seed with the same input
- **THEN** every tell begins at the same time on the same column

### Requirement: The storm is gentle on the eyes
A bolt SHALL NOT flash the whole screen at more than a faint level, and bolts SHALL NOT land more often than once a second. With reduced motion the leader SHALL NOT flicker, rain SHALL NOT be drawn and the bolt SHALL be a steady line with no screen flash.

#### Scenario: Reduced motion
- **WHEN** reduced motion is enabled and a bolt lands
- **THEN** a steady bolt and its marker are drawn, with no flicker, rain or screen flash
