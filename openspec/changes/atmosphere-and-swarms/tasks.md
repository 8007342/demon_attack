# Tasks

## 1. Transmittance and detail reveal
- [x] 1.0 Interim: shields, armour, halos and pips hidden in the fog, fading in over the haze (f050241f).
- [ ] 1.1 `Perspective.transmittance(n)`; colour-matrix tint (fog colour, saturation, contrast) per depth bucket,
      replacing the double-draw haze; sector fog colours.
- [ ] 1.2 Staged reveal from t (outline, gear, full colour); eyes and glows punch through; holding wave capped.
- [ ] 1.3 Tests: reveal stages, gear never visible while holding, perspective-parity guards unchanged.

## 2. Fog layers
- [ ] 2.1 `atmosphere.dart`: layer state, drift, per-sector density and colour; tile fallback (two baked fBm
      tiles) and draw slots in `scene.dart` (horizon band, far banks, ground fog, 1–2 sky sheets).
- [ ] 2.2 Depth-binned drawing: far banks and ground fog interleaved with creatures by nearness.
- [ ] 2.3 `shaders/fog.frag` (fBm + domain warp) behind a capability check; verify on the web build.
- [ ] 2.4 Never fogged: bullets, player, tells and HUD drawn above the sky sheets; alpha caps near the ship.
- [ ] 2.5 Settings: Atmosphere full / reduced; reduced motion keeps layers static.

## 3. Flock arrivals
- [ ] 3.1 `flock.dart`: seeded agents, squadrons with leader paths, arrive + separation/alignment/cohesion (k 7)
      + wander, 30 Hz fixed step, altitude arc, β hand-off to the slot.
- [ ] 3.2 Waves and reinforcement groups enter through the flock; entering creatures stay untargetable.
- [ ] 3.3 Tests: determinism (same seed, same paths), entrance-window parity with today, no creature settles
      within .25 field widths of the ship, calibration bots within tolerance.

## 4. Shadows
- [ ] 4.1 Altitude shadow model (offset, three blur sprites, opacity through ground fog); incoming shadows
      visible, settled formation shadows unchanged.

## 5. Sentinel foreshadowing
- [ ] 5.1 Studio: silhouette sheet per sentinel species (8 banking frames × 2 blur levels), contact sheet for the
      operator.
- [ ] 5.2 Foreshadow state from wave w − 2: Gerono path with depth, growth per wave, breathing, behind the far
      banks; pure presentation.
- [ ] 5.3 Arrival hand-off into the sentinel entrance with an insect-style escort swarm.
- [ ] 5.4 Radio hook: an optional line when the silhouette is first seen (pending voice batch).

## 6. Review
- [ ] 6.1 Frame-time budget on a phone-sized window (fog ≤ 2 ms, flock ≤ .5 ms).
- [ ] 6.2 Operator playtest: fog layers, swarm feel, shadows, sentinel foreshadowing; tune.
