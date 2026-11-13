# Design: ground troops that read the terrain

The research, the full audit with file:line references, and the rejected
alternatives are in `plan/ground-terrain-interaction.md`. The visual rules
and frame lists are in `plan/ground-troops-terrain-style-guide.md`. This
file records the decisions and the numbers.

## Principle: rules stay on depth
The gameplay boundary from `add-terrain-relief` and `ground-war-v4` holds:

| Unit | Terrain may change | Terrain may never change |
| --- | --- | --- |
| Threat unit | lateral x inside its side band, pose, state | depth `z` and its speed, fire range, breakthrough, telegraph, missiles, pressure, allied strength |
| Skirmish unit | lateral x across the plane, depth speed (× pace), queueing | hold line, hp, fire timing, its random stream (navigation draws no random numbers) |
| Convoy ally | lateral x, engaged advance speed (× pace), queueing | slot depths, hp, fall-back and repair |

With `ground.relief == null` (pure model tests and simulations), every code
path is the current one.

## Navigation lattice (`GroundNav`, `lib/game/ground_nav.dart`)
- **Grid.** 48 columns at x = 4 + 7.5·i, and 36 rows at fixed depths from
  z 200 to 1400, spaced like `TerrainView._rows` (about 8 flat screen units
  apart). The arrays are `Float32List`/`Uint16List` and are allocated once.
- **Height.** `TerrainView.rawHeight(x, z)`: the displayed height, so units
  avoid what the player sees. 1/6 of the rows are refreshed per model step,
  so the whole grid is at most 0.1 s stale. The ground scrolls 1.3 texels
  in that time.
- **Slope.** max(|dh/ds|, |dh/dw|) by finite differences on the lattice,
  converted to world texels with `TerrainView.lateral`.
- **Tags.** From the up to 3 `TerrainFeature`s near the cell (`feature(j−1..j+1)`),
  evaluated with the generator's own shape parameters:

| Tag | Test |
| --- | --- |
| `ravine` | canyon, `t < 1.05` and `ends > 0.25` |
| `cliff` | mesa, `0.76 < r < 0.92` |
| `plateau` | mesa, `r ≤ 0.76` |
| `valleyFloor` | valley, `t < 0.6` and `ends > 0.3` |
| `crest` | ridge, `|w − crest| < 0.15·width` |
| `brush` | forest / crystalField / ruins footprint |
| `lane` | `GroundCamera.laneLeft ≤ x ≤ laneRight` |

`TerrainField` gains `tagsAt(s, w)`. It is pure and uses the same lateral
frame and centre blend as `rawHeight`: left and right tags are OR-ed where
the two edge frames blend, in x 150–210. Analytic tags are needed because
at z 1000 a 7.5-unit column covers about 22 texels, the width of a canyon
floor, so a raster would alias.

## Movement classes

| Class | Walk ≤ | Climb ≤ | Impassable | Links |
| --- | --- | --- | --- | --- |
| infantry | 0.45 | 2.5 | slope > 2.5; ravine and cliff except at links | bridge, ford, climb line, jump-down |
| light vehicle | 0.35 | 0.75 | > 0.75; ravine; cliff | bridge, ford, crest hop (visual) |
| heavy vehicle | 0.30 | 0.60 | > 0.60; ravine; cliff; plateau | heavy bridge, shallow ford |
| walker | 0.50 | 1.6 | > 1.6; ravine | bridge, ford, stride-over |

Mapping: `GroundForce.infantry` and `GroundForce.rockets` → infantry.
`GroundForce.heavyTank` → heavy. `GroundForce.vehicle` by sector kind:
buggy → light, crawler → heavy, beast → walker, tower → heavy. Allies by
`ground-forces.json` kind: rover, apc, halftrack → light; militia →
infantry; mbt, spg, heavy → heavy; mech → walker. A `MoveClass` enum and a
`moveClassOf(force, sector, ally, variant)` function are the single source
of truth. The gargoyle ground army adds rows to that function only.

Slopes are displayed texels per texel (envelopes included). The analytic
maxima are: rolling ~0.4, ridge ~1.0 (0.6 in the lane), valley side ~1.5,
canyon wall ~9, mesa edge 7–20. A ridge is therefore a climb for
infantry and walkers and too steep for vehicles outside the lane. Vehicles
funnel to the lane saddle, and that is the intended choke point.

## Cost and the lateral flow field
Cell cost for class `c`:
`1 + 3·max(0, slope − walk_c) + (valleyFloor ? −0.15 : 0) + (brush ? 0.2 : 0)`
(0.05 for heavy vehicles) `+ (crest ? 0.1 : 0)`. Impassable cells cost
`1e4`; link cells cost the link's cost for the classes that own the link.
There is **no height term**, which fixes the ravine attraction.

For each class and each travel direction (toward the camera for demons,
and up the plane for allies, relative to the scrolling ground), one
backward pass from the goal row computes, per cell,
`J[r][i] = cost[r][i] + min_{|Δ|≤L_c} (J[r'][i+Δ] + 0.4·|Δ|)`, where `r'`
is the next row in travel order and `L_c` is the column reach per row for
the class's lateral speed (infantry 1, light 3, heavy 2, walker 2). The
pass stores `next[r][i]`. It reruns whenever a refresh cycle completes.
That is 4 classes × 2 directions × 1 728 cells × at most 7 candidates,
about 0.05 ms amortised.

**A unit's goal column** is the `next` chain followed for the look-ahead
time `T_c` (heavy 2.5 s, light 1.5 s, infantry and walker 1.2 s),
converted to rows by the unit's relative ground speed. That is
`v − 13` texels/s for demons and `13 + vz` for allies. The existing
flank, spread, convoy-pull and wander terms in `_v4Route` are kept and
added to the field cost of the candidate. The height term at :634 is
removed.

**Pace.** `pace = clamp(1 − 0.35·max(0, slopeAlong − walk_c)/(climb_c − walk_c), 0.55, 1)`.
Skirmish and ally depth speeds are multiplied by `pace`. Threat units are
not.

## Links
Generated per feature, deterministically, with `terrainRand(seed, feature.id, salt)`:

| Link | Placement | Classes | Capacity | Cost |
| --- | --- | --- | --- | --- |
| bridge | 1 per canyon, `along = ±(0.15 + 0.3·rand)` | all (heavy only in sectors 1, 2, 4, 5) | 1 | 1.5 |
| ford | 2 per canyon, at the ends with `ends < 0.25` (heavy only where `ends < 0.12`) | infantry, light, walker, heavy (shallow) | 2 | 2.0 |
| climb line | 2 per mesa, on its long sides | infantry, walker | 2 | 3.0 |
| jump-down | canyon rim or mesa talus with a drop ≤ 14 texels, downhill only | infantry | — | 1.2 |
| crest hop | ridge crest with slope ≤ 0.75 | light vehicle (visual state only, no cost change) | — | — |

Capacity is a reservation table `Map<int, List<int>>` (link id → unit
ids). It is cleared per level. A unit that is refused waits on its
approach cell (state `queue`), in a column spaced 0.6 × its width. After
3 s it takes the cheapest non-link cell (state `grind`). Until the bridge
art lands (task 4.3), bridges are shown as fords.

## Blocked threat units
A threat unit's band can be fully blocked near the camera: at z 220 the
band is about 61 texels and a canyon with its rim about 71. It then takes
the cheapest cell in its band and shows `ford` over a ravine and `grind`
elsewhere. Its depth is unchanged, so breakthrough timing and the missile
dodge stay calibrated. This is the only case in which any unit stands on
a ravine cell without a link.

## Poses
`GroundPose` gains:
- `slopeAlong`: signed, along the unit's own travel.
- `slopeAcross`.
- `state` (`GroundMoveState`).
- `hidden` and `crestY`.

`climb` is kept as an alias of `slopeAlong`, so `TerrainRadio.ally` and the
tread and dust code read the corrected sign. `placeAt` takes the travel
direction. States use hysteresis (enter at the limit, leave at 0.8 × it) and
are held for at least 0.35 s. They are computed only when z < 900; further
out the state is `walk`.

Hidden ground: `TerrainView` exposes `trueY(x, z)` (the unclamped
projection) and `crestY(x, z)` (the clamped one). The painter draws the
unit at the true y and clips to `y < crestY`. The contact shadow is clipped
too.

## Radio
In a `// --- ground terrain` block in `game_events.dart`, emitted through
`dispatchGameEvent` in combat only, with `{sector, side, x, y}`:

| Event | When | Gap |
| --- | --- | --- |
| `convoyFording` | an ally enters a ford, near (z < 700) | 15 s |
| `convoyBridge` | ≥ 2 allies queued at one link | 20 s |
| `troopsClimbing` | an allied squad on a climb line, or a slope climb that lasts ≥ 0.6 s | 15 s |
| `enemyDetour` | a demon heavy's goal moves by > 40 units because of a ravine or cliff, near | 20 s |

## Performance
- Budget: ≤ 0.25 ms per frame added, on top of 1.1–2.7 ms
  (`ground_war_v4_visual_test.dart` at 1080 × 2340). The test asserts the
  total stays below 16 ms and logs the nav share.
- No allocation per step. The lattice is refreshed incrementally. The DP
  runs only when a refresh cycle completes.
- The painter adds 1 shadow cell per unit (drawn in the same pass as the
  unit), at most 15 `clipRect`s, and particles inside the existing caps
  (tracers ≤ 48, vegetation particles ≤ 160; terrain dust ≤ 3 per unit).

## Merging with `gargoyle-ground-army`
That change should express each new unit as a `MoveClass` (and, if needed,
extra links it owns), and take its pose frames from the per-class lists in
the style guide. Nothing in this change names a faction except the
existing `GroundForce` mapping.
