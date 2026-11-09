# Ground war combat

## ADDED Requirements

### Requirement: Demon ground forces
In sectors 1–4, demon ground units SHALL advance along the flyover ground plane using the background's perspective projection, staying in the side bands outside the central firing lane. They SHALL fire only from the near ground, after a telegraph of at least one second (launcher raise, then glow) and with a launch flash. Player shots SHALL pass over ground units; only homing missiles destroy them.

#### Scenario: Far units hold fire
- **WHEN** a ground unit is still beyond the near-ground fire line
- **THEN** it does not telegraph or launch

#### Scenario: Telegraphed launch
- **WHEN** a loaded unit reaches the near ground
- **THEN** it telegraphs for the full tell before a missile launches

#### Scenario: Shots fly over
- **WHEN** a player shot crosses a ground unit
- **THEN** the unit is unharmed and the shot continues

### Requirement: Fair ground missiles
A ground missile SHALL fly a fixed path to the player's x sampled at launch, without tracking, growing in drawn size as it approaches. It SHALL collide only once it reaches the ship's plane, with a hitbox matching its drawn warhead there. A hit SHALL count exactly like a hostile shot. Player shots SHALL NOT destroy missiles.

#### Scenario: Sidestep
- **WHEN** the ship moves one hitbox width away from the sampled x before the missile arrives
- **THEN** the missile misses and no life is lost

#### Scenario: Shielded hit
- **WHEN** a missile reaches a shielded ship
- **THEN** the shield is consumed and no life is lost

### Requirement: Homing missiles
Collecting the homing power-up SHALL fire three homing missiles automatically, each launched after the previous one hits. One missile SHALL destroy a ground unit; against air targets it SHALL deal one hit of 3 damage. The salvo SHALL combine with every other power and the shield, and survive a life loss.

#### Scenario: Sequential salvo
- **WHEN** homing missiles are collected with three ground units alive
- **THEN** exactly one missile flies at a time and all three units are destroyed by three successive missiles

### Requirement: Homing target order
Homing missiles SHALL target ground units first, the one closest to firing first; otherwise the highest-ranking air target: open carrier core, sentinel, elite, gold, coral, violet, teal; and finally the carrier's shield or closed core.

#### Scenario: Air fallback
- **WHEN** no ground unit is alive
- **THEN** the missile seeks the highest-ranking air target and deals 3 damage

### Requirement: Allied ground units
Allied units SHALL skirmish with some demon ground units, trading visible tracers. They SHALL never collide with the player or block shots, and SHALL never be destroyed: when overwhelmed they are totalled and retreat off screen. Destroying an engaged ally's attacker SHALL save it with a score bonus; no ally outcome SHALL penalise the player.

#### Scenario: Ally overwhelmed
- **WHEN** an engaged ally's health runs out
- **THEN** it limps off or its crew ejects, an `allyRetreated` event fires, and the player's lives and score are unchanged

#### Scenario: Ally saved
- **WHEN** a homing missile destroys an engaged ally's attacker
- **THEN** an `allySaved` event fires and the score increases
