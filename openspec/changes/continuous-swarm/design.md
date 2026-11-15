# Design: continuous swarm

Research: `plan/swarm-research.md`. Baseline code map: §1 of that file. Units are arena units (360 × 520), seconds
at hostile rate unless stated. `r = clamp(route, 0, 4)`.

## 0. Ownership and boundaries

| Concern | Owner |
|---|---|
| Who exists, HP, budgets, admission, targetability, positions, dives | **model** (`model.dart`, `swarm_stream.dart`, `swarm_patterns.dart`, `flock.dart`) |
| Which fog layers exist, their depth bands, tint, the sentinel's composed fade | **fog-restoration (W2)**: `atmosphere.dart`, fog drawing in `scene.dart` |
| Shadows, facing, agitation wave (cosmetic offsets) | **presentation** (`scene.dart`, `creature_motion.dart`, `flyover_background.dart`) |
| Radio lines | comms (unchanged, consumes events) |

The parity rule of `atmosphere-and-swarms` ("the fight is identical with or without the flock") is **retired on
purpose**: the swarm now decides where hitboxes are. It is replaced by a determinism guard and a calibration
guard (§9).

Depth contract with W2:
- W3 writes `Demon.nearness` (0.06–1.0), `Demon.altitude` (screen units above its ground point) and the new
  `Demon.swarmState` ∈ {reserve, approaching, present, diving, reentering}. W3 never draws fog.
- W2 reads them to interleave and veil. W2 never moves creatures.
- W3 reads band depths from one accessor, `Atmosphere.bandNearness` (a sorted list, W2 to expose). Until that
  exists, it uses the current constants: horizon 0.26, banks 0.335 / 0.43.
- The reserve holds *below* the deepest band, and approach paths cross every band. This is how "incoming waves
  slowly rising up through the underlying layers" happens without W3 knowing how layers look.

## 1. Cohorts

A **cohort** is everything one wave number brings: the roster from `_buildRoster`, the finite groups from
`policy.reinforcementFlocks`, the escort, the wave-wide ordinal and the elite budget. Nothing in its *content*
changes. `_buildRoster`, `_ordinaryProfile`, `reinforcementSize`, `escortSize` and the admission inequalities of
`plan/difficulty-calibration.md` are reused verbatim. The 318-wave audit must not notice this change.

What changes is *when and how* members are born on screen:

```
cohort c:   roster  ──split──► skeins R1..Rm   (m = ceil(roster/5), 3..6 each, by formation column band)
            group f ──split──► skeins Gf1..    (4–7 → 1–2 skeins)
            escort  ──────────► cloud E        (unchanged insect style, from the sentinel silhouette)
```

Wave-number semantics are unchanged: `wave++`, `'wave'` and `'checkpoint'` fire when the next cohort is
**merged** (§2.3).

## 2. The stream (`lib/game/swarm_stream.dart`)

Pure Dart, no Flutter imports. It is owned by `ArcadeModel` as `stream`. It is seeded from (run seed, sector,
route, wave, skein id) with its **own** PRNG. It never draws from `model.random`, so every other random draw in
the run keeps its sequence.

### 2.1 States of a member
`reserve → approaching → present → (diving → reentering → present)* → dead`

- **reserve:** born, drawn veiled in the deep fog (n ∈ [0.10, 0.20]), untargetable, silent, gear hidden. It does
  not count toward clearing or occupancy. It drifts on Lévy steps (μ = 2, l_min 6, l_max 60 world units, one step
  every 0.6–1.4 s) around its skein's reserve point. At most 18 reserve members are drawn. Further reserve skeins
  are represented by their leaders only.
- **approaching:** flies its skein's swoop (§3). Untargetable and silent, as an entering creature today
  (`entranceProgress < 1`).
- **present:** targetable, fires, dives. It is driven by its squad pattern (§4).

### 2.2 Inside a cohort: skein release
- **Roster skeins.** Released in order. The first leaves at cohort start, each next one after a gap g:

  g = g_base · clamp(live / target, 0.5, 1.0)

  - g_base = 1.3 / 1.1 / 0.95 s (Easy / Normal / Hard);
  - `live` is the number of present ordinary members;
  - `target` = 0.6 · roster.

  Killing fast brings the rest sooner. All roster skeins are released within `≤ g_base · (m − 1)` s, so the
  occupancy peak stays at or below today's (whole roster at once).
- **Wave 1 of a sector** keeps its dramatic arrival (`arrivalHintDuration`, operator 2026-11-14). Its skeins are
  released across the opening's second half, as the staggered entrance is today. A checkpoint restore uses the
  short form (1.0 s), as today.
- **Group skeins** are born into the **reserve at cohort start**, so they are visible as shapes in the fog. They
  are *admitted* by today's rule in `_updateReinforcements`:
  - casualties needed `1 + flocksSpawned`, cooldown 0.6 then 1.2 s, fallback 4.5 s;
  - occupancy `active ordinary + group ≤ initial roster + largest group`;
  - escort reserve, and the empty-wave prompt admission.

  Admission flips the skein from reserve to approaching. `flocksSpawned` counts admissions, as before, and
  `'reinforcements'` fires at admission with `eta` = the swoop duration.
- **Escort:** unchanged trigger (`_escortLeft`). It pours from the foreshadow silhouette as the insect cloud. The
  sentinel itself follows §6.3.

### 2.3 Between cohorts: the next wave without a ladder
This generalises the `--- wave pressure` block and replaces it.

- **Trigger** (unchanged): not the level's last wave, all groups admitted, no sentinel alive or waiting, and
  `live ≤ policy.pressureThreshold` (2/3/4). Then cohort c+1 is born: its roster skeins go to the reserve, and the
  first `ceil(m/2)` of them start approaching on a slow hold path. This is today's `incomingHold`, now a real
  swoop that pauses at the fog front.
- **Accelerating approach.** The approach clock length is

  A = policy.incomingSeconds · q,  with  q = clamp(T_actual / T_expected, q_min, 1)

  - `incomingSeconds` = 10 / 8 / 6;
  - q_min = 0.65 / 0.55 / 0.5 (Easy / Normal / Hard);
  - `T_actual` = seconds from cohort c's start to its trigger;
  - `T_expected = 2 + ΣHP_c / (4.35 · 0.4)`, where ΣHP is the cohort's total ordinary HP (roster + groups) and
    4.35 hits/s is the baseline sustained damage (`plan/difficulty-calibration.md`). The efficiency was
    fitted in task 1.3 from the pilot baseline: **0.763** at Normal (Easy 0.822, Hard 0.920; one constant, the
    Normal value, is used for every mode; `plan/calibration-current.md`).
  - A lost life pauses the clock (unchanged) and sets q = 1 for the next cohort, the ALC relaxation.
- **Merge** (`_mergeCohort`, replacing `_mergeIncoming`):
  - **Stragglers die first.** The approaching skeins hold a **lull** of `max(0.8, 1.4 · q)` s at the fog front.
    This is the release beat; there are no targets, so nobody fires. Then they close in over `incomingCloseIn`
    (0.9 s). There is **no `RunMode.transition`**. Leftover hostile shots fizzle at the merge (a 0.25 s dissolve)
    instead of being cleared silently. Pickups keep falling and can be collected.
  - **Clock runs out first** (forced): the approaching skeins close in alongside the stragglers. This is the
    calibrated occupancy path, unchanged.
  - Either way: `wave++`, `_resetWaveEnemies` (keeping the incoming ordinal and elites, as today), `'wave'`,
    `'checkpoint'`, `'cohortMerged'`.
- **Guard.** Through all of this, active + approaching ordinary members never exceed
  `initial roster + largest group`. This is the existing bound, asserted in the new test.

### 2.4 Difficulty knobs (`difficulty.dart`)
- `skeinGap` 1.3 / 1.1 / 0.95
- `paceFloor` (q_min) 0.65 / 0.55 / 0.5
- `swarmTempo` 0.85 / 1.0 / 1.1: the pattern angular and lateral speed factor, multiplied by the route movement
  growth `1 + 0.04 r`.

None of these touch HP, counts or the elite budget.

## 3. Skeins and parabolic swoops (`flock.dart`)

The world space is kept: X = (x − 180) / n, Z = 348 / n, plus altitude. A skein leader flies a **swoop** from its
emitter to its squad station:

- **Emitters:** left gate, right gate, centre, and two "deep" gates under the far banks (n 0.10–0.14). The gate is
  chosen per skein (seeded) so consecutive skeins alternate sides. Lateral crossing is the point: it shows the
  banked renders.
- **Ground track:** a quadratic Bézier P0 → P1 → P2 in (X, Z).
  - P0 is the emitter, P2 is the station.
  - P1 is offset sideways by a swing of 160–320 world units, toward the side *opposite* the emitter, so the path
    crosses the arena.
- **Altitude:** a parabola `h(u) = h0 + (h_peak − h0) · 4u(1 − u) + (h_fight − h0) · u²`.
  - h0 is low in the fog, h_peak is 1.4–2.0 × h_fight, and h_fight is the squad's fighting altitude (§5).
  - The skein *rises out of* the fog, crests, and settles: the operator's "parabolic curves".
- **Progress:** u(t) uses the existing per-agent `pathU` (launch delay, ease 1.7–2.6), so there is no lockstep.
- **Followers** (unchanged): offset pursuit of their slot on the leader's track, k = 7 topological sep/ali/coh,
  wander.
- **Hand-off** (changed): followers no longer blend into a fixed grid slot. At u = 1 they are already squad
  members (§4). The β blend now goes from the swoop to the **pattern target**, over the same `handoffShare`
  window. The quintic smootherstep entrance requirement still holds: no position or velocity snap.

`ArrivalFlock` becomes `SwarmFlock`. It keeps agents for the creature's whole life, not just the entrance. It is
stepped from `ArcadeModel._step` at the model's fixed 60 Hz. The 30 Hz accumulator is dropped because the model
is already fixed-step, and that removes interpolation between gameplay positions.

## 4. Fighting patterns (`lib/game/swarm_patterns.dart`)

A **squad** is the set of present members of one skein. Each squad has a **station** S and an **anchor** A(t).
Each member has a pattern target `T_i(t) = A(t) + offset_i(state, t)`.

**Stations** come from the same 6-column slot allocation as today (`_buildRoster`, `_spawnReinforcementGroup`).
The squad's station is the mean of its members' home slots, so spatial density and depth match the calibrated
grid. Rows below `shipY − 130` stay forbidden.

**States** (Couzin order, with an order dial φ ∈ [0, 1] eased at 0.8 /s):

| State | φ | Anchor | Member offset | Lateral speed |
|---|---|---|---|---|
| mill (torus) | 0 | S + slow drift (±20) | ring of radius R = 34–56, angular speed ω = 0.7–1.1 rad/s · tempo; direction alternates by squad; y radius 0.45 R (a ring seen at a slant); phase 2πi/k + jitter | R·ω ≈ 24–62 |
| ribbon | 0.5 | Gerono 1:2 around S, a = 60–90, period 9–12 s, `t(τ) = τ + 0.15 sin 2τ` | a chain along the anchor's recent track (sampled at 0.12 s per rank), plus an agitation phase | 30–60 |
| sweep (parallel) | 1 | S.x ± span/2 (span 90–180), smootherstep, period 4.5–7 s | a stretched line behind the anchor, spacing 30–36; it stretches on turns (Hemelrijk 2011) | peak ≈ 1.9·span/period ≈ 40–75 |
| cloud | n/a | the sentinel (spring) | insect orbit (existing) | — |
| hover (legacy) | n/a | slot | today's `_targetFormationPosition` sines | ≤ 30 |

- **Switching.** Each squad dwells 7–12 s (seeded), then moves to a *neighbouring* state (mill ↔ ribbon ↔ sweep;
  the collective memory). Targets crossfade over 1.2 s with smootherstep.
- **Bounds.**
  - The anchor is clamped to x ∈ [48, 312] and to y within the squad's home band ± 24.
  - Member targets are clamped to x ∈ [20, 340] and y ≤ shipY − 130.
- **Steering.** Member position follows its target with a critically damped spring (ω_n = 6 /s), plus k = 7
  separation against **all** present ordinary members (radius 30), plus alignment within the squad (0.6). Speed is
  capped at 140 · tempo.
- **Additions on top of the target, unchanged:** `evadeOffset` (the gated gameplay evade), the telegraph crest,
  and the dive. A member in `divePrep` or `telegraph` freezes its pattern phase, so tells read cleanly.
- **Vacuole.** When a member dies or dives, the squad's ring or line closes over 0.6 s (k re-indexed).
- **Hover fallback.**
  - Selected for Easy route 0, sector 1, waves 1–2 (onboarding).
  - Selected when `swarmPatterns` is false (a debug and fixture flag).
  - Selected for strays without a squad: hand-built fixtures and restored demons, through the existing "solo
    flock" path.

  Existing tests that place demons by hand keep their positions.

Cost: N ≤ 61, brute-force k-NN over N² ≈ 3.7 k distance checks per step. This is well under 0.2 ms at 60 Hz in
the Dart VM; measured in task 3.6.

## 5. Visible evasion (presentation)

The scene keeps a per-creature cosmetic offset δ_i, clamped to `|δ| ≤ hitHalfWidth / 3`, and a wing-tilt τ_i. The
offset is never written to the model, and hitboxes never move.

- **Agitation wave.** When a player shot's predicted path passes within 30 units of a present member within
  0.3 s, that member gets an impulse away. The impulse propagates over the squad's k-neighbour graph at 40 ms per
  hop with decay 0.7 (Procaccini 2011).
- **Flash expansion** on a kill: neighbours within 50 units are pushed out, then return over 0.5 s.
- **Vacuole:** see §4.

These create the "swarm reacting to the predator" read without changing who can be hit (W4 owns dodging).

## 6. One swarm timeline

### 6.1 Events with an eta
The new and changed GameEvents (`game_events.dart`) carry `eta`, the seconds until the members become
targetable, at hostile rate:
- `cohortSighted`: the first reserve skein of a cohort becomes visible (`eta` = time to its admission, or the
  approach length A).
- `reinforcements`: at admission (`eta` = swoop duration).
- `sentinelIncoming`: when the sentinel starts its rise (`eta` = rise duration).
- `cohortMerged`: replaces the `'wave'` banner moment.

Comms ends its call on the eta, the same mechanism as `divePrep.diveIn`. `cohortSighted` reuses the `waveStart`
trigger's lines and clips ("Next wave forming up.", "New contacts on the scope.", …), so there are no new
recordings. `comms_moments.dart` maps the event onto that trigger. Pacing classes are unchanged.

### 6.2 Dive re-entry from the fog
Today a diver that leaves the bottom drops back in from the top (`arrivesFromDistance = false`, 0.65 s).

Now it becomes `reentering`:
- It is placed at a deep gate on its side (n 0.12).
- It flies a short swoop (u over 1.1 s · 1/hostileRate) back to its squad's current target.
- It is untargetable until it lands, as today.

The extra 0.45 s off the field makes things slightly easier. It is accepted and measured in §9.

### 6.3 Sentinel rise
The foreshadow silhouette is already in the swarm's far fog. At escort admission (unchanged trigger):
- The escort cloud pours from the silhouette.
- The sentinel rises along a depth path from the silhouette's (x, y, n) to its station over 3.2 s, ease-in-out in
  nearness. Altitude starts high and descends.
- Its `entranceProgress` maps onto that path.

How the rise is composed through soft fog layers (the operator's "slow fade-in through the cloud") is W2's to
draw. W3 guarantees the depth path crosses every band slowly: at least 0.6 s per band.

### 6.4 Level and boss transitions
These are out of scope here (W5b `cinematic-flow`). This change exposes the hooks W5b needs:
- `stream.drain()`: stop releases;
- `stream.rout(direction)`: all present and reserve members switch to a parallel flee into the fog;
- `stream.preload(cohort)`: the next sector's first cohort as reserve silhouettes.

## 7. Sideways facing (`creature_motion.dart`)

- **Thresholds:** `turnEnter` 55 → 38, `turnExit` 24 → 16, `minHold` 0.14 → 0.28 s.
- **Squad heading.** The scene passes each creature's squad lateral velocity. When the squad's |v| ≥ 30 and the
  creature's own vx does not oppose it beyond `turnEnter`, the creature takes the squad's direction. Whole squads
  bank together, as real flocks do.
- **Swoops** cross the arena laterally (§3). Sweeps and mills carry 24–75 u/s (§4).
- **Metric:** the share of drawn ordinary-creature frames with `dir ≠ 0` during `combat`.
  - Baseline first (task 1.2; expected around 15–25 %).
  - Target ≥ 50 % at Normal sector 2 over 60 s.
  - Telegraph, dive and fire poses are excluded (they have their own cells).
- **Sentinels** keep the rotate-and-squash bank. A rendered sentinel bank set and a true profile set (yaw ±70°)
  for ordinary creatures are an optional art follow-up (`plan/swarm-research.md` §6), not in this change.

## 8. Shadows

### 8.1 Creatures
`_swarmShadows` and `_arrivalShadows` merge into `_creatureShadows`.

- **Who.** Every creature with `altitude > 0` and nearness > 0: approaching, present, diving or reentering. Reserve
  members cast none (they are under the fog).
- **Altitude.** The model writes `altitude` for present members too, as a cosmetic channel computed in
  `swarm_patterns.dart`:
  - h_fight = 70 + 30 · (row band) screen units;
  - mill: ring tilt ±12;
  - sweep: dips 10 at the turn ends;
  - ribbon: 14 · sin 2t.

  Divers lose altitude linearly to 0 at the ship's row.
- **Silhouette, offset, softness.** The same as today's `_arrivalShadow`: offset `h · tan 32° · 0.22` along the
  sun, ground slant 0.42, penumbra growth `1 + 0.3k` with k = h / 300.
  - alpha = `0.55 · (1 − 0.4k) · t_ground`, where `t_ground` comes from W2's ground fog accessor (fallback 0.85).
  - Divers get × 1.25.
  - There is **no fade on settling**; the shadow fades only on death (0.3 s).
- **Sway.** Because shadows derive from live pattern positions and altitude, they "shift back and forth as they
  swarm" by construction. On top, the sun azimuth drifts ±4° over 40 s (seeded per sector).
- **Batching.** Group by blur bucket (3). For each bucket: one `saveLayer` with the ink colour filter and blur,
  then a single `drawAtlas` of the cells, so at most three layers per frame. The reduced atmosphere tier uses one
  unblurred layer.

### 8.2 Ship and interplay
- **Ship.** `FlyoverBackground.paintShadow` draws the ship silhouette from the ship-parts hull cell (inked, blur
  bucket 1), at the ship's fixed altitude on the same sun offset. The critter duck reaction stays.
- **Converging tell.** A diver's shadow slides toward the ship's shadow as its altitude falls. This needs no extra
  code; it is the geometry of §8.1. The review frames show it.
- **Shadow over the ship.** If a creature's shadow quad overlaps the ship's hull rect, the ship gets a multiply
  dim of `0.15 · overlap share`. This is capped so the ship's outline contrast stays above the readability floor
  in `plan/atmosphere-research.md` §11. Bullets are never dimmed.
- **Sentinel foreshadow shadow.** While the silhouette circles, a very soft, large shadow (alpha ≤ 0.2, bucket 2)
  sweeps the far terrain. It is gated by `t_ground`, so it disappears in thick ground fog.

Shadows are drawn in the ground pass, under bullets and the ship, as today.

## 9. Determinism, calibration and tests

- **Determinism.** The same seed and the same inputs give identical positions, events and outcomes over a
  full-sector simulation (`test/continuous_swarm_test.dart`). The stream and patterns PRNG is separate from
  `model.random`. A test asserts that the sequence of `model.random` draws is unchanged for a run without
  patterns.
- **Budgets.** `test/difficulty_calibration_test.dart` is unchanged and green.
  `test/reinforcement_pressure_test.dart` keeps its assertions: groups arrive or are accounted for, the escort is
  larger, and the occupancy bound holds.
- **Wave pressure → cohort merge.** `test/wave_pressure_test.dart` is rewritten:
  - the trigger at the threshold;
  - the approaching cohort is untargetable and silent;
  - the approaching roster equals a fresh roster;
  - forced merge versus lull;
  - a lost life pauses the clock and resets q;
  - the last wave brings no cohort;
  - no `RunMode.transition` between the waves of a sector;
  - q shortens the approach for a fast clear and never below `paceFloor`.
- **Pilot metrics.** `test/campaign_playtest_test.dart` gets a metrics recorder: per (mode, route, sector, wave),
  the clear time, hit ratio, peak active (present + approaching), hostile bullets, `dir ≠ 0` share and shadow
  count. Results go to `.cache/swarm-metrics.json`, and a summary goes to `plan/calibration-current.md`.

  **Acceptance against the pre-change baseline** (task 1.1):
  - every campaign completes;
  - per-sector mean ordinary-wave clear time is within +25 % (the existing review trigger);
  - hit ratio drops by no more than 15 %;
  - peak active is ≤ the bound;
  - hostile bullets are ≤ 120.

  If clear time grows too much, tune `swarmTempo` and the mill radius before anything else.
- **Average pilot.** A second, non-invulnerable pilot variant (`AveragePilot`: 0.25 s reaction, 70 % aim, dodges
  nearest shots) records lives lost per sector. It reports and does not fail. Its numbers become the W4
  baseline.
- **Perf.** `test/atmosphere_perf_test.dart` gets a 61-creature combat frame with shadows. Budget: no more than
  +1.5 ms over the baseline frame in the test harness. On the preview, check frame time on a phone (iPhone 12 Pro
  Max is the operator's device).

## 10. Risks
- **Harder to hit.** Moving targets lower the hit ratio, and the tempo knob is the first lever. Easy uses tempo
  0.85, and onboarding uses the hover.
- **Fixtures.** Many tests place demons by hand. The stray fallback keeps hover positions for them. Run the whole
  suite after task 3.
- **W2 merge order.** Both changes edit `scene.dart` near the creature depth sort. W3 touches only shadows and the
  `incoming` → `swarmReserve` read. Rebase onto W2 when it lands. The `Atmosphere` accessor names are agreed in
  §0.
- **Checkpoints.** A restore starts the cohort fresh (reserve rebuilt from the cohort's deterministic split), as a
  wave restart does today.

## 11. Decisions taken on the operator's behalf
1. **Waves stay as invisible accounting** (checkpoints, budget, wave number). Only the presentation of the ladder
   goes. This keeps every calibration guarantee.
2. **Wave 1's long dramatic arrival is kept.** The operator praised it on 2026-11-14.
3. **The release beat survives as a lull** in the stream (no phase, no card). Booth's relax beat is kept without a
   stop.
4. **Visible evasion is cosmetic.** Gameplay dodging is W4's.
5. **No new art in W3.** The existing ±38° banked renders are used. A profile set is an optional follow-up.
6. **No new voice lines in W3.** `cohortSighted` reuses the `waveStart` clips.
