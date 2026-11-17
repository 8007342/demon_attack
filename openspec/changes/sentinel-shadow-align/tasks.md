## 1. Cast the looming shadow from the silhouette

- [x] 1.1 `_lurkSpec` projects from `foreshadowBase(f)` (silhouette x, ground under its nearness) at `SentinelForeshadow.shadowAltitude` with the flyers' sun direction (`_flyerHit`), and sizes by `sentinelShadowScale` on the hit's ground nearness
- [x] 1.2 The rising sentinel's shadow altitude eases from `SentinelForeshadow.shadowAltitude` (was `LurkTrack.nearAltitude`, same 120)
- [x] 1.3 Remove `LurkTrack`, its seed stream and `_lurkFrontZ`; remove the 0.2 nearness floor (`lurkMinNearness`) from the size rule
- [x] 1.4 Section marker `// --- sentinel-shadow-align` in `scene.dart` and `model.dart`

## 2. Tests

- [x] 2.1 `test/sentinel_shadow_align_test.dart`: alignment at sampled frames two waves, one wave and zero waves ahead, flat and draped
- [x] 2.2 Scale is monotone in the silhouette's nearness; it grows from the farthest stage to battle
- [x] 2.3 Hand-off: per-frame centre step and scale step bounded through the rise
- [x] 2.4 `test/terrain_shadows_lurk_test.dart` loses the track tests; review tests sample the lurk by time
- [x] 2.5 §2 gates; the §7 calibration tests stay green (presentation only)
