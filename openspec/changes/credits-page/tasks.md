# Tasks

## 1. Page (`lib/ending/`)
- [x] 1.1 `CreditsView`: still page, keyboard scrolling, phone and desktop layouts (design §1)
- [x] 1.2 Remove the auto-scroll ticker, PAUSE/RESUME button and Space toggle from `EndingPage`
- [x] 1.3 Built-on cards (Tillandsias icon, neutral glyphs for Fedora and Podman), source button, trademark note (design §2)

## 2. Credits data (`tools/generate_credits.lua` → `assets/credits.json`)
- [x] 2.1 Schema v2: `built_on`, `source_label`, `trademark_note`; a `url` on every row
- [x] 2.2 Models: links, the ACE-Step licence fix, Demucs, whisper.cpp, the image-workflow models (design §4)
- [x] 2.3 Third-party licences from `licences/acknowledgements/`
- [x] 2.4 CC0 sample libraries as "coming" (design §6)
- [x] 2.5 Open-source projects in three groups (design §5); SDK and package links

## 3. Credits song
- [x] 3.1 `credits` in the song map, `tools/score/songs/credits.lua`, the `credits` form in `score_gen.lua`
- [x] 3.2 `lua tools/score/score_gen.lua --check` and `lua tools/midi_stats.lua check`
- [x] 3.3 `node tools/mix_meter/trim.mjs` (under `forge-guard run --`)
- [x] 3.4 `SongDirector` `credits` cue; `main.dart` cues it for the title's CREDITS; the web player loads it early

## 4. Tests and gates
- [x] 4.1 Widget and data tests (design §7); song director tests
- [x] 4.2 §2 gates: analyze, test, worker tests, build, `openspec validate credits-page --strict`
- [ ] 4.3 Operator listening: the credits song and the move from and back to the overture
- [ ] 4.4 Operator review of the logo decisions (design §2), e.g. ask the Fedora Council or read the LF policy for Podman
