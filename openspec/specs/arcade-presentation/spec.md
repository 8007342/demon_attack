# arcade-presentation

## Purpose
Present original animated pixel-art worlds and responsive arcade screens with adaptive synthesized music.

## Requirements

### Requirement: Original pixel artwork
Demons, player, boss, explosions, pickups, and the controller panel SHALL use a coherent original pixel-art style with animated creature and effect frames.

#### Scenario: Creature flight
- **WHEN** a demon is active
- **THEN** its wings animate and its damage state remains visually readable

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
