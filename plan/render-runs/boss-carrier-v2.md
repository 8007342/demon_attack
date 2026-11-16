# Render ledger: boss carrier v2 (R8, R10)

This is the production ledger for the v2 boss art direction: the Thornwake carriers. It records every run, every pick
and why, and what is left.
- Direction: `plan/operator-feedback-2026-11-15b.md` R8 and R10.
- Design: `openspec/changes/boss-hero-assets/design.md` §8.
- Rules: `docs/styleguide/alien-capital-ships.md`.
- Kit: `art/families/alien-carriers.json`.
- Run log: `art/families/alien-carriers-runs.json`.

The operator delegated the picks (project memory "autonomy"). Each checkpoint records the pick, the reasons and the
rejected runs, and the operator can override any of them.

Branch `work/boss-carrier-v2` (worktree `~/.cache/tillandsias-project/worktrees/boss-carrier-v2`), off `game` (with
`origin/game`'s merge of `work/boss-hulls-b3`). The v1 frigate, cruiser and battlecruiser picks in
`plan/render-runs/boss-hero-assets.md` are superseded.

## 0. How to rebuild (preflight of every run)

```sh
PY=$(lua tools/boss_rig/setup_bpy.lua)                                   # bpy 5.3.0 venv (idempotent)
$PY -I tools/rigkit/rig.py art/families/alien-carriers.json --check       # originality, symmetry, counts, anchor gate
(cd tools/rigsheet && go build -o ~/.cache/tillandsias-project/rigsheet .)
lua tools/rigkit/bake_family.lua art/families/alien-carriers.json carrier1-thorn --sheets art/contact/boss-carrier-v2-thorn
```

`bake_family.lua` rebuilds a hull without GPU: rig → fit and symmetrise the committed picks → mask diff → projection
bake → finish → manifest → budget (→ sheets). The picked raws are committed under
`art/sprites/sources/boss-carrier-v2/<hull>/`.

## 1. C1: the shared libraries, the kit and the turntables (2026-11-15, CPU)

**Built**
- `tools/rigkit/` (design §8.5):
  - `rigkit.py`, the bpy module kit;
  - `rig.py`, the rig, `--check` and the controls;
  - `bake.py`, the projection bake;
  - `bake_family.lua`, the no-GPU rebuild;
  - `collect.lua`, studio outputs → raws + run log.
- `tools/rigsheet/` (Go, standard library): finishing, the manifest, the budget and every sheet.
- The v1 `tools/boss_rig` and `tools/boss_sheet` are untouched. They keep the superseded frigate provenance
  reproducible, and `boss-grandeur` is adding its pack to `boss_sheet`, so nothing here edits it.

**The kit** (`art/families/alien-carriers.json`):
- tour 1 is built from six slots with three sets each, baked as three combinations (`carrier1-thorn`, `-lattice`,
  `-shroud`; 9 instances each);
- tours 2–5 add `maw`, `barrier`, `tendril`, `sac` and `crown` slots and extra blister and emitter batteries (13 / 17 /
  21 / 24 instances, extent ×1.08 → ×1.32).

**Look iterations, all on clay, no GPU except one 2-image probe:**
1. **v2a, a round dome with a small prow pod.** The prow read as a mouth with teeth: thin bone pillars between the
   openings, a bead apron and a radiating thorn mane. Two dome blisters read as eyes. Rejected on the first preview.
   It gave the head-reading guard (styleguide §3.4).
2. **v2b, solid bulkheads, battery blisters, forward prongs.** One full-model probe (st-1794784185894-83, seeds
   1010000–1010001, 40 steps, ≈ 5.4 min per image) and 8 Lightning seeds (st-1794784753371-84) showed:
   - a glossy spiked *beetle*: a round dome, a black pod for a jaw;
   - the two violet emitters on the dome read as **eyes** in every seed;
   - the octagonal scale grid painted as studs.

   Rejected. The Lightning batches queued on the v2b controls for lattice and shroud (st-…-85, -86) confirmed it:
   grimacing faces.
3. **v2c (current).** A flat wedge slab:
   - superellipse exponent 6, a straight ±300 front, two terraces, a bone keel or crystal crown;
   - long fore-and-aft armour strakes (a ship's linear detail in grown material) instead of a scale grid;
   - emitters in rows of three per flank, never a lone pair;
   - the thorn prow's thorns jut sideways like a ram;
   - drop offsets fixed (several prims had been buried under the surface).

   It reads as a capital ship in the full-plan lineup and as a hangar deck flanked by prongs at the screen crop.

**Gates.** `--check` ok on all 7 hulls (originality, mirror symmetry by KD tree to 0.5 units, the anchor gate at 9
views). The anchor gate is ok in every rendered view and stage. Two library fixes came from the symmetry check:
- jitter is keyed on |x| (mirror twins draw the same numbers, mirrored);
- dropped elements on the left cast at their right twin and mirror the hit (the BVH triangulates quads along one
  diagonal).

The displacement uses Newell normals.

**CPU.**
- Full rig of the three tour-1 hulls (9 views × S0/S2/S3 × 6 passes): 191–209 s per run, peak RSS 1.57 GB (< 2 GB),
  8 threads.
- Four full runs plus about 15 hero-only previews this checkpoint: ≈ 16 min of Blender wall time.

**Sheets.**
- `art/contact/boss-carrier-v2-kit.png`: per tour-1 combination, the 3 × 3 clay views with hints, the simulation
  windows and the solid body, and the id, depth, S2, S3, normal and hint passes at the hero view.
- `art/contact/boss-carrier-v2-lineup.png`: tours 1–5 as full plans (`--envelope off`) at one scale, with the phone
  screen at Z 0.70 dashed. The ship always overflows it.

## 2. C2: tour-1 heroes, three set combinations (2026-11-15/16, GPU)

**Graphs** (all one-image Qwen-Image-Edit-2511 edits of the coloured-hint clay control on the green key; models already
in the studio; no download):
- `carrier-hero-qwen-fast.json`: Lightning LoRA, 4 steps, 1.6 MP, ≈ 21 s per image;
- `carrier-hero-qwen.json`: the full model, 40 steps, true CFG 4 with the negative, 1.6 MP, ≈ 5.3 min per image;
- `carrier-refine-qwen.json`: the full model at 2.4 MP, 28 steps, denoise 0.40, on a picked hero.

The studio reads workflows from the main checkout, so each run used a byte-identical copy in its ignored `.build/carrier-v2/`.

All runs are logged in `art/families/alien-carriers-runs.json` (workflow and model hashes, inputs, seeds, prompts,
output hashes, verdicts).

| Job | Control | Graph | Seeds | Verdict |
| --- | --- | --- | --- | --- |
| st-…-83 | v2b thorn | full | 1010000–01 | probe; beetle with a jaw pod, emitters read as eyes. Rejected (geometry) |
| st-…-84/85/86 | v2b thorn/lattice/shroud | fast | 1011000–07, 1021000–07, 1031000–07 | glossy beetles and grimacing faces. Rejected (geometry) |
| st-…-87/88/89 | v2c (ctl4) | fast | 1012000–05, 1022000–05, 1032000–05 | **ship-like** for thorn and lattice; very dark; the shroud prow's stacked cases read as a grille mouth |
| st-…-90/91/92 | ctl4 | full, prompt with "lighter lilac-grey edges, lit from the upper left" | 1013000–03, 1023000–03, 1033000–03 | **Rejected:** the value lift overshot into pink-maroon plastic with white tile strakes; less menacing. Lesson: keep the dark prompt and let the finish and the phone mock judge the values |
| st-…-93/94/95 | ctl5 (plate clay 0.54, shroud V cases) | fast, dark prompt | 1014000–07, 1024000–07, 1034000–07 | thorn and lattice good; the shroud's V cases paint as **brows over closed eyes**. Rejected for shroud |
| st-…-96/97/98 | ctl5 | full, dark prompt + negative "pink, magenta, white tiles, bright" | 1015000–01, 1025000–01, 1035000–01 | thorn and lattice picks; shroud's ctl5 brows again (queued before the fix) |
| st-…-100 | ctl6 shroud (staggered scale field, no centre V) | fast | 1036000–07 | brows gone; shroud pick |
| st-…-99 | belly ctl (thorn) | fast | 1019000–03 | belly pick 1019000 |

**Picks (delegated)**
- **carrier1-thorn: 1015001** (full model). Long armour strakes and organic scale shingles on the citadel, bone keel,
  racks of bone thorn-blades on the prongs, rows of violet emitter crystals, small ember gun ports, wine-red membranes.
  Dark, with bright accents only where §2 allows. 1015000 has richer scale texture, but its two big glowing ember
  discs at the prong roots read as a beast's eyes, with the prongs as jaws (head-reading guard). The Lightning
  1014002 and 1014005 are runners-up: more brick-like strakes.
- **carrier1-lattice: 1025000** (full model). A violet crystal crown on the citadel, lattice veins down the flanks,
  bone-rib sail wings, ember batteries on the prongs. 1025001's bone keel is striking, but its wing roots paint as
  pitted bone spheres that read as skulls (rejected under the originality rules). Lightning 1024005 is the
  runner-up.
- **carrier1-shroud: 1036001** (Lightning, ctl6). The darkest scale field over the deck, a thorn forest over the
  slab, sinew between the wing cases, and lobe-chain arms at the frame edge. 1036000 has sinew strands that
  read as hair; 1036002 and 1036003 paint the scale field as pale pebbles (teeth-like).
- **Belly (thorn): 1019000**. An armoured underside banded with ribs, a bone keel spine, rows of ember pores and the
  scythe arms as horns. 1019001–03 painted junk outside the silhouette (the finish masks it, but the keel is weaker).

**Head reading is the main failure mode of this direction.** The rig went through three geometry fixes for it (C1
v2a, v2b; C2 ctl5 → ctl6), and each fix is now a rule in the styleguide §3.4.

Sheets (one per set; control, then per candidate the raw and the hero finished at phone density, zoom 0.70 at DPR 2
= 1.4 px/unit, with the simulation windows):
- `art/contact/boss-carrier-v2-heroes-thorn.png`;
- `art/contact/boss-carrier-v2-heroes-lattice.png`;
- `art/contact/boss-carrier-v2-heroes-shroud.png`.

## 3. C3: tour-1 stages, projection bakes, the budget decision (2026-11-16)

**Stage looks** (Lightning one-image edits; the B3 rules hold: the clause "The black hangar openings stay black and
empty, no fire inside them" in every stage prompt, and S3 chained from the S2 pick):

| Set | S2 job, seeds | S2 pick | S3 job (chained), seeds | S3 pick |
| --- | --- | --- | --- | --- |
| thorn | st-…-102, 1017200–03 | **1017201**: armour torn over a glowing ribcage, gallery dark (1017203: all molten) | st-…-105, 1017300–03 | **1017300**: a breach where the spines tore away, cracks into the deck, smoke inside the outline |
| lattice | st-…-103, 1027200–03 | **1027202**: a glowing sinew network (1027201: the deck repainted as four large openings; 1027203: crossed crystals read as an angry face) | st-…-106, 1027300–03 | **1027303**: the crown is gone, as in the S3 geometry (1027300 keeps it) |
| shroud | st-…-104, 1037200–03 | **1037200**: a molten crack network, deck dark | st-…-107, 1037300–03 | **1037301**: the hull splits along the keel |

**S1 is not baked** (budget decision 3 below). The stage sheets show S1 as an approximation of the runtime overlay on S0
(crystals dimmed, the hull darkened and warmed, ember glints).

**Library fix.** `bake_family.lua` now runs `maskdiff` for **S2 against S0** (scales and emitter crystals shed) as well as
S3 against S0. Without it, the AI's still-painted crystals projected onto the hull behind them.

**Bake.** Each set runs `RIGKIT_REUSE_RIG=1 lua tools/rigkit/bake_family.lua art/families/alien-carriers.json carrier1-<set>
--sheets art/contact/boss-carrier-v2-<set>`:
- the rig: 163 s for all three hulls, peak RSS 1.57 GB;
- the projection bake: 98 renders per hull in about 58 s at 8 threads, layers cropped to their module border;
- the whole run: 126–135 s per hull.

**Mirror check** (rendered −12° against mirrored +12°): 5.7 % (thorn), 6.2 % (lattice), 8.5 % (shroud) of texels,
all on thin spike edges.

**Budget, measured** on the finished stored sprites (`rigsheet budget`, from `manifest.json`):

| Hull | S0 core | S0 mass | S2 | S3 | Wrecks | **Total** | Packed page (`boss_sheet pack`) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| carrier1-thorn | 3.78 | 4.92 | 2.18 | 1.98 | 0.75 | **13.61 MB** | 1 page 4096 × 994 = **15.53 MB** (with the frontal parts) |
| carrier1-lattice | 3.14 | 5.19 | 2.08 | 1.88 | 0.84 | **13.14 MB** | — |
| carrier1-shroud | 2.73 | 5.78 | 2.12 | 1.70 | 1.27 | **13.60 MB** | — |

**How the budget was met (16 MB unchanged).** The first measurement, on a test bake at 6 stored views, mass 1.0 px/unit
and S1 baked, was 21.9 MB for S0 + wrecks alone (≈ 35 MB with stages). The decisions, in the order taken:
1. **The visible envelope** (design §8.3) clips everything that can never reach the screen. This was in from C1.
2. **Texel classes.** The prow (where the player aims) stays at 2.0 px/unit; the hull mass is stored at 0.8 px/unit
   (≈ 1.1 device px per texel at Z 0.70 on a DPR-2 phone). It is dark, mostly behind the fliers, and partly off-screen.
3. **S1 becomes a runtime overlay** (scorch and crystal flicker on S0), as `boss-grandeur` §6 already specified for S1.
4. **Swerve views at the middle pitch only.** The stored views are (38, 0), (45, 0), (45, +12), (52, 0); a
   (38|52, ±12) request draws (45, ±12), and yaw −12 draws +12 mirrored. The glide's pitch change still shows when
   the ship is level, and the swerve when it turns; the combination shows the turn.
5. **The prow and the carapace have no wreck frames** (`wreck: "layer"`): the runtime sinks their own S3 layer.
6. **The pack uses one 4096-wide page and a skyline packer for v2 bakes.** Shelf packing on 2048-wide pages wasted
   ≈ 20 % (18.1 MB for 15.3 MB of sprites).

Rejected alternatives: a 24 MB budget (would keep 6 views at 1.0 px/unit; not justified while the phone mock reads
well at 0.8), and deriving pitch views by vertical scaling (an error of 0.17 × relief height, 17 units at the
citadel top).

**Sheets**
- `art/contact/boss-carrier-v2-{thorn,lattice,shroud}-views.png` (+ `.gif`): the 9 views with the simulation windows
  (unstored views are labelled), and the swerve-and-glide strafe;
- `art/contact/boss-carrier-v2-{thorn,lattice,shroud}-stages.png`: S0, S1 (approx.), S2, S3 at yaw −12/0/+12, S4 wrecks;
- `art/contact/boss-carrier-v2-sets.png`: the three set combinations of tour 1, S0 and S3.

## 4. C4: the phone mock, the belly, and the pack into the game (2026-11-16)

- **`art/contact/boss-carrier-v2-phone-mock.png`.** The thorn carrier is rebuilt from the stored sprites at their stored
  densities, as the runtime draws them (`rigsheet mock` → `composeLayers`), in a 360 × 520 CSS arena at DPR 2. It
  shows four moments:
  - Engage at Z 0.86, centred, with the force-field rim;
  - Climb at Z 0.70, swerving left at pitch 38;
  - S2 at Z 0.76, pitch 52;
  - S3 at Z 0.72.

  Each frame has the ship, the 34-CSS-px creature floor and the shadow on the fog. Verdict:
  - the hull fills the top half to two-thirds of the screen and spills off the top and both sides;
  - the gallery, the gun ports and the ember weak points read; the mass stays dark under the swarm band;
  - stage changes read at a glance.

  Known limit: at Z 0.86 the deck pod with its two lit turret ports can still read as a mouth to a primed eye.
- **Belly** (the `boss-grandeur` gap: the Overflight shows the hull from below). The kit gained underside detail
  (`v_keel`, `v_ribs`, `v_pores` in the carapace common prims; dark ovals there were dropped because pairs of them read
  as eyes). The rig renders `views.belly` (pitch −48) with `--envelope off`. Pick 1019000 is finished at 0.5 px/unit
  to `fin_belly.png`, a manifest entry of kind `belly`, outside the resident budget (0.67 MB, drawn only during the
  Overflight).
- **Pack.** `tools/boss_sheet pack BAKE RIG carrier1-thorn=frigate` (the pack, extended in `pack_v2.go`, reads the v2
  manifest; `BossHeroSprite.ppu` is now a double). It replaced the superseded frigate hero:
  - `assets/images/boss-frigate-hero-0.png`: 4096 × 994, 15.53 MB resident;
  - the regenerated hero section of `lib/game/boss_atlas.dart`, a generated file (no hand edits to `lib/`).

**Not packed in this branch (hand-off).** Packing the thorn carrier as `frigate` worked (15.53 MB on one page), but
`test/boss_grammar_test.dart` "the frigate assembly matches its packed view set" then fails: the v1 grammar's tour-0
ids (spine, bow, tower, engines) are not the v2 ids. `lib/` belongs to `boss-grandeur`, so the pack output was reverted.
The game still draws the v1 frigate hero, repacked byte-identically with the patched tool; the only change in
`boss_atlas.dart` is that `ppu` is now a double. `flutter test`: all tests passed. What the runtime owner does is in
the design §8.6.

## 5. C5: tours 2–5 (2026-11-16, first pass)

The rigs and the full-plan lineup have been in place since C1. One Lightning batch of 4 seeds per tour used the tour's
set prompt plus its escalation line (`prompts.hero_tour_N`) and the clause "The black shapes are deep black empty
hangar mouths" (tours 2+ add flank maws). Jobs st-…-108 to -111, seeds 2014000–03, 3024000–03, 4034000–03, 5014000–03.

| Tour | Hull | Pick | Note |
| --- | --- | --- | --- |
| 2 | carrier2-thorn (13 inst., ×1.08) | 2014000 | the clean strake ship. Rejected: 2014001 (violet glow fills the gallery), 2014002 (two ember dots read as eyes). On the lineup a violet glow sits in the core window: **reroll** with a stronger dark-opening clause |
| 3 | carrier3-lattice (17 inst., ×1.16) | 3024003, provisional | at this extent the lattice prow's crystal and strut row paints as **bone teeth** in all four seeds. **Fix the lattice prow** (point the crystals up and back, drop the struts) before a final pass |
| 4 | carrier4-shroud (21 inst., ×1.24) | 4034003, provisional | the scale field paints pale and tooth-like at this scale; darken the field (plate clay) or replace it with chitin |
| 5 | carrier5-thorn (24 inst., ×1.32) | 5014001 | the crystal crown blazes over a thorn forest: the scariest of the five. 5014002: the scythe arms read as bull horns |

**Bakes (S0 only, no stage looks yet):** `lua tools/rigkit/bake_family.lua art/families/alien-carriers.json <hull>`,
130–139 s each with the rig. The tour-5 bake first failed: a module outside the envelope in a view gave Blender an empty
render border. `bake.py` now skips such layers and wrecks.

| Tour | S0 core | S0 mass | Wrecks | S0 total | Projected with S2 + S3 at stage scale 0.5 | at 0.4 |
| --- | --- | --- | --- | --- | --- | --- |
| 2 | 3.78 | 6.72 | 1.03 | 11.53 | 16.78 | 14.89 |
| 3 | 3.35 | 6.00 | 0.99 | 10.35 | 15.02 | 13.33 |
| 4 | 2.77 | 7.12 | 1.49 | 11.37 | 16.33 | 14.54 |
| 5 | 3.91 | 7.06 | 1.44 | 12.42 | 17.89 | 15.92 |

**Escalation budget plan.** Stage layers at 0.4 × the class density for tours 2–5. Page overhead was ≈ 12 % on
tour 1, so tour 5 also needs mass 0.65 px/unit (or S3 as tile patches over S2, B3 lesson 5) to land under 16 MB as a
packed page. Re-measure after the stage looks.

**Sheets**
- `art/contact/boss-carrier-v2-lineup-finished.png`: the finished S0 of tours 1–5 at one scale, with the phone screen
  at Z 0.70;
- `art/contact/boss-carrier-v2-lineup.png`: the full clay plans;
- `art/contact/boss-carrier-v2-belly.png`: the belly control and the finished belly.

## 6. Spent and left

**GPU** (one job at a time; the queue was never flooded; no failures, no downloads, the studio was never restarted).
There were 140 images in 29 jobs, ≈ 2.6 h from the output timestamps:
- 118 Lightning images at ≈ 21 s (≈ 41 min);
- 20 full-model images at 1.6 MP, 40 steps, true CFG (≈ 5.3 min each, ≈ 106 min);
- 2 refine images at 2.4 MP (≈ 9 min);
- the rest is model loads and queue turnover.

Waste worth naming: the value-lift batch (st-…-90/91/92, ≈ 63 min) and the shroud ctl5 full run (st-…-98, ≈ 11 min)
were rejected.

**CPU** (Blender at 8 threads, peak RSS 1.57 GB): ≈ 35 min of Blender wall time.
- Six full tour-1 rigs (140–209 s each);
- ≈ 40 hero-only and belly previews;
- tour-1 bakes (≈ 60 s of projection per hull, 4 runs);
- tours 2–5 rigs and bakes (≈ 10 min).

Go finishing and sheets took a few minutes more.

**Left**
1. Hand-off to `boss-grandeur`:
   - the grammar on the v2 slot ids;
   - the `prow` as the front pass;
   - a per-run pick among the baked combinations;
   - then `boss_sheet pack BAKE RIG carrier1-<set>=frigate`;
   - the carrier camera band Z 0.70–0.86;
   - the decay events of the styleguide §6;
   - the belly in the Overflight;
   - wreck shadows (the wreck sprites' alpha is the shadow mask).
2. Tours 2–5: reroll tour 2's core glow; fix the lattice prow and the shroud scale field; stage looks; budget at a
   stage scale of 0.4.
3. The scythe-arm wrecks are cropped by the envelope (the wing extends past it). Give wrecks their own frame
   (`--envelope off` rig for wrecks).
