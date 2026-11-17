# Tasks

## 1. Analysis (`work/fire-rate-tune`)
- [x] 1.1 Read the fire timer, shot speeds, hostile speeds, the fixed-step accumulator and the shot painter; write the causes (design §1)
- [x] 1.2 `tools/strobe/strobe.lua`: displacement, spacing, correspondence ratio and rounding beat per stream at 120/60/30 Hz, before (`--before`) and after (design §3.1)
- [x] 1.3 Sources with provenance; the snippet-only perceptual claims as `fr-*` entries in `plan/provenance-audit.md`

## 2. Model (`lib/game/model.dart`, `// --- fire-rate-tune` markers)
- [x] 2.1 `fireSteps` 18, `rapidFireSteps` 8, `fireInterval` in whole steps; the `1e-9` timer epsilon
- [x] 2.2 `shotSpeed` 480, `spreadShotSpeed` 420; the Spread sprite chosen by the constant in `ship_painter.dart`
- [x] 2.3 `hostileVy` on the 15 u/s grid, applied in `_hostile`
- [x] 2.4 The accumulator epsilon in `update`; the volley timer never carries an overdue step (the vsync snap is phone-performance's)
- [x] 2.5 Pilots and the core-door lead pip use `ArcadeModel.shotSpeed` instead of 390

## 3. Recalibration (CLAUDE.md §7)
- [x] 3.1 Before: the gates on `game` 5961ae11; the Average pilot (`tools/ordinary_wave_probe.dart`), the fairness harness, the profiler
- [x] 3.2 Ordinary sectors: sentinel hull × 0.7 (`DifficultyPolicy.sentinelHull`, also the bonus par), dive shields −1; rosters tried and rejected (design §5.1)
- [x] 3.3 Carrier: hatch pools, core shares and `minLayer` 2 inside the carrier-hatches target bands, difficulty order on every tour (design §5.2)
- [x] 3.4 Loom cap 120 s (tour 5's third launch wave)
- [x] 3.5 Supply Run crates every 3 s (bonus balance duration band)
- [x] 3.6 Tests whose numbers the change moves on purpose: boss endurance hits re-baselined; progression, combat balance, combined powers, carrier hatches, wing cannons updated; the drones and escort tests made robust to the faster kills
- [x] 3.7 Before and after values in `plan/calibration-current.md`, "Fire-rate tune"

## 4. Review
- [x] 4.1 `test/fire_rate_tune_test.dart`: the spec's scenarios
- [x] 4.2 `test/fire_rate_tune_review_test.dart` (review tag) and `art/contact/fire-rate-tune.png`; picks and notes in `plan/render-runs/fire-rate-tune.md`
- [x] 4.3 Gates: `flutter analyze`, `flutter test` (lock, concurrency 2), `npm run test:worker`, `npm run build`, `openspec validate fire-rate-tune --strict`
- [ ] 4.4 Operator playtest on a phone at 60 and 30 fps; the renderer half (smear, interpolation, sprite phase) lands with `phone-performance` (design §4)
