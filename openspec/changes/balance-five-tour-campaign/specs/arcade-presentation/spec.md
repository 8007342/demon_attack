## MODIFIED Requirements

### Requirement: Planetary parallax
Each of the five sectors SHALL retain its distinct original pixel-art theme, terrain, planets, moons and satellites. Each of five campaign routes SHALL have a distinct named variant of every sector. Independently moving background layers and occupation details SHALL increase in complexity toward the base and on later routes, with smooth transitions and readable threats.

#### Scenario: Advance level
- **WHEN** the game advances to another sector
- **THEN** terrain and celestial composition change rather than only hue

#### Scenario: Territory story
- **WHEN** the player revisits a sector on a later route
- **THEN** its name, layered scenery and captions communicate a different location and a deeper threat

### Requirement: Arcade screens
The app SHALL provide title, play, pause, victory, campaign-complete and game-over screens, inline unlocked-mode Top10 tabs, three-wheel score entry, a score/lives/destination/wave HUD, and a futuristic pixel controller panel. Destinations SHALL replace numeric level/cycle headings. Lives SHALL remain readable above three.

#### Scenario: Start
- **WHEN** a visitor starts a game
- **THEN** play shows five lives in Easy or three in Normal/Hard and automatic fire starts during combat

#### Scenario: Landing scores
- **WHEN** the landing page loads
- **THEN** Top10 appears without a separate scoreboard action and locked difficulty tabs are hidden

### Requirement: Layered power status glyph
The controller panel SHALL show a single composite pixel glyph with distinct spread arrows, rapid-fire lightning and enclosing shield. Each effect SHALL show its own name, countdown and duration bar. Removing an effect SHALL remove only its glyph layer and timer. Status SHALL not block piloting or displace the controller guidance label as effects change. The standalone multi-fire glyph SHALL resemble twin cannons rather than crosses.

#### Scenario: Triple combination
- **WHEN** all three modifiers are active
- **THEN** all glyph layers and independent countdowns remain visible without shifting controller guidance

#### Scenario: One effect ends
- **WHEN** shield is consumed or an effect expires
- **THEN** remaining layers stay visible, guidance stays aligned and touch piloting continues

## ADDED Requirements

### Requirement: Readable story interludes
Brief cinematic messages SHALL use substantially larger text and more arena area than the current small captions, with a larger travel progress bar. Arrivals, carrier falls, recognition, departures and the final ending SHALL tell a continuous exploration story consistent with destination names and scenery on every route.

#### Scenario: Phone interlude
- **WHEN** travel is shown on a 390-pixel-wide phone
- **THEN** its destination, story message and progress bar are legible without clipping

### Requirement: Boss visual damage
Boss shield and belly geometry SHALL be symmetric around the sliding door at every viewport size. A full shield SHALL be wider and visibly deplete as damaged. Boss shield/core health bars SHALL be removed. Increasing core damage SHALL produce escalating smoke, sparks and flames, followed by a falling-wreck cinematic on defeat.

#### Scenario: Damaged carrier
- **WHEN** the shield and then core take damage
- **THEN** the shield visibly recedes and hull effects intensify without health bars

### Requirement: Difficulty medal artwork
Every mode SHALL have five distinguishable medal awards and matching empty silhouettes. Easy medals SHALL be simpler than Normal and Hard medals more elaborate than Normal. Reward scenes and Top10 SHALL use the same medal designs.

#### Scenario: Partial achievement
- **WHEN** a Normal player has defeated three bosses
- **THEN** the score row shows its three Normal medals and two empty medal silhouettes
