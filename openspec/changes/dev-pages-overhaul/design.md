# Design: Dev pages overhaul (dev-pages-overhaul)

## 1. How the pages are built and routed

| Page | Address | Built from | Routed by |
|---|---|---|---|
| Console | `/console` | `lib/widgets/dev_console.dart` in the game app (`lib/main.dart`, `isConsoleRoute`) | Worker serves `index.html` for any path; the app's `onGenerateRoute` opens the console |
| Gallery | `/gallery/`, `/gallery/?page=<id>[&tile=n]` | `lib/gallery_main.dart`, a second web build (`scripts/build-web.sh`, `--base-href /gallery/`) | static files under `build/web/gallery/` |
| Studio | `/studio` (also `/gallery/?page=studio`) | the gallery app opening `ReviewStudio` (`lib/review/`) | `worker/index.mjs` `isStudioPath` serves `/gallery/` at `/studio`; the app reads the path |

The studio's catalogue (`lib/review/review_catalog.dart`) reads the generated atlas contracts, the comms bank and the
score manifest, so its radio, music, background and most sprite items were already live. The gallery's staged
scenes were not, and the studio's "scenes" tab shows exactly those (`sceneBuilder`). Related: `add-asset-review-studio`
(the studio and notes), `asset-review-progression` (the separate `tools/asset_pipeline/review.html`; untouched).

## 2. Audit (before → after)

Checked against `origin/game` b29c9749 on 2026-11-17 by reading the scene code paths (`lib/game/scene.dart`
`_carrierFront`, `BossPainter.sync`, `GroundPainter`, `GroundBlocksLayer.unitTrack`).

| Scene / tab | What it showed | What the game uses now | Stale? | Fix |
|---|---|---|---|---|
| Gallery `carrier` | A hand-built `Carrier(cycle)` stepped by `creatures.update` only. `BossPainter.sync` was never called, so `armada.ready`/`heroReady` stayed false and `_carrierFront` drew the `CombatAtlas.fallbackRow` sprite from `combat.png` with the v1 eyes, side hatches and rectangle jaws; the wrecks likewise | carrier-v3 hero hull (`boss-carrierN-*-hero-0.png`, bent, data page), carrier-hatches (tusk-framed core door, upper hatches), hatch-emergence (lurkers, climb-outs, tusk-prong motif), boss-grandeur director | **Yes, several versions** | Live: the console's carrier launcher (`ConsoleStart.boss`) for run 1 fight, fast decay (shield → armour → modules → collapse → wreck) and approach (loom); new `carrier-tours` page for runs 2–5 |
| Gallery `creatures`, `elites`, `actions` | Creatures from `combat.png` on a bare `ArcadeModel()` with no presentation step (backdrop and fog frozen at their initial state) | Same creature atlas, with the sector backdrop, fog and swarm look | Partly (backdrop) | Staged on `startAt(sector 2, run 2)` with the presentation pipeline each frame |
| Gallery `weapons` | Live run from `ArcadeModel()..start()` | `ship-weapons.png` + `.json` | No | Console-style run that loops (`restart`) |
| Gallery `sentinels` | Staged sentinels, no presentation | `sentinel-effects.png`; silhouettes in the fog | Partly | Presentation pipeline (the fog silhouettes now draw) |
| Gallery: dive shields | (none) | dive-shield-thinning: one arc that thins to a 40 % floor | Missing | New `dive-shields` page: medium, elite, sentinel dive and rush shields at full, middle and last point |
| Gallery: insignia | (none) | gargoyle-insignia twin-fang glyphs (`insignia.png`) | Missing | New `insignia` page: the review sheet's dense formation |
| Gallery: ground war | (none) | ground-war-v4 on ground blocks (`assets/images/ground-blocks/`), gargoyle-ground-army | Missing | New `ground-war` page: live sectors 1–4 |
| Gallery: weather | (none) | dynamic-weather rain tiers | Missing | New `weather` page: drizzle, rain, downpour via `RainLayer.override` |
| Gallery: bonus levels | (none) | `bonusLevels` (Supply Run, Stormfront) | Missing | New `bonus` page, one live tile per bonus level |
| Gallery: perf tiers | (none; only `?perf=` on the game) | phone-performance `PerfTier` full/lean/lite | Missing | New `perf-tiers` page: sector 4, run 5, downpour, one tile per forced tier |
| Gallery: mission medals | (none) | `MissionMedal` from `mission-medals.png` | Missing | New `medals` page: every mission id plus the generic fallback |
| Studio backgrounds | `BackgroundScene`, the live `SectorBackground` | same | No | — |
| Studio sprites: creatures, combat effects, sentinel effects, ship, flyover creatures and vegetation, portraits | Generated atlas contracts | same | No | — |
| Studio sprites: `boss-*` frontal hulls (forms, damage, plumes of `boss-frigate.png` … `boss-dreadnought.png`) | The five frontal sheets | Every tour 0–4 and every seeded tour draws a packed hero hull (`BossPainter.heroForRun` is never null), so no run shows a frontal sheet | **Yes** | Removed from the list; the carrier is reviewed live (§3) |
| Studio sprites: `ground-*` vehicle and ally rows of `ground-forces.png`; all of `ground-troops.png` | Old unit atlases | Units, allies and troops are drawn from the ground blocks (`unitTrack`/`allyTrack`); the old rows are only drawn until a sector's blocks load | **Yes** | Removed from the list; effects rows of `ground-forces.png` kept (still drawn) |
| Studio sprites: insignia, hatch-emergence, sentinel silhouettes, ground wildlife | (none) | Drawn by the game | Missing | Added from their generated atlases |
| Studio scenes | The gallery's six pages, flat | — | (see gallery rows) | Registry, grouped by area, labelled with sources |
| Studio radio | `comms_bank.dart` + `web/audio/comms/manifest.json` | same | No | — |
| Studio music | `web/audio/score/score.json` sections (MIDI-first score) | same | No | — |
| Console launcher, carrier launcher, sentinel jump, bonus picker | `ConsoleStart` → `ArcadeModel.startAt` (the real game) | same | No | — |
| Console score panel | `ScoreListeningPanel` (adaptive-soundtrack) | same | No | — |
| Console links | ART GALLERY and ASSET REVIEW buttons | — | — | `DevNavBar` (§4) |
| Comms portraits | Studio sprites `portraits/*` from `comms-portraits.png` | same (`commsPortraitRows`) | No | — |

## 3. Root fix: one scene class, the game's pipeline

`lib/review/gallery_scenes.dart` holds `GalleryScene` (a `DemonScene`) and every page's tiles.

- **Staged** tiles (`live: false`) start the model with `ArcadeModel.startAt` (sector 2, run 2, as the review sheets
  do), clear its wave, place creatures by hand, and each frame run `DemonScene.update` minus the simulation step:
  `perf.frame`, `applyBudget`, `advancePresentation` (backdrop, carrier director, fog, rain), `armada.sync`,
  `groundForces.blocks.sync`, `creatures.update`. Nothing is drawn from a frozen copy.
- **Live** tiles (`live: true`) run `DemonScene.update` itself on a console-style run (`ConsoleStart.applyTo` or
  `startAt(console: true)`), with the ship kept alive (`keepAlive`), and restart their run after 75 s, a game over or
  the ending, so a tile loops.
- The scene registry `scenePages` (`review_catalog.dart`, pure Dart) gives each page an id, title, `GameArea`,
  `sources` (changes or specs) and `assets`; the gallery index, the gallery header and the studio's scene list all read
  it. The original ids (`creatures`, `elites`, `actions`, `weapons`, `sentinels`, `carrier`) are kept so existing
  notes still find their scene.
- `GalleryPage` builds its tiles once (a stateful widget), so a studio rebuild (typing a note) no longer restarts the
  runs.

## 4. Navigation and the version slot

`lib/review/dev_nav.dart`: `DevNavBar` (CONSOLE, GALLERY, STUDIO; the current one highlighted and inert; keys
`dev-nav-<page>`) and `DevFooter`, which ends in the single placeholder `KeyedSubtree(key: dev-footer-version)` marked
`// --- build-version`. The console (under its launchers), the gallery (header and footer) and the studio (above its
tabs, footer as `bottomNavigationBar`) use them. This change draws no version itself.

## 5. Removed and kept

Removed (the game never loads them; checked with `git grep` on 2026-11-17):

| File | Size | Why it can go |
|---|---|---|
| `assets/images/ship-parts.png` | 8 KB | Provisional ship pack (local-image-ship-asset-pipeline 6.3); the game draws `ship-weapons.png`. Its last reader, `rigsheet mock`, now crops `ship-weapons.png`'s hull cell |
| `assets/images/ship-parts.json` | 4 KB | Its metadata; the scene reads `wing_muzzles` from `ship-weapons.json` (comment in `model.dart` corrected) |

Kept, although no longer listed by the studio, because game code still references them (CLAUDE.md §5 forbids deleting
a referenced asset; removing them means editing the shared painters, so it is a follow-up, see Open questions):

| File | Size | Reference |
|---|---|---|
| `boss-frigate.png`, `boss-cruiser.png`, `boss-battlecruiser.png`, `boss-battleship.png`, `boss-dreadnought.png` | 2.2 MB | `BossAtlas.classes` (generated frontal section) and the `BossPainter.sync` fallback for an unpacked tour; unreachable today (test: every tour has a hero hull) |
| `ground-troops.png`, the unit rows of `ground-forces.png` | 8 KB + part of 36 KB | `GroundPainter` fallback until a sector's blocks load; `GroundPainter.useBlocks` switch |
| `combat.png` fallback row | (inside the creature atlas) | `CombatAtlas.fallbackRow`, drawn while a hull loads |

## 6. Guards

`test/dev_pages_test.dart`:
- every scene page builds its tiles; staged models are started (sector 1–4, playing); live tiles are live;
- the carrier tiles run the console fight on a packed hero hull and keep the ship alive for 3 s of simulation;
- weather, bonus and perf tiles carry their forced state; medal ids are atlas ribbons;
- every `sources` entry names a change, an archived change or a spec;
- every scene asset and every studio atlas image exists and is named by the game's code (`lib/` outside
  `lib/review/` and `gallery_main.dart`), none is a fallback sheet, and any `boss-*` sheet is a reachable hero asset;
- every tour (routes 0–7 × 16 variants) draws a packed hero hull; `ship-parts.*` stays removed;
- the gallery index, a scene page header and the studio's grouped list render with the navigation and the version slot.

## 7. Verification

Tests and the web build only: the forge has no browser, and the host browser tools reach the operator's preview, not a
server in this worktree (see the tasks' note). The visual check is left to the operator on the preview after the squash.

## Open questions

1. Remove the frontal boss sheets (2.2 MB) and their fallback path? It touches `boss_painter.dart`, `scene.dart` and the
   generated `boss_atlas.dart` (whose frontal section needs Pillow), and `BossAtlas.classes` still carries the class
   metadata the grammar uses. Proposed as its own change.
2. Retire the ground units' old-atlas fallback (`useBlocks`, `ground-troops.png`, unit rows of `ground-forces.png`)?
   Same reasoning: a shared-painter edit, its own change.
3. The live tiles are heavy (a carrier tile keeps its hero pages, about 14 MB each, resident). `carrier` shows three
   tiles of one hull, `carrier-tours` four hulls; `&tile=<n>` shows one. Enough, or one tile per page by default?
