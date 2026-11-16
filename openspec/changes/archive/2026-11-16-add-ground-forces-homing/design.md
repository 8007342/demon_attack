# Design: ground forces, allies and homing missiles

All tunables live in `GroundTuning` and `GroundPlan` in `lib/game/ground_war.dart`; the values below are the shipped defaults.

## Architecture
- `ground_war.dart` is a `part` of `model.dart`. Its state is one object (`ArcadeModel.ground`, a `GroundWar`) and its logic is an extension, so `model.dart` gains only short hooks marked `// --- ground war`: level/wave begin, the combat step, pickups, kill drops, salvage end, campaign completion and the `homing` flag on `hitDemon`.
- The simulation stays pure and fixed-step. Rendering (`ground_painter.dart`) only reads it. `scene.dart` gets three marked lines: load the atlas, `paintGround` before air combat, `paintAir` after it.
- **One camera.** `GroundCamera` repeats the flyover's projection (`y = 172 + 348·z0/z`, texel scale `2·z0/z`); a test pins it to `FlyoverBackground`'s constants. A ground unit has a depth `z` (texels ahead of the camera), a side and a fraction across its side band.

## Lane decision
Ground units always stay in the side bands (screen x outside 96–264), as landmarks and creatures do, and never cross the dark central lane, not even to fire. Only their missiles cross it. This keeps the air combat legible, keeps a unit's position predictable from first sighting, and means a missile always flies inward toward the player, which reads clearly as "incoming".

## Approach and fire
| Tunable | Value |
| --- | --- |
| Spawn depth / screen y | z 1400 / y ≈ 215 (tiny, fogged) |
| Sighted event | z ≤ 1150 |
| Approach speed | 105 texels/s × hostile rate |
| Fire range (near ground) | z 400 → 205 (y ≈ 323 → 467) |
| Creep speed in range | 30 texels/s × hostile rate |
| Telegraph | 1.1 s: launcher raised (first 45%), then glow pulsing faster, plus a warm bracket on the ground |
| Launch flash / cooldown | 0.28 s / 3.2 s |
| Missiles per unit | Easy 1, Normal/Hard 2 (1 for the first Krybor unit) |
| Missiles in flight | at most 3; only one unit telegraphs at a time |

A unit takes about 9.5 s to drive from the horizon into range, which gives the player time to see it coming and to obtain homing missiles. The renderer brightens units from 38% at spawn to 100% at the fire line: subdued at the horizon, a clear threat when near.

## Ground missiles
- The target is the player's x sampled at launch, at y = ship plane. The path is fixed: a lerp plus a 64-unit pop-up arc (`sin πt`). After the plane it keeps its final heading, with no tracking.
- Flight time is 1.7 s ÷ hostile rate. The drawn width grows from 8 to 36 arena units (`t²`).
- **Fair collision**: no collision before `t = 0.9` (the ship's plane). The hitbox radius is 0.4 × the drawn width (the warhead body, not its exhaust glow) plus the ship's half-extents 9 × 10. One sidestep of about 24 units clears it. A warm target marker blinks at the ship plane where the path crosses it.
- A hit calls `hitPlayer` exactly like a hostile shot: it costs a life unless the shield absorbs it (the shield is consumed, with 1 s protection).
- **Shots cannot destroy missiles (decision).** Player fire is permanent auto-fire. If shots could pop missiles, the ordinary stream would erase most of them without the player doing anything, the dodge lesson would vanish, and the homing power-up would lose its purpose (it is the counter to launchers). Missiles stay a pure movement test, readable through size, telegraph and marker.
- Player shots also fly over ground units (no collision), and Large blasts do not reach the ground.

## Homing missiles
- **Pickup** (`HomingPickup`, falling at the usual 64/144 units/s, with the same 22 × 23 catch box): arms a salvo of 3. Picking one up while a salvo is in progress refills it to 3. It combines with every module and the shield, is preserved on life loss, and freezes outside combat with everything else. A level change clears it.
- **Sequence**: the first missile launches 0.12 s after pickup; each next one 0.18 s after the previous one hits (or expires after 3 s or leaves the screen). Launch sides alternate left, right, left from wing pylons. With no valid target the salvo holds its missiles until one appears.
- **Flight**: a 0.1 s straight climb, then steering at 9 rad/s, accelerating from 230 to 480 units/s. If its target disappears it retargets in flight.
- **Targeting** (`pickHomingTarget`):
  1. While any demon ground unit is alive and on screen, the highest `threat` among them: telegraphing (soonest launch) > in range and loaded (soonest reload) > closest.
  2. Otherwise air targets: **carrier core while vulnerable** (shield down and a hatch open) > **sentinel** > **elite** > **gold** > **coral** > **violet** > **teal**; ties go to the demon nearest the ship. Entering or waiting demons are skipped.
  3. Last, the carrier itself: its shield while up, or its closed core.
- **Damage**: a ground unit is destroyed by one missile. Against air targets, one heavy hit of 3 (`homingAirDamage`, through `hitDemon(..., homing: true)`): it kills 1–3 HP demons, leaves a 4-HP demon on 1, strips one layer by 3 on sentinels (layers never overflow), and counts as an offensive power for breaking a sentinel's dive shield. Against the carrier, it removes 3 shield; it reaches the core only through an open hatch (3 damage), and a closed hull takes only a dent. A full salvo therefore removes at most 9 core HP, about 16–56% of a route-dependent core, and only if the hatch timing cooperates. It does not trivialise the boss.

## Drops (guarantee)
| Rule | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Chance per ordinary kill while ≥1 ground unit lives | 14% (+4% per extra unit) | 12% (+4%) | 10% (+4%) |
| Pity: guaranteed on the next kill after this much ground pressure without homing | 5 s | 6 s | 7 s |
| Airdrop if no kill comes within 4 s more | yes | yes | yes |
| Over the carrier (level 5) | every 20 kills (at 10, 30, …) | same | same |

No homing pickup drops while one is falling or a salvo is in progress, and none drop in sectors 1–4 without ground pressure. The existing eight-kill weapon rotation and heart drops are unchanged; the homing drop is an extra roll after them. Tests check that a pickup exists before a fresh unit can reach the fire line for every difficulty.

## Introduction ramp
The ramp step is `s = sector + min(route, 3) − (Easy ? 1 : 0)`, and counts are scaled by density (0.8/1/1.2).

| Step | Waves | Units per wave | Max active | Interval | First delay |
| --- | --- | --- | --- | --- | --- |
| ≤0 | — | 0 | — | — | — |
| 1 (first Krybor) | final wave only | 1 (1 missile) | 1 | — | 7 s |
| 2 | from wave 2 | 1 | 1 | 14 s | 5 s |
| 3 | all | 2 | 2 (Easy 1) | 11 s | 4 s |
| 4 | all | 3 | 2 | 9 s | 3.5 s |
| 5 | all | 3 | 2 (Hard 3) | 8 s | 3 s |
| ≥6 | all | 4 | 3 (Easy 2) | 7 s | 3 s |

So Normal and Hard see one unit late in the first Krybor visit and none earlier; Easy sees its first unit in Ringfall's second wave. Timers advance only in combat. Ground units never block a wave from completing. In-flight ground missiles are cleared at each wave entrance and at salvage, so they never cross a breather. Units are cleared at level clear.

## Allies
- Every other demon unit (`allyEvery = 2`; the very first one always) arrives engaged with an ally 110 texels nearer the camera on the same side. The pair advances together (a running battle). The sector's ally design comes from the atlas.
- The demon fires a warm tracer every 1.3 s ÷ hostile rate, costing the ally 1 of its 8 HP. The ally returns cyan tracers every 0.9 s; these are cosmetic, because only homing missiles destroy demon units.
- Allies never collide with the player or block shots, and **never die**. At 0 HP an ally is *totalled*: it limps toward the outer edge, smoking and sparking (crews with odd ids eject in a pod that flies off), then leaves. Event: `allyRetreated` (`allyLost` is an alias of the same string).
- **Positive-only consequences**: destroying an engaged ally's attacker saves it (`allySaved`, +250 × route). A sector whose engaged allies all held gives +500 × route, and `fleetIntact {scope: level}` fires at level clear. `fleetIntact {scope: campaign}` fires at the campaign victory when no ally retreated all run. `GroundWar.fleetIntactLevel` and `fleetIntactRun` expose the result. `wingmatesLost` is a counter the squad/comms feature may increment; it counts against "intact".
- Visual language: cyan/teal accents on neutral grey-blue hulls and a blinking cyan distress cross over an ally under attack. Demon units use dark hulls with saturated warm accents. Decorative creatures stay small and muted, with no lights and no launcher.

## Events and SFX
`GameEvent(name, data)` records queue on `ground.events`. `main.dart` drains `model.takeGameEvents()` each tick into `dispatchGameEvent` (`lib/game/game_events.dart`), a single no-op-safe function: with no listeners it does nothing, and a throwing listener is isolated. The music bridge and the comms panel call `GameEvents.listen` (commander lines: `groundForceSighted` → "Ground forces ahead!", `homingPickup` → "Homing missiles armed!", `allyUnderAttack` → "Pick up some homing missiles!" / "Please shoot these enemies!", `allyRetreated` → "I'm totalled, going back to base!"). Every payload carries `sector`, and positional events carry `x` and `y`.
SFX use the existing `events` → `audioSfx` route with four new names synthesised in `demon-audio.js` (`groundSfx`, a self-contained branch): `missileLaunch` (noise whoosh plus a rising saw), `missileIncoming` (a falling sine whistle at t = 0.45), `homingLock` (a two-note beep plus hiss) and `groundExplosion` (low drum plus long noise).

## Presentation
- `ground-forces.png` (v2 contract in `ground_atlas.dart`, 12 × 10 cells of 32 × 24 texels): four demon units and four allies with move cycles, telegraph, fire and post-fire, burning wreck, ally hit, limp and escape pod frames, ground explosion, scorch, launch flash, tracer spark, smoke, and the nose-on missile with its trail puffs. Units are drawn with nearest-neighbour filtering at `texel(z) × 1.05`, mirrored for the right band, and depth-sorted.
- The missile is one high-detail cell scaled from 8 to 36 units, with an analytic smoke trail sampled from earlier points on the same fixed path (stateless) and a launch flash at the unit.
- Ship-weapons row 7: the pylon rack with 3/2/1/0 missiles, the flying missile with cyan exhaust, the reticle, launch flashes, deploy frames, a detached pylon and the pickup badge. The rack is part of `paintShip`, so the transition route glyph shows the loadout automatically.
- HUD: a HOMING row with three pips in `PowerStatus`, and pylon missiles in `PowerGlyphPainter`.
- Hints: `ground_missiles` (preferred at the first Ringfall entrance) and `homing_missiles` (preferred at the first Ember entrance), each with a procedural pixel illustration. They are eligible only for sectors 1–4.

## Calibration
See `plan/difficulty-calibration.md` ("Ground war"). The ground war does not change any ordinary-wave budget (the 318-wave audit is identical). For the protected pilot it adds measured missile exposure, and its homing pickups shorten long sentinel waves. The intended bands, and the measured values, are recorded there.
