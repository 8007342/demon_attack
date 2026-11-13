# Tasks

## 1. Navigation core
- [ ] 1.1 `MoveClass` and `moveClassOf` (forces, sector vehicles, ally variants); per-class limits table
- [ ] 1.2 `TerrainField.tagsAt(s, w)` (ravine, cliff, plateau, valleyFloor, crest, brush), with the same frames and centre blend as `rawHeight`
- [ ] 1.3 `GroundNav` lattice (48 × 36), incremental refresh (1/6 of the rows per step), slope, tags, no allocation per step
- [ ] 1.4 Links from features (bridge, ford, climb line, jump-down, crest hop), deterministic per feature id; reservation table with capacity
- [ ] 1.5 Per-class backward lateral flow field for both travel directions; `next` and `pace` lookup
- [ ] 1.6 `_v4Route`: drop the height term (ravine attraction), add the field cost along the look-ahead chain; `_v4Steer` reads it; threat units are clamped to their band
- [ ] 1.7 `_v4Advance` and `_updateAllies`: skirmish and ally depth speed × pace; queueing at links; 3 s queue timeout to grind
- [ ] 1.8 `_v4Convoy`: project the slot and foe goals onto the field; ally reach per class
- [ ] 1.9 Blocked threat units: cheapest band cell, ford or grind state, depth untouched

## 2. Poses and presentation
- [ ] 2.1 `GroundPose`: `slopeAlong` (signed along travel), `slopeAcross`, `state`, `hidden`, `crestY`; `climb` becomes an alias; fix the convoy sign in the painter and `TerrainRadio`
- [ ] 2.2 State machine with hysteresis, 0.35 s hold, z < 900 LOD, at most 3 non-walk units on screen
- [ ] 2.3 `TerrainView.trueY` and `crestY`; painter clips units and shadows on hidden ground
- [ ] 2.4 Contact shadow (stepped ellipse, lit-slope opacity, narrows with lift)
- [ ] 2.5 Slope-directed dust, crest-hop arc, jump arc, reduced-motion fallbacks
- [ ] 2.6 Radio: `convoyFording`, `convoyBridge`, `troopsClimbing`, `enemyDetour` in a `// --- ground terrain` block

## 3. Art (Go pipelines)
- [ ] 3.1 `tools/ground_troops`: `pose` gains pitch, climb, wade, air and crouch; infantry rows get climb, climb-line, descend, jump and wade frames; the tank gets pitch ±1, +2 and ford; the atlas grows to 20 × 7 cells; fx row 6 holds the sector splashes and pebbles
- [ ] 3.2 Ground-forces pipeline: vehicle pitch ±1 and ford, buggy crest air and land, ally hull climb, descend and ford, walker climb and stride-over
- [ ] 3.3 One ComfyUI shading keyframe per unit per pose family (climb, descend, jump, wade, pitch); provenance in `art/families/ground-troops-runs.json` and `ground-forces-runs.json`
- [ ] 3.4 Contact sheets; review at 1× and 3× over all five sector grounds; silhouette (solid-fill) check at the z 600 drawn size

## 4. Bridges
- [ ] 4.1 Bridge placement exposed to the flyover (feature id → w, s, span)
- [ ] 4.2 A bridge prop per sector on the mesh (rides the canyon rims; depth-sorted with units)
- [ ] 4.3 Show bridges as bridges instead of the interim ford presentation

## 5. Proof
- [ ] 5.1 `test/ground_nav_test.dart`: class mapping, tag determinism, ravine tags on flat canyon floors, slope limits, link generation and capacity, look-ahead swerve ≥ 1.5 s, no allocation per step
- [ ] 5.2 `test/ground_terrain_sim_test.dart`: headless relief, sectors 1–5 × difficulties × routes 0–1, 120 s each: no skirmish unit or ally on a ravine cell without a link; threat units only when their band is blocked; heavies never on cliff or plateau
- [ ] 5.3 Threat parity: navigation on and off, equal breakthroughs, missiles and launch times; hit rate within 5%; flat-ground positions identical to the previous build
- [ ] 5.4 Presentation: climb sign for convoy and demons, hidden-ground clipping, state hysteresis, radio rate limits, reduced motion
- [ ] 5.5 Perf: navigation share ≤ 0.25 ms per frame in `ground_war_v4_visual_test.dart`; review frames at 360×780 and 1280×720 in every sector (a ridge crossing, a canyon ford, a mesa detour)

## 6. Docs and merge
- [ ] 6.1 `plan/terrain-relief.md`: navigation section; fix the stale `_climbDust` reference
- [ ] 6.2 `plan/style-guide.md`, "Ground war presentation": link to `ground-troops-terrain-style-guide.md`
- [ ] 6.3 Reconcile with `gargoyle-ground-army`: its units map onto `MoveClass`, and its pose lists follow the style guide
