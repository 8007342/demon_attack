# Sector artwork and occupation progression

Five original background paintings were generated with the built-in imagegen tool, using the `imagegen` skill. They are project assets at `assets/images/sector-1.png` through `sector-5.png`; each is 1024 × 1536. They contain no original-game screenshot or sprite. Gameplay sprites remain original deterministic artwork.

Every prompt used the same production constraints: original intricate 16-bit pixel artwork, chunky crisp pixels and restrained dithering; portrait 2:3 composition; an almost empty dark central 60% firing lane; detailed objects concentrated around top corners, side edges and the horizon; sparse stars; near-black navy shadows with dim colored silhouettes; suspenseful science-fiction becoming progressively demonic; no characters, demons, player ships, bullets, text, UI, logos or watermarks.

| Level / file | Final scene prompt | Narrative visual role |
| --- | --- | --- |
| 1 / `sector-1.png` | Cold blue rocky lunar frontier; distant ringed ice planet; friendly small moon; tiny geometric human outpost beacons on rocky horizon. | The last safe frontier and human settlement. |
| 2 / `sector-2.png` | Violet vast gas giant with broad diagonal planetary rings; dense asteroid belt along sides; distant abandoned orbital satellites; purple cratered moon. | Leaving settlements behind, crossing an abandoned orbital corridor. |
| 3 / `sector-3.png` | Coral volcanic moon; jagged black basalt; dim red lava river horizon; huge eclipse; layered eclipsed moons with orange rim light. | A hostile forge world and route into occupied territory. |
| 4 / `sector-4.png` | Green abyssal void; ruined gothic demon towers on irregular floating rocks; dense clustered tiny moons; broken alien arches; eerie emerald nebula. | The swarm's conquered ruins and unnatural moon congregation. |
| 5 / `sector-5.png` | Red-black fortress planet with huge occult orbital ring; distant demonic shipyard with angular gothic towers; massive spiked orbital fortress silhouettes; blood-red storm clouds. | The carrier's origin, shipyard and storm fortress. |

`SectorBackground` adds separate moving moon constellations, scrolling star layers, slowly rotating orbital devices and beacon pulses. Each sector has distinct foreground geometry: frontier structures, asteroids, lava spires, gothic ruins, and occupied fortress towers. Solar-panel satellites turn into thorned relays deeper in demon territory. Later cycles increase orbital occupation and add red territorial markers along the edges; these stay outside the central firing lane.

Complete worlds crossfade with `DemonScene.environment`: both the source painting and its animated geometry blend. Travel begins shifting toward the next sector before arrival. Paintings use nearest-neighbor sampling and a dark veil so projectiles, vulnerable cores and creature silhouettes remain the brightest gameplay elements. Cinematic blackout boundaries and letterbox behavior are preserved. Salvage remains an active control phase and retains the normal ship and pickups.

Elite creatures use the existing animated atlas plus a rotating broken halo, outer armor plates and long horns. Each hit removes a plate and shortens the horns. This remains legible beyond the three intermediate atlas molts, up to seven hit stages, while preserving final angry forms.
