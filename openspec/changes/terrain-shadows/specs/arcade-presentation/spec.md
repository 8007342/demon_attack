# Arcade presentation

## ADDED Requirements

### Requirement: Terrain-conforming shadows
Every shadow caster (flying creatures, divers, sentinels, the player's ship and the boss) SHALL cast its shadow where the sun ray from the caster meets the visible terrain surface, including relief, crests, valleys and the blend between sector terrains during travel. The shadow SHALL follow the shape of the surface it falls on and SHALL be hidden where a nearer crest hides that ground.

#### Scenario: Shadow over a ridge
- **WHEN** a creature flies over a ridge between the player and the horizon
- **THEN** its shadow lies on the ridge's surface, bends over its crest, and lengthens on the slope facing away from the sun

#### Scenario: Shadow behind a crest
- **WHEN** a shadow falls on ground hidden behind a nearer crest
- **THEN** the hidden part of the shadow is not drawn

#### Scenario: Travel between sectors
- **WHEN** the terrain blends from one sector to the next during a transition
- **THEN** shadows move continuously with the changing surface, without jumps

### Requirement: Shadows on flat ground are unchanged
On flat ground a shadow SHALL appear exactly where, how large, how soft and how dark it appeared before this change. Shadows SHALL remain presentation only and SHALL never dim bullets.

#### Scenario: Flat ground unchanged
- **WHEN** a shadow falls on flat ground
- **THEN** its position, size, softness and darkness match the shadow before this change

### Requirement: Sentinel lurking shadow
While a sentinel approaches from the fog, before it takes its place in the fight, a broad, very soft shadow SHALL creep slowly along the ground from the far terrain toward the ground-war front, growing darker as the sentinel nears and fading in thick ground fog. Ground units it passes over SHALL visibly hesitate. When the sentinel emerges, the lurking shadow SHALL merge smoothly into the sentinel's own shadow so that only one sentinel shadow is ever visible.

#### Scenario: Approach
- **WHEN** a sentinel is foreshadowed in the fog
- **THEN** a large soft shadow moves slowly across the terrain toward the front lines, and ground units beneath it hesitate

#### Scenario: Emergence
- **WHEN** the sentinel rises out of the fog
- **THEN** its lurking shadow contracts onto its combat shadow without a second shadow or a pop

### Requirement: Boss shadow
The boss SHALL cast a large, soft shadow on the terrain using the same projection as every other caster, and the shadow SHALL become smaller and fainter as the boss flies higher.

#### Scenario: Boss climbs
- **WHEN** the boss gains altitude during its fight
- **THEN** its shadow on the terrain shrinks and fades accordingly

### Requirement: Shadow quality fallback
On the reduced atmosphere tier, or when the device cannot keep the frame budget, shadows SHALL fall back to flat-ground placement with a single sharp layer. Shadow drawing SHALL use at most three blur layers per frame on every tier.

#### Scenario: Reduced tier
- **WHEN** the atmosphere runs at the reduced quality tier
- **THEN** shadows are drawn flat with one sharp layer and gameplay is unchanged
