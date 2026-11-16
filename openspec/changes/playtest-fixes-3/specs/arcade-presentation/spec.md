# Arcade presentation

## ADDED Requirements

### Requirement: Diving shields are one coherent shape
Every thermal diving shield (small, not-so-small, sentinel and the rush's crimson bow) SHALL be drawn as one continuous crescent whose colour bands share a single leading edge and thickness profile, in the creature's own frame, so that every part scales, turns and wears together at every creature scale and dive pose. Its nose SHALL lead the dive's heading. Segments SHALL be separated only by thin notches, and a spent segment SHALL remain as a dark ember outline so the crescent keeps its shape.

#### Scenario: A large diver close to the camera
- **WHEN** a three-point diving shield is drawn at 1.6 times scale
- **THEN** it reads as one crescent with two thin notches, with no columns offset from one another and no detached pieces

#### Scenario: Worn shield
- **WHEN** one point of a three-point diving shield is spent
- **THEN** the spent segment shows as a dark outline in its place and the other two keep burning

### Requirement: The berserk transformation reads as invulnerable
During a sentinel's rally and lock its crimson bow SHALL condense around it, and during the rush the bow SHALL be at full size, dimming as the rush shield wears. A hit that glances off a berserk sentinel SHALL show a white-hot star with sparks ricocheting away from the body for under 0.3 s.

#### Scenario: Shot during the transformation
- **WHEN** the player's shot strikes a sentinel in its rally
- **THEN** a deflect spark appears at the impact and the sentinel does not flash

### Requirement: One consistent sentinel shadow
A sentinel SHALL cast exactly one terrain-conforming shadow from its lurk through its rise, the fight and its rush, never disappearing. Every phase SHALL share one look and one size rule (the ground's nearness under it and the sentinel's altitude), so the size never jumps; in the fight it SHALL match the sentinel's drawn size, and on the lock it SHALL glide onto the ship's shadow point.

#### Scenario: From the lurk to the fight
- **WHEN** the lurking shadow hands over to the sentinel rising out of the fog and the sentinel takes its place
- **THEN** one shadow glides onto it, its size changes by less than a third, and it stays visible while the sentinel fights

#### Scenario: Rush
- **WHEN** the sentinel locks on and charges
- **THEN** its shadow glides onto the ship's shadow point and grows with the nearer ground, never vanishing

### Requirement: Background fills the band above the arena
When the viewport is taller than the bottom-aligned arena, the band above it (where the toasts appear) SHALL always show the live background up to the top of the viewport: the sector sky and its parallax particles, the high fog and, during transitions, the cloud cover. No gameplay SHALL be drawn or placed in that band: no creature, shot, spawn, target or HUD collision. Inside the arena the background SHALL be unchanged.

#### Scenario: Phone portrait without a toast
- **WHEN** the game is played at 360 × 640 or 390 × 844 and no toast is showing
- **THEN** the band above the arena shows the sky and fog to the top of the screen, with no empty strip

#### Scenario: A creature above the arena
- **WHEN** a creature or a shot is above the arena's top edge
- **THEN** it is not drawn in the band

### Requirement: The sector change flies straight up
The sector-change transition SHALL read as the ship climbing straight up: the world SHALL not bank, the camera pitch SHALL begin with the climb in clear air so the horizon and ground visibly fall away below the ship before the cloud, the band the pitch uncovers SHALL show deep sky until the cloud comes in, and the pursued flock SHALL climb ahead of the ship with no sideways stream, fanning out to its side only in the Descent.

#### Scenario: Leaving a sector
- **WHEN** a sector is cleared and the Pursuit begins
- **THEN** the world drops straight down under the climbing ship with no roll and the flock rises ahead of it
