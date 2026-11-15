# Tasks

## 1. Archaeology
- [x] 1.1 Compare the fog across d6c1f868, df170d0d/e2be77a2/6953b98f, 3fb472b8 and the close-out; render the
      6953b98f review frames; record what was better and what regressed (design §1).

## 2. World anchoring
- [x] 2.1 Drop the ship from `Atmosphere` (`advance`, `_shift`, `FogLayer.parallax`) and the shader offset.
- [x] 2.2 Drop the ship parallax from the ground-atmosphere art (`offset`, bands, cloud shadows).
- [x] 2.3 `SentinelForeshadow.place()` without the ship; slower fade-in (3 s).

## 3. Pervasive layers
- [x] 3.1 The art adds to the fBm horizon band and far banks instead of replacing them; low cloud deck at .45
      under the horizon band.
- [x] 3.2 Upper veil and mid veil layers; wider profiles for the horizon band and banks; ground fog from the
      horizon; five air layers in the creatures' depth sort (`Atmosphere.depthSlots`).
- [x] 3.3 Lane clearing for the layers that reach the near lane; analytic and rendered lane-cap tests.
- [x] 3.4 Softer shader wisp cut.

## 4. Sentinel
- [x] 4.1 Silhouette after the horizon band, behind banks A/B and both veils; the sentinel's flight crosses
      every layer.

## 5. Verification
- [x] 5.1 `test/fog_restoration_test.dart`: depth order, coverage, layers in front of the silhouette, lane
      cap (analytic and rendered), fog unchanged by the ship's position, silhouette path independent of it.
- [x] 5.2 Existing tests updated (`ground_atmosphere_test.dart`, `atmosphere_swarms_test.dart`); sim parity
      tests unchanged and passing; `flutter analyze` clean.
- [x] 5.3 Review frames and `art/contact/fog-restoration.png` (3 sectors, before/after, foreshadow + incoming
      wave, sentinel arriving).
- [ ] 5.4 Operator playtest on a device (shader path and frame-time guard on a phone).
