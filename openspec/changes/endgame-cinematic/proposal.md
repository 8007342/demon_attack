# Proposal: endgame-cinematic

## Why

Operator, 2026-11-16 (`plan/operator-feedback-2026-11-16.md`, Round 3d, E1): the end-game scene "should be at least
a few seconds long with a few cinematic shots and transitions, and its own exlusive dialogs", it "needs to be
properly researched and plan", and it should "make EVERY DETAIL OF THE GAME have a new meaning after a second run".
The reveal: the kids imagined the whole war while playing a board game. The Admiral is the mom who says it is time
to go home, the grumpy General is the always-smiling owner, the sassy purple cadet is the teenage waitress with the
free soda refills, Krybor is the restaurant's name, and the gargoyles, ships and tanks are plastic figures. The
operator asked whether it needs its own ComfyUI pipeline, storyboard and guidelines, and set the bar at an
animated feature's level of production.

Today the ending is one still (`assets/images/beach-ending.webp`) with a slow zoom and two captions
(`lib/ending/ending_page.dart`), and its canon is older: teenage human and demon friends on a beach
(`plan/story-hooks.md`). It has no dialogue, and only a handful of radio lines hint at it.

## What changes

- **Research** (`plan/endgame-cinematic-research.md`): story and animation craft, reveal structure, shot grammar,
  transitions, colour scripts, sound, accessibility (Part A); Blender, generated video and hybrid routes, the
  runtime form in Flutter web, models, licences, VRAM, budgets and risks (Part B). Sources sit beside each
  conclusion; 33 unsourced claims are listed in `plan/provenance-audit.md`, Part E.
- **The reveal ledger** (`plan/endgame-reveal-ledger.md`): 167 rows mapping a game detail to its meaning at the
  table, where the game plants it, and the shot that pays it off; the mapping of all 25 radio speakers to people
  and animals at the restaurant; 26 proposed plant lines.
- **The style guide** (`docs/styleguide/endgame-cinematic.md`): tone, look, the cast as bystanders, the plastic
  figures, the colour script, staging, text, sound, review gates.
- **The storyboard** (`art/storyboards/endgame/`): eight boards and the shot list: seven shots in 29 seconds, plus
  a 3-second button after the credits.
- **The lines** (`art/comms/endgame-lines.proposal.json`): 12 exclusive cinematic lines and 26 plant lines, as a
  proposal. The live bank is not touched.
- **New capability `endgame-cinematic`**: the reveal sequence; skip, pause and failure rules; exclusive dialogue
  with subtitles; an in-engine layered scene for portrait and landscape; reduced motion; loading and size; details
  that come from the finished run; the ledger check; the plant rules; a committed, licence-clean pipeline.
- **Modified `arcade-progression`**: "Ending after the fifth carrier" now opens the cinematic, and the replay is
  offered on the medal screen as well as the title.
- **Canon change**: the beach becomes the patio of Krybor, a beachfront burger restaurant in San Diego; the
  brood-side players are kids in horned hoodies. The two captions stay.

## Decisions the operator may want to override

Taken by the lead so the work can proceed (design §10): the General is Gorrak, the Brood Marshal, nicknamed by the
fleet; the cadet is Vexxa, with a proposed rank label WING CADET; the pilot is never shown or voiced; the sign reads
KRYBOR; the scene is in-engine, not a video.

## Not in this change

- No rendering and no model download. Tasks 3 onward start after the storyboard checkpoint (CP0).
- No runtime code yet, and no edit to `art/comms/lines.json`: the `voice-stack` change owns its schema and the
  recording. This change hands it the lines, the `plant` and `set` fields it needs, and the "room" audio chain.
- No full character animation and no video file. A video cut is a later, separate decision (research B6, B7).
- No music or voice work around tillandsias#1103. Until clips exist the scene ships with subtitles only.

## Impact

- New: `art/cinematic/endgame/` (shot script, layout, picks), `tools/cinematic/layout.py`, a `rigsheet` packer
  verb, production job files, `assets/images/cinematic/`, `assets/cinematic/endgame.json`, `web/audio/cinematic/`.
- Changed: `lib/ending/ending_page.dart` (the player replaces the still reveal; the still stays as the fallback),
  `lib/main.dart` (preload during the route-5 carrier, the medal-screen replay, the tooltip wording),
  `lib/services/run_storage.dart` (the last completed run and the completion count),
  `lib/comms/` (plant fields and the second set), `assets/credits.json`, `plan/asset-provenance.md`,
  `plan/story-hooks.md` (its open questions are answered in design §9).
- Superseded text: "beach ending" in `openspec/specs/arcade-progression/spec.md` (delta here) and the "Beach reveal
  and credits" requirement of the open `battle-metal-radio-rework` change (task 1.4 reconciles it).
- Depends on: `voice-stack` (voices, schema), tillandsias#1103 (audio), `carrier-v3` (the carrier mesh for the toy).
