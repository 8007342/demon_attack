# Tasks

## 1. Research and request (this branch)

- [x] 1.1 Survey expressive TTS, voice identity, non-verbal vocalisations, radio FX and authoring tools, with sources (`plan/voice-stack-research.md`)
- [x] 1.2 Inventory what is installed today (forge, studio, host audio appliance); decide on placeholders (design §6)
- [x] 1.3 Write the coordinator request list: models, VRAM, licences, studio nodes (research §9)
- [ ] 1.4 Coordinator admits the primary engine as a studio capability (tillandsias, after #1103); record the admitted node class names and pins in `art/comms/voice-engines.json`

## 2. Schema and checks (`tools/comms_pipeline.py`, `dart` stage, pure Python)

- [ ] 2.1 Emotion list (today's nine plus `cheering`, `furious`, `relieved`, `awed`, `smug`), `intensity` 0–3, `direction` ≤ 120 chars; byte-identical bank for today's lines
- [ ] 2.2 `art/comms/cues.json` (closed cue vocabulary, per-engine mapping); strip cues from subtitles and reading time; reject unknown cues
- [ ] 2.3 `art/comms/tone.json` (allowlist, idioms, deny list with letter-swap matching); fail on deny matches; run it over the current bank and fix or allowlist what it finds
- [ ] 2.4 Update the `lines.json` `comment` (v5: intensity, direction, cues, tone) and `plan/audio-studio/README.md`
- [ ] 2.5 Tests for 2.1–2.3 (a fixture bank with good and bad lines), run through the shared flock

## 3. Voice identities

- [ ] 3.1 Write a voice description per cast member (fleet, ground crew Mensah/Kessler/Voss/March, brood) in `art/comms/cast.json`
- [ ] 3.2 Render or design each reference clip with the admitted engine, pick it, commit `art/comms/voices/<id>.flac` and its transcript; log in `plan/render-runs/voice-identities/`
- [ ] 3.3 `stats` stage: distinctness report over the new identities

## 4. Batch runner, takes and picks

- [ ] 4.1 Lua batch job (`tools/production/`) that queues studio workflows one at a time, writes the per-take ledger and skips verified takes on resume
- [ ] 4.2 Take counts: three for priority ≥ 8 and `signature` lines, two otherwise; automatic accept rules (length, clipping, silence, ASR word match where available)
- [ ] 4.3 Picks: contact sheet or listening page per batch; one-line reason per pick in the ledger; commit picked FLAC masters

## 5. Delivery

- [ ] 5.1 Radio chain v4: keep the current chain; add cue stingers and the demon growl layer as committed settings
- [ ] 5.2 Loudness: short-clip momentary measure, true-peak headroom, `verify` checks per design §5
- [ ] 5.3 Manifest `tier`, `engine`, `revision`, `licence`; `verify` rejects non-commercial engines and `candidate` clips in the shipped bank

## 6. Pilot and promotion

- [ ] 6.1 Pilot batch: 20 lines across all emotions, five cue-only clips, two pseudo-swears, three brood lines; operator listens
- [ ] 6.2 Promote the pilot; update the borrowed-line count; full gates
- [ ] 6.3 Re-render the remaining bank in batches; promote each; archive this change when the bank is all `final`
