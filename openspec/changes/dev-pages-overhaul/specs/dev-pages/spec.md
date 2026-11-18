# Dev pages

## ADDED Requirements

### Requirement: Gallery scenes draw the current game
Every gallery scene SHALL draw with the game's own scene renderer and run its presentation pipeline each frame (backdrop, fog, the carrier director and hero hull, ground blocks, weather, perf tier) on a model started the way the game starts one. A scene SHALL NOT draw from a hand-built boss, a frozen copy of art or a fallback atlas the game no longer shows.

#### Scenario: The carrier scene shows the hero hull
- **WHEN** the operator opens `/gallery/?page=carrier`
- **THEN** each tile runs the console's carrier launcher for run 1 (fight, fast decay, approach)
- **AND** the carrier is drawn from the run's packed hero hull with its hatches and the emergence, as in the game

#### Scenario: A staged scene still runs the presentation
- **WHEN** a staged scene (creatures placed by hand) is shown
- **THEN** only the simulation step is frozen; the backdrop, fog, weather and perf tier advance as in the game

### Requirement: Scenes cover the shipped game areas
The gallery SHALL have scene pages for the swarm (creatures, elites, actions, insignia, dive shields), the ship's weapons, the sentinels, the carrier (run 1 and tours 2 to 5), the ground war, weather, bonus levels, the perf tiers and the mission medals.

#### Scenario: Weather strengths side by side
- **WHEN** the operator opens `/gallery/?page=weather`
- **THEN** three live sectors show drizzle, rain and downpour, forced through the game's rain override

#### Scenario: Perf tiers side by side
- **WHEN** the operator opens `/gallery/?page=perf-tiers`
- **THEN** one heavy scene is shown at the full, lean and lite tiers

### Requirement: Scenes are grouped and labelled
The gallery index and the studio's scene list SHALL group scenes by game area and label each with its title, whether it is staged or live, and the OpenSpec changes or specs it shows. Every source SHALL name an existing change, archived change or spec.

#### Scenario: Finding the carrier's sources
- **WHEN** the operator opens `/gallery/`
- **THEN** the CARRIER group lists the carrier scenes labelled `carrier-v3 · carrier-hatches · hatch-emergence · boss-grandeur`

### Requirement: Studio atlases are the game's
The studio's atlas list SHALL contain only sheets the game draws: no frontal boss sheet that no tour reaches, and no sheet the game keeps only as a loading fallback. It SHALL include the insignia, hatch-emergence, sentinel-silhouette and ground-wildlife sheets.

#### Scenario: No frontal boss hulls
- **WHEN** the operator filters the sprites tab by `boss`
- **THEN** no frontal hull (`boss-frigate.png` to `boss-dreadnought.png`) is listed

### Requirement: Shared navigation and a version slot
`/console`, `/gallery/` and `/studio` SHALL share one navigation bar linking all three (the current page marked) and one footer with a single slot for the build version, filled by the build-version change.

#### Scenario: From the studio to the console
- **WHEN** the operator presses CONSOLE in the studio's navigation
- **THEN** `/console` opens in the same tab

### Requirement: Staleness guard
Tests SHALL fail when a scene page lists an asset the game does not name, when the studio lists a fallback or unreachable sheet, when a tour would draw a frontal hull, or when a scene page fails to build.

#### Scenario: A stale sheet returns to the studio
- **WHEN** a change adds a frontal boss sheet back to the studio's atlas list
- **THEN** `test/dev_pages_test.dart` fails
