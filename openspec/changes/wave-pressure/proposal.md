# Proposal: wave pressure and distant arrivals

## Why
The operator (2026-11-14): "The very first wave of enemies from game load takes a dramatic time to arrive in
glorious fashion, let's also start the reinforcements and waves come from a distance, we might have to start
their incoming even before the previous wave ends, when it's below a certain threshold, so users have a sense
of pressure to finish them off before the next one arrives." And: "make sure that enemies at a distance are
obscured or fogged out, maybe add some smoke and cloudy layers to add distance effect."

Today every wave after the first starts only once the previous wave is fully cleared, after a fixed
transition. The last few stragglers have no stakes, and the next wave pops in from a clean slate.

## What Changes
- **Early approach.** On an ordinary wave that is not the level's last, once every reinforcement group has
  arrived, no sentinel is alive or waiting, and at most `pressureThreshold` enemies remain
  (Easy 2, Normal 3, Hard 4), the next wave's roster is born and creeps out of the horizon fog
  (`model.incoming`, event `incoming`). It is visible but not targetable, does not fire, and does not count
  toward the clear.
- **Finish first, keep the release.** If the stragglers fall first, the approaching wave settles in during the
  usual short release (1.4 s + story reading time), exactly as a fresh wave starts today.
- **Linger, and it joins.** If `incomingSeconds` (Easy 10, Normal 8, Hard 6, at hostile rate) run out first,
  the wave number advances and the approaching roster closes in while combat goes on, alongside the
  stragglers. A lost life pauses that clock.
- **Same encounter budget.** The approaching roster is exactly the next wave's own: count, species, HP and
  the wave-wide elite budget (plan/difficulty-calibration.md). Only the timing changes. The threshold never
  exceeds the smallest reinforcement group, so stragglers + roster stay inside the calibrated occupancy bound
  (initial roster + largest group). One sentinel at a time still holds.
- **The first wave is unchanged:** its dramatic arrival hint keeps its full length.
- **Distance and weather.** Far creatures fade in (`Perspective.fade`) and wear the horizon haze; the still-
  approaching wave is fogged harder (85 % haze) with drifting mist wisps; a band of smoke and low cloud drifts
  along the horizon behind every creature. These are procedural placeholders until the ground-forces-rework
  atmosphere atlas (`plan/ground-atmosphere.md`) lands.

## Balance references
- Valve, L4D (Booth 2009): build-up / peak / release. The approach adds a build-up beat in the last seconds of
  a wave; finishing the wave still earns the release.
- Sweetser & Wyeth, GameFlow (2005): clear goals and feedback. The approaching wave is a visible, readable goal
  ("finish them before those arrive"), scaled by difficulty.
- plan/difficulty-calibration.md: timing beats, never extra HP; finite groups; occupancy admission.

## Impact
`lib/game/model.dart` (`_spawnWave` split into `_resetWaveEnemies` and `_buildRoster`, the `--- wave pressure`
block, `_completeWave`), `lib/game/difficulty.dart` (`pressureThreshold`, `incomingSeconds`),
`lib/game/perspective.dart` (`fade`), `lib/game/scene.dart` (incoming drawn farthest, fog, mist wisps, horizon
smoke). Tests: `test/wave_pressure_test.dart`. The campaign playtest, ground-front and perspective-parity guards
pass unchanged.
