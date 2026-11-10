# Gameplay round 3 progression

## ADDED Requirements

### Requirement: Visible breakthrough drama
- Sectors 1–2 SHALL never fire at the player.
- In sector 2, some demon units SHALL be stopped by the allies just short of fire range, with a `groundNearMiss` event.
- Sectors 3 and 4 SHALL guarantee at least one breakthrough per sector visit. It SHALL be telegraphed by `allyUnderAttack` and `groundBreakthroughWarning` before `groundBreakthrough`.
- Sector 4 SHALL keep regular breakthroughs.

#### Scenario: Near miss
- **WHEN** a near-miss unit approaches in Ringfall
- **THEN** its ally destroys it within 22 texels of the fire line, `groundNearMiss` fires, and no ground missile is launched

#### Scenario: Guaranteed breakthrough
- **WHEN** nothing has broken through 9 s into an Ember Moon visit
- **THEN** the next arrival is unescorted and out of homing lock until it reaches fire range, and the warnings precede its breakthrough

### Requirement: Console starts
A console start SHALL begin a fresh run at the chosen sector, route and difficulty, at 0 points with the starting lives, with earlier routes counted as won. Normal scoring and top-10 rules SHALL apply.

#### Scenario: Sentinel jump
- **WHEN** the console starts a sentinel encounter
- **THEN** the run is on route 2 or later, at a wave whose roster includes a sentinel
