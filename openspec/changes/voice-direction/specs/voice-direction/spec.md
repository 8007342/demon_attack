# Voice direction

## ADDED Requirements

### Requirement: Emotion beats inside a line
A line in `art/comms/lines.json` MAY carry `beats`: an ordered list that splits its spoken words into two to four parts, each with its own `emotion` (from the voice-stack list), `intensity` (0–3) and optional `direction`. The words of the beats, joined with single spaces, SHALL equal the line's text with cues removed. The line's own `emotion` SHALL equal the last beat's emotion. The `dart` stage SHALL reject a mismatch and name the clip id.

#### Scenario: A swing inside one line
- **WHEN** a line reads `"Contact low, I can't shake it! Wait, got him! Woohoo!"` with three beats `calm` 1, `panicked` 3 and `triumphant` 3
- **THEN** it validates, the subtitle shows the whole text, and each engine's render request carries the three beats in order (design §4.1)

#### Scenario: Beats that do not match the text
- **WHEN** the beats' words joined do not equal the text without cues
- **THEN** the `dart` stage exits non-zero with `<clip id>: beats do not match text`

#### Scenario: Old lines
- **WHEN** a line has no `beats`
- **THEN** it renders as one beat with the line's emotion and intensity, and the bank is byte-identical to before

### Requirement: Authored banter threads
A trigger MAY carry `threads`: authored exchanges of two to four turns. Each turn SHALL be a full line (human or brood) with an optional `gap` in seconds from the end of the previous turn, from −0.6 (overlap) to 1.5, default 0.15. Clip ids SHALL be `<trigger>.x<n>.<k>` for thread n and turn k, appended and never reordered. A thread SHALL be rendered as one unit, each turn conditioned on the audio of the turn before.

#### Scenario: A three-turn thread
- **WHEN** a trigger has a thread Kessler → Mensah → Kessler with gaps 0.1 and −0.3
- **THEN** the clip ids are `<trigger>.x0.0`, `.x0.1` and `.x0.2`, and the render job sends the three turns together with the first turn's take as context for the second (design §4.2)

#### Scenario: A gap out of range
- **WHEN** a turn has `"gap": -1.2`
- **THEN** the `dart` stage exits non-zero and names the clip id

### Requirement: Threads play as one unit
The comms director SHALL play a thread only when every speaker in it is on the current call, SHALL reserve the channel for the whole thread, and SHALL start each turn at the end of the previous turn plus its `gap`. A thread SHALL NOT be broken up by a lower-priority line. A gameplay-critical `urgent` line MAY cut a thread, and the thread's remaining turns are then dropped.

#### Scenario: Speaker missing
- **WHEN** a thread names Mensah and Mensah is not on this run's lineup
- **THEN** the director skips the thread and may play a single line of the same trigger instead

#### Scenario: Overlap
- **WHEN** turn 2 has `"gap": -0.3`
- **THEN** it starts 0.3 s before turn 1 ends, both voices play, and the subtitles show both turns

#### Scenario: Urgent interrupt
- **WHEN** an `urgent` line fires during turn 2 of a three-turn thread
- **THEN** turn 2 is cut, turn 3 never plays, and the urgent line plays

### Requirement: Layered brood vocals
A brood line SHALL be built from up to three layers, named in the line or defaulted from its `grunt` kind: a `performance` (the speaker's `say`, spoken by the speaker's identity with the line's emotion), a `vocal` (a model-made growl, snarl, roar, hiss, cackle, chitter, grunt or cheer from the cue vocabulary) and the procedural `growl` of the `grunts` stage. Every layer SHALL be rendered clean, kept as a master, and only then sent through the speaker's demon FX chain.

#### Scenario: Default layers
- **WHEN** a brood line has `grunt: "snarl"`, a `say` and no `vocal` field
- **THEN** it renders a performance of the `say` plus a `snarl` vocal from the vocal engine, layered with the procedural growl at the character's committed mix

#### Scenario: Vocal-only line
- **WHEN** a brood line is `"say": "[growl]"`
- **THEN** it renders the vocal and growl layers only, and the card shows the gloss only

#### Scenario: Clean masters kept
- **WHEN** a brood take is picked
- **THEN** its clean performance, clean vocal and transformed mix are all committed under `art/comms/masters/<batch>/`

### Requirement: Demon FX chain per character
Each brood character SHALL have a committed FX chain in `art/comms/demon-delivery.json` (schema v2): an ordered list of steps from a closed set (`reverse`, `pitch`, `formant`, `granular`, `ringmod`, `drive`, `subharmonic`, `eq`, `doubler`) with their parameters. The chain SHALL be deterministic for a given input and seed. Values are listening picks, logged with their reason in the pilot ledger.

#### Scenario: Unknown step
- **WHEN** a chain names a step `vocoder` that is not in the closed set
- **THEN** the pipeline exits non-zero and names the character

#### Scenario: Deterministic chain
- **WHEN** the same clean master is processed twice with the same chain and seed
- **THEN** the two outputs are byte-identical

### Requirement: Wet amount may change inside a brood line
A brood beat MAY carry `voice`: `brood` (full FX chain, the default) or `plain` (no FX). Where two beats differ, the pipeline SHALL crossfade between the processed and clean renders of the same take over 80 to 200 ms at the beat boundary, so a line can start as a demon and finish as the person underneath. A `plain` beat SHALL only be allowed on a line marked `"set": "second"` or in the ending's cinematic lines.

#### Scenario: Growl, then himself
- **WHEN** the cinematic line "A rematch. After a short break." has beats `brood` ("A rematch.") and `plain` ("After a short break.")
- **THEN** the render takes one clean performance, runs the FX chain over it, and crossfades from the processed to the clean signal at the beat boundary

#### Scenario: Plain voice in a first run
- **WHEN** a radio line without `"set": "second"` has a `plain` beat
- **THEN** the `dart` stage exits non-zero: the brood are never heard plainly before the reveal

### Requirement: Brood identities survive the reveal
Each brood character's voice identity SHALL be cast as the restaurant person they turn out to be (`plan/endgame-reveal-ledger.md` §1.3), so the clean performance under the FX chain is the voice the ending plays plainly. A character the ending shows as a child SHALL be voiced plainly only after the operator approves a child voice; until then the ending uses subtitles with laughs and groans for them (`endgame-cinematic` design §12, decision 9).

#### Scenario: Vexxa in the ending
- **WHEN** the ending plays Vexxa's line "Refills for the fleet. On the house."
- **THEN** it is rendered from the same identity that performs her brood lines, with no FX chain and the `room` chain only

#### Scenario: A child's line without approval
- **WHEN** the ending reaches a line spoken by Ulgra, Morth or Nibb and no child-voice approval is recorded in `art/comms/cast.json`
- **THEN** the line shows as a subtitle and plays only its non-verbal cue

### Requirement: Automatic take rejection
Every take SHALL pass automatic checks before anyone listens: the duration within 0.5–2.5× the expected length of its words, no sample at or above −0.5 dBFS, no silence over 0.8 s inside speech, a word error rate under 15 % against the cue-stripped text from the admitted speech recogniser, and a speaker similarity to the identity clip at or above the engine's calibrated threshold. A vocal-only take SHALL show no recognised words. A rejected take SHALL be logged with its reasons and never picked.

#### Scenario: Words in a growl
- **WHEN** the speech recogniser hears "hello" in a take meant to be `[growl]`
- **THEN** the take is rejected with `words in vocal`

#### Scenario: Identity drift
- **WHEN** a take's speaker similarity to `art/comms/voices/<id>.flac` is below the threshold
- **THEN** the take is rejected with `identity` and its score

#### Scenario: No recogniser admitted yet
- **WHEN** no speech recogniser is admitted in the studio
- **THEN** the word and vocal checks are logged as `skipped`, the other checks still run, and the take may reach the listening pass

### Requirement: Take counts per kind
A batch SHALL render at least four takes for a thread, a line with `beats`, a `signature` line or a priority ≥ 8 line; three for other speech lines; and one reel of three to six vocal cues per character and engine with three seeds for vocals. If every take of a line is rejected, the batch SHALL render up to the same number again once, then mark the line `failed` in the ledger.

#### Scenario: All takes rejected
- **WHEN** all four takes of a thread are rejected
- **THEN** four more render with new seeds, and if those fail too the ledger marks the thread `failed` and the batch continues

### Requirement: Picks logged with listening scores
Each pick SHALL be recorded in the batch ledger with the picked take, a one-line reason and the scores from the listening sheet (design §6). The listening pass SHALL be blind to the engine: takes are labelled by a random code until the scores are in.

#### Scenario: Blind pass
- **WHEN** the pilot's listening page is built
- **THEN** each take is labelled by a code, the code-to-engine key sits in the ledger, and the page does not show engine names

### Requirement: Pilot before the bank
Before the bank is re-rendered, a pilot SHALL render the 20 lines and 10 brood vocalisations of design §7 on VoxCPM2 + Dia and on each admitted challenger (Fish Audio S2-Pro, Higgs Audio v2), score them on the listening criteria, and record the engine decision per role (speech, threads, vocals) in the design. Nothing from the pilot ships before its picks are promoted under the voice-stack tier rules.

#### Scenario: A challenger wins threads only
- **WHEN** Higgs v2 wins most thread scores and VoxCPM2 wins most single lines
- **THEN** the design records Higgs v2 for threads and VoxCPM2 for single lines, and `voice-engines.json` gives each engine its role

#### Scenario: A challenger is not admitted
- **WHEN** Fish S2-Pro is not admitted in the studio when the pilot runs
- **THEN** the pilot runs without it, and the ledger records the missing engine and its admission state
