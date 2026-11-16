# Proposal: bonus balance and the run record (B1)

## Why
From the operator's third playtest on 2026-11-16 (`plan/operator-feedback-2026-11-16.md`, B1):
- "Bonus levels last about as long as regular levels and are about as hard: sometimes a little easier, sometimes a
  little harder." The operator played one that lasted about 3 seconds; that is a bug.
- "Enemy count and possible score points stay about the same as the regular level they replace."
- "When you play you get what you get": balance the levels instead of adding a scoreboard rule.
- "The end-of-run medal screen shows the number of medals, the run's modifiers, the play date, the play time and the
  score. The scoreboard records the modifiers."

What the game has (bonus-levels, in `game` at 1c670982):
- Both bonus levels play **two** waves (`BonusWaves.count = 2`) instead of the sector's 3-7; Supply Run plays them at
  60 % of the roster (at least 3 creatures) with half the reinforcements and the two lightest species; Stormfront at
  85 % with half the reinforcements; neither has sentinels or elites. Measured with the protected calibration pilot,
  a bonus level lasted 9-25 combat seconds where its sector lasts 25-119, with 10-32 kills against 27-187. On Easy,
  route 0, sector 2 a Supply Run is two waves of three to five drones and no reinforcements: a player who carries
  powers from sector 1 clears it in about three seconds.
- Awards were shares of a "par" that counted only the opening rosters, so a bonus level paid +45-60 % more than its
  sector at route 1, and about the same at route 0.
- The scoreboard stores initials, score, difficulty, medals, play time and finisher lives; it has no run modifiers
  and no date. The end-of-run screen shows the score row (initials, medals, time, score).

## What Changes
- **Bonus waves default to the sector's.** `BonusWaves.count` is null by default: the replaced sector's own number of
  waves. Sentinels and elites default on. A level changes the sector only where its twist needs it.
- **Par counts the whole sector**: opening rosters, finite reinforcement groups, and on a sentinel wave the sentinel
  and its escort, at face value.
- **Retuned levels.** Supply Run: the sector's waves; kills pay 60 %; crates every 3.5 s (at most three in the air,
  no total); clear 0.25, flawless 0.1, cap 0.45 of par. Stormfront: the sector's waves at 115 % of the opening
  roster; kills pay 70 %; the storm strikes less often on Normal and Hard and a tenth less often per route; clear 0.15,
  flawless 0.1, cap 0.3 of par.
- **A balance gate** (`test/bonus_balance_test.dart`) measures every catalogue level against its sector with the
  calibration pilots and holds duration, enemy count, possible score and difficulty within ±15 % pooled (±20 % per
  difficulty, difficulty pooled only), and no cell under 60 % of its sector's duration.
- **The run record.** The model names a run's modifiers (`runModifierIds`: the bonus levels reached, then the run
  rule). The scoreboard stores them and the play date; records saved before have none and load unchanged. The
  end-of-run medal screen shows a compact run record card; board rows carry a small date-and-modifiers line.

## Impact
- Code: `lib/game/bonus/` (types, catalogue labels, both levels, storm tuning), `lib/game/model_bonus.dart`
  (`sectorPar`, `bonusCap`, `regularSentinelWave`, `runModifierIds`), `lib/services/scores.dart`,
  `lib/widgets/run_record.dart`, `lib/main.dart` (finish, submit, final result, entry, board rows),
  `worker/index.mjs` (columns `modifiers`, `playedOn`).
- Tests: `test/bonus_balance_test.dart` with `test/support/bonus_balance.dart`, `test/run_record_test.dart`,
  `test-worker/scores.test.mjs`; updated bonus level tests.
- Unseeded runs (every page test, every calibration tool) are unchanged: no plan, no bonus level.
- Plan: `plan/calibration-current.md` "Bonus balance".
