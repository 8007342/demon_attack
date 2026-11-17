# Proposal: build version stamp

## Why
The operator, 2026-11-17 (operator feedback round 6, relayed by the lead session): "Please file a spec to have a
"vYY.MM.DD.<daily-build-number>", today would be v56.11.17.1, that way I could tell when the newer versions are
live." Today nothing in the game, the dev pages or the Worker says which deploy is being served, so after a merge to
`main` the operator cannot tell whether Cloudflare has finished deploying it.

## What Changes
- A build-time version `vYY.MM.DD.N` derived from git alone (`scripts/build-version.mjs`): `YY` is years since 1970
  (the Tillandsias scheme, 2026 → 56), the date is the deploy commit's committer-local day, and `N` counts the
  first-parent commits on `main` that day (each one is a Workers Builds production build). Builds that are not on
  `main` read `vYY.MM.DD-dev+<sha>`; a production build whose number cannot be established reads `vYY.MM.DD.0+<sha>`.
- `scripts/build-web.sh` passes it to both Flutter builds as `--dart-define=BUILD_VERSION` and writes
  `build/web/version.json`.
- The game shows it in small text on the title screen and in the pause menu; `/console`, `/gallery` and `/studio`
  show it in a footer (`lib/widgets/build_version_label.dart`).
- The Worker answers `GET /version` with the build record as uncached JSON and an `x-build-version` header.

## Capabilities
### Modified Capabilities
- `deployment`: adds the build version stamp, its daily number, where it is shown, and the `/version` endpoint.

## Impact
- New: `scripts/build-version.mjs`, `lib/build_info.dart`, `lib/widgets/build_version_label.dart`,
  `worker/version.mjs`, tests `test-worker/build-version.test.mjs`, `test/build_version_test.dart`, shared cases
  `test/fixtures/build_version_cases.json`.
- One-line hooks in `lib/main.dart`, `lib/gallery_main.dart`, `lib/widgets/dev_console.dart`, `worker/index.mjs`;
  `wrangler.jsonc` routes `/version` to the Worker first.
- No generated file is committed: the version exists only in build output.
