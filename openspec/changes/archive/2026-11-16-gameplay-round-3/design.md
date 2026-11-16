# Design: gameplay round 3

## 1. Life-loss sequence (`lib/game/life_loss.dart`)

`ArcadeModel.lifeLossPhase` steps through `none → exploding → regrouping → emerging → none`. The mode stays `playing` throughout. `ArcadeModel.shipAway` is true while exploding or regrouping.

| Tunable (`LifeLossTuning`) | Value | Effect |
| --- | ---: | --- |
| `explode` | 0.7 s | The ship explosion before the regroup starts |
| `regroup` | 1.6 s | Shots drain, the swarm reforms, nothing can hit |
| `drainWindow` | 0.35 s | Each hostile shot fizzles at a random moment in this window |
| `emerge` | 0.55 s | The reserve ship's fly-in from y = 546 to the ship line (cubic ease-out) |
| `protection` | 2.0 s | Blinking protection, from the start of the fly-in |
| `regroupSpeedX/Y` | 240 / 200 units/s | The swarm's top speed back to formation |

The ship is away for 2.3 s per life lost.

- **While away:**
  - `_hostile()` drops every new hostile shot, so nothing fires, the carrier included.
  - Dive scheduling, `divePrep` and tells are suspended.
  - Diving demons pull out and fly back to their formation slot.
  - Reinforcement arrivals and wave completion wait.
  - Ground units cannot start a telegraph.
  - The homing rack holds its next launch.
  - Pickups freeze in place, because the ship cannot collect them.
  - Module timers freeze. `invulnerable` covers the whole sequence.
- **At `regroupStart`:** hostile shots get a fizzle delay, and ground missiles in flight end with a fizzle.
- **At `playerRespawn`:**
  - Any remaining hostile shots end and the ship recentres at x = 180.
  - `invulnerable = 2.0`, which uses the existing 12 Hz blink.
  - Auto-fire resumes once the fly-in is about done.
  - Ground launchers get at least 1.2 s of cooldown.
- **Unchanged:**
  - A shield still absorbs a hit with no sequence.
  - The final life still goes straight to the defeat celebration; `playerDestroyed` carries `final: true`.
  - Score, lives and the loadout are unchanged: offensive modules survive, as before.
- **Visuals (the life-loss section of `scene.dart`):**
  - A 12 fps procedural pixel explosion: a white flash, a fireball whose noise holes eat it from the rim, a shock ring, then a rising smoke column with embers. It sits on top of the existing staggered blasts.
  - 18 hull shards in four tones with burning trails. The fitted modules tumble away using their ship-atlas sprites (visual only).
  - Shot fizzles: a six-spark pop with smoke.
  - The fly-in draws a long mint thruster plume.

### Events
All three are queued on the model's structured event queue (`takeGameEvents`) and carry `sector`:
- `playerDestroyed {x, y, lives, final}` at the hit.
- `regroupStart {x, y, lives, duration, shotsDrained, missilesDrained}` 0.7 s later.
- `playerRespawn {x, y, lives, protection}` 2.3 s after the hit.

The existing string event `life`, and with it the derived `lifeLost`, still fires at the hit. The comms agent plays the demons' celebration during the regroup and the squad's new-life chatter after `playerRespawn`, without blocking play.

## 2. `divePrep`
- Every dive tell now starts with `Demon.divePrep = 0.5 s` (scaled by the hostile rate) and a `divePrep {x, y, lead, sentinel, elite}` event. This covers scheduled dives, elite and sentinel attack dives, angry dives and swarm-policy dive commits.
- The tell and its sampled target x start when the beat ends. Dive-commit dives still lead the ship.
- The beat counts toward the concurrent-dive cap, so it adds no dives. It shifts each dive 0.5 s later at the same cadence.
- Last stands are not dives and are unchanged.

## 3. Ground war v2

### Placement
`GroundPlacement.place(side, across, z, widthTexels)` is the single projection from logical ground position to screen. It is used by every unit and ally getter, so a visual terrain layer can wrap it.

### Convoy allies
- At level start, one ally per side holds station at `allyHoldZ` 250 (+14 on the right side, +38 for a second slot). This is screen y ≈ 404–420, just above the ship line, outside the firing lane.
- A new demon unit is met by an idle ally on its side, or by a reinforcement that rolls in from z 150 (below the screen edge). Field repairs restore the ally to 8 HP.
- An engaged ally advances toward `foe.z − 300`, clamped to `[holdZ, 620]`, at 150 texels/s. When the fight ends it falls back at 90 texels/s.
- The fight model is unchanged: it starts when the foe is sighted (z 1150), and ally fire, demon fire and breakthrough prediction keep their timing. Only where the ally stands changes.
- Totalled allies limp toward the outer edge, drop back and leave.
- Allies never collide with the player or block shots.

### Homing to the ground
- A ground target gets a cubic-curve flight lasting `0.95 + 0.55 × (z − shipZ)/1000` s, clamped to 0.95–1.75 s:
  - It starts at the launch point.
  - It climbs 150 units, offset 34 units to the missile's side.
  - It reaches an apex 95 units above the unit, offset 26 units outward.
  - It ends at the unit's ground contact.
- The curve's end follows the moving unit.
- Perceived depth eases from the ship's plane (z ≈ 199) to the unit's depth. The sprite and trail puffs scale by `texel(depth)/texel(shipZ)`, and the missile fogs with `depthLight`.
- The missile impacts when its progress reaches 1.
- If the target is lost, the missile re-aims at the next ground unit with 70% of a fresh flight, or reverts to the fast air steering.
- Air targets are unchanged: about 0.4–0.7 s.
- The salvo is still sequential, with 0.18 s after each hit.

| Target depth | Flight |
| ---: | ---: |
| z 400 (fire range) | ≈ 1.06 s |
| z 900 | ≈ 1.33 s |
| z 1300 | ≈ 1.55 s |

### Breakthrough visibility
- **L1:** quiet. The allies stop every unit at fire range + 80.
- **L2 near misses:**
  - Each unit has a 55% chance (`nearMissChance`) to be a near miss.
  - Allied fire cannot finish a near-miss unit until it is within 22 texels of the fire line. The allies stop it there, with `groundNearMiss {x, y, marginZ}`.
  - A unit can fire only from the fire line, after a 1.1 s telegraph, so a near-miss unit never fires.
- **L3/L4 guarantee:**
  - If nothing has broken through 9 s into the level, the next arrival is the guaranteed unit. It has no ally, and homing cannot lock on to it until it breaks through.
  - It is telegraphed by `allyUnderAttack` (unescorted, at z 1000), then `groundBreakthroughWarning` 3 s before fire range (for every threatening unit), then `groundBreakthrough`. The existing urgent homing drops, pity timer and airdrop then apply.
  - One per sector visit.
- **L4:** keeps its regular breakthroughs.

### Art v3
The ground-forces atlas is now a 40×32 grid, 16×16 cells:
- Allies: two variants per sector, with turret or torso layers, squads, walkers, recoil, dust and crew.
- Effects: a 10-frame explosion, shock rings, scorch variants, flame loops, debris, muzzle flashes and impact sparks.

See `plan/asset-pipeline.md` and the "Art (v3)" section of `openspec/changes/tune-ground-war-front/design.md`.

## 4. `/console`
- `lib/widgets/dev_console.dart` is reached via `onGenerateInitialRoutes` / `onGenerateRoute` in `main.dart` (the console route section). Any other path opens the arcade.
- `ArcadeModel.startAt({difficulty, sector, route, wave})` starts a fresh run at 0 points with the starting lives. It sets `medals = route`, so earlier routes count as won; sentinels appear from route 1 on.
- `ArcadeModel.sentinelWave` finds the first sentinel wave.
- Score entry and the top-10 list are unchanged.

## Calibration
- The life-loss sequence adds 2.3 s of ship-away time per life lost. During it, nothing threatens the player and the swarm does not attack. Module timers freeze, so powered time is unchanged.
- The protected campaign pilot never loses a life, so its workload numbers are unaffected.
- The `divePrep` beat delays every dive by 0.5 s without changing cadence. Its workload effect is in the remeasured numbers in `plan/difficulty-calibration.md`.
- The ground changes are remeasured with the profiler. The guarantee and the slower homing flights raise sector 3 breakthroughs for an attentive pilot; sectors 1–2 stay at zero.
