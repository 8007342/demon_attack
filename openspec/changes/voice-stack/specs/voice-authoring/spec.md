# Voice authoring

## ADDED Requirements

### Requirement: Performance direction on every line
Every radio line in `art/comms/lines.json` SHALL carry an `emotion` from the closed emotion list and MAY carry an `intensity` (0 low, 1 normal, 2 high, 3 peak; default 1) and a free-text `direction` note for the take. The `dart` stage SHALL reject an unknown emotion, an intensity outside 0–3, or a `direction` longer than 120 characters, and name the clip id.

#### Scenario: Existing lines stay valid
- **WHEN** the `dart` stage runs on a bank whose lines carry only today's nine emotions and no intensity
- **THEN** it succeeds, treats every line as intensity 1, and `lib/comms/comms_bank.dart` is byte-identical to before

#### Scenario: Unknown emotion
- **WHEN** a line says `"emotion": "giddy"` and `giddy` is not on the list
- **THEN** the stage exits non-zero with `<clip id>: unknown emotion giddy`

#### Scenario: New emotions
- **WHEN** a line uses one of the added emotions `cheering`, `furious`, `relieved`, `awed` or `smug`
- **THEN** it validates, and the engine profile for that emotion is read from `art/comms/voice-engines.json`

### Requirement: Non-verbal cues from a closed vocabulary
A line's text MAY contain inline cues in square brackets (`[laugh]`, `[whoop]`, `[grunt]`) and a line MAY be cue-only. Cues SHALL come from the closed vocabulary in `art/comms/cues.json`, each mapped per engine to a native tag or to a separately rendered stinger. Cues SHALL be stripped from the subtitle text and from the reading time.

#### Scenario: Cue inside speech
- **WHEN** a line reads `"[whoop] Got him! Scratch one!"`
- **THEN** the subtitle shows `Got him! Scratch one!` and the render request carries the engine's own whoop tag or a whoop stinger before the speech

#### Scenario: Unknown cue
- **WHEN** a line contains `[burp]` and `burp` is not in `cues.json`
- **THEN** the `dart` stage exits non-zero and names the clip id and the cue

#### Scenario: Cue-only line
- **WHEN** a demon line is `"[growl]"` with a SIGINT gloss
- **THEN** it renders as a non-verbal clip, and the card shows the gloss only

### Requirement: Family-friendly language
Every human line, demon `say` and gloss SHALL pass the tone check in `art/comms/tone.json`: no word or phrase on its deny list, and every exclamation from its allowlist of pseudo-swears (e.g. "frak", "blast it", "son of a glitch"). The allowlist SHALL stay PG: no slurs, no real profanity, no religious oaths, nothing sexual. The `dart` stage SHALL fail on a deny-list match.

#### Scenario: Pseudo-swear passes
- **WHEN** a line reads `"Frak! They're on my six!"`
- **THEN** the tone check passes

#### Scenario: Denied word
- **WHEN** a line contains a word on the deny list, matched case-insensitively on word boundaries with common letter swaps
- **THEN** the `dart` stage exits non-zero, names the clip id and quotes the matched word

#### Scenario: Allowed idiom
- **WHEN** the existing line "Target destroyed. Hell of a run, pilot." is checked
- **THEN** it passes because "hell of a" is an allowlisted idiom, while "hell" on its own is denied

### Requirement: One stable voice per character
Each cast member SHALL have a committed voice identity: a reference clip (lossless, 6–20 s, under `art/comms/voices/`), its transcript, a short voice description and the engine that made it. Every take for that character SHALL be conditioned on that identity. The `stats` stage SHALL report per-character pitch and timbre and flag two characters closer than its distinctness threshold.

#### Scenario: Identity survives a reset
- **WHEN** the forge cache is wiped and a line for Mensah is re-rendered
- **THEN** the take is conditioned on `art/comms/voices/mensah.flac` from the repository, not on a cached file

#### Scenario: Alien voices
- **WHEN** a brood line is rendered
- **THEN** it is performed by the speaker's identity, then reversed, pitched down and growl-layered by the committed demon delivery settings, and both the clean and the transformed masters are kept

### Requirement: Takes and picks are logged
Every voice render batch SHALL write a ledger under `plan/render-runs/voice-<batch>/`: per take the clip id, engine, model and revision, seed, settings, input hash, output sha256, duration, loudness, peak and verdict; per clip the picked take and a one-line reason. Picked masters SHALL be committed. A take that fails the accept rules SHALL never be picked.

#### Scenario: Several takes for key lines
- **WHEN** a batch renders a priority ≥ 8 or `signature` line
- **THEN** it renders at least three takes with different seeds, and the ledger records which was picked and why

#### Scenario: Resume after a reset
- **WHEN** a batch is interrupted and restarted
- **THEN** takes whose ledger entry and output hash match are skipped, and only missing or changed takes render

### Requirement: Loudness and format
Shipped voice clips SHALL be mono Opus at 48 kbps in Ogg, decoded peak at most 0 dBFS. Human speech SHALL be normalised to −18 LUFS integrated, demon speech to −18.5 LUFS, and clips shorter than 1 s to the same target measured as maximum momentary loudness. Masters SHALL be mono FLAC at the engine's native rate, at least 24 kHz, with at least 1 dB true-peak headroom before the radio chain.

#### Scenario: Verify stage
- **WHEN** `verify` decodes the bank
- **THEN** every clip is within ±1 LU of its target, peaks at most 0 dBFS, is not silent, and matches its manifest duration

#### Scenario: Short stinger
- **WHEN** a 0.6 s whoop is normalised
- **THEN** its maximum momentary loudness is −18 ±1 LUFS

### Requirement: Placeholder to final swap
Each manifest clip SHALL carry a `tier`: `text` (no audio), `placeholder` (borrowed or quick render), `candidate` (rendered, not picked) or `final` (picked in a ledger). Only `placeholder` and `final` clips SHALL ship. Promoting a clip SHALL keep its clip id, regenerate the bank and pending list, and pass `verify` and the full test gates.

#### Scenario: Promote a batch
- **WHEN** a batch's picks are promoted
- **THEN** the manifest tiers change to `final`, `voice-batch-pending.md` loses those lines, and the borrowed-line count in `test/comms_director_test.dart` drops by the number of borrowed lines replaced

#### Scenario: Candidate never ships
- **WHEN** the web build runs and a clip is still `candidate`
- **THEN** the build uses the clip's placeholder or text card instead

### Requirement: Engines run as admitted studio capabilities
Voice engines SHALL run as host studio capabilities behind the studio's admission and licence register, never as a second GPU container or a direct model pull. A shipped clip SHALL come only from an engine whose code and weights licences allow commercial use, and its engine, revision and licence SHALL be in the manifest.

#### Scenario: Non-commercial weights
- **WHEN** an engine's weights are licensed non-commercial
- **THEN** its takes may be used for internal reference only, and the `verify` stage fails if one is in the shipped bank

#### Scenario: Model not admitted
- **WHEN** a batch asks for a model that the studio has not admitted
- **THEN** the batch stops with the studio's consent or admission answer, and nothing is downloaded without the operator's token
