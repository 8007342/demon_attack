# Tasks

Art production moved to `openspec/changes/ground-forces-rework/` on 2026-11-14: the atlas layout (now per-unit blocks packed per sector), the family spec, the tool, renders, packing and contact sheets. Tasks marked **moved** are done there. Fiction, roster, palette, gameplay hooks, events and simulation proofs stay here.

## 1. Art direction
- [ ] 1.1 Review and approve `plan/gargoyle-army-style-guide.md` with the operator: the pillars, castes, roster, and the Tier A/B split
- [ ] 1.2 Black-fill silhouette sheet for every Tier A unit at ×0.31, ×0.62 and ×1.0, then a blind role-sort with the labels hidden. Fix any role that two reviewers confuse
- [ ] 1.3 Originality pass: check every unit name and silhouette against well-known game units, and rename or redesign any near match. Confirm that no prompt names a franchise, studio or artist
- [ ] 1.4 Link the style guide from `plan/style-guide.md` ("Ground war presentation") and add the Host family to `plan/asset-pipeline.md`

## 2. Family specs and palette
- [ ] 2.1 Add `demon_gilt` (#1B1406 #36280D #644B18 #9A7324) and the five sector stone ramps as reserved sets. Re-check luma against the `demon_ramp` caps and rim 0.56
- [ ] 2.2 (**moved** to ground-forces-rework 2.3, block layout) Write `art/families/ground-host.json` (schema `demon-attack.ground-host/v1`): the atlas (48 × 40 cells, 16 × 12), style and negative prompts, the 76xxxx seed ranges, and per-unit prompts from the style guide (Tier B rows reserved)
- [ ] 2.3 (**moved** to ground-forces-rework 2.5: baked per-sector atlases) Decide sector tint: runtime ramp mapping or baked variants (design decision 4). Measure memory, size and draw calls
- [ ] 2.4 (**moved** to ground-forces-rework 2.3: `ground-infantry.json` instead) Append rows 6–8 (Rubbling, Knell-bearer, Prior) to `art/families/ground-troops.json` without changing rows 0–5

## 3. Renders and finishing
- [ ] 3.1 (**moved** to ground-forces-rework 2.1: `tools/ground_blocks`) `tools/ground_host` (Go, standard library): jobs, run, ingest, pack and offline, sharing the ground_troops rasteriser and keyframe shading
- [ ] 3.2 Optional concept turnarounds per Tier A unit with a large model (review references only). Ask the operator before any first-time model download (`image.generate` consent flow)
- [ ] 3.3 (**moved** to ground-forces-rework 5.2) Texture keyframes on the studio: 3 candidates per Tier A unit, then pick for shading. Record provenance in `art/families/ground-host-runs.json`
- [ ] 3.4 (**moved** to ground-forces-rework 5.3–5.5) Author grid frames per the column layouts:
  - move, telegraph (channel fill), fire, recoil, hit, damage, special and wreck;
  - walkers keep ≥ 3 texels of clear ground between the legs
- [ ] 3.5 (**moved** to ground-forces-rework 5.6) Pack `assets/images/ground-host.png` and the appended `ground-troops.png` rows. Generate `lib/game/ground_host_atlas.dart` and the updated `ground_troops_atlas.dart`
- [ ] 3.6 (**moved** to ground-forces-rework 5.6) Contact sheet `art/contact/ground-host-contact.png`, including a greyscale strip and a black-fill strip
- [ ] 3.7 (Tier B, flagged) Narthex, Rosegun, Thurible and Cistern rows

## 4. Gameplay hooks (skirmish layer only)
- [ ] 4.1 New `GroundForce` values and the per-sector mix weights in `SkirmishFront`; caps and intervals unchanged
- [ ] 4.2 Reliquary unload (once, at the hold line or at ≤ 50% HP, cap permitting)
- [ ] 4.3 Carillon stand-off at U(620, 760), the ranging tilt and channel fill, and the arcing slag-shell tracer
- [ ] 4.4 Hodcrawler mending (+1 HP every 4 s within 90 texels) and the trailing behaviour
- [ ] 4.5 Knell-bearer rally on a tide surge (+20% for 5 s within 120 texels)
- [ ] 4.6 Chapterhouse:
  - at most one per visit (Hollow from route 1, Carrier from route 2);
  - arrival interval ×0.85 while it is alive;
  - when it falls: Rubblings within range rout, and the tide is forced into a 6 s lull
- [ ] 4.7 Painter: Host atlas drawing, telegraph frames 0.6 s before each Host shot, specials, fx row, and reduced-motion handling
- [ ] 4.8 Events `reliquaryUnloading`, `artilleryRanging`, `walkerSighted`, `hostCommandSighted` and `hostCommandFallen` in a `// --- undercroft host` block, rate-limited. Map them in comms onto existing generic ground lines

## 5. Review and proof
- [ ] 5.1 `test/ground_host_sim_test.dart`: same threat (breakthroughs and ground shots equal, Host off against on), no ally retreats in sectors 1–2, Tier A presence, at most one command per visit
- [ ] 5.2 `test/ground_host_test.dart`: the unload, mend, rally, rout and hold-line rules, plus the invariants (no `model.random`, no homing targets, no pressure or strength change)
- [ ] 5.3 (art half **moved** to ground-forces-rework 7.2) Atlas contract tests: cells, binary alpha, palette membership, gilt coverage and gilt stillness, no ally-cyan pixels on Host rows, walker leg gaps
- [ ] 5.4 `test/ground_host_visual_test.dart`: phone (360 × 780) and desktop (1280 × 720) frames in all five sectors with allies, swarm and Host on screen together; frame cost < 16 ms
- [ ] 5.5 Operator review against the style guide checklist (Section 11), then fold the decisions into `plan/game-design.md` ("Ground war") and the main specs
