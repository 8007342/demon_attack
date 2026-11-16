# arcade-presentation

## Purpose
Present original animated pixel-art worlds and responsive arcade screens with adaptive synthesized music.

## ADDED Requirements

### Requirement: Original pixel artwork
Demons, player, boss, explosions, pickups, and the controller panel SHALL use a coherent original pixel-art style with animated creature and effect frames.

#### Scenario: Creature flight
- **WHEN** a demon is active
- **THEN** its wings animate and its damage state remains visually readable

### Requirement: Planetary parallax
The background SHALL layer stars, ringed planets, moons, and a horizon with relative motion and rising or setting celestial bodies as levels advance.

#### Scenario: Advance level
- **WHEN** the game advances
- **THEN** the sky palette or celestial positions change while enemies and bullets remain readable

### Requirement: Arcade screens
The app SHALL provide title, play, pause, victory, game-over, and Top10 screens, a readable score/lives/level HUD, and a futuristic pixel controller panel inviting touch.

#### Scenario: Start
- **WHEN** a visitor starts a game
- **THEN** the play screen shows three lives and starts automatic fire

### Requirement: Adaptive MIDI soundtrack
A MIDI-event synthesizer SHALL provide distinct level tracks, escalating boss-phase music, a victory fanfare, and transitions aligned to musical phrases with fades. Audio SHALL start only after a user gesture and provide mute and lifecycle pause.

#### Scenario: Boss transforms
- **WHEN** the boss enters a more advanced phase
- **THEN** the score transitions smoothly into more intense boss music without restarting audio abruptly
