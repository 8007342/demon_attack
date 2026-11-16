# Design: ground war v4

## Principle: two layers
The **threat front** (`GroundFront`, `ground_war.dart`) is unchanged: same schedule, same `model.random` draws, same rules (breakthroughs only in sectors 3–4, missiles only from broken-through units, near misses, the guarantee). The **skirmish layer** (`GroundFront.skirmish`, a `SkirmishFront`) adds the ambient war beside it. Every way the skirmish layer could feed back into the threat or the air war is cut:

| Coupling | v4 rule |
| --- | --- |
| Random stream | Skirmishes draw from `GroundSkirmish.rng`, seeded per level from sector, route and difficulty; `model.random` is never touched |
| Threat spawn cap | Counts non-skirmish units only |
| Pressure meter, allied strength | Skirmish units and their deaths never move them |
| Breakthroughs, ground missiles | Skirmish units have no shots and hold at ≥ 430 texels (fire range starts at 400) |
| Ally retreats (`fleetIntact`) | A skirmish never totals an ally: at ≤ 3 HP it falls back to its slot and repairs in 3.5 s |
| Homing salvo | Skirmish units are not targets (a salvo fired at the ambient war would change the air war and leave threats unanswered) |
| Ally for a threat unit | `_assignAlly` takes an idle convoy ally, else rolls a reinforcement in, as before |

`SkirmishFront.enabled = false` (a test hook) turns the layer off and plays v3 exactly. `test/ground_war_v4_sim_test.dart` flies every sector on every difficulty, fast and slow pilots, routes 0–1, with the layer off and on.

| Level | Breakthroughs before → after | Ground shots at the player before → after | Engagements/min before → after |
| --- | --- | --- | --- |
| L1 Krybor | 0 → 0 | 0 → 0 | 6.9 → 25.0 (3.6×) |
| L2 Ringfall | 0 → 0 | 0 → 0 | 8.0 → 26.5 (3.3×) |
| L3 Ember | 19 → 19 | 31 → 31 | 3.9 → 26.1 (6.7×) |
| L4 Hollow | 19 → 19 | 25 → 25 | 4.2 → 29.6 (7.0×) |
| L5 Carrier | 0 → 0 | 0 → 0 | 0 → 11.6 |

An "engagement" is an ally–foe pairing that starts on the visible ground (`GroundWar.alliesEngaged`, the same counter before and after). Allies retreated: 0 in every level, before and after.

## Skirmish front per sector (Normal; Hard +1 cap in Krybor, +route/2 cap in Ember)

| Sector | Cap at the surge | Interval at the surge | First | Demon forces | Convoy (slots) | Squad |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 5 | 3.8 s | 2.5 s | vehicle, infantry ×2 | vehicle, infantry ×2 each (4) | 3 |
| 2 | 5 | 3.8 s | 2 s | vehicle, infantry ×2, rockets | + rockets (5) | 3 |
| 3 | 5 | 3.6 s | 2 s | + heavy tank | (6) | 4 |
| 4 | 6 | 3.3 s | 2 s | heavy tank ×2 | (6) | 4 |
| 5 | 3 | 5.5 s | 4 s | infantry, rockets, heavy tank | (4) | 3 |

**Tide.** `tide = 0.5 + 0.5·sin(2π·t/34 + φ)`. The live cap is `round(cap·(0.35 + 0.65·tide))`. The interval is `interval·(1.55 − 0.85·tide)·U(0.8, 1.2)`, with groups of two above tide 0.55. `groundTide` fires at surge (> 0.72) and lull (< 0.28).

**Units.** HP: vehicle 4, squad = troopers (one hit drops one), rockets 3, heavy tank 6. Approach (texels/s × hostile rate): 95 / 58 / 50 / 70. Hold line: U(430, 560). An ally is assigned from z 900 and nobody fires before z 700, so fights happen on the visible ground. Demon fire at its ally: vehicle 1.5 s/1, infantry 1.0 s/1, rockets 2.3 s/2, tank 2.0 s/2. Allied fire: vehicle 0.9 s/1, infantry 0.75 s/1, rockets 1.9 s/2. A unit holding with no ally for 7 s, or alive for 45 s, is shelled by allied artillery.

**Convoy.** Escort slots sit at lateral offsets ±64, ±128, ±22, ±156 from an anchor that follows the ship's x (rate 1.1/s), at depths 250–326. The convoy fills to its size over the first seconds, rolling in from below. An engaged ally moves to its foe's x ± 30 and to `foe.z − 150` (clamped to its slot depth and 620). Allies spread apart within 30 units at a similar depth.

**Manoeuvre.** Every 1.8–4.4 s a unit picks a lateral goal among 7 probes ±126 units around it. The cost adds the relief height there (`GroundRelief.heightAt`, so units take valley floors), crowding by neighbours within 34 units, distance, a flank target 46–86 units beside its ally, a slight pull toward the convoy and a random wander. Lateral speed is force speed × `texel(z)`, eased. Facing follows lateral velocity, else the foe. Threat units weave the same way but inside their own side band, so their missiles leave from the same places as before and the dodge is exactly as hard (the campaign autopilot's hit rate is unchanged); the rules still read only z.

## Terrain (coarse)
See `plan/terrain-relief.md`. Segment 520 (was 300). Features about 2.2× higher with twice the footprint, offset up to 150 texels from the edge so they reach the lane. Rolling noise at 125/390 and 55/160 texels, amplitude 21–26. Lane relief 62% (was 18%), with the two edge frames blended across x 150–210 (no seam). A near envelope of 0.6–1 keeps the closest hills from walling the ship. Shading is `1 + 4.2·(n·l − l_z) + 0.02·h`, and hidden ground is ×0.5. An additive `gridGlow` (lit slope, height, +0.42 on crest vertices) is drawn as a second `drawVertices` with `BlendMode.plus` at gain 150, tinted by the sector light.

## Presentation
- **Troops** (`ground-troops.png`, 12 × 6 cells of 32 × 24): demons side-on, facing right and mirrored by `facing`. Squads draw each trooper on its own walk phase in a 5-slot formation. A holding trooper kneels to aim, one trooper fires at a time, and the fallen topple into cracked stone rubble that fades after 4 s. Demon troops draw at 1.0× and their light never falls below 0.62 in the haze. Allied troopers are seen from behind at 0.7× of the 1.3× ally scale.
- **Depth sort:** `FlyoverBackground` implements `GroundOccluders`. The ground painter repaints any plant that is nearer than a unit or ally whose box it overlaps, in depth order.
- **IFF:** a 3-block cyan chevron over every live convoy unit.
- **Weapons:** `GroundTracer.kind`: small arms (0.14 s streak), rockets (0.6 s arc with a smoke trail, using the fx-row rocket sprite) and shells (0.3 s fast streak). Warm or cyan impacts.

## Performance
`test/ground_war_v4_visual_test.dart` measures model update plus full-arena recording at 1080 × 2340 with a busy ground war: 1.1–2.7 ms per frame across sectors on the loaded forge CPU. The test asserts < 16 ms. Caps: skirmish units ≤ 6 (cap × tide), convoy ≤ 6, tracers ≤ 48 and vegetation particles ≤ 160 (unchanged). The flyover adds one `drawVertices` (the glow pass).
