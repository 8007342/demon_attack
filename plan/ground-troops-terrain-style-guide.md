# Ground troops on terrain: movement and animation style guide

A companion to [style-guide.md](style-guide.md) ("Ground war presentation")
and [ground-terrain-interaction.md](ground-terrain-interaction.md) (the
research and the plan). OpenSpec: `openspec/changes/ground-terrain-interaction/`.

Unit classes are generic, so any army can map onto them (the gargoyle
ground army included): **infantry, light vehicle, heavy vehicle, walker**.
The rules here describe how a class *moves and reads*. Faction looks (demon
warm lights and stone hide, allied grey-blue hulls with cyan stripes) are
unchanged.

## 1. Principles

1. **Feet on the ground you see.** A unit's contact row sits on the drawn
   surface (`placeAt` y). Ground hidden behind a crest hides the unit's
   lower body behind that crest. A unit never stands on a crest it is
   actually behind.
2. **Terrain changes the pose, never the pixels' angle.** Slopes are shown
   with authored pitch and lean frames on the texel grid, not by rotating
   the sprite. Nearest-neighbour sampling only.
3. **One state at a time, held long enough to read.** A movement state is
   held for at least 0.35 s. Entering and leaving use hysteresis (enter at
   the threshold, leave at 0.8 × it), so nothing flickers on a noisy slope.
4. **Detail scales with nearness.** Terrain states are drawn only nearer
   than z 900 (screen y ≳ 239). Further out, units walk or roll on their
   base cycle, and only their pace (cycle rate) and dust change.
5. **Threat first.** Terrain tells never cover a telegraph, a launch flash,
   a muzzle, the IFF chevron or the distress beacon. When they compete, the
   tell wins and the terrain state drops to its base frame.

## 2. Movement states

| State | Trigger (`GroundPose.state`) | What the player should read |
| --- | --- | --- |
| **walk / roll** | slope along travel ≤ the class's walk limit | normal advance |
| **climb** | walk limit < slope ≤ climb limit, uphill | effort: slower cycle, lean in, extra dust behind |
| **descend** | the same band, downhill | braking: lean back, skid dust ahead |
| **jump** | a jump-down link or a crest hop | brief airborne: the body lifts and the shadow stays on the ground |
| **ford** | on a ford link | wading or splashing in the sector's material, slower |
| **bridge** | on a bridge link | single file, plank rumble, no dust |
| **queue** | waiting for a link that is full | halted in a short column, ready pose |
| **avoid** | the lateral goal moved by more than 40 units because of a ravine, cliff or steep slope ahead | a visible swerve: the body turns with the lateral velocity, and dust kicks up on the outside of the turn |
| **grind** | forced across impassable ground (a threat unit whose band is blocked, or a queue timeout) | struggle: the slowest cycle, heavy dust, the climb pose for its class |

## 3. Per class

Speeds are the visual cycle rate × the base rate. Depth speed is a rule
matter (see the design).

### Infantry (squads of 2–5 troopers)

| State | Pose | Frames | Notes |
| --- | --- | --- | --- |
| walk | existing 4-frame walk | 4 | squad formation as now |
| climb | torso pitched 2 texels forward, knee high, a free hand reaching forward; on a climb line, hands on the rock, body vertical | 2 (slope) + 2 (climb line) | climb lines: troopers go one after another (0.25 s apart) and the formation narrows to a column |
| descend | torso back 1 texel, heel first, weapon held high | 2 | small pebble puffs ahead |
| jump | crouch (anticipation), airborne tuck, land (knees bent) | 3 | arc 6–10 texels high at the squad scale; the shadow shrinks by one step at the apex |
| ford | waist-deep wade: legs hidden below a material band, weapon raised overhead | 2 | splash fx on alternate frames |
| bridge | the walk cycle at 0.8 rate, single file | (reuse) | |
| queue / brace | half-crouch, weapon ready, looking ahead | 1 | the aim frame can stand in until it is authored |
| grind | the climb frames at 0.5 rate | (reuse) | |

Demon troopers stay side-on (facing by lateral velocity, mirrored). Allied
troopers stay seen from behind: their climb shows the back and pack tipped
toward the camera, and their descent shows more helmet top.

### Light vehicle (buggy, rover, APC, half-track)

| State | Pose | Frames | Notes |
| --- | --- | --- | --- |
| roll | existing 4-frame move | 4 | |
| climb | nose-up pitch +1 (side-on: front 2 texels higher; from behind: the rear deck foreshortened and more of the roof showing) | 2 | dust doubles behind |
| descend | nose-down pitch −1 | 2 | skid dust ahead of the wheels |
| crest hop | the nose-up frame for 0.1 s, airborne (wheels hanging), a nose-down landing | 2 (air, land) | lift 2–4 texels; the shadow stays on the ground and narrows one step; landing throws one dust ring |
| ford | wheels and tracks hidden in the material band, bow wave | 2 | |
| bridge | the roll cycle at 0.7 rate | (reuse) | |
| queue | hold at the move frame 0, lamps on | 1 | |

### Heavy vehicle (tank, crawler, tower, MBT, SPG)

| State | Pose | Frames | Notes |
| --- | --- | --- | --- |
| roll | existing move | 4 | |
| climb | pitch +1 and pitch +2 (steep) | 2 + 2 | the turret stays level: authored, the turret pivot keeps its row |
| descend | pitch −1 | 2 | tracks throw clods ahead |
| ford | shallow ford only: the lower hull hidden, a wide bow wave | 2 | |
| bridge | slow (0.6) and alone: the bridge holds one heavy | (reuse) | a little dust sifts down from under the deck |
| avoid | turns early: the swerve starts at least 1.5 s before the obstacle | — | heavies are the clearest "it saw the ravine" read |
| grind | climb frames, the slowest cycle, the heaviest dust, one spark every 0.5 s | (reuse) | |

### Walker (artillery beast, mech)

| State | Pose | Frames | Notes |
| --- | --- | --- | --- |
| walk | existing gait, with the torso bob | 4 | |
| climb | long stride, front leg high, torso pitched forward 2 texels | 2 | |
| descend | short stride, body low | 2 | |
| stride-over | one long leg spanning a ravine end: plant, swing, plant | 3 | the signature walker move, never used by other classes |
| ford | legs in the material band, torso dry | 2 | |
| bridge | the gait at 0.7 rate | (reuse) | |

## 4. Shadows, dust, splash

- **Contact shadow** (new, every class): a stepped pixel ellipse, 3 rows
  for vehicles and walkers and 2 for a trooper, directly under the contact
  row. Width is 0.8 × the unit's visible width. Colour is the outline ink
  #0A0716 at 35% opacity (50% on lit slopes, where `gridShade > 1.2`). It
  stays on the ground during jumps and hops, narrowing one step per 3
  texels of lift. It is drawn before the unit, in the same depth order,
  and clipped like the unit on hidden ground.
- **Dust follows the slope.** Uphill, dust goes behind and up. Downhill,
  it goes ahead and low. Across a slope, it goes to the downhill side.
  Use the existing fx `dustCol` frames. Count: walk 1, climb 2, grind 3
  per unit (inside the existing particle caps).
- **Ford splash** per sector (palette from the ground tile, luminance
  ≤ 0.40): Krybor ice spray, Ringfall regolith dust, Ember cinder sparks
  (warm, but never as bright as a telegraph), Hollow mire droplets, Carrier
  ichor. Three frames each, a new strip in the ground-forces fx row.
- **Pebble trickle** on climb lines: 2 single-texel pebbles falling 4–6
  texels.

## 5. Readability at phone size

- At 360 px wide, a trooper at z 600 is about 13 × 15 px and a tank about
  30 × 20 px. A pitch must therefore change **at least 2 texels** of
  silhouette (nose height, torso lean). Any less is invisible.
- **Silhouette test.** Every new frame, filled with solid black at the
  drawn size for z 600, must still show which state it is: climb versus
  walk, wade versus walk.
- **No more than one state change per unit every 0.35 s**, and no more
  than **3 units** in a non-walk state on screen at once (the most
  distant ones fall back to walk). The battle reads; it does not fizz.
- Queues at a link are a **column of 2–4**, spaced 0.6 × the unit width,
  facing the link. Never a pile-up: overlapping sprites are forbidden at
  a queue.
- The terrain states keep the faction's luminance caps. Dust and splash
  stay below unit body luminance. Wade bands use the ground tile's darker
  ramp, never a bright waterline.
- **Reduced motion:** jumps and hops become a 1-frame step (no arc), and
  splashes and pebbles are not drawn. Pitch and climb frames stay, because
  they are information.

## 6. Frame and atlas needs

`ground-troops.png` (32 × 24 cells) grows from 12 to **20 columns** and
from 6 to **7 rows**. Columns 0–8 stay exactly as they are (demon rows use
7–8 for topple and rubble, ally rows for the run stride).

Infantry rows (0 demon grunt, 1 demon rocket brute, 3 ally rifle, 4 ally rocket):

| Columns | Frames |
| --- | --- |
| 9–10 | climb on a slope, A/B |
| 11–12 | climb line (hands on rock), A/B |
| 13–14 | descend, A/B |
| 15–17 | jump: crouch, air, land |
| 18–19 | wade, A/B |

Heavy tank row (2; columns 0–7 are used today):

| Columns | Frames |
| --- | --- |
| 8–9 | pitch +1, A/B |
| 10–11 | pitch −1, A/B |
| 12–13 | pitch +2, A/B |
| 14–15 | ford, A/B |

New fx row 6: the ford splash, 3 frames for each of the 5 sector
materials (columns 0–14), and the pebble trickle (columns 15–16).

`ground-forces.png` (40 × 32 cells, 16 × 16) for the vehicle rows:

| Rows | Free columns | Use |
| --- | --- | --- |
| demon sector vehicles (0–3) | 10–15 | pitch +1 A/B, pitch −1 A/B, ford A/B. The light `buggy` (row 0) uses columns 14–15 for crest air and land instead, and its ford is shown with the fx splash over the roll frame |
| allies (4–11) | 13–15 | hull climb (from behind), hull descend, ford. The turret layer is reused unchanged |
| walkers (`beast` row 2; the ally `mech` row) | 10–15 on demon rows, 13–15 on ally rows | climb A/B, then the 3 stride-over frames (demon: 12–14; the ally mech's stride-over takes 13–15 and its climb reuses the gait at half rate with the torso bob doubled) |

The ground-forces rows already hold 16 columns. If the gargoyle army needs
more poses, add rows; do not shrink cells.

Every frame is authored in Go on the texel grid (`tools/ground_troops/build.go`:
extend `pose` with `pitch int`, `climb`, `wade`, `air`, `crouch`). Pitch is
made by **shearing the body rows ±1 texel per 6 columns about the contact
point**, then cleaned by hand-authored overrides. The existing `rotate`
helper may be used only for the 2-texel torso lean above the hip (`cut`).

## 7. High-res refinement renders (ComfyUI keyframes)

The pipeline stays the same: an AI keyframe contributes only −1/0/+1
shading on the authored silhouette (`aiTexture`). New poses need one
keyframe per unit per **pose family**, not per frame:

| Family | Units | Prompt additions (to the unit's existing prompt) | Selection check |
| --- | --- | --- | --- |
| climb | every infantry, walker | "climbing a steep rocky slope, leaning forward, one hand reaching up, side view" (allies: "seen from behind, climbing away up a steep slope") | the hand and the lean read in a black fill at 64 px |
| descend | every class | "carefully descending a slope, leaning back, heels first" | |
| jump | infantry | "mid-air jump, knees tucked, weapon held close" | the body above the shadow, no motion-blur trails |
| wade | infantry, walker | "wading waist-deep through a shallow ford, weapon held above the head" | a clear horizontal waterline band |
| pitch | vehicles | "tilted nose-up climbing a steep slope, side view" / "nose-down descending" | treads and wheels stay parallel to the slope |

Use `source_px` 64 as now; refinement candidates are 3 per family; record
the seed and selected id in `art/families/ground-troops.json` (`units[].poses`)
and the run log in `ground-troops-runs.json`. Negative prompt as now, plus
"ground plane, horizon, cast shadow, motion blur, rotated frame".
Review on `art/contact/ground-troops-contact.png` at 1× and 3×, and over all
five sector grounds at phone size.

## 8. Do and don't

- Do: lean, pitch, hide feet in a wade band, keep the shadow honest.
- Do: let heavies swerve early and visibly; let infantry take the hard
  way (climb lines) where vehicles detour.
- Don't: rotate sprites, smooth-scale, or draw a unit on top of a crest it
  is behind.
- Don't: show a vehicle driving along a canyon floor or up a mesa wall.
- Don't: make terrain tells brighter than threat tells.
