# Phone performance ledger (change `phone-performance`)

Measured numbers only. Design: `openspec/changes/phone-performance/design.md`. Research:
`plan/phone-performance-research.md`. Sheets: `art/contact/phone-performance-*.png`.

## 1. How it was measured (2026-11-17)

- **Frame cost.** `test/phone_performance_review_test.dart` (review-tagged; run with
  `flutter test --concurrency=1 --run-skipped --tags review --dart-define=PERF_TAG=<tag> test/phone_performance_review_test.dart`)
  paints each scene once through `test/support/counting_canvas.dart` at an iPhone 12–15 viewport (390 × 844 CSS px,
  DPR 3) and counts every canvas call per layer. "before" ran on `origin/game` at 5961ae11 with only the harness and the
  layer markers added (a detached worktree); "after" on this branch. Counts are deterministic.
- **CPU raster ms** is the forge CPU rasterising the recorded frame at 1170 × 2532 in the Flutter tester (no GPU). It
  is indicative only: the fog shader and blur layers dominate it, which a phone GPU does far faster. It is not an iPhone
  frame time.
- **Bundle.** `npm run build` (Flutter 3.47.7, release, `--no-web-resources-cdn`) before and after; sizes are file
  bytes, gzip with `gzip -9`.
- **Stepping.** The fixed-step loop of `ArcadeModel.update`, fed synthetic interval sequences (the gate test, and the
  same loop in Lua for the counts).

## 2. Frame cost per scene (whole frame)

Scenes: **bullet-fight** (sector 4, hard, 61 creatures at the active cap, 70 player and 60 hostile shots, 30 blasts);
**ground-war-rain** (sector 3 at a busy ground skirmish, downpour forced); **ground-war-env-unsettled** (the same frame
with the backdrop's sector blend a hair short of the sector after one presentation step); **carrier-fight** (sector 5,
route 0, the hero carrier fight-ready, 3 s in); **carrier-breakup** (the same fight after the shield drop and two
armour steps: 87 components). The `-lean` and `-lite` rows force that tier on the same frame.

| Scene | Build | Draw calls | Image draws | Atlas calls/sprites | Vertex draws | Save-layers | Blurs | Shader paints | CPU raster ms (forge) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bullet-fight | before | 636 | 283 | 10/154 | 5 | 11 | 2 | 118 | 842.3 |
| bullet-fight | after | 324 | 151 | 11/284 | 5 | 11 | 2 | 96 | 895.2 |
| bullet-fight-lean | after | 279 | 138 | 13/346 | 3 | 4 | 0 | 74 | 93.2 |
| bullet-fight-lite | after | 264 | 132 | 13/346 | 3 | 4 | 0 | 74 | 91.8 |
| ground-war-rain | before | 364 | 130 | 4/120 | 6 | 11 | 2 | 121 | 866.2 |
| ground-war-rain | after | 303 | 115 | 5/135 | 6 | 11 | 2 | 99 | 883 |
| ground-war-rain-lean | after | 263 | 108 | 7/150 | 3 | 4 | 0 | 76 | 89.1 |
| ground-war-rain-lite | after | 254 | 108 | 7/150 | 3 | 4 | 0 | 76 | 92.6 |
| ground-war-env-unsettled | before | 368 | 131 | 8/252 | 9 | 11 | 2 | 123 | 856.3 |
| ground-war-env-unsettled | after | 300 | 115 | 5/135 | 6 | 11 | 2 | 99 | 887.2 |
| carrier-fight | before | 569 | 31 | 4/128 | 9 | 15 | 6 | 133 | 841.3 |
| carrier-fight | after | 545 | 26 | 5/133 | 9 | 15 | 2 | 111 | 855.7 |
| carrier-breakup | before | 438 | 61 | 5/126 | 11 | 16 | 7 | 137 | 910.2 |
| carrier-breakup | after | 410 | 52 | 6/135 | 11 | 16 | 3 | 115 | 932.7 |

Reading it:
- **FULL tier, same look:** draw calls −49 % in the bullet fight (636 → 324) and −17 % in the ground war (364 → 303);
  carrier fight blurs 6 → 2 and break-up 7 → 3 (the fog-bank boss shadow blurred once); shader paints −19 / −18 % (118 → 96, 121 → 99)
  (coarser ground-fog strips). The unsettled backdrop no longer draws a second world: vertex draws 9 → 6, atlas
  sprites 252 → 135.
- **FULL-tier raster is not lower** on the forge CPU (842 → 895 ms, within run-to-run noise; the smear adds a few
  rects). The FULL wins are CPU-side (fewer JS-to-Wasm draw calls, fewer offscreen blur layers per draw), not fill.
- **LEAN and LITE** cut save-layers 11 → 4 and blurs 2 → 0, and the forge CPU raster about nine-fold (895 → 93 ms in
  the bullet fight), because the fog shader and the blurred shadow layers are gone.

### 2.1 Per layer: bullet fight

| Layer | Before calls | After calls | Before save-layers | After save-layers |
|---|---:|---:|---:|---:|
| background | 47 | 47 | 0 | 0 |
| creatures | 106 | 106 | 0 | 0 |
| fog | 110 | 88 | 7 | 7 |
| ground | 37 | 37 | 0 | 0 |
| overlay | 6 | 6 | 2 | 2 |
| player | 30 | 28 | 0 | 0 |
| shadows | 2 | 2 | 2 | 2 |
| shots | 298 | 10 | 0 | 0 |

`player` 30 → 28: the explosion cap (30 blasts alive, 28 drawn at FULL; they are drawn in that layer).

### 2.2 Per layer: carrier fight

| Layer | Before calls | After calls | Before save-layers | After save-layers |
|---|---:|---:|---:|---:|
| background | 53 | 53 | 0 | 0 |
| creatures | 199 | 199 | 1 | 1 |
| fog | 116 | 94 | 9 | 9 |
| ground | 24 | 24 | 0 | 0 |
| overlay | 169 | 169 | 3 | 3 |
| player | 1 | 1 | 0 | 0 |
| shadows | 2 | 2 | 2 | 2 |
| shots | 5 | 3 | 0 | 0 |

The four blurs that left the `creatures` layer are the fog-bank boss shadow. The carrier hero mesh's vertex count could
not be read from the canvas (a `Vertices` object is opaque); `armada.meshVertices` and `breakup.lastVertices` read 0 in
this headless setup, so the handoff's 5,058-vertex figure is **not re-measured** here.

### 2.3 Visual parity (FULL, after against before)

Whole-frame PSNR of the 390 × 844 frames (`magick compare -metric PSNR`), the frames on the sheets:

| Scene | PSNR dB |
|---|---:|
| bullet-fight | 37.9279 |
| ground-war-rain | 44.4979 |
| ground-war-env-unsettled | 33.1117 |
| carrier-fight | 50.9992 |
| carrier-breakup | 50.7083 |

The differences are the WebP backdrops, the coarser ground-fog strips, the shot smear and (bullet fight) the two oldest
explosions over the cap. The unsettled frame is lowest because the before frame also drew the near world under the far
one (its motes and seams show through); on the sheet the two are indistinguishable.

## 3. Ambient systems and caps (inventory)

The full inventory (every ambient system, its count constants, primitives, switches, and every save-layer and blur in
`lib/game`) is design §4.2 and the tables it summarises. Measured per frame in the scenes above (FULL, after):
fog 88 calls and 7 save-layers in the sector 3 and 4 scenes, 94 and 9 in the carrier fight (LEAN and LITE: 72 and 3); creature shadows 2–3 blurred full-screen layers;
rain 193 far + 77 near streaks + 29 splashes in a downpour (LEAN 116 + 46 + 20, LITE 68 + 27 + 10).

## 4. Bundle

| Item | Before | After |
|---|---:|---:|
| `main.dart.js` | 3,885,385 B (gzip 1,194,677) | 3,889,754 B (gzip 1,196,756) |
| `canvaskit/canvaskit.wasm` (what Safari loads) | 7,284,602 B (gzip 2,916,585) | unchanged |
| `assets/images/` in the build | 27,063,183 B | 13,728,625 B |
| The seven converted backdrops | 15,141,237 B (PNG) | 1,806,664 B (WebP q88) |
| Images fetched at startup (5 sectors, sky, hint scenes, combat, effects, cockpit, insignia, ship, ground forces, troops, ground atmosphere) | 15,803,945 B | 2,469,387 B |
| `build/web/assets` | 27,963 KiB | 14,941 KiB |
| `build/web/gallery` (second app, not loaded by players) | 93,126 KiB | 80,109 KiB |
| `build/web/audio` (not in scope) | 24,221 KiB | 24,221 KiB |

WebP per file (`lua tools/asset_compress/webp.lua`, quality 88, method 6, sharp YUV; PSNR against the PNG):

| File | PNG B | WebP B | Ratio | PSNR dB |
|---|---:|---:|---:|---:|
| sector-1 | 1,721,861 | 185,374 | 10.8 % | 39.43 |
| sector-2 | 2,221,290 | 246,886 | 11.1 % | 39.12 |
| sector-3 | 1,930,290 | 214,064 | 11.1 % | 37.10 |
| sector-4 | 2,245,176 | 301,086 | 13.4 % | 38.77 |
| sector-5 | 2,292,707 | 278,060 | 12.1 % | 36.74 |
| cosmic-sky | 2,296,272 | 242,178 | 10.5 % | 39.31 |
| hint-scenes | 2,433,641 | 339,016 | 13.9 % | 36.39 |

`main.dart.js` grew 4,369 B (the tiers, the shot layer). `lib/game/ground_atmosphere_atlas.dart` was regenerated from
the WebP paintings (`go run . pack`, `check` passes): fog tints moved by at most 5/255 (sector 3 `0x442F3C` →
`0x423037`, sector 5 `0x3C273F` → `0x39283A`).

## 5. Stepping

Fed to the model's fixed 1/60 s accumulator for 600 frames:

| Intervals | Frames stepping 0 or 2 times, raw | With `snapFrameDelta` |
|---|---:|---:|
| 16, 17, 17 ms repeating (rounded timestamps) | 400 (200 + 200) | 0 |
| 1/59.94 s | 0 | 0 |
| 33, 34 ms alternating | — | 0 (every frame exactly 2 steps) |

## 6. Not measured here (needs the iPhone)

Real frame times in Safari, whether Safari's rAF intervals jitter around 16.7 ms, the time to reach LEAN in Low Power
Mode on a real device, heat over a session, and the smear's look on the phone's panel (tasks 9.1–9.4).
