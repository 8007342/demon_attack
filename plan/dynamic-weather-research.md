# Dynamic weather: readable 2D rain (research for `dynamic-weather`, W1)

Round 3b, 2026-11-16. Question: how do games draw rain in 2D so that it reads as weather but never hides the play?
Provenance per CLAUDE.md §8. Most game-industry pages were blocked by the forge's proxy on 2026-11-16 (fetch reset);
those are listed as snippet-only and do not source any claim below.

## Sources

| Id | Source |
|---|---|
| S1 | [source: supremey17, "Pixel-game rain, snow, lightning and clouds" (pull request #4, weather-app2.0), https://github.com/supremey17/weather-app2.0/pull/4, read 2026-11-16] |
| S2 | [source: Jaewoong Eum (skydoves), "compose-animations" README, example 21 "Rainy", https://github.com/skydoves/compose-animations, read 2026-11-16] |
| S3 | [source: Manabu-GT, "Aether" README (weather effects for Jetpack Compose), https://github.com/Manabu-GT/Aether, read 2026-11-16] |
| S4 | [source: W3C WAI, "Understanding Success Criterion 2.3.1: Three Flashes or Below Threshold", https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold.html, read 2026-11-16] |
| S5 | [source: W3C WAI, "Understanding Success Criterion 2.3.3: Animation from Interactions", https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions.html, read 2026-11-16] |
| S6 | [source: MDN, "prefers-reduced-motion", https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion, read 2026-11-16] |
| S7 | [source: Flutter, "Canvas.drawRawPoints" and "PointMode" API docs, https://api.flutter.dev/flutter/dart-ui/Canvas/drawRawPoints.html and https://api.flutter.dev/flutter/dart-ui/PointMode.html, read 2026-11-16] |
| S8 | Stormfront's own rain, `lib/game/bonus/levels/stormfront_painter.dart` (`StormPainter.paintSky`), read 2026-11-16 (in repo). |

Snippet-only (not used as support):
- [source: PC Gamer, "How developers make perfect rain in games", https://www.pcgamer.com/how-developers-make-perfect-rain-in-games, unread: snippet only]
- [source: 80.lv, "How rain works in video games", https://80.lv/articles/how-rain-works-in-video-games, unread: snippet only]
- [source: Natalya Tatarchuk (ATI), "Artist-Directable Real-Time Rain Rendering in City Environments", SIGGRAPH 2006 Advances in Real-Time Rendering, https://advances.realtimerendering.com/s2006/Tatarchuk-Rain.pdf, unread: snippet only]
- [source: Construct forum, "How do I make rain effect through the whole layout", https://www.construct.net/en/forum/construct-3/how-do-i-8/query-rain-effect-143680, unread: snippet only]
- [source: godotshaders.com, "Rain and Snow with Parallax Effect", https://godotshaders.com/?p=5326, unread: snippet only]

## Conclusions and where they went

1. **Two depth layers told apart by brightness, speed and length; the far layer never splashes.** A pixel rain uses a
   dim back layer and a bright front layer, drops snapped to a pixel grid and slanted by the wind, and the back layer
   never splashes [S1]. Per-drop speed alone can encode depth [S2]; Aether's presets go from light to storm by adding
   layers [S3]. → Design §2: far streaks (short, slow, faint) and near streaks (long, fast, brighter), pixel-snapped,
   one wind slant; splashes belong to neither streak layer and sit on the ground.
2. **Splashes as a small crown on impact.** S1 replaced round dots with a pixel "crown" sprite; S2 draws optional splash
   marks where drops meet the ground. → §3: a two-fleck crown and a widening ripple line, smaller toward the horizon.
3. **Readability.** None of the read sources measures rain against gameplay readability, so the rule here is the
   project's own: rain is background. It is drawn under the ground units, the fog, the creatures, the ship and the
   shots, and the dimming is under them too, which only raises their contrast against the backdrop. [UNSOURCED:
   plan/provenance-audit.md#W-01]: no read source; checked instead on the review sheets (§7).
4. **No flashes.** A general flash is a pair of opposing luminance changes of 10 % or more; three or fewer per second
   pass [S4]. Regular-level rain has no lightning and no whole-screen luminance change faster than its 3 s slew, so it
   cannot flash. → §5.
5. **Reduced motion.** Non-essential motion (parallax among it) should honour the system's reduced-motion setting
   [S5, S6]; Aether disables animated effects under "Remove animations" [S3]. → §5: half the drops, a third of the
   speed, shorter streaks, no splashes and no gusts.
6. **Batching.** `drawRawPoints(PointMode.lines, …)` draws every pair of points as a segment with one paint [S7], so a
   whole layer is one call. Stormfront draws its 44 streaks one `drawLine` each, as a pure function of index and
   clock [S8]; the field is reused, the calls are batched. → §4.
