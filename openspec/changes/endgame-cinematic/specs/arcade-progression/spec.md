# arcade-progression

## MODIFIED Requirements

### Requirement: Ending after the fifth carrier
The end-game cinematic and credits SHALL open only in the victory over the campaign's last carrier: sector 5 of the fifth route. Victories over the first four carriers SHALL play their normal victory scene and travel into sector 1 of the next route, with no ending. A resumed run SHALL still earn the ending at the fifth carrier. The ending replay SHALL be offered on the title and on the medal screen only after the fifth carrier has fallen at least once.

#### Scenario: Earlier carriers
- **WHEN** the carrier of route 1, 2, 3 or 4 is destroyed
- **THEN** no ending opens, and the run travels to sector 1 of the next route

#### Scenario: Fifth carrier
- **WHEN** the carrier of route 5 is destroyed
- **THEN** the end-game cinematic opens during the victory scene, the credits follow it, and closing them leads to the completed result and score entry with the score, lives and medals unchanged

#### Scenario: Resumed final route
- **WHEN** a saved run on route 5 is resumed and its carrier destroyed
- **THEN** the end-game cinematic opens

#### Scenario: Replay from the medal screen
- **WHEN** the fifth carrier has fallen at least once and the player opens the medal screen
- **THEN** a replay control opens the cinematic and its credits, and closing them returns to the medal screen with nothing in the run or the saved record changed

#### Scenario: No replay before the first completion
- **WHEN** the fifth carrier has never fallen on this device
- **THEN** neither the title nor the medal screen shows the replay control or names the cinematic
