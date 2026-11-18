# Tasks

## 1. Spec
- [x] 1.1 Proposal, design, delta spec (`deployment`); `openspec validate build-version --strict`

## 2. Version (`scripts/build-version.mjs`)
- [x] 2.1 Format `vYY.MM.DD.N`, `.0+sha`, `-dev+sha`; YY = year − 1970
- [x] 2.2 Daily number from `main`'s first-parent history, committer-local day; `WORKERS_CI_BRANCH` decides production
- [x] 2.3 Shallow clones: deepen from `origin`, else `.0+sha`
- [x] 2.4 `scripts/build-web.sh`: `--dart-define=BUILD_VERSION` for both builds; `build/web/version.json`

## 3. Display
- [x] 3.1 `lib/build_info.dart` (pure Dart) and `lib/widgets/build_version_label.dart`
- [x] 3.2 Title screen corner and pause menu (`lib/main.dart`)
- [x] 3.3 `/console` footer, `/gallery` and `/studio` (`MaterialApp.builder`)

## 4. Worker
- [x] 4.1 `GET /version` (`worker/version.mjs`), Worker-first route in `wrangler.jsonc`

## 5. Tests and gates
- [x] 5.1 `test-worker/build-version.test.mjs`: format cases, day rule, fixture repo, shallow clone, `/version`
- [x] 5.2 `test/build_version_test.dart`: shared cases, 2026-11-17 → 56, label placement
- [x] 5.3 CLAUDE.md §2 gates
- [ ] 5.4 After the next release: `curl https://demonattack.tlatoani.net/version` reports the merge's version
- [ ] 5.5 Operator: settle design §6 (day boundary, skipped builds)
