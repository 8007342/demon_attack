# Tasks

## 1. Studio

- [x] 1.1 Route `?page=studio` in the gallery and link it from `/console` (ASSET REVIEW).
- [x] 1.2 Backgrounds: `DemonScene` reduced to the sector flyover, with run, speed and travel blend.
- [x] 1.3 Atlas animations from the generated contracts and `ship-weapons.json`: frame steps, loop modes, speed, filmstrip.
- [x] 1.4 Radio: filters, portrait lip-sync and subtitle, manifest metadata, auto-play next.
- [x] 1.5 Music: play, loop whole, seam, bar range or stem slot; bar timeline; MIDI score path.
- [x] 1.6 Staged scenes from the existing gallery pages.

## 2. Notes

- [x] 2.1 Notes panel: quick tags per kind, text, playhead offset and section, edit and delete.
- [x] 2.2 Local store, JSON export and import, content hashes and build commit (`BUILD_COMMIT`).
- [x] 2.3 `/api/notes` in its own SQLite Durable Object behind `NOTES_TOKEN`; sync from the studio.
- [x] 2.4 `tools/review_notes.lua` worklist and README section.

## 3. Verification

- [x] 3.1 `test/review_studio_test.dart`: hashing, store, sync, catalog coverage, notes panel, studio layout at phone and desktop widths.
- [x] 3.2 `test-worker/notes.test.mjs`: validation, storage, filters, last-writer-wins, token and origin gates, Lua worklist.
- [x] 3.3 Build the gallery once (`flutter build web -t lib/gallery_main.dart`).
- [ ] 3.4 Set `NOTES_TOKEN` in production and locally (`.dev.vars`), then do a first review pass on the local preview.
