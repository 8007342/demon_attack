# Arcade progression

## ADDED Requirements

### Requirement: The lull is the interwave recovery
When a wave's stragglers fall before the next wave has closed in, the next wave SHALL hold at the fog front for a lull of `max(0.8, 1.4 · q)` s, where q is its pacing factor, and then close in. During the lull no creature is targetable or fires, leftover hostile shots dissolve, and piloting and pickup collection continue. The first wave of each sector SHALL keep its full dramatic arrival.

#### Scenario: Clean finish
- **WHEN** the player destroys the last straggler while the next wave approaches
- **THEN** the approaching wave pauses briefly in the fog while falling pickups can still be collected, then closes in with no card or phase change

#### Scenario: First wave of a sector
- **WHEN** a sector begins
- **THEN** its first wave rises out of the fog over the full arrival introduction, as before
