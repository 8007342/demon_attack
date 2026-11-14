# Console runs and the board

## ADDED Requirements

### Requirement: Console runs are not ranked
The game SHALL NOT submit a console run's result to `/api/scores` and SHALL NOT open the initials entry for it, whatever its score. Its final score SHALL be shown beside the board, tagged `CONSOLE RUN · NOT RANKED`.

#### Scenario: High console score
- **WHEN** a console run ends with a score that would enter an empty or low board
- **THEN** no initials entry opens, no POST is sent, and the result shows with the unranked tag
