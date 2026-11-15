# Tasks

## 1. Transmittance and detail reveal
- [x] 1.0 Interim: shields, armour, halos and pips hidden in the fog, fading in over the haze (f050241f).
- [x] 1.1 `Perspective.transmittance(n)`; colour-matrix tint (fog colour, saturation, contrast) per depth bucket,
      replacing the double-draw haze; sector fog colours.
      Note: `Atmosphere.veilMatrix`/`tintFor` (16 cached buckets); air and veil colours per sector from
      `plan/ground-atmosphere.md` §2, lerped with the scene's environment.
- [x] 1.2 Staged reveal from t (outline, gear, full colour); eyes and glows punch through; holding wave capped.
      Note: ordinary creatures use an emissive-mask colour matrix; sentinels get two eye embers instead (the
      gold species' body is as warm as its eyes, a mask cannot separate them).
- [x] 1.3 Tests: reveal stages, gear never visible while holding, perspective-parity guards unchanged
      (`test/atmosphere_swarms_test.dart`; the perspective tests pass unchanged).

## 2. Fog layers
- [x] 2.1 `atmosphere.dart`: layer state, drift, per-sector density and colour; tile fallback (two baked fBm
      tiles) and draw slots in `scene.dart` (horizon band, far banks, ground fog, 1–2 sky sheets).
      Note: tiles are baked at load (tileable, domain-warped fBm); `Atmosphere.art` lets the ground-atmosphere
      atlas replace a slot's texture later.
- [x] 2.2 Depth-binned drawing: far banks and ground fog interleaved with creatures by nearness.
      Note: horizon band (n .26) and banks A/B (n .335/.43) are drawn as the depth sort passes them; ground fog
      is drawn before the creature pass (no creature flies below its top edge while farther than n .55).
- [x] 2.3 `shaders/fog.frag` (fBm + domain warp) behind a capability check; verify on the web build.
      Note: compiles into the `flutter build web` bundle (SkSL, local coordinates) and renders in
      `flutter test`; `FragmentProgram` load failure falls back to tiles. Runtime check in a browser still to
      do on the preview. The shader draws only the horizon band and far banks (frame budget); ground fog and
      sky sheets use the tiles at every tier. No half-resolution target was needed.
- [x] 2.4 Never fogged: bullets, player, tells and HUD drawn above the sky sheets; alpha caps near the ship.
- [x] 2.5 Settings: Atmosphere full / reduced; reduced motion keeps layers static.
      Note: the pause menu (no settings screen exists); remembered under `demonAttack.atmosphere`.

## 3. Flock arrivals
- [x] 3.1 `flock.dart`: seeded agents, squadrons with leader paths, arrive + separation/alignment/cohesion (k 7)
      + wander, 30 Hz fixed step, altitude arc, β hand-off to the slot.
- [x] 3.2 Waves and reinforcement groups enter through the flock; entering creatures stay untargetable.
      Note: presentation over the model's entrance clock; the wave-pressure hold mills in the fog; the
      sentinel's escort comes as an insect swarm.
- [x] 3.3 Tests: determinism (same seed, same paths), entrance-window parity with today, no creature settles
      within .25 field widths of the ship, calibration bots within tolerance.
      Note: parity is exact (bit-identical fight, four sector/route runs of 150 s). The .25-width test covers
      the flock's own placement; the existing reinforcement rows (y up to 412) can settle ~70 units from the
      ship, unchanged by this work.

## 4. Shadows
- [x] 4.1 Altitude shadow model (offset, three blur sprites, opacity through ground fog); incoming shadows
      visible, settled formation shadows unchanged.
      Note: the shadow is the creature's own silhouette flattened on the ground with three blur levels; drawn
      over the ground fog. Opacity raised from the research's .45 (the ground is very dark); still subtle on
      the darkest sectors — tune in the playtest.

## 5. Sentinel foreshadowing
- [x] 5.1 Studio: silhouette sheet per sentinel species (8 banking frames × 2 blur levels), contact sheet for the
      operator. (Not in this run: a placeholder from the sentinel's flight frames is used.)
      Note (2026-11-15): derived on the CPU from the flight frames (`tools/sentinel_silhouettes`, no GPU: a shape,
      not a texture, and no committed workflow renders banked rig poses): `assets/images/sentinel-silhouettes.png`,
      `lib/game/sentinel_silhouette_atlas.dart`, `art/contact/sentinel-silhouettes.png`. The foreshadow draws it
      (far→near blur cross-fade, eyes follow the bank); the flight-frame placeholder stays as the fallback and
      still serves the arrival cross-fade, which must match the body frame.
- [x] 5.2 Foreshadow state from wave w − 2: Gerono path with depth, growth per wave, breathing, behind the far
      banks; pure presentation.
      Note: shown only while no other sentinel is in the fight (one at a time).
- [x] 5.3 Arrival hand-off into the sentinel entrance with an insect-style escort swarm.
      Note: the escort's entrance (.8 s) ends before the sentinel sets out (1.15 s delay), so the swarm pours
      out of the silhouette first, then the sentinel follows from the same spot.
- [ ] 5.4 Radio hook: an optional line when the silhouette is first seen (pending voice batch).

## 6. Review
- [ ] 6.1 Frame-time budget on a phone-sized window (fog ≤ 2 ms, flock ≤ .5 ms).
      Measured in `test/atmosphere_perf_test.dart` (CPU tester): flock 40 agents .03 ms per frame; fog
      recording .1–.2 ms; CPU raster is not a GPU number. A phone GPU measurement is still to do.
- [ ] 6.2 Operator playtest: fog layers, swarm feel, shadows, sentinel foreshadowing; tune.
      (Open 2026-11-15: folded into the ground close-out playtest checklist, render plan
      `plan/render-runs/ground-forces-rework.md` §17 (fog darkness vs the old haze).)
