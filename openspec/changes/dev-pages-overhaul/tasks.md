# Tasks

## 1. Spec (`work/dev-pages-overhaul`)
- [x] 1.1 Proposal, design (routing, audit table, root fix, navigation, removals, guards), delta spec `dev-pages`
- [x] 1.2 `openspec validate dev-pages-overhaul --strict`

## 2. Root fix
- [x] 2.1 `lib/review/gallery_scenes.dart`: `GalleryScene` staged (presentation pipeline, no simulation step) and live (console-style run, kept alive, looping)
- [x] 2.2 Existing pages moved onto started models; carrier pages on the console's carrier launcher
- [x] 2.3 New pages: insignia, dive shields, carrier tours, ground war, weather, bonus, perf tiers, medals

## 3. Catalogue and navigation
- [x] 3.1 `ScenePage` registry (area, sources, assets) in `review_catalog.dart`; studio scene list grouped by area
- [x] 3.2 Studio atlas list: frontal boss sheets and fallback ground units out; insignia, hatch-emergence, sentinel silhouettes, ground wildlife in
- [x] 3.3 `lib/review/dev_nav.dart`: `DevNavBar` and `DevFooter` with the one build-version slot; console, gallery and studio use them
- [x] 3.4 Gallery index grouped by area; scene header with title, area and sources

## 4. Removals
- [x] 4.1 `assets/images/ship-parts.png` and `.json` removed; `rigsheet mock` crops `ship-weapons.png`; README and `model.dart` comment updated

## 5. Tests and gates
- [x] 5.1 `test/dev_pages_test.dart` (scene list smoke, staleness guard, navigation); `test/console_route_test.dart` new keys
- [x] 5.2 Gates: `flutter analyze`, `flutter test`, `npm run test:worker`, `npm run build`
- [ ] 5.3 Operator: look at `/gallery/`, `/studio` and `/console` on the preview after the squash (no browser reaches this worktree)

## 6. Follow-ups (design, Open questions)
- [ ] 6.1 Decide on removing the frontal boss sheets and their fallback path (own change)
- [ ] 6.2 Decide on retiring the ground units' old-atlas fallback (own change)
