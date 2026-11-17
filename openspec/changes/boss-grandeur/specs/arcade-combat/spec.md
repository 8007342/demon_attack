# Arcade combat

## ADDED Requirements

### Requirement: Bounded boss glide
The boss SHALL glide vertically within 16 arena units of its fight row, deterministically for a run seed, with its force field following it. Boss endurance and survival measured by the campaign playtest SHALL stay within 5 percent of the values before this change.

#### Scenario: Glide bounds
- **WHEN** a boss fight runs for its full length
- **THEN** the boss's row never leaves the band of 16 units around its fight row

### Requirement: Composable boss ships
Each tour SHALL field a larger and more complex boss assembled from a carapace, a prow and modules (9, 13, 17, 21 and 24 module instances on tours one to five), and repeat cycles beyond the fifth tour SHALL draw seeded picks among the largest baked hulls within the same budgets. Every assembly SHALL share the same core, bay, turret and solid-body geometry, and modules SHALL NOT change health, shield or fire budgets.

#### Scenario: Later tour
- **WHEN** the fourth tour reaches its boss
- **THEN** the boss is visibly larger and carries more modules than the third tour's, while its hit areas and endurance follow the same rules

### Requirement: Boss decay events
Every step of the boss's decay SHALL be emitted into the game event queue as a named event, once per step and per module, in the fixed order shield, armour, modules, collapse: its rise, each shield cell, the shield at half, the shield down, armour shed, each module lost, the core exposed, and the collapse with each falling wreck and its end. The names SHALL be the styleguide's decay vocabulary, and every event SHALL carry the run's set combination.

#### Scenario: Shield worn down
- **WHEN** the player's shots wear the boss's shield from full to nothing
- **THEN** twelve shield-cell events, one shield-failing event at half and one shield-down event are queued, in order

#### Scenario: Names
- **WHEN** a carrier is fought from full shield to its collapse
- **THEN** the queue carries `bossShieldCellLost`, `bossShieldFailing`, `bossShieldDown`, `bossArmourShed`, `bossModuleLost`, `bossCoreExposed`, `bossCollapseStart`, `bossWreckFalls` (the carapace last) and, when the victory rout ends, `bossCollapseEnd`

#### Scenario: Module torn away
- **WHEN** the boss's core damage moves it into its next form
- **THEN** a module-lost event names the slot that broke away, after the armour-shed event for that slot
