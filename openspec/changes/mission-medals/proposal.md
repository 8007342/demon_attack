# Proposal: clear bonus missions and mission medals (B2)

## Why
From the operator's round 3b (`plan/operator-feedback-2026-11-16.md`, B2):
- **Supply Run was not understood.** "Was that like a magnet? Some powerups were different but they were just
  holding." The instructions were unclear, or went by too fast, if there were any.
- **Final scores use no text for modifiers.** The run record's modifier chips (SUPPLY RUN, HEAVY ORDNANCE …) become
  badges: special mission medals with little ribbons or accents per mission. Hero art goes through the shared asset
  pipeline.

What the game had (`game` at 7c1da7d1), and why it read that way (design §1):
- The urgent-mission card closed with the transition's flight, or 1.2 s into combat, whichever came first; its
  brief was two clauses ("Crack the falling crates: three hits each. Kills drop nothing; the cargo drops
  everything.").
- In the level, the explanation came by radio, and every in-level Supply Run line borrowed a recorded clip **with
  that clip's own subtitle**: "Crates on parachutes. Three hits opens one." was heard and shown as "Salvage drifting.
  Collect what you can."; the magnet pickup as "New toy! Try it out."; double score as "Good pickup. Make it count."
- A crate showed no progress between hits (ux-declutter removed its pips); opening one played the wave-clear jingle
  and could draw "Wave's clear. Sweep up the salvage."
- The two bonus powers showed only as a badge in a timer ring beside the ship: the magnet's badge is the shield's U
  recoloured, and neither power drew its effect. They "were just holding".

## What Changes
- **Supply Run's brief** is one short sentence: "Shoot the falling crates open and catch the cargo." The card shows
  the rule as a five-step pictogram.
- **The card holds the level's start** until it has been read (the brief's reading time and every scripted turn) or
  tapped, at most 15 s; it says TAP TO START while it holds. Applies to every bonus level.
- **Cues on the objects**: gold target brackets on an unhit crate, a crack per hit; a dotted drop line and a landing
  marker under falling cargo; the magnet's reach and pull beams; two gold coins orbiting the ship under double score.
- **Feedback**: a burst ring and a new `crateOpen` chime when a crate opens; a flash at the ship on a catch; a tally
  of crates opened in the arena's corner; radio lines in their own words (written lines, `"pending": "text"`), a
  more frequent crate call, and new banter when a crate falls past unopened (`bonusCrateMissed`).
- **The mechanic itself is unchanged** (three hits, kills drop nothing, the same crates, powers and scoring), so the
  bonus-balance gate holds as it was.
- **Mission medals**: one composable medal per mission (a shared base plus per-mission ribbon, accent and emblem
  layers, from a rigkit + ComfyUI + rigsheet hero atlas) on the run record card (medal screen and final score card)
  and beside the regular medals on scoreboard rows. The mission's name is the medal's accessibility label and tap
  tooltip; no modifier text is shown.
- Stormfront was checked: its brief and storm tells read; it gains the card's hold and nothing else.

## Impact
- Code: `lib/game/bonus/levels/supply_run*.dart`, `bonus_painters.dart`, `lib/comms/comms_briefing*.dart`,
  `lib/widgets/transition_overlay.dart`, `lib/widgets/mission_medal*.dart`, `run_record.dart`; hooks in `scene.dart`
  (the hold), `main.dart` (wiring, scoreboard rows), `model.dart` (the crate's raw sound event),
  `game_events.dart` (one event name), `web/audio/demon-audio.js` (one sound).
- Radio: `art/comms/lines.json` (Supply Run in-level triggers become written lines; one new trigger), regenerated
  `comms_bank.dart`.
- Art: `art/families/mission-medals.json`, picks under `art/sprites/sources/mission-medals/`,
  `assets/images/mission-medals.png`, ledger `plan/render-runs/mission-medals.md`.
- Capabilities: new `bonus-supply-run-clarity`, new `mission-medals`.
