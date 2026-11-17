# Proposal: bonus briefings a first-time player can read (B3)

## Why
The operator, round 6 (`plan/operator-feedback-2026-11-17.md`, B3), verbatim: "The instructions for the Bonus Levels
are still unclear, and the overlapping of the radio chatter closed the box before I was able to read it :) please
make sure instructions are clear, and accompany them with one radio chatter of one single sentence instruction, it
doesn't have to match the text instructions, it's to keep the game flow."

What the game had (`game` at b29c9749), and why it read that way (design §1):
- The urgent-mission card closed as soon as its scripted chatter (invite, dare, retort) had been read **or could no
  longer play**. Chatter delayed by other radio expired, which counted as "done", and the card closed. A fast script
  closed it before the brief's reading time, too: the reading time only gated the hold at the flight's end.
- Each level's brief was one sentence with two clauses ("Lure the lightning onto the swarm. When the air hums over
  you, slide out."): no separate goal and how-to, and words such as "lure" and "hums" that a kid may not know.
- Three radio turns (invite, dare, brood retort) competed with the card's text for attention.

## What Changes
- **Clear instructions:** every bonus level gets a goal line and a how-to line (`BonusLevelDef.brief` and the new
  `BonusLevelDef.how`), in short words and checked against the rules in code. The goal is drawn bold. Stormfront
  gets a pictogram strip like Supply Run's.
- **A guaranteed reading time:** the card opens at the transition's radio slot whatever the channel is doing. It
  stays up for at least its reading time (4–8 s), or until the player taps it or presses Space or Enter. The radio
  never closes it. The existing hold at the flight's end (TAP TO START, at most 15 s) now waits for the reading time
  only.
- **Exactly one radio line per bonus level:** a new `bonusCall.<level>` trigger with one single-sentence line in a
  squadmate's voice. It is a written line (`"pending": "text"`, no audio until tillandsias#1103), not a copy of the
  card's text, and it plays on the card alongside the instructions. The invite, dare and retort are no longer
  spoken. While the card is up, the rest of the squad is hushed, so no toast covers it.
- **Flow:** no new modal step. The card is still the transition's one radio message; the slot asks for the reading
  time (up to the 2 s a slot may add), and anything left is the existing short hold at the flight's end.

## Impact
- Code: `lib/comms/comms_briefing.dart`, `lib/comms/comms_briefing_view.dart`, `lib/widgets/transition_overlay.dart`,
  `lib/game/bonus/bonus_types.dart`, `lib/game/bonus/levels/{supply_run,stormfront}.dart`.
- Radio: `art/comms/lines.json` (two triggers appended), regenerated `lib/comms/comms_bank.dart` and
  `plan/audio-studio/voice-batch-pending.md`. The borrowed-line count is unchanged (55).
- Tests: `test/bonus_briefing_test.dart`, `test/bonus_briefing_card_test.dart`, `test/mission_medals_test.dart`.
- Supersedes the bonus-levels requirement "The card goes before the fight" (closing when the chatter has been read)
  and mission-medals' definition of "read" (design §5).
- Balance: none. The rules of play are unchanged.
