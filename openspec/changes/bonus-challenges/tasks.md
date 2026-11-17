# Tasks: bonus-challenges

## 1. Framework (pushed early for `crosswind`)
- [x] 1.1 `BonusChallengeDef`, `ChallengeNotes`, `ChallengeStatus`, `BonusChallenge` in `lib/game/bonus/bonus_challenge.dart` (pure Dart); `BonusLevelDef.challenge`
- [x] 1.2 Model hooks: one challenge per visit, `challengeNote`, `shipHit`/`shipLost` from `hitPlayer`, settle at the last kill, the 1UP through the extra-life increment, `bonusOneUp` sound, failure and earned events
- [x] 1.3 Supply Run (CATCH ALL CARGO) and Stormfront (DODGE EVERY BOLT) declare and report their conditions
- [x] 1.4 design.md §API

## 2. Iconography
- [x] 2.1 `ChallengeBadgePainter`: medal disc, pictogram, arcade 1UP plate; live, failed (slash, shake, flash), earned (burst); reduced motion
- [x] 2.2 The badge on the urgent-mission card with its label; the HUD pip beside the lives
- [x] 2.3 The perfect-run medal (`<level>OneUp`) on the run record; the checkpoint keeps the won 1UPs

## 3. Radio
- [x] 3.1 Append `bonusChallenge.<level>`, `bonusChallengeFailed.<level>`, `bonusChallengeEarned(.<level>)` to `art/comms/lines.json`; regenerate with `python3 -I tools/comms_pipeline.py dart`
- [x] 3.2 The card speaks the challenge call as its one line

## 4. Balance
- [x] 4.1 Earn rates with the Average and Challenger pilots (`test/support/challenge_pilot.dart`); record them and the lives budget in `plan/calibration-current.md`
- [x] 4.2 §7 calibration gates unchanged (they run without a run seed)

## 5. Tests and gates
- [x] 5.1 `test/bonus_challenges_test.dart`: per-level tracking, immediate failure, the 1UP once, checkpoint and record, badge states, one call per level
- [x] 5.2 `test/bonus_challenges_rate_test.dart`: winnable by a pilot trying, rare by default
- [x] 5.3 `test/bonus_briefing_test.dart`: the card's one line is the challenge call
- [ ] 5.4 All §2 gates
- [ ] 5.5 Operator playtest: the badge reads at a glance on a phone, the quip and the cheer land
