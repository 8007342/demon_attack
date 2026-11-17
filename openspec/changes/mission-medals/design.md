# Design: clear bonus missions and mission medals

Operator feedback round 3b, B2 (`plan/operator-feedback-2026-11-16.md`). Base: `game` at 7c1da7d1.

## 1. Why Supply Run did not read

Supply Run's rule in code (`lib/game/bonus/levels/supply_run.dart`, `lib/game/model_bonus.dart`): the sector's own
waves; kills drop nothing; a parachute crate every 3.5 s (at most three in the air) takes three hits and drops one
pickup: a regular power, or with 30 % a bonus power (`salvageMagnet`: pickups within 150 units fly to the ship for
12 s; `doubleScore`: kill and crate points ×2 for 9 s). Kills pay 60 %; crates, the clear and a flawless run pay the
rest up to a cap.

What the player saw:

| Moment | What it showed | Why it failed |
|---|---|---|
| Briefing | "Crack the falling crates: three hits each. Kills drop nothing; the cargo drops everything." | Two clauses; the card closed with the flight or 1.2 s into combat, often before its chatter was read |
| In-level radio | `bonusStart.supplyRun` "Crates on parachutes. Three hits opens one." | Borrowed clip `salvage.h2` **with its own subtitle**: heard and shown as "Salvage drifting. Collect what you can." |
| A crate hit | a white flash | No progress between hits (ux-declutter removed the pips) |
| A crate opened | the wave-clear jingle; maybe "Wave's clear. Sweep up the salvage." | It emitted the raw `salvage` event (the wave-clear sound and radio) |
| Magnet collected | badge beside the ship; "New toy! Try it out." | The badge is the shield's U recoloured; nothing drew the pull; the line was a borrowed subtitle |
| Double score | gold badge beside the ship; "Good pickup. Make it count." | No visible effect at all |

"Was that like a magnet?" (it was, and nothing said so) and "some powerups were different but they were just
holding" (two badges riding in timer rings beside the ship, with no visible effect) follow from the last two rows.

## 2. The card holds the start

`BonusBriefing.holds` (pure Dart, `lib/comms/comms_briefing.dart`): while the card is open and unread, and the
transition's flight has at most `holdLead` (0.25 s) left, the presentation layer does not step the model
(`DemonScene.holdModel`, wired in `main.dart` to `TransitionPresenter.briefingHolds`). The fog, the card and the
radio keep running on their own clocks. **Read** = the brief (plus the run rule) has been up for
`1.5 + chars / 15` s, clamped to 3-7 s, and every scripted turn has ended or expired. A tap, Space or Enter
dismisses the card and releases the hold; `maxHold` (15 s, summed over the visit) bounds it if the channel stalls.
While holding, the card shows TAP TO START (pulsing; steady with reduced motion).

Why hold rather than keep the card up into combat: the card sits at the top of the arena, where the swarm comes out
of the cloud; holding at the Descent's end costs the player nothing (nothing fires yet) and reads like an arcade
mission intro. Why in the presentation layer: the model stays deterministic and every calibration tool, which steps
the model directly, is unchanged. Test rigs that step the model directly ignore the hold unless asked
(`Rig.step(hold: true)`).

The brief is one sentence ("Shoot the falling crates open and catch the cargo.", 50 characters). Under it, for a
level that registers one (`BonusBriefingCard.howTo`), a 26-px pictogram strip shows the rule: a bracketed crate on
its parachute, three shots, the crate bursting, the cargo on its dotted line, the ship on its marker. It is drawn
in the colours of the in-level cues, so the card teaches what the level shows.

## 3. Cues on the objects and feedback

`SupplyRunCues` (`levels/supply_run_cues.dart`) is a `BonusMechanic` that adds no rule: it watches crates and
pickups (identity sets, no PRNG, no award) and records pops (a crate removed while destroyed), catches (a pickup
gone within 34 units of the ship), the tally, and queues `bonusCrateMissed` when a crate falls past the ship row
unopened in combat. `SupplyRunPainter` (`levels/supply_run_painter.dart`, registered in `BonusPainters.byLevel`)
draws over the fight:

- unhit crate: gold corner brackets pulsing (the target); after hit *n*, *n* fixed crack paths with a gold seam;
- falling cargo: a dotted drop line and an oval marker with a chevron on the ship row under it;
- `salvageMagnet`: a dashed arc of the 150-unit reach over the ship and three beads running along each pull;
- `doubleScore`: two gold coins orbiting the ship;
- pop: an expanding ring (gold; coral for a bonus crate) with a white flash; catch: a mint (gold for bonus) ring;
- tally: a small crate glyph and one gold pip per crate opened at the arena's top left (10 per row).

Reduced motion: no pulse, no orbit, the beads stand still; every mark stays. No text over the play area.

Sound: a bonus crate now emits the raw `crateOpen` (a wooden pop and a rising three-note chime in
`web/audio/demon-audio.js`); outside bonus levels (the carrier's crates) it stays `salvage`.

The mechanic itself is unchanged (three hits; the same crates, powers and scoring). Simplifying it was considered
(two hits, no bonus powers) and rejected: the confusion came from missing feedback, not from the rule, and the
balance gate's numbers stay exactly as they were.

## 4. Radio

- `bonusStart.supplyRun`, `bonusCrate.supplyRun`, `bonusPickup.salvageMagnet`, `bonusPickup.doubleScore` become
  written lines (`"pending": "text"`): their own words, no audio, until tillandsias#1103 records them. Nine borrowed
  lines fewer (`test/comms_director_test.dart`: 64 → 55).
- New lines (appended, never reordered): two start calls ("Gold brackets mark the crates. Crack one, then slide
  under it."), three crate calls, and the new trigger `bonusCrateMissed.supplyRun` (four squad teases, two brood
  claims). Story hooks in the `plan/story-hooks.md` vein: Sunny's "Tell me it's snacks this time.", Nomad's "Catch it
  before it hits the sand.", Rook's "That crate's going to the fish.", Nibb's "Does it have the crunchy ones?".
- `bonusCrate.supplyRun` speaks with chance 0.75 (was 0.4), still in the `loot` family's rate limit.

## 5. Stormfront

Checked against the same list: its brief names the goal and the tell ("Lure the lightning onto the swarm. When the
air hums over you, slide out."), the tell is an amber column with a rising static sound, the bolt hits both sides.
It gains the card's hold (framework) and nothing else. Its in-level lines still borrow clips with loosely fitting
subtitles ("Attack run. Watch your flanks."); left as is because the operator loved its feel and its voiced lines
are part of it. Listed in tasks as a follow-up for the operator to decide.

## 6. Mission medals in the UI

- `lib/widgets/mission_medal.dart`: `MissionMedal(id, size)` composes the atlas cells
  `ribbon.<id>` (else `ribbon.generic`), `base`, `accent.<id>` (optional), `emblem.<id>` (else `emblem.generic`),
  each a whole aligned cell, drawn with `drawImageRect` into the widget's box (height `size`, width by the cell
  aspect). The atlas is decoded once (`MissionMedalSheet`); until then a vector fallback in the mission's ribbon
  colours keeps the footprint. Label: `<NAME> mission medal`; tooltip on tap: the name (`runTagLabel`).
- `RunRecordCard`: the chips' `Wrap` becomes a `Wrap` of 34-px medals (key `run-record-modifiers` kept).
  "STANDARD RUN" stays for a run without missions.
- Scoreboard rows (`main.dart`, `_scoreRowLine`): the record's medals stand beside its regular medals (16 px
  compact, 20 px otherwise); the note line under the row keeps only the date.

## 7. Medal art

Through the shared pipeline (rigkit family → ComfyUI hero → rigsheet finish and atlas), as `flight-joystick` did.
The run, its picks and their reasons, the GPU time and the rebuild command are in `plan/render-runs/mission-medals.md`.

## 8. Contact sheets

- `art/contact/mission-medals-variants.png`: every variant, composed and as layers, large and at 20 / 36 px.
- `art/contact/mission-medals-screens.png`: the medal screen and the board, 360 wide.
- `art/contact/mission-medals-supply-run.png`: the card in flight, the card holding, the cues, the feedback.
