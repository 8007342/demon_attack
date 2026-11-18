# Tasks: weather-everywhere

## 1. Storms in regular sectors (model, pure Dart)
- [x] 1.1 `lib/game/weather/storm_plan.dart`: `StormSpec`, `StormPlan.forLevel` (rain/downpour levels, 14 %), `force`, the regular `StormTuning`
- [x] 1.2 `lib/game/model_weather.dart`: `WeatherRun`, `_stormBeginLevel`, `_stormStep` on lightning-rework's API; hooks in `model.dart` and `model_wind.dart` (`// --- weather-everywhere`)
- [x] 1.3 Events `stormStart`, `stormStop`, `windDive`; `windStart` and `windGust` carry a radio variant

## 2. Flash safety and look
- [x] 2.1 `StormLook` (regular, Stormfront, LITE), marker blink ≤ 3 Hz with an integrated phase, Stormfront glow capped
- [x] 2.2 `lib/game/weather/storm_layer.dart`: `FlashSafety` (reduced flashing, `?flash=low`, luminance step), `StormLayer`; scene hooks
- [x] 2.3 Ship zap flicker 3 Hz and off with reduced flashing; ship static reads regular storm tells

## 3. Radio
- [x] 3.1 Six triggers appended to `art/comms/lines.json` (group `weather`, 10 s); `python3 -I tools/comms_pipeline.py dart`

## 4. Wind flap
- [x] 4.1 Feasibility: the rig reproduces `combat.png` pixel for pixel; `tools/generate_wind_flap.py`, recipe `art/families/wind-flap.json`
- [x] 4.2 Candidates A/B/C, pick B, fit pass; ledger `plan/render-runs/wind-flap.md`; sheets `art/contact/wind-flap-*.png`
- [x] 4.3 `assets/images/wind-flap.png`, `lib/game/wind_flap_atlas.dart` (generated), `lib/game/weather/wind_flap.dart`; virtual rows in the scene and `CombatAtlas.headAnchor`
- [x] 4.4 Gallery weather page: storm, storm + gale, wind-flap sheet

## 5. Smart dives
- [x] 5.1 `ArcadeWindDive`: who reads the wind, `windDiveDelay`, held prep, the ride (curve and aim), tallies
- [x] 5.2 Crosswind's push bound test admits the ride

## 6. Tests and gates
- [x] 6.1 `test/weather_everywhere_test.dart`: frequencies, regular bolts, flash limits, reduced flashing, radio lines and pacing, wing asymmetry, smart-dive preference, bounded waits
- [x] 6.2 CLAUDE.md §4 row for the generated wind-flap files; `plan/calibration-current.md` note (unchanged)
- [x] 6.3 §2 gates
- [ ] 6.4 At archive (after dynamic-weather): MODIFY "Rain respects accessibility settings" to drop its "No lightning outside Stormfront" scenario
- [ ] 6.5 Operator playtest: storm frequency, flap readability at phone size, the ride's curve
