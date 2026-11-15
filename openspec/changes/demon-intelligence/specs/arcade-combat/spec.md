# Arcade combat

## MODIFIED Requirements

### Requirement: Demon swarms and transformations
Four levels SHALL introduce faster organic swarms, home-tethered Boids separation/cohesion with incoming-shot lateral evasion, telegraphed predatory dives, and armored demons that visibly weaken after hits; advanced enemies SHALL enter angry final forms. Evasion SHALL be tiered by creature: small creatures use the offline JEV action prior (`SwarmPolicy`); not-so-small creatures use it with an energy-planner veto; elites (hunters) and sentinels use the deterministic energy planner over exact kinematics against every visible player shot.

#### Scenario: Armored demon
- **WHEN** a multi-hit demon takes a nonlethal hit
- **THEN** its form changes and its remaining final form can attack more aggressively

#### Scenario: Hunter dodges what a drone cannot
- **WHEN** a straight player shot is fired at an elite and at a small creature in the same position
- **THEN** the elite sidesteps out of its path while the small creature behaves as before this change

## ADDED Requirements

### Requirement: Enemy intelligence tiers
Creatures SHALL be classed into four tiers by what they already are: drones (small), skirmishers (not-so-small), hunters (elites) and sentinels. Tiers SHALL differ only in decision-making: perception delay, foresight, choice temperature, candidate moves and dodge cooldown. HP, birth counts, fire rates and elite budgets SHALL be unchanged.

#### Scenario: Route 0
- **WHEN** a first-tour campaign is played
- **THEN** no hunters appear (the elite budget is zero), and drone and skirmisher behaviour matches the calibrated baseline

### Requirement: Evasion stays bounded and deterministic
Only one drone or skirmisher and one hunter MAY be evading at a time. Decisions SHALL be deterministic for a run seed and SHALL NOT change the run's other random draws.

#### Scenario: Replayed wave
- **WHEN** the same wave is replayed with the same seed and inputs
- **THEN** every creature makes the same evasion choices at the same moments

### Requirement: Hunters dive between player fire
A hunter's dive SHALL keep its aim point fixed from the start of its tell. On the way down it SHALL weave through gaps in the player's shot stream, re-planning ten times a second, with lateral speed and acceleration bounded and never more than 60 units from its straight dive line. It SHALL NOT track the ship.

#### Scenario: Threading a stream
- **WHEN** a hunter dives into a player shot stream with shots 88 units apart
- **THEN** it passes between two shots that would have hit a straight dive, and still arrives at its original aim point

### Requirement: The brood reacts to skilful play within bounds
A skill level SHALL be derived from the player's accuracy, clear tempo and near-miss dodges. It SHALL be capped per difficulty (Easy 0.5, Normal 0.8, Hard 1.0), SHALL drop by at least 0.35 on a lost life, and SHALL NOT be raised by score, power-ups or time survived. It SHALL NOT change HP, births, the concurrent dive cap, the bullet cap or fire intervals.

#### Scenario: After a death
- **WHEN** the player loses a life
- **THEN** the skill level drops by at least 0.35 and does not rise again for ten seconds

### Requirement: Skill sharpens hunters
A higher skill level SHALL make hunters react sooner and see further, aim their dives at the forecast of the player's next position, and allow pincer dives by two hunters, each with its own tell. The brood SHALL remark once per sector when it starts adapting.

#### Scenario: Pincer
- **WHEN** two hunters are ready and the skill level is high
- **THEN** both show a dive tell and aim either side of the player's forecast position

#### Scenario: Skilled player
- **WHEN** a Normal player keeps high accuracy and clears waves quickly on route 1
- **THEN** hunters dodge more often and two hunters may dive either side of where the player is heading, each with its own warning, while the number of simultaneous divers stays within the cap

### Requirement: Sentinel final rush
A sentinel SHALL be eligible for a final rush with probability 0.20 / 0.35 / 0.45 (Easy / Normal / Hard), plus up to 0.10 with skill. The rush SHALL trigger at or below a quarter of its hull, or when it is left alone below half hull.

#### Scenario: Low hull
- **WHEN** an eligible sentinel drops to a quarter of its hull
- **THEN** it begins its final rush

### Requirement: Rush passes are fast but escapable
Each rush pass SHALL rally and lock on for at least 1.0 s of real time, then rush at 640 / 780 / 880 units per second at the forecast of the player's position. It SHALL home at no more than 0 / 50 / 75 degrees per second, and never more than 0 / 14 / 16 degrees from its locked aim, until it nears the ship's row, then commit. A missed rush SHALL come around through the fog for up to 1 / 2 / 3 passes in total, then sacrifice itself off screen without reward.

#### Scenario: A dodging pilot escapes
- **WHEN** the ship starts moving away from the locked aim as the rush begins
- **THEN** the rush misses on at least 99 % of passes across seeds

#### Scenario: A stationary pilot is caught
- **WHEN** the ship stays at the locked aim
- **THEN** the rush hits on at least 90 % of passes

### Requirement: Rush shield
A rushing sentinel SHALL raise its own rush shield of 3 / 4 + cycle÷2 / 5 + cycle÷2 (Easy / Normal / Hard), separate from its dive shield. Every player hit SHALL damage the rush shield, with offensive powers and homing hits adding breaker damage. While the rush shield holds, the hull SHALL take no damage. Breaking it during a rush SHALL stagger the sentinel and award a bonus.

#### Scenario: Breaking the rush shield
- **WHEN** a player with only the base gun lands four hits on a Normal route-1 sentinel during its rush
- **THEN** the rush shield breaks, the sentinel staggers and slows, and its hull takes damage again

### Requirement: Sentinel rush radio chatter
The rush SHALL have its own radio: an urgent squad warning that ends as the rush starts, a brood war cry on lock, a warning when it comes around again, a call when the rush shield breaks, relief after surviving, and a brood reaction to a miss.

#### Scenario: Rush warning
- **WHEN** a sentinel locks on
- **THEN** a squad member warns the pilot and the brood shouts a war cry before it charges

### Requirement: Unrecorded lines use truthful placeholders
Lines not yet recorded SHALL play an existing clip whose subtitle is that clip's own text, so audio and subtitles always agree. A line with no truthful existing clip SHALL stay silent until recorded. Pending lines SHALL be listed for the next voice recording batch.

#### Scenario: Before the voice batch
- **WHEN** a sentinel rush starts before the new lines are recorded
- **THEN** the squad warning plays an existing sentinel-dive clip with that clip's own subtitle, ending as the sentinel starts its rush
