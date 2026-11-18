# Arcade combat

## ADDED Requirements

### Requirement: Seeded lightning storms in regular sectors
A seeded run SHALL choose each regular level's storm from the run seed, the route and the sector alone. Only a level that rains at the rain or downpour tier MAY storm, so lightning is rarer than rain and about as rare as wind. The run's first sector, the carrier's sector, bonus levels and unseeded runs SHALL never storm, so every calibration gate runs without lightning.

#### Scenario: Frequency
- **WHEN** the plans of 2000 run seeds over three routes and sectors 1 to 4 (route 0 sector 1 excluded) are drawn
- **THEN** between 12 % and 16 % of the levels storm, every stormy level rains at the rain or downpour tier, fewer levels storm than rain, and the storm share is within 8 points of the wind share

#### Scenario: Unseeded run
- **WHEN** a run starts without a run seed
- **THEN** no level storms and no `stormStart` event is sent

### Requirement: Regular storms strike rarely and by the lightning rule
A stormy level's bolts SHALL fall only while its rain is heavy, at least 6.5 s apart after each bolt (divided by the hostile rate), each told for at least 1.25 s and never forked. A bolt SHALL stun, zap and be dodged exactly as in the storm-lightning rule: it never costs a life.

#### Scenario: Two minutes of a downpour storm at Normal
- **WHEN** a downpour storm runs for two minutes of combat
- **THEN** 9 to 16 bolts fall, never two within 5 s, `stormStart` is sent once, and creatures in a bolt's column are stunned

#### Scenario: Rain that builds mid-level
- **WHEN** a stormy level's rain is still light
- **THEN** no tell starts until its planned intensity reaches 0.4

### Requirement: Smart demons ride the wind into a dive
In a wind, a creature that reads the wind (veterans, hunters and sentinels; skirmishers from the third tour) SHALL hold a picked dive at most 2.4 s until the dive would start in a tailwind toward the ship, then let the wind carry it in a curve onto an aim set upwind of the ship; facing only a headwind it MAY let the pick go. Drones SHALL dive when picked. The choice SHALL be deterministic and draw nothing from the run's random stream.

#### Scenario: Smart against grunt timing
- **WHEN** a gale blows over sector 3 of the third tour for 90 s on six seeds
- **THEN** the share of smart creatures' dives that start in a tailwind of at least 0.45 toward the ship is at least 15 points above the drones' share

#### Scenario: Calm air
- **WHEN** there is no wind
- **THEN** every picked dive is prepared at once, no creature holds a dive and no dive is a ride

#### Scenario: Bounded wait
- **WHEN** a smart creature is picked to dive at any moment of a windy level
- **THEN** it waits between 0 and 2.4 s or lets the pick go, and a stun or a regroup ends the wait
