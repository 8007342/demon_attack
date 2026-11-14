# Ground troops on the terrain: research, audit and plan

Round `work/battle-metal-radio-rework` (2026-11-13). The operator: the
flyover relief "looks great", but the ground troops were built quickly and
ignore it. They do not avoid climbs or ravines, and they never jump or climb.
This note has three parts: what the code does today, what other games do,
and the approach we recommend. OpenSpec change:
`openspec/changes/ground-terrain-interaction/`. Visual rules:
[ground-troops-terrain-style-guide.md](ground-troops-terrain-style-guide.md).

The unit classes here are generic on purpose: **infantry, light vehicle,
heavy vehicle, walker**. Another round is designing the gargoyle ground
army (`plan/gargoyle-army-*.md`, `openspec/changes/gargoyle-ground-army/`).
Its units should map onto these four classes, so the two changes can merge.

---

## 1. Current state (audit)

### 1.1 Terrain data that exists at runtime

| Data | Where | Notes |
| --- | --- | --- |
| World heightfield `TerrainField.heightAt(s, w)` | `lib/game/terrain_field.dart:234` | A pure, seeded function: rolling value noise plus one feature per 520-texel segment (`segment`, :154). The lateral frame is the distance from the nearer screen edge line, not a centred world |
| Feature records `TerrainFeature(id, kind, side, w, amp, s, len, width)` | :12, made in `_makeFeature` :168–210, cached per segment | **The only semantic data.** A ridge spans the full width (`side` 2). Valleys and canyons are trenches that run *along* the ground (half-length 235–245, half-width 32 / 21). A mesa is a superellipse plateau. Nothing outside the generator and `TerrainRadio` reads these records |
| Feature shapes | `_featureHeight` :245–297 | Canyon: a flat floor, steep walls from `t` 0.55 to 1, a low rim to `t` 1.7, and depth tapering to 0 at both ends (`ends`). Mesa: a flat top, a cliff from `r` 0.78 to 0.9, and talus to 1.05 |
| Displayed height `TerrainView.rawHeight(x, z)` | :467 | The world height times the envelopes: 62% in the lane (`laneRelief`, :400), 0.6–1 near the camera, fading out between 6·z0 and 12·z0 (`fadeNear`/`fadeFar`, :397), and the two edge frames blended across x 150–210 |
| Screen grid (25 columns × about 100 rows, rebuilt when `cam` changes) | `_ensure` :493–550 | `gridHeight`, `gridY`, `gridShade`, `gridGlow` and a private `_hidden` mask (:510: ground behind a nearer crest). These are the vertices the mesh draws |
| `surfaceAt(x, z)` → height, visible y, `slopeS`, `slopeW`, `hidden` | :591–615 | Slope is computed by central differences of `rawHeight`. Nothing in the ground war calls it |
| `heightAt(x, z)`, `placeAt(x, z)`, `place(...)` | :705, :692, :650 | `heightAt` interpolates the screen grid. `placeAt` returns the visible y plus `climb` and `pace` (0.5–1.25) from heights 10 texels ahead and behind |
| Vegetation | `vegetation*`, `vegetationAt` | Stateful plants that units push over. They do not block anything |

There is **no** slope map, no passability grid, no ravine or cliff mask, no
crossing (bridge or ford) data, and no per-class movement rule. The relief
reaches the model only through the `GroundRelief` interface
(`lib/game/ground_war.dart:636–645`). `FlyoverBackground.advance` installs
it every frame (`flyover_background.dart:113–114`). In pure-model tests and
simulations `ground.relief` is **null**, so the ground there is flat.

Scale check (analytic, displayed slopes as dh/dx in texels per texel, before
the lane and near envelopes):

| Feature | Steepest slope | Reads as |
| --- | --- | --- |
| Rolling hills (two octaves) | ~0.3–0.5 | gentle |
| Forest / crystal / ruins hummocks | ~0.3 | gentle |
| Ridge flank (full width, along w) | ~1.0 (0.6 in the lane) | steep, but the only way through |
| Valley side (across) | ~1.5 | steep sides, a flat welcoming floor |
| Canyon wall (across) | ~9 | cliff (ravine) |
| Mesa edge | ~7 along w, ~20 across | cliff |

### 1.2 How ground units move today

- **Depth is a rule input.** Threat units approach at
  `approachSpeed` 105 texels/s and then creep at 30
  (`ground_war.dart:877–882`). Breakthrough, fire range and homing all read
  `z`. Skirmish units approach at 50–95 texels/s down to a hold line
  (`ground_war_v4.dart:421–423`). Allies move in depth toward a slot or a
  foe at 150 / 90 texels/s (`ground_war.dart:1176–1195`). **Terrain never
  changes depth speed.**
- **The lateral route is a one-row probe.** Every 1.8–4.4 s `_v4Route`
  (`ground_war_v4.dart:622–655`) scores 7 lateral probes 42 units apart at
  the unit's **current depth only**. The cost is
  `relief.heightAt(px, u.z) / 7` (:634) plus crowding, flanking and wander.
  `_v4Steer` (:662–681) eases toward the goal at the class's lateral speed.
  It never looks ahead, so a unit only reacts to a mesa once it is already
  on the mesa's row.
- **Bug: ravines attract units.** The cost is the raw height, so a canyon
  floor (−52 to −68 texels, a cost of about −8 to −10) is the *cheapest*
  probe there is. Units steer into ravines on purpose. The legacy band
  placement `place()` has the same soft-min on `h / 9`
  (`terrain_field.dart:661–676`).
- **Allies ignore terrain laterally.** `_v4Convoy`
  (`ground_war_v4.dart:684–727`) steers to the slot, or to the foe ±30,
  plus spreading. It has no terrain term.
- **Placement.** `_placeGroundOnTerrain` (`ground_war.dart:951–966`) asks
  `placeAt(lx, z)` for every unit and ally once per step. `x` and `y`
  come from the pose (`ground_war.dart:391–396`, :474–477).
- **The climb sign is wrong for the convoy.** `climb` is "uphill toward the
  camera" (`terrain_field.dart:684`, :699). Demons travel toward the
  camera, so the sign is correct for them. Allies hold a fixed depth while
  the ground scrolls under them at 13 texels/s (`baseSpeed` 26 / 2,
  `flyover_background.dart:86`, :130). Relative to the ground they travel
  *away* from the camera, so their uphill is `climb < 0`. The tread rate
  (`ground_painter.dart:536`), the extra climb dust (:546–547) and the
  `convoyClimbing` and `convoyStuck` radio events
  (`terrain_field.dart:885–905`, called from `flyover_background.dart:860`)
  therefore fire while the convoy is going *downhill*. This needs a test
  to pin it down. The fix is to report the slope along each unit's own
  direction of travel.
- **Hidden ground.** Rows hidden behind a nearer crest collapse onto the
  crest line (`_ensure`, :507–511), and `yOf` returns that line. A unit in
  a dip behind a ridge is therefore drawn standing *on the crest*, fully
  visible. It should be partly hidden by the crest.

### 1.3 How they look on the terrain today

- Demon squads (`ground_painter.dart:333–388`): 4 walk frames, aim, fire,
  hit, topple and rubble. One dust puff while moving. There is no slope
  pose, no climb, no jump and no wade.
- Demon heavy tank (:390–420) and sector vehicles: 4 move frames, two dust
  puffs, and no pitch.
- Allies: the tread rate scales with `pose.pace`, and dust grows with
  `pose.climb` (inverted, see above). Infantry have walk, run, kneel and
  volley frames.
- **No contact shadow** under any ground unit (`shadow` does not occur in
  `ground_painter.dart`). On lit slopes units look pasted on.
- Atlases: `ground-troops.png` has 12 × 6 cells of 32 × 24 texels, and
  columns 9–11 are free on every unit row (`ground_troops_atlas.dart`).
  `ground-forces.png` has 16 × 16 cells of 40 × 32 texels. Demon rows use
  columns 0–9 and ally rows use 0–12. Frames are authored on the texel grid
  in Go (`tools/ground_troops/build.go`: `pose` :148, `rowFrames` :731,
  `rotate` :560). One ComfyUI keyframe per unit only adds −1/0/+1 shading
  (`aiTexture` :591).
- `plan/terrain-relief.md` still names `GroundPainter._climbDust`, which no
  longer exists (the climb dust is now inline in the ally painter).

### 1.4 Constraints to keep

- **Same threat.** Threat units' depth, schedule, breakthroughs and
  missiles must not change. Their lateral weave stays inside their side
  band (ground-war-v4). Skirmish units keep their own random stream.
- **Phone budget.** The busy v4 ground war costs 1.1–2.7 ms per frame
  (model plus recording, 1080 × 2340; `ground_war_v4_visual_test.dart`).
  Live units: threat ≤ 3, skirmish ≤ 6, convoy ≤ 6, so about 15 movers in
  total.
- **Determinism.** No new random draws in the threat front. Navigation
  must be a pure function of (sector, route, cam, x, z, class).

---

## 2. Research

### Flow fields and cost fields

Supreme Commander 2 and Planetary Annihilation move large crowds with
**flow fields**. A per-cell **cost field** (higher means less comfortable or
slower) feeds an **integration field**: a Dijkstra flood from the goal that
gives the travel cost to the goal from each cell. Its gradient gives each
cell a direction, and agents steer by bilinearly blending the four nearest
cell vectors. Impassable cells get a maximum value and no vector. SC2 and PA
**tile** the field to save memory and build time.
[howtorts: basic flow fields](https://howtorts.github.io/2014/01/04/basic-flow-fields.html),
[Wildfire Games forum on flow fields](https://wildfiregames.com/forum/topic/17161-flow-fields-for-pathfinding),
[Warzone 2100 forum summary](https://forums.wz2100.net/viewtopic.php?p=134867),
[Emerson, "Crowd Pathfinding and Steering Using Flow Field Tiles", Game AI Pro 360](https://www.taylorfrancis.com/books/9780429100277/chapters/10.1201/b16725-29),
[bevy_flowfield_tiles_plugin (cites Emerson)](https://docs.rs/crate/bevy_flowfield_tiles_plugin/latest/source/README.md),
[howtorts: continuum crowds caveat](https://howtorts.github.io/2014/01/09/continuum-crowds.html).
Grids tie a lot, and a slight random jitter in costs smooths the artifacts
([Red Blob Games, all-pairs](https://www.redblobgames.com/pathfinding/all-pairs/)).
Weighted costs (water costs ten times grass) need Dijkstra, not plain
breadth-first search
([Red Blob Games, A* introduction](https://www.redblobgames.com/pathfinding/a-star/introduction.html)).

**Takeaway.** Our units share a direction of travel (demons toward the
camera, the convoy up the plane), so one integration field per movement
class is enough. With one shared goal (the near edge, or the slot row), a
flow field costs the same for 1 unit or 15, and it looks ahead by
construction.

### Cost maps from slope; separate passability grids

- Planners compute a slope magnitude per cell and threshold it against
  each vehicle's pitch limit to decide what is navigable
  ([CMU, heading-specific slope](https://www.ri.cmu.edu/publications/planetary-mission-preplanning-with-heading-specific-slope-and-distance-from-shadow)).
  Traversability stacks weight slope, step height and roughness, and
  saturate to "impassable" at per-agent limits
  ([terrain_toolkit traversability](https://aleskucera.github.io/terrain_toolkit/traversability/)).
- 0 A.D. builds a finer **navcell** passability grid per movement class
  (water depth, slope, and so on), because its terrain tiles are too coarse
  to show narrow gaps. The long-range pathfinder runs on that grid
  ([0 A.D. pathfinder design, tex](https://gitea.wildfiregames.com/Itms/0ad/raw/branch/main/docs/pathfinder.tex),
  [PDF mirror](https://svn.science.uu.nl/repos/edu.3803627.INFOMOV/0AD/docs/pathfinder.pdf)).
- Slope-to-multiplier cost functions with a hard cap
  ([eikonal crate cost.rs](https://docs.rs/crate/eikonal/0.1.0/source/src/cost.rs)).

**Takeaway.** One cost table per movement class, with slope thresholds and
**semantic tags** that override slope. A canyon floor is flat, so slope
alone would call it passable. Our 25-column mesh is too coarse for
42-texel canyons at depth, which is the 0 A.D. lesson. So we tag from the
analytic feature records, not from the raster.

### Cliffs, climbers and jump links

- StarCraft II paints pathing as walkable, **climbable** and inaccessible.
  Reapers jump and Colossi walk over climbable cliffs but not over
  inaccessible gaps. A unit flagged "cliff jumper" without the matching
  pathing still runs at the cliff and gets stuck
  ([sc2mapster on reaper jumps](https://www.sc2mapster.com/forums/development/miscellaneous-development/176462-how-to-make-reapers-jump-a-valley?comment=1),
  [Liquipedia Colossus: Cliff Walk](https://liquipedia.net/starcraft2/Colossus_(Legacy_of_the_Void)),
  [Liquipedia Reaper](https://liquipedia.net/starcraft2/Reaper)).
- Navmeshes model jumps, ladders and climbs as **off-mesh links**: explicit
  point-to-point edges. A navmesh's "walkable climb" only covers small
  steps, and higher ledges need links
  ([A* Pathfinding Project forum](https://forum.arongranberg.com/t/walkable-climb-should-be-less-than-walkable-height/3399),
  [Recast graph with off-mesh links](https://www.arongranberg.com/astar/docs/example_recast_offmeshlinks.html)).
  Unity generates jump links automatically by walking navmesh edges and
  keeping a jump only if its landing spot is on the navmesh, padded by
  about 2 × the agent radius
  ([Unity manual: building off-mesh links automatically](https://docs.unity3d.com/ru/2020.1/Manual/nav-BuildingOffMeshLinksAutomatically.html)).
  Mononen (Recast) gives the same advice: candidates sit on navmesh edges,
  and checking the landing spot culls most of them
  ([recastnavigation group](https://groups.google.com/g/recastnavigation/c/oNvcV1K0CWY)).

**Takeaway.** Passability is **per class** (climbable vs inaccessible). Each
jump, climb, ford or bridge is a **link** with its own animation, generated
deterministically from the features (canyon to bridge or ford, mesa to
climb line, ridge crest to hop). A unit only uses the links its class owns.

### Choke points, fords and bridges

Choke points make the AI clump its troops
([Total War chokepoint tactics](https://recapio.com/digest/utilize-chokepoints-to-destroy-a-larger-force-total-war-tactics-warhammer-3-by-zerkovich)).
Fords slow troops
([Total War wiki: Mastering Battles](https://wiki.totalwar.com/w/Mastering_Battles.html)).
Bridge battles hinge on the crossing points
([Encyclopedia of War: bridge battles](https://encyclopedia-of-war.shoutwiki.com/wiki/Bridge_battles)).
AI units that only follow local rules hug walls on bridges and pile up
([Warhammer 2 discussion](https://steamcommunity.com/workshop/filedetails/discussion/1182188528/1743346190289489186),
[Rome II discussion](https://steamcommunity.com/workshop/filedetails/discussion/362473569/4357871368303663075)).
Groups get through clutter better by sharing one backbone path and then
spreading by clearance
([Kamphuis & Overmars 2004](https://ics-websites.science.uu.nl/docs/vakken/mcrws/papers_new/Kamphuis_Overmars%20-%202004%20-%20Finding%20paths%20for%20coherent%20groups%20using%20clearance.pdf)).
Reynolds-style separation still handles local spacing
([AI for Game Developers, flocking](https://oreilly.com/library/view/ai-for-game/0596005555/ch04.html)).

**Takeaway.** Give each link a **capacity** (a bridge takes one vehicle at a
time, a ford two). Units queue at the approach in a short column and then
spread out again. The bunching *is* the readable moment, and it earns a
radio line.

### Visual tells

- **Blob shadows** ground characters and serve as a landing guide while
  they are airborne. Scale or fade the blob with height, and keep it off
  the feet
  ([Infinity Nikki shadow analysis](https://engineered.at/articles/infinity-nikki-mysterious-shadow-drop),
  [Unreal: dynamic blob shadow](https://forums.unrealengine.com/t/dynamic-blob-shadow/56816),
  [Godot SimpleShadow2D, stepped falloff](https://godotengine.org/asset-library/asset/5282)).
- At low resolution, motion lives in 1–3 pixel shifts. Lean and
  anticipation beat realism, and a solid fill of the silhouette must still
  read
  ([sprite-ai: animation principles](https://www.sprite-ai.art/guides/animation-principles),
  [pixel-art sprite skill notes](https://skillselion.com/skills/omer-metin/skills-for-antigravity/pixel-art-sprites)).
  Separate "up" and "down" poses read better than one shared pose
  ([Zegley devlog](https://zegley.itch.io/2d-platformermetroidvania-asset-pack/devlog/673495/theme-updates-slide-animation-and-wip-animations)).
  Foot travel must match the slope that the body's shading implies
  ([PixelJoint critique](https://pixeljoint.com/forum/printer_friendly_posts.asp?TID=16787)).
  A climb whose body just deforms inside a square box does not read as a
  climb ([itch.io comment](https://itch.io/post/7453826)).
- Rotating a pixel sprite by a free angle breaks it
  ([Godot Q&A](https://godotengine.org/qa/144998/pixelart-sprite-looks-bad-when-on-an-angle)),
  and this repo's style guide forbids smooth filtering. So slope poses are
  **authored pitch frames**, never runtime rotation.

---

## 3. Recommended approach

### 3.1 The shape of the problem (why this is cheap)

Our units do not need general 2-D pathfinding:

1. **Depth is prescribed.** Threat units are ruled by depth, so terrain may
   never stall them. Skirmish units and allies may be *slowed* by terrain,
   because their depth is not a threat rule (the hold line and the slot
   are).
2. **Everything travels along one axis.** Demons travel toward the camera
   and the convoy travels up the plane. The only free choice is the
   **lateral** column at each depth.
3. **The world scrolls at 13 texels/s.** What will be under a unit in *t*
   seconds is predictable. For an ally at fixed depth it is the ground now
   at `z + 13t`. For a demon approaching at speed `v`, it is the ground now
   at `z − (v − 13)t`.

So the "flow field" is a **lateral integration field over a small
screen-aligned lattice**: columns at fixed screen x, rows at fixed depths.
For each movement class and travel direction we run one backward dynamic
program (a Viterbi, the 1-D case of a Dijkstra flood with a single goal
row). It gives every cell the best next column. Units read their cell's
best column as their lateral goal: look-ahead with no per-unit search.

### 3.2 `GroundNav` (new, `lib/game/ground_nav.dart`, pure)

**Lattice.** 48 columns (7.5 units apart, x 4–356) × 36 rows at fixed
depths from z 200 to 1400, spaced so rows are about 8 screen units apart
on the flat (the same law as `TerrainView._rows`). That is 1 728 cells.

**Per cell, refreshed incrementally:**

| Field | Source | Cost |
| --- | --- | --- |
| `h` displayed height | `TerrainView.rawHeight(x, z)` (what the player sees) | 1 728 evaluations per full rebuild |
| `slope` = max(\|dh/ds\|, \|dh/dw\|) | Finite differences on the lattice, in texels per texel | free |
| `tag` bit set | **Analytic**, from the 3 nearby `TerrainFeature`s: `ravine` (canyon with `t < 1.05` and `ends > 0.25`), `cliff` (mesa with `0.76 < r < 0.92`), `plateau` (mesa top), `valleyFloor` (`t < 0.6`), `crest` (ridge with `\|w − crest\| < 0.15·width`), `brush` (forest / crystal / ruins), `lane` | 3 feature tests per cell |
| `link` id | See 3.4 | — |

**Refresh budget.** Rebuild 1/6 of the rows per model step, so the full
lattice is fresh every 6 steps (0.1 s at 60 Hz). The terrain moves 1.3
texels in that time, under one tenth of a row. That works out to about 290
height evaluations per step, the same order as one vegetation pass. The
tags come from cached feature records. Target: **≤ 0.15 ms per step on a
mid phone**, checked in the perf test.

**Why tags are analytic.** At z 1000 one 7.5-unit column covers 22 texels,
and a canyon floor is about 20 texels wide. A raster would alias canyons
in and out of existence from frame to frame. The feature records are exact
and stable. This is 0 A.D.'s navcell lesson, applied without building a
finer grid.

### 3.3 Movement classes

| Class | Who today (map from `GroundForce` and the atlas kinds) | Walk ≤ | Climbs ≤ (slow, climb pose) | Impassable | Own links |
| --- | --- | --- | --- | --- | --- |
| **infantry** | demon grunts and rocket brutes; allied rifle and rocket squads; ally `militia` | 0.45 | 2.5 (scramble) | > 2.5, `ravine` except at links, `cliff` except at a climb line | jump-down (drop ≤ 14 texels), climb line, ford, bridge |
| **light vehicle** | demon `buggy`; ally `rover`, `apc`, `halftrack` | 0.35 | 0.75 | > 0.75, `ravine`, `cliff` | ford, bridge, crest hop (visual) |
| **heavy vehicle** | demon `crawler`, `tower`, `heavyTank`; ally `mbt`, `spg`, `heavy` | 0.30 | 0.60 | > 0.60, `ravine`, `cliff`, `plateau` | bridge (rated heavy), shallow ford |
| **walker** | demon `beast`; ally `mech` | 0.50 | 1.6 (stride climb) | > 1.6, `ravine` | stride-over (ravine ends with `ends < 0.5`), ford, bridge |

Thresholds use hysteresis: a unit enters the climb state at the threshold
and leaves it at 0.8 × the threshold. A ridge flank (up to 1.0) is
"climb" for infantry and walkers and "too steep" for vehicles. Ridges span
the full width and are lowest in the lane (62% envelope), so vehicles
funnel to the saddle. **That is our natural choke point.**

**Cost per cell (per class).** `1` + `k_s · max(0, slope − walk)` +
`valleyFloor ? −0.15 : 0` + `brush ? 0.2 : 0` (0.05 for heavy vehicles,
which flatten it) + `crest ? 0.1 : 0` (a skyline penalty) + a
lateral-move cost of `0.4 · |Δcol|`. Impassable cells cost `1e4`, never
infinity. That way the DP always returns *some* best column, and a unit can
never be trapped (see 3.5). The cost uses **no height term**, which removes
the "ravines are cheapest" bug.

### 3.4 Links (deterministic, from the features)

| Link | Made from | Who | Capacity | Visual |
| --- | --- | --- | --- | --- |
| **Bridge** | each canyon: one per canyon at `along = ±(0.15…0.45)` seeded by feature id | all classes (heavy only if the sector rates it heavy: Krybor, Ringfall, Hollow and Carrier yes, Ember no) | 1 vehicle or 1 squad | new bridge prop sprite on the mesh (Phase 3). Until then, a ford at the same spot |
| **Ford** | both canyon ends, where `ends < 0.25` (depth ≤ 25% of amp) | infantry, light, walker; heavy only where `ends < 0.12` | 2 | sector material splash (ice spray, dust, cinders, mire, ichor), wade pose |
| **Climb line** | every mesa: 2 lines on its long sides | infantry, walker | 2 | climb pose, pebble trickle |
| **Jump-down** | mesa talus and canyon rim, drops ≤ 14 texels | infantry only, downhill only | — | crouch, air, land |
| **Crest hop** | ridge crest at `slope < 0.75`, light vehicle at full pace | light vehicle (visual only) | — | 2–4 texel airborne arc, shadow stays on the ground |

Links are edges in the DP: a `ravine` cell that holds a link costs the
link's cost instead of `1e4` for the classes that own it. Capacity is
enforced by a small reservation table (`linkId → occupant ids`). A unit
that wants a full link gets its depth speed held, if it is a skirmish unit
or an ally (the queue), or keeps going laterally, if it is a threat unit
(see 3.5).

### 3.5 Who obeys what

| Unit | Lateral goal | Depth speed | When blocked |
| --- | --- | --- | --- |
| Threat unit | `GroundNav` column, clamped to its side band (as now) | **unchanged** (a rule) | If the whole band row is impassable for its class, it takes the cheapest cell and shows the **grind** state (slow anim, heavy dust). Over a ravine it uses the ford pose. Never stalled |
| Skirmish unit | `GroundNav` column, full width, blended with flank and spread (existing `_v4Route` terms, minus the height term) | × `pace` (0.55–1.0, from the class cost of the cell ahead) | Queues at the link; after 3 s it falls back to the cheapest cell (grind). The hold line still rules |
| Convoy ally | slot x or foe x, **projected onto the nav field**: the nearest column whose cost along its own look-ahead is under `1e3` | engaged advance × `pace` | Queues at the link (convoy bunching) |

**Rules unchanged.** Threat depth, fire range, breakthroughs, missiles,
pressure and allied strength stay as they are, and nothing draws from
`model.random`. The skirmish layer keeps its own random stream. With
`ground.relief == null` everything behaves as it does today.

### 3.6 Climb sign, hidden ground, poses

- `GroundPose` gains `slopeAlong` (signed, along the unit's own travel:
  toward the camera for demons, and up the plane for allies when
  `vz + 13 > 0`), `slopeAcross`, `state` (walk / climb / descend / jump /
  ford / bridge / grind / avoid) and `hidden` (with `crestY`). `climb`
  stays as a deprecated alias equal to `slopeAlong`, so the painter and
  `TerrainRadio` read the right sign.
- A unit on hidden ground is drawn at its **true** ground y and clipped
  above the crest line (one `clipRect` each, at most about 15). No more
  units standing on top of ridges they are actually behind.

### 3.7 Presentation

The style guide covers this. In summary: authored pitch frames (−1, 0, +1)
and climb, jump, wade and brace frames per class; a stepped pixel contact
shadow; dust whose direction follows the slope; ford splashes in the
sector's material; queue and hold poses at links. States appear only
nearer than z 900 (LOD), and a state is held for at least 0.35 s.

### 3.8 Radio (new rate-limited events)

`convoyFording`, `convoyBridge` (a queue of ≥ 2 at a link), `troopsClimbing`
(a squad on a climb line, near) and `enemyDetour` (a demon heavy turns away
from a ravine). Each carries `{sector, side, x, y}` and is spaced at least
15 s apart. Comms owns the lines.

### 3.9 Performance budget

| Item | Budget (mid phone) | Notes |
| --- | --- | --- |
| Lattice refresh | ≤ 0.10 ms per step | 1/6 of the rows per step |
| DP per class | 4 classes × 2 directions × 1 728 cells × 3 neighbours, only when the lattice is fresh: **0.05 ms**, amortised over 6 steps | `Float32List`s, no allocation |
| Unit queries | 15 × O(1) | read the cell's next column and pace |
| Painter | +1 shadow draw, +≤ 15 `clipRect`, +particles inside existing caps | the shadow goes in the existing ground `drawAtlas` batch where possible |
| Total | **≤ 0.25 ms per frame on top of 1.1–2.7 ms** | asserted in `ground_war_v4_visual_test.dart` |

### 3.10 Rejected alternatives

- **Full 2-D A\* per unit.** Not needed, because depth is prescribed. It
  would also cost 15 searches per re-plan.
- **A navmesh with off-mesh links.** The terrain is endless and morphs
  during travel, and baking a navmesh at runtime is far beyond the budget.
  We keep the *idea* of links.
- **Rotating sprites to the slope.** It breaks pixel art and the style
  guide.
- **Changing the generator** (wider canyons, lower ridges). The operator
  likes the terrain. Units adapt to it, not the other way round.
- **Owning the relief in the model.** That would make simulations see the
  terrain, but it means moving the flight clock out of
  `FlyoverBackground`. It is deferred: tests install a headless
  `TerrainView` with a scripted `cam`, as `terrain_relief_test.dart`
  already does.

### 3.11 Phases

1. **Nav core.** `GroundNav` lattice, tags, class table, DP, the
   ravine-attraction fix, the climb sign, unit and ally integration, tests.
2. **States and tells.** Pose states, hidden-ground clipping, contact
   shadow, slope dust, ford splash, LOD and hysteresis, radio events.
3. **Art.** Pitch, climb, jump, wade and brace frames in
   `tools/ground_troops` and the ground-forces pipeline; a bridge prop per
   sector.
4. **Merge** with `gargoyle-ground-army`: map its units onto the four
   classes.

## Sources

Everything cited inline above.
