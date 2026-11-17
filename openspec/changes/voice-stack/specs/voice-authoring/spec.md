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

### Requirement: Two-layer pseudo-swears
Each allowlist entry in `tone.json` SHALL carry a `theme`, a `layer` (`surface`, `nod` or `reveal`) and a plain `surface` meaning that works on its own for a young player. A `nod` or `reveal` entry SHALL also note its hidden reading for reviewers. Every phrase SHALL be original: no quoted line, lyric or catchphrase from another work. The hidden reading SHALL stay as PG as the surface.

#### Scenario: Surface stands alone
- **WHEN** a reviewer reads a `nod` entry's `surface` field without its hidden note
- **THEN** the phrase still makes sense as a squad exclamation

#### Scenario: Copied catchphrase
- **WHEN** a line contains a phrase on `tone.json` `quoteDeny` (famous lines from games, films or songs), matched case-insensitively
- **THEN** the `dart` stage exits non-zero and names the clip id

#### Scenario: Missing layer
- **WHEN** an allowlist entry has no `theme` or `layer`
- **THEN** the `dart` stage exits non-zero and names the entry

#### Scenario: Trading lines
- **WHEN** an exchange trigger pairs a brood taunt with a squad retort
- **THEN** both may use allowlist entries, and an entry with `retorts` lists the entries that answer it

### Requirement: Hint lines fit one line
An in-fight hint line (a short instruction such as "Destroy the hatches!", "Time the open hatch!" or "Fire ahead of its position!") SHALL fit on one radio subtitle line at the radio font size. The font size and the line-length test are owned by change `carrier-hatches`; this change only marks hint lines (`"hint": true`) so that test can find them. A hint line SHALL carry no cues.

#### Scenario: Hint too long
- **WHEN** a line marked `"hint": true` is too long for one subtitle line
- **THEN** the `carrier-hatches` line-length test fails and names the clip id

#### Scenario: Cue in a hint
- **WHEN** a hint line contains `[whoop]`
- **THEN** the `dart` stage exits non-zero

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
Voice engines SHALL run through a Tillandsias studio voice capability (like #1103, not built yet) behind the licence register, never as a second GPU container or a direct pull, loading only the weights and code commits in `plan/model-pins-voice.md`. A shipped clip SHALL come only from an engine whose licence leaves the audio free beyond a credit line, or one a signed decision covers. The manifest SHALL carry each clip's engine, revision, licence and credit.

#### Scenario: Output-restricting licence
- **WHEN** an engine's licence restricts its outputs (for example Coqui XTTS-v2 or Higgs v3) and no signed decision covers it
- **THEN** its takes may be used for internal reference only, and the `verify` stage fails if one is in the shipped bank

#### Scenario: Credit line
- **WHEN** a shipped clip comes from an engine whose licence asks for a credit (for example "Built with Fish Audio")
- **THEN** the credits and the README carry that line, generated from the manifest

#### Scenario: Model not admitted
- **WHEN** a batch asks for a model that the studio has not admitted
- **THEN** the batch stops with the studio's consent or admission answer, and nothing is downloaded without the operator's token

#### Scenario: Pinned runtime code
- **WHEN** the capability loads an engine
- **THEN** it runs the code commit and weight revision pinned in `plan/model-pins-voice.md` for that engine, and a dependency the engine would fetch on its own (Dia's DAC codec, Higgs's `bosonai/hubert_base`, VoxCPM's optional denoiser) is either pinned there or switched off

#### Scenario: An engine larger than the GPU's headroom
- **WHEN** Fish S2-Pro runs on the 24 GB RTX A5000
- **THEN** it runs in a 4-bit quantisation that works on Ampere (NF4), alone on the GPU with every other model unloaded before and after, as change `voice-direction` specifies
