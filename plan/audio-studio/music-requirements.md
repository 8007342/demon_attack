# Demon Attack music and voice requirements

Status: draft for the operator and the host session, 2026-11-14.

This document says what Demon Attack needs from music and voice production. It
names use cases and the exact asset contract the game consumes. It does not
name tools. The host (Tillandsias) provides **generic** capabilities (generic
API endpoints and MCP services usable by any project); this project keeps its
own workflows, scores, specs and exporters. Section 6 lists the generic
capabilities these use cases need.

## 1. Why this exists

On 2026-11-14 the operator rejected every music asset produced so far: the
in-game adaptive score, 27 campaign takes, and an A/B of the ACE-Step turbo
and base models at 80 and 256 kbps. Their verdict: "quite bad", thin, too
simple, not our battle-metal theme, and sounding like low-bitrate audio. The
radio voices also sound low-res.

Measured causes:

- Music came from ACE-Step 1.5 XL turbo (8 steps). Its top end above 8 kHz
  is a flat noise floor, not instrument detail. More steps (base model) and a
  higher bitrate did not fix it by ear.
- The adaptive layers were generated or sliced separately, so they never
  sound like one full mix. The shipped stems peak around -6 to -7 dBFS.
- The voices come from a 24 kHz model, so nothing exists above 12 kHz
  (-65 dB), which sounds like a phone.
- Not the cause: the master limiter. Even with tier 4, dive layers and the
  power layer stacked at Full volume, only about 2% of frames reach its
  threshold.

The lesson for the tooling: production needs **iterative refinement with
local models through configurable pipelines**, the way ComfyUI fixed the
kumbia project's art. Every quality call is made by ear, by the operator, in
a studio window beside the agent.

## 2. Quality bar

- **Genre and identity:** battle metal with a recurring campaign theme that
  is recognisable in every level, the menu and the ending. Real high-gain
  rhythm guitars, tight metal drums, bass, leads and harmonies, plus epic
  layers (choir, organ, brass, bells) where a level calls for them.
- **Fidelity:** full-band 48 kHz stereo masters with real detail up to
  16 kHz and beyond. Shipped encodes must stay transparent for dense
  distorted guitars (see A4).
- **Coherence:** every adaptive layer of a level is cut from **one
  arrangement and one mix**, so any combination the game plays sounds like the
  same band in the same room.
- **Acceptance:** the operator approves by listening. Measurements screen out
  bad takes early; they never stand in for approval.

## 3. Use cases

Each use case is something the agent and the operator must be able to do
repeatedly, on local hardware, with every step reproducible from committed
files.

- **UC1, compose and arrange.** Write and edit the campaign as symbolic music
  (MIDI or an equivalent score): the shared theme, per-level riffs,
  progressions, sections, and intensity variations. Transpose, change tempo,
  rearrange sections, double or harmonise parts, and humanise timing and
  velocity. The source of truth is committed scores (today:
  `tools/music_motifs.py`, `art/music/campaign.json`, `web/audio/midi/`).
- **UC2, render with real instruments.** Turn each part into audio with
  sampled or modelled instruments: drum kit, bass, DI guitars through amp
  and cabinet models, orchestra, choir, organ, bells. Each part renders to
  its own stem, sample-accurate on the bar grid.
- **UC3, generative enrichment.** Use local generative models where they
  help: audio-to-audio over a rendered demo, regenerating or extending one
  section, and text-to-music for sketches. The output must stay
  bar-aligned with the score so it can be mixed and sliced.
- **UC4, mix and master.** Multitrack mixing with per-track and bus
  processing: gain, pan, EQ, compression, saturation, reverb, delay,
  sidechain, automation. Then mastering to a loudness target, with an
  optional reference track. Output both the full mix and processed stems
  (each stem through the master bus) so stems sum back to the mix.
- **UC5, export the adaptive set.** From one arrangement and mix, cut the
  exact set of cues the game needs (section 4): loops with seamless loop
  points, tails, intros and outros, dive layers, the power layer and accent
  sprites. Encode them and write the manifest.
- **UC6, audition and iterate.** The operator opens the pipeline in a
  window, plays any node's output, A/Bs two nodes or a node against a
  reference, loops a region, solos and mutes tracks, and sees waveform and
  spectrum. They change one parameter and re-render only what depends on it.
  Notes go into the project's review notes (`/studio`, `page_notes.dart`).
- **UC7, screen automatically.** Before the operator listens: loudness
  (EBU R128 integrated, short-term, true peak), clipping, clicks and glitches,
  bandwidth (energy above 12 and 16 kHz), loop-seam continuity, tempo and key
  checks against the score, and a learned aesthetics score. Takes that fail
  are rejected with a reason.
- **UC8, voices.** Produce the radio bank: 574 short lines (385 human,
  189 demon), with per-character voices cloned from references, emotion
  control, 48 kHz output, demon creature processing (growl, pitch, formant,
  saturation), measured mouth timing for lip-sync, loudness-matched to the
  bank target.
- **UC9, reproduce and trace.** Every output carries provenance: pipeline,
  node parameters, seeds, model files and hashes, input hashes, tool
  versions. Re-running a committed pipeline with the same inputs gives the
  same output, or the provenance says why not.
- **UC10, batch and resume.** Run long batches (all levels, all takes, the
  whole voice bank) one GPU job at a time, with tickets that survive an agent
  or forge restart. Resume from the first unfinished job, and checkpoint
  results to git as they complete.

## 4. The game's asset contract (what UC5 must produce)

The runtime is `web/audio/demon-audio.js`, reading
`web/audio/music/manifest.json`. These are hard constraints today; changing
them is a game change, made in this repo.

### 4.1 Grid, format, loudness

- Sample rate 48 kHz, stereo. Each level has its own tempo, defined as an
  integer number of samples per bar (4/4):

  | Level | Name | BPM | barSamples | Key |
  |---|---|---|---|---|
  | 1 | Krybor | ~170 | 67765 | E minor |
  | 2 | Ringfall | 160 | 72000 | D major |
  | 3 | Ember Moon | 180 | 64000 | E minor |
  | 4 | The Hollow | 150 | 76800 | C minor |
  | 5 | The Carrier | ~190 | 60632 | F minor |
  | menu, marches, alien win | | 120 | 96000 | |

- Loops start and end on bar lines, and their length is a whole number of
  bars of that grid.
- Loudness: recorded cues are mastered to -18 to -19 LUFS integrated; the
  engine applies fixed gains (file 0.7, master 0.65, player Full +6 dB, Low
  -4 dB) and a safety limiter at -1.5 dBFS.
- Encodings shipped: Opus in Ogg (primary) and AAC in M4A (fallback),
  48 kHz, with byte sizes and sha256 in the manifest. The bitrate must be
  high enough that dense distorted guitars stay transparent (to be set by
  listening; today about 80 kbps, which is too low).

### 4.2 Cues per level `l<n>` (n = 1..5)

| Cue | Kind | What it is |
|---|---|---|
| `l<n>-intro` | tail | plays once when the level starts, then hands over; has a short loop tail (`loopStart`/`loopEnd`) |
| `l<n>-t1` .. `l<n>-t4` | loop | four intensity tiers of **the same riff and bar structure** (calm to peril), so a tier change keeps the loop position |
| `l<n>-outro` | loop | travel music after the level |
| `l<n>-layers` | sprite | six bar-aligned dive layers, `slotBeats` 8 each: `stab`, `swell`, `fill`, `gallop`, `lead`, `low`; they compose over the playing tier, at most a few at once |
| `l<n>-power` | loop | power-up layer (today: the percussive band above 3 kHz of tier 4), on while a power-up is active or a pickup is falling |
| `l<n>-accents` | sprite | eight 1.5 s stingers: `dive`, `laststand`, `hatch`, `reinforce`, `breakthrough`, `destroyed`, `gloat`, `respawn`, quantised to the level's grid |

Global cues: `menu` (loop), `levelclear` and `levelclear-fleet` (tails),
`finale` and `finale-fleet` (tails), `victory` (tail), `cackle` (one-shot),
`alienwin` (loop).

### 4.3 Campaign form (target for the new score)

- One theme across the campaign: scale degrees 1-3-5-4, rhythm 1.5-0.5-1-1
  beats, developed per level (the per-level themes and progressions are in
  `art/music/campaign.json` and the riff summaries in the manifest `motifs`).
- Each level's full arrangement is 96 bars in six sections: opening 8,
  theme A 24, answer B 16, contrast C 16, developed recap 24, outgoing 8.
  The tiers, layers and accents are cut from it (UC5).
- Bridges between levels (32 s, a pivot chord sequence each), an ending (warm
  resolution in F major, ~100 s) and a menu overture (~96 s).
- Level characters: L1 rebellious galloping battle metal; L2 heroic power
  metal with twin harmonies and brass; L3 fiery galloping battle metal; L4
  ominous doom with bells and war-march drums; L5 apocalyptic blackened power
  metal with tremolo, blast beats and organ, the campaign climax.

### 4.4 Runtime rules that constrain the music

- Music level is constant: speech never ducks it, effects never sidechain it
  (operator ruling). The mix must leave room for radio voices without ducking.
- Radio airtime is paced to about 15 to 25 percent; the score carries the game.

### 4.5 Voices (UC8)

- 574 clips listed in `web/audio/comms/manifest.json`, built from
  `art/comms/audio.json`. Today: Opus 48 kbps mono, -18 LUFS-class targets,
  mouth-timing data per clip.
- Target: 48 kHz output with full bandwidth, expressive delivery per emotion,
  and demon voices with real growl and creature character.

## 5. Constraints

- **Licences:** everything shipped must allow commercial use and
  redistribution in an open-source game. CC0, CC-BY (credited in
  `assets/credits.json`), MIT, Apache-2.0 and similar are fine. No CC-BY-SA
  or non-commercial sample libraries; no non-commercial models for shipped
  audio. Tool licences (GPL, LGPL) do not reach rendered audio. Demucs-class
  separation is allowed **for internal analysis and reference only**
  (operator acknowledgement, 2026-11-14); separated audio never ships.
- **Hardware:** one 24 GB GPU (RTX A5000), shared one job at a time; CPU work
  in parallel. A bigger or cloud GPU is an operator decision (cost).
- **Storage:** large raws and stems live in a persistent workspace
  (`~/.cache` under the forge), not in the repo or the RAM-backed checkout;
  only masters chosen by the operator and the shipped encodes are committed.
- **Admission:** every model and node is pinned and licence-admitted by the
  host; nothing bypasses admission.

## 6. Generic capabilities requested from the host

Written as capability families, not products. Each should be reachable as a
headless API (with tickets and provenance, like `studio.queue_workflow`) and
as MCP tools, and usable by any project.

1. **Pipeline engine:** node graphs saved as JSON in the project, run
   headless or in an operator-visible window; per-node caching so a change
   re-renders only downstream nodes; seeds; per-output provenance (UC6, UC9).
2. **Symbolic I/O and transforms:** read and write MIDI; transpose, tempo
   map, section splice, humanise, part extraction (UC1).
3. **Instrument rendering:** SFZ/SF2 samplers, drum samplers, amp and
   cabinet modelling (NAM-class plus impulse responses), plugin hosting for
   open instrument plugins; one stem per part on a sample grid (UC2).
4. **Generative audio:** the best admitted local music models for
   audio-to-audio, repaint/extend a time range, and text-to-music; long
   outputs (several minutes) (UC3).
5. **Mix and master:** multitrack bus graph, standard processors, automation,
   loudness-targeted mastering with optional reference, stem rendering
   through the master bus (UC4).
6. **Slicing and export:** cut regions on a bar grid, make seamless loops
   with crossfaded seams, assemble sprites with slot metadata, encode to
   Opus/AAC at given bitrates, and emit a manifest fragment (sizes, hashes,
   loop points) that a project-side exporter maps onto its own schema (UC5).
7. **Analysis and screening:** R128 loudness and true peak, clipping,
   click/glitch detection, bandwidth, spectrum and waveform images, tempo,
   beat and key, loop-seam similarity, learned aesthetics scores (UC7).
8. **Separation:** source separation for analysis and reference (internal
   use) (UC7).
9. **Voices:** expressive TTS at 48 kHz with cloning from references and
   emotion control, voice conversion, creature processing, and bandwidth
   extension for legacy clips (UC8).
10. **Audition UI:** players on every node, A/B against a node or a
    reference, loop regions, solo and mute, waveform and spectrogram (UC6).
11. **Jobs:** a GPU queue (one job at a time), CPU workers, tickets that
    survive restarts, batch submission and resume (UC10).

The project side then owns: the scores, the pipelines (committed workflow
JSON), the exporter that maps generic outputs onto
`web/audio/music/manifest.json`, the voice specs, and the acceptance notes.

## 7. First pilot (proposed)

1. One level (L3 Ember Moon, 180 BPM, E minor): finalise its 96-bar score
   from the motif and progression.
2. Render it through the real-instrument chain into stems; mix and master.
3. Screen it (UC7), then the operator auditions the full mix in the studio
   against the current in-game score.
4. Only after approval: cut the adaptive set (UC5), wire it into the game on
   a work branch, and play it in context.
5. Then the theme across all levels, bridges, menu and ending; then voices.
