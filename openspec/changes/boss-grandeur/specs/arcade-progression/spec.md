# Arcade progression

## ADDED Requirements

### Requirement: Boss level opens with loom waves
The boss level SHALL open with ordinary waves (one on the first tour, two from the second tour) while the boss looms under the fog as a dark, slowly rising mass that cannot be hit and does not fire. The loom SHALL end when its waves are cleared or after 75 seconds.

#### Scenario: Tour one boss level
- **WHEN** the first tour reaches its boss sector
- **THEN** one ordinary wave is fought while the boss looms under the fog, and only then does the boss rise to the front

### Requirement: Boss emerges from under the fog
The boss SHALL first fly in from behind the player and sink into the far fog during the arrival, and after the loom SHALL emerge slowly from under the fog over four to six seconds. It SHALL become hittable and start firing only once fully emerged, and no stragglers from the loom waves SHALL remain visible in the fog.

#### Scenario: Rise
- **WHEN** the last loom wave is cleared
- **THEN** the boss rises out of the fog nose first, sheds the fog, and the fight begins only when it is fully out
