# Bonus level: Crosswind

## ADDED Requirements

### Requirement: Crosswind level
The bonus catalogue SHALL hold Crosswind, appended after Stormfront: a level in sectors 2 to 4 where the crosswind tier of the wind blows from start to end over the sector's swarm (x 0.88), three drops in four are Powerful, and the brood's kites ride the gusts. Its goal SHALL be popping the kites with shots aimed through the wind.

#### Scenario: Wind from the start
- **WHEN** a run enters Crosswind
- **THEN** the level's wind is the crosswind tier and blows at full share within half a second

#### Scenario: Completion
- **WHEN** a wind-aware pilot plays Crosswind (sector 3, route 2) to its end
- **THEN** the level clears with `bonusCleared`, at least one wave of kites was launched and more than half of them were popped

### Requirement: Single shots only
Crosswind SHALL ban Spread and Rapid: their drops SHALL never fall, modules carried in SHALL be removed at once, and a run modifier SHALL NOT bring them back (a level's ban beats a run's only-this-power rule). Every volley SHALL be one shot.

#### Scenario: Carried-in modules
- **WHEN** the ship enters with Spread and Rapid and fights for 30 s
- **THEN** neither module is active after the first step and no step adds more than one player shot

#### Scenario: Spread Only run
- **WHEN** a Spread Only run reaches Crosswind and fights for 60 s
- **THEN** Spread is never active and no Spread drop is on screen

### Requirement: Kites ride the wind
Kites SHALL enter from the upwind edge (from the top in a lull), ride the wind faster than a shot drifts, bob about their height and leave when the wind carries them off or after 15 s. A player shot SHALL pop a kite in one hit for points inside the level's cap and send `kitePopped`; a kite that gets away SHALL send `kiteEscaped`. At most three fly at once, 3 to 5 per wave by route. Kites never harm the ship and draw only from the level's seed.

#### Scenario: Determinism
- **WHEN** the same level seed is played twice with the same inputs
- **THEN** the kites fly the same paths, and another seed flies different ones

#### Scenario: Riding the gust
- **WHEN** a strong wind blows on a kite older than 2 s
- **THEN** its sideways speed points with the wind

### Requirement: Crosswind briefing, radio and music
The urgent-mission card SHALL show one bold goal line and one how-to line, and the radio SHALL speak exactly one briefing call (`bonusCall.crosswind`, one sentence), as for every bonus level. The level SHALL request the score section `bonus-wind` (its `BonusLook.cue`) and fail soft, staying on the current section, while the song has none.

#### Scenario: Missing section
- **WHEN** Crosswind starts in a song without a `bonus-wind` section
- **THEN** the director sends no move and the music stays on its section

#### Scenario: Section present
- **WHEN** Crosswind starts in a song with a `bonus-wind` section
- **THEN** the director moves to it
