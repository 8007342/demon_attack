# Tasks: spear-bearers

## 1. The rule (model, pure Dart)
- [x] 1.1 `lib/game/spear_bearers.dart`: `SpearTuning`, `SpearKit`, `SpearRun`, `FallenBuckler`, `spearBearerScheduled`, `_spearFor`, `_spearUp`, `_spearStep`, `_throwSpear`, `_spearIgnite`, `_bucklerHit`, `_spearFrame`
- [x] 1.2 Hooks in `model.dart` (`// --- spear-bearers`): `ShotKind.spear`, `Demon.spear`, `spearRun`, the birth flag in `_ordinaryProfile` and the three birth sites, `_igniteDiveShield`, the step, no triple spread, the buckler in `hitDemon`
- [x] 1.3 Structured event `spearThrow`; raw sounds `spearGlint`, `spearRelease`, `bucklerClang`, `bucklerOff` (`web/audio/demon-audio.js`)

## 2. Sprites
- [x] 2.1 `tools/spear_bearers` (Go): gear geometry, atlas, generated Dart, contact and candidate sheets, `check`, `go test`
- [x] 2.2 Picks logged (`plan/render-runs/spear-bearers.md`); style guide §5.6; CLAUDE.md §4 row
- [x] 2.3 `lib/game/spear_bearer_painter.dart` and scene hooks (gear after the elite armour; spears and fallen bucklers after the shots); the shot layer skips spears

## 3. Parallel hooks
- [x] 3.1 insignia-ranks: `SpearBearerPainter.rankOf` (hunter) and its test; branch not pushed when this landed
- [x] 3.2 fang-and-wings-comms: `spearThrow` emitted on release; branch not pushed when this landed
- [ ] 3.3 When `work/insignia-ranks` lands: merge it, keep the bearer on the hunter's mark
- [ ] 3.4 When `work/fang-and-wings-comms` lands: merge it, voice a throw shout on `spearThrow` with its API and line ids

## 4. Gallery
- [x] 4.1 `spear-bearers` scene page: states on the four species, one dive in a loop

## 5. Balance
- [x] 5.1 `tools/ordinary_wave_probe.dart`: `routes=`, `spears=off`, bearer, throw and spear-life counts
- [x] 5.2 Probe before/after, defence budgets, campaign playtest; numbers in `plan/calibration-current.md`

## 6. Tests and gates
- [x] 6.1 `test/spear_bearers_test.dart`: schedule, mid-dive throw and its lead, withheld and re-armed, no spread, wind, lightning, buckler, painter (images disposed, loops bounded)
- [x] 6.2 `flutter analyze`, the suite through the lock, `npm run test:worker`, `npm run build`, `openspec validate spear-bearers --strict`
