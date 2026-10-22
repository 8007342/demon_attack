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
Only Easy and Normal enemies SHALL rarely drop left, right or top heart pieces, more often in Easy. Three unfinished heart slots SHALL each accept one of each part. A pickup SHALL fill the earliest slot missing that part; excess copies SHALL be ignored. A completed heart SHALL immediately award one life and free its slot. Shapes SHALL assemble visibly into a heart.

#### Scenario: Repeated left pieces
- **WHEN** three left pieces are collected with empty slots
- **THEN** each slot holds a left piece and further left pieces are ignored until a slot completes

#### Scenario: Completed heart
- **WHEN** a slot containing left and right collects a top
- **THEN** exactly one life is granted and that slot becomes available again

#### Scenario: Hard life economy
- **WHEN** a Hard enemy dies
- **THEN** it cannot drop a heart piece and boss victories remain the only extra-life source

### Requirement: Rare winged threats
Scarce large enemies SHALL use original horizontal-line, broad-wing silhouettes, shields and armor even at their weakest tier, withstand several player hits and survive repeated dives if undamaged. They SHALL appear only at final-wave refresh entrances initially, and additionally in later waves of stronger modes. Later routes SHALL introduce additional distinct enemy types. Large threats SHALL have a distinct defeat animation.

#### Scenario: Special entrance
- **WHEN** an eligible final-wave refresh introduces a large threat
- **THEN** its silhouette, defenses and telegraphed dives distinguish it from ordinary demons

#### Scenario: Special defeat
- **WHEN** a large enemy is destroyed
- **THEN** it plays its own defeat animation and awards its score once
