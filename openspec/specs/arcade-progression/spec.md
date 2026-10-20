# arcade-progression

## Purpose
Give each sector a paced multi-wave challenge and a continuous audiovisual journey into the next encounter.

## Requirements

### Requirement: Multiple waves per level
The first cycle SHALL use three waves in LV1–2 and four in LV3–4. Later cycles SHALL add up to three waves per level. Clearing a wave SHALL preserve level, score, lives and powers until the final wave. The HUD SHALL show wave progress.

#### Scenario: Clearing an early wave
- **WHEN** wave one is cleared in level one
- **THEN** wave two enters in the same level while piloting and falling-item collection remain available

#### Scenario: Clearing the final wave
- **WHEN** the last wave of a level is defeated
- **THEN** a protected two-second pickup grace period precedes the victory sequence and sector change

### Requirement: Animated victory and travel
Level completion SHALL show a four-second animated celebration and ship departure, followed by a four-second travel flyby and eased arrival into the next sector. Boss victory SHALL celebrate for 5.5 seconds before travel into the next cycle. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends
- **THEN** victory effects and ship departure precede star-flight, a destination flyby and the next encounter entrance

### Requirement: Transition safety and pause
Recovery phases SHALL disable enemy damage and firing while allowing piloting and item collection during interwave entrances and final salvage. Other cutscenes SHALL lock piloting. Active power time SHALL freeze outside combat; pause SHALL freeze all movement, pickups and phase clocks.

#### Scenario: Pausing travel
- **WHEN** travel is paused
- **THEN** progression and cinematic time stop until Resume, with lives and active power unchanged

#### Scenario: Collecting between waves
- **WHEN** a player pilots under a falling pickup during an interwave entrance or salvage
- **THEN** it is collected and its full power duration is preserved until combat resumes

### Requirement: Completion and travel music
Level completion SHALL trigger an immediate original MIDI victory flourish with a short fade from combat music. Travel SHALL use a bridge cue, and the next encounter SHALL enter on the musical grid. Muting and pause SHALL continue to apply.

#### Scenario: Musical reward
- **WHEN** the final demon of a sector is destroyed
- **THEN** the victory flourish responds immediately and transitions into travel music without a silent scene cut

### Requirement: Boss endurance
The first boss SHALL have 72 shield hits and 24 core hits, increasing by 18 and 10 respectively each cycle. Core damage SHALL remain impossible until the shield is depleted and the sliding door exposes the core.

#### Scenario: Extended shield phase
- **WHEN** the first boss receives eighteen valid shield hits
- **THEN** fifty-four shield hits remain and its core is unchanged
