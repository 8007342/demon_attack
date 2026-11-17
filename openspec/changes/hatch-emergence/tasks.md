# Tasks

## 1. Spec (`work/hatch-emergence`)
- [x] 1.1 Proposal, design (hatch candy, beats, variants, budgets, pipeline, tiers), delta specs; sources read 2026-11-17
- [x] 1.2 `openspec validate hatch-emergence --strict`

## 2. Art (design §4; ledger `plan/render-runs/hatch-emergence.md`)
- [x] 2.1 rigkit: named key poses with a parent chain (`articulation.keyposes`, `parents`); the joystick tilt grid unchanged
- [x] 2.2 The family `art/families/hatch-emergence.json` from `tools/rigkit/families/hatch_emergence.lua`: one skeleton, three species, 12 key poses; clay checked on CPU before any GPU
- [x] 2.3 Heroes in the studio (Qwen edit, Lightning 4-step), one job per species, four seeds each; picks logged with reasons and the head-reading check
- [x] 2.4 rigsheet: a family tone grade for pose finishes; `posepack` (hulls × poses, one cell, generated Dart); `bake_poses.lua --pack`
- [x] 2.5 `assets/images/hatch-emergence.png` + `lib/game/hatch_emergence_atlas.dart`; the rebuild is byte-identical

## 3. Runtime
- [x] 3.1 `lib/game/hatch_emergence.dart`: beats, variants, lurkers, the director (exactly once), budgets
- [x] 3.2 `lib/game/hatch_emergence_painter.dart`: one image per frame, the rim clip, the flip, the glide anchor
- [x] 3.3 `CarrierHatchPainter`: inner glow, telegraph pulse, vents and ichor, the thinning field and its ripple, the break burst, staging
- [x] 3.4 Hooks (`// --- hatch-emergence`): `scene.dart` (load, update, lurkers after the front pass, the creature loop), `model.dart` (`fightMinionCap`, `hatchFlockPreview`, read only), `perf/frame_budget.dart` (`emergence`, `lurkers`, `hatchVents`)

## 4. Tests
- [x] 4.1 `test/hatch_emergence_test.dart`: timing inside the windows; parity; exactly once; variety; LITE; atlas and draw-call budgets
- [x] 4.3 The head-reading guard (lead review: the first draft read as a reptile eye): redesign per design §1.7; `test/hatch_eye_guard_test.dart` (eye ≤ 0.35, concentric ≤ 0.45); sheets re-rendered
- [x] 4.2 Calibration gates unchanged (full `flutter test`)

## 5. Review
- [x] 5.1 `test/hatch_emergence_review_test.dart` (review tag): close-ups, strips per species, in-fight frames and GIF in `art/contact/`
- [ ] 5.2 Operator review in the preview (the operator overrides the picks)
