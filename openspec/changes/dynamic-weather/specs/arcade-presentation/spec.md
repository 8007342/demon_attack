# Arcade presentation

## ADDED Requirements

### Requirement: Seeded rain on regular levels
A seeded run SHALL choose each regular level's weather from the run seed, the route and the sector alone: about one level in four SHALL rain, as a drizzle, rain or downpour with its own wind slant. Unseeded runs, bonus levels and the carrier's sector SHALL stay dry. Rain SHALL be presentation only: no gameplay rule, spawn, score or calibration number SHALL depend on it.

#### Scenario: Frequency
- **WHEN** the plans of 2000 run seeds over three routes and sectors 1 to 4 are drawn
- **THEN** between 22 % and 28 % of the levels rain and drizzle, rain and downpour all occur

#### Scenario: Unseeded test run
- **WHEN** a run starts without a run seed
- **THEN** no level rains and no rain event is sent

#### Scenario: Same seed
- **WHEN** the same run seed reaches the same route and sector twice
- **THEN** the rain has the same tier, peak, wind, start and stop

### Requirement: Rain changes softly
Rain SHALL never appear, vanish or change strength abruptly: the drawn intensity SHALL move toward its target at no more than a third of full strength per second. A level MAY start dry and begin raining, or ease off before its end, and the rain SHALL fade out as the ship leaves the sector.

#### Scenario: Rain starts mid-level
- **WHEN** a level's rain is planned to start 2 s into combat and build over 8 s
- **THEN** the frames at 1.5, 3.5, 5.5, 7.5 and 9.5 s show it growing from nothing to its peak with no jump

#### Scenario: Leaving the sector
- **WHEN** a rainy level ends and the travel begins
- **THEN** the rain fades to nothing within 3 s

### Requirement: Readable layered rain
Rain SHALL be drawn in parallax layers (faint short slow far streaks, brighter longer faster near streaks), with splashes on the ground, a slightly thicker horizon haze, slightly dimmer light and a faint wet sheen, over the full height of the background including the band above the arena. All of it SHALL be drawn under the ground units, fog, creatures, ship and shots, never over them.

#### Scenario: Downpour in a fight
- **WHEN** a downpour falls during a fight at phone portrait size
- **THEN** every creature, the ship and every shot stays clearly visible over the rain

#### Scenario: Tall phone
- **WHEN** the viewport is taller than the arena
- **THEN** the rain also falls in the band above the arena

### Requirement: Rain fits the mobile-web budget
Rain SHALL be drawn in batches, at most one draw call per streak or splash layer and per alpha step, with at most 200 far streaks, 80 near streaks and 64 live splashes, and SHALL allocate nothing per drop per frame.

#### Scenario: Heaviest rain
- **WHEN** a downpour is drawn at full strength
- **THEN** it draws 200 far and 80 near streaks and at most 64 splashes in no more than four line batches and three rects

### Requirement: Rain respects accessibility settings
With reduced motion the rain SHALL be lighter and slower (half the drops at about a third of the speed, shorter, with no splashes and no gusts). Regular-level rain SHALL have no lightning, thunder or flash, so it cannot cause a general flash under WCAG 2.3.1; lightning stays exclusive to the Stormfront bonus level.

#### Scenario: Reduced motion downpour
- **WHEN** a downpour falls with reduced motion on
- **THEN** about half the streaks are drawn, they fall at about a third of the speed and no splash is drawn

#### Scenario: No lightning outside Stormfront
- **WHEN** any regular level rains at any strength
- **THEN** no bolt, tell or whole-screen flash is drawn

### Requirement: Rain audio events
The rain SHALL send `rainStart` when a shower begins, `rainStop` when it has died away and `rainIntensity` when it crosses into another tier, each carrying the tier, the intensity, the wind and the sector, for the music and sound engine. A gust near a tier boundary SHALL not repeat events.

#### Scenario: A shower builds to a downpour and stops
- **WHEN** the rain grows from nothing to a downpour, gusts around the rain-downpour boundary and stops
- **THEN** one `rainStart` (drizzle), one `rainIntensity` to rain, at most a few to downpour and back, and one `rainStop` are sent
