# Render plan: ground forces rework

The production plan for the art in `openspec/changes/ground-forces-rework/`: which workflows, which family specs, which review checkpoints, and how many GPU jobs. **Nothing here has been run.** Every GPU step waits for the operator's go at the checkpoint before it, and follows the studio rules in [rerender-all.md](rerender-all.md) (one job at a time on the host studio, push after every checkpoint, keep raws under `/home/forge/.cache/tillandsias-project/`, never on the tmpfs checkout).

Design: [../ground-unit-animation.md](../ground-unit-animation.md) (frames and blocks), [../human-ground-forces-style-guide.md](../human-ground-forces-style-guide.md), [../gargoyle-army-style-guide.md](../gargoyle-army-style-guide.md), [../ground-atmosphere.md](../ground-atmosphere.md), [../ground-easter-eggs.md](../ground-easter-eggs.md).

## 1. Pipeline

The approved sprite pipeline is the refinement pilot's (rerender-all, Section 5.1): **Qwen-Image-Edit-2511 redraws a reference, BiRefNet mattes it, and the family's finishing step puts it on the grid with the family palette.** The rework adds a rig in front (so every heading and frame starts from the same geometry) and a video model for organic in-betweens.

```
 rig (Go, no GPU)            GPU                                    finish (Go, no GPU)
 ───────────────            ───                                    ───────────────────
 unit rig ──► grid frame ─┬─► reference ×8 ─► Qwen edit (heading) ─► BiRefNet ─► area downscale
 (boxes, wedges,          │   (flat key bg)      + hero keyframe                     │
  tracks, legs)           │                                                         ▼
                          │                                         palette quantise to family ramps
                          └─► control clip ──► Wan2.2 VACE ──► frame pick ─► BiRefNet ─► (same)
                              (silhouette+depth) + keyframe                              │
                                                                                         ▼
                                     mask to the rig silhouette (±1 texel where the rig marks a soft edge)
                                     ► binary alpha ► outline ink ► overlays (fill, lights, dmg) from the rig
                                     ► per-sector ramp remap + kit ► debris cut ► pack per sector + Dart metadata
```

Rules that keep animation aligned:
1. **The rig owns the silhouette and the anchor.** The grid frame from the rig fixes the outline, the contact row, the turret pivot and the leg gap. AI output may move an edge by at most 1 texel, and only where the rig marks a soft edge (ornament tips, hair, banners). Everything else is masked back to the rig.
2. **One hero per unit.** The first approved keyframe (the primary heading) is the second reference image for every other heading and every in-between of that unit, so materials and colours stay the same across the turntable.
3. **Never chained.** Each heading is edited from its own rig reference plus the hero, never from the previous heading's output (the drift rule in `plan/asset-pipeline/README.md`).
4. **Temporal gate.** Within one move cycle, interior pixels outside the animated parts may differ by at most 8% between consecutive frames after finishing; frames that flicker more are re-finished with the hero's shading transferred instead.
5. **Overlays are never AI.** Channel fills, lights, damage seams, pitch shears and debris cuts are generated on the grid from the rig, so they always line up.

## 2. Workflows

| Workflow | Status | Use |
| --- | --- | --- |
| `art/workflows/sprites/variant-qwen-edit.json` | **Committed** (pilot) | Hero keyframes: one reference (the rig render) plus prompt |
| `art/workflows/sprites/heading-qwen-edit.json` | **Add** | Copy of `variant-qwen-edit.json` with a second `LoadImage` feeding `image2` of both `TextEncodeQwenImageEditPlus` nodes. image1 = rig render at the target heading or pose, image2 = the approved hero. Prompt prefix: "Redraw image 1 with exactly the materials, colours and detail of image 2. Keep the outline, pose and viewing angle of image 1." |
| `art/workflows/comms/matte-birefnet.json` | **Committed** | Mattes single images |
| `art/workflows/sprites/matte-birefnet-batch.json` | **Add** | The same BiRefNet graph over an image batch (one job per in-between clip) |
| `art/workflows/sprites/inbetween-wan-vace.json` | **Add** | Wan2.2 VACE 14B (fp8), lightx2v 4-step LoRA, 480 × 480, 17 or 33 frames. Inputs: reference image (the finished keyframe at ×8 on the key colour) and a control clip (the rig's silhouette and depth for the motion). Output: an image batch |
| `art/workflows/backgrounds/strip-sheet.json` | **Committed** | Seam-healed horizontal strips: the `lowCloud` decks (optional AI pass) |
| `art/workflows/backgrounds/sprite-transparent.json` | **Committed** | SDXL + pixel-art-xl + LayerDiffuse transparent sprites: flock flyers |

Concept art for the Fleet (optional, review only) goes through `image.generate` with the host's consent flow, not a committed workflow: ask the operator before any first-time model download.

All new workflows take seeds and prompts as inputs, are committed before their first run, and record model hashes in the `*-runs.json` provenance as the existing families do.

## 3. Family specs to add

All under `art/families/`, schema `demon-attack.ground-blocks/v1` (shared by the three unit families), each validated with `studio.validate_family` before any run.

| Family spec | Produces | Seeds |
| --- | --- | --- |
| `ground-fleet.json` + `ground-fleet-runs.json` | `assets/images/ground-fleet-<sector>.png` | 78xxxx (Fleet style guide, Section 10) |
| `ground-host.json` + `ground-host-runs.json` | `assets/images/ground-host-<sector>.png`. Replaces the 16 × 12 single-atlas layout planned in `gargoyle-ground-army` (decision 4) with the block layout | 76xxxx (gargoyle guide) |
| `ground-infantry.json` + `ground-infantry-runs.json` | `assets/images/ground-infantry-<sector>.png`, both factions | 7601xx Host, 7804xx Fleet |
| `ground-atmosphere.json` + `ground-atmosphere-runs.json` | `assets/images/ground-atmosphere.png` | 7900xx |
| `ground-wildlife.json` + `ground-wildlife-runs.json` | `assets/images/ground-wildlife.png` | 7910xx |

Shape of a unit entry (illustrative, for the family-spec task):

```json
{
  "id": "lodestar",
  "faction": "fleet",
  "block": "V",
  "slot": {"sector": "ember", "variant": 0},
  "headings": [0, 22.5, 45, 67.5, 90],
  "art": {"kind": "turret", "angles": [0, 22.5, 45, 67.5, 90]},
  "rig": "rigs/lodestar.json",
  "size_texels": {"h0": [26, 24], "h90": [36, 19]},
  "subject": "a futuristic main battle tank, low faceted wedge hull ...",
  "sectors": {"ember": {"modifier": "soot dark lower hull, square heat-shield tiles"}},
  "seed": 780200,
  "hero": {"heading": 45, "candidates": 4, "selected": null},
  "headings_candidates": 2,
  "inbetweens": []
}
```

The rig files live beside the family (`art/families/rigs/<unit>.json`): primitives (box, wedge, chamfered box, cylinder, track band, leg segment), the turret pivot, the channel path (Host), the eye and light points, the seam lines for debris, and soft-edge marks.

**Tooling.** `tools/ground_blocks` (Go, standard library), with verbs `rig`, `jobs`, `ingest`, `finish`, `pack`, `contact` and `offline`. It supersedes the `tools/ground_host` planned in `gargoyle-ground-army` and shares the rasteriser and keyframe shading of `tools/ground_troops`, which is why it is Go and not Lua (the forge's preferred order is Lua, Rust, Go; the gargoyle change made the same call). `offline` builds every atlas from the rig alone with rig shading, so the runtime can integrate the block contract before any GPU work.

## 4. Review checkpoints (contact sheets)

Each checkpoint is a contact sheet made with `studio.contact_sheet` (no GPU) or the tool's `contact` verb, committed under `art/contact/`, then reviewed by the operator. Nothing after a checkpoint runs before it is approved.

| # | Checkpoint | Sheet | Operator decides |
| --- | --- | --- | --- |
| CP0 | **Rig turntables** (no GPU) | `ground-rig-turntables.png`: every unit's black fill and rig shading at all headings, ×0.62 / ×1.0 / 3×; turret × hull seating grid | Heading count (5 per faction), silhouettes, black-fill role sort, sizes |
| CP1 | **Pilot**: Lodestar, Crocket, Ashlar Guard | `ground-pilot.png`: hero candidates, the 5-heading turntables, one in-between clip each, over Ember and Hollow ground at phone size | The look; whether the pipeline (rig + Qwen + VACE) is good enough to scale. Default if rejected: grid frames with rig shading plus keyframe shading only (the ground-troops method) |
| CP2 | **Fleet heroes** | `ground-fleet-heroes.png`: primary heading, all 7 vehicles and 2 troopers, greyscale strip, black-fill strip | Fleet style |
| CP3 | **Host heroes** | `ground-host-heroes.png`: all Tier A units and the refresh, per-sector remaps | Host style and corruption gradient |
| CP4 | **Turntables** | `ground-fleet-turntables.png`, `ground-host-turntables.png`: all headings and turret angles, animated strips at 1× and 3× | Headings read as a rotation; no drift between headings |
| CP5 | **Animation sets** | `ground-*-animation.png`: every state per unit as a frame strip, plus GIF previews | Motion quality: idle, wind-up and release, hit, death, arrival, specials |
| CP6 | **Atmosphere** | `ground-atmosphere-contact.png`: every layer per sector, then composited over each sector with units at z 1400 / 1100 / 850 / 600 at 360 × 780 | Fog density and tint, emergence, lane cap |
| CP7 | **Easter eggs** | `ground-easter-eggs.png`: flyers, critter leaps, debris sheets, dance strips | Charm, and that nothing reads as a target |
| CP8 | **In game** | Review frames from the runtime work at 360 × 780 and 1280 × 720 in every sector | Final acceptance per sector |

## 5. GPU job estimate

Per-job times are from the pilot and the model research on the A5000: Qwen-Image-Edit-2511 (fp8, Lightning 4-step) about 13 s; BiRefNet about 4 s per image (about 20 s per 33-frame batch); Wan2.2 VACE 14B (fp8, lightx2v 4-step, 480², 33 frames) about 2–4 min; SDXL transparent sprite about 25 s; FLUX.2-klein-4B about 6 s.

**Units in scope.** Fleet: 7 vehicles (6 V, 1 W) and 2 infantry. Host: 6 V (Crocket, captured Crocket, Tympanum, Reliquary, Carillon, Hodcrawler), 1 W (Buttress Strider), 1 K (Chapterhouse), 5 infantry. Sector looks are offline ramp remaps of one master, not separate renders.

| Item | Count | Candidates | Jobs | Model |
| --- | --- | --- | --- | --- |
| Hull heroes (primary heading) | 15 units | 4 | 60 | Qwen edit |
| Hull, other headings | 58 (14 units × 4 + the Chapterhouse's 2) | 2 | 116 | Qwen edit (heading) |
| Articulated layers (turrets, pods, cradle, jib, gunner) | 53 angles | 2 | 106 | Qwen edit (heading) |
| Infantry keyframes | 7 units × 3 headings (hero 4, others 2) | | 56 | Qwen edit |
| Infantry terrain poses (climb, descend, jump, wade) | 7 units × 4 | 2 | 56 | Qwen edit |
| Wreck / totalled keyframes | 15 | 2 | 30 | Qwen edit |
| Critter leap poses | 10 species × 2 | 1 | 20 | Qwen edit |
| **Qwen edit subtotal** | | | **444** | about 1.6 h |
| Mattes of every Qwen candidate | | | **444** | BiRefNet, about 0.5 h |
| In-between clips: infantry walks (21), infantry actions (42: idle, wind-up and fire, hit and fall, arrival, flee, flourish), walker strides (13), specials and arrivals (16) | 92 | 2 | **184** | Wan2.2 VACE, about 9 h |
| Batch mattes of every clip | | | **184** | BiRefNet, about 1 h |
| Flock flyers | 5 species | 4 | 20 | SDXL transparent |
| Low cloud decks (optional; procedural first) | 5 sectors | 4 | 20 | SDXL strip |
| Fleet concept turnarounds (optional) | 7 | 3 | 21 | `image.generate` |
| **Total** | | | **about 1,320 jobs** | **about 13 GPU hours** |

Allow 15% for rerolls: **about 1,500 jobs and 15 hours**, run in phases with the checkpoints between them.

**Lean option** (if CP1 shows the video in-betweens are not worth their cost): VACE only for the 7 primary-heading infantry walks, the 3 primary walker strides and the 16 specials (26 clips, 52 jobs, about 2.6 h); the other 66 clips become 3 Qwen pose edits each with one candidate (198 jobs plus 198 mattes). That is about 1,450 jobs but **about 6.5 GPU hours**.

**No-GPU parts** (all in `tools/ground_blocks`): grid frames, track and wheel cycles, the Skiff hover bob, every overlay (channel fills, lights, damage), pitch shears, ford bands, debris cuts, per-sector remaps, atmosphere layers (procedural from seeded noise, as the existing ground fx), packing and metadata.

### Phases

| Phase | Content | Jobs (full) | Gate before |
| --- | --- | --- | --- |
| 0 | Rigs, `offline` atlases, CP0 sheet | 0 | Operator approves the design docs |
| 1 | Pilot: Lodestar, Crocket, Ashlar Guard (heroes, headings, turret, 2 VACE clips each) | about 90 | CP0 |
| 2 | Fleet: remaining units | about 480 | CP1 |
| 3 | Host: remaining Tier A and refresh | about 650 | CP2 (can run in parallel with Phase 2 if the operator prefers Host first) |
| 4 | Threat vehicles (Gutter-runner, Scrapmason, Kiln Ox, Belfry) as V/W blocks, behind a flag | about 230 more | CP5 and a gameplay check of telegraph timing |
| 5 | Atmosphere and wildlife | about 80 | CP4 |

## 6. Ledger

When a phase runs, log it here as the radio and flyover runs are logged in `rerender-all.md`: date, phase, job ids, failures, picks, and the commit of the packed atlases. Add a line to `rerender-all.md` Section 5.3 pointing at this file.

## 7. Phase 0 results (2026-11-14, no GPU)

Branch `work/ground-blocks`. Everything below is CPU only and regenerates byte-identically.

**Tool.** `tools/ground_blocks` (Go, standard library plus the shared rasteriser `tools/pixelgrid`, which was split out of
`tools/ground_troops`; the ground-troops atlas, Dart file and contact sheet are byte-identical before and after the split).
A rig is a set of convex primitives in texels (box with chamfers and cuts, n-gon prism and frustum, square bar, ellipsoid,
two-segment leg) plus marks: material, tags for poses, emissive lights, channel stages 1–3, debris pieces, soft edges, and
a gait for legged units. Every cell is an orthographic ray cast (camera 30° down, light from the upper left, flat facet
shading, rim light, ink outline), so headings, layer angles, pitch and arrivals all come from one geometry.

```bash
cd tools/ground_blocks
go run . validate     # three family specs against the 26 rigs (stands in for studio.validate_family)
go run . offline      # rig-only atlases per sector + lib/game/ground_blocks_atlas.dart + art/families/ground-blocks-pack.json
go run . contact      # art/contact/ground-rig-turntables.png (CP0)
go run . rig [ids]    # x8 rig references on the key colour for the GPU jobs ($BLOCKS_WORK/rig)
go run . jobs         # the queue: 104 hero, 176 heading and 160 layer edits (440 jobs)
go run . ingest       # raws -> $BLOCKS_RAW, provenance into the families' -runs.json
go run . finish IN.png <cell>   # one AI image back on the grid (mask, quantise, ink)
go run . pack         # like offline, but uses finished cells under art/sprites/sources/ground-blocks/
go test ./...         # determinism, heading sets, cell contract, seating, leg gap, palettes, budget, finish round trip
```

**Families.** `art/families/ground-fleet.json`, `ground-host.json`, `ground-infantry.json` (schema
`demon-attack.ground-blocks/v1`) and their empty `-runs.json`. Rigs: `art/families/rigs/<unit>.json`, 26 units: Fleet
Sleet, Cairn, Tether, Lodestar, Sextant, Stilt, Skiff and the rifle and rocket troopers; Host Crocket, captured Crocket,
Tympanum, Reliquary, Carillon, Hodcrawler, Buttress Strider, Chapterhouse, Rubbling, Ashlar Guard, Corbel Brute,
Knell-bearer, Prior; and the four threat vehicles (Gutter-runner, Scrapmason Crawler, Kiln Ox, Belfry) with headings, per
the operator's "no flag, fix forward". Their telegraph keeps the `ground-forces.png` contract as V-block specials (f0
launcher raised, f1 glow, f2 launch flash, f3 smoking), so no timing moves.

**Per-sector packing and memory** (task 2.5; `art/families/ground-blocks-pack.json`). RGBA is the uncompressed GPU
footprint of the sector's three atlases; PNG is the download.

| Sector | Fleet atlas | Host atlas | Infantry atlas | RGBA | PNG |
| --- | --- | --- | --- | --- | --- |
| Krybor | 960 × 360 (2 blocks) | 960 × 520 (3) | 640 × 192 (4) | 3.7 MB | 77 KB |
| Ringfall | 960 × 200 (1) | 960 × 840 (5) | 640 × 240 (5) | 4.4 MB | 94 KB |
| Ember | 960 × 360 (2) | 960 × 1040 (6) | 640 × 288 (6) | 5.8 MB | 120 KB |
| **Hollow** (busiest) | 960 × 240 (1) | 960 × 1560 (8: 5 V, 2 W, 1 K) | 640 × 336 (7) | **7.4 MB** | 141 KB |
| Carrier | 960 × 200 (1) | 960 × 1240 (6) | 640 × 288 (6) | 6.0 MB | 111 KB |

Today's `ground-forces.png` plus `ground-troops.png` hold 1.5 MB RGBA. The design estimated about 7.1 MB for Hollow; the
measurement is 7.4 MB. **Budget assumed here: 8 MB RGBA per sector and no atlas side over 4096 px** (the test enforces
both). No phone budget was written down anywhere, so this is a proposal for the operator: at 8 MB the half-resolution far
atlas (open question, decision 1.4) is **not** needed. Only one sector's set is resident at a time.

**Draw calls.** The painter draws each sprite layer with one `drawImageRect`. A busy Hollow frame at the skirmish caps (6
Host units, one threat, three allied vehicles, two squads of four) is about 48 calls: a vehicle is hull + articulated
layer + up to two overlays (lights and a fill or damage state) at near LOD, infantry one each; today the same frame is
about 28. Beyond z 900 the LOD rule (Section 6.5 of the animation doc) drops overlays but `lights`, so far units cost 2–3.
Three textures per sector (plus the shared fx rows inside the Fleet and Host atlases). If the runtime batches per atlas
with `drawAtlas`, the frame is 3 calls; that is a runtime choice, not an art one.

**Metadata** (task 2.6): `lib/game/ground_blocks_atlas.dart` maps cell names to (atlas, row, column) per sector through 10
shared layouts, with per-heading pivots, per-angle muzzles, sizes, the hull origin, the art pivot, walker bob, debris piece
names and the turn tracker table. **Not wired into the game yet**: the painter still draws `ground-forces.png` and
`ground-troops.png`, and the atlases live in `assets/images/ground-blocks/`, which is not in `pubspec.yaml` (so they do not
ship until the runtime integration adds that directory). Integration of headings into gameplay is a later task.

**Deviations and notes for review.**
- Overlays that are empty at a heading or angle (the feature faces away from the camera) are not stored and have no name;
  the runtime draws nothing for a missing name. Every overlay state exists at some heading (tested).
- The Carillon's cradle turns through the five Host angles in Phase 0; the plan's three ranging tilts are left to the GPU
  pass (they are a pose of the same layer).
- Walker turntables change 44–58% of their silhouette between some headings (legs swing through), above the 40% "pop"
  guide; vehicles and infantry stay under it. Logged by `TestHeadingSteps`, not failed. Worth a look at CP0.
- Rig shading is a placeholder: the faces are flat facets. The GPU path (Phases 1–3) redraws materials on the same outlines.

### 7.1 Originality checklist (task 1.3, from memory, no web search)

Names and silhouettes were checked against well-known games, films and toys from memory only. No prompt in the three
family specs names a franchise, studio or artist (the validator rejects a list of franchise words). Flags for the
operator, highest first:

| Unit | Concern | Suggestion |
| --- | --- | --- |
| **Gutter-runner** (Host threat) | Exact name match with a well-known tabletop fantasy rat-folk scout unit ("Gutter Runners") | Rename, for example **Spout-runner** or **Gutterhound** |
| **Stilt** (Fleet walker) | A box cab with side gun pods on two legs is close to a famous film franchise's two-legged scout walker | Keep the straight telescoping legs (the film's are reverse-jointed); move the pods under the cab or onto one side only |
| **Sleet** (Fleet scout) | A six-wheeled rover with outboard wheels and a small turret recalls a well-known sci-fi RPG's six-wheeled exploration tank | Four big wheels plus a rear skid, or a lower pod; the wedge body already differs |
| **Carillon**, **Chapterhouse** | Gothic war machines with bells and spires sit near a well-known tabletop sci-fi faction's cathedral and organ tanks | The Host is gargoyle stone with no human crew, crosses or scripture; keep that line, avoid organ pipes and skull motifs |
| **Chapterhouse**, **Belfry** | A building on legs recalls a famous animated film's walking castle and the folk hut on hen's legs | Low risk (folk motif); keep the buttress legs and the octagonal plan |
| **Kiln Ox** | A four-legged beast carrying a war structure recalls a well-known fantasy RTS's drum-carrying beast | Low risk; the kiln-mortar and basalt keep it apart |
| Lodestar, Skiff, Sextant, Cairn, Tether, Crocket, Tympanum, Reliquary, Hodcrawler, Buttress Strider, Scrapmason, Rubbling, Ashlar Guard, Corbel Brute, Knell-bearer, Prior | Generic words or original compounds; no near match recalled | None |

These are recall checks, not a search; the operator confirms or asks for a proper search before any renames.

## 8. Ledger: workflow smoke runs (2026-11-14 22:50–23:00 UTC)

Graph checks only (task 3.4), on rig renders; none of this is pilot art. Raws kept under
`~/.cache/demon-attack/ground-blocks/smoke/`.

| Workflow | Job | Time | Result |
| --- | --- | --- | --- |
| `matte-birefnet-batch.json` | st-1794696590492-1 | 2.3 s | Clean silhouette matte of the Lodestar h045 rig render |
| `inbetween-wan-vace.json` (17 frames, 20 steps, no LoRA) | st-1794696599521-2 | 135 s | 17 frames + 17 mattes; a static control strip gives a stable, on-model clip (Ashlar Guard). Faster than the 2–4 min estimate even without lightx2v |
| `inbetween-wan-vace.json` (17 frames, **Wan2.2-Lightning Seko-V1.1**, 4 steps, cfg 1, split 2/2) | st-1794722605549-0 | 34 s (+88 s one-time LoRA fetch) | Ashlar h090 walk strip: 17 frames + 17 mattes, on-model, clean mattes; faint key-colour haze under the feet in a few frames (the matte drops it). About 4× faster than 20 steps. Sheet: `art/contact/ground-vace-lightning-smoke.png` |
| `heading-qwen-edit.json` | st-1794696756635-3 … -6 | 29 s each | Runs. Findings below |

Heading-edit findings for the pilot (CP1 to confirm):
1. **At denoise 1.0 Qwen follows image 2's pose, not image 1's.** With a generic prompt, the h000 job came back at the
   hero's 45°. Adding an explicit view phrase fixed the heading (the job prompts already carry `heading_phrases`), but it
   then copied the hero's turret as a second barrel. At **denoise 0.7** (`"$node:11.denoise": 0.7`) the rig geometry
   held exactly. Pilot plan: run each heading at 0.7 and 1.0 for the first unit, pick one setting before scaling. The
   finish step masks to the rig silhouette either way, so stray parts outside it are clipped; interior ones are not.
2. **Name the key colour.** "plain flat background" let the model draw a transparency checkerboard; "solid flat magenta
   background (#FF00FF), no checkerboard" kept the key. Proposed for the three family `style_prompt`s at CP0.
3. Avoid effect words in prompts ("smoke test" drew a smoke plume).

Tooling: `go run . control [ids]` writes the VACE control strips (17 and 33 frames) for every `inbetweens` clip, from
the block's own key cells, one scale and anchor per clip (`$BLOCKS_WORK/control/<id>/`).

## 9. Ledger: Phase 1 pilot, heroes (2026-11-15)

**CP0 approved by the operator** (2026-11-15): "quite pretty"; angles consistent and mostly correct, cannons on top,
combined sprites smooth; Chapterhouse and Belfry "a little weird but in a good way".

Hero candidates, `variant-qwen-edit.json`, 4 seeds each, about 14 s per image: Lodestar st-1794721235621-7
(780200–780203), Crocket st-1794721311538-8 (760200–760203), Ashlar Guard st-1794721379253-9 (760110–760113).
Ingested into the `-runs.json` files; raws in `~/.cache/demon-attack/ground-blocks/{raw,pilot}/`.

- Raw quality is high: a clean key, the faction looks read at once (cyan-lit grey-blue Fleet; violet stone Host with
  gargoyle faces and a glowing slag channel; a horned, winged musketeer). Lodestar seed +3 grew a second barrel.
- **Finished on the grid they collapse** (`art/contact/ground-pilot-heroes-finished.png`): `finish` keeps only the AI
  image's luminance inside the rig silhouette and recolours it from the rig's material ramps, so AI colour (eyes,
  horns, glow), and anything outside the rig shape (wings, a longer musket), is lost; the four seeds become nearly identical
  rig-shaded texture. At denoise 0.7 (st-1794721555014-10) the raw hero follows the rig closely and keeps the detail,
  but the finish still flattens it: the bottleneck is the finish, not the model.
- Fixed: the Host family's key is green (#00FF00); its prompt now names green, not magenta (the magenta Crocket raws
  were finished against the wrong key).
- ~~Operator decision needed~~ **Decided 2026-11-15, see §10: colour-preserving finish (option 1).**

## 10. Operator approvals (2026-11-15)

The operator approved every open recommendation in this plan ("record all approvals to your recommendations"):

| # | Decision | Approved | Status |
| --- | --- | --- | --- |
| A1 | How `tools/ground_blocks finish` treats AI art (§9) | **Option 1:** keep the AI image's colour, quantised to the faction palette, inside the rig silhouette dilated by ±1 texel (wings, horns, a longer musket survive at the edge; nothing further out). Not chosen: AI outline wins on soft parts (2), rig shading only (3, stays the CP1 fallback) | Done, §11 |
| A2 | VACE in-betweens use the Wan2.2-Lightning LoRA (Seko-V1.1, 4 steps, cfg 1, split 2/2) | Yes, as the default schedule | Done, commit 60860c05 |
| A3 | Heading edits (§8 finding 1) | Run each heading at denoise 0.7 and 1.0 for the first unit (Lodestar), pick one setting before scaling | Pilot plan |
| A4 | Name the key colour in prompts (§8 finding 2); no effect words (finding 3) | Yes | Already in the three family `style_prompt`s |
| A5 | Atlas budget (§7) | 8 MB RGBA per sector, no atlas side over 4096 px; the half-resolution far atlas (decision 1.4) is not needed | Test already enforces it |
| A6 | Originality (§7.1) | Apply the suggestions: rename **Gutter-runner → Spout-runner** (first suggestion; the operator can still pick Gutterhound); Stilt pods under the cab or on one side; Sleet four big wheels plus a rear skid; Carillon / Chapterhouse keep no crew, crosses, scripture, organ pipes or skulls; Chapterhouse, Belfry, Kiln Ox unchanged (low risk) | To implement before Phase 2 (Fleet/Host rigs, family, atlas names, specs) |

## 11. Ledger: A1 finish, pilot heroes re-rendered (2026-11-15, after the cache wipe)

The host reset wiped the raws, so the 12 heroes were re-rendered from their recorded seeds, same workflow and prompts
(Crocket now with the green-key prompt): Lodestar st-1794727438235-0, Crocket st-1794727507536-1, Ashlar Guard
st-1794727575553-2, 4 seeds each, ~59 s per unit. Outputs are not byte-identical to the first run (GPU
nondeterminism); `-runs.json` holds the new hashes. Raws in `~/.cache/demon-attack/ground-blocks/raw/` only: commit
the selected hero's raw once it is picked.

`finish` now implements A1 (commits a7aed0b0 and the next one). A first version took the mean colour per texel and
mottled; the majority vote of palette-snapped source pixels gives flat panels, discrete cyan strips, the slag glow
as a line, and Ashlar's horns and musket. Sheet: `art/contact/ground-pilot-heroes-a1.png`, one row per raw: rig | raw |
finished. Known limit (by design): the rig silhouette ±1 still owns the shape, so where the AI drew a different body
(Crocket's turret, Ashlar's wings) the extra parts are clipped.

**Waiting on the operator:** pick one hero per unit (`hero.selected` in the family), then the Lodestar heading jobs at
denoise 0.7 vs 1.0 (A3).
