# Ground atmosphere: fog, mist, low cloud and battlefield smoke

The operator: "make sure that enemies at a distance are obscured or fogged out, maybe add some smoke and cloudy layers to add distance effect." This document specifies the **art layers** and the **visual targets**. The runtime fog and arrival code belongs to the agent changing gameplay code; Section 6 is the interface note for that work. OpenSpec change: `openspec/changes/ground-forces-rework/`.

## 1. What exists today

- **Ground fog** on the flyover mesh: `_groundFog(flatY)` in `flyover_background.dart`, 0.85 at the horizon falling to 0 about 110 px below it.
- **Unit brightness**: `GroundPainter.depthLight(z)`, 38% at the spawn depth (z 1400) rising to 100% at the fire line (z 400). Flames and flashes fog at half rate.
- **Swarm haze**: arrivals tinted dusk violet #454A74 at up to 60% between nearness 0.30 and 0.56 ([perspective.md](perspective.md)).

What is missing: distant units are dimmer but still crisp, so the far ground reads as a lit diorama rather than a battlefield seen through weather. There are no layers **between** depth bands, so nothing passes in front of a far unit and nothing hides an arrival.

## 2. Visual targets

The ground's depth is compressed into a thin screen band: z 1400 is y ≈ 215, z 900 is y ≈ 239, z 700 is y ≈ 258, z 400 is y ≈ 323 (`GroundCamera.yOf`). The atmosphere works in three depth zones:

| Zone | Depth | Screen y | What the player sees |
| --- | --- | --- | --- |
| **Far: the murk** | z ≥ 1150 | 172–226 | Shapes only. Units are dark silhouettes about 75–85% into the fog tint. Their **light pattern** shows through (Host eyes, Carillon's three upward dots, the Chapterhouse's lit windows: gargoyle guide Section 9). Low cloud and the horizon fog band drift across them |
| **Mid: the mist** | 750 ≤ z < 1150 | 226–254 | Silhouettes and faction colours return, 25–60% into the fog. Mist banks pass in front of some units and behind others, so units **emerge** from the mist as they approach |
| **Near: clear** | z < 750 | 254 and below | No fog tint beyond `depthLight`. Only battlefield smoke from wrecks and weapons, kept out of the lane |

**Density curve for unit tint** (target for the runtime; the art is tuned against it):

```
fogMix(z) = 0.82 × smoothstep(700, 1350, z)       # 0 at z ≤ 700, 0.41 at z 1025, 0.82 at z ≥ 1350
unit body colour   = lerp(body, fogTint[sector], fogMix)
emissive pixels    = lerp(emissive, fogTint[sector], fogMix × 0.5)   # warm eyes, cyan strips, flames
```

This replaces nothing: `depthLight` still dims; `fogMix` adds the colour of the air. Threat units (`ground-forces.png` rows 0–3) keep the existing `max(.62, depthLight)` floor and cap `fogMix` at 0.45, so a unit that can fire at the player is never lost in the murk (threat first).

**Sector fog tints** (starting points; the art pipeline samples each sector's horizon row of the sky strip and clamps to luma 0.10–0.22 and chroma ≤ 0.12, so no tint ever reads as ally cyan or demon warm):

| Sector | Fog tint | Character | Smoke tint |
| --- | --- | --- | --- |
| Krybor | #3A4458 | frost haze, blue-grey | `smoke[3]` #555B65 |
| Ringfall | #3D3550 | violet regolith dust | `smoke[2]` with violet 10% |
| Ember | #46302C | ash and heat shimmer, dark rust | `smoke[1]` #262A32 (soot) |
| Hollow | #2E3A35 | mire mist, grey-green | `smoke[3]` with green 8% |
| Carrier | #3A2836 | plum vapour off the hull | `smoke[2]` with plum 10% |

## 3. Layers

All layers are pixel art on the arena grid (1 texel = 1 arena unit at the depth they sit at), nearest-neighbour, with **stepped alpha**: 4 levels only (0.2, 0.4, 0.6, 0.8) plus fully transparent. This is the one family exempt from the binary-alpha rule; stepped alpha keeps the pixel look while letting the air be translucent. No smooth gradients.

| Layer id | Size (texels) | Tiles | Sits at | Parallax (× ship x offset) | Drift | Baked alpha | Runtime opacity | Blend |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `horizonFog` | 512 × 48 | x | bottom edge at y 226 (z ≈ 1150), top at y 178 | 0.08 | 1.5 units/s | 0–0.8 | 0.7–1.0 | srcOver |
| `lowCloud` | 512 × 40 | x | y 140–180, straddling the horizon | 0.04 | 4 units/s | 0–0.8 | 0.5–0.9 | srcOver |
| `midMistA` | 512 × 24 | x | depth-sorted as an object at z 1050 (bottom at y ≈ 230) | 0.20 | 3 units/s | 0–0.6 | 0.6–1.0 | srcOver |
| `midMistB` | 512 × 24 | x | depth-sorted as an object at z 850 (bottom at y ≈ 243) | 0.30 | −2 units/s (opposite) | 0–0.6 | 0.4–0.8 | srcOver |
| `cloudShadow` | 4 sprites, 128 × 40 | no | on the ground, z 600–1400 | 0.25 | 6 units/s | single level, colour #0A0716 | 0.10–0.22 | srcOver (dark ink at low opacity) |
| `smokeDrift` | 6 frames, 48 × 32 | no | above wrecks, burning ground, artillery impacts | n/a (world-locked) | rises 4 units/s, sways ±2 | 0–0.8 | 0.3–0.7; **≤ 0.30 inside the lane** | srcOver |
| `smokeWall` | 3 frames, 96 × 40 | no | long smoke from a burning wreck line or a Thurible (Tier B) | world-locked | 1 unit/s | 0–0.6 | 0.3–0.6; never inside the lane | srcOver |
| `dustVeil` | 512 × 16 | x | a thin band kicked up behind an advancing tide (z 900–1200) | 0.25 | follows the tide | 0–0.4 | 0–0.8 (rises with the `groundTide` surge) | srcOver |

**Per sector:** `horizonFog`, `lowCloud`, `midMistA`, `midMistB` and `dustVeil` exist once per sector (tinted and shaped for the sector). `cloudShadow`, `smokeDrift` and `smokeWall` are shared, drawn tinted by the sector's smoke tint.

**Shapes.**
- `horizonFog`: a soft, uneven bank whose top edge undulates with a 64–128 texel period. Densest (0.8) at the bottom rows next to the ground; thinnest at the top. Two or three darker "holes" per tile where far units can be glimpsed.
- `lowCloud`: flat-bottomed cloud deck pieces with stepped tops, the underside one step darker (lit from above). It crosses the horizon line so arrivals that come **over** the horizon are half hidden for the first second.
- `midMist`: thin horizontal wisps 3–8 texels tall with long gaps (at least 40% of the tile empty), so mist hides some units and not others. Never a solid band.
- `cloudShadow`: big soft-edged stepped blobs; they slide across the far and mid ground and dim what they cross.
- `smokeDrift`: a 6-frame puff from dense to thin; `smoke` ramp, 2–3 alpha levels, rounded but stepped.

## 4. Draw order

From back to front (only the new layers are marked **new**):

1. Sky, sky strips, mid ridges (unchanged).
2. **`lowCloud`** (back half: rows above the horizon).
3. Ground mesh with its `_groundFog` (unchanged).
4. Ground objects with z ≥ 1150, depth-sorted (units, plants, wrecks).
5. **`horizonFog`**.
6. **`cloudShadow`** (on the ground, before units nearer than 1150 are drawn).
7. Ground objects 1050 ≤ z < 1150; **`midMistA`** at z 1050; objects 850 ≤ z < 1050; **`midMistB`** at z 850; objects z < 850. The mists are entries in the same depth sort, so units emerge through them.
8. **`dustVeil`**, then **`smokeDrift`** / **`smokeWall`** at their world depth.
9. Tracers and ground fx; then the air war, the ship and the HUD (unchanged: **no atmosphere layer is ever drawn over the air layer**).

## 5. Rules

1. **Threat first.** Nothing in this family may hide a telegraph, a launch flash, the ground missile, a hostile shot, the ship or an IFF chevron. All layers draw below the air layer. Threat units cap `fogMix` at 0.45.
2. **Lane cap.** Inside the central lane (x 96–264) below y 300, combined atmosphere alpha is at most 0.30. `smokeWall` and `cloudShadow` never enter the lane below y 300.
3. **Luma cap.** Fog and smoke stay at luma ≤ 0.22 (tints) and ≤ 0.40 (lit smoke tops). They are never brighter than a unit's body.
4. **No signal colours.** No `demon_warm`, `ally_cyan` or gilt in any atmosphere pixel.
5. **Stepped, not smooth.** 4 alpha levels; no gradients; nearest-neighbour; parallax offsets rounded to whole arena units.
6. **Reduced motion.** Drift stops (layers stay, static); `smokeDrift` holds its densest frame and fades out; parallax stays (it follows the ship, which the player moves).
7. **Performance.** All layers together: at most 8 extra draw calls per frame (one `drawAtlas` for the tiled bands, one for sprites) and under 0.3 ms on the review harness.

## 6. Interface note for the runtime agent

This is the part to copy into the runtime work. Art drops in without code changes once these names exist.

**Atlas.** `assets/images/ground-atmosphere.png`, 512 px wide, stepped alpha (4 levels). Generated metadata `lib/game/ground_atmosphere_atlas.dart` (written by the art pipeline's `pack` step, never by hand) with:

```dart
abstract final class GroundAtmosphereAtlas {
  static const String file = 'ground-atmosphere.png';
  // Per sector s (0 Krybor .. 4 Carrier): Rect sources for the tiled bands.
  static Rect horizonFog(int s);   // 512 x 48
  static Rect lowCloud(int s);     // 512 x 40
  static Rect midMistA(int s);     // 512 x 24
  static Rect midMistB(int s);     // 512 x 24
  static Rect dustVeil(int s);     // 512 x 16
  // Shared sprites.
  static Rect cloudShadow(int i);  // i 0..3, 128 x 40
  static Rect smokeDrift(int f);   // f 0..5, 48 x 32
  static Rect smokeWall(int f);    // f 0..2, 96 x 40
  static const List<int> fogTint;  // ARGB per sector (Section 2)
  static const List<int> smokeTint;
}
```

**Layout.** Rows from the top: per sector, `horizonFog` 48 + `lowCloud` 40 + `midMistA` 24 + `midMistB` 24 + `dustVeil` 16 = 152 rows, × 5 sectors = 760 rows; then a 40-row strip of 4 cloud shadows; then a 32-row strip of 6 smoke puffs (288 px) and a 40-row strip of 3 smoke walls (288 px). Total 512 × 872 px (1.8 MB RGBA).

**What the runtime owns** (all of it the other agent's call; these are the targets the art is tuned to):

| Item | Target |
| --- | --- |
| Placement | Section 3 table: y bands, depth-sort slots (z 1050 and z 850), parallax factors, drift speeds |
| Opacity | The "runtime opacity" column, multiplied with the baked alpha; may vary by sector weather or the tide |
| Unit tint | `fogMix(z)` and the emissive half-rate rule in Section 2; threat units capped at 0.45 |
| Lane cap | Combined alpha ≤ 0.30 in x 96–264, y ≥ 300 |
| Arrivals | Far arrivals start inside the murk (z ≥ 1150) and walk out through `midMistA/B`; mid-field spawns may use the Host `arrive` (unearthing) frames instead ([ground-unit-animation.md](ground-unit-animation.md), Section 7.2) |
| Before the art lands | Flat bands in `fogTint` with the same alpha steps and y ranges are a valid placeholder; the art replaces them by name |

**What the art owns:** shapes, tints within the caps, the tile seams (every tiled band wraps seamlessly at 512), and the frame counts above.
