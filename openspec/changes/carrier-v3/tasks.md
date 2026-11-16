# Tasks

## 0. Research, spec and plan (this phase)
- [x] 0.1 Research with provenance: `plan/carrier-v3-research.md` (scale and speed, sprite bending, hull-conforming fields, carrier launches)
- [x] 0.2 This change: proposal, design, delta specs, tasks; `openspec validate carrier-v3 --strict`
- [x] 0.3 Re-render plan: `plan/render-runs/carrier-v3.md` (Blender changes, GPU estimate, 16 MB budget per hull)
- [x] 0.4 Link both from `plan/operator-feedback-2026-11-16.md` C1
- [ ] 0.5 Operator review of the spec (gate for everything below)

## 1. Script and director (pure Dart, no art needed)
- [ ] 1.1 `lib/game/carrier_script.dart`: `CarrierScript` for tours 1–5 (design §8 table) and seeded scripts beyond tour 5 within tour 5's limits; unseeded runs use the authored script
- [ ] 1.2 `BossDirector`: phases Overflight → Approach → Close → Takeoff → Climb → Collapse (design §4); approach distance D with steps and creep; the 90 s cap
- [ ] 1.3 `ArenaCamera`: the per-tour carrier band (`minZoomFor(tour)`); floors and envelope per tour (design §5.2); `test/arena_camera_test.dart` floors at 0.62
- [ ] 1.4 Tests: `test/carrier_script_test.dart` (determinism, limits beyond tour 5), `test/boss_director_test.dart` (approach steps, cap, hittable threshold, take-off timing)

## 2. Gameplay hooks
- [ ] 2.1 `lib/game/carrier_gates.dart`: gate state machine (closed → telegraph 1.2 s → opening 0.5 s → launching → closing 0.8 s), volleys at 0.12 s, own PRNG stream `seed ^ 0xB055 ^ 0x6A7E`
- [ ] 2.2 `model.dart`: launch waves (the loom waves' rosters) enter from gate positions projected through D; `Carrier.emerge` becomes the Close progress; `_beginRise` becomes the Close; the cap is 90 s
- [ ] 2.3 Fight minion flocks out of on-screen gates (round-robin over gates with `|x| ≤ 150` arena units at the carrier's x)
- [ ] 2.4 Shield intercept unchanged; `test/carrier_field_equivalence_test.dart` (shield hit log identical)
- [ ] 2.5 Calibration: boss endurance (`test/boss_endurance_test.dart`) and campaign playtest within the boss-grandeur gates (pooled 5 %, per difficulty 10 %), plus the boss level's clear time within 10 %; log in `plan/calibration-current.md`

## 3. Bend (works on today's art)
- [ ] 3.1 `lib/game/carrier_bend.dart`: the analytic bend (design §2.2), springs, limits, wing lag, buffet; anchor invariance test (±3 units at the limits)
- [ ] 3.2 `BossPainter`: one `drawVertices` per pass from the hull page's `ImageShader` (grid step 20 units, `FilterQuality.low`), vertex buffers reused, rebuilt only when the bend moves; stored view (45, 0) only
- [ ] 3.3 Until the re-render: per-module heights from the mount (dorsal, lateral, bow, ventral); the height-parallax shift is capped at 4 units
- [ ] 3.4 Retire the view selection (`BossView` stays as the hero view for non-carrier hulls)
- [ ] 3.5 Profiling on a mid-range Android phone in Chrome (CanvasKit) and Safari iOS: the carrier passes ≤ 2 ms of raster per frame at DPR 2; record it in the design

## 4. Force field
- [ ] 4.1 `shaders/carrier_field.frag` (design §3): rim band from the signed distance, offset by the shield, 12 region masks, hex lattice near impacts and in the scan, up to 4 ripples, inverse bend
- [ ] 4.2 Data texture per hull from the pack (R distance, G region, B height); until the re-render, generate it at load time from the hull's S0 alpha (Dart, jump flooding at 0.5 px/unit)
- [ ] 4.3 Region depletion order (outer arms inward, prow last) mapped onto the 12 shield cells; the insignia row stays on the front lip
- [ ] 4.4 Fallback without shader support: today's arc

## 5. Presentation
- [ ] 5.1 Approach draw slots between the fog layers by D; aerial perspective `fog = 1 − e^(−0.55 (D − 1))`; running lights through the fog
- [ ] 5.2 Gate presentation: telegraph lights, rail chase, door states (runtime-drawn leaves until the re-render's door layers), ejection
- [ ] 5.3 Take-off beat (design §4.4): world pitch (the transition-ascent pitch), fog rush, nose-up bend, altitude spring, zoom ease
- [ ] 5.4 Speed cues (design §6): fog streaks, differential cloud flow, vortex trails, torn wisps, buffet, trauma shake on four beats
- [ ] 5.5 Reduced motion (design §7)

## 6. Events and audio
- [ ] 6.1 `game_events.dart`: the new names and data (design §9); `test/boss_intro_events_test.dart` (order, throttle)
- [ ] 6.2 `music_director.dart`: existing cues on `bossApproach`, `bossInRange` and `bossTakeoff`; the doom and epic-metal layers wait on tillandsias#1103

## 7. Re-render (after the operator's review; `plan/render-runs/carrier-v3.md`)
- [ ] 7.1 Rig and kit: one stored view, gate and compartment modules with door states, under-painted occlusion margins, the height, distance and region grid export, per-tour envelopes
- [ ] 7.2 Tour 1: regional gate and fix passes on the three picked heroes; stages re-projected
- [ ] 7.3 Tours 2–5: hero rerolls with the face and teeth fixes, S2 and S3 looks, bellies
- [ ] 7.4 Pack, budget (≤ 16 MB per hull), review strips `art/contact/carrier-v3-*.png`
- [ ] 7.5 Operator phone playtest

## Archive order
`boss-grandeur` is archived first, then this change: its MODIFIED requirements replace boss-grandeur's.
