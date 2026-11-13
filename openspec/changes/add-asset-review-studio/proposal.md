# Proposal

## Why

The operator reviews assets by playing the game and remembering what sounded or looked wrong. Some demon clips "still don't growl", some sound like uncompressed audio, some human radio lines are emotionally flat, and loops or animations have timing problems. There is no single place to play one asset on its own, and no record an agent can read back to decide what to regenerate or refine.

## What Changes

- Add an asset review studio to the gallery (`/gallery/?page=studio`), linked from `/console` as **ASSET REVIEW**. It shows the sector flyovers playing live per sector and run, every atlas animation frame by frame with a speed control, the gallery's staged scenes, the radio bank (filter by speaker, human or demon, emotion and event; portrait lip-sync and subtitle while a clip plays) and the music cues and stems (play, loop the seam, a bar range or a stem slot).
- Every item gets a notes panel: quick tags, a free-text note and the playhead time when the note was started. A note records the asset reference, kind, source file, content hash and build commit.
- Notes are kept in the browser, export as JSON, and sync to a new operator-only Worker API, `/api/notes`, in its own SQLite Durable Object behind a bearer secret, separate from the public high scores.
- Add `tools/review_notes.lua`, which turns an export or a `GET /api/notes` response into a markdown worklist grouped by tag.

## Capabilities

### New Capabilities
- `asset-review-notes`: the review studio, targeted notes and their operator-only persistence and worklist.

### Modified Capabilities
None. The high-score API and the `/console` run rules are unchanged; the console only gains a link.

## Impact

- New `lib/review/` (studio, viewers, notes model, browser adapter, SHA-256); `lib/gallery_main.dart` routes `?page=studio`; one button in `lib/widgets/dev_console.dart`.
- `worker/notes.mjs`, the `/api/notes` route in `worker/index.mjs`, and a `REVIEW_NOTES` Durable Object with migration `v2` in `wrangler.jsonc`. Production needs `wrangler secret put NOTES_TOKEN`; without it the API answers 503.
- `scripts/build-web.sh` passes `BUILD_COMMIT` to the gallery build.
- Tests: `test/review_studio_test.dart`, `test-worker/notes.test.mjs`.
