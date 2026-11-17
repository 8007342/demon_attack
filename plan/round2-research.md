# Round 2 research: macron.dev, a Blender route, alien insignia (R2–R6)

Operator intent: `plan/operator-feedback-2026-11-15b.md`. This file gives the findings behind five OpenSpec changes
(`terrain-shadows`, `transition-ascent`, `boss-grandeur`, `boss-hero-assets`, `alien-insignia`) and the recommended
order. R1 (no stragglers at level end) is a bug fix handled separately.

## 1. How macron.dev rendered "Tlatoāni and Mācron learning to animate and write"
Source: the public repo 8007342/macron.dev, read from the sibling clone
`~/.cache/tillandsias-project/siblings/macron.dev`, which was up to date. Key commits:
- 3418b67: a 4-frame Qwen loop;
- fcc5d92: "a 48-frame Blender + Wan VACE loop";
- f8b8233: a 72-frame room loop with a moving camera;
- 5c0da5a: a per-frame clip check;
- 5706159: seeding from the canon painting "Arabiya Ink and Voices".

Notes and lessons:
- `public/notes/2026-11-14-forge-blender-blockout-to-wan-vace-loop.md`;
- `public/lessons/make-art-in-the-forge-studio.md`;
- recipes in `art/animations/*/recipe.json`.

### 1.1 Tools
- **Blender ran inside the forge, never as a program.**
  - The note says "There is no `blender` binary or shim in the forge, but the `bpy` wheel works headless."
  - Install: `uv python install 3.13`, a venv on persistent disk, `uv pip install bpy==5.3.0` (~430 MB download).
    bpy 5.3 needs Python 3.13. [source: Blender Foundation via PyPI, "bpy 5.3.0" release metadata (requires_python ==3.13.*; manylinux x86_64 wheel 427,524,100 bytes), https://pypi.org/project/bpy/5.3.0/, read 2026-11-16]
  - Scripts run as plain Python (`python art/tools/blockout*.py OUT …`), with CPU rendering only: Workbench for clay
    and wire, EEVEE for depth.
  - The idea came from the kumbia-kombat repo ("Blender as a bpy venv").
- **Blender scenes.**
  - Fully procedural from Python: primitive cubes, spheres, cylinders and cones, bevels, parenting, palette from the
    canon art, contacts computed rather than placed.
  - Every motion is cyclic (frame N = frame 0).
- **Passes.**
  - *clay*: Workbench solid;
  - *wire*: Workbench with a Wireframe modifier;
  - *depth*: EEVEE emission of the camera distance, linear, near = white, `view_transform = "Raw"` (the first depth
    pass came out white until Raw was set).
  - No normal, canny or mask passes, and no beauty render as control.
- **Cameras.**
  - `blockout.py`: fixed, 640 × 480, 48 frames.
  - `blockout_room.py`: a ±10° arc around the table with a 30 cm push-in mid-loop, 768 × 576, 72 frames.
  - `blockout_canon.py`: ±4° drift and a 6 % push-in. The frame-0 camera is *fitted to the painting*: pitch from the
    horizon row, 53° FOV, and props un-projected from their pixel positions.
- **ComfyUI** (`art/workflows/`):
  - `qwen-edit.json`: Qwen-Image-Edit-2511 with Lightning, 4 steps, cfg 1.
  - `keyframe-sdxl.json`: rejected, because text alone could not draw the characters.
  - `qwen-edit-layout.json`: a two-image edit (old keyframe plus clay). Failed by drawing two robots.
  - `wan-vace-{loop,room,canon}.json`: Wan 2.2 Fun VACE 14B fp8 with high and low experts, `WanVaceToVideo` with
    `control_video` (packed depth frames), an all-white mask and one `reference_image`, length 81, two 10/10
    `KSamplerAdvanced` passes at cfg 3.5.
  - `art/tools/pack_control.py` packs the depth frames into multi-frame PNGs that core `LoadImage` reads as a batch,
    so no custom nodes were needed.
- **Host tools used:**
  - `studio.start`, `studio.run_workflow` and `studio.queue_workflow` with `studio.job_status`;
  - `studio.models`, `studio.contact_sheet`, `gpu.status`, `tillandsias.lane_version`.
  - No tray or studio tool offers Blender.

### 1.2 Consistency tricks that transfer
1. **Identity from a reference, pose from a bare control.** The prompt and control must agree. The reference is canon
   art (a Qwen re-stage, later the unedited painting).
2. **Fit the blockout to the reference** (`--overlay` draws depth edges over the painting).
3. **Draw hints into the control.** Eyes and the hopping dot are pure white in the depth pass. This fixed the
   three-eyed robot that prompts alone could not fix.
4. **Thicken thin parts** (pencil, arms) so the depth pass carries them.
5. **Fixed seed** (31) across re-runs; wrong looks go into the negative prompt.
6. **Measure, don't eyeball.**
   - `--check` is a per-frame BVH overlap test (exit 1), and it caught sign errors.
   - Loop seams are judged by "jolt" (a step minus the mean of its neighbours).
7. **Close the loop inside one run** (cycle + 8–9 frames, blended in a quiet beat). Splicing separate runs failed
   (`pin_ends.py`, `pack_bridge.py`); runs differ by a floor of about 4–6.
8. **Full recipes:** prompts, seeds, sha256s, and the runs that did not ship.

### 1.3 Failures and gaps they recorded
- Four Qwen-edited frames in ping-pong jumped between frames.
- The first Wan use downloaded about 41 GB even though `studio.models` listed the files as on disk.
- `VRAM grow failed` / `gpu_memory_busy` errors when demon_attack's studio and another engine shared the GPU, which
  `gpu.status` did not show. Projects took turns through the coordinator.
- Blender bugs: sign errors, and bevel width applied before scale.

**cannonball:** nothing on Blender, turntables or VACE. "3D" there means pseudo-3D road rendering only.

### 1.4 What we take
- `boss-hero-assets` adopts:
  - the bpy-in-forge route;
  - procedural geometry from a spec;
  - clay and depth as bare controls;
  - identity from a reference (today's boss atlas frames);
  - hints drawn into the control (core window, bays, sensor clusters);
  - fixed seeds and full recipes;
  - per-frame checks (anchors within ±3 units, instead of BVH overlap).
- We do **not** adopt Wan VACE for the boss. Our CP1 evidence (`plan/render-runs/ground-forces-rework.md` §12) found
  that VACE adds little when the rig already carries the motion, and that per-view AI drifts.
- We add one trick macron.dev did not need: **camera-projecting the single approved hero onto the mesh**, so all 9
  views share materials by construction.

## 2. A Blender route for boss hero assets
### 2.1 What the host and studio offer (checked 2026-11-15, tray 56.11.15.5)
- `tillandsias.index` groups: preview, toolchain (flutter only), image, studio (ComfyUI), browser, cloudflare, cloud,
  webstudio. **No Blender anywhere.**
- `studio_options` lists GrapesJS, Decap, Tina, Puck, Onlook, ComfyUI and Audio Studio. No 3D tool.
- `studio.status`: running (`tillandsias-demon_attack-studio`). It was not restarted.
- `studio.models` shows on disk:
  - Qwen-Image-Edit-2511 fp8 with the Lightning 2509 and 2511 4-step LoRAs;
  - SDXL base, Animagine XL 4.0, SDXL-Lightning;
  - **ControlNet-union promax** and openpose;
  - **IP-Adapter plus** with CLIP vision;
  - LayerDiffuse;
  - BiRefNet;
  - FLUX.2-klein-4B;
  - Wan 2.2 Fun VACE 14B (high and low) with the Lightning LoRAs;
  - ACE-Step.

  Not on disk: Real-ESRGAN, Qwen-Image 2512. Neither is needed. **The boss pipeline needs no model download.**
- The studio container is ComfyUI only. Putting Blender in it, or in a toolchain image, would be a host-side change,
  hence the asks in §2.3.

### 2.2 Verdict: Blender works in this forge as the `bpy` wheel (proven today)
- `uv 0.13.7` is installed.
- `uv python install 3.13`, then `uv venv`, then `uv pip install bpy==5.3.0`, all into
  `~/.cache/tillandsias-project/bpy-venv` (1.0 GB on disk). `import bpy` reports 5.3.0.
- **Smoke test:** `tools/boss_rig/bpy_smoke.py` builds a primitive boss blockout and renders clay (Workbench) and
  depth (EEVEE emission, Raw) at pitch 38/45/52° × yaw −14/0/+14°.
  - 18 renders at 384² in **47 s** on 20 cores.
  - The sheet is `art/contact/boss-hero-bpy-smoke.png`.
  - Vulkan could not initialise, but EEVEE rendered correctly anyway.
- The route needs no host change. It is the route macron.dev documented, so it is not a workaround.
- **Fallback, if the wheel route ever breaks.** `tools/ground_blocks` (Go, standard library) already ray-casts rigs
  made of boxes, wedges and cylinders for the ground forces. A `boss` verb produces the same passes (clay, depth,
  normal, module-ID) and anchors, and the projection bake back-projects through the ray-cast depth. It is lower
  quality at silhouettes but deterministic, and it uses the same file layout, so nothing downstream changes.

### 2.3 Asks for the host agent or operator (none blocks the plan)
1. **Pinned Blender.** Provide either:
   - a `toolchain.prepare blender` image beside flutter, carrying `bpy==5.3.0` on Python 3.13; or
   - a persistent volume that survives host resets for `~/.cache/tillandsias-project/bpy-venv`.

   The project memory records that host resets wipe the cache volume. Today the venv is re-created by an
   idempotent setup (about 1 min, about 430 MB from PyPI) at every run's preflight.
2. **CPU budget.** Confirm that one Blender process (8 threads, ≤ 2 GB RAM) inside the forge's shared memory budget is
   acceptable while the studio runs GPU jobs. The pipeline never runs two at once.
3. *(Optional, later)* GPU Cycles in the studio container. It is not needed: the AI hero supplies the materials.

## 3. The original alien sprites: what got lost
Sources: `git show 8cf79246:assets/images/combat.png` (the original 32-grid atlas from `tools/generate_sprites.py`),
f30e8462 (the first 64-grid pass), 15bff99e / 827d478d / 92638db1 (gargoyles), the pre-64 `lib/game/scene.dart`
(indicator code at about lines 500–575), and today's `scene.dart` 848–916 and 2284–2714.

**Then (32-grid, about 1.35 CSS px per art pixel), all baked or drawn large:**
- **Species:** a flat teal, violet, coral or gold body and wings behind a heavy 2 px outline, covering 1,000+ px² of
  the sprite.
- **Molt 1–3:** a hue shift of the whole body, torn wings, a pale belly.
- **Angry:** the whole sprite turns gold `#ffbd53`, with red eyes and scars.
- **Code overlays:**
  - elites: a rotating ring of 2 × 2 dots, armour plates losing one per hit, and horn steps;
  - every creature with HP > 1: 2 × 2 health pips over the head.

**f30e8462 (64-grid, still front-facing and flat).** Readable chest marks: teal ivory chevron, violet twin bars,
coral fang slashes, gold ruby star. Elites gained gold pauldrons.

**Today (64-grid gargoyles in 3/4 banking flight, still drawn at 40 units, so about 0.68 CSS px per art pixel):**
- the rank decals are capped at about 5 × 5 art px (3–4 CSS px) inside textured hide, and are often hidden by wings;
- the elite overlay is a few pixels per level (the gold crest spikes are the operator's "spikes");
- the dotted ring remains (the operator's "dots");
- health pips were removed by ux-declutter (869410ad);
- molts are holes and cracks, and angry is scorched membranes and red eyes;
- shields are effects (a thermal dive arc, sentinel wear frames), not identity marks.

**Diagnosis.** The detail doubled, but none of the signals were scaled to match. Whole-body colour coding was lost,
the marks shrank to sub-readable blobs, and nothing replaced the pips.

**Remedy:** `docs/styleguide/alien-troops.md` and the `alien-insignia` change.
- Rank glyphs (talon, double talon, ocellus, crown) drawn above the head on the old coarse pixel, after the camera, at
  a fixed CSS size.
- Cyan hex cells with spent sockets for force shields.
- A whole-hide warm-up per molt, an ember rim when angry, a white flash on the dive tell.

The mockups are in `art/contact/alien-insignia-{ranks,shields,phone,glyphs}.png`, made by `tools/alien_insignia`
(Go) from the shipped atlas.

## 4. Notes for the other workstreams
- **R2 `terrain-shadows`.**
  - Every shadow today sits on `Perspective.groundY(n)`, a flat plane.
  - `TerrainView` already exposes `surfaceAt` (height, visible y, slopes, crest occlusion) on a cached mesh, so a sun
    ray march plus a 3 × 2 drape costs almost nothing.
  - The lurking shadow is a presentation-only track on its own PRNG stream.
- **R3 `transition-ascent`.**
  - Today the ship sprite climbs and the world translates by a flat 46 units, with a symmetric speed bump.
  - The fix: a monotonic speed ramp peaking inside the cloud, plus a camera pitch about the horizon (near ground
    leaves first) and a small world roll. The ship barely moves.
  - The front-line calls are in `art/comms/lines.json` now, each on a truthful recorded placeholder, with the voice
    batch pending (tillandsias#1103).
- **R4 `boss-grandeur`.**
  - The altitude change is one camera-height parameter A: sizes and parallax scale by 1/A.
  - The zoom touches the gameplay layer only as a uniform scale about the ship's row; the follow moves only the
    background.
  - Safety is tested by identical simulation logs at two zooms.
  - The view set (38/45/52° × ±12°) works with today's frontal atlas until R5 lands.

## 5. Recommended implementation order
1. **R1 (bug)**, as the operator ordered.
2. **In parallel:**
   - **`alien-insignia`**: the styleguide and mockups are done; the runtime is small and independent;
   - **`boss-hero-assets` B0–B1**: CPU rig turntables, then the frigate pilot heroes on the GPU (about 3 min). These
     need the operator's look approval early, because R4's art depends on them.
3. **`terrain-shadows`.** Self-contained. It also provides the boss caster and the lurking shadow that R4 uses.
4. **`transition-ascent`.** Self-contained, and the comms data is already in. It touches the same FlowDirector plan as
   R4's overflight, so land it before R4.
5. **`boss-grandeur`.** Last. It consumes the R2 casters, the R6 cell language and the R5 atlases. It ships first with
   the frontal-atlas fallback, then switches to the view set when R5 reaches B2 and B3.
6. **`boss-hero-assets` B2–B4** follow R4's in-game integration.
