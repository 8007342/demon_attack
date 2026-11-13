# Proposal: ground troops that read the terrain

## Why
The operator: the flyover's terrain relief "looks great", but the ground troops were built quickly and ignore it. They do not avoid climbs or ravines, and they never jump or climb. The audit (`plan/ground-terrain-interaction.md`) confirms this and finds worse:
- The lateral route cost is the raw height, so canyon floors are the *cheapest* place to go. Units steer into ravines on purpose.
- Routes probe only the unit's current depth, so units react to a mesa only once they are on it.
- The convoy's climb is measured with the demons' sign, so its uphill dust and `convoyClimbing` fire while it goes downhill.
- Units behind a crest are drawn standing on top of it.
- No ground unit casts a contact shadow.

## What Changes
- **Terrain navigation (`GroundNav`, new and pure).** A small screen-aligned lattice (48 columns × 36 depth rows) is refreshed incrementally from the displayed heights. Each cell gets a slope and **analytic tags** from the generator's feature records: ravine, cliff, plateau, valley floor, crest, brush and lane. One backward dynamic program per movement class and travel direction (a lateral flow field) gives every cell its best next column. All units share it, and it looks ahead by construction.
- **Four generic movement classes**: infantry, light vehicle, heavy vehicle and walker. Each has walk and climb slope limits and its own passability. Every existing unit maps onto one class, and the gargoyle ground army will too.
- **Links**: bridges and fords on every canyon, climb lines on mesas, infantry jump-downs and light-vehicle crest hops, all generated deterministically from the features. A link has a capacity, so units queue at it (convoy bunching).
- **Who obeys what.** Threat units take the nav column inside their side band, and their depth never changes. When blocked they grind across in a struggle pose. Skirmish units and allies take the nav column, and their depth speed follows the terrain pace. They queue at links.
- **Poses and tells.** `GroundPose` reports the slope along the unit's own travel and a movement state: walk, climb, descend, jump, ford, bridge, queue, avoid and grind. A unit on hidden ground is clipped behind the crest. A stepped pixel contact shadow, dust that follows the slope, and per-sector ford splashes are added.
- **Art.** Authored pitch, climb, descend, jump, wade and stride-over frames per class, via the Go pipelines. One ComfyUI shading keyframe per pose family. Later, a bridge prop per sector.
- **Radio.** `convoyFording`, `convoyBridge`, `troopsClimbing` and `enemyDetour`, each rate-limited.

## Capabilities
### New Capabilities
- `ground-terrain-navigation`: movement classes, the navigation field, terrain tags, links and their capacity, and the gameplay boundary.

### Modified Capabilities
- `arcade-presentation`: movement-state poses, hidden-ground clipping, contact shadows, slope dust and splash, the climb sign, and the new radio events.

## Impact
- New: `lib/game/ground_nav.dart`, plus tests.
- Changed (marked `// --- ground terrain` hooks):
  - `ground_war.dart`: `GroundPose`, `_placeGroundOnTerrain`.
  - `ground_war_v4.dart`: `_v4Route`, `_v4Steer`, `_v4Advance`, `_v4Convoy`.
  - `terrain_field.dart`: feature tags, `placeAt` sign and state, hidden flag.
  - `ground_painter.dart`: states, shadow, clip, dust.
  - `game_events.dart`: four names.
- Art: `tools/ground_troops`, the ground-forces pipeline, `art/families/ground-troops*.json`, `ground-forces*.json`, and the atlases (`ground-troops.png` grows to 20 × 7 cells).
- Docs: `plan/terrain-relief.md` (stale `_climbDust` reference), the style guide.

The threat front's rules, schedule, random stream and calibration are unchanged. With no relief installed, behaviour is identical to today.
