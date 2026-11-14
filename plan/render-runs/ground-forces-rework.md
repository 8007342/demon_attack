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
