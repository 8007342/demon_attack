# Design: a living, time-driven ground front

Everything lives in `lib/game/ground_war.dart` (`GroundFront`, `GroundTuning`, `GroundWar`). It supersedes the wave-based `GroundPlan` in `add-ground-forces-homing`; that change's camera, missiles, homing salvo, allies-never-die and events are unchanged except as noted here.

## Schedule (per sector, `GroundFront.of`)
| Sector | Presence | Interval | First unit | Demon HP (ally hits) | Breakthroughs | Base strength E/N/H | Base pressure |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Krybor | 1 | 6 s | 6/6/5 s | 2 | never | 1.0 | .10 |
| 2 Ringfall | 2 | 6 s | 3 s | 3 | never | .95 | .20 |
| 3 Ember | 2 | 8 s | 4 s | 4/5/5 + route | occasional | .86/.76/.71 − .03·route | .35 |
| 4 Hollow | 2 | 8 s | 3 s | 6/7/7 + route | regular | .72/.62/.58 − .03·route | .50 |

(The route term is capped at 3.)

- **The clock** is the level's combat clock (`levelClock`, which already stops in every cinematic). Air waves no longer reset or plan the ground. Arrival intervals are `interval / (0.7 + 0.6·pressure)`, with at most `presence` live demon units (+1 above pressure 0.75). While a broken-through unit can still fire, no new unit arrives: one breakthrough at a time, so slower players are not swamped and faster players still meet the war within the first seconds of every sector.
- **Escorts**: in sectors 1–2 every unit has an ally; from sector 3 a unit is escorted with probability = allied strength.

## Skirmish
- The ally fires every `0.9 / (0.7 + 0.6·strength)` s (0.69 s at full strength) for 1 damage. The demon fires at its ally every `1.3 / (0.8 + 0.6·pressure)` ÷ hostile rate, against 8 ally HP. A demon unit at 0 HP is destroyed by the allies (`groundUnitDestroyed {by: allies}`, no player score, strength +0.03).
- **Guarantee for sectors 1–2**: a unit that somehow reaches fire line + 80 texels alive is finished by the allies. Nothing ever reaches fire range there.
- **Prediction**: from sector 3, each step estimates whether the unit reaches fire range alive: unescorted, or `hp × allyInterval > timeToFire`, or the ally falls first. The first time this holds within depth 1000, the allies call for help (`allyUnderAttack {unescorted, secondsToBreakthrough}`) and a cyan beacon blinks over the ally. Quiet skirmishes the allies are winning show no beacon and raise no call.
- **Breakthrough**: reaching fire range alive sets `brokeThrough`, emits `groundBreakthrough` and lowers strength by 0.02. Only then can the unit telegraph and fire (1 missile on Easy, 2 on Normal/Hard).

## Meters
- `alliedStrength` (0.2–1): homing kill +0.08, saved ally +0.04, allied win +0.03, retreat −0.08, breakthrough −0.02; it relaxes toward the sector base at 2%/s. When the player helps a lot, more units are escorted and allies fire faster: the allies push ahead.
- `pressure` (0–1): its target is `base + 0.05·route + 0.08·live + 0.12·threatening + 0.1·broken + 0.12·progress − 0.6·(strength − base)`, capped at 0.45 in sectors 1–2. Progress is `levelClock / (wavesPerLevel · 20 s)`. It is smoothed at 0.7/s, and `groundPressure {level}` fires at every tenth.

## Homing drops
| Situation | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Breakthrough looming or a broken-through unit can fire: chance per kill | 30% | 25% | 20% |
| … pity: guaranteed on the next kill after | 3 s | 4 s | 5 s |
| … airdrop if no kill within a further | 3 s | 3 s | 3 s |
| Otherwise (all levels, the carrier too) | every 40 kills, at 20, 60, 100, … | same | same |

Forty kills is the cadence at which each module returns in the eight-kill rotation, so outside a crisis homing is just another pickup. Homing targeting puts broken-through units first, then threatening ones, then the previous order.

## Calibration
See `plan/difficulty-calibration.md`, "Ground war". With an attentive pilot, median wave times stay within 10% of the pre-ground-war baseline. Breakthroughs and would-be hits are zero in sectors 1–2 on every difficulty, and per-sector breakthroughs order Easy < Normal < Hard.
