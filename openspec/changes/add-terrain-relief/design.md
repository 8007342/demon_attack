# Design: terrain relief, vegetation and terrain radio

The full design, API and event table are in `plan/terrain-relief.md`. Key decisions:

## Generator
- A pure, seeded function per sector and route (`TerrainField`): rolling value noise plus one feature per 300-texel segment from the sector's weights; every feature's support stays within its neighbours, so any distance is seamless. Hashing uses Park–Miller steps below 2^53 so the VM and the web agree.
- The lateral frame is distance from the nearer screen-edge line, the frame walls, landmarks and props already use. A centred world frame put most features under the walls or inside the faded lane; the edge frame keeps them in the side bands at every depth while they still grow as they approach.

## Drawing
- The ground is one indexed `drawVertices` mesh (25 fixed screen columns × ~100 fixed-depth rows) sharing the ground tile shader. Rows are clamped per column so terrain never rises again behind a nearer crest; hidden ground collapses on the crest line and gets a dark band.
- Light and fog are vertex colours (modulate) over a tile baked 1.8× brighter once per sector: a colour filter on the mesh cost ~5 ms of a 13 ms CPU raster.
- During travel both worlds share one blended relief (`mix` follows `environment`), so geometry morphs while textures crossfade.
- One surface API (`surfaceAt`/`yOf`) interpolates the same triangles the mesh draws, so sprites sit exactly on the drawn ground; with no relief it equals the flat camera.

## Gameplay boundary
- `GroundRelief.place` returns a pose; `GroundUnit.x/y` and `GroundAlly.x/y` use it when present. Rules (fire range, breakthroughs, collisions, ally removal by age) read `z`, `side`, `across`. Missile launch points, tracers and homing aim follow the visible pose, so they meet the drawn sprite. Without a relief (pure model tests) everything is flat as before.

## Performance (flyover_perf_test, 1080×1560 CPU raster, same loaded forge)
| | record steady | raster steady | record crossfade | raster crossfade |
| --- | --- | --- | --- | --- |
| before | 0.29 ms | 12.95 ms | 0.25 ms | 24.8 ms |
| after | 0.67 ms | 14.3 ms | 0.98 ms | 24.9 ms |

## Known gaps
- Ground units are drawn after the whole flyover, so a plant nearer than a unit can be overdrawn by it.
- Uphill slowing is visual (pace, dust); logical speed is unchanged by design.
