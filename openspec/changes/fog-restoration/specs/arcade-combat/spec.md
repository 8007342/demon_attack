# Arcade combat

## ADDED Requirements

### Requirement: World-anchored fog
Fog layers, ground-atmosphere bands, cloud shadows and the sentinel's foreshadow silhouette SHALL be anchored
to the world: they SHALL move only with their own drift and, for ground fog, with the terrain scroll. The
player ship's position and the steering input SHALL NOT move, shift or reshape any of them.

#### Scenario: Ship crosses the screen
- **WHEN** the player steers the ship from the left edge to the right edge
- **THEN** every fog layer and the sentinel's silhouette stay where the wind and the terrain put them, exactly
  as if the ship had not moved

### Requirement: Pervasive layered fog
The fog SHALL cover the whole depth of the field, from the upper sky down to the near ground, as several soft,
overlapping layers that add up, not as a single band. At least five air layers SHALL be interleaved with the
creatures by depth (an arriving creature rises through them one at a time), and the fog SHALL cover ground units
as well as creatures. The near-lane limits are in the scenarios. The ground-atmosphere art SHALL add to these
layers, not replace them.

#### Scenario: A wave rises through the fog
- **WHEN** the next wave sets out from the horizon toward its formation slots
- **THEN** each creature is first seen behind several fog layers, and the layers fall behind it one by one as
  it comes nearer, until it is clear in formation

#### Scenario: Near lane stays readable
- **WHEN** fog drifts over the near lane and the ship
- **THEN** the ship, bullets and lane units stay readable, the fog's combined opacity in the near lane is at most
  30 %, and over the ship it stays at or under the existing sky-sheet cap

### Requirement: Sentinel fades in through the fog
The sentinel's foreshadow silhouette SHALL fade in slowly (over about three seconds) far behind the fog, with
at least three soft fog layers drifting in front of it at their own winds, and the arriving sentinel SHALL fly
in from the silhouette's position through every fog layer before it reaches its hover. The silhouette sheet,
the figure-eight path and its growth per wave SHALL be kept.

#### Scenario: Silhouette in the cloud
- **WHEN** a sentinel is due one or two waves ahead
- **THEN** its silhouette slowly appears behind several drifting fog layers, its eyes glowing through the
  murk, and when its wave comes the sentinel emerges from that spot through the layers
