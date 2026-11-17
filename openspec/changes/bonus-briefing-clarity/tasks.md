# Tasks: bonus-briefing-clarity

## 1. Instructions
- [x] 1.1 Diagnose why radio closed the card (design §1)
- [x] 1.2 `BonusLevelDef.how`; goal and how-to lines for Supply Run and Stormfront, checked against the rules (design §2)
- [x] 1.3 The card draws the goal in bold, the how-to line under it, and `StormfrontHowTo` beside Supply Run's pictogram

## 2. The card's life
- [x] 2.1 The card opens at the slot whatever the channel does; `read(now)` is time only; `minRead` 4 s, `maxRead` 8 s
- [x] 2.2 Close only on dismiss, 1.2 s of combat, or transition over and read; the radio never closes it
- [x] 2.3 The slot asks for the longer of the line and the reading time; the hold covers the rest

## 3. Radio
- [x] 3.1 Append `bonusCall.supplyRun` and `bonusCall.stormfront` (one line each, `"pending": "text"`) to `art/comms/lines.json`; regenerate with `python3 -I tools/comms_pipeline.py dart`
- [x] 3.2 The card speaks exactly that one line; the hush keeps the rest of the squad quiet while it is up

## 4. Tests and gates
- [x] 4.1 `test/bonus_briefing_test.dart`: instructions, one line per level, reading time, the briefing survives incoming radio
- [x] 4.2 `test/bonus_briefing_card_test.dart`: goal, how-to and pictogram on the page; radio neither closes nor covers the card
- [x] 4.3 Borrowed-line count in `test/comms_director_test.dart` checked (unchanged, 55)
- [x] 4.4 `flutter analyze`, the full suite through the lock, `npm run test:worker`, `npm run build`, `openspec validate bonus-briefing-clarity --strict`
- [ ] 4.5 Operator playtest on a phone: the briefing reads, and the radio line keeps the flow
