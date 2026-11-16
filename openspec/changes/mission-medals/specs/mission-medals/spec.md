# Mission medals

## ADDED Requirements

### Requirement: Missions are medals, not text
The run record card (the end-of-run medal screen and the final score card) and every scoreboard row SHALL show a run's modifiers (the bonus levels it met, its run rule) as mission medals, one per mission, and SHALL NOT show their names as visible text. Each medal SHALL carry the mission's name as its accessibility label and as a tooltip on tap.

#### Scenario: A run that met Supply Run under Heavy Ordnance
- **WHEN** the medal screen shows its run record
- **THEN** a Supply Run medal and a Heavy Ordnance medal stand where the chips were, the words SUPPLY RUN and HEAVY ORDNANCE are not on screen, and tapping a medal shows its name

#### Scenario: A scoreboard row
- **WHEN** the board lists a record with modifiers
- **THEN** its mission medals stand beside its regular medals, its note line keeps only the play date, and the row fits 360 logical pixels wide

### Requirement: Composable medal layers
A mission medal SHALL be composed at runtime from one hero atlas: the mission's ribbon, the shared medal base, the mission's accent (optional) and its emblem, stacked as whole aligned cells. Every catalogue bonus level and run modifier SHALL have its own ribbon and emblem; an id without layers SHALL wear the generic ribbon and emblem. A new mission SHALL need only its layers in the atlas.

#### Scenario: Every catalogue mission
- **WHEN** a record names each bonus level and run modifier in the catalogue
- **THEN** each has its own ribbon and emblem layers in the atlas

#### Scenario: A mission from a newer build
- **WHEN** a record names a mission this build does not know
- **THEN** its medal shows the generic ribbon and emblem and its label spells the id out

### Requirement: Medal art through the shared pipeline
The medal hero art SHALL be made through the shared asset pipeline (a rigkit family, ComfyUI hero renders, rigsheet finish and atlas), match the regular medals' palette and read at 20 logical pixels. The picked raw renders and the recipe SHALL be committed so the atlas rebuilds without a GPU, and the picks and their reasons SHALL be logged in the run ledger.

#### Scenario: Rebuilding the atlas
- **WHEN** the ComfyUI studio is unavailable
- **THEN** the committed picks and family rebuild `assets/images/mission-medals.png` and `lib/widgets/mission_medal_atlas.dart` with the command in `plan/render-runs/mission-medals.md`
