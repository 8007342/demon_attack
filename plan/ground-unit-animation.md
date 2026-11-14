# Ground units: headings, turrets and animation sets

The frame contract for the reworked ground war: how many headings each unit has, how frames are named and laid out in the atlases, how the runtime picks and blends headings, how turrets rotate on their own, and the full animation set per unit for both armies. OpenSpec change: `openspec/changes/ground-forces-rework/`. Art direction: [human-ground-forces-style-guide.md](human-ground-forces-style-guide.md) (the Ground Fleet) and [gargoyle-army-style-guide.md](gargoyle-army-style-guide.md) (the Undercroft Host). Render plan: [render-runs/ground-forces-rework.md](render-runs/ground-forces-rework.md).

The rules that do not change:
- Pixel art on a texel grid, one PNG pixel per texel, drawn nearest-neighbour (`FilterQuality.none`). **Sprites are never rotated or smooth-scaled at runtime.** Every heading is an authored cell. (Quarter turns of debris pieces are the one exception: they are lossless.)
- Units are bottom-centred on the cell's last row, as today, and drawn through `GroundCamera` / `placeAt`.
- Presentation only. Headings, turrets and animation states read simulation state and never change it, and never draw from `model.random`.

---

## 1. Where this comes from: how the ship and the gargoyles turn

| Thing | How it turns today | Code |
| --- | --- | --- |
| Player ship | A continuous `shipBank` eases toward `shipVx / 330` at rate 16/s; the painter rotates the canvas by `bank × 0.14` rad and squeezes it by `1 − |bank| × 0.14`, plus a counter-thruster puff | `model.dart` (shipBank), `scene.dart` `_playerShip` |
| Gargoyles | Discrete authored frames: bank left, neutral, bank right. `CreatureMotion` smooths velocity, then switches `dir` with hysteresis (`turnEnter` / `turnExit`) and a minimum hold (`minHold`), so the frame never flickers | `creature_motion.dart`, `sprite_atlas.dart` |
| Allied turrets | Five authored screen angles (0°, 22.5°, 45°, 67.5°, 90°), mirrored; the nearest one toward the foe | `ground_atlas.dart` (`allyTurretAngles`), `ground_painter.dart` `_aim` |
| Ground hulls | **One** heading. Demons are side-on facing right and snap to a mirror when they cross; allies always face straight up the plane | `ground_painter.dart` |

The ground war borrows the gargoyle approach (smoothed motion, then discrete authored frames with hysteresis and a hold), not the ship's canvas rotation, because ground sprites must stay on the grid. To get the ship's feel of "leaning into a turn", a turn plays **through every intermediate heading**, one step at a time, with a skid-dust puff on the outside of the turn.

## 2. Heading sets

Headings are **screen angles of the unit's nose**, measured like `allyTurretAngles`: 0° points straight up the plane (toward the horizon), 90° points to screen right, 180° points straight down the plane (toward the camera). Negative angles are the mirror image. Each faction authors one quadrant-and-a-bit and mirrors the rest.

| Faction | Authored headings (index h0–h4) | Mirrored | Distinct headings | Why this arc |
| --- | --- | --- | --- | --- |
| Ground Fleet | 0°, 22.5°, 45°, 67.5°, 90° | −22.5° … −90° | 9 | The convoy drives up the plane and steers across it; it backs up to fall back (reverse treads), it never turns round |
| Undercroft Host | 90°, 112.5°, 135°, 157.5°, 180° | −90° … −157.5° | 9 | The Host comes down the plane toward the convoy; 90° is today's side-on frame, 180° charges the camera |
| Host infantry | 45°, 90°, 135° | −45° … −135° | 6 | Side-on as today, plus a front three-quarter for the advance and a rear three-quarter for a rout |
| Fleet infantry | 0°, 45°, 90° | −45°, −90° | 5 | From behind as today, plus back three-quarter and side |
| Chapterhouse | 90°, 135°, 180° | −90°, −135° | 5 | Octagonal and symmetric: fewer headings read the same |

A heading outside the authored arc is **clamped** to the nearest authored heading (a routing Host vehicle at 60° uses 90°; a Fleet vehicle reversing at 120° keeps its last heading and runs its treads backward).

**Why 22.5°.** It is the existing turret step, so the hull and the turret share one angle grid, and one step changes at least 2 texels of silhouette at the far scale (×0.62), which the terrain guide sets as the visibility floor. 45° steps were tried on paper: a 90° turn would be only two frames and would pop. 11.25° steps would double the art for changes smaller than a texel at mid-field.

## 3. Frame naming

Every cell has a stable name. The generated Dart metadata maps names to `(atlas, row, column)`; code never hard-codes columns.

```
<unit>.<layer>.<state>.h<heading>[.f<frame>]
<unit>.<layer>.<state>.a<angle>[.f<frame>]
```

- `unit`: lower-case id (`lodestar`, `crocket`, `ashlar`, `rubbling`).
- `layer`: `hull`, `art` (the articulated layer: turret, gun pod, cab, bell cradle, jib, ridge gunner), `fx` (a sparse overlay drawn on top of a hull or art cell), `debris`.
- `state`: `move`, `idle`, `fill1` … `fill3`, `lights`, `dmg1`, `dmg2`, `arrive`, `pitchUp`, `pitchDown`, `ford`, `air`, `land`, `special`, `wreck`, `rubble`, `totalled`, `pod`, `fire`, `aim`, `hit`, `fall`, `run`, `flourish`, `climb`, `descend`, `jump`, `wade`, `climbLine`, `strideOver`.
- `heading` / `angle`: three digits, the authored angle rounded down: `000 022 045 067 090 112 135 157 180`.
- `frame`: zero-based within the state.

Examples: `lodestar.hull.move.h045.f2`, `lodestar.art.aim.a067`, `crocket.fx.fill2.h135`, `carillon.art.aim.a000` (cradle level), `ashlar.hull.walk.h090.f3`, `reliquary.hull.special.h157.f1` (unload).

Mirrored cells are not stored; the runtime passes `mirror: true` (as today). Marks, glyphs and faces must read correctly mirrored (both style guides).

## 4. Atlas blocks

Units are packed in **blocks**: a fixed grid of rows × 20 columns per unit. A block's layout depends only on its class, so the generator and the painter share one table per class.

| Atlas | Cell (texels) | Holds |
| --- | --- | --- |
| `assets/images/ground-fleet-<sector>.png` | 48 × 40 | Fleet vehicle and walker blocks used in that sector, plus the Fleet fx rows |
| `assets/images/ground-host-<sector>.png` | 48 × 40 | Host vehicle, walker and command blocks used in that sector (sector stone baked in), plus the Host fx rows |
| `assets/images/ground-infantry-<sector>.png` | 32 × 24 | Infantry blocks for both factions used in that sector |
| `assets/images/ground-atmosphere.png` | see [ground-atmosphere.md](ground-atmosphere.md) | Fog, mist, cloud and smoke layers |
| `assets/images/ground-wildlife.png` | 16 × 12 | Flocks, fleeing critters ([ground-easter-eggs.md](ground-easter-eggs.md)) |

**Per-sector packing.** Each sector loads only the blocks it uses. This bakes the Host's sector stone ramp and corruption kit into the sector's atlas, which resolves `gargoyle-ground-army` design decision 4 (sector tint) in favour of baked variants: there is no runtime ramp mapping, and memory stays bounded because no sector holds every unit. A unit that appears in several sectors is packed once per sector from one master (the ramp remap and the kit overlay are offline steps with no GPU).

Memory check (RGBA, uncompressed in GPU memory): a 4-row vehicle block is 960 × 160 px (0.6 MB). The busiest sector (Hollow: 4 Fleet + 6 Host blocks plus fx) is about 960 × 1840 px (7.1 MB), against 1.3 MB for today's `ground-forces.png`. If a real phone shows pressure, the fallback is to drop headings h1 and h3 at far LOD (Section 6.5) into a half-resolution "far" atlas; this is an open question for review, not a default.

### 4.1 Vehicle block (V-block): 4 rows × 20 columns

| Row | Columns | Content |
| --- | --- | --- |
| 0 `hull` | `h × 4 + f` for h 0–4, f 0–3 | Move cycle per heading. Tracks: the link sliver shifts 1 texel per frame. Wheels: spokes. Skiff: f0–1 hover bob, repeated |
| 1 `art` | 0–4 | Articulated layer at angles a0–a4 (turret, gun pod, cradle, jib, ridge gunner), each centred on its pivot |
| | 5–9 | Host: `fill1` overlay per angle (the first lit channel segment). Fleet: `fire` per angle (barrel back 2 texels, muzzle ring lit) |
| | 10–14 | Host: `fill2` per angle. Fleet: Sextant elevation 1; others the dented turret overlay |
| | 15–19 | Host: `fill3` per angle (full channel, eyes and mouth lit). Fleet: Sextant elevation 2; others reserved |
| 2 `fx` | 0–4 | `lights` overlay per hull heading: Host eyes and vents (idle pulse and flare), Fleet cyan strips (flicker when totalled) |
| | 5–9 | `dmg1` overlay per heading: Host warm crack seams; Fleet dented plates |
| | 10–14 | `dmg2` overlay per heading: Host broken ornament and wider seams; Fleet hanging skirt and smoke vent |
| | 15–18 | Host: `arrive` 4 frames at h3 (the unearthing). Fleet: `totalled` track-thrown A/B and limp A/B at h0 |
| | 19 | Reserved |
| 3 `states` | 0–5 | `pitchUp` and `pitchDown` at the three headings nearest the travel axis (Fleet h0–h2, Host h2–h4) |
| | 6–7 | `ford` A/B at the travel heading (Fleet h0, Host h3) |
| | 8–9 | Light vehicles: crest `air` and `land`. Others: special frames 5–6 |
| | 10–13 | `special` 4 frames (Reliquary unload, Hodcrawler mend, Carillon ripple, Cairn deploy, Tether tow, Sextant brace) at the travel heading |
| | 14–15 | Host: `wreck` A/B at h3. Fleet: crew `pod` A/B |
| | 16–17 | Host: `rubble` heap, cooling A/B. Fleet: reserved |
| | 18–19 | Host: two `debris` sheets, 6 pieces each (16 × 20 sub-cells). Fleet: one armour-shard sheet, one reserved |

For a unit **without** an articulated layer (Crocket, whose gun is fixed under the prow), row 1 holds the `fill` overlays per hull heading instead, and columns 0–4 are reserved. The overlay key is "the layer the weapon is on".

**Overlays.** `fill*`, `lights`, `dmg*` are sparse cells: only the changed pixels are opaque (warm seams, lit channels, chips drawn in outline ink). They are drawn with normal blending on top of the cell they belong to, at the same anchor. This is how a 5-heading unit gets a telegraph, idle life and two damage states without authoring 5 × (3 + 1 + 2) full frames: the generator rasterises the channel path, eye points and crack network per heading from the rig, so overlays always line up with their hull.

### 4.2 Walker block (W-block): 5 rows × 20 columns

| Row | Columns | Content |
| --- | --- | --- |
| 0 | 0–5, 6–11, 12–17 | Stride, 6 frames, at h0, h1, h2 |
| | 18–19 | `idle` stance A/B at h2 |
| 1 | 0–5, 6–11 | Stride at h3, h4 |
| | 12–13 | `idle` stance A/B at h3 |
| | 14–16 | `strideOver` 3 frames at the travel heading |
| | 17–18 | `climb` A/B |
| | 19 | Reserved |
| 2 | as V-block row 1 | Articulated torso or cab |
| 3 | as V-block row 2 | Overlays, arrival / totalled |
| 4 | 0–1, 2–3 | `descend` A/B, `ford` A/B |
| | 4–19 | As V-block row 3, columns 8–19, then reserved (Buttress Strider collapse uses `wreck` plus special 3 frames) |

Every stride frame keeps at least 3 texels of clear ground between the legs (gargoyle rule; it applies to the Stilt too).

### 4.3 Command block (K-block): the Chapterhouse

Cells are **double height** (48 × 80, two atlas rows per frame) because the spire is the unit's cue. 4 double rows × 20 columns:

| Double row | Columns | Content |
| --- | --- | --- |
| 0 | 0–5, 6–11, 12–17 | Stride, 6 frames, at 90°, 135°, 180° |
| | 18–19 | `idle` A/B at 135° |
| 1 | 0–2 | Window `lights` overlay per heading |
| | 3–5, 6–8 | `dmg1`, `dmg2` per heading |
| | 9–17 | Banner flutter overlay, 3 frames per heading (out of step with the stride) |
| 2 | 0–3 | Command pulse (eye flare, ring start) |
| | 4–8 | Fall, 5 frames (the spire topples first) |
| | 9–12 | `arrive`: the undercroft doors open and it walks out, 4 frames |
| | 13–14 | Rubble with the eye guttering, A/B |
| 3 | 0–1 | Debris sheets (with the gilt finial piece) |

### 4.4 Infantry block (I-block): 2 rows × 20 columns, 32 × 24 cells

| Row | Columns | Content |
| --- | --- | --- |
| 0 | `h × 4 + f`, h 0–2, f 0–3 | Walk per heading (Host 45°/90°/135°; Fleet 0°/45°/90°) |
| | 12–13 | `idle` A/B (breathing: 1-texel shoulder rise; Host horn or bell bob) |
| | 14–15 | `aim` A/B (wind-up: weapon raised; Host back-channel lit) |
| | 16 | `fire` |
| | 17 | `hit` |
| | 18–19 | `fall` A/B (Host topple; Fleet stumble to one knee, never down) |
| 1 | 0 | Host `rubble` (crumbled stone); Fleet `kneel` |
| | 1–3 | `arrive`: Host claws out of the ground; Fleet hops off a ramp |
| | 4–5 | `run` A/B (flee for the Host, fall back for the Fleet) |
| | 6–9 | `flourish`: Fleet victory dance; Host taunt jig |
| | 10–11 | `climb` A/B |
| | 12–13 | `descend` A/B |
| | 14–16 | `jump` crouch, air, land |
| | 17–18 | `wade` A/B |
| | 19 | `climbLine` (hands on rock; bobs 1 texel at runtime) |

Specials use the action columns: the Knell-bearer's ring is `aim` A (swing out), `fire` (strike), `aim` B (return); the Prior's point is `aim` A; the Prior's spire topple is `fall` A/B. Squads draw several troopers from the same block, as today.

**Fold-in of the terrain change.** The pose columns planned in `openspec/changes/ground-terrain-interaction` (climb, descend, jump, wade, pitch, ford, stride-over, crest hop) are produced inside these blocks for every reworked unit. Units that are not reworked keep the terrain change's planned columns in `ground-troops.png` and `ground-forces.png`.

## 5. Runtime: picking and blending headings

A small presentation tracker per unit, modelled on `CreatureMotion` (name it `GroundHeading`), owned by the painter's per-unit state, never by the simulation:

```
on update(x, z, dt):
  v   = smoothed ground velocity (lateral texels/s from screen x via 1/texel(z), depth texels/s), k = 1 − exp(−8·dt)
  if |v| ≥ vMin (4 texels/s):           target = screenAngle(v)          # nose direction on screen
  elif engaged and a foe exists:        target = angle to foe            # heavies square up to their foe, slowly
  else:                                 target = heading                 # hold
  heading += clamp(wrap(target − heading), ±ωMax·dt)                     # turn rate limit
  hold = max(0, hold − dt)
  if hold == 0:
    i = current authored index
    if heading is past the midpoint to i±1 by more than 3°:              # hysteresis
      i = i ± 1                                                         # ONE step: never skip a heading
      hold = minHold
      emit skidDust(outside of turn)                                    # the ship's counter-thruster puff, on the ground
  frame = (i, mirror = heading < 0)
```

| Class | ωMax (hull) | minHold | ωMax (articulated layer) |
| --- | --- | --- | --- |
| Infantry | 360°/s | 0.10 s | — |
| Light vehicle (Sleet, Cairn, Tether, Crocket, Gutter-runner) | 180°/s | 0.12 s | 270°/s |
| Heavy (Lodestar, Sextant, Skiff, Tympanum, Reliquary, Carillon, Hodcrawler) | 75°/s | 0.20 s | 120°/s |
| Walker (Stilt, Buttress Strider) | 90°/s | 0.18 s (a step lands on a stride plant when one is within 0.1 s) | 150°/s |
| Chapterhouse | 30°/s | 0.40 s | — |

Consequences:
- A Lodestar swinging 90° takes about 1.2 s and shows h0 → h1 → h2 → h3 → h4, each at least 0.2 s. That is the "rotates slightly to change direction" read.
- The move cycle keeps running through a turn. A tracked vehicle turning in place runs its treads at 0.6 rate.
- Crossing 0° (Fleet) or 180° (Host) flips the mirror. Passing through the symmetric heading keeps that frame for one hold so the flip never pops.
- A heading change and a terrain state change (climb, ford) are each limited to one per hold, and the terrain guide's cap (at most 3 units in a non-walk state) also counts units mid-turn.
- **Pitch at off-axis headings.** Pitch frames exist only at the three travel-axis headings. At other headings the unit shows its base move frame plus the terrain dust: the terrain guide's LOD rule already allows that.
- **Reduced motion:** headings still change (they are information), skid dust is not drawn.

**What the simulation must expose** (read-only, already mostly there): screen x and depth z per unit per frame, `engaged` and the foe, `mirrored` for the legacy rows, the terrain `GroundPose`.

## 6. Articulated layer (turret) rotation

The articulated layer is drawn after the hull, at the hull's anchor plus `pivot[h]`:

```
turretOrigin = unitAnchor + pivot[unit][h] × scale        # pivot from the generated metadata, unmirrored, flip x when mirrored
draw art cell a (mirror if aim < 0) at turretOrigin − recoil along aim
```

- **Independent angle.** The layer has its own angle (`aim`), tracked like the hull heading but with its own rate limit (table above) and the same hysteresis and one-step rule. It points at the foe when engaged, otherwise it sweeps slowly (the existing idle scan) or follows the hull.
- **Angle set.** Fleet a0–a4 = 0°, 22.5°, 45°, 67.5°, 90° (today's `allyTurretAngles`). Host a0–a4 = 90° … 180°. The Carillon's cradle uses three tilts (level, ranging 1, ranging 2) in a0–a2 instead of directions, and the Sextant's elevation is a separate state (V-block row 1, columns 10–19).
- **Turret leads, hull follows.** When the foe is more than 67.5° from the hull heading and the unit is engaged and slow, the hull target becomes the foe angle (heavies "square up"). Otherwise the hull follows its velocity.
- **Muzzle.** `muzzle[unit][a]` (dx, dy from the pivot, texels) replaces today's per-row `allyMuzzle`. Tracers and muzzle fx start there.
- **Recoil.** As today: the layer kicks back along its own angle (1.6 texels, Fleet 2 texels for main guns) and settles over 0.14 s.
- **Host overlays follow the layer.** `fill1–3` are per angle, so the channel fills on the turret's gun at any angle.
- **Seating check.** The generator renders every (hull heading × layer angle) pair on the contact sheet. A pair where the turret floats or clips into the skirts fails review.

### 6.5 Level of detail

| Depth | Headings shown | Turret | Overlays |
| --- | --- | --- | --- |
| z < 900 | all | independent | all |
| 900 ≤ z < 1200 | all | snaps to the nearest of a0, a2, a4 | `lights` only (the light patterns of the gargoyle guide, Section 9) |
| z ≥ 1200 | h0, h2, h4 only | follows the hull | `lights` only, fogged at half rate |

## 7. Undercroft Host: the full animation set

The operator asked for the Host to feel like a rich, swarming strategy-game army. The Host stays what its style guide made it: **carved living stone**, not a grown swarm (no chitin, creep, slime or tentacles). The richness comes from five motion rules applied to every unit:

1. **It breathes.** Every unit has a 2–4 frame idle at 2–3 fps: a 1-texel chest or deck heave, eye pulse, membrane twitch, chain sway. Stone that breathes is the Host's "alive" read.
2. **It rises from below.** The Undercroft lives underground. Units that spawn mid-field **unearth**: a crypt slab cracks with warm seams, heaves, and the unit climbs out with a dust ring. Packs of Rubblings pour out of one slab. Far arrivals come out of the fog instead ([ground-atmosphere.md](ground-atmosphere.md)).
3. **Anticipation, action, follow-through.** Every attack is channel fill (wind-up), mouth bloom (release), recoil and settle. Every hit is a flinch and a flash.
4. **Secondary motion.** Membranes, banners, chains, censers and bells lag the body by one frame.
5. **It breaks.** Deaths are readable and varied: crumble, topple, or a light vehicle bursting into authored pieces ([ground-easter-eggs.md](ground-easter-eggs.md), "Little tanks in pieces").

### 7.1 Per-unit frame table

Frames are per authored heading unless marked "at hT" (one heading only). "Ov" means a sparse overlay. Hold times from the gargoyle guide: 0.10–0.14 s infantry and light vehicles, 0.16–0.20 s walkers and command.

| Unit | Block | Idle | Move | Wind-up | Release | Hit | Damage | Death | Arrival | Special | Cells |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Rubbling | I | 2 (horn bob) | 4 × 3 h | `aim` 2 (chisel raised) | `fire` 1 (jab/throw) | 1 | — | `fall` 2 + `rubble` 1 | 3 (claw out); packs pour from one slab | `run` 2 (rout), `flourish` 4 (jig) | 40 |
| Ashlar Guard | I | 2 | 4 × 3 h | 2 (spout-musket raised, channel lit) | 1 (bloom) | 1 | — | 2 + 1 | 3 | `run` 2, `flourish` 4 | 40 |
| Corbel Brute | I | 2 | 4 × 3 h | 2 (corbel launcher shouldered, glow) | 1 | 1 | — | 2 + 1 | 3 | `run` 2 | 40 |
| Knell-bearer | I | 2 (bell sway) | 4 × 3 h | ring: swing out (`aim` A) | strike (`fire`), return (`aim` B) | 1 | — | 2 (bell drops) + 1 | 3 | ripple ring fx (fx row) | 40 |
| Prior | I | 2 (pennant flutter) | 4 × 3 h | point (`aim` A) | — | 1 | — | spire topple 2 + 1 | 3 | — | 40 |
| Crocket | V | lights Ov (eye pulse) | 4 × 5 h | `fill1–3` Ov × 5 h | muzzle bloom (shared fx) + recoil 1 texel | hit flash | `dmg1–2` Ov × 5 h (hooks snap) | wreck 2 + rubble 2 + 12 debris pieces | `arrive` 4 | crest air/land | 80 |
| Crocket (captured, Krybor) | V | as Crocket, human hull with stone hooks bolted on | | | | | | | | | 80 |
| Tympanum (refresh) | V | lights Ov | 4 × 5 h | `fill1–3` Ov × 5 a | bloom + recoil | flash | `dmg1–2` × 5 h | wreck 2 + rubble 2 + 12 pieces (the horned turret pops) | 4 | — | 80 |
| Reliquary | V | lights Ov (ridge glow) | 4 × 5 h | ridge gunner `fill` × 5 a | bloom | flash | dmg × 5 h (roof caves) | wreck 2 + rubble 2 + pieces | 4 | unload 4 + 2 (wings lift, doors open, light spills, squad drops) | 80 |
| Carillon | V | lights Ov | 4 × 5 h | cradle tilt (a0–a2) + `fill1–3` | ripple 3 (special 10–12) | flash | dmg × 5 h | wreck 2 (bells topple) + rubble 2 + pieces (bells roll) | 4 | ripple fire | 80 |
| Hodcrawler | V | jib sway (art a0–a4 at 2 fps) | 4 × 5 h | jib `fill` × 5 a | — | flash | dmg × 5 h | wreck 2 (jib falls) + rubble 2 + pieces | 4 | mend 4 (block set, target seams close) | 80 |
| Buttress Strider | W | stance 2 × 2 h | stride 6 × 5 h | `fill1–3` Ov × 5 h | bloom + 1 texel rock | flash | dmg × 5 h (knee pinnacles snap) | collapse 3 + rubble 2 + pieces | 4 | strideOver 3 | 100 |
| Chapterhouse | K | idle 2 + banners 3 Ov | stride 6 × 3 h | pulse 4 | — | flash | dmg × 3 h | fall 5 + rubble 2 + pieces | 4 (doors of the undercroft) | command pulse | 60 double cells |

Threat vehicles (Gutter-runner, Scrapmason Crawler, Kiln Ox, Belfry) keep their rows and frame contract in `ground-forces.png`. Giving them V/W blocks is Phase 4 of the render plan, behind a flag, because their launch and telegraph timing is a gameplay contract.

### 7.2 Host arrival (unearthing), frame by frame

| Frame | Content | Hold |
| --- | --- | --- |
| `arrive.f0` | A flat crypt slab on the ground (the sector's stone), with 3–5 warm `demon_warm[1..2]` seams | 0.20 s |
| `arrive.f1` | The slab cracks and tilts up 2 texels; seams brighten to `demon_warm[3]`; dust ring start (shared fx) | 0.14 s |
| `arrive.f2` | The unit's top half above the ground line (horns, spire or turret first), slab shards to the sides | 0.14 s |
| `arrive.f3` | The unit at full height, one leg or track still in the hole; shards settle | 0.14 s, then `move` |

The other agent's arrival code decides **when** a unit unearths and when it walks out of the fog instead; the art supplies both.

## 8. Ground Fleet: the full animation set

| Unit | Block | Idle | Move | Fire | Hit | Damage | Totalled | Special | Cells |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sleet | V | lights Ov | 4 × 5 h (bounce) | `fire` × 5 a | shards | `dmg1–2` × 5 h | track/wheel lost 2 + limp 2 + pod 2 | crest air/land | 80 |
| Cairn | V | lights Ov | 4 × 5 h | 5 a | shards | × 5 h | as above | deploy 4 (ramp drops, squad out) | 80 |
| Tether | V | lights Ov | 4 × 5 h | 5 a (twin autocannon alternates) | shards | × 5 h | as above | tow 4 (A-frame lowers, cable) | 80 |
| Lodestar | V | lights Ov | 4 × 5 h | 5 a (barrel slide, muzzle ring) | shards | × 5 h | as above | — | 80 |
| Sextant | V | lights Ov | 4 × 5 h | 5 a + 2 elevations | shards | × 5 h | as above | brace 2 (spades) | 80 |
| Skiff | V | hover bob is the idle | 2 × 5 h | 5 a | shards | × 5 h | as above (drops onto its belly) | — | 80 |
| Stilt | W | stance 2 × 2 h | stride 6 × 5 h | cab pods 5 a | shards | × 5 h | as above (kneels) | strideOver 3 | 100 |
| Rifle trooper | I | 2 | 4 × 3 h | `aim` 2 + `fire` 1 | 1 | — | stumble 2, `kneel` | `flourish` 4 (dance), `run` 2 | 40 |
| Rocket trooper | I | 2 | 4 × 3 h | 2 + 1 (backblast fx) | 1 | — | 2, kneel | `flourish` 4, `run` 2 | 40 |

## 9. Cell budget

| Faction | Blocks | Cells |
| --- | --- | --- |
| Fleet | 6 V + 1 W + 2 I | 480 + 100 + 80 = 660 |
| Host (Tier A + refresh) | 6 V + 1 W + 1 K + 5 I | 480 + 100 + 120 (60 double) + 200 = 900 |
| **Total** | | **about 1,560 cells**, of which about 460 are sparse overlays generated from the rig |

Only a fraction of these cells go through the GPU (keyframes and in-betweens); the rest are generated on the grid (Section 10 of the render plan).

## 10. Tests the implementation should add

(For the code change that consumes these atlases; listed here so the art contract is testable.)
- Every named cell in the generated metadata exists, is non-empty (overlays: at least 1 opaque pixel) and has binary alpha.
- Heading turntables: consecutive authored headings differ by at least 2 texels of silhouette at ×0.62 (otherwise the step is invisible) and by no more than 40% of silhouette pixels (otherwise it pops).
- `GroundHeading`: never skips an index; never changes twice within `minHold`; a 90° turn of a heavy takes 1.0–1.4 s; a heading oscillating ±5° around a midpoint does not flicker.
- Turret seating: for every (hull heading, layer angle) pair, the art layer's lowest opaque row overlaps the hull's turret-ring rows.
- Host: gilt pixels identical across move frames; no `ally_cyan` pixels. Fleet: no `demon_warm` or `demon_gilt` pixels.
- Walker leg gap ≥ 3 texels in every stride frame at every heading.
