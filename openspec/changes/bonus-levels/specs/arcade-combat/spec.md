# Arcade combat

## ADDED Requirements

### Requirement: Powerup rules
Every power that drops from a kill or a supply crate SHALL pass through the powerup rules in force. Rules SHALL support banning powers, allowing only one power, converting a drop to a given power with a given chance, and switching kill drops off. A banned drop SHALL become the next allowed power of the regular cycle, or nothing when all are banned. With no rule in force a drop SHALL be exactly the regular one.

#### Scenario: Ban
- **WHEN** shields are banned and the regular cycle would drop a shield
- **THEN** the next allowed power of the cycle drops instead

#### Scenario: Only one power
- **WHEN** the rules allow only spread
- **THEN** every kill drop and every crate carries spread

#### Scenario: Chance
- **WHEN** a rule converts drops to blast rounds with a 35 % chance
- **THEN** about 35 in 100 drops are blast rounds and the rest follow the regular cycle

### Requirement: Run modifiers
A seeded run MAY have one run modifier: a named set of powerup rules that holds for the whole run. Each modifier in the catalogue SHALL have its own chance per run; at most one SHALL fire. The run SHALL announce its modifier once, by radio, when combat first begins. A bonus level's own rules SHALL apply on top of the run modifier's: bans add up and the level's only-X wins.

#### Scenario: No-shield run
- **WHEN** a run has the no-shield modifier
- **THEN** no shield drops from any kill or crate in any sector of that run

#### Scenario: Announcement
- **WHEN** a run with a modifier reaches its first combat frame
- **THEN** one run-modifier event is sent and never repeated in that run

### Requirement: Bonus-only powerups
A bonus-only powerup SHALL drop only inside a bonus level and SHALL end when that level ends. Each SHALL have its own timer, frozen outside combat and while the ship is away, and an effect composed of: a score scale, a pickup magnet radius, a player fire-interval scale, and regular powers collected with it. Bonus-only powerups SHALL NOT exclude or replace regular powers.

#### Scenario: Collect
- **WHEN** the ship collects a bonus-only powerup
- **THEN** its timer starts, its effect applies, and the active regular powers continue unchanged

#### Scenario: Leaves with the level
- **WHEN** the run flies on to the next sector
- **THEN** no bonus-only powerup is active

### Requirement: Bonus level waves and crates
A bonus level SHALL define its waves as changes to the replaced sector's calibrated ones: the number of waves, a roster scale, a reinforcement scale, whether sentinels and elites appear, and a cap on the species. It MAY drop parachute supply crates on a clock, bounded on screen and in total; a crate SHALL open after three hits and release its power or bonus-only powerup. On the level's last kill, crates still in the air SHALL burst open so their contents fall through the pickup grace.

#### Scenario: No sentinel
- **WHEN** a bonus level forbids sentinels and replaces a sector that would bring one
- **THEN** no sentinel and no sentinel silhouette appears in it

#### Scenario: Crates bounded
- **WHEN** crates are never shot
- **THEN** no more than the level's on-screen limit are in the air and no more than its total are dropped

### Requirement: Supply Run
The Supply Run bonus level SHALL play two waves of scavengers at 60 % of the sector's roster with half its reinforcements, without sentinels or elites and with only the two lightest species. Kills SHALL drop no powers. Up to eight supply crates SHALL come down, at most three at once, about one every 4.5 seconds, each carrying a regular power or, about three times in ten, a bonus-only powerup.

#### Scenario: Shoot a crate open
- **WHEN** the third shot hits a crate
- **THEN** it bursts, pays its points and its pickup falls

#### Scenario: Kills drop nothing
- **WHEN** the eighth creature of the level falls
- **THEN** no power drops from it

### Requirement: Supply Run rewards
The Supply Run SHALL offer two bonus-only powerups: the salvage magnet, which for 12 seconds pulls falling pickups and heart pieces within 150 units to the ship, and double score, which for 9 seconds counts kill and crate points twice. A crate SHALL pay 150 points times the route number. The clear award SHALL be the replaced sector's par score and the flawless award a further 0.3 of it, and everything the level adds beyond kill points SHALL stay within 1.5 times that par.

#### Scenario: Salvage magnet
- **WHEN** the salvage magnet is active and a pickup falls within its reach
- **THEN** the pickup flies to the ship and is collected

#### Scenario: Double score
- **WHEN** a creature falls while double score is active
- **THEN** it pays twice its points
