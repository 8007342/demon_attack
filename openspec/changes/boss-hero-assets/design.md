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
