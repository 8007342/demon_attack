# Ground front progression

## ADDED Requirements

### Requirement: Time-driven ground front
Ground activity SHALL start early in sector 1 on every difficulty and follow a schedule driven by combat time, independent of how quickly air waves are cleared. Arrivals SHALL be paced by a ground pressure meter (0–1) and capped, so a slow player never faces more than one broken-through unit firing at a time.

#### Scenario: Fast and slow players
- **WHEN** two players fight the same sector at very different air-wave speeds
- **THEN** ground units arrive at the same combat times for both, and the slower player sees more of the war but never a burst

#### Scenario: Early activity
- **WHEN** an Easy run enters Krybor
- **THEN** the first ground unit arrives within the first ten seconds of combat

### Requirement: Allies hold the early sectors
In sectors 1–2 every demon ground unit SHALL be met by an ally that destroys it before fire range. From sector 3, units SHALL be able to break through when unescorted or out-gunned: occasionally in sector 3 and regularly in sector 4, ordered by difficulty. Player help SHALL raise allied strength, so allies escort and win more often.

#### Scenario: Quiet Krybor
- **WHEN** sectors 1–2 are played on any difficulty
- **THEN** no ground unit reaches fire range and no ground missile is launched

#### Scenario: Unchecked Hollow
- **WHEN** an unescorted demon unit approaches in sector 4 and the player does not help
- **THEN** its allies call for help, then it breaks through and fires

### Requirement: Homing urgency
Homing missiles SHALL drop with high urgency (a high chance per kill, a pity timer and an airdrop) while a demon unit threatens to break through or has broken through and can still fire. Otherwise they SHALL be an ordinary pickup on a fixed kill cadence.

#### Scenario: Help in time
- **WHEN** an unescorted unit appears at the horizon and the player keeps destroying demons
- **THEN** a homing pickup drops before the unit reaches fire range
