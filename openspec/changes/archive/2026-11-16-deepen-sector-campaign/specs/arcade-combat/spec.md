# arcade-combat updates

## MODIFIED Requirements

### Requirement: Repeat cycles
Defeating each carrier SHALL continue the same run at LV1 with retained score, lives, powers and kill count. Later cycles SHALL increase speed, waves, roster size, species variety and multi-molt elites with stronger telegraphed attacks. Speed, waves and density SHALL have safe upper bounds.

#### Scenario: Victory
- **WHEN** the boss core is destroyed
- **THEN** the next cycle starts at level one with the score and remaining lives retained

#### Scenario: Two carrier victories
- **WHEN** the player defeats two carriers in one run
- **THEN** each return to LV1 retains the run and adds complexity compared with the preceding cycle

#### Scenario: Advanced elites
- **WHEN** an elite appears in later cycles
- **THEN** its extended damage forms are visible and its attacks are stronger but telegraphed
