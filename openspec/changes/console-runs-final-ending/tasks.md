# Tasks

## 1. Ending gate
- [x] 1.1 `ArcadeModel.finalBoss` / `finalRoute`; `victory → completed` uses it
- [x] 1.2 `ArcadePage._tick` schedules the ending only for the final carrier; precache likewise
- [x] 1.3 Resume no longer guesses `_endingShown` from the route
- [x] 1.4 `RunHistory.everFinished` gates the replay button
- [x] 1.5 Tests: no ending after carriers 1–4 (they travel on), the ending after carrier 5 (`test/ending_progression_test.dart`)

## 2. Console runs
- [x] 2.1 `startAt(console: true)`: 1 life, 0 points, `ranked = false`; `start`/`restoreCheckpoint` rank again
- [x] 2.2 No checkpoint save, no history, no initials entry, no POST for an unranked run
- [x] 2.3 `CONSOLE RUN · NOT RANKED` tag in the HUD and on the result
- [x] 2.4 Console page copy; room in the link row for the asset viewer / notes link
- [x] 2.5 Tests: every sector/route/difficulty, boss and sentinel jumps, no POST, storage untouched (`test/console_run_test.dart`)

## 3. Docs
- [x] 3.1 This change; the `gameplay-round-3` console start points here
