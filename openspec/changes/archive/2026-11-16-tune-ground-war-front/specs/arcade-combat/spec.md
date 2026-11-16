# Ground front combat

## ADDED Requirements

### Requirement: Allied fire
Allied ground units SHALL damage the demon unit they are fighting; a demon unit reduced to zero SHALL be destroyed without player score. Allies SHALL still never collide with the player, block shots or die.

#### Scenario: Allies win a skirmish
- **WHEN** an escorted demon unit loses its last hit points to allied fire
- **THEN** it is destroyed, a `groundUnitDestroyed` event with `by: allies` fires, and allied strength rises

### Requirement: Breakthrough
A demon unit that reaches fire range alive SHALL be a breakthrough: a `groundBreakthrough` event fires, and only then may it telegraph and fire ground missiles.

#### Scenario: Breakthrough fires
- **WHEN** a demon unit reaches fire range in sector 3 or 4
- **THEN** `groundBreakthrough` fires before its first telegraph
