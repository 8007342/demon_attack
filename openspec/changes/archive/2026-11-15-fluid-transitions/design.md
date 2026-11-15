# Design: fluid transitions

## 1. Audit (before)
Phase lengths are the model's (`lib/game/model.dart`); `storyReadingTime` is 1/3 s.

| Phase | Length | What was on screen at once |
| --- | --- | --- |
| Wave change (wave > 1) | 1.73 s | `SWARM REINFORCEMENTS` card (title, wave pips, `WAVE x OF y`, `HOSTILE FORMATIONS INBOUND · STAY SHARP`); radio dock; on phones a full-size `transmissionJunior` (35 %) over everything |
| Salvage | 2 s | `RECOVERY WINDOW ACTIVE` card with seconds, instruction and progress bar; radio dock |
| Level clear | 4.33 s | Story card: `SECTOR SECURED`, sector name, storyboard, departure line ("X is secure…"), progress bar; radio dock with the level-clear exchange |
| Carrier victory | 5.83 s | Story card: carrier falling → recognition, medal, `♥ +1UP`, story line, progress bar |
| Travel | 4.33 s | Story card: `JUMP DRIVE ACTIVE`, destination, route storyboard with sector names, "Set course for…" briefing (tour escalation on a new route), progress bar, `DESTINATION LOCK %`; on phones the full-size `transmissionMission` briefing replaced it, on wide screens the side tiles spoke it |
| Arrival (wave 1) | 4.5 s | Tactical hint card (`TACTICAL BRIEFING`, `SECTOR x · WAVE 1`, hint art, title, detail, progress bar); the `sectorStart` line on the radio at the same time |
| Carrier arrival | 4.5 s | Two panels: warning banner at the top, objective dock with `INTERCEPT LOCK %` and progress bar at the bottom |

Noise: three progress bars for one sector change, two cards in a row with a hard cut between travel and arrival, the hint read while a voice talks, and the phone transmission covering the travel card. The loadout appears only on the storyboard ship (kept). Story clues for the ending live in battle chatter (comms), not in these cards; the campaign's own story beats are the sector-secured briefing and the tour escalation on a new route (kept).

## 2. The rule: one primary message
`TransitionPresenter.build` picks exactly one of: the interlude card, the story card, the carrier alert, or nothing. The progress strip is not a message: one 26 px line at the top of the arena.

| Phase | Primary | Strip |
| --- | --- | --- |
| Wave change | none | `WAVE 2/4 · REINFORCEMENTS` + wave pips (fades in and out) |
| Salvage | none | `RECOVERY WINDOW · COLLECT CARGO · 2s` |
| Level clear | story card (storyboard, next leg's briefing) | `SECTOR 2/5 CLEAR · ROUTE I` |
| Carrier victory | story card (medal, `+1UP`) | — |
| Travel | interlude card (story card on a new route) | `JUMP → <DESTINATION> · 64%` |
| Arrival | interlude card (continued) | `<SECTOR NAME> · WAVE 1/4` |
| Carrier arrival | one alert at the top (signature, target, objective, progress) | — |

On phones the radio dock hides while a card is up (the card is the radio), and sits below the strip otherwise. The phone-only full-size transmission overlay is gone: transmissions show in the radio card or the dock.

## 3. Interludes
`InterludePlanner` (`lib/game/interlude.dart`) is pure and seeded (`ArcadePage.interludeSeed` in tests; a fresh seed per run otherwise).

- **Window.** Travel leg + arrival (4.33 + 4.5 s) when both play; the travel leg alone into the carrier sector (its arrival keeps the alert); the arrival alone for the opening, a resumed run and the first sector of a new route (its travel keeps the tour-escalation story card). Windows under 3 s get no card.
- **Kind.** The opening is a tip; then tip and radio alternate strictly. If no radio line fits the window the slot falls back to a tip.
- **Tip item.** `HintDeck` (unchanged rules: shuffled rounds, sector-specific introductions). The detail sentence shows only when title + detail can be read in the window; a re-draw avoids the item just shown.
- **Radio item.** A seeded category draw weighted by the moment (briefing ×2 before the carrier; banter when struggling; jokes after a flawless sector), then a line from the bank:
  - briefing: `transmissionMission.<sector>`, `sectorStart.<sector>`, `transmissionMission`;
  - banter: non-joke `transmissionJunior`, `sectorStart`;
  - joke: signature or teasing lines of `transmissionJunior`, `sectorStart`, `broodTaunt` (human);
  - taunt: brood `broodTaunt`, `levelClear` (shown as glyphs with the SIGINT gloss).
  Human lines keep to this run's lineup, brood lines to the destination's officers; moods prefer excited/triumphant/teasing after a flawless sector and warm/calm when struggling. The last eight lines shown are excluded.
- **Reading time.** `readSeconds(text) = 1.2 s + words / 4` (about 240 words a minute). A tip must fit `window − fade`; a radio line's `max(clip + 0.8 s hold, readSeconds)` must fit `window − 2 fades − 1.2 s` (the wait for the squad channel).

### Radio card and the squad channel (no second voice)
The comms director already sends the next-mission briefing (`transmissionMission`) on every travel leg and a `sectorStart` line on arrival. The radio card therefore:
1. adopts a line the channel has on air (transmissions first, then human, then brood), holding it after the clip ends so it can be read;
2. otherwise, after 1.2 s with nothing on air or queued as a transmission, plays its own pick with `commsPlay` (speech on and audible only) and draws it from a local `CommsMessage` so the portrait lip-syncs;
3. never switches lines before the shown one ends.

### Silent tip
While a tip is up, the presenter calls `SquadComms.setVoice(false)` (only if the player's speech is on) and restores the player's setting when the window ends, the card is skipped, the run ends or a new run starts. On wide screens the call tiles dim to 35 % so silent subtitles do not compete.

## 4. Pacing and music
- Fades are one beat of the 120 BPM score (0.5 s), eased, driven by the transition clock (pause-safe, deterministic). The card fades in when its content is ready, so an adopted line never pops in at full opacity. No hard cuts: the travel and arrival halves of a window are one card.
- The music already enters travel and arrival on its own grid; the card never changes phase timing, so it cannot drift from the score. True beat sync would need the music clock from `demonAudio` (not exposed to Dart today).
- Skip (tap on the card or arena, Space, Enter) dismisses the card for the rest of the window and stops the card's own line. In an arrival it also starts the fight, as the opening briefing did; in travel the flow is unchanged.
- Reduced motion: no fades or slide, instant show/hide.

## 5. Files
- `lib/game/interlude.dart`: planner, categories, `readSeconds`, `radioPool`.
- `lib/widgets/interlude_card.dart`: `InterludeFrame`, `TipInterludeCard`, `RadioInterludeCard`, `TransitionStrip`.
- `lib/widgets/transition_overlay.dart`: `TransitionPresenter` (window, plan, radio adoption, silent tip, skip, story card, carrier alert, strip).
- `lib/main.dart`: the old `_interlude`, `_hintInterlude`, `_waveTransitionInterlude`, `_salvageInterlude`, `_bossArrivalInterlude` and `_commsTransmission` are gone; delimited `// --- fluid transitions` hooks call the presenter.

## 6. Hooks other owners could add
- Comms: a `CommsDirector.hush(until)` (hold flavour and briefing lines, keep must-play) would make the silent tip quiet without muting the whole voice bus, and a `CommsDirector.offer(line)` would let the radio card queue its own pick through the pacing instead of waiting for silence.
- Model: an arrival duration derived from the planned card (or a model-level `interludeWindow`) would let a long tip use the whole arrival without the 4.5 s fixed length.
- Audio: exposing the score's beat phase would let fades land exactly on the bar.
