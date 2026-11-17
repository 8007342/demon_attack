# Proposal: bonus challenges, a perfect run for a 1UP

## Why
The operator, verbatim: "the bonus levels are a great addition, but let's raise the ante, add a condition, and
display it with iconography, like "catch all the cargo for 1UP", or "dodge all lightning for 1UP", let's use radio
comms and in-game idioms to convey these messages."

What the game had (`game` at ea0a00b3): each bonus level has a goal and a how-to line on its urgent-mission card
(bonus-briefing-clarity), one radio line, a clear award and a flawless share of the sector's par. Nothing asks for a
perfect run, and nothing on screen says what a perfect run would be.

## What Changes
- **A generic challenge.** `BonusLevelDef.challenge` (a `BonusChallengeDef`) declares one perfect-run condition as
  data: the notes that fail it at once, the notes it needs by the clear, its pictogram and its 1UP. Any level adds one
  in a few lines; a mechanic reports its own notes with `model.challengeNote(name)` (design §API).
- **The two shipped levels:**
  - Supply Run, CATCH ALL CARGO: no crate may pass the ship unopened and no prize may fall past it uncaught.
  - Stormfront, DODGE EVERY BOLT: no lightning bolt may touch the ship (a shield knocked off counts; a bolt the
    lightning rod grounds does not).
- **Live state in the model**, pure Dart and deterministic: live (in progress, still possible), failed, earned. The HUD
  and the radio read it.
- **Iconography:** a medal-style badge (gold rim, dark socket, the condition's pictogram) beside an arcade 1UP plate.
  It sits on the urgent-mission card with the condition in words, and as a small pip beside the lives during the
  level. It breaks (red slash, grey, struck-through 1UP, a short shake) the moment the condition fails, and bursts
  (rays, a ring, sparks) when the 1UP is earned. Drawn with painters (design §3).
- **Radio:** the card's one line becomes the level's challenge call (`bonusChallenge.<level>`, one sentence); a quip
  when it fails (`bonusChallengeFailed.<level>`, with an optional brood taunt); a 1UP cheer when it is earned
  (`bonusChallengeEarned` and per-level variants, with an optional brood retort). Written lines (`"pending": "text"`)
  until tillandsias#1103.
- **Reward:** one life through the extra-life path at the level's last kill (the extra-life fanfare, no heart card),
  once per visit. The run record shows the perfect-run medal (`<level>OneUp`: the level's medal with a 1UP plate),
  and the checkpoint keeps it.

## Impact
- Code: new `lib/game/bonus/bonus_challenge.dart` (pure Dart) and `lib/game/bonus/challenge_badge.dart` (painters);
  `bonus_types.dart`, `bonus_catalog.dart`, `levels/{supply_run,supply_run_cues,stormfront}.dart`; hooks in
  `model_bonus.dart`, `model.dart` (`hitPlayer`, checkpoint), `game_events.dart` (two names), `main.dart` (HUD pip,
  1UP sound), `comms_briefing.dart`, `comms_briefing_view.dart`, `comms_view.dart` (one import),
  `widgets/mission_medal.dart`.
- Radio: `art/comms/lines.json` (seven triggers appended), regenerated `lib/comms/comms_bank.dart` and
  `plan/audio-studio/voice-batch-pending.md`. Borrowed-line count unchanged (55).
- Balance: the calibrated campaign runs without a run seed and has no bonus level, so the §7 gates are untouched.
  A real run gains at most one life (one bonus level per run); measured earn rates and the lives budget are in
  design §5 and `plan/calibration-current.md`.
- Capability: new `bonus-challenges`.
