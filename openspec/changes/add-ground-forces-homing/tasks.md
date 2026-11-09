# Tasks

## 1. Simulation
- [x] 1.1 `GroundCamera` shared with the flyover (pinned by a test); `GroundTuning` and the `GroundPlan` introduction ramp
- [x] 1.2 Demon ground units: approach, near-ground fire gate, telegraph, launch, cooldown, shot budget, wrecks
- [x] 1.3 Ground missiles: fixed path, growth, ship-plane collision with a size-matched hitbox, a hit counted as a hostile shot
- [x] 1.4 Homing salvo: pickup, sequential launch, guidance, targeting order, damage (ground 1-kill, air 3, carrier hatch rule)
- [x] 1.5 Drops: per-kill chance with ground pressure, pity timer, airdrop, carrier kill-count drop
- [x] 1.6 Allies: engagement, tracers, totalled retreat or pod (never death), saved bonus, fleet-intact tally and bonus
- [x] 1.7 Marked hooks in `model.dart`; checkpoints and new levels clear transient ground state

## 2. Events, audio, HUD, hints
- [x] 2.1 `game_events.dart` dispatcher and stable names; drained in `main.dart`
- [x] 2.2 Synth SFX in `demon-audio.js` (`groundSfx` branch)
- [x] 2.3 HOMING HUD row and glyph pylons; rack in `ShipPainter.paintShip` (transition glyph included)
- [x] 2.4 Two hint cards with procedural illustrations; deck preference at the first Ringfall and Ember entrances

## 3. Art
- [x] 3.1 Ship-weapons row 7 (rack, missile, reticle, flashes, deploy, detached, badge) in `generate_ship_sprites.py`
- [x] 3.2 Ground-forces pipeline (`tools/ground_forces_assets.py`, spec, runs, sources, offline rebuild, contact sheet, docs)
- [x] 3.3 `ground_painter.dart`: depth-sorted units and allies, telegraph brackets, tracers, wrecks and explosions, retreat, missiles with trail and marker, homing reticle

## 4. Calibration and tests
- [x] 4.1 Profiler: ground statistics; `--naive`, `--reaction=S` and `--seed=N` pilots; `GROUND_WAR_DISABLED` baseline
- [x] 4.2 Calibration docs updated with per-difficulty bands and measurements
- [x] 4.3 Campaign autopilot dodges ground missiles and collects homing pickups; all three difficulties complete
- [x] 4.4 Unit tests: pacing, fire gate, collision fairness, targeting order, sequential launch, damage, drop guarantee, allies, events
- [x] 4.5 Review renders (`test/ground_forces_visual_test.dart`) for every sector and moment
