# Tasks

## 1. Relief
- [x] 1.1 `TerrainField`: seeded rolling noise + per-segment features, sector profiles and light
- [x] 1.2 `TerrainView`: blend, lane and horizon envelopes, screen grid with occlusion clamp, slope light
- [x] 1.3 Ground as one indexed `drawVertices` mesh with vertex light and fog (fog draw removed)
- [x] 1.4 Walls, landmarks, props and creatures on the surface
- [x] 1.5 Travel crossfade morph; reduced motion

## 2. Units and vegetation
- [x] 2.1 `GroundPose` / `GroundRelief` hook in `ground_war.dart` (`// --- terrain`), poses refreshed each step
- [x] 2.2 `place` navigation (soft-min over band probes, lane clamp, climb, pace); climb dust in `GroundPainter`
- [x] 2.3 Vegetation placement, push state, frames and particles
- [x] 2.4 Vegetation pipeline in Go (`tools/vegetation`): jobs, run, ingest, pack, offline; spec, runs, sources, contact

## 3. Events and docs
- [x] 3.1 `TerrainRadio` and the four event names in `game_events.dart`
- [x] 3.2 `plan/terrain-relief.md`, style guide and asset pipeline sections
- [x] 3.3 Tests: determinism, seams, lane, surface/mesh consistency, navigation, rules unchanged, rate limits; perf before/after; review frames
