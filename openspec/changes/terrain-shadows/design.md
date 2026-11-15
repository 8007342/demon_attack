# Design: terrain-conforming shadows

Builds on `continuous-swarm` design §8 (the shadow pass), `ground-terrain-interaction` (`TerrainView`, the 25-column
screen mesh with `surfaceAt`, `yOf` and `heightAt`) and `fog-restoration` (ground fog transmittance).

## 1. What exists
- `Scene._shadowOf(Demon)` (`lib/game/scene.dart`):
  - centre at `Perspective.groundY(n)` plus a sun offset of `h · tan 32° · 0.22`, rotated by a ±4° sun drift;
  - three blur buckets by altitude (`k = h / 300`); alpha `0.95 · (1 − 0.4k) · groundLight`;
  - one `saveLayer` per bucket with the ink colour filter and a `drawAtlas` of cells.
- The ship shadow is a fixed-altitude caster (h = 40).
- The foreshadow shadow is an effects-atlas strip at nearness 0.08–0.4, alpha ≤ 0.2.
- `TerrainView` (`lib/game/terrain_field.dart`):
  - keeps per-frame grids `gridY` (visible surface screen y) and `gridHeight` over `rowZ` × 25 columns;
  - answers `surfaceAt(x, z)` with height, visible y, world slopes `slopeS` and `slopeW`, and a `hidden` flag behind a
    nearer crest.
- "Deformation" in the operator's words covers three things, and the projector honours all of them because it reads
  only `TerrainView`:
  - the per-sector relief;
  - the lane-relief and distance envelopes;
  - the cross-sector blend `mix` during travel.

## 2. The projector (`lib/game/shadow_projector.dart`)
A caster is `(x, z, h, footprint, kind)`, where:
- `x` is the screen/world lateral position;
- `z` is the ground depth under the caster, `GroundCamera.zOf(Perspective.groundY(n))` for flyers;
- `h` is the altitude in arena units, the same channel the swarm already publishes;
- `footprint` is the silhouette's ground size (cell plus scale).

**Hit point.** The sun ray leaves the caster with ground displacement `d = (h − t) · tan θ · 0.22` along azimuth `φ`,
where `t` is the terrain height at the landing point. Three fixed-point iterations are enough (the height field is
smooth at the mesh resolution):
```
t0 = 0; p_i = (x, z) + (h − t_i)·tanθ·0.22·(cos φ, sin φ·zStretch(z)); t_{i+1} = heightAt(p_i)
```
- `zStretch` converts a screen-space ground offset into depth at that row, so the offset reads the same as today's.
- When the result is flat (t = 0), the hit point equals today's centre exactly. Unit test: every shadow on a flat
  field matches the legacy centre within 0.01 units.

**Drape.** The silhouette is drawn as a 3 × 2 grid (4 × 3 vertices) on the ground plane around the hit point.
- Each vertex is moved to its surface position: `TerrainView.yOf(vx, vz)` for y, and x unchanged.
- The result is a sheared and stretched quad mesh. A shadow crossing a ridge bends over it, and a shadow in a valley
  sits on the floor.
- **Foreshortening by slope** comes from the vertices, with no extra term:
  - a slope facing away from the sun spreads the rows (longer);
  - a slope facing toward it compresses them.
- **Occlusion.** A vertex whose `surfaceAt(..).hidden` is true takes the crest line's y. Any cell whose four corners
  are all hidden is dropped. This is the same rule units use, so a shadow never shows through a hill.
- **Softness.** `k` is now `(h − t) / 300`, the caster's height above the surface it falls on, not above the flat
  plane. A creature low over a ridge casts a sharper shadow there, as the operator's "follow the relief" asks.

**Batching.** Vertices and texture coordinates go into one `Float32List` per (image, blur bucket) and are drawn with
`Canvas.drawVertices(Vertices.raw(...), BlendMode.srcOver, paint..shader = ImageShader(image))` inside the existing
bucket `saveLayer`.
- The images are the creature atlas, the effects atlas, the ship image and the boss atlas, so at most four draw calls
  per bucket.
- The layer cap stays three.
- About 60 casters × 12 triangles is about 720 triangles: negligible next to the terrain mesh.

**Fallback tier.** The flat placement (today's code path) is kept behind `ShadowMode.flat`. It is used:
- on `AtmosphereQuality.reduced`;
- when the frame-time governor already dropped the atmosphere tier;
- in the perf test's baseline.

**As built (task 1).**
- The projector works against a small `ShadowSurface` interface (`shadowLift`, `shadowDrape`) rather than
  `GroundRelief`; `TerrainView` implements both. `FlatShadowSurface` is today's plane, and the tests use synthetic
  surfaces (a ridge, a mesa) through the same interface.
- Positions are screen x and *flat-ground y* (`GroundCamera.yOf(z)`), not (x, z). An offset along flat-ground y is
  exactly the legacy screen offset, so `zStretch` is the identity in that frame and drops out.
- The terrain height `t` is measured in arena units, as the visible lift of the surface above flat ground (texel height
  × `GroundCamera.texel(z)`), so that `h − t` subtracts like units. Both lookups read the cached mesh grids
  (`gridHeight`, `gridY`), never the relief functions.
- The ship keeps its own legacy offset direction (lateral only, `ShadowProjector.shipDir`); flyers use
  `(cos φ, 0.25 + sin φ)`.
- "Rows spread on the slope facing away from the sun": with the sun behind the scene, shadows fall toward the camera,
  so that slope is the one facing the camera (the near side of a ridge). The ridge test checks exactly that.

**As built (task 2).**
- `DemonScene.shadowMode` is `ShadowMode.flat` on `AtmosphereQuality.reduced` and `draped` otherwise;
  `shadowModeOverride` forces either (tests, review strips, the perf comparison). There is no frame-time governor in
  the code base yet, so "the governor's low tier" is the reduced tier: a governor that drops the atmosphere to reduced
  drops the shadows to flat with it.
- The flat path is the legacy code verbatim (`drawAtlas` on a plane scaled by 0.42), and the legacy centre expression
  is kept as written, so the reduced tier is byte-identical. `test/terrain_shadows_scene_test.dart` compares the pass
  with `test/fixtures/shadow-flat-reduced.png`, rendered by the untouched pre-change pass.
- The draped path draws one `drawVertices` per image per bucket (`shadowDrawCalls`, `shadowDrawCallsPerBucket`),
  with a cached `ImageShader` per image (nearest sampling, as the atlas path) and vertex colours carrying each
  shadow's alpha (`BlendMode.modulate`).
- Softness `k = (h − t) / 300` drives the bucket, the alpha and the growth together, as the legacy `k` did, so a
  creature low over a ridge casts a sharper, darker and slightly smaller shadow there.
- Death ghosts keep their flat-ground point and are re-draped each frame while they fade.
- Measured (`test/atmosphere_perf_test.dart`, 61 casters, phone size ×3): recording 0.03 ms flat, 0.10 ms draped;
  CPU raster of the pass 64 ms flat, 68 ms draped (dominated by the blur layers, as before).

## 3. Casters
| Caster | Altitude source | Footprint | Notes |
|---|---|---|---|
| Ordinary creature | `Demon.altitude` (swarm patterns, dive ramp) | its current atlas cell | Unchanged alpha and buckets; only placement and drape change |
| Diver | the dive ramp down to 0 at the ship row | cell | The "converging tell" (§8.2 of continuous-swarm) now converges *on the terrain* under the ship |
| Sentinel (in play) | its altitude | effects-atlas shadow strip | The rush lock snap keeps targeting the ship's shadow hit point, not a flat point |
| Lurking sentinel (§4) | the foreshadow's virtual altitude, 220 down to 120 | strip × 2.5 | bucket 2, extra blur |
| Ship | fixed h = 40 | ship hull cell | From `FlyoverBackground.shipShadowVisible`; ground critters still duck under it |
| Boss | `boss-grandeur`'s boss altitude (default 160) | a boss shadow cell: the hull's alpha, area-downscaled ×0.5 and inked, baked once per hull load | alpha ≤ 0.35, bucket 2. It shrinks and fades as the boss climbs |

## 4. The lurking shadow
**Track.** `SentinelForeshadow` gains a `lurk` track, a presentation-only path on the ground:
- it starts at the far terrain under the silhouette's circling point (z ≈ 9 z0, near the fog);
- it ends at the ground-war front's depth (`GroundTuning.frontZ`, or z ≈ 2 z0 when there is no ground war);
- it moves at 10–16 units/s of screen travel with a slow lateral meander (amplitude 30, period 9 s);
- it is seeded from the run seed on its own stream (`seed ^ 0x5E57`), so the simulation's draws are untouched.

**Envelope.**
- Alpha is `0.30 · rise · groundLight`, where `rise` eases in over the first 3 s of the foreshadow.
- It is gated by ground-fog transmittance, so in thick fog it is a darkening, not a shape.
- The footprint grows 1.0 → 1.3 as the virtual altitude falls.
- The sun drift applies as usual.

**Hand-off.** When the sentinel's entrance begins, the lurking shadow's hit point is interpolated over 0.8 s onto the
in-play sentinel's projected shadow. Footprint and alpha are interpolated too, and the in-play shadow is suppressed
until then, so there is exactly one sentinel shadow at all times.

**Ground reaction.** Ground units and critters inside the lurking footprint use the existing duck or hesitate reaction
(`FlyoverBackground` critter duck; ground units slow their pace × 0.7 while covered). Presentation only: fire,
ranges and fronts are unchanged.

**Reduced motion.** The track still moves (it is slow), but without meander.

## 5. Determinism and tests
- **Pure projector tests** on synthetic `GroundRelief` fields:
  - flat equivalence;
  - a 30-unit ridge: the shadow centre lies on the ridge, and the drape rows spread on the far slope;
  - crest occlusion: every cell is hidden behind a nearer mesa;
  - morph: across `mix` 0 → 1 the hit point moves continuously, with no jump above 2 units per 1/60 s.
- **Scene tests:**
  - the layer count is still ≤ 3 and the draw count ≤ 4 per bucket;
  - the reduced tier is byte-identical to today's flat output on a fixed frame.
- **Review strips** (`test/terrain_shadows_review_test.dart` writes `art/contact/terrain-shadows-*.png`):
  - Hollow towers and Ringfall mesas with a swarm overhead;
  - a diver converging over a ridge;
  - the lurking shadow at 0 / 25 / 50 / 75 / 100 % of its track;
  - the boss shadow at two altitudes;
  - 360 × 780 and 1280 × 720.

## 6. Risks
- **Mesh cost.** `yOf` interpolates the cached grid, so there is no relief evaluation per vertex. Twelve vertex
  lookups per caster are cheap. Measured in the perf test.
- **Shimmer.** Vertices snap to the mesh as the camera scrolls. Vertex y is smoothed with the same sub-row
  interpolation `yOf` already uses. If needed, the drape is quantised to whole pixels after the warp, never before.
- **Readability.** Shadows on bright slopes get darker. The existing `groundLight` factor and the 0.9 alpha cap still
  apply, and bullets are never dimmed.

## 7. Decisions taken on the operator's behalf
- The drape is 3 × 2 cells, not per-pixel. It is enough to bend over a ridge at sprite scale and costs nothing.
- The lurking shadow is presentation only. It never telegraphs a gameplay event the player must react to (the rush
  keeps its own tell), so it can be atmospheric without fairness rules.
- The boss shadow ships here (it was missing). Its altitude coupling is owned by `boss-grandeur`.
