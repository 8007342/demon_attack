# arcade-progression updates

## MODIFIED Requirements

### Requirement: Multiple waves per level
The first cycle SHALL use three waves in LV1–2 and four in LV3–4. Later cycles SHALL add up to three waves per level. Clearing a wave SHALL preserve level, score, lives and powers until the final wave. The HUD SHALL show wave progress.

#### Scenario: Clearing an early wave
- **WHEN** wave one is cleared in level one
- **THEN** wave two enters in the same level while piloting and falling-item collection remain available

#### Scenario: Clearing the final wave
- **WHEN** the last wave of a level is defeated
- **THEN** a protected two-second pickup grace period precedes the victory sequence and sector change

### Requirement: Transition safety and pause
Recovery phases SHALL disable enemy damage and firing while allowing piloting and item collection during interwave entrances and final salvage. Other cutscenes SHALL lock piloting. Active power time SHALL freeze outside combat; pause SHALL freeze all movement, pickups and phase clocks.

#### Scenario: Pausing travel
- **WHEN** travel is paused
- **THEN** progression and cinematic time stop until Resume, with lives and active power unchanged

#### Scenario: Collecting between waves
- **WHEN** a player pilots under a falling pickup during an interwave entrance or salvage
- **THEN** it is collected and its full power duration is preserved until combat resumes
