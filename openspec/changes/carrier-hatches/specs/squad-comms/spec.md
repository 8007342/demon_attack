# Squad comms

## ADDED Requirements

### Requirement: Carrier radio hints
The radio SHALL teach the carrier fight with three short hint lines, one each: "Destroy the hatches!", "Time the open hatch!" and "Fire ahead of its position!". They SHALL be triggered by model events at the fight's start and the core's exposure, and when the player's shots show the mistake each hint corrects, within cooldowns. Until they are recorded, they SHALL show as written lines.

#### Scenario: Missing the hatches
- **WHEN** six of the player's shots in four seconds spark off the carrier's armour during the hatch chapter
- **THEN** "Destroy the hatches!" shows as a one-line written radio line, at most once per 20 s

#### Scenario: Shooting where the door was
- **WHEN** three shots in four seconds pass the open core door's row on its trailing side
- **THEN** "Fire ahead of its position!" shows, at most once per 25 s

### Requirement: One-line radio subtitles at a larger size
The phone radio strip's subtitle SHALL be drawn at 14.5 px, and the desktop tiles' at 15 × scale. Lines flagged one-line, the carrier hints at least, SHALL be 28 characters or fewer and SHALL be drawn on one line at full dock width. A test over `art/comms/lines.json` SHALL enforce the limit.

#### Scenario: The hint on a 360-px phone
- **WHEN** "Fire ahead of its position!" plays on a 360-px-wide phone
- **THEN** it is drawn on one line with its speaker's tag and nothing is cut off

#### Scenario: A too-long hint
- **WHEN** a flagged line longer than 28 characters is added to the bank
- **THEN** `test/comms_line_length_test.dart` fails and names the line
