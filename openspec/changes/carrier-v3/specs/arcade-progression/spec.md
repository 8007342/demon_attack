# Arcade progression

## MODIFIED Requirements

### Requirement: Boss level opens with loom waves
The boss level SHALL open with launch waves that come off the approaching carrier: two on the first three tours and three from the fourth tour. The carrier SHALL approach from far ahead while these waves are fought, closing a step each time one is cleared, and SHALL be impossible to hit and silent until it is in range. The approach SHALL end when its waves are cleared or after 90 seconds.

#### Scenario: Tour one boss level
- **WHEN** the first tour reaches its boss sector
- **THEN** two waves are launched from the carrier's gates as it approaches, and only after they are cleared does it close to fight range

#### Scenario: Approach cap
- **WHEN** the player has not cleared the launch waves after 90 seconds
- **THEN** the carrier closes to fight range anyway, and what is left of the waves breaks away into the fog

### Requirement: Boss emerges from under the fog
The boss SHALL first fly in from behind the player and sink into the far fog during the arrival, then approach from far ahead and close to its fight distance over about four seconds once the launch waves are done. It SHALL become hittable and start firing only once in range, and no stragglers from the launch waves SHALL remain visible in the fog.

#### Scenario: Close
- **WHEN** the last launch wave is cleared
- **THEN** the carrier closes to its fight row, sheds the fog, and the fight begins only when it is in range

## ADDED Requirements

### Requirement: Composable carrier script
Each tour's carrier SHALL be driven by a script that sets its launch waves, gates, volleys, approach distances, framing, altitude, bend limits, speed cues and force-field style, with repeat cycles beyond the fifth tour drawing seeded scripts within the fifth tour's limits. The same run seed SHALL give the same script, and a run without a seed SHALL use the tour's authored script. Run modifiers that apply to ordinary waves SHALL apply to launch waves.

#### Scenario: Same seed, same carrier
- **WHEN** a run is replayed with the same seed
- **THEN** its carriers approach, launch and climb the same way

#### Scenario: Beyond the fifth tour
- **WHEN** a run reaches its sixth carrier
- **THEN** it uses a seeded script whose framing, bend and launch numbers stay within the fifth tour's limits
