# Proposal: boss hero assets (R5)

## Why
From the operator's second playtest on 2026-11-15 (`plan/operator-feedback-2026-11-15b.md` R5):
- "Hero art for the enemy boss ship, with several angles rendered so it can swerve and pitch."
- "Learn from 8007342/macron.dev, where agents used the forge to render an animation of Tlatoāni and Mācron learning
  to animate and write."
- "Learn how to properly Blender+ComfyUI ourselves a properly scary boss ship."
- "Blender is not installed in the forge; the pipeline and tool access are part of the design."

Today's five boss atlases (`assets/images/boss-{frigate,cruiser,battlecruiser,battleship,dreadnought}.png`, from
`tools/generate_boss_sprites.py`) are a single frontal view with baked parts. `boss-grandeur` (R4) needs:
- a 3 × 3 view set (pitch 38/45/52°, yaw −12/0/+12°);
- module layers that can break away;
- damage stages and wrecks;
- the five tour hulls built from one composable grammar.

**Research** (`plan/round2-research.md` §1–§2):
- macron.dev ran Blender *inside the forge* as the `bpy` 5.3.0 wheel on a uv-managed Python 3.13, headless on the
  CPU. Its clay (Workbench) and depth (EEVEE emission of the camera distance, Raw view) passes drove Wan 2.2 VACE,
  with identity taken from a canon reference image.
- We reproduced the route here on 2026-11-15: `tools/boss_rig/bpy_smoke.py` rendered 18 views (clay plus depth, 3
  pitches × 3 yaws) of a primitive boss blockout in 47 s on 20 cores. The sheet is
  `art/contact/boss-hero-bpy-smoke.png`.
- Every ComfyUI model this pipeline needs is already on disk in the studio: Qwen-Image-Edit-2511 with its Lightning
  LoRA, SDXL with ControlNet-union promax and IP-Adapter plus, and BiRefNet. No model download is required.

## What Changes
- **A boss pipeline: rig → hero → projection bake → finish → pack.** It is the boss analogue of the ground-forces CP1
  "lean hybrid": one AI hero per hull, carried to every view by geometry instead of per-view edits.
  1. **Rig (CPU, Blender in the forge).**
     - `tools/boss_rig/` builds each hull from the `boss-grandeur` grammar (`art/families/boss-hulls.json`):
       procedural modules on a spine.
     - It renders, per view and stage: clay, depth, normal and module-ID passes, plus the projected functional
       anchors.
     - **Fallback** with the same outputs: a `boss` verb in `tools/ground_blocks` (the Go ray-cast rig that already
       drives the ground forces), used if the wheel ever stops working in the forge.
  2. **Hero (GPU, one per hull).** Qwen-Image-Edit-2511 redraws the 45°/0° clay render, with today's atlas frame of
     that hull as the identity reference (image 2). This is macron.dev's rule: identity from a reference, pose from a
     bare control. The alternative graph is SDXL + ControlNet-union (depth) + IP-Adapter. Four candidates; the
     operator picks at a checkpoint.
  3. **Projection bake (CPU).**
     - In Blender, the chosen hero is camera-projected onto the hull mesh from the hero view.
     - The other 8 views and every module layer are rendered with that texture. Clay-tinted fill covers faces the
       hero never saw.
     - Views stay within ±12°/±7° of the hero, so stretch is small and materials are identical across the view set
       *by construction*. This is the boss version of `ground_blocks bake`.
     - Damage stages come from Qwen edits of the hero ("scorched", "plating torn away, glowing ribs"), projected the
       same way. Detached modules and wrecks come from the geometry.
     - An optional low-denoise (≤ 0.3) depth-ControlNet pass heals projection seams, gated by a consistency check.
  4. **Finish and pack (CPU, Go).**
     - `ground_blocks`-style finish: hull-family palette quantise, silhouette mask ±1 texel, outline ink, rig-driven
       lights, fire points and breach overlays.
     - Then pack per hull with generated Dart metadata: views, modules, stages, wrecks and per-view anchors.
- **Review checkpoints:**
  - **B0**: rig turntables, no GPU;
  - **B1**: frigate pilot heroes;
  - **B2**: frigate view set and stages;
  - **B3**: all hulls;
  - **B4**: in game.
- **Budgets:**
  - ≤ 16 MB RGBA resident (one hull at a time), atlas pages ≤ 4096 × 2048;
  - about 1.2 GPU hours with rerolls (about 25 min without the optional seam pass);
  - about 45 CPU minutes of Blender for all five hulls, at 8 threads to respect the forge memory budget.
- **Gates.** Functional anchors (core window, bays, turret pivot, solid body) project within ±3 units of the shared
  simulation geometry in every view. The view set must read as one ship turning (no drift).

## Capabilities
### New Capabilities
(none)

### Modified Capabilities
- `arcade-presentation`: ADDED requirements for the boss view-set art, module and stage art, art budgets and
  reproducible provenance.

## Impact
- **New:**
  - `tools/boss_rig/`: Python, because `bpy` forces it. `bpy_smoke.py` is committed now; `build.py`,
    `project_bake.py` and `setup_bpy.lua` come later.
  - `art/families/boss-hulls.json` and `boss-hulls-runs.json`;
  - `art/workflows/sprites/boss-hero-sdxl-cn.json` (SDXL + ControlNet-union + IP-Adapter);
  - `plan/render-runs/boss-hero-assets.md` (the ledger).
- **Changed:**
  - `tools/ground_blocks`: a `boss` fallback rig verb, and `finish` and `pack` modes for hulls;
  - `lib/game/boss_atlas.dart`: generated, extended with views, modules, stages and anchors;
  - `tools/generate_boss_sprites.py`: retired once the new atlases land.
- **Assets:** `assets/images/boss-<hull>-*.png` pages. The raws are kept under `art/sprites/sources/boss-selected/`,
  because host resets wipe the cache volume.
- **Host / operator asks** (non-blocking; `plan/round2-research.md` §2.3): a pinned Blender (`bpy`) toolchain or a
  reset-proof location for the 1 GB venv. No model downloads, and no studio restart.
- **Feeds** `boss-grandeur` (R4). The alien-troop palette and shield language come from `alien-insignia` (R6).
