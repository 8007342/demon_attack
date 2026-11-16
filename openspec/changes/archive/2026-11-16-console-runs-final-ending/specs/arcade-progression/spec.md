# Final ending and console runs

## ADDED Requirements

### Requirement: Ending after the fifth carrier
The beach ending and credits SHALL open only in the victory over the campaign's last carrier: sector 5 of the fifth route. Victories over the first four carriers SHALL play their normal victory scene and travel into sector 1 of the next route, with no ending. A resumed run SHALL still earn the ending at the fifth carrier. The title's ending replay SHALL be offered only after the fifth carrier has fallen at least once.

#### Scenario: Earlier carriers
- **WHEN** the carrier of route 1, 2, 3 or 4 is destroyed
- **THEN** no ending opens, and the run travels to sector 1 of the next route

#### Scenario: Fifth carrier
- **WHEN** the carrier of route 5 is destroyed
- **THEN** the ending opens during the victory scene, and closing it leads to the completed result and score entry with the score, lives and medals unchanged

#### Scenario: Resumed final route
- **WHEN** a saved run on route 5 is resumed and its carrier destroyed
- **THEN** the ending opens

### Requirement: Console runs
A console run SHALL begin at the chosen sector 1–5 (the carrier included), route 1–5 and difficulty, with exactly one life and 0 points, with earlier routes counted as won. It SHALL be unranked: it SHALL NOT save or clear the player's checkpoint or change the unlock history, and the HUD SHALL show a `CONSOLE RUN · NOT RANKED` tag. A normal start or a resumed save SHALL be ranked.

#### Scenario: Carrier jump
- **WHEN** the console starts the carrier of route 5 on Hard
- **THEN** the run is at sector 5, route 5, with one life, 0 points and the unranked tag

#### Scenario: Saved run untouched
- **WHEN** a console run reaches new waves and ends
- **THEN** the stored checkpoint and unlock history are as they were before it
