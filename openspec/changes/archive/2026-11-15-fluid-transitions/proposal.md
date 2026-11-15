# Proposal: fluid transitions (one message at a time, alternating interludes)

## Why
Operator request, 2026-11-14: "Our transition tips and progress are starting to get too noisy, we might need to combine some of those to keep the game fluid with everything that's going on at the same time engaging. Let's use the transitions to display either a tooltip, or a radio message in full screen (as in desktop mode) in the middle of the play area sometimes, alternating between game screenshot silent tips (and we hear the music) and radio chatter, for the next mission, maybe also tips, banter, taunts, jokes, etc. Keep it all fluid since it all should play along well with the music."

The audit (design.md §1) found up to four things competing during one sector change: a story card with its own progress bar, a tactical hint card with a second progress bar, a full-size radio transmission over both on phones, the radio dock, and a wave banner on every wave change. The travel card and the arrival hint each held for one phase, so the release between sectors cut hard from card to card. The radio spoke through the hint.

## What Changes
- **One primary message at a time** in the play area: an interlude card, a story card (sector secured, carrier victory, jump into a new route) or the carrier alert. Everything else is folded into a slim progress strip at the top of the arena (sector pips, one line, wave pips, a hairline of phase progress).
- **Alternating interludes** on level and mission transitions. One card spans the travel leg and the arrival that follows it (about 8.8 s), or the arrival alone (the opening, a resumed run, a new route). The opening card is a tip; after that, tips and radio cards alternate, seeded, never the same item twice in a row:
  - **Silent tip:** one tactic over its staged pixel scene (`HintArt`), with no voice: the squad channel is held quiet while it is up and the music carries the moment.
  - **Radio card:** a full-size transmission (portrait, speaker, subtitle) centred in the play area on every screen size, as the phone transmission already was. It shows the squad channel's own transition line (the next-mission briefing) when there is one, and otherwise plays one recorded line from the 574-clip bank, picked by event and emotion: a briefing, banter, a joke or a brood taunt.
  - Each card is chosen to be readable in its window (reading time from its word count; a radio line's clip plus its hold), fades in and out over one beat, can be skipped by tap, Space or Enter, and never lengthens a transition.
- **Merged / removed:** the travel story card (its "set course for" briefing moves onto the sector-secured card), the separate arrival hint card and its header, every per-card progress bar and `DESTINATION LOCK %`, the `SWARM REINFORCEMENTS` wave banner (now a strip line), the salvage banner (now a strip line), the phone-only full-size transmission overlay, and the second carrier-arrival panel (merged into one alert).
- **Kept:** the storyboard on the sector-secured, carrier-victory and new-route cards; the medal and `+1UP` recognition; the tour-escalation story beat on a new route; the carrier objective; the loadout drawn on the storyboard ship.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: illustrated instruction now appears on alternating transition interludes; new requirements for the one-primary-message rule, the interlude cards and the progress strip.

## Impact
New `lib/game/interlude.dart` (planner), `lib/widgets/interlude_card.dart` (cards, strip), `lib/widgets/transition_overlay.dart` (presenter). `lib/main.dart`: the old transition UI functions move out; small delimited hooks (`// --- fluid transitions`). Comms code is untouched: the presenter uses `SquadComms.setVoice`, the director's read-only state and `commsPlay` / `commsStop`. No model, music or audio asset change. Tests: `test/fluid_transitions_test.dart`.
