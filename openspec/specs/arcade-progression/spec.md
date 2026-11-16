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
Level completion SHALL show an animated celebration and ship departure, followed by a travel flyby and eased arrival into the next sector. Text-bearing cinematic phases SHALL allow approximately one third of a second more reading time than their preceding durations: ordinary level-clear and travel phases SHALL each last approximately 4.33 seconds rather than four seconds. Boss victory SHALL show carrier collapse, medal recognition and +1UP before story-led travel into the next route, with the same additional reading allowance for its captions; the fifth victory SHALL lead to campaign completion. Motion SHALL remain continuous across phases.

#### Scenario: Sector handoff
- **WHEN** a level ends
- **THEN** victory effects and ship departure precede star-flight, a destination flyby and the next encounter entrance

#### Scenario: Fleet recognition
- **WHEN** a boss is beaten
- **THEN** its falling wreck precedes a medal and heart reward scene with fleet recognition, followed by the next destination or final ending

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
Normal and Hard bosses SHALL retain baseline shield/core health of 72/24, increasing by 18/10 per route. Easy SHALL reduce each value by 20%, rounded to a positive whole hit count. Core damage SHALL remain impossible until the shield is depleted and the sliding door exposes the core.

#### Scenario: Extended shield phase
- **WHEN** the first Normal boss receives eighteen valid shield hits
- **THEN** fifty-four shield hits remain and its core is unchanged

#### Scenario: Easy endurance
- **WHEN** the first Easy boss appears
- **THEN** it has 58 shield hits and 19 core hits

### Requirement: Medal and life rewards
Every boss victory SHALL award exactly one medal for its ordinal victory and selected difficulty and exactly one extra life, including the fifth boss. Recognition SHALL happen once even across pauses and restored checkpoints. Final remaining lives SHALL include the fifth reward.

#### Scenario: Final medal
- **WHEN** the fifth boss is defeated
- **THEN** the run has five medals and its final lives include the fifth +1UP

### Requirement: Active campaign timer
Accumulated time SHALL count only active combat simulation. Pauses, cinematics, salvage, travel, landing and time away SHALL be excluded. Resume SHALL restore the saved wave-start accumulated time. Both partial and completed runs SHALL expose accumulated time for score display.

#### Scenario: Paused journey
- **WHEN** a player pauses or watches a cutscene
- **THEN** accumulated playing time remains unchanged

### Requirement: Readable arrival hint interval
First-wave illustrated arrivals SHALL last 4.5 seconds by default, with the complete text and image visible throughout. A visible Hold/Pause action SHALL freeze the card, remaining interval and game state until explicit Resume, which SHALL continue the same card from the paused point. Hint time SHALL NOT count as active combat or consume power timers. Other story and interwave phase timing SHALL remain independently defined.

#### Scenario: Hold to understand
- **WHEN** the player holds an arrival hint before its interval ends
- **THEN** its content and countdown stay unchanged indefinitely and combat cannot begin until the player resumes

### Requirement: Slow ground-force introduction
Ground forces SHALL appear only over sectors 1–4. On the first route, Normal and Hard SHALL field one unit, late in Krybor's final wave, and Easy none in Krybor. Unit budgets SHALL ramp gently with sector and route, ordered Easy ≤ Normal ≤ Hard, with at most three active at once. Skirmishing allies SHALL follow the same ramp.

#### Scenario: First Krybor
- **WHEN** a Normal run plays its first Krybor visit
- **THEN** exactly one ground unit appears, during the final wave

#### Scenario: Carrier
- **WHEN** the carrier level is fought
- **THEN** no ground units appear

### Requirement: Homing availability
While demon ground units are alive, each ordinary kill SHALL have a chance to drop homing missiles. A pity timer SHALL guarantee a drop after a few seconds of ground pressure, and the fleet SHALL air-drop one if no kill delivers it. Over the carrier, homing missiles SHALL drop as an ordinary kill-count power-up. No second drop SHALL occur while one is falling or a salvo is armed.

#### Scenario: Guarantee before range
- **WHEN** a fresh ground unit appears at the horizon and the player keeps destroying demons
- **THEN** a homing pickup drops before the unit reaches the near-ground fire line

### Requirement: Fleet intact tally
The model SHALL track per level and per run whether no ally retreated and no wingmate was lost. It SHALL emit `fleetIntact` at a clean level clear and at a clean campaign victory, and MAY award a bonus, never a penalty.

#### Scenario: Clean sector
- **WHEN** a sector is cleared without any ally retreating
- **THEN** a `fleetIntact` event with scope `level` fires

### Requirement: Time-driven ground front
Ground activity SHALL start early in sector 1 on every difficulty and follow a schedule driven by combat time, independent of how quickly air waves are cleared. Arrivals SHALL be paced by a ground pressure meter (0–1) and capped, so a slow player never faces more than one broken-through unit firing at a time.

#### Scenario: Fast and slow players
- **WHEN** two players fight the same sector at very different air-wave speeds
- **THEN** ground units arrive at the same combat times for both, and the slower player sees more of the war but never a burst

#### Scenario: Early activity
- **WHEN** an Easy run enters Krybor
- **THEN** the first ground unit arrives within the first ten seconds of combat

### Requirement: Allies hold the early sectors
In sectors 1–2 every demon ground unit SHALL be met by an ally that destroys it before fire range. From sector 3, units SHALL be able to break through when unescorted or out-gunned: occasionally in sector 3 and regularly in sector 4, ordered by difficulty. Player help SHALL raise allied strength, so allies escort and win more often.

#### Scenario: Quiet Krybor
- **WHEN** sectors 1–2 are played on any difficulty
- **THEN** no ground unit reaches fire range and no ground missile is launched

#### Scenario: Unchecked Hollow
- **WHEN** an unescorted demon unit approaches in sector 4 and the player does not help
- **THEN** its allies call for help, then it breaks through and fires

### Requirement: Homing urgency
Homing missiles SHALL drop with high urgency (a high chance per kill, a pity timer and an airdrop) while a demon unit threatens to break through or has broken through and can still fire. Otherwise they SHALL be an ordinary pickup on a fixed kill cadence.

#### Scenario: Help in time
- **WHEN** an unescorted unit appears at the horizon and the player keeps destroying demons
- **THEN** a homing pickup drops before the unit reaches fire range

### Requirement: Ending after the fifth carrier
The beach ending and credits SHALL open only in the victory over the campaign's last carrier: sector 5 of the fifth route. Victories over the first four carriers SHALL play their normal victory scene and travel into sector 1 of the next route, with no ending. A resumed run SHALL still earn the ending at the fifth carrier. The title's ending replay SHALL be offered only after the fifth carrier has fallen at least once.

#### Scenario: Earlier carriers
- **WHEN** the carrier of route 1, 2, 3 or 4 is destroyed
- **THEN** no ending opens, and the run travels to sector 1 of the next route

#### Scenario: Fifth carrier
- **WHEN** the carrier of route 5 is destroyed
- **THEN** the ending opens during the victory scene, and closing it leads to the completed result and score entry with the score, lives and medals unchanged

#### Scenario: Resumed final route
- **WHEN** a saved run on route 5 is resumed and its carrier destroyed
- **THEN** the ending opens

### Requirement: Console runs
A console run SHALL begin at the chosen sector 1–5 (the carrier included), route 1–5 and difficulty, with exactly one life and 0 points, with earlier routes counted as won. It SHALL be unranked: it SHALL NOT save or clear the player's checkpoint or change the unlock history, and the HUD SHALL show a `CONSOLE RUN · NOT RANKED` tag. A normal start or a resumed save SHALL be ranked.

#### Scenario: Carrier jump
- **WHEN** the console starts the carrier of route 5 on Hard
- **THEN** the run is at sector 5, route 5, with one life, 0 points and the unranked tag

#### Scenario: Saved run untouched
- **WHEN** a console run reaches new waves and ends
- **THEN** the stored checkpoint and unlock history are as they were before it

### Requirement: Visible breakthrough drama
- Sectors 1–2 SHALL never fire at the player.
- In sector 2, some demon units SHALL be stopped by the allies just short of fire range, with a `groundNearMiss` event.
- Sectors 3 and 4 SHALL guarantee at least one breakthrough per sector visit. It SHALL be telegraphed by `allyUnderAttack` and `groundBreakthroughWarning` before `groundBreakthrough`.
- Sector 4 SHALL keep regular breakthroughs.

#### Scenario: Near miss
- **WHEN** a near-miss unit approaches in Ringfall
- **THEN** its ally destroys it within 22 texels of the fire line, `groundNearMiss` fires, and no ground missile is launched

#### Scenario: Guaranteed breakthrough
- **WHEN** nothing has broken through 9 s into an Ember Moon visit
- **THEN** the next arrival is unescorted and out of homing lock until it reaches fire range, and the warnings precede its breakthrough

### Requirement: Console starts
A console start SHALL begin a fresh run at the chosen sector, route and difficulty, at 0 points, with earlier routes counted as won. Normal scoring SHALL apply; lives and ranking follow the `console-runs-final-ending` change (one life, never ranked).

#### Scenario: Sentinel jump
- **WHEN** the console starts a sentinel encounter
- **THEN** the run is on route 2 or later, at a wave whose roster includes a sentinel

## Research and reference traceability

- Master reference index: [plan/reference-register.md](../../../plan/reference-register.md)
- External & sibling source disposition ledger: [plan/research-source-ledger.md](../../../plan/research-source-ledger.md)
- Project-committed UX cheatsheets:
  - [.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md](../../../.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md)
  - [.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md](../../../.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md)
