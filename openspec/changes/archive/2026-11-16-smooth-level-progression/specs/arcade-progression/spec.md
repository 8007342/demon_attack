# Arcade progression

## Purpose
Give each sector a paced multi-wave challenge and a continuous audiovisual journey into the next encounter.

## ADDED Requirements

### Requirement: Multiple waves per level
LV1–2 SHALL contain three waves and LV3–4 SHALL contain four. Clearing a wave SHALL preserve level, score, lives, and powers until the final wave is defeated. The HUD SHALL show wave progress.

#### Scenario: Clearing an early wave
- **WHEN** wave one is cleared in level one
- **THEN** wave two enters in the same level with a short animated entrance and the same score and lives

#### Scenario: Clearing the final wave
- **WHEN** the last wave of a level is defeated
- **THEN** the victory sequence begins before level or scenery changes

### Requirement: Animated victory and travel
Level completion SHALL show a four-second animated celebration and ship departure, followed by a four-second travel flyby and eased arrival into the next sector. Boss victory SHALL celebrate for 5.5 seconds before travel into the next cycle. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends
- **THEN** victory effects and ship departure precede star-flight, a destination flyby and the next encounter entrance

### Requirement: Transition safety and pause
Cutscenes and entrances SHALL disable damage and firing, preserve remaining power time, and pause their animation and timers when the game is paused.

#### Scenario: Pausing travel
- **WHEN** travel is paused
- **THEN** progression and cinematic time stop until Resume, with lives and active power unchanged

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
