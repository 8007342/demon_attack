# Arcade progression

## MODIFIED Requirements

### Requirement: Animated victory and travel
Level completion SHALL play as swarm beats on one transition clock: a rout of about two seconds (the pickup grace) in which the remaining brood scatters into the fog, a pursuit of about six seconds in which the ship climbs into the clouds after the fleeing flock while the sector changes inside the cloud, and a descent into the next sector in which that flock becomes the next sector's first wave. Boss victory SHALL celebrate for 5.5 seconds before the pursuit into the next cycle. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends
- **THEN** the brood flees into the fog, the ship chases it up into the clouds, and the same flock comes out of the clouds in the next sector as its first wave

## ADDED Requirements

### Requirement: Transitions never cut to black
No transition, outro or game-over frame SHALL be an opaque full-screen wipe or darker than the sector's night floor. A scene change SHALL happen only while the cloud cover is at least 85 %, and the swarm's direction of travel and the ship's screen position SHALL be preserved across it.

#### Scenario: Palette swap
- **WHEN** the sector changes during a pursuit
- **THEN** the swap happens inside bright cloud, and the flock keeps flying in the same screen direction afterwards

### Requirement: Transitions are skippable and respect reduced motion
A tap, Space or Enter during a sector transition SHALL jump to the descent within one frame, without shortening the pickup grace. With reduced motion, transitions SHALL play the same beats as crossfades without camera tilt or shake.

#### Scenario: Skipping
- **WHEN** the player taps during a pursuit
- **THEN** the ship begins its descent into the next sector on the next frame

### Requirement: Transition music lands on the grid
The last kill of a sector SHALL get an immediate stinger. The pursuit and the descent SHALL start on beat boundaries of the score's grid.

#### Scenario: Descent cue
- **WHEN** a pursuit ends
- **THEN** the next sector's music starts on a beat boundary as the ship descends

### Requirement: The carrier arrives through the swarm
On arrival at the carrier sector, the pursued flock SHALL circle the arrival point, open a gap for the carrier's descent, and pour into its hangar bays once it settles, before carrier combat starts. The carrier's own arrival and combat SHALL be unchanged.

#### Scenario: Carrier arrival
- **WHEN** the ship descends into the carrier sector
- **THEN** the brood rings and parts around the carrier as it comes down, then streams into its bays

### Requirement: Swarm outros
Completing the campaign SHALL thin the fog, lift the shadows and climb the ship above the clouds into the ending without passing through black. Losing the last life SHALL gather the swarm into a slow circling mill over the wreck, with brood taunts, before the skyward pan to High Scores.

#### Scenario: Game over
- **WHEN** the final life is lost
- **THEN** the brood circles over the wreck before the camera pans up to High Scores

### Requirement: Swarm attract mode
The title screen SHALL show the current sector's swarm milling in the fog with the sentinel silhouette passing behind it. An idle demo flight MAY start after 30 s without input. It SHALL never record a score, and any input SHALL return to the title.

#### Scenario: Idle title
- **WHEN** the title screen is open
- **THEN** squads circle and stream in the fog behind it, casting shadows on the ground
