# Tasks

## 1. Research and request (this branch)

- [x] 1.1 Survey expressive TTS, voice identity, non-verbal vocalisations, radio FX and authoring tools, with sources (`plan/voice-stack-research.md`)
- [x] 1.2 Inventory what is installed today (forge, studio, host audio appliance); decide on placeholders (design §6)
- [x] 1.3 Write the coordinator request list: models, VRAM, licences, studio nodes (research §9)
- [x] 1.3a Re-read the licence texts for a free GPL-3.0 game; "OK for this repo?" per model (research §10)
- [x] 1.3b Operator decisions flagged in research §10 (2026-11-16, research §10.4): non-commercial with a credit line is acceptable (Fish S2-Pro, Higgs v2 in); Chatterbox dropped; IndexTTS-2.5 out unless a need such as exact duration control appears
- [x] 1.3c Drop Chatterbox: pin and settings out of `audio.json` (`delivery`, `identity` kept), its stages out of `tools/comms_pipeline.py`, the CPU worker tools out of `tools/production/`; `dart` byte-identical
- [x] 1.3d Credits: voice-stack engines and the Fish Audio and Higgs/Llama credit lines in `tools/generate_credits.lua` → `assets/credits.json`
- [x] 1.3e Sign-off list `plan/licences-to-sign.md` (licence id, models, URL, pinned sha256, bytes, scope, what signing permits)
- [ ] 1.3f Operator signs the three restricted licences through `/accept-licence` (records in `licences/acknowledgements/`)
- [ ] 1.4 Coordinator admits the primary engine as a studio capability (tillandsias, after #1103); record the admitted node class names and pins in `art/comms/voice-engines.json`

## 2. Schema and checks (`tools/comms_pipeline.py`, `dart` stage, pure Python)

- [ ] 2.1 Emotion list (today's nine plus `cheering`, `furious`, `relieved`, `awed`, `smug`), `intensity` 0–3, `direction` ≤ 120 chars; byte-identical bank for today's lines
- [ ] 2.2 `art/comms/cues.json` (closed cue vocabulary, per-engine mapping); strip cues from subtitles and reading time; reject unknown cues
- [ ] 2.3 `art/comms/tone.json` (allowlist, idioms, deny list with letter-swap matching); fail on deny matches; run it over the current bank and fix or allowlist what it finds
- [ ] 2.3a Two layers: `theme`, `layer`, `surface`, `hidden`, `speakers`, `retorts` on every allowlist entry; `quoteDeny`; seed `tone.json` from design §3.2; `nod`/`reveal` entries rationed as `signature`
- [ ] 2.3b Write a first set of trading exchanges with the allowlist (brood taunt, squad retort) as `pending: text` lines; tone check passes
- [ ] 2.3c `"hint": true` flag; reject cues in hint lines; hand the flag to the `carrier-hatches` line-length test (design §3.3)
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
- [ ] 5.3 Manifest `tier`, `engine`, `revision`, `licence` (`outputs`, `credit`, `decision`); `verify` rejects `restricted` engines without a signed decision and `candidate` clips in the shipped bank; credits and README list the shipped engines' credit lines

## 6. Pilot and promotion

- [ ] 6.1 Pilot batch: 20 lines across all emotions, five cue-only clips, two pseudo-swears, three brood lines, rendered by VoxCPM2 and each admitted challenger (Fish S2-Pro, Higgs v2) from the same identity clips; per-line picks with reasons; operator listens
- [ ] 6.2 Promote the pilot; update the borrowed-line count; full gates
- [ ] 6.3 Re-render the remaining bank in batches; promote each; archive this change when the bank is all `final`
