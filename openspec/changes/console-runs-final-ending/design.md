# Design: the ending after the fifth carrier, unranked /console runs

## 1. Root cause of the early ending
Every route ends in sector 5, the carrier, so a carrier falls five times per campaign (routes 0–4, `ArcadeModel.cycle`). `ArcadePage._tick` scheduled `_showEnding()` whenever `mode == RunMode.victory && transitionProgress >= .72`, with no route test, and `_endingShown` was only reset per run. The first carrier (route 0) therefore opened the ending; the run then continued to route 1 behind it. On resume, `_endingShown = cycle > 0` hid the ending for every later route, including the real one.

## 2. The gate
- `ArcadeModel.finalRoute = 4` and `bool get finalBoss => level == 5 && cycle >= finalRoute`.
- `_tick` schedules the ending only when `finalBoss` holds, and re-checks it in the post-frame callback. The `victory` precache of `beach-ending.webp` uses the same test.
- `update` moves `victory → completed` on `finalBoss` (same as the old `cycle >= 4`, since victories only happen in sector 5).
- `_resumeGame` sets `_endingShown = false`.
- `RunHistory.everFinished` (JSON `everFinished`, absent → false) is set by a ranked `bossDefeated` when `finalBoss`; it gates the title's replay button.

| Carrier | Route index | Ending | After the victory |
| --- | ---: | --- | --- |
| 1–4 | 0–3 | no | travel → sector 1 of the next route |
| 5 | 4 | yes, at 72 % of the victory scene | completed → result / top-10 entry |

## 3. Console runs
- `ArcadeModel.startAt(..., console: true)` sets `lives = 1` and `ranked = false` after the normal fresh start. `start()` and `restoreCheckpoint()` set `ranked = true`. `ConsoleStart.applyTo` always passes `console: true`.
- `ArcadePage`:
  - `checkpoint` events are not saved while `!model.ranked`; `bossDefeated` records no history.
  - `_finishRun` for an unranked run builds the `ScoreEntry` for display, sets `finalRanked = false`, shows it beside the (reloaded, GET-only) board and returns to the title. It never sets `screen = 'entry'`, never clears the stored checkpoint and never records a failure.
  - `_submit` returns at once for an unranked run (defence in depth).
  - HUD: a `CONSOLE RUN · NOT RANKED` tag (`hud-unranked`) under the playing time. Result: the same tag (`result-unranked`) under `YOUR FINAL SCORE`.
- The console runs can still play the ending: a console start on route 5's carrier is the quickest way to review it.

## 4. Reference: kumbia-kombat `/console`
Its console (`lib/console/`, `lib/review_links.dart`) starts review runs from one place that names every option, labels each item with a stable reference, and keeps review links apart from the game's own flow. Matched here: the console states its rules on the page, `ConsoleStart.label` names the start, and the link row is the place for the review pages (gallery now, the asset viewer / notes page next).
