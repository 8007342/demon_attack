# Proposal: the looming sentinel's shadow follows its silhouette

## Why
The operator, 2026-11-17 (verbatim): "When the big centinel is lurking in the back, behind the clouds, its shadow
doesn't follow it, it's and independent minded shadow lol please align them. Once in the battle its shadow follows it
correctly, same thing for the swarm their shadows seem correctly aligned, it's only the incoming big centinel looming
from the back, it's shadow is not aligned with the silohuette hovering behind the clouds. [...] use the regular
demons' as example on how their shadows are calculated, their flying in matches their shadows quite well, it's only
our centinel hoovering behind that has a rogue shadow."

Correction from the operator, same day (verbatim): "Don't use my percentages lol just make it smaller at a distance,
and track the centinel as it approaches. Once its shadow maps correctly it should behave correctly for size and
perspective as well. Shouldn't it?"

Root cause: the lurking shadow (terrain-shadows §4) was never cast from the silhouette. It walked its own
`LurkTrack`: a seeded start x (180 ± 54) with a ±30 meander, creeping from the far terrain to the ground-war front at
10–16 u/s with a virtual altitude 220 → 120, while the silhouette flies a figure-eight (x = 180 ± 96–120) at
nearness 0.05–0.31. Nothing tied the two, so the shadow wandered on its own.

## What Changes
- The looming shadow is cast like every flyer's shadow: from the ground under the silhouette's nearness, below its
  drawn x, at one altitude (120, the rising sentinel's starting altitude), along the flyers' sun direction, draped on
  the relief. Its size is the one sentinel size rule on the ground nearness that projection hits: smaller far away,
  growing as the silhouette comes nearer, with no extra factor.
- The `LurkTrack` (its path, meander, seed stream and front depth) is removed.
- The 0.2 floor on the ground nearness in the size rule (lurk-visibility) is removed: it held the far shadow at one
  size, against the projection.
- The hand-off into the rising sentinel's shadow is unchanged and now starts from the same point and size.

## Impact
- Code: `lib/game/scene.dart` (the lurk spec, the size rule), `lib/game/model.dart` (`SentinelForeshadow` loses its
  track and gains `shadowAltitude`). Presentation only: no simulation draw, no calibration number moves.
- Tests: `test/sentinel_shadow_align_test.dart` (new); `test/terrain_shadows_lurk_test.dart` drops the track's tests;
  two review tests sample the lurk by time instead of track progress.
- Supersedes the track in `terrain-shadows` design §4 ("creeps from the far terrain toward the front").
