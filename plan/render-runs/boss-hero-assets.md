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

## 3. B2: frigate view set, stages and wrecks (2026-11-15)

**Projection bake** (`tools/boss_rig/project_bake.py`, task 4.1). The picked hero, fitted to the rig frame, is
camera-projected from the hero view onto the hull mesh in object (rest) coordinates. A surface point takes the hero
texel when it faces the hero camera and its hero-view depth matches the rig's 16-bit z pass within 1.5 units;
otherwise it takes a clay-tinted fill (the family colour of its material under a fixed key light). Every view,
module layer (other modules held out, so the layers recompose the beauty exactly) and wreck (module alone at the
hero view, rest and tumbled 24°/−10°/18°) is rendered with that texture, on Cycles CPU, 9 samples. Then
`boss_sheet bakefinish` finishes each image to the atlas density (beauty masked to the view's rig silhouette ±1
texel; palette quantise to the family ramps; ink outline).

**Symmetry (decision).** The atlas stores yaw +12° and draws −12° mirrored (§1, decision 3), so an asymmetric hero
would swap details from side to side mid-swerve. Each projected image is therefore symmetrised about the hull's
centre axis (exact at yaw 0) with `boss_sheet sym`, keeping the **left** half of 921000 (the better-lit half; the
right half reads darker at phone size). Check on the sheet: the mirrored +12° view differs from a rendered −12° view
in 3.6 % of texels (edge anti-aliasing only).

**Stage heroes** (task 4.2), `variant-qwen-edit.json` on the picked hero, 2 seeds each, ≈ 34 s per job:

| Stage | Job | Seeds | Pick | Why |
| --- | --- | --- | --- | --- |
| S1 scorched | st-1794779563530-61 | 923100–923101 | **923101** | soot and glowing hairline cracks, plates still read; 923100's black drips read as oil |
| S2 exposed | st-1794779567292-62 | 923200–923201 | **923200** | plates torn off over a glowing ribcage, maw and bays kept; 923201 is a lava-crack skin with a smoke plume |
| S3 breaking | st-1794779569923-63 | 923300–923301 | — | both put the plates back: an independent edit from S0 breaks the S2 → S3 progression |
| S3 breaking (chained) | st-1794779704501-64 | 923400–923401 | **923400** | edited from the S2 pick: broken ribs, cracked face, chipped horn, burning breaches; 923401 drifts blue and grows a stray hammer |

Rule note: ground forces forbids chaining edits (drift). For damage the drift *is* the point (damage accumulates),
so S3 chains from S2. The S3 geometry has no tower (first in the detach order); `boss_sheet maskdiff` drops the
hero texels where the S3 clay differs from S2 (25 k texels), so the deck behind the lost tower takes the fill
instead of a painted tower. The breach and fire overlays from the rig cover it at runtime.

Picks committed under `art/sprites/sources/boss-selected/frigate/stage/`; picks recorded in `boss-hulls.json`
`selected.frigate`; all 16 runs in `boss-hulls-runs.json`. Rebuild without GPU: `lua tools/boss_rig/bake_hull.lua
frigate --sheets` (rig, fits, maskdiff, sym, bake, finish, budget, sheets).

**Sheets**
- **`art/contact/boss-pilot-views.png`**: the 9 finished views ×1 with the simulation windows; the mirror check; the
  5 module layers recomposed and spread out. **`art/contact/boss-pilot-views.gif`**: a 72-frame strafe at atlas
  density with yaw chosen from the horizontal velocity (±12° above 40 % of max) and pitch from the vertical glide
  (±16 units: 38° above, 52° below), as `boss-grandeur` §5 selects them. The ship reads as one object turning and
  gliding; no material or detail changes between views (by construction).
- **`art/contact/boss-pilot-stages.png`**: S0–S3 at yaw −12/0/+12 and the S4 wrecks (bow, engines, spine, tower;
  rest and tumbled, from the S2 look).

**Budget (task 4.5), measured on the finished layers** (`boss_sheet bakebudget`): S0 module layers 6.07 MB, wrecks
2.58 MB, stage patches 17.45 MB as full module rects → 26.1 MB, **over the 16 MB budget**. The rig-based estimate of
§1 (13.4 MB) assumed patches only where geometry changes; the AI stage looks restyle the whole surface, so every
patch covers its whole module. **Decision (reversible): stage patches S1–S3 are stored at half atlas density and
drawn ×2** (damage textures are blotchy and survive it): 4.36 MB → **13.0 MB total for the frigate**. Bigger hulls
scale like the rig estimate (≤ ×1.15), so ≈ 15 MB for the dreadnought; re-measure at B3. Alternatives on file:
16-px tile patches (13.6 MB of patches, still too much at full density), or S1 as a runtime tint overlay.

**Verdict (delegated): B2 accepted** for the frigate: no drift between views, anchors on the simulation windows in
every view, stages read in order at phone size (S1 is dark; the eyes stay lit). Known limits: faint light rims along
some inner silhouette edges where the hero's anti-aliased edge projects onto geometry; fill areas (nacelle sides,
membrane undersides, the S3 deck) are flat family colour; S2/S3 redraw the face as a ribcage over the maw (the scene
still draws the core window there).

**Not done (next run):** task 4.4, pack (atlas pages ≤ 4096 × 2048 per hull, generated `lib/game/boss_atlas.dart`
with views, modules, stages and anchors). It changes the generated Dart contract that `BossPainter` reads today, so
it should land together with `boss-grandeur` 4.3 (the assembly painter). Task 4.3 (optional seam heal) is skipped:
the projected views need no healing at this spread.

## 4. B3: the four remaining hulls (2026-11-15)

Branch `work/boss-hulls-b3` (worktree `~/.cache/tillandsias-project/worktrees/boss-hulls-b3`), off `game`. Same
pipeline as the frigate, one commit per hull. Rebuild any hull without GPU: `lua tools/boss_rig/bake_hull.lua <hull>
--sheets` (sheets go to `art/contact/boss-b3-<hull>-{views,stages}.png`; the frigate keeps its `boss-pilot-*` names).
The finished outputs land in `~/.cache/tillandsias-project/boss-bake/<hull>/` in the frigate's layout (`S0..S3/fin_beauty_*`,
`fin_layer_*`, `fin_wreck_*`), so the `boss-grandeur` pack drops them in.

**Brief.** The operator wants later tours to bring larger, scarier, more complex ships of the same family; the
frigate hero 921000 is the identity reference. The rig already grows the hull tour by tour (5 → 17 modules, extent
×1.00 → ×1.60, B0). The hero prompts escalate the *look* with it: each hull has its own prompt in
`boss-hulls.json` `prompts.hero_qwen_<hull>` (all keep the frigate's stone, bone, ember and clay-mapping
sentences, and name "the same family as a violet stone gargoyle frigate"):
- cruiser: violet slag-glass over the stone (its palette lead), longer horns, torn wing membranes, gun pylons;
- battlecruiser: blackened stone in thick layered plates with glowing ember seams and vents, heavy pods;
- battleship: gothic arches, buttresses and spires, arched ember windows, the keel blade;
- dreadnought: the darkest, scarred stone with molten seams, crowns of spikes, twin towers, brood sacs.

**Tool changes** (no change to the frigate's outputs): `boss_sheet` sheet titles say `BOSS HULL … (B3)` and the
picked seed for hulls other than the frigate; the B1/B3 hero sheet's CSS-size column now scales by the hull's own
texel density (it assumed the frigate's 2 px/unit, which misplaced the sim windows on bigger hulls);
`bakebudget` prints the decided total (stage patches at half density).

### 4.1 Cruiser (tour 2, Brood Cruiser, 8 modules, 1.9 px/unit)

| Job | Graph | Seeds | GPU | Result |
| --- | --- | --- | --- | --- |
| st-1794780837344-65 | `variant-qwen-edit.json`, clay + hints, `hero_qwen_cruiser` | 931000–931003 | 60 s | all four on the rig |
| st-1794780903888-66 | `heading-qwen-edit.json`, image 2 = **frigate hero 921000** (the B1 follow-up test), `hero_qwen_ref` | 930000–930001 | 49 s | **Rejected.** Both copy the frigate's short wings and grey stone and drop the cruiser's wide sails and pylons: two-image edits pull toward image 2 even when it already has the new pose. Settles the B1 question: 1-image prompts for every hull |
| st-1794781019479-67 | S1 edit of 931000 | 933100–933101 | 33 s | |
| st-1794781053640-68 | S2 edit of 931000 | 933200–933201 | 33 s | |
| st-1794781108709-69 | S3 edit **chained from S2 933200** | 933400–933401 | 35 s | |

**Picks**
- **Hero 931000.** On the rig (maw and bays on the sim windows at CSS size); deep violet slag-glass panels over the
  frigate's stone, longer horns and spikes, torn wing membranes on bone fingers, lit gun pylons and a lit tower slit.
  It reads as the frigate's bigger, meaner sibling. Runner-up 931003 (committed): tusks across the maw, angrier,
  but muddier at CSS size. Rejected: 931001 and 931002, whose round bone ornament at the tower foot reads as a head
  emblem.
- **S1 933100:** soot and glowing hairline cracks, plates and lights still read (933101: black drips).
- **S2 933200:** plates torn over a burning ribcage, maw and bays kept dark (933201: flames fill the maw and bays,
  smoke outside the silhouette).
- **S3 933401** (chained): cracked face, snapped horn, breaches, maw still dark; the debris it paints outside the
  hull is masked off by the rig silhouette. 933400 fills the maw with flames, which would hide the core window.

**Bake.** Rig 21 s; projection bake 331 renders in 189 s (8 threads); whole `bake_hull.lua` 280 s. Anchor gate ok
in all 27 stage × view renders. Mirror check: the mirrored +12° view differs from a rendered −12° view in 14.5 % of
texels (frigate 3.6 %): the cruiser's many thin wing spikes add anti-aliased edge texels; no detail swaps sides on
the sheet.

**Budget:** S0 layers 7.36 MB + stage patches at half density 5.14 MB + wrecks 2.74 MB = **15.23 MB** (≤ 16; 15.82 MB
before the wreck-pair decision of §4.2).

Sheets: `art/contact/boss-b3-cruiser-heroes.png`, `-views.png` (+ `-views.gif`), `-stages.png`.

### 4.2 Battlecruiser (tour 3, Siege Battlecruiser, 11 modules, 1.7 px/unit)

| Job | Graph | Seeds | GPU | Result |
| --- | --- | --- | --- | --- |
| st-1794781364001-70 | `variant-qwen-edit.json`, `hero_qwen_battlecruiser` | 941000–941003 | 60 s | all on the rig |
| st-1794781569207-71 | S1 edit of 941001 | 943100–943101 | 35 s | |
| st-1794781605550-72 | S2 edit of 941001 | 943200–943201 | 36 s | both fill the maw with fire and light the bay frames |
| st-1794781661198-73 | S2 reroll, prompt + "The fanged maw and the two hangar bays stay dark and empty, no fire inside them." | 943210–943211 | 35 s | maw and bays dark |
| st-1794781712508-74 | S3 chained from S2 943210 (same clause) | 943400–943401 | 35 s | |

**Prompt change (all later stage edits):** S2 and S3 add "The fanged maw and the two hangar bays stay dark and empty,
no fire inside them." On the cruiser one of two S2 seeds and one of two S3 seeds lit the maw; on the battlecruiser
both S2 seeds did. The core window and the bays must stay dark: the scene draws the core glow and the launch light
there itself.

**Picks**
- **Hero 941001.** On the rig. The family's biggest, angriest snarl sits exactly over the core window, with ember
  seams across the brow, an arched ember window in the tower, and heavy hanging pods with glowing mouths. It is
  more brutal than the cruiser without going black. Runner-up 941000 (committed) has the strongest ember seams, but a
  round bone knob on the turret dome reads as an emblem. Rejected: 941002 (bright purple; the bays stretch into tall
  doors past the bay windows) and 941003 (near-black: at CSS size only the eyes and pod mouths read, the same
  failure as frigate 921003).
- **S1 943100** (soot splotches and glowing cracks; 943101 is too subtle).
- **S2 943210** (broken plates and fires, maw and bays dark; 943211 keeps most plates).
- **S3 943400** (chained: wider molten cracks, shattered wing edges; 943401 reads *less* damaged than its S2
  input).

**Bake.** Rig 27 s; projection bake 445 renders in 276 s; whole `bake_hull.lua` 387 s. Anchor gate ok. Mirror
check 8.9 % of texels.

**Budget decision: mirrored wreck pairs are stored once.** Measured first at 16.52 MB (S0 7.93 + stage patches at
half density 5.09 + wrecks 3.50), over the 16 MB budget. The atlas already stores yaw −12° as mirrored +12°, and a
mirrored module pair once at yaw 0. The same rule now covers the S4 wrecks: `<m>L` is stored and `<m>R` draws it
flipped, which reads as the mirrored tumble. This loses no hull texel. `bakebudget` counts it this way, and the pack
should store only the L wreck of each pair. Frigate 13.0 → 12.80 MB, cruiser 15.82 → 15.23 MB, **battlecruiser
15.80 MB** (S0 7.93 + stage patches 5.09 + wrecks 2.79).

Sheets: `art/contact/boss-b3-battlecruiser-heroes.png`, `-views.png` (+ `.gif`), `-stages.png`.
