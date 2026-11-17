# Tasks

## 1. Diagnosis and rules
- [x] 1.1 Find why the talons read as hearts, from the glyph data and the shipped sheets (design §1)
- [x] 1.2 Write the readability rules for marks of a few pixels (design §1; styleguide §4.1)

## 2. Design and art
- [x] 2.1 Count the ranks in code: `AlienRank` has five; drones carry none, so four marks, also used by carrier forms 1–4
- [x] 2.2 Author candidates per rank in `tools/alien_insignia/gargoyle.go`; `go run . candidates` renders them on the four species at 8×, 2×, DPR 2 and DPR 1 (`art/contact/gargoyle-insignia-candidates.png`)
- [x] 2.3 Pick fang, twin fangs, winged fang and winged crown; log the picks and rejections in `plan/render-runs/gargoyle-insignia.md`
- [x] 2.4 `go test` in `tools/alien_insignia` enforces the rules and the lookalike ceiling on the shipped glyphs

## 3. Atlas and runtime
- [x] 3.1 Regenerate `assets/images/insignia.png` and `lib/game/insignia_atlas.dart` with `go run . atlas -root ../..` (byte-identical across runs)
- [x] 3.2 `InsigniaPainter.glyphKey` maps the ranks to the new keys; doc comments in `sprite_atlas.dart` and `scene.dart`
- [x] 3.3 `test/insignia_test.dart`: the new keys, and a test that the ladder widens with rank

## 4. Review and docs
- [x] 4.1 `test/gargoyle_insignia_review_test.dart` (review tag): the dense formation in the real scene, with the atlas, without it, and the placed marks
- [x] 4.2 `go run . gargoyle -root ../..` writes `art/contact/gargoyle-insignia.png`: the ladder at 8×, 2× and 1×, on the demons at phone size, and in game, old against new
- [x] 4.3 Update `docs/styleguide/alien-troops.md` (§3, §4, §4.1, §7, §9)

## Workflow follow-up
- Operator phone playtest of the new ladder, then archive `alien-insignia` and, after it, this change.
