# Design: The carrier rendering engine (carrier-render-engine)

## Inputs and citations
- The operator's round 3b, C3 in `plan/operator-feedback-2026-11-16.md`.
- The research is in `plan/carrier-render-engine-research.md`. The IDs used here (`[D4]`, `[X1]`, `[F5]`, `[P5]`, …)
  are its rows. Each row carries its source in the CLAUDE.md §8 form, read on 2026-11-16 unless it is marked
  "unread: snippet only". Rows D15, D16, D18, D19, X7, X8, X9, F7 and F8 are snippet-only and source nothing here.
  Our own choices are marked `[UNSOURCED: plan/provenance-audit.md#CRE-n]`.
- The runtime it replaces is carrier-v3 §2–§3 and §14 (`openspec/changes/carrier-v3/design.md`).
- The re-render's plan is `plan/render-runs/carrier-v3.md`, on `work/carrier-v3-render`.

## 0. What stays
- The bend's analytic displacement, its limits (lean 3°, bank 2.5°, pitch 2°, 3° in the take-off), its springs, its
  deck lock and its buffet (carrier-v3 §2.2–§2.3).
- The field's distance map, contours, regions, lip, hits, scan and shards (carrier-v3 §3).
- The gameplay. The model, the shield's intercept surface, the hit windows, the gates and the calibration are not
  touched. `test/carrier_field_equivalence_test.dart` and the calibration gates hold.

## 1. What the operator saw, and why
These causes were read from the carrier-v3 runtime on `game` (3ceec704).

| Complaint | Cause in the code |
| --- | --- |
| "It warps a few separate layers individually." | `CarrierMesh` emitted one grid per module layer, each with its own copy of the shared edges. Each layer carried a constant height per mount (0, −20, 10 or 60), and the wings bent with lagged parameters at 1.25 × amplitude. Under a bend, two layers that overlap at one spot get different displacements, so they slide against each other: by up to the 4-unit parallax cap, and by more at the wing tips through the lag. That is the "separate layers" read. |
| "The components fall apart as separate random assets, each moving linearly." | `BossDirector._collapse` made one `BossWreck` per module, each with a random `vx` (±25), a random spin, a 0.25 s stagger and its own constant fall. Every module sprite moved on its own straight line, with no shared body and no common momentum. |
| "The off-screen sections fall off, which shows they were only partial assets." | Each wreck drew its module's layer sprite, shrinking toward the sprite's own anchor. As it fell, the parts of each layer that had been off-screen came into view with their hard cut edges. |
| "Its regions narrow inward." | The membrane sat at an offset `6 + 18·s`, so it moved toward the hull as the shield wore. Lost cells' regions were switched off from the outer arms inward. Both read as the field shrinking, not wearing. |

## 2. Compose, then warp (the bend)

### 2.1 Decision
Each pass of the hull (back: everything but the prow; front: the prow, drawn after the creatures) is drawn **once**
into one texture. That texture is warped by **one** continuous grid mesh whose vertices are shared by every module.
- One indexed grid cannot open a seam: adjacent triangles reference the same vertex `[D4]`
  `[UNSOURCED: plan/provenance-audit.md#CRE-1]`.
- It is the engine pattern of drawing children as a single object `[D12]`, and the shared-vertex mesh of skeletal
  runtimes `[D13]`.
- It is also the terrain's technique: one texture over one displaced mesh.

**The rigid read.** One smooth height field `h(x, y)` drives the displacement. The analytic bend of a height-field
surface is the projection of a small rigid rotation of that surface (carrier-v3 §2.2). Per-layer heights and the wing
lag made it non-rigid, so both are gone. A giant reads as heavy through slow, eased, small motion, not through flex
`[D17]`; the size-and-weight timing sources are snippet-only (`[D18]`, `[D19]`), so they support nothing here. The
limits and springs are already small, slow and critically damped (carrier-v3 §2.3). Reduced motion keeps the bend off
`[D20]`.

### 2.2 The composite
- `CarrierComposer.compose` records the pass's layers in their draw order into a `PictureRecorder`, then calls
  `toImageSync`. The image stays GPU-resident, with no read-back `[D1]`.
- **Extent.** The texture covers the union of the pass's layer rects in hull units, off-screen parts included. A
  composite cut to the screen would clip the hull `[D2]`.
- **Density.** 2 px per unit, the packed pages' own density, so nothing is resampled. Tour 1's back pass is
  1,440 × 1,200 px and its prow 874 × 284, under the 2,048 cap `[P1]` `[P3]` `[UNSOURCED: plan/provenance-audit.md#CRE-7]`.
- **Torn-away modules** that the art still draws at that stage are composed as charred stumps (the old `saveLayer`
  stump filter, applied once at compose time).
- **The cache.** One composite per pass, keyed by the hull, the drawn stage, the stage, the detached set, the run's
  assembly and whether the footprint is resident.
  - It is re-composed only when that key changes: at most once per damage step (stages S0–S3 and each detach,
    ≤ 7 per fight).
  - The old image is disposed at once `[P5]` `[P6]`.
  - At the collapse, the fight's composites are released and only the wreck's stays.
- **No per-frame `saveLayer`** composes the layers `[P7]`. The decay overlay keeps its own `saveLayer` (carrier-v3
  §2.4), and it now tints one texture instead of fifteen.

### 2.3 The mesh
- `CarrierWarpMesh` is a 20-unit grid over the composite's rect, with shared vertices (`Vertices.raw` with 16-bit
  indices) `[D4]` `[D5]`.
- **The cull.** A cell is kept when it overlaps a layer's rect and, once the field's distance map is built, lies
  within 15 units of the hull's alpha edge. That trims the mostly transparent quads, which cost fill `[P10]`.
- The composite has transparent margins, so the silhouette comes from the texture's filtered alpha, not the
  un-anti-aliased triangle edge `[D8]`.
- **Filtering.** `FilterQuality.low` (bilinear), set on the `ImageShader` itself `[D6]` `[D7]`.
- **Rebuilds.** The positions are rewritten only when a bend parameter moved more than 0.02°. The `Vertices` object
  is reused until then. There are no vertex colours.
- **On the CPU.** Flutter has no vertex shaders, so the warp runs on the CPU `[D11]`.

### 2.4 The height field
`CarrierHeightGrid` holds one height per 20-unit node over the hull frame. Both passes sample the same field, so the
prow and the carapace displace every shared point alike.
- **Until the re-render.** Each node takes the height of the topmost layer whose rect covers it (the old mount
  heights), then two 3 × 3 box-blur passes. The 60-unit dorsal step becomes a ramp under 30 units per node, and the
  4-unit parallax cap still applies.
- **After the re-render.** The field is the per-layer height grids of §5, merged with the topmost-covering rule and
  then blurred once.

### 2.5 Rig points
`BossPainter.bent` displaces lights, nozzles, fires, gates, trails and the field with the same displacement and the
same height field, and with no lag. A point therefore stays on its spot of the art: the mesh interpolates the same
displacement linearly between nodes, and the difference is under 0.5 unit.

### 2.6 Budget (mobile web)
| Item | carrier-v3 runtime | This change | How measured |
| --- | --- | --- | --- |
| Vertices, tour 1 (`carrier1-thorn`), both passes | 1,858 | **1,066** in game (footprint cull); 1,262 without it | `CARRIER_RENDER_MESH` in the review test; `CARRIER_MESH` in `test/carrier_bend_test.dart` |
| Triangles, tour 1 | 3,288 | **1,910** in game; 2,328 without the cull | same |
| Tour 5 (`carrier5-thorn`), without the cull | 3,045 / 5,324 | 1,508 / 2,810 | `test/carrier_bend_test.dart` |
| `drawVertices` calls per frame | 2 | 2 | review test asserts 2 |
| Position rebuild (desktop VM) | ≈ 70 µs | 23–76 µs | `test/carrier_bend_test.dart`, only when the bend moved |
| Texture memory (both passes, tour 1) | the shared page | +7.9 MB | `compositeBytes` |
| Layer overdraw the composite removes (sum of layer rects ÷ mesh area) | 1.24 (tour 1), 1.67 (tour 5) | 1.0 | `layer_overdraw` in `test/carrier_bend_test.dart` |
| Compose (recording plus GPU raster) | — | ≤ 7 per fight, both passes | `composites` counter |

**Frame-time reasoning.** No phone has been profiled yet (carrier-v3 task 3.5 stays open).
- **Raster.** The hull's fill is now one textured pass per pass, where the old meshes drew every layer's overlapping
  rects. The overdraw falls by the layers' overlap: 1.24 × on tour 1, 1.37 on the lattice set and 1.67 on tour 5, by
  the rect areas.
- **Vertices.** The vertex work fell by 40 %, and is far under the terrain mesh already drawn on phones (about
  4,800 × 2, carrier-v3 `[R2]`).
- **Memory.** The extra 7.9 MB of texture sits inside the 16 MB per-hull budget of `plan/render-runs/carrier-v3.md`.
- **Composing.** One compose is a picture of about 15 `drawImageRect` calls, rasterised once on the GPU. At most one
  happens per damage step, never in steady flight.
- **The Impeller caveat.** On native Impeller, textured `drawVertices` renders to a texture first `[D9]`, so one mesh
  per pass beats one per layer there as well. Web runs on Skia: CanvasKit or skwasm `[P9]`. Mobile web must be
  checked by hand `[P11]`.

### 2.7 Rejected
- **Per-layer meshes**, the carrier-v3 runtime, for the drift in §1.
- **A per-frame `saveLayer` compose**: it costs an offscreen target per frame `[P7]`.
- **A fragment-shader warp over the screen**: no vertex stage exists `[D11]`, and a hull larger than the screen is a
  fill-rate risk.
- **A control lattice (FFD)** `[D15]`: the analytic bend already is a 3-parameter global deformation. A lattice can
  drive the same mesh later without changing the pipeline.

## 3. The cohesive collapse

### 3.1 Decision
The wreck is one texture (§3.3), cut into a two-level hierarchy, and every piece is a rigid body of one closed-form
model. Pieces inherit `v + ω × r` from their parent at release, the point-velocity formula of rigid-body engines
`[X1]` `[X2]`. Breaking is pre-computed at the collapse's start, never cut at runtime `[X6]`. The hierarchy follows the
games' practice of big chunks first, then smaller ones, but that source is snippet-only (`[X7]`); the tiers and
numbers are ours `[UNSOURCED: plan/provenance-audit.md#CRE-5]`.

### 3.2 Timeline (`CarrierCollapseScript`, one constant each)
| t (s) | Beat |
| --- | --- |
| 0 | The core dies. The shake, then six chain blasts on the cracks over 0.1–1.1 s. The hull keeps 35 % of its horizontal velocity, sinks at 3 units/s plus gravity 4 units/s², and starts listing toward its travel (angular acceleration 0.011 rad/s²). |
| 0.1–1.55 | **The sag.** The wing tips and the stern's end droop down-screen by up to 12 units before anything breaks: its back is breaking. |
| 1.25 | The **stern** section shears off (three blasts along its crack). |
| 1.55 | The **wing on the side it lists to** shears off. |
| 2.05 | The other wing shears off. |
| 2.2–4.6 | **Chunks.** 60 % of each section's chunks, outer ones first, break from their section (one blast each). The rest ride their section. The deck's chunk never leaves the fore hull. |
| 0.8–7.0 | **The cloud deck** rises from below the arena (y 700) to above the wreck (y −20). Below its edge the wreck dissolves, so the lower pieces enter the cloud first. |
| 5.2–7.0 | The wreck fades, and is gone at 7.0. |

### 3.3 The wreck's art
- **One composite.** The hull as it was at death is composed once into one texture over the whole hull frame (both
  passes, back then prow) `[D1]` `[D2]`.
  - The stage and detached set at death are kept by the collapse, so the wreck is the hull the player saw.
  - The decay char is baked in (alpha 0.42).
  - The art's cut edges are feathered with `dstOut` ramps 56 units wide on the left, right and top. Opaque art at the
    frame's edge is a cut; it dissolves instead of showing a straight line.
- **The fracture** (`CarrierFracture`): the 20-unit grid of §2.3, culled to the footprint.
  - Its interior nodes are jittered by ±6 units, so the cracks are ragged.
  - The two triangles per cell alternate their diagonal by hash.
  - Each triangle goes to a chunk by a Voronoi partition with a noisy metric: distance × (1 + 0.45 × value noise at
    60 units) `[X5]`.
- **Seeds until the re-render.** Each layer's centre, with big layers split into about 180-unit cells. The cracks
  therefore follow the modules' structure. The re-render's chunk masks replace the seeds (§5).
- **Sections.** By seed position: |x| ≤ 120 is the fore hull (0), or the stern (3) where y < −200; x < −120 is the
  left wing (1); x > 120 is the right wing (2).
- **Drawing.** All triangles go through one `Vertices` (unshared corners, about 1,600 triangles on tour 1), drawn
  with one `drawVertices` over the wreck texture.

### 3.4 The physics model (closed form, deterministic)
Each body has a pivot `c` (hull-local), a parent, a release time `t_r`, a kick `(ix, iy, iω)`, a gravity `g` and an
angular acceleration `α`.
- **Before** `t_r`, a body's pose is its parent's pose, exactly. It is attached.
- **At** `t_r`, its state is:
  - position: `X₀ = T_parent(t_r)(c)`;
  - velocity: `V₀ = V_p + ω_p × (X₀ − X_p) + (ix, iy)` `[X1]`;
  - angle: `A₀ = A_p`;
  - angular velocity: `ω₀ = ω_p + iω`.
- **After** `t_r`:
  - `X(t) = X₀ + V₀u + ½g u² ŷ`;
  - `A(t) = A₀ + ω₀u + ½α u²`;
  - where `u = t − t_r`.
- **Constants.**

  | Body | Gravity (units/s²) | Kick (units/s) | Spin (rad/s) |
  | --- | --- | --- | --- |
  | Hull | 4 | — | — |
  | Sections | 6 | 9, outward from the core | ±0.035, outward |
  | Chunks | 10 | 8 × (0.6–1.4), outward from their section | ±(0.04–0.12) |

  Smaller pieces fall a little faster and spin a little more. Everything is slow, because a giant far away falls
  slowly on screen `[D17]` (`[D19]`, `[X9]` snippet-only).
- **Depth.** All bodies share one depth scale, `1 − 0.35 · smoothstep(0, 7, t)`, about a point on the hull at
  hull-local (0, −150) carried by the hull body. The far edge, off-screen above, stays off-screen while the near hull
  recedes toward it. The wreck sinks as one structure.

### 3.5 Off-screen parts
Every piece is cut from the one composite of the whole hull. So a part that was off-screen at death stays attached to
its body and enters the frame with its full art, never as a separate sprite `[X11]`
`[UNSOURCED: plan/provenance-audit.md#CRE-4]`. Until the re-render's art extends past the frame (§5.3), the feathered
edges (§3.3), the depth-scale centre (§3.4), the cloud deck and the fade keep the frame's cut edges out of sight.

### 3.6 Continuity
- **Smoke.** Emitted in world space from each released piece's crack, about 3 puffs per second per emitter, capped at
  90. Puffs left behind make the trail; puffs that moved with the piece would look stuck `[X10]`.
  - Each puff grows from 5–9 to 27–31 units over 1.6–2.2 s, lifts at 10 units/s and fades.
  - A fresh puff has an ember core.
- **Blasts.** At most 32 (the scene's explosion sprite). Each rides its body and appears where a crack opens: a radial
  kick look on top of the inherited motion `[X4]`.
- **Shadow.** One shadow for the whole wreck: its own alpha, inked, blurred by 3 and multiplied, closing in as it
  sinks. The old code drew eight.
- **Fog.** A haze tint up to 0.6 × progress, plus a tint band above the cloud deck.

### 3.7 Reduced motion
There is no list and no spin. Kicks are 40 % and there is no sag and no smoke. The wreck still sinks, recedes and
fades.

### 3.8 Budget
- **CPU.** About 4,700 vertices are transformed per frame through ≤ 21 body poses (no trig per vertex: one sin/cos per
  triangle), plus at most 90 puffs.
- **GPU.** The collapse lasts 7 s, with two `saveLayer`s per frame: the shadow and the fog/dissolve. That is fewer
  than the eight per-wreck layers before.
- **Memory.** The wreck texture is 1,440 × 1,280 px (7.4 MB). The fight's composites are released when it is built.

## 4. The field thins in place

### 4.1 Decision
The field keeps its footprint and wears through: its width and opacity fall, and holes grow `[F5]`
`[UNSOURCED: plan/provenance-audit.md#CRE-6]`. The wear shows through shape (width and gaps), not colour alone `[F3]`,
and through dropout rather than strobing `[F2]`.

### 4.2 The membrane
- **Offset.** It sits at one fixed offset: the 24-unit contour, the full field's look, at every shield level. It
  never moves inward.
- **Wear.** `w(s) = 0.18 + 0.82 · s^0.8`.
  - Glow: width `1.5 + 5.5w`, alpha `0.04 + 0.14w`.
  - Core: width `0.7 + 1.3w`, alpha `0.3 + 0.6w`.
  - The alpha comes from the paint's colour, never a `saveLayer` `[F10]`.
- **Gaps.** The worn-through share is `0.6 · ((0.7 − s)/0.7)^1.4` for `s < 0.7`, so about a third at s = 0.25.
  - The gaps are coherent 36-unit patches, crawling at about 7 units/s. They are never salt-and-pepper.
  - The lip, where shots stop, keeps its gaps 40 % narrower.
- **Lost cells.** A lost cell's region flashes once, as before. It then stays drawn at 0.3 × the wear, with gaps of at
  least 60 % and alpha 0.75. The region order of carrier-v3 §3.2 still says which regions fail first, but none is
  switched off while the shield holds.
- **Low field.** At s ≤ 0.25 the brightness varies between 0.7 and 1.0 at 1.75 Hz, low in contrast and cyan/teal,
  never red `[F1]` `[F2]`.
- **Crackle.** At s ≤ 0.5, a run of three segments flashes white-cyan for one 0.2 s tick. That is at most 1.75 sparks
  per second per region, each a few units long: under three flashes per second, and far under the area limit `[F1]`.
- **Shield down.** Over 0.4 s the width and alpha go to zero and the gaps grow to 100 %, in place. The emitter shards
  stay.
- **Reduced motion.** A static gap pattern, no crackle and no flicker `[F11]`.

### 4.3 The lip and the intercept
The gameplay surface (`Carrier.forceFieldSurfaceY`, depth `43 + 32·s`) is simulation and stays. The lip is still drawn
on it, because that is where shots stop, and is blended into the fixed contour over 70 units. It therefore still moves
in by up to 32 units at the centre as the shield empties. That is gameplay truth, and the thinning now carries the
wear read everywhere else.

## 5. Interfaces expected from the re-render (`work/carrier-v3-render`)
The re-render agent owns the art; this change owns the runtime. Each interface has a fallback that works on today's
art, and the runtime switches per field when the manifest carries it.

| # | Interface (manifest / atlas) | Used for | Fallback today |
| --- | --- | --- | --- |
| 5.1 | **Composable layers**: premultiplied alpha, under-painted beneath their occluders by ≥ 12 units (`plan/render-runs/carrier-v3.md` §1), drawn in manifest order. They must compose into one image with no seam. | §2.2 composite | Today's layers compose as they draw. |
| 5.2 | **Height grids per layer**: `layers[].height`, int16 at 20-unit cells, from the rig's z pass. Merged by the topmost-covering rule, then one blur. | §2.4 height field | Mount constants, blurred twice. |
| 5.3 | **Art past the visible frame**: an `envelope` margin of ≥ 80 units beyond the hull frame wherever the hull is cut (no opaque texel on the envelope's edge). | §3.5 off-screen | `dstOut` feather, 56 units. |
| 5.4 | **Chunk and section masks**: a `wreck.chunks` id map (8-bit, 0.5 px/unit over the envelope), a section per chunk (0 fore hull with the deck, 1 left wing, 2 right wing, 3 stern), and optional crack polylines. | §3.3 fracture | A Voronoi partition over the layer centres with a noisy metric. |
| 5.5 | **Tip points**: `slots.<slot>.vortex` and `.hinge` (wing and prong tips). | vortex trails; sag weights | The outer-lower extreme of each wing layer. |
| 5.6 | **Field data texture**: R the distance, G the region, B the height (carrier-v3 §3.4). | §4 membrane | A load-time EDT of the S0 alpha. |

When 5.4 lands, `CarrierFracture.build` takes the chunk of each triangle from the id map, sampled at its centroid,
instead of from the Voronoi partition. Everything downstream is unchanged.

## 6. Tests
- **`test/carrier_render_engine_test.dart`** (default suite):
  - one surface: every edge is shared by at most two triangles, and the vertices are shared;
  - rigid: the displacement changes by < 6 units across any cell at the limits;
  - the deck lock, and the rig points riding the same field;
  - the height field has no step of 30 units or more;
  - the hierarchy, with the deck never released;
  - attachment and continuity at release, and the kick bound (< 20 units/s);
  - cohesion: every chunk within 120 units of the rigid hull's carry, and a list under 10°;
  - the collapse runs headless, and reduced motion neither spins nor smokes;
  - the director: a v2 carrier makes one collapse and no module wrecks;
  - the field: the wear curve, the dropout curve and the fixed offset.
- **`test/carrier_bend_test.dart`**: the composed mesh's counts per hull (tours 1 and 5), under 4,000 vertices and
  7,000 triangles.
- **`test/carrier_field_equivalence_test.dart`** (unchanged): the shield's hit log is identical.
- **`test/carrier_render_engine_review_test.dart`** (`review`):
  - the bend sheet asserts one call per pass and prints the counts;
  - the collapse sheet and the field sheet;
  - the GIF frames for the collapse and the bend sweep.
- **Gates:** `flutter analyze`, the full suite through the lock, the worker tests, the build and the calibration gates
  (CLAUDE.md §2 and §7).

## 7. Risks and open questions
- **Phone profiling** (carrier-v3 task 3.5) is still open. The numbers in §2.6 are vertex counts and VM timings, not
  phone frame times.
- **Impeller colour filters on image-shader `drawVertices`.** An open issue reports them ignored `[D10]`. This change
  puts every colour filter on a `saveLayer`, as carrier-v3 §2.4 did, and none on the mesh paint.
- **The collapse's two `saveLayer`s** each cover the wreck's bounds for 7 s. If a phone drops frames there, the shadow
  layer goes first.
- **The lip still moves in** (§4.3), because it is gameplay. If the operator wants the lip to hold still too, the
  intercept surface would have to change, and that is a balance change for `plan/calibration-current.md`.
