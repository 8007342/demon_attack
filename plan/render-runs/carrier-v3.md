# Re-render plan: carrier v3 (C1 step 6)

**Status: plan only.** Nothing here runs until the operator has reviewed the `carrier-v3` spec (task 0.5). The runtime
parts (bend, field, gates, intro) work on today's packs first (design §2.5, §3.4); the re-render makes them better.

| | |
| --- | --- |
| Direction | `plan/operator-feedback-2026-11-16.md` C1 |
| Design | `openspec/changes/carrier-v3/design.md` |
| Research | `plan/carrier-v3-research.md` |
| v2 ledger (rates, picks, what is left) | `plan/render-runs/boss-carrier-v2.md` |
| Kit | `art/families/alien-carriers.json` |
| Tools | `tools/rigkit`, `tools/rigsheet`, `tools/boss_sheet pack` |

The rules of the v2 ledger stay:
- one GPU job at a time;
- no model downloads (everything runs on models already in the studio);
- every run is logged in `art/families/alien-carriers-runs.json`;
- picked raws are committed under `art/sprites/sources/boss-carrier-v2/<hull>/`;
- the picks are delegated (project memory "autonomy").

## 1. Principle: keep the look the operator praised
"The big ship looks great." So the tour-1 heroes (thorn 1015001, lattice 1025000, shroud 1036001) are **kept**.
- **Tour 1.** The new modules and the fixes go in by **regional edits**: the hero is re-run on the new control, and
  only the changed regions are composited onto the old pick, with `rigsheet maskdiff`, in the rig frame. The rest of
  the hull stays byte for byte.
- **Tours 2–5** were first passes with known faults (v2 ledger §5, §7). They get full hero rerolls.

## 2. What changes in the Blender model (rigkit and the family JSON)

### 2.1 One stored view
- `views.stored` becomes `[[45, 0]]`, plus `views.belly`. The 38° and 52° pitches and the ±12° yaw are dropped from the
  bake.
- `rig.py` still renders the 3 × 3 clay for review sheets only (`--views review`), never stored.
- This alone frees about three quarters of today's resident bytes (v2 measured 13.1–13.6 MB for 4 views). §5 spends
  them.

### 2.2 A hull built for bending
1. **Under-painted occlusion margins.**
   - Today each module layer is rendered with its neighbours held out, so its pixels stop exactly where a neighbour
     covers it (styleguide §4). Under the bend's height parallax, layers shift against each other by up to about 10
     units (spines 120 units high × 3° of lean, through `h·cos p₀ / sin p₀`), which would open slivers.
   - `bake.py` therefore renders each layer twice, with and without holdouts. The stored layer is the un-held render,
     masked to its own alpha ∩ (the held-out alpha dilated by **12 units**).
   - The projection bake has no hero pixels under an occluder. Those under-painted texels are filled by `rigsheet`'s
     new `pullpush` (edge-extending fill from the visible texels), then darkened 15 %. They are only ever seen at
     glancing parallax.
2. **Height grid per layer.** It comes from the rig's z pass (`boss-hero-assets` §8.5): the height above the hull's
   reference plane at 20-unit cells, written into `manifest.json` (`layers[].height`: a `w × h` array of int16
   units). The runtime bend reads it (design §2.2). This lifts the 4-unit parallax cap of the interim runtime.
3. **Hinge roots** for the lagging modules (wing, sail, tendril):
   - `slots.<slot>.hinge` gives a root point and a tip direction;
   - the runtime ramps the wing lag from root to tip (design §2.2);
   - no art change beyond the data.
4. **Mesh margin.** Each layer is cropped with ≥ 4 transparent texels on every side, because `drawVertices` does not
   anti-alias, so the silhouette must come from alpha (research `[W5]`). Today's crop margin is
   `render.margin = 6`, so this is already met; it is now asserted in `--check`.

### 2.3 Gate and compartment modules
`CarrierGates.forTour` (gameplay data, design §4.1) is the source of truth. `anchors.verify_dart` gains the gate
points, so the rig fails its gate if a gate module is more than 3 units off.

| Slot | Mount | Tours | Sets | States baked | Notes |
| --- | --- | --- | --- | --- | --- |
| `gate` (new) | prong underside, bow | 1+ (×2), 5 (+×2 aft) | `leaf` (chitin leaves), `iris` | closed, open | lit launch rail as an ember-hint strip on the clay; interior black (`dark`) |
| deck bays | (prow) | 1+ | (the prow's own) | — | the runtime-drawn deck doors stay (boss-carrier-wire); no bake |
| `maw` | lateral | 2+ | `iris`, `slit` | closed, open | the existing slot becomes a gate; the brood light stays at runtime |
| `hatch` (new) | dorsal, citadel terrace | 3+ | `petal`, `slab` | closed, open | the dorsal compartments; creatures rise, then swoop |
| `sac` | dorsal, under the prongs | 4+ | `cluster` | whole, split | splitting is the "open" state |

- **Opening** is the runtime blend of the two baked states plus the leaves' scale. No in-between frames are baked.
- **Telegraph lights and the rail chase** are runtime (lights in `rig.json` `lights` with `kind: gate`).
- **Vortex points.** `slots.<slot>.vortex` lists the prong and wing tips for the runtime trails (design §7).
- **Field regions.** `field.regions` gives 12 seed points (wing tips, wing roots, aft flanks, prong outers, prong
  inners, citadel, prow). `rigsheet fielddata` builds the hull's data texture from them (R the signed distance from
  the S0 union alpha by exact EDT, G the Voronoi region id, B the height). It is 0.5 px/unit over the envelope:
  0.48 MB on tour 1, 0.59 MB on tour 5.

### 2.4 Per-tour envelopes
`render.envelope` moves from the family into each hull (design §6.2):

| Tour | Envelope (x, y) |
| --- | --- |
| 1 | ±360, −430 … +240 (today) |
| 2 | ±370, −450 … +240 |
| 3 | ±375, −470 … +240 |
| 4 | ±380, −490 … +240 |
| 5 | ±390, −520 … +240 |

The later, wider frames therefore show more ship and never an empty edge.

### 2.5 The face and teeth fixes (from `boss-carrier-v2.md` §5 and §7 "Left")
| Hull | Fault | Fix |
| --- | --- | --- |
| carrier1-thorn | the dome's rows of dark ports suggest eyes at Z 0.86 (shaded at runtime, not fixed) | geometry: the ports become a staggered field of ≥ 7 small pores per row (no pair reads), regional edit of the dome. The runtime dome shade stays as a guard |
| carrier2-thorn | violet glow fills the core window | reroll with the stronger clause "the black shapes are deep black empty hangar mouths, no light inside" and the negative "glow inside openings" |
| carrier3-lattice | the prow's crystal and strut row paints as bone teeth | geometry: the crystals point up and back, the struts are dropped (ledger §5) |
| carrier4-shroud | the scale field paints pale and tooth-like | plate clay 0.54 → 0.40, or chitin instead of scales over the deck |
| scythe-arm wrecks | cropped by the envelope | wrecks get their own frame (`rig.py --envelope off` for wreck renders only) |
| bellies | only the thorn's exists | bellies for lattice, shroud and tours 2–5 |

### 2.6 Stages for tours 2–5
S2 and S3 looks (one-image Lightning edits, S3 chained from S2, with the "hangar openings stay black" clause), as tour 1
had them in v2 §3. They replace the runtime heavy-overlay fallback.

## 3. Order of work
| # | Step | Kind |
| --- | --- | --- |
| 0 | Kit and tools: `views.stored`, `gate`/`hatch` slots, hinge, vortex, field regions, per-hull envelope; `bake.py` under-paint; `rigsheet pullpush`, `fielddata`, height export; `--check` extended (gate anchors, margin). Rebuild tour 1 **without GPU** from the committed picks (`bake_family.lua`) to prove the bend-ready bake and the budget | CPU |
| 1 | Tour 1 regional passes (gates, thorn dome) + regional S2/S3 | GPU |
| 2 | Tours 2–5 heroes (rerolls with fixes) | GPU |
| 3 | Tours 2–5 S2, S3 | GPU |
| 4 | Bellies (lattice, shroud, tours 2–5) | GPU |
| 5 | Bake, finish, `fielddata`, budget, pack (`boss_sheet pack`: one view, gates, data page), review strips `art/contact/carrier-v3-*.png` | CPU |

**Checkpoints** (sheets committed, picks logged here):
- K1: the tour-1 bend-ready rebuild with no GPU, and its budget;
- K2: tour-1 gate edits;
- K3: tours 2–5 heroes;
- K4: stages and bellies;
- K5: the in-game strips at each tour's minimum zoom.

## 4. GPU job estimate
The rates measured in v2 (ledger §2 and §6):
- Lightning (Qwen-Image-Edit-2511 + Lightning, 4 steps, 1.6 MP): **≈ 21 s/image**;
- full model (40 steps, true CFG 4, 1.6 MP): **≈ 5.3 min/image**;
- refine (2.4 MP, 28 steps, denoise 0.40): **≈ 4.5 min/image**.

v2's model-load and queue overhead was negligible (140 images, ≈ 2.6 h, matching the sum of the image times).

| Step | Jobs | Images | Time |
| --- | --- | --- | --- |
| 1a Tour 1 regional heroes (gates, thorn dome), 3 hulls | 6 (fast + full each) | 24 Lightning + 12 full | 8 + 64 min |
| 1b Tour 1 regional S2 and S3 | 6 | 24 Lightning | 8 min |
| 2 Tours 2–5 heroes, 4 hulls | 12 (fast, full, refine) | 32 Lightning + 16 full + 4 refine | 11 + 85 + 18 min |
| 3 Tours 2–5 S2 and S3 | 8 | 32 Lightning | 11 min |
| 4 Bellies, 6 hulls | 8 | 24 Lightning + 8 full | 8 + 42 min |
| **Planned** | **40** | **136 Lightning, 36 full, 4 refine** | **≈ 4.3 GPU-hours** |
| Reroll reserve | | | + 40 % (v2 wasted 74 of 156 min on rejected batches) |
| **Envelope** | | | **4.3 h planned, ≤ 6 h with rerolls** |

- **Not in the estimate (optional C6):** a second set combination for each of tours 2–5 (styleguide §5 wants at least
  two per tour). That is ≈ 2.5 h more (4 hulls × heroes, stages and belly).
- **CPU** (Blender at 8 threads, peak RSS ≈ 1.6 GB, under the forge's 2 GB):
  - the under-paint doubles the layer renders, ≈ +60 s per hull;
  - a full bend-ready rig and bake is ≈ 6 min per hull, so 7 hulls ≈ 45 min per pass;
  - with ≈ 3 passes, about **2.5 h of Blender wall time**;
  - the Go finishing, `fielddata` and the sheets take minutes.

## 5. Byte budget per hull (16 MB, unchanged)
The gate is unchanged: **≤ 16 MB of resident RGBA per hull (one set combination), measured by `rigsheet budget` on
the finished layers and checked again as the packed page.** The belly stays outside it, as it is drawn only in the
Overflight.

**How the freed bytes are spent.** One stored view leaves about three quarters of today's budget unspent. It goes on:
1. **Sharpness under the warp.** Bilinear resampling under the bend softens by about half a texel, and the later tours
   frame wider. So the `mass` class rises from 0.8 to **1.2 px/unit** on tours 1–3 and **1.1** on tours 4–5. At Z
   0.70 and DPR 2 that is ≈ 1.2 device px per texel, where today it is 1.75. The `core` class (the prow) stays 2.0.
2. The 12-unit under-paint (≈ +10 % area).
3. Gate modules with two states each.
4. The field data texture.
5. Wrecks in their own frame.
6. S2 and S3 for every tour.
7. The wider envelopes of tours 2–5.

**Estimate**, scaled from the v2 measurements (ledger §3 and §5: per-view share, density² and envelope area):

| Hull | Mass px/unit | Stage scale | S0 core | S0 mass + S2 + S3 + wrecks | Gates | Field data | Sum | **Packed (+12 %)** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| carrier1-* (×3) | 1.2 | 0.5 | 1.05 | 7.0 | 0.2 | 0.48 | 8.8 | **≈ 9.8 MB** |
| carrier2-thorn | 1.2 | 0.5 | 1.05 | 10.2 | 0.3 | 0.51 | 12.1 | **≈ 13.5 MB** |
| carrier3-lattice | 1.2 | 0.5 | 1.05 | 9.5 | 0.4 | 0.53 | 11.5 | **≈ 12.9 MB** |
| carrier4-shroud | 1.1 | 0.5 | 1.05 | 9.9 | 0.5 | 0.55 | 12.0 | **≈ 13.4 MB** |
| carrier5-thorn | 1.1 | 0.5 | 1.05 | 10.4 | 0.6 | 0.59 | 12.6 | **≈ 14.1 MB** |

**If a measured hull goes over**, apply these levers in this order:
1. stage scale 0.4 (the v2 escalation plan);
2. mass 1.0;
3. S3 as tile patches over S2 (B3 lesson 5).

The budget is re-measured at K1 (tour 1) and K4 (tour 5) and recorded here. The download a player waits for stays one
hull's PNG page, about 1 MB today.

## 6. Not in this re-render
- No Wan VACE and no animation frames. Doors open by blending their two states, and the bend does the turning.
- No new pitch or yaw views.
- No change to the tour-1 set combinations or their picks, beyond the regional edits.
