# Tasks

## 1. Comms data (done in this change)
- [x] 1.1 Add `frontCall` (5 lines) and `frontCall.1`–`frontCall.4` (2 lines each) to `art/comms/lines.json`, each with a recorded ground-distress placeholder (design §4)
- [x] 1.2 Regenerate `lib/comms/comms_bank.dart` and `plan/audio-studio/voice-batch-pending.md` with `python3 tools/comms_pipeline.py dart`; comms tests green

## 2. Flow beats
- [x] 2.1 `FlowPlan.sectorChange`: add `speed`, `pitch`, `roll`, `streaks` beats with reduced-motion gains (design §1); `climb` amplitude 24; `tilt` kept only for outro and game over
- [x] 2.2 `test/flow_director_test.dart`: `speed` monotonic to the swap, reduced plan has zero pitch/roll/streaks, swap still inside the cloud peak

## 3. Presentation
- [ ] 3.1 `scene.dart`: replace the flat tilt translate with the pitch transform (horizon drop 96·q, ground scale 1 + 0.35q about the horizon; sky translate only) and the world-only roll about the ship
- [ ] 3.2 Cinematic ship: rise ≤ 24, thrust `1 + 2.5·climb + 1.5·speed`, scale nudge `1 − 0.04·speed`
- [ ] 3.3 `flyover_background.dart` and `atmosphere.dart`: speed factor `1 + 7·env('speed')` (reduced `1 + env`), dropping the travel sin bump
- [ ] 3.4 Fog streaks (10–14, seeded from the plan, cloud pass), zero in reduced motion

## 4. Front calls
- [ ] 4.1 Track visited sectors and the destination in `model_flow.dart`
- [ ] 4.2 `RadioCategory.frontCall` reading `frontCall*`; `InterludePlanner.planRadio` prefers `frontCall.<dest>` then `frontCall` on revisits, falling back to today's order; `bossArrival` untouched
- [ ] 4.3 `test/interlude_test.dart`: revisit / first visit / boss arrival / short window

## 5. Review
- [ ] 5.1 `test/transition_ascent_review_test.dart` → `art/contact/transition-ascent-full.png`, `-reduced.png` (12 frames, 360 × 780 and 1280 × 720)
- [ ] 5.2 Update `cinematic-flow` design §2 cross-reference

## Workflow follow-up
- Voice batch: record the 13 `frontCall*` lines when tillandsias#1103 unblocks; the placeholders fall away with no code change.
- Operator phone playtest, then `openspec archive transition-ascent`.
