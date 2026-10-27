# arcade-presentation

## Purpose
Present original animated pixel-art worlds and responsive arcade screens with adaptive synthesized music.

## Requirements

### Requirement: Original pixel artwork
Creatures, player, boss, fire, smoke, explosions, warnings, pickups and controller artwork SHALL use original Atari-era-inspired pixel art on fixed low-resolution grids, bounded palettes and nearest-neighbor sampling. Original-game sprites/screenshots SHALL NOT be copied or traced. Creatures and effects SHALL use discrete pixel frames, including runtime-generated art; smooth vector silhouettes, antialiased curves, gradients and continuously deforming flames SHALL NOT replace those frames.

#### Scenario: Creature flight
- **WHEN** a demon is active
- **THEN** its wings animate and its damage state remains visually readable

#### Scenario: Enlarged rare creature
- **WHEN** a large creature is drawn larger than an ordinary demon
- **THEN** its outline, segmented wings and damage forms retain visible logical pixels and discrete animation poses without smooth vector edges

#### Scenario: Articulated heavy flight and subtle tell
- **WHEN** a sentinel hovers or prepares its attack
- **THEN** its wide wings articulate through eight distinct slow pixel poses and its own small pose change supplies the warning without an oversized detached marker

#### Scenario: Carrier damage and attack warning
- **WHEN** carrier fire or a rare creature's dive warning is visible
- **THEN** the effect uses original bounded-palette pixel frames, and the warning is a creature-associated sprite cue rather than an arrow

### Requirement: Stepped 2.5D pixel lighting and banked poses
The renderer SHALL present 2.5D depth using nearest-neighbor stepped directional hemisphere/rim highlights, banked ship transforms (`shipBank`), angled sling-shot bolts, 3-tier diving bow-shock shields (`diveShield`), and open/sealed carrier auxiliary side doors (`sideDoorLeft`, `sideDoorRight`) without smooth GLSL normal-map blur.

#### Scenario: Stepped 2.5D pixel lighting, banked ship poses, and 3-tier dive shields
- **WHEN** the player ship banks, creatures dive with their 3-tier atmospheric shields, or the carrier exposes its center and auxiliary side hatches
- **THEN** volume and shielding render as crisp stepped pixel layers with directional highlights and shadow contrast

#### Scenario: Sling-shooting arrival hint
- **WHEN** the `sling_shot` arrival card is selected during sector loading
- **THEN** it pairs a concise 5–9 word action sentence on strafing to curve shots with an original pixel illustration of banked diagonal shots entering an open hatch

### Requirement: Thermal re-entry plasma fire vs. geometric force shields
Diving creature shields (`diveShield`) SHALL use a strictly thermal blackbody gradient (blinding white stagnation core -> incandescent solar yellow -> superheated ablation orange -> deep crimson/charcoal smoke trail and embers, with zero cyan/violet bands). Technological force shields SHALL use cool geometric cyan/teal/violet hex and segmented pixel barriers.

#### Scenario: Thermal blackbody dive shields vs. cool geometric force shields
- **WHEN** a creature dives with an atmospheric re-entry shield or an entity displays a technological force shield
- **THEN** the re-entry shield renders as a white-yellow-orange-crimson thermal envelope with embers and zero cyan/violet bands, while the force shield renders as a geometric cyan/teal/violet barrier

### Requirement: Multi-part Dreadnought Carrier presentation
The Brood Dreadnought Carrier SHALL render as a `184 × 120` logical pixel multi-part sprite hierarchy across 4 evolution forms (`Carrier`, `Brood Ark`, `Siege Carrier`, `Brood Flagship`) with articulated mandibles, dorsal retro-thrusters, tracking ventral dual-turrets, 3 launch bay shutters, progressive fracture overlays, orbital retro-burn arrival, and sequential meltdown.

#### Scenario: Dreadnought multi-part hierarchy, arrival, and meltdown
- **WHEN** the Brood Dreadnought arrives, fights across its 4 forms, or is defeated
- **THEN** it displays its `184 × 120` multi-part carapace and sub-components, descends with orbital retro-burn and klaxon telemetry, and explodes sequentially from wing pylons to auxiliary bays to central core

### Requirement: Cockpit Control Panel, defeat celebration, and 3-beat opening zoom-out
The bottom panel SHALL render a Stylized Starfighter Cockpit Control Panel combining the Weapon/Shield Telemetry Schematic with a rotating Steering Yoke & Gun Angle Gimbal (`±6°, ±12°, ±18°, ±24°`) for touch and 3D device tilt. New games SHALL open with a 3-beat Cockpit Panel zoom-out; final life loss SHALL show an enemy victory celebration and skyward pan to High Scores.

#### Scenario: Cockpit Control Panel yoke, interim gun angles, and 3-beat opening zoom-out
- **WHEN** a new game starts or the pilot steers via touch drag or calibrated 3D device tilt
- **THEN** the camera pulls back continuously from the igniting Cockpit Control Panel into the live arena without fading to black, and the rotating yoke and gimbal reflect interim shooting angles (`0°, ±6°, ±12°, ±18°, ±24°`)

#### Scenario: Last-life-lost victory celebration and skyward High Score pan
- **WHEN** the player loses their final life
- **THEN** the ship explodes, surviving enemies, Sentinels, or the Dreadnought perform a victory celebration swarm, and the camera pans skyward into the starfield High Scores table

### Requirement: Planetary parallax
Each of the five levels SHALL have a distinct original pixel-art environment with terrain, planets, moons and satellites. Background complexity and visible demon infrastructure SHALL grow toward the carrier and on later cycles, with relative layer motion and smooth transitions that preserve threat readability.

#### Scenario: Advance level
- **WHEN** the game advances to another sector
- **THEN** the environment changes in terrain and celestial composition rather than only hue

#### Scenario: Territory story
- **WHEN** the player travels toward the carrier or begins a harder cycle
- **THEN** cinematic captions, pictorial pixel-art storyboard interludes, and environmental occupation details communicate the deeper threat

### Requirement: Arcade screens
The app SHALL provide title, play, pause, victory and game-over screens, inline Top10 on the title, three-wheel score entry, a score/lives/level/wave HUD, and a futuristic pixel controller panel.

#### Scenario: Start
- **WHEN** a visitor starts a game
- **THEN** the play screen shows three lives and starts automatic fire during combat

#### Scenario: Landing scores
- **WHEN** the landing page loads
- **THEN** the Top10 appears on that page without a separate scoreboard action

### Requirement: Adaptive MIDI soundtrack
A MIDI-event synthesizer SHALL provide distinct level tracks, escalating boss-phase music, a victory fanfare, and transitions aligned to musical phrases with fades. Audio SHALL start only after a user gesture and provide mute and lifecycle pause.

#### Scenario: Boss transforms
- **WHEN** the boss enters a more advanced phase
- **THEN** the score transitions smoothly into more intense boss music without restarting audio abruptly

### Requirement: Layered power status glyph
The controller panel SHALL show a single composite pixel glyph formed from the visible layers of all active modifiers, with distinct spread arrows, rapid-fire lightning and an enclosing shield. Each effect SHALL also show its own name, countdown and duration bar. Removing an effect SHALL remove only its glyph layer and timer, and the status SHALL not block touch piloting.

#### Scenario: Triple combination
- **WHEN** all three modifiers are active
- **THEN** arrows, lightning and shield remain visible in the composite glyph and all three independent countdowns are shown

#### Scenario: One effect ends
- **WHEN** shield is consumed or an effect expires
- **THEN** the other layers and countdowns remain visible and touch piloting continues

### Requirement: Illustrated gameplay instruction
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration and equivalent semantics. Hints SHALL advance automatically during loading without guide, Hold, Menu or manual-advance controls. Normal pause SHALL freeze the card. Advice SHALL describe actual game rules without promising protection the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Automatic loading hint
- **WHEN** a sector begins
- **THEN** one complete illustrated hint appears during loading and disappears automatically before the initial swarm flies in

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability

## Research and reference traceability

- Master reference index: [plan/reference-register.md](../../../plan/reference-register.md)
- External & sibling source disposition ledger: [plan/research-source-ledger.md](../../../plan/research-source-ledger.md)
- Project-committed UX cheatsheets:
  - [.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md](../../../.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md)
  - [.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md](../../../.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md)
