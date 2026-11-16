# Proposal: dynamic weather (W1)

## Why
From the operator's round 3b (`plan/operator-feedback-2026-11-16.md`, W1): regular levels should sometimes rain, from a
drizzle to heavy rain. The operator loved Stormfront's storm ("SUPER AWESOME!!"); its lightning and thunder stay
exclusive to that bonus level.

## What Changes
- **Rain plan** (pure Dart, `lib/game/weather/rain_plan.dart`): each regular level of a seeded run rains with
  probability 0.25 (sectors 1–4; the carrier sector and bonus levels stay dry), as a drizzle, rain or downpour with
  its own wind slant; half the rainy levels start dry and build in mid-level, and three in ten ease off before the end.
  Unseeded runs (tests, the calibrated campaign) are always dry.
- **Rain layer** (`lib/game/weather/rain_layer.dart`): far and near streak layers, ground splashes, a little dimming,
  a thicker horizon haze and a faint wet sheen, drawn over the backdrop (and the band above the arena) and under
  everything that plays. Every change is a soft 3 s slew. Batched: one `drawRawPoints` per pass.
- **Audio events**: `rainStart`, `rainStop`, `rainIntensity` (tier, intensity, wind, sector) through
  `dispatchGameEvent`, for the future music and SFX engine. No audio assets.
- **Accessibility**: reduced motion halves the drops, slows them to a third, shortens them and drops the splashes and
  gusts. No lightning, so nothing flashes.

## Impact
- Code: new `lib/game/weather/`; hooks in `lib/game/scene.dart` (`// --- dynamic-weather`) and three names in
  `lib/game/game_events.dart`. Stormfront is untouched.
- Specs: `arcade-presentation` (rain).
- Gameplay: none. Visual only; calibration unchanged.
- Research: `plan/dynamic-weather-research.md`. Review sheets: `art/contact/dynamic-weather-*.png`.
