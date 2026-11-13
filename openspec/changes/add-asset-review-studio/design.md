# Design

## Decisions

1. **The studio lives in the gallery app, not the game.** `lib/gallery_main.dart` already builds to `/gallery/` and is linked from `/console`. The studio is a page of it (`?page=studio`, with `&tab=` and `&item=` deep links), so the shipped game bundle does not grow and the console keeps its run rules. The console only gains a link.
2. **The studio reuses the game's renderers and contracts.** Backgrounds are a `DemonScene` reduced to its `SectorBackground` (flight speed, run and travel blend are the controls). Atlas animations come from the generated contracts (`CombatAtlas`, `GroundAtlas`, `GroundTroopsAtlas`, `VegetationAtlas`, `FlyoverAtlas`, `BossAtlas`, the comms portrait rows and `ship-weapons.json`), not from hand-written rectangles. Radio clips use the comms bank, `CommsMouth`, `paintPortrait`, `paintBackdrop` and `CommsSubtitle`. Music uses the cue manifest (seam points, bar length, stem slots). The squad-comms playback (`comms-audio.js`) is not called: the studio plays the raw file with an audio element, which is what a note is about and gives a reliable playhead.
3. **Note format `demon-attack.notes/v1`.** Following kumbia-kombat's console notes, a note is keyed by a stable reference (`kind / id`, for example `radio / gloat.d3`) and names its source file. It adds an id, quick tags, text, an optional playhead `offset` in seconds, a `section` (run, bar range, stem slot or frame), the asset's content hash, `createdAt` and `updatedAt`, and the build commit. Several notes per asset are allowed. The same JSON is the export download, the Worker body and the Lua tool's input.
4. **Content hashes.** Audio uses the manifests' `sha256.ogg`. An atlas animation uses the SHA-256 of its image file, a background the SHA-256 of its six image hashes, a scene the hash of its three main sheets. The panel marks a note whose hash differs from the current asset ("asset changed since").
5. **Local first, then sync.** Notes are saved to `localStorage` at once and marked pending. Sync pushes pending notes in batches of 200, sends pending deletions, then pulls every note. For one id the newer `updatedAt` wins on both sides, so an old offline copy never overwrites an edit.
6. **Operator-only storage.** `/api/notes` is served by its own SQLite Durable Object (`ReviewNotes`, migration `v2`), not by `HighScores`. Every method needs `authorization: Bearer <NOTES_TOKEN>`. Without the secret the API answers 503, so a deployment without it never exposes notes. Writes from another origin are refused. Bodies are capped at 256 KiB and stored notes at 5000.
7. **Lua worklist.** `tools/review_notes.lua` is plain Lua 5.4 with its own JSON decoder, following the forge's Lua-first tooling rule. Tags are ordered by action: regenerate, refine, the audio faults, timing, others, keep, untagged.

## Risks

- `localStorage` is per browser. Until a sync or an export, notes exist on one device only. The pending badge on the sync button shows this.
- Raw playback does not include the in-game ducking and +2 dB voice gain, so loudness judgements are relative to the file.
- An atlas animation's hash covers its whole sheet, so a change to any sprite on that sheet marks every note on it as "changed since".
