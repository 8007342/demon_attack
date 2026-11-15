# Arcade progression

## ADDED Requirements

### Requirement: Seeded run plan
A run MAY start with a run seed. The run's plan (its bonus level and its run modifier, if any) SHALL be a pure function of that seed, the plan's tuning and the catalogues, drawn with a random stream of its own. With the standard tuning about 85 % of seeded runs SHALL have exactly one bonus level and none SHALL have more. The odds SHALL be tunable in one place: the chance of a bonus level, each route's weight, the eligible sectors and the scale of the modifier chances.

#### Scenario: Same seed, same plan
- **WHEN** two runs start with the same run seed and the same tuning
- **THEN** they have the same bonus level in the same route and sector and the same run modifier

#### Scenario: About once per run
- **WHEN** many runs start with different run seeds
- **THEN** about 85 in 100 have one bonus level, none has two, and the others have none

#### Scenario: Catalogue growth
- **WHEN** a bonus level is appended to the catalogue
- **THEN** every earlier run seed still places its bonus level in the same route and sector

### Requirement: A bonus level replaces one regular sector
A bonus level SHALL take the place of one regular sector of the run: sector 2, 3 or 4 of a route, never the opening sector of the first route, never a carrier sector and never a sector of the final route. Early routes SHALL be more likely than later ones. The run SHALL keep its sector count: the bonus level counts as the sector it replaces for the route, the medals, the checkpoint and the next sector.

#### Scenario: Replacement
- **WHEN** a run's plan holds a bonus level for sector 3 of the first route
- **THEN** after sector 2 the run plays the bonus level, and after it sector 4

#### Scenario: Protected sectors
- **WHEN** plans are drawn for any run seeds
- **THEN** none places a bonus level in sector 1, in a carrier sector or on the fifth route

### Requirement: The campaign is unchanged without a plan
A run that starts without a run seed SHALL have no bonus level and no run modifier, and SHALL play the calibrated campaign exactly: no bonus-level rule SHALL draw from the simulation's random stream or change any roster, drop, score or timing. A seeded run SHALL be identical to the unseeded run up to the first sector its plan touches. Automated tests and calibration tools SHALL start unseeded runs unless they ask for a seed.

#### Scenario: Unseeded run
- **WHEN** a run starts without a run seed
- **THEN** every sector is regular and every power drop follows the regular cycle

#### Scenario: Seeded run before its bonus level
- **WHEN** a seeded run without a run modifier is compared with the unseeded run through the sectors before its bonus level
- **THEN** score, kills, lives, creatures and pickups match at every second

#### Scenario: Deterministic bonus run
- **WHEN** the same run seed plays the same inputs twice
- **THEN** both runs match through the bonus level, including its crates and their contents

### Requirement: Bonus level scoring
Inside a bonus level, kills SHALL score as in the replaced sector times the level's scale. The level MAY add crate points, a clear award on its last kill and a further flawless award when no ship was lost in it. Everything it adds beyond ordinary kill points SHALL count against one cap per level. Awards and cap MAY be shares of the replaced sector's par score. Lives, heart pieces, medals and active time SHALL work as in any sector.

#### Scenario: Clear award
- **WHEN** the last creature of a bonus level falls and no ship was lost in it
- **THEN** the clear award and the flawless award are added to the score

#### Scenario: Ship lost
- **WHEN** a ship was lost during the bonus level
- **THEN** only the clear award is added

#### Scenario: Cap
- **WHEN** crate points, score-scale powers and awards together exceed the level's cap
- **THEN** the score gains exactly the cap beyond ordinary kill points

### Requirement: Bonus runs resume
The saved checkpoint SHALL carry the run seed. Resuming SHALL restore the same plan, so a run saved inside a bonus level resumes that level's saved wave and a run saved before it still reaches it. A checkpoint without a run seed SHALL resume a run without a plan.

#### Scenario: Resume inside a bonus level
- **WHEN** a run is resumed from a checkpoint taken in its bonus level
- **THEN** the bonus level's saved wave restarts with the level's rules

#### Scenario: Older checkpoint
- **WHEN** a checkpoint saved before this change is resumed
- **THEN** the run continues as the regular campaign
