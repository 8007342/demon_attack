# Tasks

## 1. The short level
- [x] 1.1 Measure every bonus level against its sector (`test/support/bonus_balance.dart`); root cause in design §1
- [x] 1.2 `BonusWaves.count` null (the sector's), sentinels and elites on by default

## 2. Balance
- [x] 2.1 `sectorPar` counts reinforcements, sentinels and escorts; `regularSentinelWave`; `bonusCap`
- [x] 2.2 Retune Supply Run and Stormfront (design §3, §4)
- [x] 2.3 `test/bonus_balance_test.dart`: the gate (design §2)
- [x] 2.4 Numbers in `plan/calibration-current.md`, "Bonus balance"

## 3. The run record
- [x] 3.1 `runModifierIds`; `RunModifierDef.label`; `runTagLabel`
- [x] 3.2 Worker: `modifiers`, `playedOn`, migration by default columns; worker tests
- [x] 3.3 `ScoreEntry` / `ScoreService` fields; `playDate`
- [x] 3.4 `RunRecordCard` on the final result and the score entry; board rows' date-and-modifiers line
- [x] 3.5 `test/run_record_test.dart`

## 4. Review
- [x] 4.1 Contact sheets `art/contact/bonus-balance-*.png` (`--dart-define=BONUS_BALANCE_CONTACT=true`)
