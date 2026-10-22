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

### Requirement: Planetary parallax
Each of the five levels SHALL have a distinct original pixel-art environment with terrain, planets, moons and satellites. Background complexity and visible demon infrastructure SHALL grow toward the carrier and on later cycles, with relative layer motion and smooth transitions that preserve threat readability.

#### Scenario: Advance level
- **WHEN** the game advances to another sector
- **THEN** the environment changes in terrain and celestial composition rather than only hue

#### Scenario: Territory story
- **WHEN** the player travels toward the carrier or begins a harder cycle
- **THEN** cinematic captions and environmental occupation details communicate the deeper threat

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
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration of the same mechanic, with real legible UI text and equivalent semantic information. The picture SHALL preserve the combat art's logical pixel grid and palette. Timed hints SHALL support holding the current card and revisiting the same instruction without a timer. Advice SHALL describe actual game rules and SHALL NOT imply protections that the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Read at the player's pace
- **WHEN** the player holds a timed hint or opens its untimed review
- **THEN** its complete text and illustration remain available until the player chooses to continue

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability

#### Scenario: Manual briefing preference
- **WHEN** the player disables automatic hint advancement and starts another sector
- **THEN** its illustrated briefing waits for Continue without advancing on a timer
