# Proposal: terrain relief, vegetation and terrain radio

## Why
The user loves the parallax flyover and asked to push it further: "bend it dynamically, so the ground has mountains and valleys that the ground fleet must navigate to make progress. They might need to push some trees and vegetation out of the way, more for the radio chatter, which should match what we see below."

## What Changes
- **Terrain relief.** The ground plane becomes an endless, seeded heightfield per sector and route: rolling hills plus one feature per world segment (ridge, valley, canyon, mesa, or a forest / crystal field / ruins), in each sector's identity. It is drawn as one textured `drawVertices` mesh displaced by height, lit by the sector's sky with slope shading, and fogged with distance. Relief is gentle in the central firing lane and fades out toward the horizon.
- **One surface and projection API** (`TerrainView.surfaceAt`, `terrainHeight`, `yOf`): walls, landmarks, props, creatures, vegetation and ground units all stand on the same surface.
- **Vegetation and obstacles** per sector (alien trees, crystal shrubs, fungal stalks, thorn brush, ruined debris) from a new Go pipeline (ComfyUI keyframes for shading, authored frames, sector palettes, offline rebuild). Ground units push through them: trees bend and topple, crystals shatter, brush flattens, stalks snap, debris is shoved aside, with dust, needles, shards, splinters and spores.
- **Navigation** (`GroundRelief.place`): units keep their logical depth, side and band but wind toward valley floors and around mesas, ride the visible surface, and report a climb and a visual pace; climbing units throw dust.
- **Terrain radio events**: `terrainAhead {kind, side}`, `convoyClimbing`, `convoyClearingVegetation`, `convoyStuck` (rate-limited) through the shared dispatcher.
- Travel crossfades morph one blended relief between sectors; reduced motion freezes the scrolling and toppling and keeps the static relief.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `arcade-presentation`: the flyover ground relief, vegetation, units on the relief, terrain events.

## Impact
New: `lib/game/terrain_field.dart`, generated `lib/game/vegetation_atlas.dart`, `assets/images/flyover-vegetation.png`, `tools/vegetation/` (Go, stdlib), `art/families/flyover-vegetation*.json`, `art/sprites/sources/vegetation/`, `art/contact/flyover-vegetation-contact.png`, `test/terrain_relief_test.dart`, `plan/terrain-relief.md`. Changed: `flyover_background.dart`, `sector_background.dart`, `game_events.dart` (four names), small `// --- terrain` hooks in `ground_war.dart` and `ground_painter.dart`. Gameplay rules, tuning, checkpoints and score are unchanged.
