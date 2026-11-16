## MODIFIED Requirements

### Requirement: Construction identity
The landing page SHALL show the Demon Attack identity, a Normal start action and inline Top10. Easy and Hard start actions and matching board tabs SHALL appear only when unlocked. A valid interrupted checkpoint SHALL expose Resume Game, using its saved difficulty independently of current board selection.

#### Scenario: Viewing the landing page
- **WHEN** a new visitor opens the page
- **THEN** the original demon logo, title, Normal start and Normal board are visible

#### Scenario: Resume selection
- **WHEN** a player selects Resume Game while another board is selected
- **THEN** the checkpoint resumes in its original difficulty
