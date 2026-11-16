# Tasks

## 1. Diving shields
- [x] 1.1 Replace the column-built bows with `_thermalBow` (one crescent, shared bands, notches, ember sockets, tip embers, heading turn) for small, medium and sentinel dive shields
- [x] 1.2 Draw the rush's crimson bow with the same function; it condenses through the rally and lock
- [x] 1.3 Before / after sheet `art/contact/playtest-fixes-3-shields-{before,after}.png` (five scales, three tiers, a worn shield, sentinels)

## 2. Sentinel rush
- [x] 2.1 Invulnerable in the transformation (rally, lock): `berserkTransforming`, `Deflect` records, no hit flash
- [x] 2.2 Rush shield as the super diving shield: bare gun deflects; powers and homing break it
- [x] 2.3 Deflect sparks in the scene
- [x] 2.4 Tuning: rush chance 0.28 / 0.45 / 0.55, rush shield 6 / 8 + c÷2 / 10 + c÷2, dodge 300, break 150, burn-out pays the kill value
- [x] 2.5 Calibration harness re-run and recorded in `plan/calibration-current.md`

## 3. Sentinel shadow
- [x] 3.1 In-play sentinel shadow altitude (it was 0: no shadow)
- [x] 3.2 One size rule for lurk, rise, fight and rush; every sentinel shadow drawn as the occluder; one-shape hand-off
- [x] 3.3 Rush sequence sheet with the shadow pass `art/contact/playtest-fixes-3-rush.png`

## 4. Band above the arena
- [x] 4.1 `paintArena` headroom; background clip to the viewport's top, gameplay clip to the arena
- [x] 4.2 Sky bake with headroom, parallax particulates over the band, high fog `paintBand`, cloud cover and pitch bands
- [x] 4.3 Sheets at 360 × 640, 390 × 844, 1280 × 720, 1920 × 1080

## 5. Ascent
- [x] 5.1 No bank, pitch from the climb, deep-sky band, flock climbs ahead (rout mostly up)
- [x] 5.2 Update `transition_ascent_review_test` expectations; fly-up strip `art/contact/playtest-fixes-3-ascent.png`

## 6. Gates
- [x] 6.1 `flutter analyze`, `flutter test`, `npm run test:worker`, `openspec validate playtest-fixes-3 --strict`
