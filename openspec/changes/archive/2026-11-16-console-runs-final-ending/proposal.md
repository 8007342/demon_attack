# Proposal: the ending after the fifth carrier, unranked /console runs

## Why
- The beach ending and credits opened after the **first** carrier fell. They are the campaign's closing credits and belong to the fifth and last carrier (sector 5 of route 5).
- `/console` runs started with the difficulty's lives and followed the normal top-10 rules. A run that skips straight to late sectors or a carrier is a review tool, not a fair score, so it must not reach the board.

## What Changes
- **Ending gate.** `ArcadeModel.finalBoss` (sector 5 and route index 4) is the single test for "the campaign's last carrier". The beach ending is scheduled only in that victory. The four earlier carriers keep their normal victory → travel flow into the next route. The victory → completed step uses the same test.
- Resuming a saved run no longer marks the ending as already shown on later routes (`_endingShown = cycle > 0` was the old guess). Checkpoints sit at wave entrances, so a resumed fifth carrier still earns its ending.
- The title's "replay beach ending" button appears once the fifth carrier has fallen (new `RunHistory.everFinished`), not after any boss.
- **Console runs.** A console start (any sector 1–5, the carrier included, any route 1–5, any difficulty) begins with exactly 1 life and 0 points and is **not ranked** (`ArcadeModel.ranked == false`):
  - no initials entry, no `/api/scores` POST; the result is shown beside the board, tagged;
  - the HUD and the result carry a small `CONSOLE RUN · NOT RANKED` tag;
  - the player's own saved checkpoint and unlock history are neither written nor cleared.
  - A normal start or a resumed save is ranked again.
- The console page states the rules: `1 LIFE · 0 POINTS · NOT RANKED`. Its link row (the art gallery) leaves room for the asset viewer / notes link another change adds.

## Capabilities
### Modified Capabilities
- `arcade-progression`: the final-carrier ending gate; console runs start with one life (supersedes the "starting lives, normal top-10 rules" clause of the `gameplay-round-3` console start).
- `high-scores`: console runs never submit to or prompt for the board.

## Impact
`lib/game/model.dart`, `lib/main.dart`, `lib/widgets/dev_console.dart`, `lib/services/run_storage.dart`; tests `test/ending_progression_test.dart`, `test/console_run_test.dart`. No worker or score-schema change: the server never sees a console run.
