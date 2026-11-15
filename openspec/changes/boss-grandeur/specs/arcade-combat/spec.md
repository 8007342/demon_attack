# Arcade combat

## ADDED Requirements

### Requirement: Bounded boss glide
The boss SHALL glide vertically within 16 arena units of its fight row, deterministically for a run seed, with its force field following it. Boss endurance and survival measured by the campaign playtest SHALL stay within 5 percent of the values before this change.

#### Scenario: Glide bounds
- **WHEN** a boss fight runs for its full length
- **THEN** the boss's row never leaves the band of 16 units around its fight row

### Requirement: Composable boss ships
Each tour SHALL field a larger and more complex boss assembled from a spine and modules (for example 5, 8, 11, 14 and 17 modules on tours one to five), and repeat cycles beyond the fifth tour SHALL assemble seeded variants within the same budgets. Every assembly SHALL share the same core, bay, turret and solid-body geometry, and modules SHALL NOT change health, shield or fire budgets.

#### Scenario: Later tour
- **WHEN** the fourth tour reaches its boss
- **THEN** the boss is visibly larger and carries more modules than the third tour's, while its hit areas and endurance follow the same rules
