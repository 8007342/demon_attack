# Design: dynamic weather

Research and sources: `plan/dynamic-weather-research.md` (ids S1–S8 below). Builds on bonus level #2 Stormfront
(`lib/game/bonus/levels/stormfront_painter.dart`, unchanged) and playtest-fixes-3 §4 (the band above the arena).

## 1. The plan (`lib/game/weather/rain_plan.dart`, pure Dart)
`RainPlan.forLevel(runSeed, route:, sector:, bonus:)` draws from `Random((runSeed ^ 'RAIN') + route·977 + sector·131)`,
every number every time so one level's odds never shift another's:

| Draw | Value |
|---|---|
| rains | p = 0.25, sectors 1–4. Sector 5 (the carrier) and bonus levels are dry; unseeded runs are dry |
| tier | drizzle 40 %, rain 40 %, downpour 20 % |
| peak | drizzle 0.18–0.32, rain 0.46–0.64, downpour 0.82–1.0 |
| wind (slant, ±) | drizzle 0.02–0.16, rain 0.06–0.26, downpour 0.14–0.38 |
| start | half from the level's start (wet when the Descent's cloud clears); half at 8–40 s, building over 6–12 s |
| stop | three in ten ease off 40–90 s after the start, over 7–12 s |
| gusts | ±10 % slow swell (two sines), off with reduced motion |

Measured over 2000 seeds × 3 routes × 4 sectors: 22–28 % of levels rain (test). The model never reads the plan:
`ArcadeModel` is untouched and calibration is unchanged.

## 2. Layers (`lib/game/weather/rain_layer.dart`)
Drawn by `DemonScene.paintArena` right after the backdrop and the bonus grade (`// --- dynamic-weather`), before the
ground units, the fog layers, the creatures, the ship and the shots, over the full height including the band above
the arena (`headroom`). In order:

| Pass | What | At a downpour (k = 1) |
|---|---|---|
| dim | one rect, rgb(8, 11, 20) | alpha 0.17 k |
| haze | horizon band gradient (±75 units), the sector's cloud colour | alpha 0.13 k |
| sheen | screen-blend gradient on the ground | alpha 0.06 k |
| far streaks | 4–8 units long, 230–340 units/s, wind × 0.8 | up to 200, alpha 0.13 + 0.11 k |
| splashes | crown (2 flecks) + ripple line, scaled 0.5–1.6 by depth | up to 64 live, two alpha batches |
| near streaks | 11–20 units long, 560–780 units/s, wind × 1.2 | up to 80, alpha 0.20 + 0.14 k |

Parallax by speed, length and brightness, as in S1 and S2; the far layer never splashes (S1). Colour is Stormfront's
rain (`0xFFB9C6E8`). Streaks are pixel-snapped and wrap over a 400-unit strip so a slant never empties a corner.
Counts scale linearly with the drawn intensity, as a prefix of a fixed index list, so a swell adds drops without
reshuffling the others.

## 3. Transitions
`RainLayer.amount` slews toward the plan's intensity at 1/3 per second (any change takes at least 3 s), and toward 0
in the title, the travel out, victory and the end screen. Plan ramps are smoothstep. Tier changes use ±0.04
hysteresis.

## 4. Drawing and budget
Stateless field: each streak is a pure function of its index and the clock (Stormfront's `paintSky`, S8), so nothing
is allocated per drop; points go into preallocated `Float32List`s. Each pass is one `drawRawPoints(PointMode.lines)`
(S7): at most 3 rects + 4 line batches per frame. The hash is a small-multiplier Wang mix that stays exact on the web
(no product above 2^53).

Measured (`test/dynamic_weather_test.dart`, flutter_tester, 2026-11-16): a downpour is 200 far + 80 near streaks and
≈ 27–30 live splashes (≤ 64); Dart recording ≈ 40 µs per frame; CPU raster of the layer at 1080 × 1920 ≈ 11 ms,
dominated by the three full-width blended rects (an upper bound; a GPU fills them in a fraction of that).

## 5. Accessibility
- Reduced motion (`sectors.flyover.reducedMotion`): half the drops, 0.35 × the speed, 0.6 × the length, 0.6 × the
  slant, no splashes, no gusts (S5, S6).
- No lightning, no thunder and no flash in regular levels: the only luminance change is the dim, which moves no faster
  than the 3 s slew, so there is no general flash under WCAG 2.3.1 (S4).
- Readability: all rain is under the play. The dim and haze darken and soften the backdrop only, which raises the
  contrast of creatures, the ship and shots (UNSOURCED, `plan/provenance-audit.md#W-01`; checked on the sheets).

## 6. Audio events
`GameEventNames.rainStart`, `rainStop`, `rainIntensity` (group `weather`), sent by the rain layer through
`dispatchGameEvent` like `TerrainRadio` (visual-only layers do not write the model's queue). Data: `tier`,
`intensity` (two places), `wind`, `sector`; `rainIntensity` adds `from`. One start per shower, one stop, and one
intensity event per tier crossing. Nothing in comms or music handles them yet; no audio assets.

## 7. Review
`test/dynamic_weather_review_test.dart` (tag `review`), phone portrait 360 × 780 bottom-aligned (the band shows):
- `art/contact/dynamic-weather-tiers.png`: sectors 1 and 3, dry / drizzle / rain / downpour, live fight.
- `art/contact/dynamic-weather-reduced.png`: the downpour with reduced motion, both sectors.
- `art/contact/dynamic-weather-fade.png`: sector 2, rain starting at 2 s and building over 8 s (0.00 → 0.57).

Picks (made 2026-11-16, logged here and in the sheets' captions; the operator overrides):
1. Downpour budget raised from 150/60/48 to 200/80/64: at 150 the downpour read as steady rain at phone size.
2. Streak alpha raised (far 0.07 + 0.09 k → 0.13 + 0.11 k, near 0.11 + 0.11 k → 0.20 + 0.14 k): the first drizzle
   was invisible at phone size. At the new values cyan and red shots and every creature stay clear on both sectors.
3. Rain stays wholly under the play (no foreground streaks over the ship): readability over drama.
4. The carrier sector stays dry: the boss fight's presentation belongs to boss-grandeur and carrier-v3.
