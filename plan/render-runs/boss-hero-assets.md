# Render ledger: boss hero assets (R5)

The production ledger for `openspec/changes/boss-hero-assets/`: every run, every pick and why, and what is left.
Research and verdict: `plan/round2-research.md` §1–§2. The ground-forces precedent (rig → one AI hero → bake, the CP1
lean hybrid) is `plan/render-runs/ground-forces-rework.md` §1, §12. The operator delegated the picks (project memory
"autonomy"), so each checkpoint below records the pick, the reasons and the rejected runs; the operator can override.

Branch `work/boss-hero-assets` (worktree `~/.cache/tillandsias-project/worktrees/boss-hero-assets`), off `game`.

## 0. How to rebuild (preflight of every run)

```sh
PY=$(lua tools/boss_rig/setup_bpy.lua)                 # idempotent: uv Python 3.13 + bpy 5.3.0 venv in the cache
$PY -I tools/boss_rig/build.py --check                  # grammar gate: counts, symmetry, anchors, budget bound, words
for h in frigate cruiser battlecruiser battleship dreadnought; do   # one Blender process per hull, 8 threads
  $PY -I tools/boss_rig/build.py ~/.cache/tillandsias-project/boss-rig --hulls $h
done
(cd tools/boss_sheet && go build -o ~/.cache/tillandsias-project/boss_sheet .)
~/.cache/tillandsias-project/boss_sheet budget ~/.cache/tillandsias-project/boss-rig frigate cruiser battlecruiser battleship dreadnought
~/.cache/tillandsias-project/boss_sheet turntables ~/.cache/tillandsias-project/boss-rig art/contact/boss-rig-turntables.png frigate cruiser battlecruiser battleship dreadnought
```

The rig outputs (≈ 25 MB per hull) live in the cache and are fully reproducible from the committed grammar and
scripts. The picked AI raws are not reproducible byte for byte (GPU nondeterminism), so they are committed under
`art/sprites/sources/boss-selected/`.

## 1. B0: rig and turntables (2026-11-15, CPU only)

**What was built**
- `tools/boss_rig/setup_bpy.lua` (task 1.1): the venv survived; the preflight checks `import bpy` = 5.3.0 and
  reinstalls only when it fails.
- `art/families/boss-hulls.json` (task 1.2, schema `demon-attack.boss-hulls/v1`): the ten-module catalogue of
  `boss-grandeur` §7 as primitive recipes (box, loft, cylinder, ellipsoid, horn, prism, membrane web), the five tour
  assemblies (5 / 8 / 11 / 14 / 17 modules, extent ×1.00 → ×1.60), stage geometry, palettes, prompts and the
  originality word list.
- `tools/boss_rig/build.py` (tasks 1.3, 2.1, 2.2): `--check` and the renders. Per hull, 9 views × S0/S2/S3 ×
  clay, hint, depth, normal, id (+ z at the hero view), and `rig.json` (frame, px per unit, cameras, module ids,
  projected anchors, lights, fires and nozzles with visibility, gate results).
- `tools/boss_sheet` (Go, standard library): sheets, the measured budget, finish, today's atlas frame.

**Design decisions taken in the rig** (not in the change text, recorded here):
1. **The functional face is the hero-facing plane.** The gargoyle head (bow module) is authored in "face frame"
   coordinates: arena x/y on the plane through the carrier centre that faces the 45°/0° camera. A point on that
   plane projects to the same arena position at 38° and 52° to second order (error ≤ 0.3 units at the solid body's
   edge). So the core maw, bays, turrets and eyes stay on the simulation windows at every pitch by construction.
2. **The swerve is a banked turn about the hero view's screen-up axis** (ship frame (0, .707, .707)), not a pure
   yaw about the vertical. A pure ±12° yaw moved the bay windows 6.8 units vertically (a hard fail of the ±3 gate).
   Turning about the hero's screen-up axis is a coordinated turn (≈ 8.5° heading + 8.5° bank into the turn), keeps
   the face plane on screen (bays move ≤ 1 unit), and reads as a heavy ship swerving. Positive yaw turns the bow to
   screen right. The far modules (tower, wings, engines) swing with real parallax.
3. **Yaw −12° is the mirror of +12°.** The hulls are mirror-symmetric (checked), so the atlas stores 6 views
   (3 pitches × {0, +12}) and draws −12 flipped; at yaw 0 a mirrored module pair is stored once. This is what
   brings every hull under 16 MB (below).
4. **Hints are a separate flat pass** (`hint_*.png`: white = eyes and lit windows, black = maw and bay mouths),
   drawn into the clay control by `boss_sheet clayhint`. Workbench's studio light greyed the hint materials out.
5. **Emission passes on Cycles, not EEVEE.** EEVEE's software-GL start costs ≈ 1.55 GB on its own (measured), which
   put a hull at 2.0–2.2 GB peak RSS, over the forge's 2 GB budget. Cycles CPU at one centre sample per pixel gives
   exact depth/normal/z values at 0.76–0.95 GB peak and is faster.

**Results**
- `--check`: ok (module counts 5/8/11/14/17, mirror symmetry, originality words, anchors and solid-body coverage at
  all 45 hull × view pairs). The bbox budget bound warns for the three biggest hulls (no occlusion trim); the
  measured gate below is the one that counts.
- **Anchor gate (task 2.2): ok in all 135 hull × stage × view renders.** Core maw, both bays and both turret pivots
  within ±3 units of `BossAtlas` (worst observed error well under 2 units, at the bays in the ±12° views), every
  anchor unobstructed (camera ray hits the bow), and the solid body (inset 3) covered by hull in every view.
- **Measured budget** (`boss_sheet budget`: id-mask rects at atlas density for S0 layers, S1 = S2 patch rects, S2
  and S3 patches from the clay differences, 6 stored views): frigate 13.41 MB, cruiser 14.75, battlecruiser 14.84,
  battleship 15.40, dreadnought 15.25 — **all ≤ 16 MB**. To get there the texel densities of the three biggest
  hulls were trimmed from the design's 1.75 / 1.6 / 1.5 px per unit to **1.7 / 1.55 / 1.42** (first measurement:
  16.11 / 16.90 / 17.37 MB).
- **CPU:** final full rig, all hulls, one process per hull at 8 threads: 113 s (frigate 14 s … dreadnought 35 s),
  peak RSS 763–945 MB. Including the iterations of this session (EEVEE runs, re-renders after design fixes) the rig
  used ≈ 14 min of Blender wall time.
- Sheet: **`art/contact/boss-rig-turntables.png`** — per hull, clay with hints at the 9 views at ×1 (atlas
  density) with the simulation windows (cyan) and the solid body (gold) overlaid, and at the hero view the module-id
  map, the depth control, S2 (plates off), S3 (first module gone) and the normal pass.

**Look iterations before B0** (all reviewed on the sheet, no GPU): the first head was a round flat mask with a
"worried" brow. Changed: the cheeks swept back 25° about a hinge outside the bays, a pointed chin, angry eye slits
under a heavy V brow (inner ends low), and the engine fingers raised into today's top-corner bat-wing silhouette.
The battleship/dreadnought keel blade was shortened and thickened (it read as a thin stick).

**B0 verdict (delegated):** accepted. Silhouettes read as one family growing tour by tour; the fixed gargoyle head
keeps the simulation windows while the hull, wings, sails, pods and spires grow behind it. Known limits: the pitch
views differ subtly (by design the face is pitch-invariant; the parallax is in the tower, wings and engines); the
bay pods' launch mouths read as dark blobs under the pods in clay.

**Not done in B0:** task 2.3, the Go ray-cast fallback rig (`tools/ground_blocks boss`). The bpy route works and is
now light (< 1 GB), so the fallback stays a documented contingency; it is needed only if the wheel stops installing.

## 2. B1: frigate pilot heroes (2026-11-15, GPU)

Input: the rig's hero view (pitch 45°, yaw 0°) as clay with hints on a flat green key
(`art/sprites/sources/boss-selected/frigate/hero/frigate-clay-key.png`), the hero depth with hints, and today's atlas
frame of the frigate (`boss_sheet atlasframe frigate`: superstructure form 0 behind the bow idle frame, maw and bay
holes filled with ink) on green (`today-frigate-key.png`). Green, not magenta: the hull family is violet.
Provenance of every run: `art/families/boss-hulls-runs.json` (workflow and model hashes, inputs, seeds, prompts,
output hashes, verdicts).

| Job (ticket) | Graph | Seeds | GPU | Result |
| --- | --- | --- | --- | --- |
| st-1794778348780-58 (tk-…-13) | `heading-qwen-edit.json`, image 1 = clay, image 2 = today's frame, denoise 1.0, prompt `hero_qwen` | 920000–920001 | ≈ 51 s | **Rejected.** Both redraw image 2 — today's frigate, its pose and silhouette — and ignore the rig. Exactly the CP1 finding (two-image edits are binary). Beautiful, but not projectable |
| st-1794778445464-59 (tk-…-14) | `variant-qwen-edit.json`, clay only, prompt `hero_qwen_single` (identity in words: violet-grey carved stone, bone horns, ember eyes, fanged maw, bat membranes, gothic tower) | 921000–921003 | ≈ 68 s | **On the rig.** All four keep the outline, the maw, bays, turrets, horns and tower where the rig put them, and read as the same family as today's boss |
| st-1794778941032-60 (tk-…-16) | `boss-hero-sdxl-cn.json` (new, task 3.1): SDXL base + ControlNet-union promax (depth, 0.85) + IP-Adapter plus (today's frame, 0.6) | 922000–922001 | ≈ 44 s | On the rig but flat, pale lavender or beige plating, noisy key; least menacing. **Not the scaling graph** |

GPU for B1: ≈ 2.7 min (3 jobs, 8 images), no rerolls, no failures (one SDXL-CN queue attempt was refused before
running because the studio reads workflows only from the main checkout; it ran from a byte-identical copy in the
ignored `.build/` folder there).

**Pick (delegated): Qwen single-image seed 921000** — `art/sprites/sources/boss-selected/frigate/hero/921000.png`.
- *Scary:* red-hot eyes under a heavy brow, a wide fanged maw, bone horns and spikes, rivets and plates; the dark
  violet stone keeps it ominous without going black.
- *Readable at phone size:* at CSS size (1 px per unit) the eyes, maw, bays and horns still separate; the bays and
  maw land on the simulation windows (sheet, right column).
- *Family resemblance:* the same violet-grey carved stone, ivory horns, ember eyes and ember-lit windows as today's
  frigate; the gargoyle face is now the whole bow.
- Runner-up 921002 (also committed): just as faithful but darker and flatter. Rejected: 921001 (paints bat
  membranes over the turrets), 921003 (bays turned into tusks, too dark), both 2-image runs, both SDXL-CN runs.
- **Graph decision:** Qwen-Image-Edit single image (clay + hints in, identity carried by the prompt and palette)
  scales to the other hulls. macron.dev's "identity from a reference image" did not work here: with today's frame
  as image 2 Qwen copies the old ship, and IP-Adapter on SDXL dilutes the look. The identity reference still matters
  — at B3 the picked frigate hero (not today's frame) is a candidate image 2 for the bigger hulls, to test whether a
  reference that already has the new pose fares better.

Finish (`boss_sheet finish`, colour-preserving like ground-forces A1): the raw is fitted to the rig frame, its alpha
is the rig silhouette dilated by one atlas texel minus key pixels (BiRefNet is not needed: the rig owns the
silhouette), green is despilled, the image is area-downscaled to the atlas density and quantised to the family ramps,
with an ink outline. Sheet: **`art/contact/boss-pilot-heroes.png`** (header: clay control, depth control, today's
frame; one row per candidate: raw, finished ×1, CSS size with the simulation windows, verdict).
