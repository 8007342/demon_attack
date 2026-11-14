# Proposal

## Why

The operator loves the 574-clip radio bank, but in play the radio was on about 90 % of the time and calls cut each other off. Hints that lead to the ending punchline got lost in the chatter. Dive announcements started with the dive and ran well past it. The subtitles were small and vanished half a second after the voice. Ground fire at the player had no reliable warning. On top of that, speech ducked the music, and the score is meant to be the star: it will be re-rendered as one epic composition that builds across waves and levels.

Measured with the seeded airtime simulation (`test/comms_pacing_sim.dart`, busy sector-3 combat, 600 s, seeds 4/11/23), the old director gave 61–65 % paced airtime, 56–58 overlapping voices, 9–14 cut lines, 26–31 dive calls aligned out of 64–72, and 0–2 warned ground launches out of 51–60.

## What Changes

- **Rate limiter with seeded jitter.** A leaky airtime budget (0.16 s of speech per second, up to 4 s banked) and a rest after every line of 3 s plus up to 2.5 s of seeded noise. Useful lines wait a shorter rest (1 s plus up to 0.8 s) and may overdraw the budget by 3 s. Flavour lines wait at most 2.5 s, and at most two wait at once; the rest are dropped, not stacked.
- **Classes.** flavour < useful (story clues, mission briefings, priority ≥ 8, dive calls) < hint (shield or power-up recommendations) < urgent (sentinel dive, shield expiring, breakthrough) < must-play (ground fire). An urgent or must-play warning may cut only a lower class. A must-play warning is never cut and never dropped, and nothing cuts a recommendation that already had to be said again.
- **Recommendations.** The observer flags `shieldSpotted` with `hint` when the ship has no shield, and raises `powerupSpotted` (with `hint`) when a weapon power-up falls while the ship has none. Recommendations ignore chance and group gaps, have their own 12 s cooldown, skip the rest and the budget, and are said again (in their shortest form) if a warning cuts them.
- **Dive calls end on the dive.** `divePrep` carries `diveIn` (beat + tell, at the difficulty's pace). The director picks a call whose measured clip length fits and starts it at `dive − duration`, so it ends within ±0.3 s of the dive. Sentinels get the urgent sentinel call, ordinary dives at most one call per 16 s, and otherwise a brood battle cry if the pacing allows. Calls observed only at the dive (`diveWarning` with `diveIn` 0) are dropped, not played late.
- **Ground fire is must-play.** A committed 1.4 s beat (`GroundTuning.firePrep`, event `groundFirePrep` with `fireIn` 2.5 s) now precedes the 1.1 s tell. The reload is shortened by the same beat, so a unit's shot cadence (4.3 s) and the damage are unchanged. The full warning clip ends at the launch, or at most 0.8 s before it. A salvo whose earlier warning ended within 2 s before a launch shares that warning. Ground warnings are outside the airtime budget.
- **Readable text.** The radio text is larger: compact cards 10.5 → 13 px, demon SIGINT 10 → 12.5 px, side tiles 11 → 13.5 px, transmission card 14 → 17 px. Subtitles stay up 2.6 s after a human clip and 3.2 s after a demon clip (it was 0.55 s).
- **Music volume is constant.** comms-audio.js no longer ducks the music. demon-audio.js no longer dips the music under explosions and hits (side-chain) or under the life-loss stinger. The speech Mute/Low/Full toggle changes only the speech level.

## Capabilities

### Modified Capabilities
- `squad-comms`: pacing, classes, recommendations, timed dive and ground-fire calls, subtitle hold and size.
- `arcade-presentation`: constant music volume.

## Impact

`lib/comms/comms_pacing.dart` (new), `comms_director.dart`, `squad_comms.dart`, `comms_view.dart`. `lib/game/game_events.dart` (observer data, `powerupSpotted`, `groundFirePrep`), `model.dart` (`diveIn`), `ground_war.dart` and `life_loss.dart` (fire beat). `web/audio/comms-audio.js`, `web/audio/demon-audio.js`. Tests: `test/comms_pacing_sim.dart`, `test/comms_pacing_test.dart`, `test/music_constant_test.dart`, plus updated director, lineup, layout, ground and worker tests. The generated bank (`comms_bank.dart`) and the audio are unchanged.
