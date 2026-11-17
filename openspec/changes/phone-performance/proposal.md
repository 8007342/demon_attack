# Proposal: phone performance (P1)

## Why
Operator round 4, P1 (`plan/operator-feedback-2026-11-17.md`): on an iPhone the live release dropped frames in heavy
action and bullet fights and the phone warmed up quickly. Heavy bullet action had "weird harmonics with framerate" and
looked choppier than it was. The operator asked to tone down background eye candy where the loss is negligible, to cap
"the amount of random crap being animated" for older devices, and to compress the app, which has "organically grown
quite large".

## What Changes
- **Frame-cost harness** (`test/phone_performance_review_test.dart`, `test/support/counting_canvas.dart`): renders the
  heaviest scenes headless and counts, per layer, draw calls, sprites, vertex draws, save-layers and blurs. The scene
  marks its layers through a one-line `LayerSink` hook.
- **Frame budget and adaptive tiers** (`lib/game/perf/frame_budget.dart`): target 60 Hz (what Safari runs on iPhone,
  ProMotion included), and three quality tiers (FULL, LEAN, LITE) picked from measured frame intervals, with
  hysteresis and no oscillation. `?perf=lite` forces a tier.
- **Caps and tune-downs**: explosion sprites and deflect stars capped per frame, the fog-bank boss shadow blurred once
  instead of per draw, coarser ground-fog strips, and a fix that stops the backdrop drawing two worlds after a travel.
  LEAN and LITE shed fog sheets, blur layers, rain, motes and sparks.
- **Steady stepping**: a frame interval within 2 ms of a whole number of 60 Hz steps is snapped to it, so jittered
  vsync timestamps step the fixed 1/60 s model once a frame instead of 0 then 2.
- **Bullet rendering** (`lib/game/shot_layer.dart`): shots drawn at their interpolated position, a faint motion smear
  one display frame long, a shimmer keyed to age instead of height, and the whole layer batched (one `drawAtlas`).
- **Asset compression**: the five sector paintings, the cosmic sky and the hint scenes ship as WebP (15.1 MB of PNG
  to 1.8 MB), with a recipe (`tools/asset_compress/webp.lua`).
- **Regression gate** (`test/phone_performance_test.dart`): budgets on counts (draw calls, steps per frame, tier
  changes), never on wall time.

## Impact
- Code: new `lib/game/perf/frame_budget.dart` and `lib/game/shot_layer.dart`; hooks in `lib/game/scene.dart`
  (`// --- phone-performance`), `atmosphere.dart`, `ground_painter.dart`, `sector_background.dart`,
  `weather/rain_layer.dart`, `ship_painter.dart`; one getter in `model.dart` (`stepRemainder`). No gameplay rule,
  speed or fire rate changes (`fire-rate-tune` owns those; coordination in design §6.5).
- Assets: seven PNGs replaced by WebP; `lib/game/ground_atmosphere_atlas.dart` regenerated (its tints are sampled from
  the paintings). Tools that read the paintings (`rigsheet`, `widescreen_assets`, `ground_atmosphere`) decode WebP.
- Specs: `arcade-presentation` (tiers, caps, stepping, bullets), `deployment` (compressed backdrops).
- Calibration: unchanged (presentation only; the simulation still steps exactly 1/60 s).
- Research: `plan/phone-performance-research.md`. Measurements: `plan/phone-performance-ledger.md`. Sheets:
  `art/contact/phone-performance-*.png`.
