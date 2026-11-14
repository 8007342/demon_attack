# Arcade combat

## ADDED Requirements

### Requirement: Layered atmosphere
The arena SHALL show layered fog in depth: a horizon band, distant fog banks, ground fog over the lower terrain,
and one or two thin, slowly drifting sky sheets over the whole arena. Fog SHALL animate by evolving its shape,
not only by scrolling. Bullets, the player ship's hitbox, attack tells and the HUD SHALL never be covered by fog.

#### Scenario: Sky sheet over the ship
- **WHEN** a sky sheet drifts across the player's ship
- **THEN** the ship and every bullet stay fully readable, and the sheet's opacity near the ship stays at or
  below 12 %

### Requirement: Creatures are veiled by depth
A creature's colour, saturation and contrast SHALL shift toward the sector's fog colour with distance. Its
shields, armour, rank halo and health pips SHALL be hidden while it holds in the fog with an approaching wave,
and SHALL appear only as it comes out of the fog, before it can fire. Eyes and glows MAY show through the fog.

#### Scenario: Approaching elite
- **WHEN** an elite creature is part of the next wave still holding in the horizon fog
- **THEN** only its veiled body (and eyes) is visible, with no armour, halo or health pips

### Requirement: Waves arrive as a flock
Every wave and reinforcement group SHALL fly in from inside the fog as a flock: in several squadrons, with
individual speeds, launch delays and wingbeat phases, and flock steering, and SHALL settle into their formation
slots without a visible jump. Arrivals SHALL be deterministic for a given run seed. The wave's entrance window,
roster and targetability SHALL be unchanged: entering creatures cannot be hit and do not fire.

#### Scenario: Reinforcement group
- **WHEN** a reinforcement group of eight creatures arrives
- **THEN** they emerge from the fog at different moments and speeds, cluster and spread as they fly, and settle
  into their slots within the same entrance window as before

### Requirement: Arrivals cast shadows
Incoming creatures SHALL cast ground shadows whose offset, softness and opacity follow their altitude and fade
through ground fog, so arrivals can be seen coming before they clear the horizon band.

#### Scenario: Shadows ahead of a wave
- **WHEN** the next wave starts its approach
- **THEN** its shadows move across the terrain while the creatures are still veiled

### Requirement: The sentinel is foreshadowed
When a wave will bring a sentinel, its giant silhouette SHALL appear one or two waves earlier, far behind the
fog, flying a figure-eight that comes nearer and larger with each wave, until the sentinel arrives with its
escort swarm. The silhouette SHALL have no hitbox, SHALL NOT fire, and SHALL NOT change the encounter.

#### Scenario: Sentinel two waves ahead
- **WHEN** wave 1 of a level whose wave 3 brings a sentinel starts
- **THEN** a dark silhouette circles in a figure-eight far behind the fog, larger and nearer during wave 2, and
  the sentinel flies in with its swarm at wave 3

### Requirement: Reduced atmosphere
Settings SHALL offer a reduced atmosphere (fewer, static-texture fog layers and no sky sheets) that also serves
low-end devices.

#### Scenario: Reduced atmosphere
- **WHEN** the player selects reduced atmosphere
- **THEN** the horizon band and ground fog remain, the sky sheets are gone, and gameplay is unchanged
