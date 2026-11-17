# Arcade combat

## ADDED Requirements

### Requirement: Seeded wind on regular levels
A seeded run SHALL choose each regular level's wind from the run seed, the route and the sector alone: about one eligible level in five SHALL be windy, as a breeze or a gale. The run's first sector, the carrier's sector, bonus levels other than Crosswind and unseeded runs SHALL be calm, so every calibration gate runs without wind.

#### Scenario: Frequency
- **WHEN** the plans of 2000 run seeds over three routes and sectors 1 to 4 (route 0 sector 1 excluded) are drawn
- **THEN** between 17 % and 23 % of the levels are windy, and both the breeze and the gale occur

#### Scenario: Unseeded run
- **WHEN** a run starts without a run seed
- **THEN** no level has wind and no shot carries any wind drift

### Requirement: A swinging, bounded wind field
A windy level's wind SHALL be a deterministic function of its seed and the level clock: a lateral strength and an along-screen strength, each within -1 and 1, whose direction swings every few seconds, with occasional short gusts. The plan SHALL be finite (at most 400 changes over 900 s).

#### Scenario: Determinism
- **WHEN** two fields are built from the same spec
- **THEN** they sample identically at every time

#### Scenario: Swings
- **WHEN** any gale field is sampled over its first minute
- **THEN** it blows both left and right at more than 0.3 of full strength

### Requirement: Wind drifts every projectile
Every projectile, the player's and the demons' alike, SHALL pick up the wind's sideways drift, settling toward the wind's speed with a 0.55 s time constant and never exceeding it (34, 52 and 60 u/s at full breeze, gale and crosswind). A strong wind SHALL carry a shot about a target's width off its line by the swarm's rows.

#### Scenario: Both sides drift
- **WHEN** a gale blows at more than half strength for 40 s of a fight
- **THEN** settled player shots and settled hostile shots both drift with the wind, none faster than its drift

#### Scenario: Size of the push
- **WHEN** a shot climbs from the ship's row to y 140 in a steady full gale
- **THEN** it lands 12 to 30 units downwind of its line

### Requirement: A tailwind adds one grid step at most
A projectile fired while the along-screen wind at its back is at least half strength SHALL fly exactly one hostile speed-grid step (15 u/s) faster along its own track for its whole flight, and never slower; otherwise its speed SHALL be unchanged. The step keeps the fire-rate-tune anti-strobe grid (whole quarter units per 60 Hz step).

#### Scenario: Bounded speed-up
- **WHEN** a seeded gale fight runs for 60 s
- **THEN** every projectile's along-track wind speed is 0 or 15 u/s in its own direction of travel, and some are 15

### Requirement: Demons fight the wind
The wind SHALL push each demon a little sideways and the demon SHALL lean into it, yielding far less than a shot: ordinary creatures at most 24 % of the wind, heavier species, elites and escorts less, sentinels 8 %, and a committed dive less again. The push SHALL stay within the arena and fade when the wind drops.

#### Scenario: Ranks
- **WHEN** the yields of an ordinary creature, a heavier species, an elite and a sentinel are compared
- **THEN** each is below 0.3 and they fall in that order (heavier and elite below ordinary, sentinel lowest)

#### Scenario: Bounded push
- **WHEN** a gale blows for 30 s of a fight
- **THEN** some demons are pushed more than a unit and none by more than drift x 0.24 x 0.6 s plus a unit

### Requirement: The wind is telegraphed
Every change of the wind SHALL be planned at least 1.5 s before it begins to push. A big swing (0.6 of full strength or more) or a gust SHALL send `windGust` exactly then, with `from`, `to`, `gust`, `strength` and `endIn` 1.5; `windStart` and `windStop` SHALL mark the wind rising and dying away.

#### Scenario: Lead time
- **WHEN** a seeded gale fight runs for 90 s
- **THEN** more than three `windGust` calls are sent, and each is followed by a planned change 1.5 s later (one step of slack)
