# Tasks

Prerequisite: `ground-forces-rework` task 2.6 (offline atlases and generated metadata).

## 1. Loading and cast
- [x] 1.1 `assets/images/ground-blocks/` in `pubspec.yaml`; `GroundBlocksLayer.sync` loads the current sector's
      three atlases and evicts the previous sector's
      (called from `DemonScene.update` next to the boss atlas sync; `install` takes decoded atlases for tests)
- [x] 1.2 Cast table per sector (threat, skirmish, heavy tank, squads, rockets, convoy, allied squads); no cast or
      wrong sector falls back to the old atlases (`lib/game/ground_blocks_cast.dart`)
- [x] 1.3 Cell selection by name through the layout: states found at whichever heading holds them, base cells fall
      back to `move` (infantry `walk`) f0, missing overlays draw nothing; frame counts from the layout

## 2. Headings and layers
- [x] 2.1 `GroundHeading`: ring of mirrored directions, smoothed velocity, rate limit, hysteresis, minimum hold,
      one step at a time, facing hint, arc clamp, seeding (`lib/game/ground_heading.dart`)
- [x] 2.2 Hull heading from travel (screen texels and depth per second); convoy reverse; skid dust on a step
      (not with reduced motion)
- [x] 2.3 Articulated layer on its own tracker toward the foe, seated on `pivot[h]`, recoil, walker bob; muzzle as
      the friendly tracer origin

## 3. States and overlays
- [x] 3.1 Threat telegraph on special f0–f3 with the old timing; fills by telegraph progress and by skirmish wind-up
- [x] 3.2 Move, idle, fire, hit flash, damage overlays, Fleet dents, lights pulse
- [x] 3.3 Host wreck then rubble with authored debris pieces; Chapterhouse fall; Fleet totalled, limp and pod
- [x] 3.4 Pitch on slopes from the relief pose; hooks for ford, crest hop and arrival
      (`fording`, `airborne`, `arrivalAge` return false/null: the simulation has no water, crest or unearthing
      events yet)
- [x] 3.5 Infantry: walk, idle, aim A/B, fire, hit, fall, rubble, run, flourish for saved squads
- [x] 3.6 Level of detail (900 / 1200)

## 4. Switch and verification
- [x] 4.1 `GroundPainter.useBlocks` (default true), the old path unchanged behind it
- [x] 4.2 Contract tests: every requestable cell exists for every cast unit in every sector; tracker determinism,
      step limits, hold, 90° timing, no flicker; turret seating for every heading and angle pair; painter
      requests during a simulated run resolve; gameplay identical with the switch on and off
      (`test/ground_blocks_runtime_test.dart`, 14 tests; review frames in `.cache/ground-blocks-review/`, including
      a 2x ground-only frame per sector and the same frame with the switch off)
- [x] 4.3 `flutter analyze`, `flutter test`, `flutter build web`; review frames
- [x] 4.4 Note progress on `ground-forces-rework` tasks 7.1 and 7.2

## 5. Deferred (not in this change)
- [ ] 5.1 Walker heading steps landing on a stride plant
- [ ] 5.2 Specials other than the threat telegraph (Cairn deploy, Tether tow, Reliquary unload, Hodcrawler mend,
      Carillon ripple, Sextant brace), banner overlays and the Chapterhouse command pulse
- [ ] 5.3 Ford, crest hop and unearthing once the simulation or the arrival work exposes them
- [ ] 5.4 Operator review of the in-game frames (part of `ground-forces-rework` CP8)
