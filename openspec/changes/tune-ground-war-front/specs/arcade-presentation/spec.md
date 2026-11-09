# Ground front presentation

## ADDED Requirements

### Requirement: Urgency signals
The model SHALL expose a ground pressure level (0–1) and emit `groundPressure` when it crosses each tenth. Allies SHALL call for help (`allyUnderAttack`, with a visible cyan beacon) before a predicted breakthrough, never during skirmishes they are winning. All ground-war events SHALL go through the shared game-event queue.

#### Scenario: Call before breakthrough
- **WHEN** a demon unit is predicted to reach fire range
- **THEN** `allyUnderAttack` fires and the beacon shows before `groundBreakthrough`

#### Scenario: Quiet skirmish
- **WHEN** allies are winning a skirmish in sector 1 or 2
- **THEN** no call for help or beacon appears, while `groundForceSighted` and `groundUnitDestroyed` still report the activity
