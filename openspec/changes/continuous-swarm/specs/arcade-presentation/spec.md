# Arcade presentation

## ADDED Requirements

### Requirement: Creatures are shown banking most of the time
Ordinary creatures SHALL use their banked-left and banked-right flight renders whenever they move sideways with purpose: swoops, sweeps, mills and dives. Squads SHALL bank together. Over a minute of Normal sector-2 combat, at least half of the drawn flight frames SHALL be banked renders, and no direction SHALL be held for less than 0.28 s.

#### Scenario: Sweeping squad
- **WHEN** a squad sweeps across the arena
- **THEN** its members are drawn in their banked renders facing the direction of travel, and turn together at the end of the sweep

### Requirement: Every flying creature casts a shadow
Every creature in flight SHALL cast a silhouette ground shadow: arriving, fighting, diving and re-entering. Each shadow SHALL be offset along the sun by the creature's altitude, softer and fainter the higher it flies, and veiled by the ground fog. Shadows SHALL persist in the front row and move with the swarm. A creature SHALL lose its shadow only when it dies. Creatures waiting in the deep fog SHALL cast none. Shadows SHALL be drawn under bullets and the ship.

#### Scenario: Front row
- **WHEN** a squad mills in the front row
- **THEN** its shadows circle on the ground beneath it, shifting as the ring turns

### Requirement: The ship's shadow joins the swarm's
The ship SHALL cast a silhouette shadow on the same sun as the creatures. A diving creature's shadow SHALL visibly converge on the ship's shadow as it closes in. A creature whose shadow falls across the ship SHALL dim the ship by at most 15 %, never dimming bullets or the ship's outline below the readability floor. A coming sentinel SHALL cast a faint, large shadow over the distant terrain while it circles in the fog.

#### Scenario: Diver overhead
- **WHEN** a gargoyle dives straight at the ship
- **THEN** its shadow slides onto the ship's shadow, and the ship darkens slightly as the diver passes over it

### Requirement: Swarm depth is published for the fog
Every creature SHALL publish its nearness, its altitude and its swarm state (reserve, approaching, present, diving, re-entering). The fog layers SHALL decide how to draw and veil creatures from these values alone. Arrival paths SHALL cross every fog band, and a rising sentinel SHALL take at least 0.6 s per band.

#### Scenario: Rising through the layers
- **WHEN** a skein leaves the reserve
- **THEN** it rises through each fog band in turn on its way into the fight
