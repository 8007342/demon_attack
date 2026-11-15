# Tasks

## 1. Projector
- [x] 1.1 Add `lib/game/shadow_projector.dart`: caster record `(x, z, h, footprint, kind)`, sun state (θ = 32°, drift), the three-iteration hit-point march against a `GroundRelief`, and the 4 × 3 drape vertices via `TerrainView.yOf` / `surfaceAt(..).hidden` (design §2)
- [x] 1.2 `test/shadow_projector_test.dart`: flat-ground equivalence to the legacy centre (≤ 0.01 u), ridge stretch, crest occlusion, morph continuity across `mix` 0 → 1 (≤ 2 u per 1/60 s)

## 2. Scene integration
- [x] 2.1 Turn `_shadowOf` into caster construction (creatures, divers, in-play sentinels with the rush-lock snap retargeted to the ship's projected hit point, ship); keep alpha, buckets and the death ghosts unchanged
- [x] 2.2 Draw each (image, bucket) batch with `drawVertices` + `ImageShader` inside the existing bucket `saveLayer`; keep `shadowLayers ≤ 3`, expose `shadowDrawCalls` for tests
- [x] 2.3 `ShadowMode.flat` fallback on `AtmosphereQuality.reduced` and the governor's low tier; keep today's path byte-identical there
- [x] 2.4 Softness from height above the hit surface (`k = (h − t) / 300`)

## 3. Lurking shadow and boss shadow
- [x] 3.1 `SentinelForeshadow.lurk` track: far terrain → front depth, 10–16 u/s, meander (amplitude 30, period 9 s), own PRNG stream `seed ^ 0x5E57`; reduced motion drops the meander
- [x] 3.2 Lurking caster: alpha `0.30 · rise · groundLight`, footprint ×2.5 → ×1.3 growth, bucket 2; 0.8 s hand-off into the in-play sentinel shadow (one shadow at all times)
- [x] 3.3 Ground hesitation under the lurking footprint (critter duck; ground unit pace × 0.7), presentation only
- [x] 3.4 Boss shadow cell baked once per hull load (alpha, ×0.5 area downscale, inked) and a boss caster at a default altitude of 160, exposing `bossShadowAltitude` for `boss-grandeur`

## 4. Validation
- [x] 4.1 Scene tests: layer count, draw calls per bucket, reduced-tier byte identity, the perf test within its existing budget
- [x] 4.2 `test/terrain_shadows_review_test.dart` → `art/contact/terrain-shadows-relief.png`, `-lurk.png`, `-boss.png` at 360 × 780 and 1280 × 720 (design §5)
- [x] 4.3 Update `continuous-swarm` design §8 cross-reference and `plan/atmosphere-research.md` §11 readability note

## 5. Lurk visibility (follow-up)
- [x] 5.1 Draw the lurk as an occluder of the ground's light: baked soft mask, desaturate + cool multiply on the draped mesh, no blur layer
- [x] 5.2 Dim the depth fog banks over it (`lurkFogPass` after the last bank); faster rise (1.5 s), size floor (n ≥ 0.2), fog only softens it
- [x] 5.3 Cross-fade the occluder into the sentinel's ink shadow through the hand-off
- [x] 5.4 `test/lurk_visibility_review_test.dart`: real phone frames on Hollow, Ember, Krybor and Ringfall, the measured core darkening asserted, and `art/contact/terrain-shadows-lurk-visibility.png`

## Workflow follow-up
- Operator playtest on phone; archive with `openspec archive terrain-shadows` after acceptance.
