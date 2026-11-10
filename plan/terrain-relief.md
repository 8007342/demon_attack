# Terrain relief, vegetation and terrain radio

The flyover's ground is a scrolling heightfield, not a flat plane. Hills,
ridges, valleys, canyons and mesas bend the projected ground; per-sector
vegetation stands on it; the ground fleet drives over it and pushes through
the plants; the comms hear about it. OpenSpec change: `add-terrain-relief`.

Everything here is **visual and positional**. The fire range gate,
breakthroughs and collisions are still decided by each ground unit's logical
depth `z`, its side and its band position `across`. The relief only changes
where a unit is *drawn* (and where homing missiles and tracers aim at it).

## Generator (`lib/game/terrain_field.dart`)

`TerrainField(sector, route)` is a pure function of world position: `s`
across and `w` along the ground (texels; the camera sits at
`w = distance / 2`). The lateral frame is the same one the walls, landmarks
and props use: `|s|` counts texels from the nearer screen-edge line (`s < 0`
on the left), so features hug the side bands at every depth and grow as
they approach. Seed: `4099 + 131·sector + 17·route`, so
every route of every sector has its own endless relief, identical on every
device (Park–Miller hashing, products below 2^53, like the flyover's).

- **Rolling hills**: two octaves of value noise (70 / 32 texels across,
  230 / 95 along) at the sector's `roll` amplitude (9–12 texels).
- **One feature per 300-texel segment**, picked from the sector's weights.
  Its support stays inside its own and the neighbouring segments, so any
  distance is seamless and no two identical notable features follow.

| Feature | Shape | Typical size (texels) |
| --- | --- | --- |
| ridge | a chevron crest across the whole field, wavering | 24–34 high, 42–56 half-width |
| valley | a trough along the ground on one side with raised lips | 17–22 deep, 125 half-length |
| canyon | a flat-floored cut with steep walls and a low rim | 26–34 deep, 10 half-width |
| mesa | a flat-topped plateau with a stepped edge and talus | 30–42 high |
| forest / crystalField / ruins | gentle hummocks carried by dense vegetation | 4–6 |

| Sector | Identity (weights) | Sky light |
| --- | --- | --- |
| Krybor | rolling ice hills, ridges, frost-pine forests, crystal fields | cold, from the left |
| Ringfall | mesas, crystal fields, wreck ruins, a few canyons | violet, from the right |
| Ember | canyons and basalt mesas, cinder forests | warm eclipse, from the right |
| The Hollow | sunken valleys between ruins and fungal groves | green, from the left |
| Carrier | sinew ridges and torn canyons, thorn thickets | red, from the right |

The light comes over the ship's shoulder (toward the horizon), so the
slopes facing the camera catch it and the ground vanishing behind a crest
falls into a dark band.

## Projection and drawing (`TerrainView`, `FlyoverBackground`)

- A height `h` (texels) at depth `z` lifts the ground by `h · 2·z0/z` arena
  units, the same scale as every sprite at that depth.
- **Envelopes**: relief is kept at up to 18% in the central lane (zero on
  the centre line where the two side frames meet, 18% at |x − 180| = 56,
  full beyond 100) and fades out between `6·z0` and `12·z0`, so the horizon
  line never moves.
- **Mesh**: 25 columns at fixed screen x (15 units apart) × ~100 rows at
  fixed depths (2.5–7 units apart in flat screen y, from `0.75·z0` below the
  screen to the horizon). Each column is clamped so it never rises again
  behind a nearer crest (no overhangs); hidden ground collapses onto the
  crest line. One indexed `drawVertices` with the sector's ground tile as an
  `ImageShader` (nearest neighbour, repeated), far rows first.
- **Light and fog** live in the vertex colours (modulate) over a copy of the
  ground tile baked 1.8× brighter once per sector, so flat ground stays at
  82% of the tile while lit slopes and high ground reach about 155% and
  shadowed ones 25%; times the sector's light colour and the old 110-unit
  distance fog (no longer a separate draw). A colour filter on the mesh
  itself cost a third of the frame, hence the bake.
- During travel both worlds share one blended heightfield (`mix` follows the
  environment), so the relief morphs while the textures crossfade.
- Walls ride the relief at their inner edge; landmarks, props, creatures and
  vegetation stand on the surface under their centre.
- Reduced motion freezes flight (so the relief stops scrolling), idle sway
  and toppling (pushed plants jump to their settled frame, no particles).

### API

| Call | Returns |
| --- | --- |
| `TerrainView.surfaceAt(x, z)` | `TerrainSample`: effective `height`, visible screen `y`, world `slopeS`/`slopeW`, `hidden` |
| `terrainHeight(x, z)`, `yOf(x, z)` | the same height / visible y (exactly where the mesh draws that ground point) |
| `place(side, across, width, z, {ally})` | `GroundPose(x, y, climb, pace)` — implements `GroundRelief` |
| `vegetation([zNear, zFar])`, `vegetationOf(field, …)`, `vegetationAt(x, z)` | the stateful plants on the ground |
| `FlyoverBackground.relief` | the view synced to the flight distance |

`place` keeps the unit's depth, side and band. It probes five lateral
offsets within ±32% of the band room, soft-minimises height plus a centring
cost (so units follow valley floors and wind around mesas), never crosses
the lane edge, stands on the visible surface, and reports the slope along
travel (`climb` > 0 uphill toward the camera) and a visual `pace` (0.5–1.25,
slower uphill).

### Ground-war hook (`lib/game/ground_war.dart`, sections `// --- terrain`)

- `GroundPose`, `GroundRelief`, `GroundWar.relief` (null keeps flat ground).
- `GroundUnit.pose` / `GroundAlly.pose`; their `x` and `y` getters use the
  pose when present.
- `_placeGroundOnTerrain()` at the end of `_updateGround` refreshes poses.
- The flyover installs itself every frame (`model.ground.relief = relief`).
- `GroundPainter` throws dust behind climbing units (`_climbDust`).

## Vegetation

Ten species, two per sector (`art/families/flyover-vegetation.json`,
`lib/game/vegetation_atlas.dart`): frost pine and ice-crystal shrub (Krybor),
ring crystal and satellite scrap (Ringfall), cinder tree and ash thorn
(Ember), grave fungus and ruin rubble (Hollow), sinew thorn and brood stalk
(Carrier). Kinds: tree, crystal, brush, stalk, debris.

Plants are seeded per 24-texel cell and side (two slots), denser inside
forest / crystal-field / ruins features (themed species), and sit in the
side bands with the units' `across` coordinate, so they never stand in the
lane. Frames (each also mirrored): idle A/B (slow sway), bend A/B, break A–C
and settled — a tree bends and topples, a crystal cracks and shatters to a
stump, brush flattens, a stalk snaps and droops, debris tumbles while it is
shoved aside along the ground. A push spawns seven particles (dust plus
needles, shards, splinters, spores or ash). Any live demon unit or ally
whose footprint meets a plant pushes it (direction: away from the unit);
the plant stays down until it scrolls away.

## Terrain radio (`TerrainRadio`, names in `GameEventNames.terrain`)

Emitted through `dispatchGameEvent` while in combat (not during travel).
Data always has `sector` (1–5) and `side` (`left` | `right` | `both`).

| Event | When | Limit | Extra data |
| --- | --- | --- | --- |
| `terrainAhead` | a notable feature enters 3.2–4.2 `z0` ahead (~25–35 s out) | 12 s apart; one per kind per 30 s; each feature once | `kind`: ridge, valley, canyon, mesa, forest, crystalField, ruins |
| `convoyClimbing` | a visible ally holds a climb > 0.18 for 0.4 s | 15 s apart | x, y |
| `convoyClearingVegetation` | an ally pushes a plant | 12 s apart | `kind`, `species`, x, y |
| `convoyStuck` | rare: an ally grinds a climb > 0.4 for 1 s | 45 s apart, once per wall | x, y |

Suggested lines (comms owns them): "Rough terrain ahead, crawling over the
ridge!", "Mesa on the left, going around!", "Clearing the tree line!",
"Crystals everywhere down here!", "We're stuck on the wall — give us a
second!". `mesa` is an extra `terrainAhead` kind beyond the original list;
comms may treat it like `ridge`.

## Performance

Measured with `test/flyover_perf_test.dart` (1080×1560 CPU raster, same
loaded forge, back to back): before 0.29 ms record / 12.95 ms raster steady,
0.25 / 24.8 ms crossfade; after 0.67 / 14.3 ms steady, 0.98 / 24.9 ms
crossfade (raster +10% steady, +0% crossfade; the earlier idle-machine
baseline was 11.4 / 20.6 ms). The ground is one
`drawVertices` (~2 500 vertices, index buffer built once, position / texture
/ colour buffers reused), the fog gradient draw is gone, and vegetation adds
one `drawAtlas` per world.
