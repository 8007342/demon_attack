# Arcade combat

## ADDED Requirements

### Requirement: Player volley cadence in whole model steps
The player's automatic fire SHALL volley every 18 fixed model steps (0.30 s) with the base gun and every 8 steps
(0.133 s) with Rapid, the same number of steps between every two volleys. Spread, Powerful and Large SHALL keep the
base cadence. A bonus fire power SHALL scale the step count and round it to whole steps. Hostile fire rates SHALL NOT
change with the player's cadence.

#### Scenario: A held base gun
- **WHEN** the player holds fire with no power for 2 s at 60 Hz
- **THEN** every gap between two volleys is exactly 18 steps

#### Scenario: Rapid
- **WHEN** Rapid is active
- **THEN** every gap between two volleys is exactly 8 steps, and the second volley of a Spread and Rapid pickup comes 8 steps after the first

#### Scenario: Demons keep their rate
- **WHEN** the player's cadence changes
- **THEN** the ordinary hostile fire timer, elite and sentinel volleys and the carrier's fan rate are unchanged

### Requirement: Projectile speeds on the anti-strobe grid
Player shots SHALL climb a whole number of units per model step: the primary at 480 units per second (8 per step) and
Spread's angled pair at 420 (7 per step). Every hostile shot's climb speed SHALL be rounded to a multiple of 15 units
per second where it is created. The aim, or sideways speed, is not rounded.

#### Scenario: Whole steps for the player
- **WHEN** a player shot flies for any number of steps
- **THEN** its rounded position advances by the same whole number of units every step, at 120, 60 and 30 fps

#### Scenario: No slow hitch in hostile shots
- **WHEN** any hostile shot of any kind, difficulty and route is drawn at 60 or 30 fps with positions rounded to whole units
- **THEN** its step length changes no more often than at 0, 15 or 30 Hz, never between 0 and 15 Hz

#### Scenario: A small change only
- **WHEN** a hostile shot's climb is snapped to the grid
- **THEN** it differs from the unsnapped speed by at most 7.5 units per second

### Requirement: Whole fixed steps without drift
The fixed-step accumulator SHALL take a step while it holds at least one step less 1e-9 s, and the volley timer SHALL
fire at 1e-9 s or less and never carry an overdue step into the next gap, so float drift never lengthens one step or
gap and shortens the next. Snapping jittered frame times to vsync is the scene's, not the model's.

#### Scenario: Whole-step frames
- **WHEN** the model is updated 240 times with frame times of 1/60, 1/30 and 1/120 s
- **THEN** it runs exactly 240, 480 and 120 steps

#### Scenario: The first gap
- **WHEN** the gun fires its first volley after a timer reset
- **THEN** the next volley comes a full interval later, not a step sooner

### Requirement: Rebalance for the slower gun
Because the player deals about 23 % less damage per second, a sentinel's hull SHALL be 70 % of its previous value,
rounded, dive shields SHALL be 3 + route ÷ 2 for a sentinel, 2 for an elite and 1 otherwise, and route 0 SHALL drop
a power every 5 kills. The carrier's HP SHALL keep each difficulty within its targets and Easy below Normal.

#### Scenario: Route 0 powers sooner
- **WHEN** the player kills ordinary creatures on route 0, and later on route 1
- **THEN** a power drops on every fifth kill on route 0 and on every eighth kill from route 1

#### Scenario: Sentinel hull
- **WHEN** a shield sentinel spawns on route 0, or an armoured one on route 4
- **THEN** its hull is 6, or 14

#### Scenario: Dive shields
- **WHEN** a basic creature, a heavier species, an elite and a route-2 sentinel begin a dive
- **THEN** their dive shields are 1, 1, 2 and 4

#### Scenario: The carrier stays fair
- **WHEN** the fairness harness plays the five carriers of each difficulty
- **THEN** the expert's time-to-kill and lives lost stay within the carrier-hatches target bands, and the naive pilot kills at least 90 % of Normal carriers

#### Scenario: Difficulty order on every tour
- **WHEN** the Easy and Normal carriers of the same tour are built
- **THEN** Easy's hatch pool is smaller than Normal's, and Hard's is at least Normal's

### Requirement: Loom cap scaled with the volley interval
The carrier's loom SHALL close after at most 120 s, so the slower gun still meets every launch wave before the carrier
closes.

#### Scenario: Tour 5's launch waves
- **WHEN** the protected campaign pilot plays any difficulty
- **THEN** tour 5's three launch waves all begin, and the campaign counts 123 entrances
