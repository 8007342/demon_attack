# arcade-combat

## Purpose
Provide readable, repeatable arcade combat against organic demon swarms and an evolving carrier boss.

## Requirements

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
Defeating each carrier SHALL continue the same run at LV1 with retained score, lives, powers and kill count. Later cycles SHALL increase speed, waves, roster size, species variety and multi-molt elites with stronger telegraphed attacks. Speed, waves and density SHALL have safe upper bounds.

#### Scenario: Victory
- **WHEN** the boss core is destroyed
- **THEN** the next cycle starts at level one with the score and remaining lives retained

#### Scenario: Two carrier victories
- **WHEN** the player defeats two carriers in one run
- **THEN** each return to LV1 retains the run and adds complexity compared with the preceding cycle

#### Scenario: Advanced elites
- **WHEN** an elite appears in later cycles
- **THEN** its extended damage forms are visible and its attacks are stronger but telegraphed

### Requirement: Scores and powers
Kills SHALL award larger scores for stronger enemies and bosses. Spread, rapid-fire and shield powers SHALL work concurrently with independent nine-second timers. Recollecting a type SHALL refresh only its timer. Expiry SHALL remove only the expired effect, and a shield hit SHALL consume only shield. Power time SHALL freeze outside combat and on pause; starting a new run SHALL clear all effects.

#### Scenario: Power expires
- **WHEN** one active power's duration elapses
- **THEN** that effect ends while the other active effects continue with their own remaining time

#### Scenario: Combined firing
- **WHEN** spread and rapid fire are active together
- **THEN** every rapid-fire volley includes the central and both angled shots

#### Scenario: Shield protects combined powers
- **WHEN** the ship is hit with spread, rapid fire and shield active
- **THEN** shield is consumed without losing a life or cancelling spread or rapid fire

#### Scenario: Refresh one modifier
- **WHEN** an already-active type is collected
- **THEN** only that type returns to nine seconds and other timers are unchanged
