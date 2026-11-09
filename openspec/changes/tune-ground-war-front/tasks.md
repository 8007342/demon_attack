# Tasks

## 1. Front
- [x] 1.1 `GroundFront` per sector replaces the wave-based `GroundPlan`; schedule on the level's combat clock
- [x] 1.2 Allied fire destroys demon units; sectors 1–2 always escorted and guaranteed held
- [x] 1.3 `alliedStrength` and `pressure` meters; one breakthrough at a time
- [x] 1.4 Breakthrough prediction, call for help, `groundBreakthrough`, `groundPressure`, `groundUnitDestroyed.by`
- [x] 1.5 Homing drops: urgent while a breakthrough looms; otherwise every 40 kills

## 2. Presentation
- [x] 2.1 Beacon only while calling for help
- [x] 2.2 Hints: missile dodge at the first Ember entrance, homing at the first Hollow entrance
- [x] 2.3 Review renders: staged moments plus live frames (early Krybor skirmish, Hollow breakthrough)

## 3. Calibration and tests
- [x] 3.1 Profiler: per-sector breakthroughs and would-be hits, allied kills
- [x] 3.2 Multi-seed calibration (baseline, attentive, naive) and docs
- [x] 3.3 Tests: early activity on every difficulty, allies win and nothing reaches fire range in sectors 1–2, schedule independent of wave speed (fast vs slow player), later-sector breakthrough after a call for help, pressure meter and events, homing drop urgency, campaign autopilot on all difficulties
