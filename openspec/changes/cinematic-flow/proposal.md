# Proposal: cinematic flow (W5b)

## Why
Operator playtest, 2026-11-15 (`plan/operator-feedback-2026-11-15.md` W5):
- the UX is covered with junk, so everything with a progress bar goes (that is `ux-declutter`, W5a, which another
  agent is doing now);
- transitions, outros and orchestration should follow the cannonball research and the macron.dev animation job;
- level and boss transitions should play as part of W3's "one consistent swarm".

Today a sector change is a chain of phases:
- salvage, 2 s;
- level clear, 4 s + reading time, with a storyboard card;
- travel, 4 s + reading time, with an interlude card (tip or radio);
- the next sector's arrival hint.

That is about 15 s of cards in front of the game. The cannonball research (`plan/swarm-research.md` §2.2) says
transitions should stream:
- blend scenery, music and radio while play continues;
- keep subject direction and screen position through motivated cuts (Cianciolo, GDC Europe 2011);
- no opaque wipe and no all-black frame;
- skip at once;
- reduced motion keeps the same beats;
- music changes on bars, with immediate feedback kept separate.

macron.dev's job shows how to choreograph it: one beat clock, overlapping `bump` envelopes, each actor a pure
function of the clock and its phase offset, seams hidden in quiet beats. Tetris Effect's "album" idea gives the
theme: **the old sector's swarm becomes the new sector's swarm.**

## What Changes
- **`FlowDirector`**: one normalized clock per transition, beats built from `bump` envelopes, all actors (ship,
  camera, swarm, fog cover, music cues, radio, caption) as functions of it. Pure Dart, deterministic, testable.
- **A sector transition becomes three swarm beats.** The mode names (`salvage`, `levelClear`, `travel`) and their
  events are kept, so music, ground war and saves keep working.
  1. **Rout** (2.0 s, the salvage grace). The last kill gets an immediate stinger and a 60 ms hit-stop. Any
     remaining brood in the fog breaks into a flash expansion and flees. Pickups can still be collected.
  2. **Pursuit** (6.0 s, plus up to 2 s if a radio line needs it). The ship climbs nose-up into the cloud layers,
     with the camera tilting up through W2's fog. The fleeing flock streams ahead, and the ship chases it. The
     sector's palette changes *inside* the cloud, which gives a motivated cut with direction preserved. One radio
     line plays on the comms dock, *or* one tip caption shows at the bottom edge, never both at once.
  3. **Descent** (overlapping the next sector's first-wave arrival). The ship drops out of the cloud into the new
     sector. The flock it was chasing comes out of the cloud as the new sector's species and wheels into the first
     wave (`stream.preload`). A brief sector title appears at the top edge.
- **Boss transition.** Arriving at the carrier sector, the pursued flock streams *into* the descending carrier's
  hangar bays. The carrier's retro-burn arrival happens in the vacuole the swarm opens for it. After its chain
  detonation, the brood remnant scatters into the fog, and that scatter is the Rout of the victory.
- **Outros:**
  - **Campaign complete:** the last rout lifts every shadow, the fog thins, and the ship climbs above the clouds
    into the existing ending.
  - **Game over:** the swarm wins. It mills in a torus over the wreck while the brood taunts, and then the
    existing skyward pan to High Scores plays.
- **Attract mode** (title screen): the swarm mills in the fog behind the title, and the sentinel silhouette passes.
  An optional demo flight by the real-shot test pilot starts after 30 s idle.
- **No cards and no strips in sector transitions.** Interlude cards and storyboards leave sector transitions. The
  radio moves to the dock, and tips become a single caption line. The illustrated hint card remains only during the
  run's opening arrival and in the pause menu. Medal and +1UP recognition stays as a diegetic flourish at the ship.
- **Rules,** all tested:
  - no opaque wipe and no frame darker than the sector's night floor;
  - skip (tap, Space, Enter) jumps to Descent within one frame;
  - reduced motion plays the same beats as crossfades, with no tilt or shake (Pursuit at most 3.5 s);
  - music: immediate stinger, then Pursuit and Descent on the next bar of the 120 BPM grid;
  - a unique art beat, a radio instruction and a caption never start at the same instant.

## Capabilities
### Modified Capabilities
- `arcade-progression`: victory and travel become swarm beats; storyboards leave sector transitions; new
  requirements for continuity, skip, reduced motion, boss arrival through the swarm, outros and attract mode.
- `arcade-presentation`: illustrated hints only at the opening and in the pause menu; one caption or radio line per
  transition beat.

## Impact
- **New:** `lib/game/flow_director.dart`, `lib/widgets/flow_caption.dart`.
- **Changed:**
  - `lib/game/model.dart`: the cinematic branch of `_step` (phase lengths, skip), `_beginLevel` using
    `stream.preload`, `_completeWave`, boss arrival and victory;
  - `lib/game/swarm_stream.dart`: real `drain` / `rout` / `preload`;
  - `lib/game/scene.dart`: cinematic drawing (camera tilt, pursued flock, Descent), carrier vacuole, game-over mill;
  - `lib/widgets/transition_overlay.dart`, `lib/game/interlude.dart`, `lib/widgets/interlude_card.dart`,
    `lib/widgets/storyboard_banner.dart`: cards leave sector transitions;
  - `lib/main.dart`: title attract and skip input;
  - `lib/ending/ending_page.dart`: entry from the outro;
  - `lib/game/music_director.dart`: bar-aligned cue timing.
- **Tests:** new `test/cinematic_flow_test.dart` and `test/cinematic_flow_review_test.dart`; updated
  `test/fluid_transitions_test.dart`, `test/cinematic_scene_test.dart`, `test/transition_loadout_test.dart`,
  `test/ending_progression_test.dart`, `test/campaign_*`.
- **Depends on:**
  - `continuous-swarm` (stream hooks, shadows, re-entry);
  - `fog-restoration` (a `cloudCover` / `fogThin` control on the layers);
  - `ux-declutter` (progress bars already gone; land after it and rebase).

  `demon-intelligence` is independent.
