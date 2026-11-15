# Design: ground presentation tuning

Source: [plan/operator-feedback-2026-11-15.md](../../../plan/operator-feedback-2026-11-15.md) W1. Builds on
`ground-blocks-runtime` (painter, cast, heading tracker) and `ground-easter-eggs` (budget, flourishes).

## 1. Presentation only
Everything here lives in the painters and reads the model. No constant the simulation reads changes, and nothing
draws from `model.random`. Squad looks are a pure hash of the unit id (web-safe integer arithmetic). Check: the
simulation fingerprint (score, lives, kills, spawns, engagements, the next `model.random` draw, every unit's and
ally's id, depth, x, hp and state) after 60 s of every sector, with the painter and eggs running, is identical before
and after this change. The existing blocks on/off and eggs on/off parity tests still pass.

## 2. Pace (`GroundPace`)
| Rate | Factor | Applied to |
| --- | --- | --- |
| `anim` | 0.5 | vehicle move and tread/wheel cycles (blocks and legacy), idle, lights pulse and flicker, convoy idle scan, totalled hop and limp, pod blink, infantry walk / run / idle / fall, legacy squad volley flicker |
| `walker` | 0.3 | stride cadence (and so the walker bob) of W-block walkers (Stilt, Kiln Ox, Buttress Strider, Belfry) and the K-block Chapterhouse, both factions; their idle |
| `turn` | 0.5 | `GroundHeading` hull and layer slew rates (`omega × 0.5`) and minimum holds (`minHold ÷ 0.5`): a heavy's 90° swing now takes 2.0–2.8 s and turret slews are half speed |
| `fx` | 0.5 | wreck visual timeline (shock ring, fireball, debris arcs and spin, flame flicker, puff column), wreck/rubble flicker, Chapterhouse fall, crumble, skid dust life, dust puffs, totalled flames, sparks and retreat smoke, critter leap ticks and flee speed (flee time doubled so the distance holds) |
| `egg` | 0.5 | dance, jig and flourish frames (0.12 → 0.24 s), turret twirl and its hop, the jackpot breakup (2.6 → 5.2 s, inside the 6 s wreck); one-shot flourish lengths and the budget's running times doubled |

**Kept at full speed (gameplay or contract):** the threat telegraph's raise and blink (8/16 Hz) and its warning
bracket (7/14 Hz), fire flashes, recoil kicks and hit flashes (simulation timers tied to launches and hits), tracers,
the distress beacon blink (a readability signal), the wreck's 6 s life. The atmosphere's battlefield smoke (drift puffs
and walls in `GroundPainter._wreckSmoke` / `_smokeItems`, constants in `ground_atmosphere.dart`) is left to W2
(`fog-restoration`), which owns that layer; the legacy puff column is slowed.

## 3. Travel speed: what could not be slowed without touching gameplay
"They move too fast" covers positional speed too. A unit's screen position is the simulation's (`GroundPlacement`):
the depth approach (`GroundTuning.approachSpeed` 105 texels/s for the threat front; `GroundV4Tuning.approach`
95 / 58 / 50 / 70 for skirmish vehicles, infantry, rockets, heavy tanks; `lateral` 62 / 38 / 32 / 44) drives the
skirmish engagement clock, the convoy's outcomes and, for the threat front, the arrival at fire range and the launch
clocks. Drawing a unit away from its simulated position would put homing missiles, tracers and the launch point
off the body. So **no travel speed is changed**, and the slower gait now slides slightly (feet at half cadence over
the same ground). At the distances involved this reads as a slow, heavy march, not a skate.

**Proposed gameplay change (not done; needs calibration):** a skirmish-only travel multiplier
`GroundV4Tuning.skirmishPace` (suggest 0.6, walkers 0.45) on `approach` and `lateral` for skirmish units and the
convoy's advance and fall-back, with `holdMin`, `interval` and `maxLife` re-tuned so the number of engagements per
level stays within the calibration tolerance (`test/ground_war_v4_sim_test.dart`,
`test/difficulty_calibration_test.dart`, `test/comms_pacing_test.dart`). The threat front (telegraph timing contract,
launch clocks, `fireLead`) stays as it is. That change would also remove the gait slide.

## 4. Squads: visual group decoupled from the gameplay squad
The simulation's squad strength is `SkirmishFront.squad` (3 or 4 by sector) and is the squad's **hp**
(`GroundV4Tuning.hp`); rocket teams have 3 hp; allied squads have the ally hp. Varying it per spawn would change hp,
fire and kill counts, the calibration and the comms pacing. The least invasive path that satisfies the operator is to
**draw** a group of 1–5 per squad from the unit id (`GroundSquadLook.size`: weights 1:3:4:3:1 for rifles, 1:2:1 for
rocket teams of 1–3) and let it fall in proportion to the hp (`standing = ceil(hp · n / maxHp)`): a group larger than
its hp loses two at once on a hit, a smaller one loses none on some hits (the hit flash still shows). The fire order
(`id % standing`) is unchanged in kind.

Individuality (`GroundSquadLook.offset`, `.gait`, `.turn`): formation slot plus a fixed spacing jitter (±2.5 × ±1.5
texels), a slow drift (1.6–2.6 × 0.8–1.4 texels at 0.2–0.55 rad/s; 40 % while holding), a lead or lag along the
march (±2 texels steady plus a ±1.6 texel surge) eased in and out with the squad's marching amount, a gait cadence of
0.85–1.15 and a phase of 0–4 frames, and a per-trooper `GroundHeading` fed the squad's velocity through its own lag
(0.8–2.8 /s) with its own hold (1–1.8 × the paced hold). The formation is no longer mirrored by facing, so nobody
swaps sides when the squad turns. A fallen trooper's place is frozen where it fell.

## 5. Sizes: runtime draw scale, not regenerated atlases
`GroundPainter.drawScale` / `allyDrawScale` multiply the simulation's perspective scale: Fleet vehicles 0.5, Host
vehicles and heavy tank 1.3, troopers 0.9. Every part of a unit uses the same scale (hull, layer pivot, muzzle,
overlays, skid dust, wreck effects, debris, jackpot, totalled, pod, IFF height, occluder box), so pivots and muzzles
stay seated and the friendly tracer still leaves the drawn muzzle.

**Crispness:** the units were already drawn at a continuous perspective scale (non-integer) with
`FilterQuality.none` and pixel-snapped origins, so a constant multiplier keeps them exactly as crisp as before.
Regenerating the atlases at half size through `tools/ground_blocks` would halve the authored detail (one-texel
outlines and lights would vanish at the source) for no gain at runtime, and would double the sheet work for both
factions. Decision: runtime scale. The review frames confirm the halved Fleet hulls keep their outlines and cyan
lights at phone size.

**Not scaled:** `GroundUnit.scale`, `width`, `bodyY` (the launch point of a threat missile, the homing aim point and
the demon tracer's target stay where the simulation puts them; they remain on the drawn body at 0.5x and 1.3x). Hit
boxes are gameplay and unchanged.

## 6. Easter eggs
Running times in `EasterEggBudget.rules` (the budget's concurrency windows) follow the slower motion: dance 3.2 s,
jig 2 s, jackpot 5 s, critter scatter 5 s; sector dance 3 s (it loops), flock 2.5 s (air, not ground). Rarities and
cooldowns are unchanged.
