# Proposal: continuous swarm (W3)

## Why
Operator playtest, 2026-11-15 (`plan/operator-feedback-2026-11-15.md` W3). They want:
- no discrete ladder of incoming enemies and no discrete batches, but a **continuous inflow** along **parabolic
  curves traced by swarm behaviour**, which merely **accelerates** if the previous wave is cleared faster;
- real swarm patterns **while flying in and while fighting**, not hovering and little figure-eights;
- enemies shown **sideways more often**;
- reinforcements, waves, level and boss transitions, sentinels, dives and radio chatter playing as **one
  consistent swarm flocking through continuous space, through layers of fog**;
- **shadows** that stay when creatures reach the front row and shift as they swarm, with demon and ship shadows
  played together for immersion.

Today, between waves of a sector there is a `RunMode.transition` release. Arrivals are a presentation-only flock
that hands each creature to a fixed slot in a 6-column grid. There, the creature bobs on sines (±29 × ±14 units),
and the bob is too slow to show the banked renders. A creature's shadow fades out as it settles. The research is in
`plan/swarm-research.md` §1, §3 and §6.

## What Changes
- **Cohorts, not batches.** A wave stays the accounting unit: roster, finite reinforcement groups, escort,
  wave-wide elite budget, checkpoint and wave number. All of these stay **exactly** as calibrated. A cohort reaches
  the screen as a stream of **skeins** (3–6 creatures). Each skein leaves a point in the fog and flies a parabolic
  swoop into the fight. Inside a sector, no transition phase separates two waves.
- **A visible reserve.** Reinforcement groups and the next cohort wait as shapes in the deep fog: untargetable,
  silent, gear hidden, searching on Lévy-flight drifts. When admitted, a skein peels off and swoops in. The
  occupancy, casualty and fallback admission rules are unchanged.
- **Rubber-band pacing.** The next cohort's approach and the gaps between skeins shrink when the player clears
  faster than the cohort's expected clear time. They are capped per difficulty and relax after a lost life. Pacing
  never adds HP, births or simultaneous attackers.
- **Fighting patterns.** Once arrived, each skein is a squad. It fights in a collective state:
  - **mill** (torus), **sweep** (parallel stream across the band) or **ribbon** (Lissajous murmuration);
  - sentinel escorts fight as a **cloud**.
  - The state is chosen with hysteresis and crossfades every 7–12 s.
  - These are simulation positions, deterministic and seeded. The old hover stays for onboarding (Easy route 0,
    sector 1, waves 1–2) and for hand-built test fixtures.
- **Visible evasion is presentation.** Player fire sends agitation waves, vacuoles and flash expansion through a
  squad. The offsets are smaller than a third of the hitbox. Gameplay dodging is unchanged here (W4 owns it).
- **Sideways facing.** Sweeps, mills and swoops carry sustained lateral speed. Squads share a heading. The
  creature motion hysteresis moves to 38 / 16 u/s with a 0.28 s hold. Banked (yaw ±38°) renders become the common
  case: target ≥ 50 % of combat frames, from a baseline measured first.
- **Shadows everywhere.** Every airborne creature keeps a silhouette ground shadow from its altitude: arriving,
  fighting and diving. The shadow sways with its pattern and is batched in at most three blur layers. The ship gets
  a silhouette shadow on the same sun. A diver's shadow converges on the ship's. A creature whose shadow lies
  across the ship dims it slightly. The sentinel's shadow sweeps the far terrain before it emerges.
- **One swarm timeline.** Arrivals, reinforcement and sentinel calls carry an `eta`, so radio calls end as the
  skein becomes targetable. Divers no longer drop back in from the top of the screen: they rejoin their squad
  out of the fog. The sentinel rises from its foreshadow silhouette along a depth path. The fog layers
  themselves belong to `fog-restoration` (W2). This change supplies the paths and depths only.

## Capabilities
### Modified Capabilities
- `arcade-combat`: continuous cohort inflow, rubber-band pacing, fighting patterns, presentation evasion and
  dive re-entry from the fog.
- `arcade-presentation`: sideways facing, persistent creature and ship shadows, the swarm–fog depth contract.
- `arcade-progression`: no transition phase between the waves of a sector; the lull is the recovery beat.

## Impact
- **New:**
  - `lib/game/swarm_stream.dart`: cohort → skein scheduler, reserve, rubber band; pure Dart.
  - `lib/game/swarm_patterns.dart`: squad states and anchors; pure Dart.
- **Changed:**
  - `lib/game/flock.dart`: model-owned for the whole flight; parabolic swoops.
  - `lib/game/model.dart`: the `--- wave pressure` block becomes `--- continuous swarm`, plus `_spawnWave`,
    `_completeWave`, `_updateReinforcements`, `_spawnReinforcementGroup`, `_targetFormationPosition`, dive
    re-entry.
  - `lib/game/difficulty.dart`: pacing caps and skein gaps.
  - `lib/game/creature_motion.dart`: thresholds and squad heading.
  - `lib/game/scene.dart`: unified batched shadows, ship-shadow interplay.
  - `lib/game/flyover_background.dart`: the ship silhouette shadow.
  - `lib/game/game_events.dart`: `eta` fields and `cohortSighted`.
  - `lib/comms/comms_moments.dart`: reuses `waveStart` lines for `cohortSighted`. No new recordings.
- **Tests:**
  - new `test/continuous_swarm_test.dart`, `test/swarm_patterns_test.dart`, `test/swarm_facing_test.dart`,
    `test/swarm_shadows_test.dart`;
  - rewritten `test/wave_pressure_test.dart`;
  - extended campaign pilot metrics;
  - `test/difficulty_calibration_test.dart` unchanged and green.
- **Review frames:** `test/continuous_swarm_review_test.dart` writes to `.cache/continuous-swarm-review/`.
- **Coordination:**
  - `fog-restoration` (W2) owns the fog layers. This change reads their band depths through one accessor.
  - `ux-declutter` removes progress bars, so this change adds no HUD.
  - `demon-intelligence` (W4) and `cinematic-flow` (W5b) build on this change.
