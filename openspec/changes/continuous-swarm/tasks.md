# Tasks: continuous swarm (W3)

Order matters. Each numbered group lands as its own commit on a `work/continuous-swarm` branch off `game`, with
`flutter analyze` and `flutter test` green. Rebase onto `fog-restoration` (W2) and `ux-declutter` if they land
first (see design §0 and §10). `demon-intelligence` and `cinematic-flow` start only after group 7.

## 1. Baselines (no behaviour change)
- [ ] 1.1 `test/support/swarm_metrics.dart`: a recorder for the real-shot campaign pilot
      (`test/campaign_playtest_test.dart`). Per (mode, route, sector, wave) it records: clear time, shots fired,
      shots hit, peak active, peak hostile bullets, lives lost.
      - Write the results to `.cache/swarm-metrics.json`.
      - Run it on `game` before any change and commit the summary table to `plan/calibration-current.md` under
        "Pre-W3 baseline".
- [ ] 1.2 Facing baseline: drive `CreatureMotion` from a 60 s Normal sector-2 simulation (no rendering) and
      record the share of frames with `dir != 0` (telegraph, dive and fire poses excluded). Add it to the same
      table.
- [ ] 1.3 Fit the efficiency constant of `T_expected` (design §2.3) so the baseline's median `T_actual / T_expected`
      is 1.0 at Normal. Record the fitted value in the design note.

## 2. The stream scheduler (pure Dart)
- [ ] 2.1 `lib/game/swarm_stream.dart`:
      - `SwarmStream`, `Cohort`, `Skein`, `SwarmState` (reserve, approaching, present, diving, reentering);
      - splitting a roster into skeins by column band (3–6 each), groups into 1–2 skeins;
      - its own seeded PRNG;
      - the skein-gap formula, the q pacing formula, lull length;
      - `drain()`, `rout(dir)`, `preload(cohort)` as stubs returning plans (W5b fills them in).
- [ ] 2.2 `difficulty.dart`: add `skeinGap`, `paceFloor`, `swarmTempo` (design §2.4) with doc comments that point
      to `plan/difficulty-calibration.md` ("timing, never HP").
- [ ] 2.3 `test/swarm_stream_test.dart`:
      - the split preserves members and order;
      - gaps shrink with low `live` and never go below 0.5 · g_base;
      - q is clamped to [paceFloor, 1];
      - a lost life resets q to 1;
      - same seed gives the same plan;
      - no draw from `model.random`.

## 3. Model integration
- [ ] 3.1 `model.dart`: replace the `--- wave pressure` block with `--- continuous swarm`.
      - `_spawnWave` builds cohort c and releases roster skeins. Wave 1 and checkpoint keep their entrance
        lengths.
      - `_completeWave` / `_mergeCohort` replace `_mergeIncoming`: lull or forced merge, no
        `RunMode.transition` for wave > 1, hostile shots fizzle (`events.add('shotsFizzle')`).
      - Keep `incoming` as a read-only view of approaching members of cohort c+1. `scene.dart` reads it until
        group 6 switches to `swarmReserve`.
- [ ] 3.2 `_updateReinforcements` / `_spawnReinforcementGroup`: groups are born into the reserve at cohort start.
      Admission keeps every existing inequality and timer verbatim and flips the skein to approaching.
      `flocksSpawned` counts admissions.
- [ ] 3.3 Occupancy guard: assert (debug) and test that present + approaching ordinary ≤ initial roster + largest
      group at every step.
- [ ] 3.4 Dive re-entry from the fog (design §6.2): replace the top re-entry in `_updateDemons` (the
      `d.y > height + 20` branch) with `reentering` via a deep gate.
- [ ] 3.5 Tests:
      - rewrite `test/wave_pressure_test.dart` per design §9;
      - `test/reinforcement_pressure_test.dart` unchanged and green;
      - `test/difficulty_calibration_test.dart` unchanged and green;
      - fix fixtures in other tests only where they asserted the old interwave `RunMode.transition`, and list
        each one in the commit message.
- [ ] 3.6 Campaign pilot: all modes complete. Compare metrics with 1.1 (budgets identical, clear times reported).

## 4. Swoops and model-owned flock
- [ ] 4.1 `flock.dart`: `ArrivalFlock` → `SwarmFlock`.
      - agents live for the creature's whole flight;
      - stepped at 60 Hz from `_step` (drop the 30 Hz accumulator and interpolation);
      - emitters (left, right, centre, two deep gates);
      - a quadratic Bézier ground track with an opposite-side swing;
      - the altitude parabola (design §3);
      - β blend to the pattern target.
- [ ] 4.2 Retire the flock parity test. Add a determinism test (`test/continuous_swarm_test.dart`): a full sector
      twice with the same seed gives identical positions, events and score.
- [ ] 4.3 Quintic hand-off guard: extend `test/combat_balance_test.dart` "wave entrance transitions smoothly" to
      cover swoop → pattern (no position or velocity snap above 1.5 units per frame).

## 5. Fighting patterns
- [ ] 5.1 `lib/game/swarm_patterns.dart`:
      - `Squad`, `SquadState` (mill, ribbon, sweep, cloud, hover), the φ dial, dwell and neighbour switching;
      - anchors and offsets per design §4, with clamps;
      - the altitude channel (design §8.1).
- [ ] 5.2 `model.dart` `_targetFormationPosition`: ordinary members of a squad use the pattern target plus
      `evadeOffset` and the telegraph crest. Strays, onboarding and `swarmPatterns == false` use today's hover
      verbatim. Spring + k = 7 separation + squad alignment + speed cap.
- [ ] 5.3 `test/swarm_patterns_test.dart`:
      - clamps (x, and y ≤ shipY − 130);
      - each state's lateral speed is within its design band;
      - switching only between neighbours;
      - crossfade has no snap;
      - the vacuole closes in ≤ 0.6 s;
      - hover fallback positions equal today's formula;
      - 61 members run a step in < 0.2 ms (VM, median of 200).
- [ ] 5.4 Calibration loop: run the 1.1 recorder. Accept per design §9 (+25 % clear time, −15 % hit ratio,
      bounds). If it is out, tune `swarmTempo` and the mill radius first and record each iteration in
      `plan/calibration-current.md`. Do not touch budgets.
- [ ] 5.5 Add `AveragePilot` (design §9) and record lives lost per sector as the W4 baseline (report only).

## 6. Presentation: facing, visible evasion, shadows
- [ ] 6.1 `creature_motion.dart`: new thresholds and hold. Add a `squadVx` argument to `update` and use the squad
      heading rule. `scene.dart` passes the squad velocity.
- [ ] 6.2 `test/swarm_facing_test.dart`: the 1.2 measurement after the change, target `dir != 0` ≥ 50 %, and no
      flicker (no direction held < 0.28 s).
- [ ] 6.3 Visible evasion in `scene.dart` (or a new `lib/game/swarm_look.dart`): the agitation wave (40 ms per hop,
      0.7 decay), flash expansion on kill, wing tilt.
      - Clamp |δ| ≤ hitHalfWidth / 3.
      - Test that the model's `x, y` are unchanged by it.
- [ ] 6.4 `_creatureShadows`: unified, batched (≤ 3 `saveLayer`s + `drawAtlas`), persistent, with altitude
      channel, sun drift, divers × 1.25, no fade on settling.
      - Read `t_ground` through the W2 accessor, falling back to 0.85.
      - Remove `_swarmShadows` and `_arrivalShadows`.
- [ ] 6.5 Ship silhouette shadow in `flyover_background.dart` `paintShadow`. Shadow-over-ship dim (cap 15 %).
      Sentinel foreshadow ground shadow.
- [ ] 6.6 `test/swarm_shadows_test.dart`:
      - every present airborne creature casts one;
      - none in the reserve;
      - at most 3 layers per frame (a recording canvas counts `saveLayer`);
      - bullets are drawn after shadows;
      - the dim never exceeds the cap.
- [ ] 6.7 Perf: `test/atmosphere_perf_test.dart` with a 61-creature combat frame plus shadows, ≤ +1.5 ms against
      baseline.

## 7. One swarm timeline and radio
- [ ] 7.1 `game_events.dart`: `cohortSighted`, `cohortMerged`, `shotsFizzle`; an `eta` on `reinforcements` and
      `sentinelIncoming`.
- [ ] 7.2 `comms_moments.dart`: map `cohortSighted` onto the `waveStart` trigger (reused clips). End calls on `eta`
      like `divePrep`. `test/comms_pacing_test.dart` and `test/comms_director_test.dart` stay green. Add a case
      where a `cohortSighted` call ends within 0.3 s of the skein becoming targetable.
- [ ] 7.3 Sentinel rise path (design §6.3): at least 0.6 s per fog band. Test the timing. Hand W2 a review frame
      of the rise.
- [ ] 7.4 Music: `music_director.dart` treats `cohortMerged` as the old `wave` stinger. `test/music_director_test.dart`
      stays green.

## 8. Review frames and playtest
- [ ] 8.1 `test/continuous_swarm_review_test.dart` (pattern of `test/atmosphere_review_test.dart`). It writes
      PNGs at phone portrait to `.cache/continuous-swarm-review/` (override `CONTINUOUS_SWARM_REVIEW_DIR`):
      - a reserve in the fog;
      - a skein mid-swoop (shadow ahead on the ground);
      - a mill, a ribbon, a sweep (banked frames visible);
      - an agitation wave after a shot;
      - a cohort merge in the lull;
      - a diver with its shadow converging on the ship's;
      - a diver re-entering from a deep gate;
      - the sentinel rising with its escort cloud;
      - the reduced atmosphere tier.

      Make a contact sheet with `studio.contact_sheet` if the studio is up; otherwise tile with a Lua script.
- [ ] 8.2 Preview playtest (`preview.publish`): a phone-portrait browser session of sector 1–2 Normal. Record
      frame time and a screen capture for the operator. Note any "ladder" moment that remains.

## 9. Docs and specs
- [ ] 9.1 `plan/game-design.md` (flock paragraph), `plan/perspective.md` (arrivals), `plan/sprite-atlas.md` (frame
      selection thresholds), `plan/calibration-current.md` (post-W3 table).
- [ ] 9.2 `openspec validate continuous-swarm`, then sync the deltas into `openspec/specs/` at archive time.
