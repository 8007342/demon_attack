# Proposal: fang-and-wings-comms

## Why

Operator, 2026-11-17 (verbatim): "the Fang and Wings shall be their self appointed battle cry: "Fang And Wings!",
let's make the Fangs and Wings a more prevalent topic in the demons radio chatter, to give it as a topic, so their
insignias on top of the demons are identifiable as Fangs/Wings. ... Some dive attacks shall have their war cry, so
please come up with a few variants for a few different demons doing dive attacks, let's time those messages and
battle crys".

Earlier direction still applies: family friendly in two layers (kids get the surface, adults get nods and double
entendres, in original phrasing only), banter and comebacks both ways (`voice-direction`, `voice-stack` §3.2 tone
guide), the comms pacing and middle ground (`comms-pacing`, `comms-middle-ground`), and the portrait lanes (humans
left, brood right, a comeback in one combined toast: `portrait-comms-lanes`).

Today the marks above the creatures' heads (`gargoyle-insignia`, reworked by the parallel `insignia-ranks`) are
never named on the radio, so a player has no words for them. The brood's only dive cries are four generic recorded
lines on `divePrep` ("Wings in!", "Down we go!", "Watch this!", "My turn!"), heard 4–7 times in ten busy minutes
because the squad's dive call almost always takes their slot, and they do not depend on who dives.

## What changes

- **Lore.** "Fang and Wings!" is the brood's battle cry and creed: wings for the flock (given), fangs for the hunt
  (earned). The ranks wear what they have earned, matching the insignia-ranks ladder. Design §1.
- **A recurring topic.** New brood chatter about the creed (`fangChatter`), and two banter exchanges in the combined
  toast: brood cry then squad comeback (`fangBanter`), squad tease about the marks then brood retort (`fangTease`).
  The director lets the creed stand in for some brood chatter and some elite sightings. Design §2, §4.
- **Dive war cries.** A presentation-only gate (`lib/game/dive_cry.dart`) lets a few dives cry, mostly higher ranks,
  with one cry in flight, and raises a structured `diveCry` event (species, rank, position, dive and tell times).
  The radio shows the cry as a brood-lane toast timed to end as the dive starts, or to ride the plunge right behind
  the squad's dive call. Lines per rank (`diveCry.grunt|veteran|hunter|sentinel`), with each species' voice on the
  brood net. Design §3.
- **For the parallel agents.** `diveCry` is the hook for `demon-choir` (wordless grunts quantised to the music); a
  throw shout `spearThrow.d0`–`d5` waits for `spear-bearers`; the cry rank reads insignia-ranks' `RankMark` once the
  model publishes it. Design §API.
- **Second run.** "Fang and Wings" is the brood-side kids' team name at Krybor. A ledger entry in
  `plan/endgame-reveal-ledger.md`. Design §6.

All new lines are written text (`"pending": "text"`): voices are blocked on tillandsias#1103. No line borrows a
placeholder voice, so the borrowed-line count stays 55.

## Impact

- `art/comms/lines.json` (eight new triggers appended, 83 lines), regenerated `lib/comms/comms_bank.dart` and
  `plan/audio-studio/voice-batch-pending.md`.
- `lib/game/dive_cry.dart` (new), `lib/game/game_events.dart` (event names, the observer's gate),
  `lib/game/model.dart` (three fields on `divePrep`; no behaviour, no random draw).
- `lib/comms/comms_creed.dart` (new), `lib/comms/comms_director.dart`, `lib/comms/comms_moments.dart`.
- Tests: `test/fang_and_wings_comms_test.dart` (new), `test/comms_pacing_sim.dart` (the sim raises the cries as the
  observer does).
- Spec: `squad-comms` (ADDED requirements).
- Calibration: none. The model's simulation and its random draws are unchanged.
