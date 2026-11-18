# Proposal: weather everywhere

## Why
The operator, 2026-11-17, verbatim: "Lightning and wind are regular weather effects that happen sometimes normaly
throughout the game, they're just rarer than regular rain. Radio chatter shall notice them. The windy sectors will
already be harder for players dealing with wind ;) no need to rebalance. Just make sure that the demons fighting the
wind use strategically their sprites flapping their wings sideways. The smarter enemies shall also use the wind to
dive."

Today rain comes to one regular level in four (dynamic-weather) and wind to one in five (crosswind), but lightning
lives only in the Stormfront bonus level: dynamic-weather kept it out of regular sectors for flashing reasons
(its design §5, research S4). lightning-rework made bolts safe for the player (a stun for the brood, a zap that
strips the ship and never costs a life) and left regular storms to the operator (its open question 1).

## What Changes
- **Lightning storms in regular sectors.** A level that rains at the `rain` or `downpour` tier may storm
  (`StormPlan`, its own salt): 0.25 × (0.4 × 0.9 + 0.2 × 1.0) = 0.14 of eligible levels. Rain 25 % > wind 20 % ≈
  lightning 14 %. Bolts fall only while the rain is heavy, on lightning-rework's rule (stun, zap, rank dodges), on
  Stormfront's `StormCell` with a slower tuning (a bolt every 6.5–10 s, never forked, 1.25 s tells). Unseeded runs,
  the first sector, the carrier's sector and bonus levels never storm.
- **Flash safety for every storm** (WCAG 2.3.1, research S4 of dynamic-weather): one flash per bolt, bolts seconds
  apart; every large-area change (wash, cloud glow) under a 10 % relative-luminance step on any backdrop; the tell's
  marker and the ship's zap flicker at most 3 Hz (were 5.7 Hz and 10 Hz). A new **reduced-flashing** setting (the
  system's reduced motion, or `?flash=low`) drops the wash and the glow and steadies the tells and the ship.
- **Radio notices the weather**: written lines (text-only, voices blocked on tillandsias#1103) for a gale rising, the
  wind turning, a storm starting and passing, rain starting, and a demon riding a gust; squad and brood; one
  `weather` rate-limit family (10 s between squad lines) on top of each trigger's cooldown.
- **Wing flapping in the wind**: real frames. A new wind-flap atlas (`assets/images/wind-flap.png`, 4 species × 5
  damage variants × 2 wind sides × 8 frames, plus elite overlays and head anchors), rendered on the CPU from the
  same gargoyle rig as `combat.png` (`tools/generate_wind_flap.py`, recipe and pick in `art/families/wind-flap.json`).
  The upwind wing beats deeper and higher, the downwind wing shallow and swept back, the body leans into the wind.
  A creature holding its place in a wind of ≥ 0.3 uses them.
- **Smart demons ride the wind to dive**: veterans, hunters and sentinels (skirmishers from the third tour) hold a
  picked dive up to 2.4 s until the wind will blow toward the ship when it starts (facing only a headwind they let the pick go), then ride it: a stronger share
  of the wind carries them in a curve onto an aim set upwind of the ship. Drones dive when picked and fight the
  wind. Deterministic; no new random draws.
- No rebalance (the operator); every calibration gate runs unseeded and calm, so it is unchanged.

## Impact
- Code: `lib/game/weather/storm_plan.dart`, `storm_layer.dart`, `wind_flap.dart`, `lib/game/model_weather.dart`
  (part of the model), `lib/game/wind_flap_atlas.dart` (generated); small hooks (`// --- weather-everywhere`) in
  `model.dart`, `model_wind.dart`, `scene.dart`, `sprite_atlas.dart`, `game_events.dart`, `rain_layer.dart`,
  `stormfront_painter.dart`, `bonus_painters.dart`, `lightning_painter.dart`; gallery weather page.
- Assets: `assets/images/wind-flap.png` (178 KB); contact sheets `art/contact/wind-flap-*.png`.
- Radio: six triggers appended to `art/comms/lines.json`; `comms_bank.dart` regenerated.
- Specs: `arcade-combat`, `arcade-presentation`, `squad-comms`.
