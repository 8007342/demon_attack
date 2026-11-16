# Arcade progression

## MODIFIED Requirements

### Requirement: Animated victory and travel
Level completion SHALL play as swarm beats on one transition clock: a rout of about two seconds (the pickup grace), a pursuit of about six seconds in which the ship climbs into the clouds while the sector changes inside the cloud, and a descent into the next sector whose first wave comes out of the cloud on the side the rout set. The rout SHALL scatter only creatures that were fighting when it began (a carrier's live minions at its fall); it SHALL NOT add creatures, and nothing SHALL come out of the fog to flee. Boss victory SHALL celebrate for 5.5 seconds before the pursuit into the next cycle. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends with its last kill
- **THEN** no creature flees through the fog, the ship climbs into the clouds, and the next sector's first wave comes out of the clouds on the side the rout set

#### Scenario: Fleet recognition
- **WHEN** a boss that is not the fifth is beaten
- **THEN** its falling wreck precedes a short medal-glyph flourish beside the ship during the pursuit (no panel and no `+1UP` text; the HUD counts the life), followed by the next destination; the fifth leads to the final ending

### Requirement: Opening cockpit zoom-out, pictorial storyboards, and defeat pan
New campaign runs SHALL start with a 3-beat Cockpit Control Panel zoom-out sequence into the live arena without fading to black. The run's opening arrival SHALL present an illustrated pixel-art tip; later sector transitions SHALL play as swarm beats without storyboard cards. Boss encounters SHALL stage an orbital retro-burn arrival and sequential chain-reaction destruction. Losing the final life SHALL stage an enemy victory celebration, a swarm mill over the wreck and a skyward pan to High Scores.

#### Scenario: 3-beat New Game Cockpit Panel zoom-out and pictorial storyboards
- **WHEN** a new campaign run begins
- **THEN** the opening camera zooms out continuously from the igniting Cockpit Control Panel into the live arena without a fade-to-black cut, and the opening arrival shows one illustrated tip

#### Scenario: Boss arrival/destruction and last-life-lost skyward High Score pan
- **WHEN** a carrier arrives or is destroyed, or the player loses their final life
- **THEN** the Dreadnought arrives via orbital retro-burn and detonates sequentially from wing pylons to auxiliary bays to central core, and losing the last life triggers an enemy victory celebration followed by a skyward camera pan to High Scores

## ADDED Requirements

### Requirement: The final wave leaves the fog empty
Once the final wave of a sector (including its sentinel finale) or the carrier fight is under way, the deep fog SHALL show no waiting creatures: no reinforcement groups, no later roster skeins and no next-wave preview. What the wave still holds back SHALL wait unseen until admitted, and all of it SHALL be admitted before the wave can end.

#### Scenario: Last wave
- **WHEN** the last wave of a sector is being fought and when it ends
- **THEN** no creature waits visibly in the fog, and nothing flies away through the fog at the level's end

#### Scenario: Sentinel finale
- **WHEN** the final wave brings a sentinel
- **THEN** its foreshadow silhouette may still circle in the murk until it rises, since it is admitted into this wave

#### Scenario: Earlier waves
- **WHEN** a wave before the last is fought
- **THEN** its reserve and the next cohort still show veiled in the fog as before

### Requirement: Transitions never cut to black
No transition, outro or game-over frame SHALL be an opaque full-screen wipe or darker than the sector's night floor. A scene change SHALL happen only while the cloud cover is at least 85 %, and the swarm's direction of travel and the ship's screen position SHALL be preserved across it.

#### Scenario: Palette swap
- **WHEN** the sector changes during a pursuit
- **THEN** the swap happens inside bright cloud, and any flock keeps flying in the same screen direction afterwards

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
On arrival at the carrier sector, any flock still flying from the rout SHALL circle the arrival point, open a gap for the carrier's descent, and pour into its hangar bays once it settles, before carrier combat starts. A sector ends only when every fighter fell, so this flock is normally empty and the carrier comes down through an empty fog. The carrier's own arrival and combat SHALL be unchanged.

#### Scenario: Carrier arrival
- **WHEN** the ship descends into the carrier sector
- **THEN** the carrier comes down through the cloud with no stand-in flock, and carrier combat starts unchanged

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
