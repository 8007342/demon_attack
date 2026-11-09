# 64-grid combat sprites

## ADDED Requirements

### Requirement: Same footprint, more detail
Combat creatures SHALL be authored on a 64 × 64 logical grid with a bounded palette, hard edges and discrete frames, and SHALL render at the same arena size as before so hitboxes and readability at phone size are unchanged.

#### Scenario: Creature size
- **WHEN** an ordinary demon is drawn
- **THEN** it occupies 40 × 40 arena units (44 when angry), sampled nearest-neighbour from its 64 × 64 cell

### Requirement: Articulated wing stroke
Ordinary demons SHALL flap through eight distinct poses per 0.5-second stroke in which roots, forearms and fingers articulate separately; sentinels SHALL hold eight poses for 0.4 seconds each, with recovery folding the span below 70 % of full span.

#### Scenario: Recovery folds
- **WHEN** a sentinel reaches its recovery pose
- **THEN** its silhouette is narrower than 70 % of its level pose

### Requirement: Visible equipment
Each species SHALL show armour, a rank insignia and a weapon mount that animates when that creature fires; elites SHALL show authored plates that shed one level per hit.

#### Scenario: Creature fires
- **WHEN** a hostile shot leaves an ordinary demon
- **THEN** the demon plays its weapon-fire frames and a muzzle flash appears at the shot's spawn point

### Requirement: Per-side cannon presentation
The cannon that fired SHALL play its own recoil and muzzle-flash frames while the other rests, and module muzzle anchors SHALL equal the projectile spawn points.

#### Scenario: Alternating wing cannons
- **WHEN** a wing module is fitted and two volleys are fired
- **THEN** the left cannon recoils on the first and the right cannon on the second
