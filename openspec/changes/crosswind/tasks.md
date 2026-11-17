# Tasks: crosswind

## 1. Wind field and plan (pure Dart)
- [x] 1.1 `lib/game/weather/wind_field.dart`: `WindSpec`, `WindField` (seeded shifts, gusts, flutter, forecast,
      bounded plan), `WindPlan.forLevel` (one eligible level in five; calm first sector, carrier, unseeded runs) and
      `WindPlan.bonusLevel`
- [x] 1.2 Tests: deterministic, bounded, swings, forecast lead, plan frequency, calm cases

## 2. Wind in the model
- [x] 2.1 `lib/game/model_wind.dart` (`part of model.dart`): `WindRun`, the level's spec (forced, bonus, plan), the
      per-step sample and its calls (`windStart`, `windGust`, `windStop`)
- [x] 2.2 Every projectile drifts (`Shot.windVx`), a tailwind adds one grid step at the muzzle (`Shot.windVy`); hooks
      in the shot loop (`// --- crosswind`)
- [x] 2.3 Demons fight the wind (operator direction): bounded push, lean, per-rank yield; hooks around
      `_updateDemons`
- [x] 2.4 The brood aims with the wind (`broodAim`), in `_hostile`
- [x] 2.5 `ShotLayer`: interpolation and smear include the wind
- [x] 2.6 Tests: both sides drift, bounded drift and speed-up, call lead time, demon yields and bounded push

## 3. Look
- [x] 3.1 `lib/game/weather/wind_layer.dart`: billows, wisps, windsock (forecast-driven), reduced motion
- [x] 3.2 `FrameBudget.windScale`; scene hooks; a shower slants with the wind
- [x] 3.3 Review sheet `test/crosswind_review_test.dart` -> `art/contact/crosswind-sheet.png`
- [x] 3.4 Gallery: wind tiles on the weather page; Crosswind on the bonus page (from the catalogue)

## 4. Crosswind bonus level
- [x] 4.1 `lib/game/bonus/levels/crosswind.dart`: the level, its rules (no Spread, no Rapid), `CrosswindMechanic`
      (kites, single shots), catalogue entry (appended)
- [x] 4.2 `PowerRules.merge`: a level's ban beats a run's `only`
- [x] 4.3 Kite sprites: studio runs, picks, `tools/wind_kites` (Go), atlas and Dart; ledger
      `plan/render-runs/wind-kites.md`
- [x] 4.4 `crosswind_painter.dart`: kites, tails, pops, tally
- [x] 4.5 Briefing card how-to strip, mission medal (rigkit hull, studio pick, ledger)
- [x] 4.6 Challenge "POP EVERY KITE" on bonus-challenges' API (merged `origin/work/bonus-challenges`), kite
      pictogram, challenger pilot strategy
- [x] 4.7 Tests: rules, single shots, Spread Only, kites deterministic and riding, completion

## 5. Radio and music
- [x] 5.1 Lines appended to `art/comms/lines.json`; `comms_pipeline.py dart`
- [x] 5.2 Merged bonus-music (via origin/game): `bonusStart` crosswind plays `bonus-wind`; fail soft without it
- [x] 5.3 `windGust` also queues `musicAccent {name: 'gust'}` (bonus-music's API)
- [x] 5.4 Tests: gust swell per call, accent event name, own song and fail-soft

## 6. Calibration and gates
- [x] 6.1 `tools/ordinary_wave_probe.dart` `wind=on skill=`; Average pilot `windSkill`
- [x] 6.2 Record before/after in `plan/calibration-current.md`
- [x] 6.3 §2 gates
