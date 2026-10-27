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

### Requirement: Curved squadron entrances and graduated carrier onboarding
Incoming squadrons SHALL fly along curved entrance paths that blend into active formation coordinates via a quintic smootherstep (`6t^5 - 15t^4 + 10t^3`) envelope with zero position or velocity snap. Early carrier encounters on Routes 0 and 1 SHALL use dialed-down endurance (`48/16` and `64/20` before Easy scaling) and expose Left/Right auxiliary side hatches (`sideDoorLeft`, `sideDoorRight`) during non-final forms (`phase < formCount - 1`).

#### Scenario: Quintic entrance handoff
- **WHEN** an arriving demon finishes its curved entrance (`enterTime` reaches zero)
- **THEN** its position and velocity match its active formation anchor without a coordinate snap

#### Scenario: Calibrated early-route boss onboarding
- **WHEN** the player fights the carrier on Route 0 or Route 1
- **THEN** shield/core endurance uses the dialed-down onboarding values (`48/16` and `64/20` in Normal/Hard) and non-final boss forms open auxiliary Left and Right hatches alongside the center hatch

### Requirement: Animated victory and travel
Level completion SHALL show a four-second animated celebration and ship departure, followed by a four-second travel flyby and eased arrival into the next sector. Boss victory SHALL celebrate for 5.5 seconds before travel into the next cycle. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends
- **THEN** victory effects and ship departure precede star-flight, a destination flyby and the next encounter entrance

### Requirement: Opening cockpit zoom-out, pictorial storyboards, and defeat pan
New campaign runs SHALL start with a 3-beat Cockpit Control Panel zoom-out sequence into the live arena without fading to black. Sector transitions SHALL present pictorial pixel-art storyboard interludes. Boss encounters SHALL stage an orbital retro-burn arrival and sequential chain-reaction destruction. Losing the final life SHALL stage an enemy victory celebration and skyward pan to High Scores.

#### Scenario: 3-beat New Game Cockpit Panel zoom-out and pictorial storyboards
- **WHEN** a new campaign run begins or a sector transition occurs
- **THEN** the opening camera zooms out continuously from the igniting Cockpit Control Panel into the live arena without a fade-to-black cut, and sector transitions display pictorial pixel-art storyboard interludes

#### Scenario: Boss arrival/destruction and last-life-lost skyward High Score pan
- **WHEN** a carrier arrives or is destroyed, or the player loses their final life
- **THEN** the Dreadnought arrives via orbital retro-burn and detonates sequentially from wing pylons to auxiliary bays to central core, and losing the last life triggers an enemy victory celebration followed by a skyward camera pan to High Scores

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
The first boss SHALL have 48 shield hits and 16 core hits on Route 0, 64 shield hits and 20 core hits on Route 1, and `72 + route×18` shield / `24 + route×10` core hits on Routes 2–4 (scaled by 0.8 in Easy). Core damage SHALL remain impossible until the shield is depleted and an active sliding door exposes the core.

#### Scenario: Extended shield phase
- **WHEN** the boss receives valid shield hits while its shield remains above zero
- **THEN** its shield energy decreases and its core health remains unchanged until the shield is depleted

## Research and reference traceability

- Master reference index: [plan/reference-register.md](../../../plan/reference-register.md)
- External & sibling source disposition ledger: [plan/research-source-ledger.md](../../../plan/research-source-ledger.md)
- Project-committed UX cheatsheets:
  - [.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md](../../../.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md)
  - [.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md](../../../.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md)
