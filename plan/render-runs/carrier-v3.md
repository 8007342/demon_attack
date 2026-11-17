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

---

# Run ledger (work/carrier-v3-render, 2026-11-16)

**Status: done (K0–K5); the operator phone playtest (task 7.5) is open.** The operator approved the long GPU jobs ("the boss fights shall be the most memorable part of this
game"). Picks are delegated (project memory "autonomy"); each pick and rejection is logged here with its reason.
Branch `work/carrier-v3-render` (worktree `~/.cache/tillandsias-project/worktrees/carrier-v3-render`), off `game`.

**Scope change during the run (coordinator, operator round 3b C3).** A separate agent re-specs the carrier rendering
engine (bend, collapse, field). This run therefore keeps its outputs engine-agnostic and does **not** change the runtime
bend, collapse or field code. It delivers data for them instead (§K0 "Interfaces") and wires only the art side (packs,
door layers, vortex points).

## K0. Kit and tools (CPU)
**Kit** (`art/families/alien-carriers.json`, checked by `rig.py --check`: originality, mirror symmetry, the anchor gate
at the stored view, and the gate anchors against `lib/game/carrier_gates.dart`):
- `views.stored = [[45, 0]]`; `rig.py --views review` renders the 3 × 3 clay for sheets only.
- **Gates** at the `CarrierGate` positions, in the plane frame, dropped onto the hull along the hero view and never
  scaled with it (a drop now casts in the target surface's own scale, so a fixed module lands on a scaled hull):
  - `gate.bay` (the deck bays, two leaves over the bay), `gate.pod` (the prong gates at ±150, 52: the hull had no
    surface there, so a chitin sponson arm reaches from the deck corner to the prong at every extent), `gate.leaf`
    (tour-5 aft gates);
  - `hatch.slab` / `hatch.petal` (tour 3+ dorsal compartments), `maw.slit` / `maw.iris` (tour 2+, elongated along the
    flank: a round dark pair reads as a head), `sac.cluster` (tour 4+, splits in two);
  - every door part has an `open` matrix (move, rotation about a pivot, scale): only `matrix_world` moves, so the
    bake's object coordinates carry the closed state's paint onto the open state;
  - **clearings**: array decor whose element falls within a gate's radius is not generated (prong plating, blister
    guns, spine thorns and the fore emitter base had covered gates).
- **Envelopes per hull** (design §6.2), tours 2–5 with **40 units of overscan** (`hulls.<h>.visible` keeps the visible
  envelope), so a collapse or a bend never shows a cut edge (operator round 3b C3). Tour 1 keeps its frame, because its
  heroes are kept.
- Texel classes: mass 1.2 px/unit on tours 1–3, 1.1 on tours 4–5; core 2.0.
- **Fixes in the clay:**
  - thorn deck: the two rows of four big plates (painted as paired dark eye ports) became a staggered field of 9 + 8
    small sinew pores and a row of low shingles;
  - thorn keel: the blunt front bulb (the skull-like tip) is a blade tapering to 0.4 units;
  - tour-3 prow (`prow.spire`): no bone strut row and no crystal column row (see K3);
  - tour-4 prow (`prow.bastion`): long chitin wing cases instead of the scale pebbles; `tag_map plate → scale`
    (clay 0.40); thorn blisters instead of the hive blisters (two lit ports per dome read as eyes);
  - the prow's gun thorns are chitin, not bone (pale pegs under the gallery read as fangs).
- Hinges and vortex points: `wing.*` and `tendril.barbed` carry `hinge {root, tip}` and `vortex` points; the carapace
  carries the prong tips. `field.regions` holds the 12 region seeds.

**Tools**
- `bake.py`: every layer is rendered twice (held out, and alone at one sample) for the under-paint; door instances
  get their open state (`door_<id>`); `heights.json` holds each instance's ship-frame z at the 20-unit lattice (BVH
  casts along the view, misses filled from neighbours); wrecks render in their own frame (sidecar JSON), never
  clipped by the envelope.
- `rigsheet`: `underPaint` (own silhouette within 12 units of the visible texels, filled by `pullPush` and darkened
  15 %), a 4-texel transparent crop margin, `fielddata` (below), `regional` / `regionmerge` (K2).
- `boss_sheet pack`: one view, `doors`, `vortex`, `gates`, `hinges` and a per-hull data page.

**Interfaces delivered for the rendering engine** (engine-agnostic; the runtime bend, collapse and field code is not
changed here):
- **Layers that compose into one image:** all layers share the rig frame registration (`dxy` + `texel` in the
  manifest, `BossHeroSprite.dx/dy/ppu` in Dart) and are under-painted 12 units beneath their occluders, so composing
  them back to front reproduces the S0 beauty and a composed texture can be warped as one image.
- **Height grids** per instance (`BossHeroData.heights`: 20-unit nodes, z + 32768 in R/G of the data page), mergeable
  into one hull grid by taking the topmost (largest z) value per node.
- **Field data texture** (`BossHeroData.field`, 0.5 px/unit over the envelope + 32): R the signed distance to the S0
  silhouette closed by a 30-unit disc (no cusp where the lip meets the prongs), G the region of the 12 seeds.
- **Fracture chunks** (`BossHeroData.chunks` = the field texture's B channel; `chunkCentres`): a marker watershed on
  the S0 beauty's luminance edges with mirror-symmetric markers about 110 units apart, so cracks follow the painted
  strakes, terraces and seams, not the module borders. 30–40 chunks per hull.
- **Tip points** (`BossHeroView.vortex`) and **hinges** (`BossHeroHull.hinges`).
- **Gate map** (`BossHeroHull.gates`: `CarrierGate` id → art instance) and **door states** (`BossHeroView.doors`).
- **Overscan** on tours 2–5 (above): the art continues 40 units past every visible edge.

## K1–K4. Runs, picks and rejections (2026-11-16)
Every job ran alone on the studio, on models already installed (Qwen-Image-Edit-2511, its Lightning LoRA); nothing was
downloaded and the studio was never restarted. Workflows: byte-identical copies of `art/workflows/sprites/carrier-hero-
qwen-fast.json` (Lightning, 4 steps) and `carrier-hero-qwen.json` (full, 40 steps, true CFG 4) under the main
checkout's ignored `.build/carrier-v3/`. Prompts: the family's `prompts.hero` + `hero_set_*` + `hero_v3_tour_N` +
`hero_v3_openings` (the brood-light clauses of v2 are gone: the light inside the gates is runtime), negatives
`negative_v3`. Raws, controls, regional inputs and masks are committed under `art/sprites/sources/carrier-v3/`; the run
records (job, seeds, prompts, model and output hashes) are merged into `art/families/alien-carriers-runs.json`.

**Not run (saved GPU time, decided on the sheets):** the refine pass (the 1.6 MP raws already exceed the stored
density: 1.63 px/unit raw against 1.2 stored), the full-model regional pass on tour 1 (the Lightning merge matches the
hero at phone density) and the full-model bellies (drawn at 0.5 px/unit and partial opacity).

- carrier2-thorn S0: fast 2016000-07 (st-…-115) on the pre-overscan control: prompt probe only (frame changed after). No core glow in any seed (the v3 opening clause works). 2016005 rejected: four bright ember discs in pairs at the emitter roots; 2016002: big lit discs on the prong blisters.
- carrier2-thorn S0 full 2017000-03 (st-…-117, ctl2 with overscan): PICK 2017001 (clean strakes and bone keel, dark deck, no light in the openings, wine membranes between prong and slab). Rejected 2017000: a row of four pale bone plates under the keel tip reads as a tooth row; 2017002: the prong bone racks paint as anatomical vertebrae with knuckle joints (skeleton reading) and two lit ports per wing in eye pairs; 2017003: two big lit ember discs over a row of bone fangs at the deck: a face.
- carrier3-lattice S0 fast 3026000-07 (st-…-116, pre-fix control): rejected as a batch: the prow's upturned crystal row still painted as a violet fringe hanging over the deck (a tooth row) and the fan wing roots as dark round knobs in eye pairs. Geometry fix: crystal row dropped from the tour-3 prow, scythe wings.
- carrier3-lattice S0 fast 3027000-07 (st-…-119, fixed control): no fringe, no teeth; the deck dark. 3027001/02/06 rejected: lit emitter discs at the shoulders in eye pairs. Prompt kept for the full run.
- carrier4-shroud S0 fast 4036000-07 (st-…-121): the scale field is gone (dark chitin cases, no pale pebbles: the tag_map and the bastion prow work); dark, spiked, menacing. Rejected 4036004: orange light inside the gallery; 4036001/02/04/07: the model paints a lit ember "eye" on the wing lobes' dark round plates (not in the control). Full run with the negative next.
- carrier3-lattice S0 full 3028000-03 (st-…-124): PICK 3028000 (crystal lattice crown, thin ember seams along the terraces, bone palisades on the prongs, barbed tendrils, the emitters in rows of three, the deck dark). Rejected 3028001: lit emitter orbs at the shoulders in eye pairs; 3028002: two lit orbs flanking the base of the citadel dome over the deck (eyes over a mouth); 3028003: two lit orbs on the dome's flanks.
- carrier4-shroud S0 full 4037000-03 (st-…-126): PICK 4037002 (dark wing-case armour with wine-red shield cases, a spine forest over every terrace, unlit dark wing plates, the deck dark). Rejected 4037000 and 4037003: the bone gun blisters on the prongs paint as little bone figures with lit ember sockets (skull-like); 4037001: lit orbs in a pair at the deck's corners.
- carrier5-thorn S0 fast 5016000-07 (st-…-122): prompt probe; the crown blazes over a thorn forest; several seeds with lit ember pairs at the prong roots.
- carrier5-thorn S0 full 5017000-03 (st-…-128): PICK 5017002 (the darkest chitin with molten seams, the great crystal crown, thorns everywhere, the deck and the gallery dark). Rejected 5017000 and 5017001: a band of fire along the deck's lintel above the gallery (a burning maw over the deck: light at an opening); 5017003: the prong racks paint as two long femur bones with lit knuckles (skeleton reading).
- carrier1-thorn S0 regional (st-…-130, Lightning, seeds 1018000-03): the v2 hero 1016000-refined with the changed clay (deck pores and shingles, keel blade, prong-gate pods, bay leaves, chitin gun thorns) pasted inside the clay-diff mask (grown 6 units, 7.4 % of the frame), repainted, merged back inside the mask only (feathered 2 units): the rest of the hero is the v2 pick. PICK 1018003 (pores read as small dark recesses, no paired ovals; the keel ends in a sharp blade; the pods are dark chitin with their leaves). Rejected 1018000: the pods paint as flat blocks and the pores vanish; 1018001: a row of lit red pores (lights in a row over the gallery); 1018002: the keel tip stays blunt. The full-model regional pass was skipped: the Lightning merge already matches the hero's paint at phone density.
- carrier1-lattice S0 regional, first pass (st-…-132, 1028000-03): rejected as a batch, and with it the kept v2 prow: at phone scale the v2 lattice hero's row of violet crystals pointing down between bone struts over the deck reads as a tooth row (the same fault as tour 3). Geometry fix: tour 1 lattice also takes `prow.spire` (no struts, no crystal row); the regional mask grows to 6.2 % of the frame.
- carrier1-lattice S0 regional, second pass (st-…-136, 1029000-03): PICK 1029003 (the deck smooth and dark, no fringe, the gates' pods dark). All four keep faint lighter ghosts where the crystals were; 1029003's are the darkest. Rejected 1029000-02: brighter ghost pillars over the deck.
- carrier1-shroud S0 regional, first pass (st-…-134, 1038000-03): rejected as a batch: the gun thorns under the turrets (chitin in the new clay) painted as two pale bone fangs hanging into the gallery (a mouth).
- carrier1-shroud S0 regional, second pass (st-…-137, 1039000-03; the prompt names the gun thorns as dark chitin spurs): PICK 1039000 (dark spurs, dark pods with their leaves). Rejected 1039001/02: key-green holes painted under the turrets; 1039003: the pods left as grey clay.
- carrier1-thorn S2 regional (st-…-138, 1017400-03; the v2 S2 1017201 with the new S0 regions pasted in the mask, the S2 prompt, merged in the mask only): PICK 1017401 (the deck pores dark, the hatch leaves closed). Rejected 1017400 and 1017402: the deck repainted with lighter blotches; 1017403: a raised plate on the deck (new geometry painted).
- carrier1-lattice S2 regional (st-…-139, 1027400-03): PICK 1027400 (the deck smooth and dark). Rejected 1027401-03: the removed crystal row came back as dark pointed stalactites over the deck (a tooth row in shadow).
- carrier1-shroud S2 regional (st-…-140, 1037400-03): PICK 1037401 (dark pods and leaves, the spurs dark). Rejected 1037400: the pods' leaves lost; 1037402: pods painted as pale flaps; 1037403: a lit sliver at the pod. Known gap kept from the v2 S2 1037200 (outside the mask): the deck shows four large black rectangles (windows reading); not repainted in this run.
- carrier1-thorn S3 regional (st-…-141, 1017500-03): PICK 1017501 (cracks carried across the deck, the pores dark, the pods cracked with the hull). The four are close; 1017500/02/03 have a smoother, less cracked deck.
- carrier1-lattice S3 regional (st-…-142, 1027500-03): PICK 1027500 (the deck dark, cracks around it). Rejected 1027501: fire on the deck's rim; 1027502: the deck lightened with ghost pillars; 1027503: an orange glow inside the gallery.
- carrier1-shroud S3 regional (st-…-143, 1037500-03): PICK 1037500; the four are near-identical inside the mask (the pods cracked with the hull).
- carrier2-thorn S2 (st-…-144, from the hero 2017001, 2017200-03): PICK 2017200 (torn armour over a glowing rib web, the crystals stumps, the gallery stays one dark opening). Rejected 2017201 and 2017202: the gallery repainted as a closed box door; 2017203: the crystals left whole.
- carrier3-lattice S2 (st-…-145, 3028200-03): PICK 3028203 (a row of four torn breaches with molten edges along the terrace; no pair). Rejected 3028200 and 3028201: a glowing ribcage under the citadel between two black breaches (two eyes over a nose); 3028202: two big breaches in a pair, each over a glowing ribcage.
- carrier4-shroud S2 (st-…-146, 4037200-03): PICK 4037201 (a molten crack network under the shed cases, the spine forest intact, the deck dark). Rejected 4037200: fire over most of the slab (no read of armour left); 4037202 and 4037203: a black breach on each prong, a symmetric pair (eyes).
- carrier5-thorn S2 (st-…-147, 5017200-03): PICK 5017202 (molten cracks through the strakes, torn membranes on the prongs, the gallery one dark opening). Rejected 5017200 and 5017203: the gallery repainted as a hanging box; 5017201: curved black scorches on the flanks.
- carrier2-thorn S3 (st-…-148, chained from S2 2017200, 2017300-03): PICK 2017301 (molten cracks through every terrace, smoke inside the outline, the keel standing). Rejected 2017303: two large black breaches side by side on the citadel (a skull's eye sockets); 2017300 and 2017302: the citadel split open to the green key (painted holes in the hull).
- carrier3-lattice S3 (st-…-149, 3028300-03): rejected as a batch: every seed punches large black breaches through the citadel in a symmetric pair or a split (skull eye sockets above the bone palisades as teeth; 3028303's single breach is the least, still a socket over teeth). Reroll with a prompt that forbids large holes.
- carrier4-shroud S3 (st-…-150, chained from S2 4037201, 4037300-03): PICK 4037301 (a web of molten cracks over the whole slab, small torn gaps scattered, no pair). Rejected 4037300 and 4037303: two large breaches side by side on the citadel (eye sockets); 4037302: the citadel split to the green key.
- carrier3-lattice S3 reroll (st-…-151, 3028310-13; the prompt forbids large holes and asks for uneven damage): PICK 3028312 (a molten crack web over the citadel and the flanks, smoke columns, only small scattered gaps). Rejected 3028310: two square black breaches in a pair; 3028311 and 3028313: pale spider-web cracks painted over the plates (reads as cobweb, not damage).
- carrier5-thorn S3 (st-…-152, chained from S2 5017202, the no-holes prompt, 5017300-03): PICK 5017301 (a molten crack web over every terrace, the thorn forest standing, no breach). Rejected 5017302: fire inside the gallery; 5017300 and 5017303: a black breach high on the citadel and fire at the deck corners.
- Bellies, first probes (st-…-153 lattice 1029900-03, st-…-154 shroud 1039900-03): rejected: the ivory keel and ribs paint as a vertebral column with ribs (a skeleton). Geometry fix: the belly keel and ribs are chitin; the prompt asks for a dark keel ridge, no bones.
- carrier1-lattice belly (st-…-155, 1029910-13, chitin keel): PICK 1029911 (a dark ridged keel, armour bands, ember pores in long rows, crystals scattered). Rejected 1029910: the keel splits into a T at the bow; 1029912: a red sinew lattice over the whole keel (reads as a ribcage); 1029913: violet glow leaking past the stern outline.
- carrier1-shroud belly (st-…-156, 1039910-13): PICK 1039911 (the darkest: a black keel ridge, pores in long rows). Rejected 1039910: lit pores in pairs along the keel; 1039912: a light, glossy belly; 1039913: a lit pore line down the keel.
- carrier2-thorn belly (st-…-157, 2019900-03): PICK 2019901 (dark keel ridge, bands, pores in rows). Rejected 2019902: the deck dropped from the bow; 2019903: reframed (the hull stretched past the control's outline); 2019900: lit pores in pairs. Known: from below the scythe arms curve like horns around the wedge (a horned-head silhouette); it is the geometry, seen only in the Overflight at partial opacity.
- carrier3-lattice belly (st-…-158, 3029900-03): PICK 3029902 (dark keel and bands, the prongs dark). Rejected 3029900: reframed past the outline; 3029901 and 3029903: the prongs painted pale grey stone.
- carrier4-shroud belly (st-…-159, 4039900-03): PICK 4039903 (dark keel, bands, scattered pores and crystals). Rejected 4039900 and 4039901: pore clusters bright and dense in a band across the belly; 4039902: a lighter, mottled belly.
- carrier5-thorn belly (st-…-160, 5019900-03): PICK 5019902 (dark keel ridge, bands, pores in rows). Rejected 5019901: a slab of the top hull painted over the bow; 5019903: the keel lit with a row of pores; 5019900: crystals in pairs along the bands.

## K5. Bake, budget, pack, sheets (2026-11-16)
**Bake** (`RIGKIT_BASE=… lua tools/rigkit/bake_family.lua art/families/alien-carriers.json <hull>`, then
`boss_sheet pack BAKE RIG carrier1-thorn=frigate carrier1-lattice=frigate carrier1-shroud=frigate carrier2-thorn=cruiser
carrier3-lattice=battlecruiser carrier4-shroud=battleship carrier5-thorn=dreadnought`).

**Budget decisions, in the order taken**
1. With the wrecks in their own frames (the scythe-arm fix) the wing wrecks were each hull's largest sprites
   (3.7–6.0 MB on tours 2–5) and tour 5 measured 17.06 MB. The collapse now breaks one composite of the hull
   (`carrier-render-engine` §3), so wreck frames are baked only for modules torn away during the fight (the first
   `forms − 1` detach ranks) and stored at the stage density.
2. Plan lever 1, stage scale 0.4, on tours 4 and 5 (`hulls.<h>.stage_scale`).
3. A deck guard in the art (`rigsheet deckshade`): on tour-1 thorn the AI's gloss on the deck dome quantised to pale
   bone as two symmetric blobs (eyes), on tour-1 lattice the bay leaves as two pale squares; their highlights are
   compressed inside the prow and bay ids before the bake (S0, S2, S3 picks, the `-deckshade.png` files).

| Hull | Sprites (`rigsheet budget`) | **Packed page + data page** | Hero PNG | Data PNG |
| --- | --- | --- | --- | --- |
| carrier1-thorn | 8.44 MB | **13.62 MB** (4096 × 820) | 0.46 MB | 0.03 MB |
| carrier1-lattice | 7.74 MB | **13.62 MB** | 0.50 MB | 0.02 MB |
| carrier1-shroud | 8.88 MB | **13.65 MB** | 0.49 MB | 0.03 MB |
| carrier2-thorn | 8.91 MB | **14.28 MB** | 0.53 MB | 0.03 MB |
| carrier3-lattice | 9.43 MB | **14.97 MB** | 0.63 MB | 0.03 MB |
| carrier4-shroud | 9.13 MB | **14.40 MB** | 0.53 MB | 0.03 MB |
| carrier5-thorn | 10.96 MB | **15.20 MB** | 0.64 MB | 0.03 MB |

Every hull is under 16 MB as packed. The page wastes 35–60 % (one 4096-wide page, its height set by the tallest
layer); a two-column or shelf-by-height packer would reclaim most of it if the budget tightens.

**Sheets**
- `art/contact/carrier-v3-render-tour1.png` … `-tour5.png`: per hull S0, S2 and S3 composed from the stored layers
  (the visible envelope dashed in gold, the overscan outside it), then every gate closed and open at 2×
  (`rigsheet v3sheet`).
- `art/contact/carrier-v3-render-bellies.png`: the seven bellies as packed.
- `art/contact/carrier-v3-render-{ingame,bend,zoom5}.png`: real in-game frames at 360 × 640 with the data pages
  loaded (`test/carrier_v3_render_review_test.dart`, `--dart-define=CARRIER_V3_RENDER_CONTACT=true`).

**Spent.** GPU: 168 images in 47 jobs, ≈ 138 min from the output timestamps (5 Lightning hero batches of 8, 4
full-model hero batches of 4, 33 Lightning batches of 4 for regional edits, stages and bellies); no failures, no
downloads, never restarted. Another agent (mission-medals) shared the studio between jobs. CPU: ≈ 75 min of
Blender (controls, rigs, under-paint bakes, 3 full rebake rounds) and ≈ 60 min of Go finishing (the under-paint's
EDT and pull-push at render resolution dominate `bakefinish`: 3–10 min per hull).

**Left**
1. The tour-1 shroud S2 (v2 pick 1037200, outside the regional mask) shows four large black rectangles across the
   deck: a row of windows. Not repainted.
2. Bellies: from below, the scythe arms and prongs of every hull curve like horns around the wedge (a horned-head
   silhouette). It is the geometry; the belly is drawn only in the Overflight at partial opacity.
3. Tour-1 lattice: faint lighter ghosts where the removed crystal row was; tour-1 lattice bay leaves stay tan (the
   runtime deck hatches cover them).
4. The tour-3 dorsal hatches sit mostly under the citadel bulge (the `CarrierGate` positions were set before the
   art); they telegraph and open, but only a sliver of the lid shows.
5. Only one set combination per tour on tours 2–5 (plan §4, optional C6).
6. The engine still has to adopt the overscan fully (`carrier-render-engine` task 5.3: the art now fades itself, so
   the wreck composite is built with `feather: 0` when the data page is in) and the hinge-weighted sag (task 5.4).
