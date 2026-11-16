# Tasks

## 1. Research
- [x] 1.1 Readable 2D rain: layers, splashes, density, reduced motion, flashes, batching; sources with provenance in `plan/dynamic-weather-research.md`, the unsourced readability claim in `plan/provenance-audit.md#W-01`

## 2. Plan
- [x] 2.1 `RainPlan.forLevel`: seeded per run, route and sector; unseeded, sector 5 and bonus levels dry
- [x] 2.2 Tiers, peaks, wind, mid-level start and stop, gusts (`RainSpec.intensityAt`)

## 3. Layer
- [x] 3.1 `RainLayer`: slew, far and near streaks, splashes, dim, haze, wet sheen; batched `drawRawPoints`
- [x] 3.2 Scene hook after the backdrop, under the play, over the band above the arena (`// --- dynamic-weather`)
- [x] 3.3 Reduced motion: fewer, slower, shorter drops, no splashes, no gusts
- [x] 3.4 Audio events `rainStart`, `rainStop`, `rainIntensity` through `dispatchGameEvent`

## 4. Tests and review
- [x] 4.1 `test/dynamic_weather_test.dart`: dry unseeded runs, frequency, determinism, soft ramps, events, draw budget and timing
- [x] 4.2 `test/dynamic_weather_review_test.dart`: `art/contact/dynamic-weather-{tiers,reduced,fade}.png`

## 5. Gates
- [x] 5.1 `flutter analyze`, `flutter test`, `npm run test:worker`, `npm run build`, `openspec validate dynamic-weather --strict`

## 6. Later (not in this change)
- [ ] 6.1 Music and SFX: rain bed and intensity layers on the `weather` events (blocked on tillandsias#1103 for assets)
