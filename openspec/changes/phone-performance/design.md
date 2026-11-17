# Design: phone performance

Research with sources: `plan/phone-performance-research.md` (R§n below). Every number here was measured; where and how
is in `plan/phone-performance-ledger.md` (L§n). Unsourced claims carry their audit marker.

## 1. What the phone sees

- **Frame rate.** On iPhone, Safari renders near 60 Hz even on 120 Hz ProMotion panels: WebKit's
  `PreferPageRenderingUpdatesNear60FPSEnabled` is on by default, and Low Power Mode (and an aggressive thermal
  mitigation) halves it to 30 [source: WebKit project, "UnifiedWebPreferences.yaml",
  https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WTF/Scripts/Preferences/UnifiedWebPreferences.yaml, read
  2026-11-17] [source: WebKit project, "AnimationFrameRate.cpp",
  https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/graphics/AnimationFrameRate.cpp, read
  2026-11-17]. Flutter renders at the browser's rate [source: flutter/flutter, "[iOS, web] Slow scrolling. Not real
  120Hz" (#117714), https://github.com/flutter/flutter/issues/117714, read 2026-11-17].
- **Renderer.** Every iOS browser runs dart2js + CanvasKit: the Wasm build's allow-list has WebKit off by default and
  needs Safari 26.2+ [source: Flutter team, "Support for WebAssembly (Wasm)",
  https://docs.flutter.dev/platform-integration/web/wasm, read 2026-11-17]. So every draw call crosses JS into the
  CanvasKit Wasm module, and draw-call count matters on the phone's CPU, not only on its GPU.
- **No heat signal.** Safari exposes neither the Compute Pressure API nor the Battery Status API [source: MDN,
  "browser-compat-data api/PressureObserver.json",
  https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/PressureObserver.json, read 2026-11-17] [source:
  MDN, "browser-compat-data api/Navigator.json",
  https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/Navigator.json, read 2026-11-17]. The frame
  interval is the only signal a page can read.
- **Costs.** `saveLayer` switches render targets, flushes batching and copies memory [source: Flutter team,
  "Canvas.saveLayer", https://api.flutter.dev/flutter/dart-ui/Canvas/saveLayer.html, read 2026-11-17]; `drawAtlas` is
  more efficient than many `drawImageRect` calls [source: Flutter team, "Canvas.drawAtlas",
  https://api.flutter.dev/flutter/dart-ui/Canvas/drawAtlas.html, read 2026-11-17]. Cutting frame time below the budget
  helps battery and heat even when it can't be seen [source: Flutter team, "Performance best practices",
  https://docs.flutter.dev/perf/best-practices, read 2026-11-17].

Measured before (L§2, iPhone 12-15 viewport 390 × 844 at 3×): a 61-creature, 130-shot fight issued **636 draw calls,
11 save-layers and 2 blur layers** a frame; 298 of the calls were the shots alone. The fog was 110 calls, 7 save-layers
and 108 shader-filled rects every frame in every scene. The carrier fight added 4 per-draw blurs (the boss shadow on
the fog banks). After a travel that ends a hair short of the next sector, the backdrop drew both worlds every frame
(drawVertices calls 6 → 9, atlas sprites 135 → 252).

## 2. Frame budget: 60 Hz, steady

Target: **60 Hz** with an even cadence, because that is what Safari gives an iPhone (§1). No self-imposed 30 Hz lock:
the page cannot pick its rAF rate, skipping alternate frames would only halve motion clarity, and heat comes from the
work per frame, which the tiers cut. When Safari itself runs at 30 (Low Power Mode), the game steps exactly twice a
frame (§5) and the governor drops to LITE (§3), which is what a player in Low Power Mode wants.
That an even cadence looks better than a higher uneven one is not sourced here [UNSOURCED:
plan/provenance-audit.md#pp-pacing]; the design does not depend on it.

## 3. Adaptive tiers

`PerfGovernor` (`lib/game/perf/frame_budget.dart`) reads each frame's wall-clock interval from `DemonScene.update`:

- A frame is **slow** above 1.5 × 1/60 s (25 ms). Intervals above 250 ms (a background tab) and the first 2 s are
  ignored.
- Over a window of 120 frames, more than 10 % slow frames **steps down** one tier (FULL → LEAN → LITE) and clears the
  window, so each step needs fresh evidence.
- Fewer than 2 % slow frames for 20 s **steps back up** one tier.
- A step down within 30 s of a step up makes the lower tier the **session ceiling**: no oscillation.
- `?perf=full|lean|lite` forces a tier (testing, a player's choice).

The existing atmosphere frame guard (fog shader off when frames average slower than 1/45 s) stays; it acts inside the
FULL tier.

## 4. Budgets and caps

| Knob | FULL | LEAN | LITE | Where |
|---|---|---|---|---|
| Fog | player's choice | reduced (2 slots of 8, tiles, no shader) | reduced | `Atmosphere.tierReduced` → `drawnQuality` |
| Creature shadows | up to 3 blurred layers | 1 sharp layer, flat | same | follows the drawn fog quality |
| Wreck smoke | 3 puffs a wreck | 1 puff | 1 puff | follows the drawn fog quality |
| Rain drops and splashes | 100 % | 60 % | 35 % | `RainLayer.budget` |
| Sector motes | 100 % | 75 % | 50 % | `SectorBackground.moteScale` |
| Explosion sprites drawn | 28 newest | 20 | 14 | scene blast loop |
| Deflect stars drawn | 24 newest | 24 | 24 (no ricochet sparks) | `DemonScene.maxDeflectsDrawn` |
| Sentinel eye halo blur | on | on | off (sharp) | `FrameBudget.blur` |

The player's saved atmosphere choice is never overwritten: the tier forces the drawn quality only.

### 4.1 Always-on tune-downs (FULL included)

1. **Fog-bank boss shadow blurred once.** It was drawn with a per-draw `ImageFilter.blur(4, 3)` on up to 4 fog slots a
   frame, each an offscreen layer. The cell is now blurred once (sigma mapped to cell pixels at the mean drawn scale,
   .875 × .45) and drawn plain. Carrier-fight blurs: 6 → 2 a frame (L§2).
2. **Ground-fog strips** 5 / 9 / 14 → 7 / 12 / 18 units. Each strip is two `ImageShader` rects built every frame; the
   fog's soft noise hides the coarser piecewise-linear mapping. Fog calls: 110 → 88 a frame (116 → 94 in the carrier fight; L§2).
3. **The backdrop lands on the sector.** The exponential approach after a travel never reaches the integer, so a hair
   short of it `SectorBackground` drew both worlds, the far one at 99.9 %. It now snaps within 0.001.
4. **Shots batched** (§6.4): 298 → 10 calls for 130 shots.

Sheets: `art/contact/phone-performance-{bullet-fight,ground-war-rain,carrier-fight,carrier-breakup,env-settle}.png`
(before, after; the first two also show LEAN and LITE).

### 4.2 Hard caps already in place (inventory, kept)

`GroundPainter.maxSmoke` 14, `maxTracers` 48 (ground war), rain `farMax` 200 / `nearMax` 80 / `splashMax` 64,
`EasterEggBudget` (`maxFlock` 9, `maxConcurrent` 2, `maxCritters` 8, `maxDebrisOnScreen` 16), vegetation burst
particles 160, hatch smoke 90, shield shards 12, carrier collapse puffs 90 and blasts 32, carrier speed streaks 40.
Unbounded before this change and now capped where drawn: `model.blasts` and `model.deflects`.

## 5. Steady stepping

The model steps a fixed 1/60 s from an accumulator (`ArcadeModel.update`). A frame interval that jitters around 1/60
(rounded timestamps, a 59.94 Hz panel) leaves the accumulator a hair short on one frame and over on the next: the
whole world stalls for a frame, then jumps two steps. A fast bullet at 390 px/s jumps 13 px after a 0 px frame. The
scene now passes `snapFrameDelta(dt)`: an interval within 2 ms of 1, 2, 3 or 4 steps becomes exactly that.

- Rounded 16 / 17 / 17 ms intervals: 400 of 600 frames stepped 0 or 2 times (200 each) → 0 after the snap
  (`test/phone_performance_test.dart`; the same loop run in Lua for this count). A 59.94 Hz panel drifts slowly
  instead: no uneven frame in 600 without the snap (by arithmetic, one stall every 1/0.06 Hz = 16.7 s).
- 30 Hz: exactly 2 steps every frame. 90, 120 Hz and hitches pass through unchanged (shots are interpolated, §6.1).
- The simulation is untouched: it still advances in exact 1/60 s steps, so calibration is unchanged.

That Safari's rAF timestamps jitter enough to trigger this on an iPhone is not yet measured [UNSOURCED:
plan/provenance-audit.md#pp-safari-timestamps]; task 9.2 checks it.

## 6. Bullet rendering (anti-strobe)

Two artefacts made bullet streams strobe:

- the 0-then-2 step cadence above, and
- the shot's two-frame shimmer keyed to its height: `frame = (clock·12 + y/9) mod 2`. At 6.5 px a step the `y/9` term
  flipped every 1.38 steps, an irregular 1-1-2 flicker beating against the 12 Hz clock term in every stream.

The wagon-wheel effect (identical objects seeming to stall or reverse when the per-frame move nears their spacing) and
smear as its remedy are not sourced here [UNSOURCED: plan/provenance-audit.md#pp-wagon-wheel]; the fixed-step plus
interpolation pattern is [source: MDN, "Anatomy of a video game", https://developer.mozilla.org/en-US/docs/Games/Anatomy,
read 2026-11-17].

### 6.1 Interpolation
Shots fly straight at a constant velocity, so each is drawn at `x + vx·r·lead, y + vy·lead`, where `lead` is the time
banked toward the next step (`ArcadeModel.stepRemainder`, under 1/60 s; 0 when the run isn't playing) and `r` the
hostile rate on x. At 90 or 120 Hz the shots move every frame instead of every other. The model positions are unchanged.

### 6.2 Shimmer on age
`ShipPainter.shotFrame(s) = floor(age·12) mod 2`: a steady 12 Hz, independent of speed and frame rate.

### 6.3 Motion smear
A shot faster than 200 px/s leaves a two-segment streak behind it, as long as its travel in one display frame (the
governor's smoothed interval × speed, at most 14 px), at 30 % then 15 % opacity, 2 px wide (3 for hostile bolts), pixel
aligned. Reduced motion drops it. The interval is held while the run is paused, so a paused frame is unchanged.

### 6.4 Batching
All shot sprites are one `drawAtlas` (`RSTransform` scale .75: the 64 px cells at 48 units, as `ShipPainter.layer`
draws them); wakes and smears are one path per colour. The sprite pixels are unchanged (`art/contact/
phone-performance-bullet-fight.png`).

### 6.5 Coordination with `fire-rate-tune`
`fire-rate-tune` owns shot speeds and fire rates (`model.dart`). This change only draws them. For stream readability at
both 60 and 30 Hz, keep each stream's spacing at least 3 × its 30 Hz per-frame move, so identical bullets never move
more than a third of their gap in a frame:

| Stream | Speed | Interval | Spacing | Move at 60 / 30 Hz | Spacing ÷ 30 Hz move |
|---|---|---|---|---|---|
| Player, normal | 390 px/s | .23 s | 89.7 px | 6.5 / 13 px | 6.9 |
| Player, rapid | 390 px/s | .105 s | 41 px | 6.5 / 13 px | 3.2 |
| Rule | v | t | v·t | v/60 / v/30 | ≥ 3, so t ≥ .1 s at any speed |

The rule is `interval ≥ 0.1 s`, whatever the speed (spacing ÷ move = interval × 30). A faster fire rate than 10 shots a
second per stream needs a smear long enough to bridge the gap instead.

## 7. Regression gate

`test/phone_performance_test.dart` runs in the default suite and budgets counts, never wall time:

- the shots layer of a 200-shot frame: ≤ 16 draw calls, the same as for 10 shots;
- frame pacing: 0 idle or double steps under jittered 60 Hz and 59.94 Hz, exactly 2 at 30 Hz;
- the governor: stays FULL at 60 Hz with 2 % hitches; reaches LITE under sustained 30 Hz; no oscillation;
- each tier draws no more than the one above it; the tier reaches the painters; the saved choice is kept;
- the backdrop lands on the sector.

The per-layer harness (`test/phone_performance_review_test.dart`, review-tagged) is the measuring tool for future
changes: it writes `build/perf/<tag>.json` and frames for before/after sheets.

## 8. Assets and loading

- **Startup images.** `DemonScene.onLoad` loads all five sector paintings and the sky, and `main.dart` precaches the
  hint scenes: 15.1 MB of PNG before the first frame. They are painted, opaque art drawn under a 50 % dark overlay and
  fog, so lossy WebP (quality 88, sharp YUV) is invisible: PSNR 36.4–39.4 dB, 1.8 MB in all (L§4). Sprite atlases and
  pixel art stay PNG. Flutter web decodes WebP through the browser [source: Flutter team, "image_decoder.dart",
  https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/lib/web_ui/lib/src/engine/image_decoder.dart,
  read 2026-11-17]; Safari decodes WebP from Safari 14 on macOS [source: MDN, "Image file type and format guide",
  https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types, read 2026-11-17] (iOS versions
  [UNSOURCED: plan/provenance-audit.md#pp-ios-formats]; the game already ships `beach-ending.webp`).
- **One format.** The PNGs are deleted (CLAUDE.md: one format per asset, no committed lossless masters); the recipe is
  `lua tools/asset_compress/webp.lua`. The tools that read the paintings decode WebP, and
  `lib/game/ground_atmosphere_atlas.dart` was regenerated (`go run . pack`): its fog tints move by at most 5/255.
- **Carrier hero pages** (10.8 MB, 35–60 % empty) load lazily on approach already. Repacking them needs `boss_sheet
  pack` from rigkit bakes that are not in this forge; lossless WebP pages need the generated `boss_atlas.dart` to name
  `.webp`. Both are tasks (8.4), not done here.
- **Code.** `main.dart.js` is 3.89 MB (1.20 MB gzip). Deferred imports split it into separate `.js` files on web
  [source: Flutter team, "Deferred components", https://docs.flutter.dev/perf/deferred-components, read 2026-11-17];
  candidates are the ending page and the dev console (task 8.2, a refactor of `main.dart`, shared). `--wasm` doesn't
  reach iPhones (§1) [UNSOURCED size comparison: plan/provenance-audit.md#pp-wasm-size].
- **Gallery.** `build/web/gallery` is a second app with its own copy of every asset (93 MB before, 80 MB after). Players
  never load it; it only costs deploy upload.

## 9. What only a real iPhone can tell

The harness counts calls on the forge; CPU raster times are the forge CPU's (indicative only). On an iPhone, check: the
FULL-tier frame time in a bullet fight and the carrier fight (Safari Web Inspector timeline); whether Safari's rAF
intervals jitter enough for §5; how fast the governor reaches LEAN on an older iPhone and in Low Power Mode; whether
the smear reads well at 60 Hz on the OLED panel; and the heat over a 10-minute session against the live release.
