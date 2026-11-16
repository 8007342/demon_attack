# Arcade combat

## ADDED Requirements

### Requirement: Carrier gate launches
The carrier SHALL release creatures only through its gates. In the approach its launch waves SHALL come out of its gates in volleys; in the fight its minion flocks SHALL come out of the gates that are on-screen at the carrier's current position.

#### Scenario: Fight flock
- **WHEN** the carrier releases a minion flock during the fight
- **THEN** the creatures come out of one of its gates that is on the screen

### Requirement: Carrier gate telegraph
Each volley SHALL be preceded by a telegraph of at least one second during which nothing leaves the gate, and a gate outside the arena SHALL NOT launch.

#### Scenario: Telegraph before release
- **WHEN** a gate is about to launch
- **THEN** its telegraph runs for at least one second before the first creature leaves it

### Requirement: Deterministic and calibrated carrier launches
Launch timing and gate choice SHALL be deterministic for a run seed, the fight's flock spawn moments SHALL stay as they were, and boss endurance, survival and the boss level's clear time measured by the campaign playtest SHALL stay within the boss-grandeur calibration gates.

#### Scenario: Same seed
- **WHEN** a boss level is replayed with the same seed and the same inputs
- **THEN** every volley leaves the same gates at the same times

### Requirement: Carrier hittable threshold
The carrier SHALL have no hitbox and SHALL NOT fire while it approaches. It SHALL become hittable and start its fight only when it has closed to its fight distance, and its shield SHALL start full at that moment.

#### Scenario: Shots during the approach
- **WHEN** a player shot crosses the approaching carrier's image
- **THEN** it does not damage the carrier or its shield and flies on

#### Scenario: In range
- **WHEN** the carrier closes to its fight distance
- **THEN** it becomes hittable and its fight begins

### Requirement: Carrier shield intercept unchanged
Redrawing the carrier's force field SHALL NOT change where player shots are stopped by the shield: the gameplay surface SHALL keep its width, its depth and its tightening as the shield wears.

#### Scenario: Field redraw equivalence
- **WHEN** a scripted carrier fight is replayed before and after the force-field redraw
- **THEN** every shield hit happens at the same place and time

### Requirement: Carrier approach and launch events
The carrier's approach and launches SHALL be emitted into the game event queue as named events carrying the run's tour and set combination: the approach start and each step closer (`bossApproach`), and each gate's telegraph, opening, launch and closing (`bossGateTelegraph`, `bossGateOpen`, `bossLaunch`, `bossGateClose`).

#### Scenario: A launch wave
- **WHEN** a gate launches a volley during the approach
- **THEN** the queue carries `bossGateTelegraph`, `bossGateOpen`, `bossLaunch` with the gate and the count, and `bossGateClose`, in that order

### Requirement: Carrier take-off events
The hittable threshold (`bossInRange`), the take-off (`bossTakeoff`) and the top of the climb (`bossClimbPeak`) SHALL be emitted into the game event queue, in that order.

#### Scenario: Into the fight
- **WHEN** the carrier comes in range
- **THEN** the queue carries `bossInRange`, then `bossTakeoff`, then `bossClimbPeak` when the climb reaches its altitude

### Requirement: Throttled carrier presentation events
Field impacts (`bossFieldImpact`) SHALL be emitted at most four times per second, and speed surges (`bossSpeedSurge`) and cloud punches (`bossCloudPunch`) SHALL be emitted as presentation events that never change the simulation.

#### Scenario: Rapid fire on the field
- **WHEN** the player's shots hit the field ten times in one second
- **THEN** at most four `bossFieldImpact` events are queued for that second
