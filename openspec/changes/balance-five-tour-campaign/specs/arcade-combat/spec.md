## MODIFIED Requirements

### Requirement: Lives and pause
Easy SHALL start with five lives; Normal and Hard SHALL start with three. A single unprotected hit SHALL remove one life, grant brief respawn protection, and end the run at zero. Pause and backgrounding SHALL freeze combat.

#### Scenario: Lethal hit
- **WHEN** an unprotected ship is hit with one life remaining
- **THEN** combat ends and the final score is shown

#### Scenario: Easy start
- **WHEN** an Easy run starts
- **THEN** the player has five lives

### Requirement: Repeat cycles
Each of the first four carrier victories SHALL continue the same run at the first sector, retaining score, lives, powers and kill count and adding its medal and +1UP. The fifth SHALL finish the campaign. Later routes SHALL increase bounded speed, waves, roster size, species variety and multi-molt elites with stronger telegraphed attacks.

#### Scenario: Victory
- **WHEN** the first boss core is destroyed
- **THEN** the next route starts at the first sector with retained score and lives plus the boss reward

#### Scenario: Two carrier victories
- **WHEN** the player defeats two carriers in one run
- **THEN** both returns retain the run and add complexity compared with the preceding route

#### Scenario: Advanced elites
- **WHEN** an elite appears in later routes
- **THEN** extended damage forms remain visible and stronger attacks are telegraphed

#### Scenario: Final victory
- **WHEN** the fifth carrier is defeated
- **THEN** the campaign finishes without a sixth route

## ADDED Requirements

### Requirement: Difficulty balance
Easy SHALL reduce enemy movement and attack cadence by 10% and boss shield/core health by 20% relative to Normal, without slowing player controls or fire. Enemy point awards SHALL be lower in Easy than Normal. Comparable waves SHALL have Easy fewer enemies than Normal and Hard more than Normal. From the second route, density growth SHALL be substantially greater in Normal/Hard than Easy.

#### Scenario: Mode comparison
- **WHEN** the same route and wave are started in all modes
- **THEN** roster counts increase from Easy to Normal to Hard and Easy enemies award fewer points

### Requirement: Complementary heart collection
Easy and Normal enemies SHALL rarely drop complementary left/right/top heart pieces, more often in Easy. Rates SHALL be substantially below the initial 4%/3% per-kill tuning. Three slots SHALL each accept one of each part; pickups fill the earliest eligible slot and excess copies are ignored. Completing a heart SHALL immediately grant one life, free its slot, and show a completed-heart/+1UP cue independently of the cleared slot. Shapes SHALL show filled and missing regions of one heart.

#### Scenario: Repeated left pieces
- **WHEN** three left pieces are collected with empty slots
- **THEN** each slot holds a left piece and further left pieces are ignored until a slot completes

#### Scenario: Completed heart
- **WHEN** a slot containing left and right collects a top
- **THEN** exactly one life is granted, a completed-heart and +1UP cue is visible, and that slot becomes available again

#### Scenario: Dense waves
- **WHEN** a later-route wave contains more enemies
- **THEN** heart pieces remain occasional rewards rather than a repeated stream of life pickups

#### Scenario: Hard life economy
- **WHEN** a Hard enemy dies
- **THEN** it cannot drop a heart piece and boss victories remain the only extra-life source

### Requirement: Rare winged threats
Scarce large enemies SHALL use original broad horizontal pixel silhouettes, segmented wings, shields and armor, withstand several hits and survive repeated dives if undamaged. They SHALL require a boss victory in the current campaign and use final-wave refresh entrances initially; stronger modes may add later-wave entrances after that gate. Later routes SHALL introduce distinct enemy types. Large threats SHALL have a distinct pixel-frame defeat animation.

#### Scenario: Special entrance
- **WHEN** an eligible final-wave refresh introduces a large threat
- **THEN** a small ordinary swarm arrives first, the threat enters slowly from above, and its segmented wings, defenses and extended hover above the swarm distinguish it before a sprite warning and fast dive

#### Scenario: First campaign route
- **WHEN** the current campaign has no boss victories, even if the device has unlocked Hard
- **THEN** no large winged threat appears

#### Scenario: Hover before diving
- **WHEN** a large winged threat has finished its slow entrance
- **THEN** it remains above all ordinary enemies with very slow stepped wing poses until its visible sprite warning precedes the fast dive

#### Scenario: Special defeat
- **WHEN** a large enemy is destroyed by player fire
- **THEN** it plays its own defeat animation and awards its score once

### Requirement: Staged sentinel arrival and attack
An eligible wave SHALL introduce a small ordinary swarm before a large threat. The threat SHALL enter slowly from above the arena, then hover above every ordinary enemy for an extended interval with very slow discrete segmented-wing poses. A sprite-style warning SHALL precede its heavy fast dive; arrow warnings SHALL NOT be used.

#### Scenario: Swarm before sentinel
- **WHEN** an eligible special wave starts
- **THEN** the small swarm enters before the sentinel's slow descent, high hover, warning and fast dive occur in that order

### Requirement: Rare sentinel sacrifice rush
A minority of sentinels SHALL be eligible once for a sacrifice rush at 25% health or below. It SHALL lock aim at the start of a distinct movement tell, then rush on a straight path without retargeting. Normal/Hard SHALL use 0.9s/600 units/s; Easy 1s/540 units/s. Impact or escape SHALL destroy it without kill rewards. Player fire SHALL interrupt either phase and grant normal kill rewards.

#### Scenario: Dodge after the tell
- **WHEN** the player moves aside after an injured eligible sentinel begins its tell
- **THEN** the sentinel rushes toward the earlier sampled position and does not steer toward the player's new position

#### Scenario: Irreversible sacrifice
- **WHEN** the rush misses the player and reaches the arena boundary
- **THEN** the sentinel destroys itself instead of returning to formation, with no score, kill count or pickup awarded

#### Scenario: Shoot down the attacker
- **WHEN** player fire destroys the sentinel during the tell or rush
- **THEN** its normal defeat rewards are granted exactly once and it cannot subsequently deal collision damage

#### Scenario: Rare eligibility
- **WHEN** an ineligible or healthier sentinel is updated repeatedly
- **THEN** it retains normal behavior without repeated chance rolls that would eventually force a sacrifice rush
