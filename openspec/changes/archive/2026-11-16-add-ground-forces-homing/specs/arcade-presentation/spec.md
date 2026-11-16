# Ground war presentation

## ADDED Requirements

### Requirement: Ground units on the flyover camera
Ground units, allies, wrecks and skirmish tracers SHALL be drawn on the flyover ground with its projection, small and subdued at the horizon and full-bright on the near ground, between the background and the air combat. Demon units SHALL use warm threat accents; allies SHALL use cyan/teal friendly accents. Both SHALL be distinguishable from the decorative ground creatures. Retreating allies SHALL show sparks, smoke and limping or an escape pod, never death imagery.

#### Scenario: Approach
- **WHEN** a ground unit approaches from the horizon
- **THEN** it grows and brightens on the ground plane without entering the central lane

### Requirement: Readable missiles and homing
Ground missiles SHALL show their launch flash, a smoke trail, a size that grows toward the ship and a marker where the path crosses the ship's plane. Homing missiles SHALL show a cyan exhaust and a lock-on reticle on their target. The ship SHALL show its loaded homing pylons, including in the transition loadout glyph, and the HUD SHALL show a HOMING row with its remaining missiles.

#### Scenario: Lock-on
- **WHEN** a homing missile is in flight
- **THEN** a reticle marks its current target

### Requirement: Ground war events and hints
Ground-war moments SHALL leave the simulation through one no-op-safe dispatcher with stable names (`groundForceSighted`, `groundForceInRange`, `groundMissileLaunch`, `homingPickup`, `homingLaunch`, `homingHit`, `groundUnitDestroyed`, `allyUnderAttack`, `allySaved`, `allyRetreated`, `fleetIntact`) for music and commander callouts. Arrival hints SHALL teach sidestepping ground missiles and collecting homing missiles after ground forces first appear.

#### Scenario: No listeners
- **WHEN** no music or comms consumer is registered
- **THEN** dispatching events has no effect on play
