# Proposal

## Why

Operator, round 6 (2026-11-17), verbatim: "The /console, /studio, and /gallery could use some overhauling ;) some of
them like the boss fight scene still shows assets from several versions of the game ago."

The gallery's carrier page built a `Carrier` by hand and stepped only the creatures, so the scene never ran the
presentation pipeline: `BossPainter.sync` never loaded a hull, and the carrier fell back to the oldest art in the game
(the `combat.png` fallback row), several versions before carrier-v3, carrier-hatches and hatch-emergence. The studio's
sprite list still played the five frontal boss sheets (`boss-frigate.png` … `boss-dreadnought.png`) that no tour
draws any more, and the ground units of the old atlases that the ground blocks replaced. Half of what ships today
(dive shields, the twin-fang insignia, the ground war, weather, bonus levels, mission medals, the perf tiers) had no
scene at all, and the three pages had no shared navigation.

## What Changes

- **Root fix.** Every gallery scene draws with the game's own `DemonScene` and runs its presentation pipeline every
  frame (backdrop, fog, the carrier director and hero hull, ground blocks, weather, perf tier) on a model started the
  way the game starts one (`ArcadeModel.startAt`, the console's `ConsoleStart`). A staged scene freezes only the
  simulation step; a live scene runs a console-style run with the ship kept alive and loops.
- **Scenes.** The carrier pages run the console's carrier launcher (fight, fast decay, approach; tours 2–5). New scene
  pages: insignia, dive shields, ground war, weather, bonus levels, perf tiers, mission medals.
- **Catalogue.** A scene registry (`ScenePage`: id, title, game area, source changes/specs, assets) drives the gallery
  index and the studio's scene list. The studio's atlas list drops the frontal boss sheets and the ground units that
  are only a loading fallback, and adds the insignia, hatch-emergence, sentinel-silhouette and ground-wildlife sheets.
- **Navigation.** One `DevNavBar` (console, gallery, studio) and one `DevFooter` with a single slot for the build
  version, which the parallel `build-version` change fills.
- **Removed.** `assets/images/ship-parts.png` and `ship-parts.json`, a provisional pack the game never loads
  (design §5).
- **Guards.** `test/dev_pages_test.dart`: every scene page builds; every scene asset and studio atlas is one the game
  names, never a fallback sheet; every tour draws a packed hero hull; every scene's sources exist.

## Capabilities

### New Capabilities
- `dev-pages`: the console, gallery and studio as one set of review pages that draw the game's current art.

### Modified Capabilities
None. The asset review studio's requirements (`add-asset-review-studio`, `asset-review-notes`) are unchanged; their
scenes now come from the registry.

## Impact

- New: `lib/review/gallery_scenes.dart`, `lib/review/dev_nav.dart`, `test/dev_pages_test.dart`.
- Changed: `lib/gallery_main.dart` (index, header, footer), `lib/review/review_catalog.dart` (atlas list, scene
  registry), `lib/review/review_studio.dart` (navigation, grouped scenes, footer), `lib/widgets/dev_console.dart`
  (navigation, footer), `test/console_route_test.dart` (the new navigation keys).
- `tools/rigsheet` `mock` draws the ship from `ship-weapons.png`; `lib/game/model.dart` one comment;
  `tools/asset_pipeline/README.md` one line.
- No gameplay, balance or calibration change; the Worker routes (`/console`, `/studio`, `/gallery/`) are unchanged.
