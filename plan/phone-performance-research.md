# Phone performance: research (change `phone-performance`)

Research for `openspec/changes/phone-performance` (operator round 4, P1: `plan/operator-feedback-2026-11-17.md`). Every
source marked "read" was fetched from the forge on 2026-11-17 and loaded. Hosts that reset the connection through the
forge proxy are listed at the end; nothing was routed around the proxy. Claims with no read source carry an
`[UNSOURCED: plan/provenance-audit.md#pp-…]` marker (audit Part PP). Measurements are in `plan/phone-performance-ledger.md`.

## 1. Flutter web renderers, Wasm, profiling

- Flutter web draws through WebGL or WebGPU with two renderers, CanvasKit and Skwasm; JS output comes from `dart2js`,
  Wasm output from `dart2wasm` via `--wasm`. The renderers page does not say which renderer is used when.
  [source: Flutter team, "Web renderers", https://docs.flutter.dev/platform-integration/web/renderers, read 2026-11-17]
- `--wasm` needs Flutter 3.24+ and an up-to-date `web/index.html` bootstrap; it builds BOTH targets (`main.dart.wasm` +
  `main.dart.mjs`, and a `main.dart.js` fallback). At startup `flutter_bootstrap.js` probes for WasmGC, JS String
  Builtins and Phase-4 exception handling and checks `wasmAllowList`; otherwise it falls back to dart2js + CanvasKit.
  [source: Flutter team, "Support for WebAssembly (Wasm)", https://docs.flutter.dev/platform-integration/web/wasm, read 2026-11-17]
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
- Safari/iOS: the Wasm build needs Safari 26.2+, and WebKit is OFF by default (`wasmAllowList.webkit: false`), so
  every iOS browser runs dart2js + CanvasKit unless the app sets `wasmAllowList: { webkit: true }`. Chromium 137+ runs
  Wasm by default; Firefox 147+ needs opt-in. Default allow-list is `{ blink: true, gecko: false, webkit: false, unknown: false }`.
  [source: Flutter team, "Support for WebAssembly (Wasm)", https://docs.flutter.dev/platform-integration/web/wasm, read 2026-11-17]
  [source: Flutter team, "Web app initialization", https://docs.flutter.dev/platform-integration/web/initialization, read 2026-11-17]
- Multi-threaded Wasm rendering needs `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy:
  credentialless` (or `require-corp`); without them it is single-threaded (`forceSingleThreadedSkwasm` forces that).
  `.wasm` must be served as `application/wasm`.
  [source: Flutter team, "Support for WebAssembly (Wasm)", https://docs.flutter.dev/platform-integration/web/wasm, read 2026-11-17]
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
- Open skwasm issue: multi-threaded skwasm triggers a major V8 GC on the raster worker almost every frame for large
  canvases (bitmap above ~9-10 MB, about 2.2-2.5 MP); measured on Chrome 157 / macOS only (adds ~0.26 ms raster, est.
  2-2.4 ms CPU per frame). Not tested on Safari.
  [source: vasilich6107 / flutter/flutter, "[web][skwasm] Multi-threaded skwasm triggers a major V8 GC on the raster worker in every frame", https://github.com/flutter/flutter/issues/196484, read 2026-11-17]
- Profiling: evaluate in profile or release mode, never debug. `flutter run -d chrome --profile` (add `--wasm`), or
  `flutter build web --profile` for a deployable profile bundle (JS `-O4` unminified symbols; Wasm `-O2 --no-strip-wasm`).
  Flutter emits timeline events into the Chrome DevTools Performance panel; optional flags `debugProfileBuildsEnabled`,
  `debugProfileLayoutsEnabled`, `debugProfilePaintsEnabled`; custom events via `dart:developer` `Timeline`/`TimelineTask`.
  [source: Flutter team, "Performance profiling for web" (Debugging web performance), https://docs.flutter.dev/perf/web-performance, read 2026-11-17]
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
- The Flutter DevTools Performance view is for mobile/desktop; for web apps Flutter adds timeline events to Chrome
  DevTools instead.
  [source: Flutter team, "Use the Performance view", https://docs.flutter.dev/tools/devtools/performance, read 2026-11-17]
- `FrameTiming` gives `buildDuration` (UI thread), `rasterDuration`, `totalSpan` (vsync start to raster finish),
  `vsyncOverhead`; receive via `SchedulerBinding.addTimingsCallback`. Batches arrive about once per second in release
  and about every 100 ms in debug/profile; overhead "very approximately 0.01% CPU" (iPhone 6s). Neither page mentions web.
  [source: Flutter team, "FrameTiming class", https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html, read 2026-11-17]
  [source: Flutter team, "addTimingsCallback method", https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html, read 2026-11-17]
- Web `onReportTimings` was implemented in 2020 (merged 2020-10-03). Current caveat: open issue that queued frames on the
  shared web renderer path (CanvasKit, Skwasm, both threading modes) drop their `FrameTimingRecorder` and count
  raster-queue wait (~100 ms in a test) as build time. So on web, FrameTiming build/raster split is unreliable today;
  use it for frame-interval/drop counting, not attribution.
  [source: flutter/engine, "Implement window.onReportTimings for web" (PR 21552), https://github.com/flutter/engine/pull/21552, read 2026-11-17]
  [source: kevmoo / flutter/flutter, "[web] SkwasmRenderer.renderScene drops FrameTimingRecorder on queue", https://github.com/flutter/flutter/issues/193696, read 2026-11-17]
- Chrome DevTools Performance panel details (CPU throttling, frames track). [UNSOURCED: plan/provenance-audit.md#pp-chrome-panel]

## 2. Safari on iOS: rAF rate, ProMotion, Low Power Mode

- WebKit's preference `PreferPageRenderingUpdatesNear60FPSEnabled` ("Prefer page rendering updates near 60 frames per
  second rather than using the display's refresh rate") has status `stable` and `defaultValue: true` on every platform
  except visionOS. So on a 120 Hz ProMotion iPhone, rendering updates (and rAF) default to ~60 Hz; users can switch the
  flag off in Settings > Safari > Advanced > Feature Flags (location: snippet only).
  [source: WebKit project, "Source/WTF/Scripts/Preferences/UnifiedWebPreferences.yaml" (main), https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WTF/Scripts/Preferences/UnifiedWebPreferences.yaml, read 2026-11-17]
  [source: MacRumors, "Enable Smoother 120Hz Browsing in Safari", https://www.macrumors.com/how-to/enable-smoother-120hz-browsing-in-safari/, unread: snippet only]
- WebKit code: with the flag on, a nominal rate above 60 is divided down to the nearest ~60 fps divisor
  (`framesPerSecondNearestFullSpeed`). Half-speed reasons are `LowPowerMode`, `NonInteractedCrossOriginFrame`,
  `VisuallyIdle`, `AggressiveThermalMitigation`: at nominal 60 Hz they give 30 fps (`HalfSpeedThrottlingFramesPerSecond
  = 30`); at other rates the rate is halved. Off-viewport frames drop to a 10 s interval.
  [source: WebKit project, "Source/WebCore/platform/graphics/AnimationFrameRate.h", https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/graphics/AnimationFrameRate.h, read 2026-11-17]
  [source: WebKit project, "Source/WebCore/platform/graphics/AnimationFrameRate.cpp", https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/graphics/AnimationFrameRate.cpp, read 2026-11-17]
- So iOS Low Power Mode caps rAF at 30 fps by design. The bug thread where a WebKit engineer calls this intended
  (iOS 14) could not be fetched.
  [source: WebKit Bugzilla, "Bug 215745 - Throttling requestAnimation Frame to 30 FPS in low power mode on iOS 14 (but not iOS 13)", https://bugs.webkit.org/show_bug.cgi?id=215745, unread: snippet only]
- Flutter issue: Flutter web on iOS at 60 fps while Android reaches ~90; a maintainer says Flutter already renders at
  the browser's maximum rate, so the Safari flag (not Flutter) decides; one report (iOS 18.2 beta 2, iPhone 15 Pro) still
  saw lag with the flag off. Issue open, P2.
  [source: flutter/flutter, "[iOS, web] Slow scrolling. Not real 120Hz" (#117714), https://github.com/flutter/flutter/issues/117714, read 2026-11-17]
- rAF "will generally match the display refresh rate" (60/75/120/144 Hz) and is paused in background tabs; animation must
  use the timestamp, not per-frame increments.
  [source: MDN, "Window: requestAnimationFrame() method", https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame, read 2026-11-17]
- Design consequence (inference from the above, not a cited claim): on iPhone Safari plan for 60 Hz normally and 30 Hz in
  Low Power Mode or aggressive thermal mitigation; the game must be timestamp-driven and look right at 30.

## 3. Thermal throttling, battery, web-exposed signals

- WebKit (Cocoa) treats thermal mitigation as on when `NSProcessInfo.thermalState >= Serious`, and adds the
  `ThermalMitigation` throttling reason; `AggressiveThermalMitigation` (which halves the rendering rate) is only set
  when the internal pref `RespondToThermalPressureAggressively` is on, default `false` (`defaultsOverridable: true`, so
  Safari's actual setting is unknown).
  [source: WebKit project, "Source/WebCore/platform/cocoa/ThermalMitigationNotifier.mm", https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/cocoa/ThermalMitigationNotifier.mm, read 2026-11-17]
  [source: WebKit project, "Source/WebCore/page/Page.cpp", https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/page/Page.cpp, read 2026-11-17]
  [source: WebKit project, "UnifiedWebPreferences.yaml", https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WTF/Scripts/Preferences/UnifiedWebPreferences.yaml, read 2026-11-17]
- Compute Pressure API: `PressureObserver` with states nominal / fair / serious ("may be throttling") / critical; MDN
  lists sources `cpu` and `thermals`; experimental, secure-context only; Permissions-Policy `compute-pressure`.
  The W3C spec (Candidate Recommendation Draft, 26 Oct 2026) defines only the `cpu` source, with thermal conditions as
  an input to the CPU state.
  [source: MDN, "Compute Pressure API", https://developer.mozilla.org/en-US/docs/Web/API/Compute_Pressure_API, read 2026-11-17]
  [source: W3C Devices and Sensors WG, "Compute Pressure Level 1", https://www.w3.org/TR/compute-pressure/, read 2026-11-17]
- Support: Chrome desktop 125+; Chrome Android, Firefox, Safari and Safari iOS: not supported.
  [source: MDN, "browser-compat-data api/PressureObserver.json", https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/PressureObserver.json, read 2026-11-17]
- WebKit's standards position on Compute Pressure is "oppose" (2023-10-04): CPU utilisation is hard to interpret on
  asymmetric cores with frequency scaling, a site's budget should not depend on system load, and cross-origin side
  channel risk.
  [source: WebKit, "Compute Pressure API" standards position (#255), https://github.com/WebKit/standards-positions/issues/255, read 2026-11-17]
- Battery Status API (`navigator.getBattery()`): Chrome 38+ (secure context from 103); Firefox 43-52 then removed;
  Safari and Safari iOS: never.
  [source: MDN, "browser-compat-data api/Navigator.json", https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/Navigator.json, read 2026-11-17]
  [source: MDN, "Battery Status API", https://developer.mozilla.org/en-US/docs/Web/API/Battery_Status_API, read 2026-11-17]
- Consequence: on iPhone Safari there is no web signal for heat or battery. The only observable proxy is the frame
  interval itself (e.g. rAF dropping to ~33 ms means Low Power Mode or a half-speed throttle). (Inference.)
- Flutter: lowering frame time below 16 ms "might not make a visual difference, but it improves battery life and thermal
  issues"; 120 fps devices need under 8 ms total.
  [source: Flutter team, "Performance best practices", https://docs.flutter.dev/perf/best-practices, read 2026-11-17]
- How sustained GPU/CPU load leads to throttling (Apple thermal-state docs, Android ADPF). [UNSOURCED: plan/provenance-audit.md#pp-thermal]

## 4. Frame budget, pacing, adaptive quality

- 60 fps gives 16.7 ms for scripts, style, layout and paint; "it is important to maintain a high and steady frame rate".
  [source: MDN, "Animation performance and frame rate", https://developer.mozilla.org/en-US/docs/Web/Performance/Guides/Animation_performance_and_frame_rate, read 2026-11-17]
- Flutter: aims for 60 fps (120 on capable devices); each frame within ~16 ms or it is dropped (jank). With separate UI and
  raster threads, aim for about 8 ms build + 8 ms raster. Test on the slowest device users might reasonably use, in
  profile mode, on a physical device.
  [source: Flutter team, "Flutter performance profiling", https://docs.flutter.dev/perf/ui-performance, read 2026-11-17]
  [source: Flutter team, "Performance best practices", https://docs.flutter.dev/perf/best-practices, read 2026-11-17]
- Fixed-timestep simulation decoupled from rendering, with the renderer interpolating between updates, is a standard web
  game-loop pattern (costs interpolation work); when frames run long, reduce quality (the RAGE example lowered render
  resolution and skipped assets to hold the budget). MDN flags its example code as needing technical review.
  [source: MDN, "Anatomy of a video game", https://developer.mozilla.org/en-US/docs/Games/Anatomy, read 2026-11-17]
- WebKit's own rate selection prefers integer divisors of the display rate (e.g. 120 -> 60, halved -> 30), which keeps a
  regular cadence. (From the code read in section 2; that this is WHY is an inference.)
- "Consistent pacing beats a jittery higher rate" (e.g. alternating 16/33 ms looks worse than locked 33 ms), the Android
  Frame Pacing (Swappy) rationale, Unity Adaptive Performance and Unreal dynamic resolution: UNSOURCED (developer.android.com,
  docs.unity3d.com, dev.epicgames.com, web.dev all blocked). [UNSOURCED: plan/provenance-audit.md#pp-pacing]

## 5. Canvas draw cost in Flutter/Skia

- `saveLayer` "is relatively expensive": it switches the render target, which can flush the GPU command buffer (losing
  batching) and causes memory churn copying the framebuffer out and back in.
  [source: Flutter team, "Canvas.saveLayer", https://api.flutter.dev/flutter/dart-ui/Canvas/saveLayer.html, read 2026-11-17]
- Best practices: `saveLayer` allocates an offscreen buffer; render target switches are "particularly disruptive" on mobile
  GPUs; `ShaderMask`, `ColorFilter`, some `Chip`/`Text` cases use it. `Opacity` and clipping are expensive; draw with a
  semi-transparent colour instead of `Opacity` (when shapes don't overlap); avoid clipping in animations.
  [source: Flutter team, "Performance best practices", https://docs.flutter.dev/perf/best-practices, read 2026-11-17]
- `drawAtlas` "is more efficient than using multiple calls to drawImageRect" for many parts of one image (sprites);
  `cullRect` allows quick rejection. `drawRawAtlas` is the typed-data-list variant (no perf comparison stated).
  [source: Flutter team, "Canvas.drawAtlas", https://api.flutter.dev/flutter/dart-ui/Canvas/drawAtlas.html, read 2026-11-17]
- `drawVertices` draws triangles from a `Vertices` (`Vertices.raw` from typed lists); no perf guidance on its page.
  [source: Flutter team, "Canvas.drawVertices", https://api.flutter.dev/flutter/dart-ui/Canvas/drawVertices.html, read 2026-11-17]
- `Picture` = recorded ops (via `PictureRecorder`), replayable with `drawPicture`/`addPicture`; `approximateBytesUsed`.
  `Picture.toImageSync` makes a GPU-resident image when a GPU context exists ("more efficient to draw"), rasterised
  asynchronously. Neither page mentions web.
  [source: Flutter team, "Picture class", https://api.flutter.dev/flutter/dart-ui/Picture-class.html, read 2026-11-17]
  [source: Flutter team, "Picture.toImageSync", https://api.flutter.dev/flutter/dart-ui/Picture/toImageSync.html, read 2026-11-17]
- Open issue (Impeller, native): `Picture.toImageSync` allocates a new GPU texture on every call; seen as a title only.
  [source: b3nni97 / flutter/flutter, "[Impeller] Picture.toImageSync allocates a new GPU texture on every call..." (#193941), https://github.com/flutter/flutter/issues/193941, unread: snippet only]
- Blur: `BackdropFilter` "is relatively expensive, especially if the filter is non-local, such as a blur"; `ImageFiltered`
  is cheaper. `ImageFilter.blur` page has no cost note. `MaskFilter.blur` cost [UNSOURCED: plan/provenance-audit.md#pp-maskfilter].
  [source: Flutter team, "BackdropFilter class", https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html, read 2026-11-17]
  [source: Flutter team, "ImageFilter.blur", https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.blur.html, read 2026-11-17]

## 6. Flame-specific

- docs.flame-engine.org was blocked; only pub.dev API docs (flame 1.38.2) were read.
- `SpriteBatch` draws many parts of one image in one pass with `Canvas.drawAtlas` (per-item transform, rotation, colour),
  "more efficient than using multiple calls to Canvas.drawImageRect"; `useAtlas: false` falls back to `drawImageRect`
  (fixes ghost lines, slower). On web `defaultColor` is used as the item background colour.
  [source: Flame team, "SpriteBatch class" (flame 1.38.2), https://pub.dev/documentation/flame/latest/sprite/SpriteBatch-class.html, read 2026-11-17]
- `FpsComponent` (non-visual) reports average fps over a sliding `windowSize` of game ticks, default 60.
  [source: Flame team, "FpsComponent class", https://pub.dev/documentation/flame/latest/components/FpsComponent-class.html, read 2026-11-17]
- `Component.debugMode` defaults false; when on, components draw extra debug info and children inherit it (so ship with it off).
  [source: Flame team, "Component.debugMode", https://pub.dev/documentation/flame/latest/components/Component/debugMode.html, read 2026-11-17]
- `Images` cache: `load`, `loadAll`, `fromCache`, `clear(name)`, `clearCache()`; no memory notes.
  [source: Flame team, "Images class", https://pub.dev/documentation/flame/latest/cache/Images-class.html, read 2026-11-17]
- Component-count guidance, `FpsTextComponent`, Flame rendering-performance advice. [UNSOURCED: plan/provenance-audit.md#pp-flame]

## 7. Temporal aliasing of fast projectiles

- Fixed-step simulation + render interpolation between the previous and current state (MDN "Anatomy of a video game",
  section 4 above) is the read source for decoupling render from simulation.
  [source: MDN, "Anatomy of a video game", https://developer.mozilla.org/en-US/docs/Games/Anatomy, read 2026-11-17]
- Glenn Fiedler's accumulator + `alpha = accumulator / dt` interpolation: not read (gafferongames.com blocked).
  [source: Glenn Fiedler, "Fix Your Timestep!", https://gafferongames.com/post/fix_your_timestep/, unread: blocked]
- Wagon-wheel/stroboscopic effect (apparent motion reverses or stalls when per-frame displacement is near a multiple of the
  spacing between identical objects), motion blur/trails/smear frames, sample-and-hold blur: UNSOURCED (Wikipedia and
  Blur Busters blocked). [UNSOURCED: plan/provenance-audit.md#pp-wagon-wheel] Note for the design: the 30 fps Low Power Mode cap (section 2) doubles per-frame displacement,
  so any bullet-stream spacing tuned at 60 fps should be checked at 30 fps as well. (Inference.)

## 8. Asset size and formats

- Flutter web image decoding (engine source, master): (1) browser `ImageDecoder` (WebCodecs) when available; (2) else
  `createImageBitmap` for static images ("e.g. older browsers or Safari/Firefox fallback"); (3) else Skia codecs inside
  CanvasKit/Skwasm. Comment: Flutter aims to build Skia without built-in decoders to shrink Wasm and prefers native
  browser decoders. Known MIME types include `image/webp` and `image/avif`. So on Safari, WebP/AVIF decode as far as
  Safari's own decoders support them.
  [source: Flutter team, "engine/src/flutter/lib/web_ui/lib/src/engine/image_decoder.dart" (master), https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/lib/web_ui/lib/src/engine/image_decoder.dart, read 2026-11-17]
- `ImageDecoder` support: Chrome 94, Firefox 133, Safari 27.3 (Safari iOS mirrors Safari).
  [source: MDN, "browser-compat-data api/ImageDecoder.json", https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/ImageDecoder.json, read 2026-11-17]
- WebP: all current major browsers; on macOS Safari needs Safari 14 + macOS 11. AVIF: Safari 16.1 (Chrome 85, Firefox
  93). MDN gives no iOS-specific versions; iOS versions [UNSOURCED: plan/provenance-audit.md#pp-ios-formats].
  [source: MDN, "Image file type and format guide", https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types, read 2026-11-17]
- WebGL needs raw bytes, so cross-origin images need CORS; without it Flutter falls back to HTML `<img>` elements.
  [source: Flutter team, "Display images on the web", https://docs.flutter.dev/platform-integration/web/web-images, read 2026-11-17]
- Deferred imports (`deferred as`, `loadLibrary()`) are web-only in the `dart` tool; deferred-library constants aren't
  constants and its types can't be used in the importer.
  [source: Dart team, "Libraries & imports", https://dart.dev/language/libraries, read 2026-11-17]
- Flutter supports deferred loading on Android and web; "The web creates deferred components as separate `*.js` files."
  For Wasm, `--enable-wasm-deferred-loading` splits into `.wasm` chunks; it is incompatible with `--web-content-hash`,
  and `--web-content-hash` does not yet support deferred imports in either JS or Wasm builds.
  [source: Flutter team, "Deferred components", https://docs.flutter.dev/perf/deferred-components, read 2026-11-17]
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
- Tree shaking: profile and release builds tree-shake; release also minifies. Icon-font tree shaking is on by default in
  release (`--no-tree-shake-icons` only to debug dynamic code points); local help: "Tree shake icon fonts so that only
  glyphs used by the application remain. (defaults to on)". General text-font subsetting [UNSOURCED: plan/provenance-audit.md#pp-font-subset].
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
  [source: local tool output, `flutter build web -h` (Flutter 3.47.7), run 2026-11-17]
- `--source-maps` emits separate `.js.map`/`.wasm.map` with no binary overhead; deployed publicly they expose symbols and
  paths, so keep them off public hosting.
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
- `--pwa-strategy` is absent from `flutter build web -h` on 3.47.7 (0 matches for "pwa"), and the 3.50 deployment page
  doesn't mention it. `--web-content-hash` (Flutter 3.50+) also absent locally. Caching per docs: hashed files
  `public, max-age=31536000, immutable`; `index.html`, `flutter_bootstrap.js`, `flutter.js`, `canvaskit/**` etc. `no-cache`;
  pre-compress `.wasm/.mjs/.js`/fonts with Brotli and gzip.
  [source: local tool output, `flutter build web -h` (Flutter 3.47.7), run 2026-11-17]
  [source: Flutter team, "Build and release a web app", https://docs.flutter.dev/deployment/web, read 2026-11-17]
- `canvasKitVariant`: `auto` (default), `full`, or `chromium` (smaller, Chromium-only); Safari gets the full build.
  [source: Flutter team, "Web app initialization", https://docs.flutter.dev/platform-integration/web/initialization, read 2026-11-17]
- `--wasm` output size vs JS (no read page gives numbers). [UNSOURCED: plan/provenance-audit.md#pp-wasm-size] Measure `main.dart.wasm`, the engine `.wasm` and
  `assets/**` in the Network panel per the web-performance page.

## Blocked or unread

All returned `ECONNRESET` through the forge proxy (treated as blocked; not routed around):

- bugs.webkit.org (bugs 215745, 173434, 281429), webkit.org (blog), lists.webkit.org not tried
- developer.apple.com (Safari 14 and 16 release notes; thermal-state docs not reached)
- www.macrumors.com, motion.dev (rAF throttling articles)
- caniuse.com (webp, avif, battery-status, PressureObserver)
- web.dev ("Rendering performance")
- en.wikipedia.org ("Wagon-wheel effect"; "Temporal anti-aliasing" not tried)
- gafferongames.com ("Fix Your Timestep!")
- blurbusters.com
- developer.android.com (Frame Pacing library, ADPF)
- docs.unity3d.com (Adaptive Performance), dev.epicgames.com (Dynamic resolution)
- developer.chrome.com (DevTools Performance panel)
- docs.flame-engine.org (all pages; Flame guide content was NOT read via its GitHub source either)
- Snippet only: MacRumors 120 Hz flag guide; WebKit bug 215745; flutter/flutter #193941 title.
