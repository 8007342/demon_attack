# Tasks

- [x] Measure the comms-pacing baseline in the seeded simulation (busy and calm, seeds 4 / 11 / 23)
- [x] Retune the pacing to the middle (duty, burst, rests, jitter) and scale it by the music intensity tier
- [x] Remove every cut: grace gap after each line, urgent warnings wait, regroup chorus overlaps only itself
- [x] Lookahead: queued timed calls and exchange answers, the observer's `groundFireForecast` reserve, and the shortest-variant fallback with `lateWarnings` / `lateDiveCalls` counts
- [x] Readable holds: reading time per character, opening kept until the answer is read, dock placed oldest first with an overflow ticker
- [x] Voice the moments from existing clips: wave start, reinforcements (one call per arrival), escorts, carrier phases and hatch, `incoming`, level clear, salvage
- [x] Pending new lines in `art/comms/pending-lines-2026-11-14.json` (not used at runtime)
- [x] Ground-truth gates: `groundPicture`, `CommsGroundPicture`, audited line and trigger gates
- [x] Transition hooks `hush` / `hushFor` and `offer`
- [x] Tests: pacing sim and targets, director, middle-ground (holds, dock, gates, moments, hooks, observer)
- [ ] Switch `lib/widgets/transition_overlay.dart` to `hush` and `offer` (owned by the transitions work)
- [ ] Listen in the browser: middle-level chatter, no cuts, warnings on time, readable cards on a phone
- [ ] Record the pending lines with the 48 kHz voice model and map them in place of the reused clips
