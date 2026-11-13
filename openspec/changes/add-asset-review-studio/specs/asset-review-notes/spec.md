# Asset review notes

## ADDED Requirements

### Requirement: Review studio reachable from the console
The gallery SHALL offer an asset review studio at `/gallery/?page=studio`, and `/console` SHALL link to it. The studio SHALL have sections for backgrounds, atlas animations, staged scenes, radio clips, music cues and all notes. It SHALL lay out on phone and desktop widths.

#### Scenario: Opening the studio from the console
- **WHEN** the operator presses ASSET REVIEW on `/console`
- **THEN** the gallery opens on the studio, without starting a run

### Requirement: Live backgrounds
The studio SHALL play each sector's flyover background live with the game's renderer, with run, flight speed (including pause) and travel blend controls.

#### Scenario: Pausing a flyover
- **WHEN** the operator picks sector 3, run 2 and speed "pause"
- **THEN** the Ember Moon flyover for run 2 holds still and a note records the run and speed

### Requirement: Atlas animation player
The studio SHALL play every atlas animation listed by the game's atlas contracts frame by frame, with play, pause, single steps, loop, ping-pong or once, and a speed multiplier.

#### Scenario: Stepping a death animation
- **WHEN** the operator pauses a creature's death animation and steps forward
- **THEN** the next frame is drawn at an integer scale and the frame number is shown

### Requirement: Radio clip browser
The studio SHALL list the radio bank with filters for speaker, human or demon, emotion and event, and SHALL play a clip with its subtitle and the speaker's portrait lip-sync.

#### Scenario: Filtering demon clips
- **WHEN** the operator selects "demon" and an emotion
- **THEN** only demon clips with that emotion or gesture are listed, with a count against the whole bank

### Requirement: Music cue player
The studio SHALL play each music cue and stem with loops of the whole cue, its loop seam, a bar range or a stem slot.

#### Scenario: Looping a stem
- **WHEN** the operator picks the `stab` slot of `l1-layers`
- **THEN** playback repeats that slot's span until the loop is changed

### Requirement: Targeted notes
Every studio item SHALL have a notes panel with quick tags, free text and the playhead time when the note was started (optional per note). A note needs a tag or text. Several notes per asset SHALL be allowed, and each SHALL be editable and deletable.

#### Scenario: Tagging a clip at a moment
- **WHEN** the operator pauses a demon clip at 1.2 s, tags it "needs growl" and adds text
- **THEN** a note is stored for `radio / <clip id>` with that tag, text and offset 1.2

### Requirement: Quick tags per kind
Tags SHALL include regenerate, refine, timing and good/keep for every kind, and the audio faults (needs growl, flat emotion, uncompressed sound, clipping, too loud, too quiet) for audio.

#### Scenario: Visual tags stay off audio
- **WHEN** a radio clip is selected
- **THEN** the panel offers the audio fault tags and not the visual ones such as jitter

### Requirement: Note provenance
A note SHALL record its asset reference, kind, source file, the asset's content hash where known, its creation and update times, and the build commit when the build exposes it.

#### Scenario: Asset changed since the note
- **WHEN** a note's hash differs from the asset's current hash
- **THEN** the note is marked as written against an older version

### Requirement: Notes export
The studio SHALL download all notes as one JSON file in format `demon-attack.notes/v1`, and SHALL import such a file or a `GET /api/notes` response, keeping the newer edit of a note.

#### Scenario: Export
- **WHEN** the operator presses Export
- **THEN** the browser downloads a JSON file with the schema name, export time, build and every note

### Requirement: Operator-only notes API
The Worker SHALL serve `GET`, `POST` and `DELETE /api/notes` from a SQLite Durable Object separate from the high scores. Every request SHALL carry the operator bearer token. Writes from another origin SHALL be refused. Notes SHALL never pass through the high-score API.

#### Scenario: Unauthorised read
- **WHEN** a request reaches `/api/notes` without the operator token
- **THEN** the Worker answers 401 (or 503 when no token is configured) and returns no notes

### Requirement: Notes API validation and merge
The API SHALL validate notes field by field, cap request size and stored count, and filter reads by kind, asset, tag and update time. When a note is written twice, the newer `updatedAt` SHALL be kept.

#### Scenario: Offline copy does not overwrite an edit
- **WHEN** a note is posted with an older `updatedAt` than the stored one
- **THEN** the stored note is kept

### Requirement: Worklist tool
`tools/review_notes.lua` SHALL turn a notes export or `GET /api/notes` response into a markdown worklist grouped by tag, ordered from regenerate to keep, and SHALL filter by tag and kind.

#### Scenario: Worklist from an export
- **WHEN** the operator runs `lua tools/review_notes.lua notes.json`
- **THEN** the output has one section per tag with its count and a checkbox line per note
