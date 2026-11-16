# arcade-presentation updates

## MODIFIED Requirements

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
