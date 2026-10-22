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

## Named route scenery requirements

Every route variant must be identifiable by its scenery at ordinary phone size with the destination label hidden. A new name, tint, generic tower count or more tiny lights is insufficient. Keep the original sector palette and painting as a foundation, then change the silhouette, placement and scale of location-specific pixel-grid structures. Use at least one clear foreground/middle-distance landmark plus supporting details, concentrated around the arena edges and horizon. Parallax movement may be continuous; the artwork retains crisp pixels.

| Sector family | Route variants and required visual distinction |
| --- | --- |
| Krybor | Frontier: sparse outpost beacons and low shelters. Slums: dense irregular stacked dwellings, patchwork roofs and narrow gaps. Docks: recognizable docking arms/gantries, open berths and cargo stacks. Mountains: stepped peaks, ridges and sparse infrastructure. Command: orderly fortified terraces, command towers and antenna arrays. |
| Ringfall | Original ringed belt. Patrol Belt: repeated patrol relays and guarded lanes. Wreckfields: broken hull silhouettes and debris clusters. Shipyards: construction frames, docking ribs and unfinished hulls. Blockade: aligned defensive platforms and barriers. |
| Ember | Original volcanic moon. Ashlands: low ash dunes and sparse burned spires. Forges: furnace stacks and industrial channels. Crucible: enclosed crater walls around a concentrated molten basin. Brood Heart: clustered organic-looking pixel nests and a central pulsating furnace silhouette. |
| Hollow | Original floating ruins. Outskirts: sparse broken arches on separated rocks. Towers: prominent vertical gothic clusters. Catacombs: layered vault mouths and recessed crypt structures. Throne: a monumental symmetrical seat/keep surrounded by subordinate ruins. |
| Carrier | Original carrier territory. Brood Ark: clustered brood pods and large transport silhouettes. Siege Carrier: gun platforms and fortified outriggers. Brood Citadel: dense nested ramparts and spires. Brood Flagship: dominant command-fortress silhouette and organized escort infrastructure. |

Compare Slums against Docks explicitly in screenshot review. Their difference must survive the dark veil and small display scale: dense inhabited blocks versus open berths and cranes. Perform the same label-hidden comparison for the other families. Captions and arrival names must describe the visible destination, and the travel crossfade must reveal those landmarks before arrival.

Elite creatures use the existing animated atlas plus a broken halo, outer armor plates and long horns. Each hit removes a plate and shortens the horns. This remains legible beyond the three intermediate atlas molts, up to seven hit stages, while preserving final angry forms. New combat overlays must follow the fixed logical pixel grid and discrete frame rules in [style-guide.md](style-guide.md); scenery's continuous parallax is not permission to draw smooth vector creatures or fire.
