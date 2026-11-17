# Tasks

## 1. Research and design (this branch)

- [x] 1.1 Research emotion direction, dialogue modes, non-verbals, brood DSP, take rejection and ComfyUI nodes, with sources (`plan/audio-voices-research.md`); unsourced claims V-04 to V-07 in `plan/provenance-audit.md`
- [x] 1.2 Design: beats, threads, brood layers, FX chain v2, render routes, pipeline, pilot, ready-to-run checklist (`design.md`)
- [x] 1.3 Pilot script `art/comms/voice-pilot.json` (8 lines, 4 threads, 10 brood items; beats checked against text)
- [ ] 1.4 Operator answers design §9 (pilot scorer, child voices); coordinator answers the admission pins (§9, question 3)

## 2. Schema (`tools/comms_pipeline.py` `dart`, pure Python)

- [ ] 2.1 `beats`: two to four, words join to the cue-stripped text, last beat sets the line's emotion; byte-identical bank without beats
- [ ] 2.2 `threads`: two to four turns, `gap` −0.6 to 1.5, clip ids `<trigger>.x<n>.<k>`, `threadChance`; Dart bank carries threads
- [ ] 2.3 Brood `vocal` and `growl` fields; `voice: plain` only with `set: second` or in cinematic lines; `cheer` and `laugh` join the demon cue list in `cues.json`
- [ ] 2.4 Validate `art/comms/voice-pilot.json` with the same checks; `stats` thread coverage per trigger
- [ ] 2.5 `lines.json` `comment` v6; tests with a fixture bank through the shared flock

## 3. Director (`lib/comms/comms_director.dart`)

- [ ] 3.1 Threads: playable only with every speaker on the call; channel reserved for the whole thread; turns placed by `gap`, overlaps allowed; urgent lines cut and drop the rest
- [ ] 3.2 Subtitles for overlapping turns; mouth tracks per turn
- [ ] 3.3 Director tests (lineup skip, overlap, urgent cut); comms layout tests still pass

## 4. Tools

- [ ] 4.1 `tools/brood_fx` (Rust: signalsmith-stretch, fundsp, ebur128): the closed step set, deterministic by seed, wet and dry outputs, beat crossfade; unit tests for determinism
- [ ] 4.2 `demon-delivery.json` v2 schema and loader; v1 fields still read for the shipped bank
- [ ] 4.3 Take checks CLI (Go or Rust over whisper.cpp; speaker similarity; ebur128; ffmpeg `astats`/`silencedetect`): verdicts and reasons into the ledger
- [ ] 4.4 Lua job `tools/production/voice-pilot.lua`: requests per engine recipe and route, one workflow at a time, resume by hash; dry-run mode
- [ ] 4.5 Engine-blind listening page with score export to `ledger.json`

## 5. Identities

- [ ] 5.1 Re-cast brood identities to the reveal people (`plan/endgame-reveal-ledger.md` §1.3) in `cast.json`; children marked pending approval
- [ ] 5.2 Hot references for the pilot's speakers (`art/comms/voices/<id>.hot.flac`), picked and logged

## 6. Pilot

- [ ] 6.1 Run the pilot (design §7, GPU order §7.5): default stack, then S2-Pro, then Higgs v2; vocal reels and the vocal library for the pilot's brood speakers
- [ ] 6.2 Automatic checks; calibrate similarity thresholds per engine
- [ ] 6.3 Blind listening, scores in the ledger; FX chain values picked per brood character with reasons
- [ ] 6.4 Decision per role (design §7.4) recorded in design §2, `voice-engines.json` and research §8; closes voice-stack task 6.1
- [ ] 6.5 Promote the pilot picks under the voice-stack tier rules; append the pilot's new lines and threads to `lines.json`; full gates
