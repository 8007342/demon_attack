# Tasks

## 1. Life-loss sequence
- [x] 1.1 `lib/game/life_loss.dart`: phases, tunables, debris, fizzles, regroup, emergence
- [x] 1.2 Gate hostile fire, dives, reinforcements, wave completion, pickups, module timers and ground fire while the ship is away
- [x] 1.3 Events `playerDestroyed`, `regroupStart`, `playerRespawn` in `game_events.dart`
- [x] 1.4 Scene: explosion, debris, fizzles, fly-in (the life-loss section of `scene.dart`)
- [x] 1.5 Tests: timing, drain/invulnerability, respawn protection, loadout, final life

## 2. divePrep
- [x] 2.1 A beat before every dive tell with a `divePrep` event; existing dive tests adapted

## 3. Ground war v2
- [x] 3.1 `GroundPlacement.place`: single screen projection
- [x] 3.2 Convoy allies (station, advance, fall back, roll-in reinforcements)
- [x] 3.3 Ground homing arc with perspective, fog and smoke trail
- [x] 3.4 L2 near misses, L3/L4 guaranteed telegraphed breakthrough, `groundBreakthroughWarning`
- [x] 3.5 Art v3 atlas and painter (work/gameplay-v3-art)
- [x] 3.6 Tests: flight times, convoy, near misses with no fire, guaranteed breakthrough
- [x] 3.7 Remeasure the ground calibration (`plan/difficulty-calibration.md`)

## 4. /console
- [x] 4.1 `ArcadeModel.startAt`, `wavesFor`, `sentinelWave`
- [x] 4.2 Console page and route (work/gameplay-v3-console)
- [x] 4.3 Tests: route, buttons, score 0, sentinel prerequisites, boss jump

## 5. Docs and review
- [x] 5.1 `plan/game-design.md`, the calibration, this change
- [x] 5.2 Review frames: explosion and regroup, respawn, homing arc, ground effects, console
