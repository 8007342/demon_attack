# Proposal: crosswind (wind weather and the Crosswind bonus level)

## Why
The operator, 2026-11-17, verbatim: "let's add another alternative to rain, to show sometimes just like thunder,
we'll also add significant wind effects, enough to deviate bullets, ours and enemies, with swinging directions,
sometimes even speeding up bullets a tiny little bit, we'll use clouds as effect. Your job is to design and introduce
this effect, and come up with one bonus level that uses this wind gimmick for its goal, like no multifire so players
would need to aim through the windy conditions. ... Pretty assets and radio chatter ... Also good to figure out how
flexible and extensible our pipelines are early on."

A later direction from the operator (relayed by the coordinator), verbatim: "the demons should fight the strong wind a
little, but not as much, it's their planet and they know how to deal with it."

## What Changes
- **Wind weather** (pure Dart, `lib/game/weather/wind_field.dart`, `lib/game/model_wind.dart`): about one eligible
  regular level in five of a seeded run is windy (a breeze or a gale; never the run's first sector, the carrier or an
  unseeded run). A seeded field swings the wind's direction every few seconds, with gusts. Unlike rain it is
  gameplay: every projectile, the player's and the demons', drifts sideways toward the wind's speed; a strong
  tailwind at the muzzle adds one 15 u/s grid step. Demons are pushed a little and lean into it; higher ranks are
  steadier.
- **Telegraph**: every change is planned 1.5 s ahead. The clouds, wisps and a windsock draw the forecast, and a big
  swing or a gust is called on the radio (`windGust`) and by the music's `gust` stinger before it pushes.
- **Look** (`lib/game/weather/wind_layer.dart`): cloud billows and wisps streaming with the wind under the play, and
  a windsock in the arena's top-left corner. Capped per perf tier (`FrameBudget.windScale`).
- **Bonus level #3, Crosswind** (`lib/game/bonus/levels/crosswind.dart`): the brood flies kites in a gale; pop them
  with single shots (no Spread, no Rapid) aimed through the wind. Kites are new studio sprites
  (`assets/images/wind-kites.png`, `tools/wind_kites`). Its music asks for `bonus-wind` and fails soft until
  bonus-music adds it. Its 1UP challenge ("every kite down") joins bonus-challenges' framework once that lands.
- **Radio**: a one-sentence briefing call, wind squad lines, brood taunts and a challenge line (text-only, voices
  blocked on tillandsias#1103).
- **Tools**: `tools/ordinary_wave_probe.dart` gains `wind=on` and `skill=`; the Average pilot can lead for wind.

## Impact
- Code: new `lib/game/weather/wind_*.dart`, `lib/game/model_wind.dart`, `lib/game/bonus/levels/crosswind*.dart`,
  `tools/wind_kites/`; small hooks (`// --- crosswind`) in `model.dart`, `scene.dart`, `shot_layer.dart`,
  `song_director.dart`, `music_director.dart`, `game_events.dart`, `bonus_types.dart`, `bonus_catalog.dart`,
  `bonus_painters.dart`, `frame_budget.dart`, `gallery_scenes.dart`, `comms_briefing_view.dart`.
- Specs: `arcade-combat` (wind), `arcade-presentation` (its look), new `bonus-level-crosswind`.
- Calibration: unseeded runs (every calibration gate) are calm, so the gates are unchanged; the wind's own effect is
  measured with the Average pilot and recorded in `plan/calibration-current.md`.
- Bonus plan: a third level in the catalogue changes which level an old run seed's bonus slot selects (as Stormfront
  did); the slots themselves are unchanged.
