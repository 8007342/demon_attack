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
| 4 | Threat vehicles (Spout-runner, Scrapmason, Kiln Ox, Belfry) as V/W blocks, behind a flag | about 230 more | CP5 and a gameplay check of telegraph timing |
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
Knell-bearer, Prior; and the four threat vehicles (Spout-runner, Scrapmason Crawler, Kiln Ox, Belfry) with headings, per
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
| **Gutter-runner** (Host threat; renamed **Spout-runner**, A6) | Exact name match with a well-known tabletop fantasy rat-folk scout unit ("Gutter Runners") | Rename, for example **Spout-runner** or **Gutterhound** |
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
| A6 | Originality (§7.1) | Apply the suggestions: rename **Gutter-runner → Spout-runner** (first suggestion; the operator can still pick Gutterhound); Stilt pods under the cab or on one side; Sleet four big wheels plus a rear skid; Carillon / Chapterhouse keep no crew, crosses, scripture, organ pipes or skulls; Chapterhouse, Belfry, Kiln Ox unchanged (low risk) | **Done** (branch `work/a6-originality`): id/name/rig `spout-runner`, atlas regenerated; Stilt has one twin-gun chin pod under the cab, no side pods; Sleet on four big wheels plus a tail sled skid (rig and subject); Host negative prompt adds crucifix, scripture, inscription, open book, organ pipes, skull(s), human crew; Carillon/Chapterhouse rigs and prompts carry none of these. validate, offline, contact and `go test` pass |

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

**Heroes selected by the operator (2026-11-15):** Lodestar 780200, Crocket 760201, Ashlar Guard 760113 (`hero.selected`).
Their raws are committed in `art/sprites/sources/ground-blocks-selected/<unit>/hero/<seed>.png`, so they survive a host
reset. Before the heading jobs, copy them to the studio inputs:
`cp -r art/sprites/sources/ground-blocks-selected/. /work/tmp/imagegen/in/ground-blocks/selected/`.

**A3, Lodestar heading edits (2026-11-15):** `heading-qwen-edit.json` with the selected hero 780200, 2 seeds per heading,
at denoise 0.7 and 1.0 (`$node:11.denoise`), ~50 s per pair. Jobs (0.7 / 1.0): h000 st-1794728100810-3 /
st-1794728150189-4; h022 -216103-5 / -266322-6; h067 -316754-7 / -368709-8; h090 -419618-9 / -470593-10. Raws in
`~/.cache/demon-attack/ground-blocks/pilot/lodestar-headings/<h>-<d07|d10>-<seed>.png`. Sheet:
`art/contact/ground-pilot-lodestar-headings.png`.
- **1.0 fails at every heading:** Qwen redraws the hero's 45° pose whatever the rig or the heading phrase says; once
  finished, the rig silhouette cuts it into a broken shape. Not usable.
- **0.7 holds the pose at all four:** rig geometry exact, plus the hero's turret hatch, cyan visor and strip accents.
  It adds less surface detail than the hero, and some raws grow stray barrel fragments outside the rig (h067 780222,
  h090 780227), which the finish clips.
- Recommendation: **0.7 as the heading default** (operator to confirm before scaling to the other units).
- **Decided (operator delegated the picks, 2026-11-15): denoise 0.7 for every heading and layer edit.** Lodestar picks,
  the cleanest of each pair: h000 780211, h022 780214, h067 780223, h090 780226 (h067 780222 and h090 780227 grew stray
  barrels). Raws committed in `art/sprites/sources/ground-blocks-selected/lodestar/heading/`.

### 11.1 `bake`: keyframes onto the whole block (2026-11-15)

The AI gives one image per heading (and per layer angle); a block has 50-odd base cells (move frames, pitch, ford,
special, pod, wreck, totalled, art aim and fire). `go run . bake <unit>` carries the keyframes' AI colour onto every base
cell through the rig: each rig texel knows its surface point (`Px.P`, unit-local for the hull, art-local before the aim
for the layer), so a keyframe texel is a sample at that point. A sample stores what the AI changed: on the rig's own ramp,
the **step offset** (re-applied over the target's rig step, so every cell keeps its own heading's lighting); on another
ramp, the **colour** (accents: cyan strips, ember eyes). A target texel takes the sample from the keyframe nearest its
heading or angle that saw the point within 1.6 rig units, else the rig colour. Hull samples within 2 texels of the
turret in a composed keyframe are dropped (the AI's turret spills over the hull). The rig owns every silhouette; overlays
stay rig; colours stay in the master sector's ramps, so `pack` remaps them per sector. Inputs default to the committed
picks in `art/sprites/sources/ground-blocks-selected/<unit>/{hero,heading,layer}/`; outputs go to
`art/sprites/sources/ground-blocks/<unit>/<cell>.png`, which `pack` uses. About 1.5 s per unit.

Lodestar baked from the hero and 4 headings (no layer-angle raws yet: art cells take the turret samples of the
composed keyframes). Sheet: `art/contact/ground-pilot-lodestar-baked.png` (rig | baked). Known limits: an AI accent
drawn outside the rig's matching part still lands on the nearest rig surface (a cyan blob on the h022 hull front);
sector kits (snow, patches) stay those of the master sector on baked cells; surfaces no keyframe saw (hull under the
turret, undersides in wreck rolls) keep rig shading.

## 12. CP1 decision (2026-11-15; the operator delegated the call)

Phase 1 evidence (sheets in `art/contact/ground-pilot-*.png`):
- **Heading edits (two-image Qwen) are binary.** Crocket h112 at denoise 0.7 / 0.8 / 0.85 (4 and 8 steps) returns the
  rig almost unchanged; at 0.9 it redraws the hero's own pose (a turreted tank) whatever the heading. No setting blends
  the hero's materials onto the rig pose (`ground-pilot-crocket-denoise.png`, `-steps8.png`). Lodestar showed the same
  (§11 A3). Jobs st-…-11 to -21, -24 to -28.
- **Single-image redraws per heading** (the hero workflow with the heading prompt, st-…-29) are rich but drift from
  the rig pose, and at sprite scale the detail averages into dark mottling (`ground-pilot-crocket-variant.png`); the
  Crocket and Ashlar heroes finish the same way.
- **VACE in-betweens** (Ashlar walk and aim, st-…-22/-23, 2 × 17 frames each, ~35 s per clip) stay on-model (wings,
  horns, musket) but barely move; the rig's key frames already carry the motion (`ground-pilot-ashlar-vace-*.png`).

**Decision: lean hybrid.** Rig-shaded blocks (the plan's fallback) plus ONE AI hero per unit, carried to every cell
by `bake` with smoothing so only material and accent colours (eyes, glow, light strips, plate tints) transfer, not
noise. No heading edits, no layer edits, no VACE clips. GPU: the remaining ~23 units × 4 hero candidates (~25 min).
Reversible: the heading and VACE workflows stay committed; a later pass can add them per unit if a better graph
(e.g. ControlNet-guided or a pose-locked LoRA) appears.

### 12.1 Bake v2 (hero-only, region materials)

`go run . bake [--with-picks] (--all | UNIT)` now carries only the selected hero by default. The rig's shading is the
base; the hero decides, per region (rig primitive × layer × binned facet normal), one material: the median AI step
offset against the rig (clamped ±1), or another ramp when ≥60% of the region's samples fall in it. Accents
(ramps of emissive materials: `ally_cyan`, `demon_warm`) transfer point by point only in clusters of ≥3 samples within
1.5 texels. Unseen regions borrow the nearest-normal seen region of the same primitive, else the rig. A despeckle then
replaces any AI-changed texel whose colour none of its same-primitive 8-neighbours shares. Emissive and flat rig
materials keep the rig colour; the rig owns silhouettes; overlays stay rig; colours stay in the master sector.
Sheet: `art/contact/ground-pilot-baked-v2.png` (rig | baked at ×4, plus a 1× strip per unit). The mottling of v1 is
gone; Lodestar keeps cyan strips and dark panel zones, Crocket its violet stone, ember eyes and slag line, Ashlar a dark
vest and the gilt musket. `--with-picks` (heading and layer picks too) was worse on Lodestar: stray cyan blobs on hull
fronts and diluted panel zones, so it is off by default. `bakereview OUT UNIT:substr,..` draws review sheets.
## 13. Ledger: hero candidates for the remaining 23 units (2026-11-15)

`variant-qwen-edit.json`, count 4 (consecutive seeds from the unit's `seed`), prompts and negatives exactly as in
`jobs.json`, input the rig `hull.ref` at the hero heading. ~58 s per unit, one job at a time, no evictions, no
failures, **no rerolls**. Job ids `st-17947…`: sleet -32456566-30, cairn -32528116-31, tether -32599302-32, sextant
-32669091-33, stilt -32737755-34, skiff -32807147-35, crocket-captured -32964222-36, tympanum -33030267-37,
spout-runner -33096160-38, scrapmason -33161978-39, reliquary -33228118-40, carillon -33294365-41, kiln-ox
-33359815-42, strider -33426418-43, belfry -33493340-44, hodcrawler -33561701-45, chapterhouse -33628683-46,
trooper-rifle -33759219-47, trooper-rocket -33824110-48, rubbling -33889866-49, corbel -33955551-50, knell
-34020477-51, prior -34085483-52. Provenance in the `*-runs.json` files; picked raws committed in
`art/sprites/sources/ground-blocks-selected/<unit>/hero/<seed>.png`. Sheet of all 26 picks (incl. the 3 pilot heroes):
`art/contact/ground-heroes-all.png` (rig | raw | finished). Picks (operator delegated):

- **sleet 780101**: big cyan visor and strips survive the finish; all four add long twin skis the rig lacks (clipped).
- **cairn 780110**: the only eight-wheeled one, matches the rig; clean plates and cyan strips.
- **tether 780120**: tracked rear, crane and drum at the back; least mottled finish.
- **sextant 780211**: clean cyan track strip and single visor; all four centre the gun on a turret instead of a rear casemate (rig owns the shape).
- **stilt 780300**: the AI draws four legs (AT-AT style) in every candidate; this one's legs line up best with the rig's two and the cab reads.
- **skiff 780310**: flat lozenge with cyan edge strip and pads, cleanest finish.
- **crocket-captured 760212**: lowest hull without a big turret (closest to the rig), slag channel along the spine.
- **tympanum 760220**: horned turret, face plate, few stray glows; least mottled of four similar tanks.
- **spout-runner 760233**: one of two with wheels instead of tracks, twin launcher; ember accents survive.
- **scrapmason 760242**: gargoyle face and slag line read at sprite size; others go flat black.
- **reliquary 760302**: casket roof with the slag ridge; strongest accent in the finish.
- **carillon 760403**: bells on top and a slag line; 760400 throws loose sparks outside the body.
- **kiln-ox 760413**: keeps the rig's brown basalt tones with glowing seams; cleanest four-legged read.
- **strider 760503**: slag stripe on the back reads; every candidate draws four legs instead of two (clipped by the rig).
- **belfry 760512**: gargoyle corner heads with ember eyes, louvred chamber, launch tube; clean finish.
- **hodcrawler 760601**: keeps the violet salvaged plates; crane hand clipped by the rig.
- **chapterhouse 760701**: Qwen returned a portrait frame (792×1320) with the spire centred while the rig's spire is
  offset; the finish fits subject box to rig box. Picked for the cleanest silhouette and rose-window glow. Weakest fit
  of the Host set; a candidate for a later re-roll if bake shows a misplaced spire.
- **trooper-rifle 780400**: cyan visor and back light, clean exoskeleton plates.
- **trooper-rocket 780413**: launcher across the shoulders reads without a big flat box (780410/-12 turn into a grey slab).
- **rubbling 760100**: ram horns, ember eye, spear; 760101 has a shadow ellipse under the feet.
- **corbel 760121**: violet stone, the face-ended launcher tube, ember eye; 760120 is grey.
- **knell 760133**: the only one with ember eyes; every candidate hangs the bell behind the waist, not low as in the rig, so the finish is mostly dark cloth.
- **prior 760140**: lantern glow lands where the rig's accent is; pennant and crown read.

Off-nominal: the Host finishes are dark overall (low-contrast stone by prompt), as the pilot Crocket was; `bake`'s
smoothing should decide whether that needs a brighter prompt. `ingest` re-records every `work/http/` folder from the
current `jobs.json`, which would have overwritten the pilot Crocket runs with the newer Host negative prompt; the pilot
folders were moved to `work/http-pilot/` so their committed records stay accurate.

## 14. All units baked and packed (2026-11-15)

`go run . bake --all` (bake v2, hero only) over the 26 selected heroes, then `go run . pack`: every unit's block now
carries its hero's region materials and accents on rig shading. Per-sector RGBA unchanged (Hollow 7.41 MB, the
busiest; all under the 8 MB budget). Review: `art/contact/ground-baked-all.png` (rig | baked at the main headings),
`art/contact/ground-heroes-all.png` (the 26 heroes). Runtime: OpenSpec `ground-blocks-runtime` merged (painter draws
the blocks, `GroundPainter.useBlocks` keeps the legacy path); `flutter analyze` clean, `flutter test` 462 passed, 1
skipped, on the merged tree.

Notes for the in-game review (CP8): some Host units bake darker than their rigs (crocket-captured, knell,
scrapmason at h135); side-on vehicles draw larger than the legacy sprites (authored size); stilt, strider, sextant
and chapterhouse heroes disagree with their rig's body plan, so only tone and accents transfer.

## 15. Atmosphere atlas (2026-11-15, no GPU)

Tasks 6.1 and 6.2, and the CP6 sheet of 6.4. Everything is procedural; no GPU job ran. The optional SDXL low-cloud strips
(`strip-sheet.json`, 20 jobs in §5) were skipped, since the plan defaults to procedural first.

- **Tool:** `tools/ground_atmosphere` (Go, standard library + `tools/pixelgrid`), verbs `pack`, `check`, `preview`.
  It is Go, not Lua, so it can share the rasteriser, hashing and deterministic PNG encoder of `ground_blocks` and
  `ground_troops` (the same call §3 made). It is a separate module rather than a `ground_blocks` verb because the
  family has its own schema (`demon-attack.ground-atmosphere/v1`) and is the one family exempt from binary alpha, so
  `ground_blocks`' binary-alpha contract tests stay untouched.
- **Family:** `art/families/ground-atmosphere.json`. Provenance: `ground-atmosphere-runs.json` (procedural: seeds,
  rects, sampled and clamped tints, atlas sha256; no models, no jobs). Seeds: horizonFog 790010+s, lowCloud
  790020+s, midMistA 790030+s, midMistB 790040+s, dustVeil 790050+s, cloudShadow 790060+i, smokeDrift 790070,
  smokeWall 790080.
- **Atlas:** `assets/images/ground-atmosphere.png`, 512 × 872, laid out as in the interface note. Alpha is
  {0, .2, .4, .6, .8}, despeckled. The tiled bands use noise that is periodic over 512, so they wrap seamlessly.
  Mist banks keep 40% or more of their columns clear. Metadata: `lib/game/ground_atmosphere_atlas.dart` (generated),
  which holds the rects, fog/lit/dark/smoke tints per sector, the layer placement table (rows, sort depth, parallax,
  drift, opacity range and default, reduced tier), `fogMix(z)` and the lane cap.
- **Tints** (horizon rows .62–.72 of `sector-N.png`, darkened as the flyover bake does, value from the plan's tint,
  35% of the sampled hue, clamped): Krybor #30384D, Ringfall #353653, Ember #442F3C, Hollow #2F3A3C (teal pulled
  back to grey chroma, 30° guard around ally cyan and demon warm), Carrier #3C273F.
- **Runtime:** `lib/game/ground_atmosphere.dart` (`GroundAtmosphereArt`) is installed in `Atmosphere.groundArt` by
  `DemonScene.onLoad`. While installed, the horizon slot draws the low cloud deck (air pass) and the far banks are
  skipped. Horizon fog (z 1150), cloud shadows (1149), mist A (1050) and mist B (850) join `GroundPainter`'s depth
  sort; the dust veil goes after every ground object and rises with the skirmish tide. Sectors cross-fade with
  `environment`. Offsets are whole arena units and sampling is nearest. Reduced atmosphere keeps horizon fog and both
  mists. Reduced motion freezes the drift (the fog clock) while parallax still follows the ship. Without the atlas,
  everything is exactly as before (fBm tiles and shader).
- **Tests:** `test/ground_atmosphere_test.dart` (14): atlas size and every slot × sector, stepped alpha and per-band
  caps, seams, mist gaps, tint caps and palette membership, density curve, slot takeover and fallback, depth slots,
  lane cap, reduced tier, reduced motion, dust and tide, and simulation parity with and without the art. Plus the
  CP6 sheet. `go test` in the tool (7): determinism, committed files match the generator, layout, steps, seams, mist
  gaps, tints.
- **CP6:** `art/contact/ground-atmosphere-contact.png` (refresh: `flutter test test/ground_atmosphere_test.dart
  --dart-define=GROUND_ATMOSPHERE_CONTACT=art/contact/ground-atmosphere-contact.png`). Top: per sector, the five
  bands at ×2 over the sector's painted horizon, with cloud shadows, smoke puffs, smoke walls and tint swatches
  (lit, fog, dark, smoke) on grey. Middle: each sector at 360 × 780 with demon vehicles at z 1400/1100/850/600 on
  both sides (squads at 850) on the art. Bottom: the same frames on the old fBm fallback, for comparison.

Open for the operator and the runtime work: the art is darker and thinner than the fBm haze it replaces, as the
plan's luma caps require, so the far ground reads as dark murk rather than pale haze. Units are not yet tinted by
`fogMix(z)` (runtime-owned; the constants are in the metadata), so far units are hidden mostly by the horizon fog
rows. `smokeDrift`/`smokeWall` are packed but no painter draws them yet.

## 16. Wildlife and sentinel silhouettes (2026-11-15)

**Flock flyers (task 6.3).** `art/families/ground-wildlife.json`, tool `tools/ground_wildlife` (Go, stdlib):
`ingest` (raws in `~/.cache/demon-attack/ground-wildlife/raw/<species>/<seed>/` → provenance in
`art/families/ground-wildlife-runs.json`, sources of record in `art/sprites/sources/ground-wildlife/`:
`<id>-raw.png` the full-resolution alpha crop of the pick, `<id>.png` at 64 px), `review OUT`, `offline`.
Five studio jobs, `sprite-transparent.json` (SDXL + pixel-art-xl + LayerDiffuse), `count` 4, ~44 s each:

| Species (sector) | Job | Seeds | Pick | Why |
| --- | --- | --- | --- | --- |
| rime-moth (Krybor) | st-1794734638268-53 | 760100–103 | 760102 | broad rounded pale wings: the widest, clearest shape at 16 × 12 |
| dust-kite (Ringfall) | st-1794734687908-54 | 760200–203 | 760201 | a clean delta/kite membrane; 760202 (ray-like) collapses to a blob |
| ash-flit (Ember) | st-1794734732566-55 | 760300–303 | 760301 | grey swift, swept wings, no face detail to read as eyes |
| puffwing (Hollow) | st-1794734777111-56 | 760400–403 | 760403 | round spore body with two stubby wings, as specified |
| hull-gnat (Carrier) | st-1794734821588-57 | 760500–503 | 760501 | slim gnat, long wings; 760503 has a cartoon face |

Finish (CPU, byte-identical): one top-down keyframe per species → flap A (spread) and flap B (span folded to
45% outside the body column, tips lifted, wings one step darker), rotated −12° for up-left and mirrored for
up-right, 4 × 4 supersampled coverage, rank-quantised to a 4-step ramp from the sector palette pulled toward
the species hint (luma .04–.32, chroma ≤ .22). Flap and heading from prompts would have given unrelated
designs per pose; deriving them keeps one creature. Tried and dropped: −35° heading (wings became a diagonal
line), outline-darkening of every edge texel (thin wings went all-outline, invisible on the fog).

**Critter leaps — deviation from the plan.** The plan called for 10 × 2 Qwen pose edits. The critters are
11–24 px wide and §12 showed Qwen edits are binary at sprite scale, so each crouch / leap is derived from the
critter's own walk frame 0 in `flyover-creatures.png` (crouch: ×1.14 wide, ×0.72 tall, 10% darker; leap:
×0.86 wide, ×1.12 tall, lifted 2 texels), both facings, luma capped at .34 (warm and saturated-cyan texels
at .20, easter-egg rule 3). No GPU.

**Atlas** `assets/images/ground-wildlife.png` 112 × 300: rows 0–4 flock (16 × 12 cells: left-a, left-b,
right-a, right-b), rows from y 60 critters (28 × 24 cells: crouch, leap, mirrored crouch, mirrored leap; feet
on the bottom row, anchor bottom-centre). Metadata `lib/game/ground_wildlife_atlas.dart`. CP7 sheet
`art/contact/ground-wildlife.png` (per species: the four cells ×8 on the sector fog tint, the source, a loose
flock at 1× and ×2; per critter: walk | crouch | leap ×5 and a 1× strip). Verdict: flyers read as small dark
birds/moths over the fog, never as targets (no warm, no violet glow, no eyes); species differ mostly in shape
(moth blob, kite delta, swift V, puff, gnat cross), which is what survives at 6–8 texels.

**Wired:** fleeing flyover critters now crouch-leap-land on every other stride (8-tick cycle at 14 fps,
phase by critter, off under reduced motion; drawn in a second `drawAtlas` after the walkers). **Not wired**
(no code exists yet): the flock burst from falling trees, `EasterEggBudget`, and the troop-proximity critter
groups of easter-eggs §4–5; `GroundWildlifeAtlas.flock(sector, flap, right:)` is ready for them.

**Sentinel silhouettes (atmosphere-and-swarms 5.1).** CPU, `tools/sentinel_silhouettes`: flight column 2 (level,
full span) of each species banked through 8 frames (±22°, the dipping wing foreshortened 24%, the rising one
5% long), 4 × 4 supersampled, Gaussian σ 1.0 (near) and 2.1 (far), alpha stepped to 8 levels, one near-black
body. Sheet `assets/images/sentinel-silhouettes.png` (160 × 96 cells, 8 × 4), metadata
`lib/game/sentinel_silhouette_atlas.dart`, contact `art/contact/sentinel-silhouettes.png` (rows: per species
near/far on four fog tints; last two rows the in-game look with warm rim and eyes). GPU rejected: the sheet is
a shape, it must match the body it cross-fades into, and no committed workflow renders a banked rig pose. The
foreshadow now draws it (frame from the path's bank, far→near blur by nearness, eyes rotate with the bank);
the old flight-frame treatment is the fallback and still serves the arrival cross-fade. Trade-off: the
silhouette glides (no wing stroke) — at its size a slow-banking glide reads as the giant soaring.

Tests: `test/wildlife_silhouette_assets_test.dart` (metadata, every cell drawn, binary alpha, luma and signal
colour caps, 8 × 2 frames per species, blur ordering); `flutter analyze` clean, `flutter test` passing.

## 17. Close-out (2026-11-15)

The operator delegated the checkpoint calls for this run. CP6 (atmosphere), CP7 (egg assets) and CP8 (in-game frames)
are decided on the sheets and frames below. OpenSpec `ground-forces-rework` tasks 6.4 and 7.1–7.4 are ticked.

**What shipped** (branch `game`, plus `work/ground-finish`):
- **Blocks for all 26 units.** Each unit is a rig plus one hero, baked and packed per sector (§13–§14). The runtime
  (`ground-blocks-runtime`) draws them with five headings, articulated layers, overlays, LOD and the telegraph contract.
  `GroundPainter.useBlocks` keeps the legacy atlases available.
- **The atmosphere atlas, wired into the game** (§15): low cloud, horizon fog, cloud shadows and both mists in the
  depth sort, plus the dust veil on the tide.
- **Runtime follow-ups in this close-out** (`lib/game/ground_atmosphere.dart`, `ground_painter.dart`,
  `ground_blocks_painter.dart`):
  - **Unit fog by depth.** `GroundFog` mixes each body toward the sector fog tint by `fogMix(z)` (cross-faded while
    travelling, stepped in 1/32). Threats cap at 0.45. Near units and units in the lane stay clear. Emissive overlays
    (lights, flames, sparks) fog at half rate, and an emissive-mask pass (`Atmosphere.glowMatrix`) lets eyes baked into a
    Host body show through the murk, as the air creatures' staged reveal does. Telegraph fills, the bracket, launch
    flashes and hit flashes are never tinted. Without the atlas nothing changes.
  - **Battlefield smoke from the packed sprites** (`GroundSmoke`). `smokeDrift` puffs carry each wreck's smoke column on
    into a drifting haze (3 puffs, or 1 in reduced atmosphere). A `smokeWall` stands over a burning wreck line (two
    hulks close together on one side; full atmosphere only; never in the lane). Skirmish units trading fire leave thin
    gun smoke (at most 4). Puffs stay at or under 0.30 inside the lane, and the total is capped at 14 sprites per
    frame. Reduced motion holds the densest frame, still.
  - **Flock flyers draw above the ground fog** (`FlyoverBackground.deferFlyers`, drawn by the scene right after the
    ground fog slot), with a small value lift (grey only, no warm, no eyes). The Krybor rime-moths now read as small
    dark moths over the fog.
- **Eggs:** the budget, dances, the jig, the breakup and jackpot, tree flocks and critter scatter (`ground-easter-eggs`).
  **Wildlife and sentinel silhouettes:** §16.
- **Docs:** the accepted decisions are in `plan/style-guide.md` ("Ground war presentation: accepted decisions") and in
  `plan/asset-pipeline.md` ("Ground blocks" → "Pipeline (lean hybrid)", with the durability rule).
- **Tests:** `flutter analyze` clean; `flutter test` 500 passed, 1 skipped. New in `test/ground_atmosphere_test.dart`:
  fog mix and caps, tint blending, far units taking the fog with the telegraph bracket untinted, wreck, wall and gun
  smoke with lane caps, reduced tiers, and the fog-and-smoke review frames (`l1/l3-fog-smoke-{art,plain}.png`). The
  flock frame now asserts the flyers read over the in-game fog. Simulation parity still holds with the art on and off.
  The CP6 sheet `art/contact/ground-atmosphere-contact.png` was refreshed, and its middle row shows the fogged units.

**Deferred:**
- *ground-blocks-runtime:* walker heading steps landing on a stride plant; specials other than the telegraph (Cairn
  deploy, Tether tow, Reliquary unload, Hodcrawler mend, Carillon ripple, Sextant brace), banner overlays and the
  Chapterhouse pulse; ford, crest hop and unearthing (the hooks still return false/null).
- *ground-easter-eggs:* shell-felled trees releasing flocks; Ringfall flocks (dust kites are ready); critter groups
  placed by terrain feature; warm seams cooling on stone pieces and the captured Krybor hull's human plate; dance
  variants by squad index; "no dance within 1.5 s of a nearby shot" and quiet on dense radio traffic; a phone-size
  review clip per egg.
- *atmosphere-and-swarms:* the radio line when the sentinel silhouette is first seen (pending the voice batch); a GPU
  frame-time measurement on a phone (the CPU numbers are in `test/atmosphere_perf_test.dart`); the operator playtest
  (6.2).
- *This change:* the Thurible's smoke wall
  (Tier B); a re-roll of the Chapterhouse hero if its spire reads as misplaced; the optional SDXL low-cloud strips.

**Suggested operator playtest** (one sector of each kind, on a phone):
1. **Side-on vehicles.** They draw larger than the legacy sprites (authored size). Check that they do not crowd the
   side bands or read as threats.
2. **Darker Host bakes.** Crocket-captured, Knell and Scrapmason at h135 come out darker than their rigs. Check that they
   still read against Ember and Hollow ground and that their eyes show through the fog.
3. **Fog darkness vs the old haze.** The new murk is darker and thinner than the fBm haze, as the luma caps require, and
   far units now take the fog colour. Decide whether the far ground reads as weather or just as dark. Also covers
   atmosphere-and-swarms 6.2.
4. **Egg frequency.** Dances (1 in 3 skirmish wins), jig (1 in 4), jackpot (1 in 8 breakups), flocks (2 in 5 tree
   falls) and critter scatter. Too rare to notice, or too busy?
5. **Smoke.** Check that wreck haze and smoke walls add depth without hiding a telegraph or crowding the lane edge.

## 18. Operator tuning (W1) (2026-11-15, no GPU)

OpenSpec `ground-presentation-tuning`, from the operator's playtest
([plan/operator-feedback-2026-11-15.md](../operator-feedback-2026-11-15.md) W1). Presentation only. The simulation
fingerprint of all five sectors is identical before and after.
- **Pace** (`lib/game/ground_presentation.dart`, `GroundPace`): every ground cycle, slew, overlay, visual effect,
  easter-egg motion and critter leap runs at 0.5x. Walkers (Stilt, Kiln Ox, Buttress Strider, Belfry, Chapterhouse)
  stride at 0.3x. The telegraph, fire, recoil, hit and tracer timing is unchanged. The atmosphere's smoke drift and
  walls are left to W2.
- **Sizes** (`GroundSize`): Fleet vehicles 0.5x, Host vehicles and the Tympanum 1.3x, troopers 0.9x, scaled at runtime
  with nearest-neighbour filtering. **No atlas regeneration:** the units were already drawn at a continuous scale
  with `FilterQuality.none`, so they stay as crisp as before, and half-size sources would lose one-texel outlines.
- **Squads** (`GroundSquadLook`): each squad is drawn as 1–5 troopers (weights 1:3:4:3:1; rocket teams 1–3), separate
  from the simulation's squad hp, and falls in proportion to its hp. Each trooper has its own spacing, drift,
  lead or lag, gait cadence and phase, and its own heading tracker.
- **Not slowed:** unit travel. It is gameplay, so design §3 proposes a skirmish-only travel multiplier that would
  need calibration.
- Before/after sheet: `art/contact/ground-tuning.png` (left: before; right: after; rows are sectors 1–5, ground layer
  at 2x on flat grey).
