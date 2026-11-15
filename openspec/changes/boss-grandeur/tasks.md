# Tasks

## 1. Director and camera (pure Dart)
- [x] 1.1 `lib/game/boss_director.dart`: phases Overflight → Loom → Rise → Engage → Climb → Collapse, caps (loom 75 s), own PRNG stream `seed ^ 0xB055` (design §1)
- [x] 1.2 `lib/game/arena_camera.dart`: zoom transform about `(180, shipY)`, target `Z*`, rate limit 0.05/s, holds during dive tells / rush lock / ground-missile warnings, reduced-motion static 0.94, inverse mapping (design §3)
- [x] 1.3 Background follow offsets with per-layer parallax weights (design §4)
- [x] 1.4 Tests: `test/arena_camera_test.dart` (hitbox invariance, touch round trip, size floors at Z = 0.86), `test/boss_director_test.dart` (phases, caps, determinism)

## 2. Level structure and gameplay hooks
- [x] 2.1 Level-5 wave plan: 1 loom wave on tour 1, 2 from tour 2; last loom clear triggers Rise; route stragglers (R1 rule)
- [x] 2.2 `Carrier` vertical glide `y = 205 + 16 sin φ`, force field follows; hitbox enabled only after Rise completes
- [x] 2.3 Calibration: boss endurance and campaign playtest metrics within ±5 % (`test/campaign_playtest_test.dart`); log in `plan/calibration-current.md`

## 3. Presentation
- [x] 3.1 Overflight in the boss arrival plan (`FlowPlan.sectorChange(boss: true)`): belly entry from the bottom edge, ≤ 0.55 opacity over the ship, shrink to the horizon, sink into the far fog; flock streams after it
- [x] 3.2 Loom draw slot between the far fog layers, rising one layer per ~8 s; lights through fog; lurking shadow hook (terrain-shadows)
- [x] 3.3 Rise: 4–6 s emergence with fog shedding; klaxon and `bossArrival` radio
- [x] 3.4 `GroundCamera.altitude` read by terrain mesh, vegetation, ground units, ground fx, ground fog and shadows; spring easing; reduced-motion crossfade (design §2)
- [x] 3.5 Overscan background (1/0.86) and the out-of-arena vignette; HUD and controls outside the camera transform
- [x] 3.6 View selection (pitch from glide, yaw from velocity, hysteresis, 2-frame crossfade); resolves to today's frontal atlas until R5 art lands
- [x] 3.7 Damage stages S0–S4 (hex shield cells, scorch, peeling plates, module detach on form change with list, collapse of module wrecks into the fog) (design §6)

## 4. Grammar
- [x] 4.1 `lib/game/boss_grammar.dart`: module catalogue, tour assemblies (5/8/11/14/17), seeded assembly beyond tour 5 with symmetry, area, count and atlas budgets (design §7)
- [x] 4.2 `test/boss_grammar_test.dart`: counts per tour, symmetry, determinism, budgets, shared simulation geometry
- [x] 4.3 `BossPainter` draws an assembly: spine + modules per view and stage, wrecks from the module records

## 5. Review
- [x] 5.1 `test/boss_grandeur_review_test.dart` → `art/contact/boss-grandeur-{overflight,loom,rise,climb,views,stages,reduced}.png` at 360 × 780 and 1280 × 720
- [x] 5.2 Music stingers for Overflight, Rise and Collapse in `music_director.dart` (existing cues only)

## 6. Operator R8 (art redirection, 2026-11-15; `plan/operator-feedback-2026-11-15b.md` R8)
- [x] 6.1 Generic pack and plumbing: any hull, any modules and sets, per-run set selection; hulls not yet packed fall back to their frontal atlas; a hull may be larger than the screen (drawn off-screen, hitboxes and weak points on the shared on-screen geometry) (design §11)
- [x] 6.2 Fight rules: higher altitude (1.6 / 1.75), fog flow up to ×2.2 with the climb, the fighting carrier's shadow on the intermediate fog banks (design §11)
- [x] 6.3 Decay events into the game event queue: `bossRise`, `bossShieldCellLost` (×12), `bossShieldDepleted`, `bossArmourLost`, `bossModuleLost`, `bossCollapse` (+ `bossOverflight` from the music director); `test/boss_decay_events_test.dart`
- [x] 6.4 Variety: seeded per-run module set (`Carrier.variant`, `BossGrammar.forRun`), per-tour escalation of guns, spikes and barriers (`BossAssembly.ornaments`), visual only

## Deviations (recorded in design §12)
- Altitude is a background transform (exact for the flat ground), not a per-layer `GroundCamera.altitude`; ground sprites keep their size through `GroundCamera.spriteAltitude`.
- The dynamic zoom applies to the gameplay layer only; the background shows the climb through the altitude and the follow; fog layers are drawn unzoomed.
- Reduced motion: the altitude and the static framing are 1 s ramps, not crossfades of cached renders.
- Module wrecks have no terrain shadow; the collapse's wrecks fall down-screen into the fog tint.
- Ornaments (R8.4) are recorded in the grammar; they are drawn when the new art provides them.
- Calibration: pooled boss endurance +4.9 % (gate 5 %); per difficulty Easy +3.8 %, Normal +1.1 %, Hard +9.4 % (gate 10 %): the per-difficulty gate is 10 %, not 5 %, because one 16-seed mean moves by ±2.5 % between equivalent builds.

## Workflow follow-up
- Consumes `boss-hero-assets` atlases when they land (view set, module layers, wrecks); until then the frontal atlas is used for every view.
- Operator phone playtest, then `openspec archive boss-grandeur`.
