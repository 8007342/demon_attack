# Tasks: lightning-rework

## 1. The rule (model, pure Dart)
- [x] 1.1 `lib/game/lightning.dart`: `LightningTuning`, `strikeLightning`, `zapShip`, `dodgeLightning`, `_lightningStep`, `_stunnedDemon`, rank, roll, rod rule
- [x] 1.2 Hooks in `model.dart` (`// --- lightning-rework`): Demon fields, model state, the stun step, shooter and diver filters, charge rate, the dodge in the formation target, stunned hits and kills
- [x] 1.3 Events `lightningStun`, `lightningShipHit`, `lightningCharged`; raw sounds `stormStun`, `shipZapped`, `demonCharged`

## 2. Stormfront
- [x] 2.1 Mechanic: stun instead of kill, zap instead of a hit, bait paid on stunned kills, the rod from the first baited kill, rod armour fitted, dodges fed
- [x] 2.2 `StormStrike.stunned/charged`; `StormTuning.damage` removed; rosters × 1.0
- [x] 2.3 Briefing goal and how-to, five-step pictogram, `bonusCall.stormfront` reworded

## 3. Presentation
- [x] 3.1 `lib/game/weather/lightning_painter.dart`: tumble, stun sparks, rods, charge, ship static and zap; scene hooks
- [x] 3.2 Rod candidates on the real scene, pick logged (`plan/render-runs/lightning-rework.md`, `art/contact/lightning-rework-rods.png`)
- [x] 3.3 Storm strip review sheet (`art/contact/lightning-rework-storm.png`)
- [x] 3.4 Sounds in `web/audio/demon-audio.js`

## 4. Radio
- [x] 4.1 Seven triggers appended to `art/comms/lines.json`; `python3 -I tools/comms_pipeline.py dart`; borrowed count unchanged (55)
- [x] 4.2 `lightningShipHit` is a comms moment (useful, never dropped as flavour)

## 5. Balance
- [x] 5.1 Bonus balance before/after, tuning, numbers in `plan/calibration-current.md`
- [x] 5.2 Campaign calibration unchanged (difficulty analysis before/after)

## 6. Tests and gates
- [x] 6.1 `test/lightning_rework_test.dart`: stun bounds, defenceless, points, zap, grace, protection, rank monotonic, rods, radio moments and rate limits
- [x] 6.2 `test/bonus_stormfront_test.dart` for the new rule
- [x] 6.3 `flutter analyze`, the suite through the lock, `npm run test:worker`, `npm run build`, `openspec validate lightning-rework --strict`
- [ ] 6.4 Operator playtest: the stun reads, the zap is fair, the rods read at sprite size
