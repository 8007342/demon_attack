# Tasks

## 1. Research
- [x] 1.1 Flutter web renderers, Wasm, profiling, FrameTiming; Safari rAF on ProMotion and in Low Power Mode; heat and battery signals; draw costs; Flame; temporal aliasing; asset formats and deferred loading: `plan/phone-performance-research.md`, unsourced claims in `plan/provenance-audit.md` Part PP

## 2. Measure
- [x] 2.1 `test/support/counting_canvas.dart` and the scene's `LayerSink` markers (`// --- phone-performance`)
- [x] 2.2 `test/phone_performance_review_test.dart`: bullet fight, ground war in a downpour, settled and unsettled backdrop, carrier fight and break-up; per-layer counts to `build/perf/<tag>.json`
- [x] 2.3 Inventory of ambient systems, caps, save-layers and blurs (design §4.2, ledger §3)
- [x] 2.4 Bundle size per asset group before and after (ledger §4)

## 3. Tiers
- [x] 3.1 `PerfTier`, `FrameBudget`, `PerfGovernor` (window, hysteresis, ceiling, warm-up, `?perf=`)
- [x] 3.2 `DemonScene.applyBudget`: fog (`Atmosphere.tierReduced`, `drawnQuality`), rain, motes; the saved choice untouched

## 4. Caps and tune-downs
- [x] 4.1 Blasts and deflect stars capped where drawn; LITE drops ricochet sparks and the eye-halo blur
- [x] 4.2 Fog-bank boss shadow blurred once (`_fogShadowCell`)
- [x] 4.3 Ground-fog strips 7 / 12 / 18
- [x] 4.4 The backdrop lands on the sector after a travel

## 5. Stepping
- [x] 5.1 `snapFrameDelta` in `DemonScene.update`; `ArcadeModel.stepRemainder`

## 6. Bullets
- [x] 6.1 `ShotLayer`: interpolation, smear, one `drawAtlas`, paths per colour; atlas-less fallback kept
- [x] 6.2 `ShipPainter.shotFrame` on age; `shotColumn`
- [x] 6.3 Spacing rule for `fire-rate-tune` (design §6.5)

## 7. Gate
- [x] 7.1 `test/phone_performance_test.dart` (counts, never wall time)

## 8. Assets and loading
- [x] 8.1 Seven backdrops to WebP (`tools/asset_compress/webp.lua`); references, tools (`rigsheet`, `widescreen_assets`, `ground_atmosphere`), family JSON; `ground_atmosphere_atlas.dart` regenerated
- [ ] 8.2 Deferred imports for the ending page and the dev console (refactor of shared `main.dart`, when no one else is in it)
- [ ] 8.3 Measure a `--wasm` build's size and its Chromium frame cost (iPhones stay on CanvasKit)
- [ ] 8.4 Carrier hero pages: repack (35–60 % empty) with `boss_sheet pack` from fresh rigkit bakes, or lossless WebP pages once `boss_atlas.dart` can name them

## 9. Device checks (operator)
- [ ] 9.1 Play the live build on the iPhone: bullet fight and carrier fight, FULL tier, Safari Web Inspector timeline
- [ ] 9.2 Check whether Safari's frame intervals jitter around 16.7 ms (`?perf=full`; design §5)
- [ ] 9.3 Low Power Mode and an older iPhone: how soon LEAN and LITE engage, and whether they look acceptable
- [ ] 9.4 Heat over 10 minutes against the previous release

## 10. Gates
- [x] 10.1 `flutter analyze`, `flutter test` (lock, concurrency 2), `npm run test:worker`, `npm run build`, `openspec validate phone-performance --strict`, calibration gates
