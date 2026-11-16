# Design: boss hero assets

Research basis: `plan/round2-research.md` §1 (macron.dev), §2 (the Blender route and its verdict), and the
ground-forces pipeline with its CP1 decision (`plan/render-runs/ground-forces-rework.md` §1, §12).

## 1. Pipeline
```
 grammar (JSON)         rig (CPU: bpy in the forge;            hero (GPU, 1 per hull)
 boss-hulls.json  ──►   fallback: ground_blocks boss) ──►  45°/0° clay ─► Qwen-Image-Edit-2511 (+ today's atlas frame
                        views 3×3 × stages S0–S3                          as identity reference) ─► BiRefNet ─► pick (B1)
                        passes: clay, depth, normal,                       │
                        module-ID, anchors.json                            ▼
                                   │                     stage heroes: Qwen edit of the picked hero (S1–S3) ─► pick (B2)
                                   ▼                                       │
                        projection bake (CPU, bpy): hero/stage image ──────┘ camera-projected from the hero view onto
                        the mesh; render 9 views × modules × stages with that texture (clay-tint fill where unseen)
                                   │
                                   ├─(optional) seam heal: SDXL + ControlNet-union depth, denoise ≤ 0.3, gated
                                   ▼
                        finish + pack (Go, ground_blocks): palette quantise to the hull-family ramps, mask to the
                        rig silhouette ±1 texel, outline ink, lights / fires / breaches from the rig, module layers
                        from ID masks, wrecks, pages ≤ 4096 × 2048, generated boss_atlas.dart
```

**Rules carried over from ground forces and macron.dev:**
1. **The rig owns silhouette and anchors.** AI output may move an edge by ≤ 1 texel, only at soft edges (spines,
   mandible tips). Everything else is masked back to the rig.
2. **One hero per hull.** Every view, module and stage derives from it through projection. There is no per-view
   regeneration (the CP1 finding: two-image heading edits are binary, and per-view redraws drift).
3. **Identity from a reference, pose from a bare control** (macron.dev, after kumbia-kombat). The control is clay or
   depth only, never a beauty render. The prompt and the control must agree.
4. **Hints drawn into the control.** Features the AI must not invent or lose are made bright in the clay and depth
   passes: eye or sensor clusters, the core window, bay mouths. This is macron.dev's fix for "three eyes".
5. **Fixed seeds and full recipes.** Prompts, seeds, model hashes, job ids and rejected runs are recorded in
   `boss-hulls-runs.json`. Raws are committed under `art/sprites/sources/boss-selected/` (host resets wipe the cache
   volume).
6. **Overlays are never AI.** Lights, engine nozzles, fire points, breaches and hex shield cells come from the rig.

## 2. View set and frames
**Views.** Pitch {38°, 45°, 52°} × yaw {−12°, 0°, +12°}. The camera convention matches the screen: the boss faces
down-screen toward the player, and pitch is the camera's elevation above the hull plane. The 45°/0° view is the hero
view and the simulation's reference.

**Projected anchors.** For each view, `anchors.json` gives the core window, bay window, turret pivots, solid body,
engine nozzles, lights and fire points in arena units from the carrier centre. Gate: functional anchors within ±3
units of `BossAtlas` constants in every view (`boss-grandeur` §5).

**Per hull, per view:**
- the spine layer;
- one layer per module (from module-ID masks; mirrored pairs stored once where mirror-safe at yaw 0, otherwise both);
- stage patches for S1 (scorch), S2 (exposed, fires) and S3 (breach), cropped to the damaged region of each module,
  never full frames;
- the S4 collapse uses the wrecks.

**Per hull, view-independent:** one wreck per module (2 tumble frames, rendered at 45°/0° and rotated in the rig, not
at runtime), and the shield hex-cell sheet (procedural, shared).

**Texel density** falls as hulls grow, so the budget holds: frigate 2.0 px/unit, cruiser 1.9, battlecruiser 1.75,
battleship 1.6, dreadnought 1.5.

## 3. Budgets
| Budget | Limit | Estimate |
|---|---|---|
| Resident RGBA (one hull) | ≤ 16 MB | frigate ≈ 8.8 MB; dreadnought ≈ 12.7 MB |
| Atlas page | ≤ 4096 × 2048 | 1–2 pages per hull |
| Download (PNG) | ≤ 1.6 MB per hull, lazy-loaded (as today) | ≈ 1.3 MB dreadnought |
| GPU (studio, one job at a time) | | per hull: 4 heroes (~20 s) + 3 stage edits × 2 (~20 s) + mattes; optional seam pass 36 jobs (~10 s) + mattes. Total ≈ 12 min per hull with the seam pass, ≈ 5 min without. Five hulls plus 15 % rerolls ≈ **1.2 h** (≈ 25 min lean) |
| CPU (Blender in the forge) | one process, `-t 8` threads, ≤ 2 GB RAM | per hull ≈ 180 renders at 768² ≈ 9 min; five hulls ≈ **45 min** |
| Disk | venv ≈ 1.0 GB in `~/.cache/tillandsias-project/bpy-venv`; raws ≈ 300 MB per hull in the cache; selected raws committed ≈ 20 MB per hull | |

**Lean fallback** if a budget fails at B2:
- 3 views (pitch 45° only, yaw −12/0/+12), with pitch carried by the glide and the zoom only;
- stage patches limited to the spine.

## 4. Grammar and family spec
`art/families/boss-hulls.json` (schema `demon-attack.boss-hulls/v1`, validated with `studio.validate_family` where the
schema allows, and by `tools/boss_rig/build.py --check`) holds:
- **Modules:** the `boss-grandeur` §7 catalogue. Each module is a procedural recipe of bpy primitives (box, wedge,
  cylinder, cone, torus, bevel and array modifiers, boolean slots) with mount, mirror, size class, ID colour, lights,
  fires, seam lines for debris, soft-edge marks and detach order.
- **Hulls:** the five tour assemblies and their extent scale. The seeded assembly rules for later cycles are mirrored
  here so the art budget is checked before any render.
- **Palettes:** the hull-family ramps. They are the gargoyle Host stone and violet slag of the ground army, darkened,
  with the Brood's ember lights, plus the cyan force-shield language shared with `alien-insignia`. Style words follow
  `plan/gargoyle-army-style-guide.md`, and the originality rules (no franchise words, no scripture or skull motifs)
  are enforced by the validator, as for ground forces.

## 5. Where Blender runs (verdict) and the fallback
- **Primary.** The `bpy==5.3.0` wheel on Python 3.13 (uv-managed) in a venv at
  `~/.cache/tillandsias-project/bpy-venv`, headless on the CPU (Workbench and EEVEE).
  - Proven in this forge on 2026-11-15 (`tools/boss_rig/bpy_smoke.py`, 47 s for 18 renders).
  - Vulkan is not available; the EEVEE depth pass still rendered correctly.
  - No host-side install is needed, and nothing is worked around: this is the route macron.dev documented.
- **Setup.** `tools/boss_rig/setup_bpy.lua` (Lua per the forge order) runs `uv python install 3.13`, `uv venv` and
  `uv pip install bpy==5.3.0`. It is idempotent and takes about 1 min. The venv lives in the cache, which a host reset
  wipes, so the setup is part of every run's preflight.
- **Asks for the host or operator** (recorded in `plan/round2-research.md` §2.3; none blocks this change):
  1. A pinned Blender toolchain image (`toolchain.prepare blender`, beside the flutter one), or a reset-proof
     persistent volume for the 1 GB venv, so renders do not depend on PyPI availability.
  2. Confirmation that one CPU-heavy Blender process (8 threads, ≤ 2 GB) inside the forge's shared memory budget is
     acceptable during studio GPU jobs. The pipeline never runs two at once.
  3. *Optional, later:* GPU Cycles in the studio container for a beauty pass. Not needed: the AI hero supplies
     materials.
- **Fallback, if the wheel route breaks.** `tools/ground_blocks boss` (Go, standard library) builds the same hulls
  from its existing primitives (box, wedge, chamfered box, cylinder) and ray-casts clay, depth, normal and ID passes
  and anchors with the same file layout. Projection bake then happens in Go by back-projecting hero texels through the
  ray-cast depth (single bounce, nearest texel). It is lower quality at silhouettes but deterministic.

## 6. Checkpoints
| # | Sheet | Operator decides |
|---|---|---|
| B0 | `art/contact/boss-rig-turntables.png`: every hull's clay at the 9 views and the module-ID map, ×1 and ×3, against the simulation windows | Silhouettes, scale per tour, module grammar |
| B1 | `art/contact/boss-pilot-heroes.png`: frigate, 4 Qwen candidates + 2 SDXL-CN candidates, finished at phone size | The look; which graph scales |
| B2 | `art/contact/boss-pilot-views.png`, `-stages.png`: the frigate view set animated through a swerve and a glide, the stages S0–S4, wrecks | No drift between views; stage readability; budget |
| B3 | `art/contact/boss-hulls-heroes.png`, `-views.png`: all hulls | Tour progression ("larger, scarier, more complex") |
| B4 | In-game review frames from `boss-grandeur` | Final acceptance |

Nothing after a checkpoint runs before the operator approves it. Per the project memory, the agent drives the render
work to completion and logs its picks. The operator's approval is needed only where a sheet introduces a new look
(B1, B3).

## 7. Decisions taken on the operator's behalf
- **Projection bake, not per-view generation.** The CP1 evidence shows per-view AI drifts and heading edits are
  binary. Projection makes the view set consistent by construction, and the ±12°/±7° spread keeps stretch small.
- **Qwen-Image-Edit first, SDXL-CN as the B1 alternative.** Both run on models already on disk. Wan VACE is not used
  for the boss: the rig renders already carry the motion, and VACE added little for ground units.
- **Today's atlas frames as identity references.** They keep the five hulls recognisable to players across the
  upgrade.

## 8. v2 art direction: the Thornwake carriers (R8, R10)
The operator rejected the frigate B2 direction (a gargoyle **face** on riveted metal plates; `plan/operator-feedback-2026-11-15b.md`
R8). §1–§7 stay valid as the pipeline; this section replaces the *look*, the hull scale and the module grammar, and moves
the tooling into shared libraries. The art rules are in `docs/styleguide/alien-capital-ships.md`; the production ledger is
`plan/render-runs/boss-carrier-v2.md`; the B0–B3 frigate, cruiser and battlecruiser picks are superseded and never packed.

### 8.1 What changes
| | v1 (frigate pass, rejected) | v2 (this section) |
|---|---|---|
| Look | gargoyle head with eyes, fangs, riveted stone plates | an alien ship: lacquered chitin, scale armour, sinew, bone, membrane, violet psionic crystal, ember ports; no face, no metal |
| Scale | the hull fits the screen (≈ 300 units wide) | a carrier that spills off the top and both sides (≈ 600 × 800+ units), held by a zoomed-out camera |
| Grammar | 10 modules, one look per module, 5 fixed tour assemblies | slots × interchangeable **sets**, one baked set combination per hull; tours add slots (9 → 24 instances) |
| Family | `art/families/boss-hulls.json` (`demon-attack.boss-hulls/v1`) | `art/families/alien-carriers.json` (`demon-attack.rig-family/v1`) |
| Tools | `tools/boss_rig`, `tools/boss_sheet` (boss constants inside) | `tools/rigkit` (bpy kit, rig, bake), `tools/rigsheet` (finish, budget, sheets), family-driven; the v1 tools stay frozen for the superseded provenance |
| Hero | Qwen-Image-Edit-2511 + Lightning, 4 steps, 1 MP, 4 seeds | Lightning exploration batches, then the full model (40 steps, true CFG 4) at 1.6 MP, then a 2.4 MP refine pass (§8.7) |
| Budget unit | whole-hull views at one density | texel **classes** per module (core 2.0, mass ≤ 1.0 px/unit) inside a **visible envelope** (§8.4) |

Unchanged rules: the rig owns silhouette and anchors (§1 rule 1), one hero per hull (rule 2; here, per set combination),
hints drawn into the control (rule 4, now coloured: violet crystal, orange ember, black openings), full recipes logged
(rule 5), overlays never AI (rule 6), one-image Qwen edits only, S3 chained from S2, and stage edits keep the core and bay
windows dark (B3 lessons 1–4).

### 8.2 The ship
- **Plan.** A flat, wide-fronted wedge slab that steps up in two terraces toward a bone keel or crown, with two forward
  **prongs** that embrace the arena and outer **arms** (scythe, rib fan or lobe chain) that run off the screen edges.
- **The prow.** The launch gallery sits in the throat between the prongs, on the hero plane. The core maw and both bays
  form one dark hangar deck behind solid chitin bulkheads, and the two gun blisters sit on the sill. This carries the
  simulation windows (`BossAtlas.coreWindow`, `bayWindow`, `turretPivot`, `solidBody`), checked against
  `lib/game/boss_atlas.dart` by `anchors.verify_dart`.
- **Head-reading guard** (styleguide §3.4). It is a hard rule, because the first v2 clay read as a mouth with teeth
  under a round head. Two lone glows on the dome read as eyes. Emitters therefore come in rows, blisters in batteries,
  bulkheads are solid, and there are no brows, manes or mandibles.

### 8.3 Camera and visible envelope (proposal to `boss-grandeur`)
The carrier needs a wider camera band than §3 of `boss-grandeur` (Z ∈ [0.86, 1]). The proposal:
- carrier fights run at **Z ∈ [0.70, 0.86]**, with the same pivot (180, 477), rate limit and holds;
- the phone floors of `boss-grandeur` §3.1 are re-checked at 0.70 by the runtime owner (the creature floor of 34 CSS px
  becomes a draw-size floor, as insignia already are).

The **visible envelope** follows: carrier x ∈ [82, 278], glide y ∈ [189, 221], and Z ≥ 0.70 show the arena x ∈ [−77, 437]
and y from −204, i.e. carrier-relative **x ±360, y −430…+240** (`render.envelope`). The rig clips its frame to it, so
nothing that can never reach the screen is rendered, baked or stored. `rig.py --envelope off` renders full plans for
review (the lineup) only.

### 8.4 Texel classes and the budget
- **Classes.** Each slot names a texel class: `core` (the prow: 2.0 px/unit, the old frigate density, where the player
  aims) or `mass` (everything else: 0.8 px/unit on tour 1, then 0.9 / 0.85 / 0.8 / 0.75 as the hull grows on tours
  2–5). The rig renders at `max(class) × render.scale` (1.5) = 3 px/unit, so every class is an area downscale.
- **Stages.** S1–S3 layers are stored at `budget.stage_scale` (0.5) × the class density, which is B2's half-density
  decision.
- **Stored views.** (38, 0), (45, 0), (45, +12), (52, 0) (`views.stored`). A (38|52, ±12) request draws (45, ±12); yaw −12
  is +12 mirrored; at yaw 0 and in the wrecks a mirrored pair is stored once.
- **S1** is a runtime overlay on S0 (scorch, crystal flicker), as `boss-grandeur` §6 already specified; it is not baked.
- **Carapace wreck.** The carapace has no wreck frames (`wreck: "layer"`): in S4 the runtime sinks its own S3 layer into
  the fog.
- **Gate.** ≤ 16 MB of RGBA per hull (one set combination), measured on the finished layers (`rigsheet budget`). The
  measured numbers are in the ledger: tour 1 is 13.1–13.6 MB (15.53 MB as one packed 4096 × 994 page with the frontal
  parts). **The budget is unchanged at 16 MB.** The levers that keep a hull 4–6 × the frigate's area inside it: the
  envelope clip, the mass class, S1 as an overlay, swerve views at the middle pitch only, and no wreck frames for the
  prow and the carapace (ledger C3).

### 8.5 The shared libraries (R10)
**`tools/rigkit/rigkit.py`** (bpy; Python only because bpy forces it) is a data-driven module kit:
- *primitives*: box, loft, shell (superellipse lofts), cyl, lathe, ell, horn (with flattened sections), shard (crystal
  bipyramid), prism, web (membrane);
- *generators*: `array` along a path, an arc or a grid, with scale and rotation ramps, seeded mirror-safe jitter, and
  `drop` onto another slot's surface (or this module's own) with normal alignment;
- *modifiers*: Catmull-Clark `subsurf` and mirror-safe noise `displace`;
- *family*: slots × sets → instances, stage plans (`shed` tags, `detach` groups);
- *scene*: views on a swerve axis, the passes clay, hint (colours), depth, normal, id and z;
- *gate*: anchor points and a coverage rect from the family JSON.

The CLIs:
- **`tools/rigkit/rig.py FAMILY OUT`**: renders the controls and writes `rig.json` (`demon-attack.rig/v2`: frame, render
  density, texel classes per instance, envelope, overlay, anchors, lights, fires);
- **`--check`**: originality, mirror symmetry (KD tree), instance counts and the gate;
- **`tools/rigkit/bake.py`**: the projection bake (§1), family-driven fills, stored views only, layer renders cropped to
  the module's border;
- **`tools/rigkit/bake_family.lua`**: the whole no-GPU rebuild of one hull from its committed picks;
- **`tools/rigkit/collect.lua`**: studio outputs → raws + run log.

**`tools/rigsheet`** (Go, standard library) reads only `rig.json` and the family JSON:
- `ctl` (the hero control);
- `fit` and `maskdiff` (raw to rig frame, silhouette, despill, symmetrise);
- `bakefinish` (finish per class + `manifest.json`);
- `budget`;
- the sheets `kit`, `heroes`, `views` (+ swerve GIF), `stages`, `sets`, `mock`, `lineup`, `grid`.

**Family schema** (`demon-attack.rig-family/v1`):
- `views` {pitch, yaw, hero, stored_yaw, swerve_axis};
- `render` {scale, margin, envelope};
- `anchors` {tolerance, points [{name, module, prim, at}], coverage {rect, inset, grid}, verify_dart, overlay};
- `materials` {tag: {clay, hint, fill}};
- `palettes` {ramps, overlay_only};
- `originality`; `prompts`;
- `slots` {slot: {mount, mirror, fixed, frame, detach, wreck, texel, id, common, common_lights / fires / nozzles,
  sets: {set: {prims, lights, fires}}}};
- `hulls` {hull: {tour, title, replaces, extent, texel {class: ppu}, set, sets {slot: set}, slots
  [slot | {slot, set, suffix, offset, scale}]}};
- `stages` {S0–S3: {shed, detach}}; `budget` {mb, page, stage_scale}; `selected` {root, hull: {S0–S3, sym}}.

A new art family (a ground titan, a sentinel mother-ship) needs a family JSON and nothing else.

### 8.6 Output layout for the pack (`boss-grandeur` owns the pack and runtime)
`~/.cache/tillandsias-project/rigkit/<family>/bake/<hull>/` (from `bake_family.lua`) holds:
- `S0..S3/fin_layer_<inst>_<view>.png`: full frame at the layer's stored density;
- `S0..S3/fin_beauty_<view>.png`: review only;
- `fin_wreck_<inst>_f<0|1>.png`;
- **`manifest.json`** (`demon-attack.boss-bake/v2`): every stored sprite with its file, kind, instance, stage, view,
  texel density, crop rect in px, and top-left `dxy` in arena units from the carrier centre, plus the stored-view and
  mirror rules and `resident_bytes`.

`rig/<hull>/rig.json` adds the instances (slot, set, detach rank, mount, texel class), the projected anchors, lights,
fires and nozzles per view and stage. Differences from the frigate layout that the pack must handle:
- densities come from the manifest, not a fixed 2 px/unit;
- a hull key is `carrier<tour>-<set>` with `replaces` naming the v1 tour key, so there is no frontal atlas
  (`assets/images/boss-<hull>.png`) for the jaw, vent, plume and breach parts;
- the carapace has no wreck frames;
- `fin_belly.png` (manifest kind `belly`): the Overflight underside at 0.5 px/unit in its own frame (`rig-belly`), outside
  the resident budget.

**Packing.** `tools/boss_sheet pack BAKE RIG carrier1-thorn=frigate` reads the manifest (`pack_v2.go`: stored
densities as-is, `BossHeroSprite.ppu` is a double, unstored views alias pitch 45, one 4096-wide skyline-packed
page) and writes the hull under the tour key it replaces. It is **not committed packed**: `test/boss_grammar_test.dart`
asserts that `BossGrammar.tour(0)` (v1 ids: spine, bow, tower, engines) equals the packed hull's module ids, and the v2 ids
are `carapace, prow, wingL/R, spines, emitterL/R, blisterL/R`. The runtime owner switches the grammar to the v2 slots,
treats the `prow` (mount bow) as the front pass (today `BossPainter` hard-codes `bow`), picks a set combination per run
among the baked hulls of a tour, then packs.

### 8.7 GPU recipe
| Pass | Workflow | Settings | Use |
|---|---|---|---|
| Exploration | `art/workflows/sprites/carrier-hero-qwen-fast.json` | Qwen-Image-Edit-2511 + Lightning, 4 steps, 1.6 MP, 6–8 seeds per set | judge the clay and the prompt |
| Hero | `carrier-hero-qwen.json` | the full model, 40 steps, true CFG 4 with the negative, 1.6 MP, 4 seeds per set | the pick |
| Refine | `carrier-refine-qwen.json` | the picked hero upscaled to 2.4 MP, 28 steps, denoise 0.40 | fine detail at the prow; gated by the anchor and silhouette fit |
| Stages | `carrier-hero-qwen.json` with stage prompts | S1 and S2 from the refined hero, S3 chained from S2 | decay looks |

All on models already in the studio; no download. Wan VACE stays unused: the projection already carries every view (§7).

### 8.8 Checkpoints (v2)
| # | Sheet | Content |
|---|---|---|
| C1 | `art/contact/boss-carrier-v2-kit.png`, `-lineup.png` | kit turntables (3 sets of tour 1), tour 1–5 full-plan lineup |
| C2 | `-heroes-<set>.png` | hero candidates per set, finished at phone density |
| C3 | `-views-<set>.png` (+ `.gif`), `-stages-<set>.png`, `-sets.png` | projected view sets, damage stages and wrecks, the sets side by side |
| C4 | `-phone-mock.png` | phone-scale in-context mock with the hull spilling off-screen |
| C5 | tours 2–5 | rigs and lineup; heroes when time allows |

### 8.9 Decisions taken on the operator's behalf
- **Combinations are baked, not mixed at runtime.** Holdout occlusion makes each module layer specific to its
  neighbours (styleguide §4).
- **The budget stays at 16 MB.** It is met with texel classes and the visible envelope, not by raising it.
- **Escalation is density, not extent.** Extent grows only ×1.32 by tour 5 (v1: ×1.60), because the ship already
  spills; each tour adds batteries, barriers, maws, sacs and the crown.
- **The carrier camera band Z 0.70–0.86** is a proposal to `boss-grandeur`; the envelope follows it.
