# Tasks: mission-medals

## 1. Supply Run clarity
- [x] 1.1 Diagnose the mechanic and why it read as it did (design §1)
- [x] 1.2 One-sentence brief and the card's pictogram (`BonusBriefingCard.howTo`)
- [x] 1.3 The card holds the start until read or tapped, at most 15 s; TAP TO START (`BonusBriefing.holds`, `DemonScene.holdModel`)
- [x] 1.4 Cue tracker `SupplyRunCues` (no PRNG, no award) and `SupplyRunPainter` (brackets, cracks, landing markers, magnet, coins, pops, catches, tally)
- [x] 1.5 `crateOpen` raw event and sound for bonus crates (carrier crates keep `salvage`)
- [x] 1.6 Radio: in-level Supply Run triggers as written lines, new lines, `bonusCrateMissed.supplyRun`; regenerate the bank; borrowed count 64 → 55
- [x] 1.7 Stormfront checked (design §5); it gains the hold only
- [x] 1.8 Tests: `test/mission_medals_test.dart`, `test/bonus_briefing_card_test.dart` (hold), `test/run_record_test.dart`; bonus-balance gate unchanged
- [ ] 1.9 Follow-up for the operator: Stormfront's in-level lines borrow loosely fitting subtitles; make them written lines too?

## 2. Mission medals
- [x] 2.1 `MissionMedal` / `MissionMedals` widgets composing atlas layers, fallback, label and tap tooltip
- [x] 2.2 Run record card and scoreboard rows show medals, never modifier text
- [x] 2.3 Medal family, hero renders, picks, atlas and generated Dart through rigkit + ComfyUI + rigsheet (`plan/render-runs/mission-medals.md`)
- [x] 2.4 Commit the picked raws and the recipe

## 3. Sheets and gates
- [x] 3.1 `art/contact/mission-medals-supply-run.png`, `mission-medals-screens.png`, `mission-medals-variants.png`, reviewed
- [ ] 3.2 `flutter analyze`, the full suite through the lock, `npm run test:worker`, `npm run build`, `openspec validate mission-medals --strict`
