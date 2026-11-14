# Proposal

## Why

Operator, 2026-11-14:

1. "The radio chatter cut was a bit too much, bring it back to the middle."
2. "Throw in a few extra more during cutscenes, wave reinforcements, etc. Now it went too quiet."
3. "Just make sure comms don't cut each other off, let them finish with some grace period."
4. "The chatter for the dives, the ground attacks, and the demon-human taunt back and forth should be properly displayed with their timeouts for being able to read their texts."
5. "Radio chatter about air coverage should also match the gameplay below."

Before comms-pacing, the radio was on air 61–65 % of the time in busy combat. comms-pacing cut it to 17–20 %, and urgent and must-play warnings could still cut a line in progress. This change aims for the middle and stops all cuts.

## Measured (test/comms_pacing_sim.dart, busy sector-3 combat, 600 s, seeds 4 / 11 / 23)

| | before (comms-pacing) | after (this change) |
|---|---|---|
| Paced airtime, busy | 19.7 / 18.0 / 16.9 % | 38.8 / 38.0 / 39.4 % |
| Paced airtime, calm stretch | 15.4 / 15.7 / 16.3 % | 24.3 / 24.3 / 25.1 % |
| Total airtime, busy (with ground warnings) | 36.4 / 29.5 / 29.8 % | 54.2 / 49.5 / 52.3 % |
| Lines started, busy | 120 / 109 / 104 | 170 / 173 / 178 |
| Overlapping voices | 0 | 0 |
| Lines cut | 12 / 7 / 7 | 0 |
| Dive calls ending within ±0.3 s of the dive | 23 / 21 / 23 (all; others dropped) | 31 of 41 / 36 of 41 / 40 of 42; the rest are urgent sentinel calls that waited for the line on air and still started before the dive |
| Ground launches | 54 / 51 / 60 | 54 / 51 / 60 |
| Ground warnings ending late (channel busy) | 0, because they cut the line on air | 2 / 1 / 1 (3.7 / 2.0 / 1.7 %); never dropped, never cut |
| … the same without the new fire forecast | – | 11 / 16 / 11 |
| Recommendations within 8 s | 25/25, 19/20, 22/22 | 24/25, 21/22, 21/21 (none later than 12 s) |
| Wave-start / reinforcement lines heard, busy | – | 10, 6, 6 / 26, 18, 25 |

The simulation now also stages the fight below (`groundPicture` engaged and over spans), the observer's fire forecast, the music director's intensity tier (3 busy, 1 calm), and reinforcement arrivals observed twice in one frame (`reinforcements` + `reinforcementsArrived`).

## What Changes

- **Middle-ground pacing.** `CommsPacing.duty` 0.16 → 0.40 seconds of speech per second, `burst` 4 → 6 s, the flavour rest 3 s + 2.5 s jitter → 1.5 s + 1.5 s, the useful rest 1 s + 0.8 s → 0.6 s + 0.6 s. The duty follows the music director's intensity tier (`musicIntensity`): ×0.6 in calm (tier 1), ×0.85 at tier 2, full at tiers 3–4. Release stretches stay quieter, as in the GameFlow build-up / peak / release rhythm.
- **No line cuts another.** Every line finishes. After every line there is a grace gap (`CommsPacing.grace`, 0.4 s; `CommsDirector.lineGap` defaults to it). Urgent warnings go first in the queue and wait at least 5 s (`urgentTtl`).
- **Lookahead.** Nothing starts that would still be speaking, with its grace gap and an exchange's answer included, when a queued timed call (dive call, ground-fire warning) is due. A new observer event, `groundFireForecast`, gives the model's own launch prediction up to 5 s ahead. The director keeps the last 2.1 s before a forecast launch (`fireReserve`) clear of everything except warnings. If a conflict still happens, the line on air finishes, the grace gap follows, and the warning plays its shortest variant (`late`, counted in `CommsDirector.lateWarnings`). Must-play warnings are never dropped. Dive calls and exchange answers that have not started yet give way to a warning. An urgent sentinel call that cannot end on the dive plays its shortest variant if it still starts before the dive (`lateDiveCalls`). Other dive calls are dropped as before.
- **More chatter at the moments that matter, from recorded clips.** Wave starts, reinforcements (`reinforcementsArrived` is an alias of `reinforcements`, so one arrival gives one call), sentinel escorts (`escort` → `sentinelIncoming`), carrier phases and hatch, the next wave on the horizon (`incoming`, from wave pressure), level clear, salvage and sector starts now rank as useful lines. `waveStart` is said at 85 % (it was 55 %) with a 16 s cooldown, and salvage at 85 % (it was 50 %) with a 30 s cooldown. `carrierHatchOpen` reuses `bossPhase.h2` "Field's down! Hit the core!" and `bossPhase.h0`, with `bossPhase.d2` for the brood. `incoming` reuses `waveStart.h0` / `.h2` / `.h4` and shares its cooldown with `waveStart`. No audio was rendered. Lines still to be recorded are in `art/comms/pending-lines-2026-11-14.json`, and nothing references them at runtime.
- **Readable subtitles.** A subtitle or card stays up until max(clip end + hold, 0.9 s + 0.055 s per character), and the reading time is capped at 7 s. An exchange's opening line stays until its answer has been read. The compact dock places cards oldest first, so a card keeps its half until it has been read. A linked exchange takes both halves. A card with no free half waits as a one-line ticker under the dock and moves up when a half frees. Flavour lines wait while an exchange is on screen, and an exchange only opens when the rest of the dock will be clear by the time its answer starts.
- **Lines match the fight below.** A new observer event, `groundPicture`, reports on change: live demon ground units engaged, threats, and whether the ship is over the battle (within 64 units, leaving at 90). `CommsGroundPicture` also remembers `allyUnderAttack` (10 s) and the player's homing help (15 s). Lines whose words go beyond their own event are gated: air-cover lines only while the ship is over the fight, calls for help only after allies called, surge and pressure narration only while ground units are engaged, flank and infantry lines by the event's position and forces, "thanks for the thunder" only for artillery wins, and ground-crew comebacks only in sectors with a ground war.
- **Transition hooks.** `CommsDirector.hush(seconds)` (and `hushFor(Duration)`) holds every line below urgent until the hush ends, then gives held lines a short wait. Warnings still play. `CommsDirector.offer(line)` queues one chosen bank line through the normal pacing (a useful line, after the grace gap), so the transition overlay no longer plays it itself.
- Music volume stays constant: speech never ducks the music.

## Capabilities

### Modified Capabilities
- `squad-comms`: pacing level, no cuts with a grace gap and lookahead, readable holds and dock stacking, voiced moments, ground-truth gates, transition hooks.

## Impact

- `lib/comms/`: `comms_pacing.dart`, `comms_director.dart`, `comms_view.dart`, `comms_types.dart` (`copyWith`), `squad_comms.dart`. New files: `comms_context.dart` (ground picture and gates) and `comms_moments.dart` (moment classes, aliases, retuned and reused-clip triggers).
- `lib/game/game_events.dart` (additive): `groundPicture`, `groundFireForecast` and `incoming` names, plus the observer's read-only `_observeGround` and `_forecastFire`.
- Tests: `test/comms_pacing_sim.dart`, `test/comms_pacing_test.dart`, `test/comms_director_test.dart`, and a new `test/comms_middle_ground_test.dart`.
- `art/comms/pending-lines-2026-11-14.json` (new, not used at runtime). The generated bank and the audio are unchanged.
