## MODIFIED Requirements

### Requirement: Animated victory and travel
Level completion SHALL show a four-second animated celebration and ship departure, followed by a four-second travel flyby and eased arrival into the next sector. Boss victory SHALL show carrier collapse, medal recognition and +1UP before story-led travel into the next route; the fifth victory SHALL lead to campaign completion. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends
- **THEN** victory effects and ship departure precede star-flight, a destination flyby and the next encounter entrance

#### Scenario: Fleet recognition
- **WHEN** a boss is beaten
- **THEN** its falling wreck precedes a medal and heart reward scene with fleet recognition, followed by the next destination or final ending

### Requirement: Boss endurance
Normal and Hard bosses SHALL retain baseline shield/core health of 72/24, increasing by 18/10 per route. Easy SHALL reduce each value by 20%, rounded to a positive whole hit count. Core damage SHALL remain impossible until the shield is depleted and the sliding door exposes the core.

#### Scenario: Extended shield phase
- **WHEN** the first Normal boss receives eighteen valid shield hits
- **THEN** fifty-four shield hits remain and its core is unchanged

#### Scenario: Easy endurance
- **WHEN** the first Easy boss appears
- **THEN** it has 58 shield hits and 19 core hits

## ADDED Requirements

### Requirement: Medal and life rewards
Every boss victory SHALL award exactly one medal for its ordinal victory and selected difficulty and exactly one extra life, including the fifth boss. Recognition SHALL happen once even across pauses and restored checkpoints. Final remaining lives SHALL include the fifth reward.

#### Scenario: Final medal
- **WHEN** the fifth boss is defeated
- **THEN** the run has five medals and its final lives include the fifth +1UP

### Requirement: Active campaign timer
Accumulated time SHALL count only active combat simulation. Pauses, cinematics, salvage, travel, landing and time away SHALL be excluded. Resume SHALL restore the saved wave-start accumulated time. Both partial and completed runs SHALL expose accumulated time for score display.

#### Scenario: Paused journey
- **WHEN** a player pauses or watches a cutscene
- **THEN** accumulated playing time remains unchanged
