# Tasks

## 1. Simulation
- [x] 1.1 Skirmish layer (`SkirmishFront`, `GroundSkirmish`): its own random stream, tide, arrival groups, hold line, artillery timeout
- [x] 1.2 Mixed forces by level on both sides; convoy escort slots that follow the ship
- [x] 1.3 Full-width manoeuvre for every unit (terrain-aware routes, spread, flanking); allies close on their foe and fall back
- [x] 1.4 Fall-back and repair instead of totalling in skirmishes; no feedback into pressure, strength, homing or `model.random`
- [x] 1.5 `// --- ground war v4` events: groundSkirmish, infantryEngaged, skirmishWon, allyFallingBack, heavyArmorSighted, groundTide

## 2. Terrain and presentation
- [x] 2.1 Coarse relief (segment 520, ×2.2 features, long rolling wavelengths, lane 62% with no seam, near envelope)
- [x] 2.2 Stronger shading plus an additive slope and crest light (dark grounds)
- [x] 2.3 Troop and heavy-tank rendering, weapon tracers, IFF chevrons, larger allies
- [x] 2.4 Plant depth sort (`GroundOccluders`)

## 3. Art
- [x] 3.1 `tools/ground_troops` (Go): jobs/run/ingest/pack/offline; 15 keyframes on the studio, 5 selected; provenance in `art/families/ground-troops-runs.json`
- [x] 3.2 `assets/images/ground-troops.png`, `lib/game/ground_troops_atlas.dart`, `art/contact/ground-troops-contact.png`

## 4. Proof
- [x] 4.1 `test/ground_war_v4_sim_test.dart`: same threat (L1–L2 zero, L3–L4 not above v3), ≥ 3× engagements per minute
- [x] 4.2 `test/ground_war_v4_test.dart`: rules, progression, manoeuvre, convoy, tide, v3 parity, depth sort
- [x] 4.3 `test/ground_war_v4_visual_test.dart`: review frames at 360×780 and 1280×720 in every sector, frame cost
