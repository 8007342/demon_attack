# Tasks

Prerequisite: `gargoyle-ground-army` tasks 1.1–1.3 (Host art direction approval, black-fill sheet, originality pass). The tasks marked "(was gargoyle X.Y)" moved here from that change.

## 1. Design review
- [ ] 1.1 Operator review of `plan/human-ground-forces-style-guide.md`: pillars, roster and names, palette, readability rules
- [ ] 1.2 Operator decision on the heading count (5 per faction), the turn tracker numbers, and the block layouts in `plan/ground-unit-animation.md`
- [ ] 1.3 Originality pass for the Fleet: every name and silhouette checked against well-known game, film and toy vehicles; rename or redesign near matches; no prompt names a franchise, studio or artist
- [ ] 1.4 Operator decisions on the open questions in `design.md` (pipeline option, pilot order, threat-vehicle phase, Carrier slot, egg rarities)
- [ ] 1.5 Link the new docs from `plan/style-guide.md` ("Ground war presentation") and `plan/asset-pipeline.md`; add a line to `plan/render-runs/rerender-all.md` Section 5.3

## 2. Rigs and tooling (no GPU)
- [ ] 2.1 `tools/ground_blocks` (Go, standard library), sharing the `tools/ground_troops` rasteriser: verbs `rig`, `jobs`, `ingest`, `finish`, `pack`, `contact`, `offline` (supersedes the planned `tools/ground_host`, was gargoyle 3.1)
- [ ] 2.2 Rig format and rigs under `art/families/rigs/` for every Fleet and Tier A Host unit: primitives, turret pivot, channel path, eye and light points, debris seam lines, soft-edge marks
- [ ] 2.3 Family specs `ground-fleet.json`, `ground-host.json` (was gargoyle 2.2, now the block layout), `ground-infantry.json` (replaces the appended `ground-troops.json` rows, was gargoyle 2.4), each with a `-runs.json`; validate with `studio.validate_family`
- [ ] 2.4 Overlay generators: channel `fill1–3`, `lights`, `dmg1–2` per heading or layer angle; pitch shears; ford bands; debris cuts (12 pieces per Host vehicle)
- [ ] 2.5 Per-sector packing with baked sector stone and kit (settles gargoyle 2.3 as baked variants); memory and draw-call measurement for the busiest sector
- [ ] 2.6 `offline` build of every block from the rig alone, plus the generated Dart metadata (cell names to atlas, row, column; pivots; muzzles; sizes), so the runtime can integrate first
- [ ] 2.7 Checkpoint CP0: `art/contact/ground-rig-turntables.png` (black fills and rig shading at every heading, turret × hull seating grid) and operator review

## 3. Workflows
- [ ] 3.1 `art/workflows/sprites/heading-qwen-edit.json` (two reference images: rig render and hero)
- [ ] 3.2 `art/workflows/sprites/inbetween-wan-vace.json` (Wan2.2 VACE 14B, lightx2v 4-step, reference image plus rig control clip)
- [ ] 3.3 `art/workflows/sprites/matte-birefnet-batch.json`
- [ ] 3.4 Dry-run each new workflow's graph in the studio without queuing (inputs resolve, models present); record model hashes for provenance

## 4. Pilot (GPU, about 90 jobs; after CP0)
- [ ] 4.1 Lodestar: hero (4 candidates), 4 other headings and 5 turret angles (2 each), mattes, finish
- [ ] 4.2 Crocket: hero, 4 headings, an `arrive` clip; finish with overlays and debris
- [ ] 4.3 Ashlar Guard: 3 headings, a walk clip and a wind-up and fire clip
- [ ] 4.4 Checkpoint CP1: `art/contact/ground-pilot.png` over Ember and Hollow at phone size; operator picks the full or lean pipeline, or the no-AI fallback

## 5. Production (GPU, after CP1)
- [ ] 5.1 Fleet heroes; checkpoint CP2
- [ ] 5.2 Host heroes and sector remaps; checkpoint CP3 (was gargoyle 3.3)
- [ ] 5.3 All headings and articulated layers for both factions; checkpoint CP4 (turntables)
- [ ] 5.4 Infantry keyframes and terrain poses for both factions (folds in the terrain change's art tasks 3.1 and 3.3 for these units)
- [ ] 5.5 In-betweens: infantry walks and actions, walker strides, specials and arrivals; wreck and totalled keyframes; checkpoint CP5 (was gargoyle 3.4)
- [ ] 5.6 Pack every per-sector atlas and the metadata; contact sheets with greyscale and black-fill strips (was gargoyle 3.5, 3.6)
- [ ] 5.7 (Flagged, Phase 4) Threat vehicles as V/W blocks, only after a gameplay check of their telegraph frames

## 6. Atmosphere and wildlife
- [ ] 6.1 `art/families/ground-atmosphere.json`: procedural bands and sprites (seeded noise, stepped alpha), sector tints sampled from each horizon and clamped
- [ ] 6.2 Optional low-cloud strips through `strip-sheet.json`; pack `assets/images/ground-atmosphere.png` and `lib/game/ground_atmosphere_atlas.dart` (generated) per the interface note
- [ ] 6.3 `art/families/ground-wildlife.json`: 5 flock species (transparent sprite workflow) and 10 critter leap pairs (pose edits); pack `assets/images/ground-wildlife.png`
- [ ] 6.4 Checkpoints CP6 (atmosphere over every sector with units at four depths) and CP7 (easter egg assets)

## 7. Handoff and proof
- [ ] 7.1 Send the atmosphere interface note (`plan/ground-atmosphere.md`, Section 6) and the block metadata contract to the runtime work; agree the names before packing
- [ ] 7.2 Atlas contract tests (for the consuming code change): cell presence, binary alpha (stepped for atmosphere), palette membership per faction, gilt stillness, leg gaps, heading step size, turret seating (art half of gargoyle 5.3)
- [ ] 7.3 Checkpoint CP8: in-game review frames at 360 × 780 and 1280 × 720 in every sector; operator acceptance
- [ ] 7.4 Fold the accepted decisions into `plan/style-guide.md`, `plan/asset-pipeline.md` and the main specs
