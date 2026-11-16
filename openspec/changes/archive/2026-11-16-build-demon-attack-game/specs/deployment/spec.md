# Deployment changes

## ADDED Requirements

### Requirement: Score Worker and Durable Object
The deployed Worker SHALL serve `/api/scores` through a bound SQLite Durable Object and serve the bundled Flutter app for non-API routes.

#### Scenario: Mixed asset and API traffic
- **WHEN** a browser requests the app shell and then `/api/scores`
- **THEN** it receives Flutter assets and a JSON scoreboard from the same origin

### Requirement: Session branch
Development checkpoints SHALL be pushed to `game`; `main` SHALL only receive a stable release.

#### Scenario: Development checkpoint
- **WHEN** a working increment is committed this session
- **THEN** it is pushed to game without changing main
