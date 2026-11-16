# arcade-combat

## Purpose
Provide readable, repeatable arcade combat against organic demon swarms and an evolving carrier boss.

## ADDED Requirements

### Requirement: Controls and permanent fire
The player SHALL move horizontally with arrow keys or a dedicated bottom touch trackpad, remain inside the arena, and fire automatically during combat.

#### Scenario: Touch movement
- **WHEN** the player drags in the controller panel
- **THEN** the ship follows horizontal movement without entering the panel

### Requirement: Lives and pause
Each run SHALL start with three lives. A single unprotected hit SHALL remove one life, grant brief respawn protection, and end the run at zero. Pause and backgrounding SHALL freeze combat.

#### Scenario: Lethal hit
- **WHEN** an unprotected ship is hit with one life remaining
- **THEN** combat ends and the final score is shown

### Requirement: Demon swarms and transformations
Four levels SHALL introduce faster organic swarms, individual predatory dives, and armored demons that visibly weaken after hits; advanced enemies SHALL enter angry final forms.

#### Scenario: Armored demon
- **WHEN** a multi-hit demon takes a nonlethal hit
- **THEN** its form changes and its remaining final form can attack more aggressively

### Requirement: Carrier shield and door
The boss SHALL fly low above the player, release flocks, and protect its core with a destructible shield followed by a sliding door. Core hits SHALL only count through an open door after the shield is depleted.

#### Scenario: Protected core
- **WHEN** a player shot strikes the boss with its shield active or door closed
- **THEN** the core does not lose health

### Requirement: Repeat cycles
Defeating the boss SHALL award points and a victory transition, then return to level one with slightly higher speed and additional demon and boss transformation stages on successive cycles.

#### Scenario: Victory
- **WHEN** the boss core is destroyed
- **THEN** the next cycle starts at level one with the score and remaining lives retained

### Requirement: Scores and powers
Kills SHALL award larger scores for stronger enemies and bosses. Collectible temporary spread, rapid-fire, and shield powers SHALL expire and display remaining time.

#### Scenario: Power expires
- **WHEN** the duration of a collected power elapses
- **THEN** its effect ends and normal firing or vulnerability resumes
