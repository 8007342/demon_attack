# Gameplay round 3 presentation

## ADDED Requirements

### Requirement: Shared events for radio and music
The model SHALL queue these structured events through the shared game-event queue, with exactly these names:
- `playerDestroyed`, `regroupStart` and `playerRespawn` for the life-loss sequence;
- `divePrep`, one beat (0.5 s) before every dive tell;
- `groundNearMiss` and `groundBreakthroughWarning` for the ground war.

#### Scenario: Dive radio
- **WHEN** a demon is about to dive
- **THEN** `divePrep` fires about half a second before its telegraph starts

### Requirement: Console page
The `/console` web route SHALL show console-styled buttons to start any sector 1–5 on any run 1–5 at any difficulty, with quick jumps to the boss and a sentinel encounter. Every other path SHALL open the arcade unchanged.

#### Scenario: Open the console
- **WHEN** the browser navigates to `/console`
- **THEN** the console page renders its selectors and the launch, boss and sentinel buttons
