# Squad comms

## ADDED Requirements

### Requirement: The radio notices the weather
The squad and the brood SHALL have short written lines when a gale rises, when the wind turns, when a demon rides a gust into a dive, when a lightning storm starts and passes, and when rain starts. Every such line SHALL be under 70 characters and family friendly, and the brood's lines SHALL relish their weather.

#### Scenario: Every weather moment has lines
- **WHEN** the comms bank is built
- **THEN** `windStart.gale`, `windGust.swing`, `windDive`, `stormStart`, `stormStop` and `rainStart` each have squad and brood lines, written (no borrowed audio)

### Requirement: Weather chatter is rate-limited
Every weather trigger SHALL belong to the `weather` rate-limit family, with at least 10 s between two squad lines of the family, on top of its own cooldown; a variant SHALL share its event's cooldown.

#### Scenario: A storm and a gale together
- **WHEN** `stormStart` arrives twice two seconds apart and a gale's `windStart` two seconds later
- **THEN** the squad speaks exactly one line, the storm's
