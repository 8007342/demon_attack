# Tasks

## 0. Research and spec (`work/audio-music`)
- [x] 0.1 Research with provenance: `plan/soundtrack-research.md`; Part S in `plan/provenance-audit.md`
- [x] 0.2 This change: proposal, design (song map §3, boss section graph §4), delta specs, tasks; `openspec validate adaptive-soundtrack --strict`
- [ ] 0.3 Operator review of the architecture, the song map and the boss graph

## 1. Pilot: the tour-1 carrier with core nodes (design §8)
- [x] 1.1 Recipe `art/music/soundtrack/pilot-carrier-t1.json` (sections, tags, seeds, overrides of `campaign-text-headroom.json`)
- [x] 1.2 `tools/soundtrack_check` (Go): `analyze`, `cut`, `check`; `tools/soundtrack_pilot.lua`: ingest, analyse, cut, encode
- [x] 1.3 Generate 4 turbo takes per section, 2 XL base takes of the core, 2 structured 150 s takes, one job at a time
- [x] 1.4 Gate, cut, seam-check; one pick per section with its reason in `plan/render-runs/soundtrack-pilot.md`; encodes in `art/music/soundtrack/pilot/`
- [x] 1.5 Listening and transition page (sections, and the fight's events through design §4.3 on a Web Audio clock)
- [ ] 1.6 Operator listening (P1): approve or replace each pick; record the verdicts in the ledger
- [ ] 1.7 A/B per section: an XL base pick and a cut from the 150 s structured take (P2)
- [ ] 1.8 Browser decode check: each loop decodes to `bars × barSamples` in Chrome, Firefox and Safari 18.4+ (P3)
- [ ] 1.9 `v2` variants of `tier1`, `tier2` and `core` by cover re-performance (`ReferenceTimbreAudio`), gated for pulse drift (P4)
- [ ] 1.10 Try `SetLatentNoiseMask` on an audio latent as a seam repair; record whether ComfyUI accepts it and how it sounds (P5)

## 2. Song map and pipeline
- [ ] 2.1 `art/music/soundtrack/song-map.json` for the whole run (design §3, §4); a Lua schema check with `jq`
- [ ] 2.2 Generalise `tools/soundtrack_pilot.lua` into `tools/soundtrack.lua` driven by the song map (any song, any grid, variants, the long-form cut)
- [ ] 2.3 Lua generator: the map to `web/audio/music/manifest.json` (v5: songs, sections, transitions, sizes, hashes) and to `lib/game/song_map.dart`; add the Dart file to CLAUDE.md §4
- [ ] 2.4 A cross-section coherence measure (long-term spectrum distance between neighbouring sections) in `soundtrack_check`

## 3. Runtime: Dart
- [x] 3.1 `lib/game/song_director.dart` (pure Dart): song state, transition table, minimum dwell, latest-wins queue, tier mapping by `depth`
- [x] 3.2 Unit tests: every row of design §4.3, two quick tiers, a late decode, the coda; no audio needed
- [x] 3.3 `MusicBridge`: carrier accents per design §4.3; drop the carrier-v3 placeholders
- [x] 3.4 `lib/services/audio.dart`: `audioSong(...)` with a test stub; `// --- adaptive-soundtrack` marker in `main.dart` where the director is registered

## 4. Runtime: web
- [ ] 4.1 `demon-audio.js`: section graph player (loop re-scheduling with `start(when, offset)`, same-position switches, bridges that auto-advance, next-beat moves)
- [ ] 4.2 Loading: neighbours first, 48 MB decoded cap, late moves wait a bar; `state.song`, `section`, `queued`, `decodedBytes`, move log
- [ ] 4.3 `test-worker/music.test.mjs`: manifest v5 shape, whole-bar files, transitions reference existing sections
- [ ] 4.4 Browser smoke: the carrier pilot plays through approach → H1 → H2 → transform → core → collapse → victory from scripted events with no gap longer than 5 ms at any move

## 5. Production (after the pilot is approved)
- [ ] 5.1 Carrier songs for tours 2–5 (U = 2, 3, 3, 4 hatch sections), each logged in `plan/render-runs/`
- [ ] 5.2 World songs: Krybor, Ringfall, Ember Moon, The Hollow (arrival, A–D × v1/v2, clear), the Stormfront section
- [ ] 5.3 Bridges (`k→r`, `r→e`, `e→h`, `h→c`, `c→k`), the overture, the defeat song
- [ ] 5.4 The coda: finale, worldized chain, ukulele theme at 95 BPM (text-to-music sketch now; sampled after #1103)
- [x] 5.5 Retire the old `l<n>-t<k>` cues from the manifest once every song is in (done by 9.8: the score covers every song, design §12.8.3)

## 6. After tillandsias#1103
- [ ] 6.1 Re-render the approved recipes with XL SFT and A/B them against the turbo picks
- [ ] 6.2 SFZ drum and bass bed per song, following `musicIntensity`; route thickening of the world songs
- [ ] 6.3 One-arrangement `v1`/`v2` variants as stem mixes; if the pack exposes ACE's masked tasks, repaint seams

## 8. MIDI first: the score as the first layer (`work/midi-first`, design §11)
- [x] 8.1 Research with provenance: `plan/midi-first-research.md`; Part M in `plan/provenance-audit.md`
- [x] 8.2 Design §11, delta specs (score as the first layer, bank, voice budget, score gates; "Adaptive MIDI soundtrack" modified), these tasks; `openspec validate adaptive-soundtrack --strict`
- [x] 8.3 Feasibility probe without downloads: `tools/midi_stats.lua` (size, peak voices) on the L3 score and the fallback cues; inventory of forge tools (none of fluidsynth, sfizz, basic-pitch, demucs installed; ollama served)
- [ ] 8.4 Bake-off (N13): the pilot's `core` section as a score with a provisional bank and as the recorded pick on the listening page; measure CPU, voices, decoded bytes and move gaps on a mid-range Android phone and an iPhone; spessasynth_lib as the measured alternative runtime; operator verdict
- [x] 8.5 Bank builder (Lua + ffmpeg): CC0 sources → zones (note, velocity, round-robin) → trimmed Opus sprites + `bank.json` (zones, sizes, sha256, source, licence); credits in `assets/credits.json` (needs N11). Built and tested on a synthetic fixture (`work/score-sampler`, design §12.9): `tools/bank/bank_build.lua` (`--dry-run`, pin verification, f0 check, Opus sprites), `art/music/bank/recipe.json`, `sfz-keys.json`. Run on the admitted pins (`work/sample-bank`, design §12.9.7): every source fetched at its pinned commit and verified; the pitch check replaced by a spectral root verification (`--f0-report`); credits in `tools/generate_credits.lua` → `assets/credits.json` ("Sampled instruments")
- [x] 8.6 Curate the first bank: drums (Big Rusty or Virtuosity), Growlybass (not Meatbass), Black And Green Guitars DI, VCSL organ, timpani and tubular bells, VSCO 2 CE brass; ≤ 2 MB Opus, ≤ 41 MB decoded, phone tier ≤ 16 MB (needs N11). Built with the round-2 pins (trumpet, glockenspiel, high guitar, organ C5/F#5): 168 zones, 1 907 850 B Opus, 40.93 MB decoded on desktop, 14.55 MB on phones; bass −12 confirmed and the VCSL organ names kept by measurement (`plan/render-runs/sample-bank.md`)
- [ ] 8.7 Texture-bed gate in `soundtrack_check` (`bed`: percussive share, energy below 120 Hz); a carrier choir bed for `core` and `collapse` from the pilot recipe with a no-drums prompt (N12)
- [ ] 8.8 Route B probe: transcribe the pilot's picked `core` take (host `audio.separate`, basic-pitch ONNX via Rust `ort`, Go onsets and f0) into a motif file; report per part what survived cleanup (needs N9, N10)
- [ ] 8.9 Route C probe: a validator-gated qwen2.5 draft of an 8-bar lead and fill from the song map (one ollama job at a time); then AMT infill and a Clef header take, if admitted (N10); measure bar-correctness and key fit
- [x] 8.10 `tools/midi_stats.lua check`: whole bars, grid onsets within 12 ms, out-of-scale share, zone ranges, peak voices ≤ 32 with a 0.5-beat release; a Lua test on the L3 score (done on the committed score, which replaced the L3 score; the test is in `test-worker/music.test.mjs`, design §12.9.4)
- [ ] 8.11 Score generator in Lua driven by the song map (sections, masks, variants as masks, stingers in scale degrees), reading the motifs' JSON export; the carrier song `c1` first, then the four world songs
- [x] 8.12 `demon-audio.js` sampler (in `demon-score.js`, design §12.9.3; heard only once the bank exists): SMF type 1 with track names, zones and `playbackRate`, per-track gains and masks on bar lines, the guitar, bass, drum and pad buses, the 48/32 voice cap with stealing, progressive bank loading with the oscillator per note until decoded; `state` diagnostics
- [x] 8.13 `test-worker/music.test.mjs`: score files parse, every section is whole bars, masks reference existing tracks, `bank.json` zones cover every track's range (the recipe's plan until a bank exists; coverage per role, design §12.9.5)
- [x] 8.14 Retire each `web/audio/midi/` cue and any recorded full mix once its score section is approved (no duplicates, design §11.2): all 38 MIDI cues and every recorded cue retired (design §12.8.3)

## 9. Score runtime in the live game (`work/score-runtime`, design §12)
- [x] 9.1 Song map `art/music/soundtrack/song-map.json` for songs `k` (Krybor) and `c1` (the carrier): sections, kinds, grids, keys, tier masks, v2/power/fleet layers, stingers in scale degrees, the accent map
- [x] 9.2 Score generator `lua tools/score/score_gen.lua` (+ `--check`): composers from the game's motifs, the §11.9 score gates (whole bars, grid, key share, tracks, peak voices ≤ 32 with a 0.5-beat release), outputs `web/audio/score/`, `score.json`, `lib/game/song_map.dart` (added to CLAUDE.md §4)
- [x] 9.3 `web/audio/demon-score.js`: SMF type 1 parser, section-graph player on demon-audio.js's clock (bar/beat moves, slip, latest wins, same position, tails/bridges, masks with 20/60 ms ramps, stingers in key, voice rules, 48/32 cap with stealing), synth voices and role buses (amp + cabinet guitars, bass drive, room), the `makeVoice` bank seam, `state.score`; hand-over with the recorded cues on bar lines both ways; `?score=off` and the per-device switch
- [x] 9.4 `SongDirector` wired in main.dart (`// --- adaptive-soundtrack`): every scene cue through `cue()`, structured events through the shared bridge
- [x] 9.5 Tests: `test/song_director_test.dart`, `test-worker/score.test.mjs` (the score files, the graph on a mocked audio clock, hand-overs, masks, stingers, cap)
- [x] 9.6 Listening aid: the SCORE · LISTEN panel on `/console` (scripted carrier fight and sector song, step buttons, stingers, SCORE/RECORDED A/B)
- [x] 9.10 The bank behind an off-by-default switch until the operator approves it (round 7): `?bank=1|0`, the /console VOICES toggle (stored per device), nothing fetched while off; `mix-trim.json` measured in both modes (`bank` block, anchored to the synth's top); A/B listening page of seven sections (design §12.9.7)
- [ ] 9.11 Flip `BANK_DEFAULT` to true in `web/audio/demon-score.js` once the operator approves the sampled score
- [ ] 9.7 Operator listening in the live game (N1, N13): the combining, the voices and the mix balance; tune `makeVoice` levels and the buses from the verdict
- [x] 9.8 Lead decision (design §12.6, §12.8.3): the operator approved the preview; deleted `art/music/soundtrack/pilot/c1-*.opus` (7 files, 1.36 MB), every recorded cue in `web/audio/music/` and its manifest (54 files, 6.34 MB; the `.m4a` twins went with `work/one-format-audio`) and `web/audio/midi/` (38 files, 68 KB); removed `demonAudio.cue`, the SCORE/RECORDED switch and `?score=off`; the review studio's music tab lists the score
- [x] 9.9 Score songs for sectors 2-4 (Ringfall, Ember Moon, The Hollow) and tours 2-5's carriers in the same generator; bridges `k→r`, `h→c` (design §12.8): `songs/sector.lua` (the three worlds and every world's Stormfront `storm`), `songs/carrier_tours.lua` (tours 2-5, every hatch tier native, `c5`'s finale and worldized bridge), `songs/bridges.lua` (`menu-k`, `k-r`, `r-e`, `e-h`, `h-c`, `c-k`), the overture, the defeat and the coda with its ukulele track; the player's cross-song hand-over, `then`, `now` moves, the worldized chain, per-song loading; SongDirector's travel bridges, bonus levels, scenes and the ending; tests (a five-route campaign trace on bar lines, the size totals); the listening panel's FULL RUN tour

## 7. Close
- [ ] 7.1 Test gates (CLAUDE.md §2) on the runtime tasks; `openspec validate adaptive-soundtrack --strict`
- [ ] 7.2 Archive after all tasks are checked
