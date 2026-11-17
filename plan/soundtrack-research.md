# Soundtrack research: one run as one long song (adaptive-soundtrack)

Status: research for `openspec/changes/adaptive-soundtrack`, 2026-11-17. Decisions are in that change's `design.md`;
this file keeps the evidence and its sources (CLAUDE.md §8). Repo facts name the file they come from. Claims that
could not be read are marked `[UNSOURCED: plan/provenance-audit.md#<id>]` (Part S of the audit).

The brief, from the operator (`plan/operator-feedback-2026-11-16.md`):

- "with the dynamic smooth transitioning soundtrack that we're also planning, one whole run of the game should feel
  like one smooth play of a long song with a game to match ;) and it's all about the boss fights";
- "doom and epic-metal undertones over the battle-metal score" for the carrier;
- "Don't just re-render, remember we're redesigning, so make sure we research the tools and ensure the pipelines
  convey …".

What failed before (`plan/audio-studio/music-requirements.md` §1, `plan/audio-backend.md`): 27 campaign takes and
the adaptive score were rejected on 2026-11-14 as thin, too simple and low-bitrate-sounding; the tiers were separate
takes of one style rather than one arrangement; above 8 kHz the turbo takes had a noise floor instead of detail.

## 1. Adaptive music architecture

### 1.1 The two families, and what engines call them

| Id | Finding | Source |
|---|---|---|
| A1 | **Horizontal re-sequencing**: clips plus a transition table. A transition can leave the current clip immediately, on the next beat, on the next bar, or at its end; it can enter the destination at its start, at the same position, or at the position it last left; it can fade in, out, cross or not at all; it can pass through a filler clip; a clip can auto-advance to a named next clip. | [source: Godot Engine, "AudioStreamInteractive" class reference, https://raw.githubusercontent.com/godotengine/godot/master/modules/interactive_music/doc_classes/AudioStreamInteractive.xml, read 2026-11-17] |
| A2 | **Vertical layering**: sub-streams that start together, play in sync, and are mixed by per-stream volume. | [source: Godot Engine, "AudioStreamSynchronized" class reference, https://raw.githubusercontent.com/godotengine/godot/master/modules/interactive_music/doc_classes/AudioStreamSynchronized.xml, read 2026-11-17] |
| A3 | **Branching on game state** is old practice: iMUSE's music database holds decision points that form "a composing decision tree", evaluated as the game runs. | [source: Michael Z. Land & Peter N. McConnell, US5315057A, https://patents.google.com/patent/US5315057A/en, read 2026-11-16 by the carrier-hatches research, `plan/carrier-hatches-research.md` M3] |
| A4 | **Parameter-driven transitions with quantisation** in FMOD Studio: a destination marker names where a section starts; a transition region carries a condition on a parameter (e.g. `Section`); its quantisation sets the points where the playhead may jump; a "magnet" region jumps at once. | [source: SGG-Modding, "Adding Dynamic Music", Hades 2 Mod Wiki, https://sgg-modding.github.io/Hades2ModWiki/docs/creating-mods/audio/adding-dynamic-music, read 2026-11-17]. A practitioner guide, not FMOD's manual: fmod.com reset the connection from the forge. [source: Firelight Technologies, "FMOD Studio User Manual 2.02, Authoring Events", https://d1s9dnlmdewoh1.cloudfront.net/2.02/studio/authoring-events.html, unread: snippet only] |
| A5 | **Wwise** music switch containers move between segments by transition rules (exit the source at a cue, bar or beat; sync the destination to its entry cue or the same time; optional transition segments) and play stingers over the music. | [source: Audiokinetic, "Understanding Music Switch Containers", https://www.audiokinetic.com/en/public-library/2024.1.0_8669/?source=Help&id=understanding_music_switch_containers, unread: connection reset]; community answers describe the default as "waits until the exit cue" [source: Audiokinetic Community Q&A, "interactive custom transitions trigger before activated", https://www.audiokinetic.com/qa/1068/interactive-custom-transitions-trigger-before-activated, unread: snippet only] `[UNSOURCED: plan/provenance-audit.md#soundtrack-wwise]` |

**What this means for us.** All three engines converge on one model: **sections** (clips, segments) joined by a
**transition table** keyed on game state, quantised to the music's grid, with **filler/transition clips** for
moves that need a bridge, **layers** synced inside a section, and **stingers** on top. The game sets a parameter
or fires an event; the music decides when, on its own grid, to move. The game never waits for the music (the
carrier-hatches design already says so, §A8).

### 1.2 Which one for Demon Attack

- **Vertical layering needs stems that sum to one mix.** ComfyUI's core ACE-Step nodes return one stereo mix (§2.3),
  separated audio may not ship (`music-requirements.md` §5: Demucs-class separation is internal-only), and ACE's own
  `extract` and `lego` tasks are not reachable through core nodes (§2.3). So full vertical layering of generated
  music is **blocked until #1103** (SFZ stems) or until ACE's masked tasks are exposed by admitted nodes.
- **Horizontal re-sequencing works with one mix per section.** Every section is a whole-bar file on one grid, and
  the engine moves on bar lines. It is what the carrier-hatches design asked for (`bossHatchTier` is "a section
  change", `bossTransform` "the bridge").
- **"Same position" switching** between intensity variants of a section (the existing `t1`–`t4`) is horizontal
  re-sequencing too (A1, `SAME_POSITION`), and needs only variants that share bar structure.
- **Thin vertical layers we can make honestly now:** stingers (accents), the existing dive layers and power layer
  (cut by HPSS from our *own* generated mixes, `plan/audio-backend.md` "Stems"), and procedural or sampled layers
  generated on the grid (a drum bed that intensifies, a riser).

**Decision (design §2): a hybrid.** Horizontal re-sequencing between sections on bar lines is the backbone;
"same-position" variants carry intensity inside a section; a thin layer set (stingers, dive and power layers, later
#1103's sampled drum and bass beds) sits on top.

### 1.3 Song form and harmony across a run

Repo facts this builds on: the world keys and tempos (`plan/campaign-composition.md`: Krybor E minor 170, Ringfall D
major 160, Ember Moon E minor 180, The Hollow C minor 150, Carrier F minor 190), the integer bar grids
(`tools/music_motifs.py` `BAR_SAMPLES`), the four-note campaign theme (degrees 1-3-5-4, rhythm 1.5-0.5-1-1), the
bridge pivots, and the run's shape (`plan/game-design.md`: five routes, each four sectors and a carrier; a seeded
bonus level may replace one sector 2–4; the fifth carrier ends the campaign).

Harmonic observations (music theory, our own reasoning, no outside claim):

- The Hollow (C minor) is the dominant's key of the carrier's F minor, so every route's last sector leans into the
  boss as V → i. That is the strongest approach a key plan can give, and it is already in the map.
- The carrier's victory can turn F minor into **F major** (the same tonic), a bright release without a key jump.
- The ending's ukulele can then stay in **F major**, at **95 BPM**, half the carrier's tempo (the carrier grid's bar
  doubled: 121 264 samples), so the handoff keeps both tonic and pulse. `plan/campaign-composition.md` already plans
  the warm F-major reprise at 96 BPM; 95 is the same idea locked to the grid.
- After a carrier victory, travel to the next route's Krybor (E minor) is a semitone drop; a pivot F → C → B7 → Em
  (C is V of F and VI of E minor) fits the existing bridge pattern.

### 1.4 How long the song is

At the campaign's tempos a 96-bar arrangement lasts 121–154 s (`plan/campaign-composition.md`). A sector lasts
longer than that in play, so sections must loop without the loop being heard: several loopable sections per world
(A, B, C …) visited in order by wave, plus intensity variants, rather than one 8-bar loop
(`plan/battle-metal-radio-production.md`: "merely increasing generation duration … would still ship short loops").

## 2. ACE-Step 1.5: what it can and cannot do

### 2.1 Upstream facts

| Id | Finding | Source |
|---|---|---|
| S1 | Generates 10 s to 10 min; text-to-music, cover, repaint; `lego`, `extract`, `complete` only on the **base** models (incl. XL base); XL needs ≥ 12 GB with offload, ≥ 20 GB recommended; the repo is MIT. | [source: ACE-Step, "ACE-Step 1.5" README, https://github.com/ace-step/ACE-Step-1.5, read 2026-11-17]; [source: ACE-Step, LICENSE, https://raw.githubusercontent.com/ace-step/ACE-Step-1.5/main/LICENSE, read 2026-11-17] |
| S2 | Structure tags in the lyrics: `[Intro]`, `[Verse]`, `[Pre-Chorus]`, `[Chorus]`, `[Bridge]`, `[Outro]`, `[Build]`, `[Drop]`, `[Breakdown]`, `[Instrumental]`, `[Guitar Solo]`, descriptors after a hyphen (`[Chorus - anthemic]`); don't stack many tags. Instrumental: lyrics `[Instrumental]`. BPM 30–300, key, time signature and duration are **guidance, not commands** ("120 BPM might come out as 118 or 122"); 60–180 BPM works well; 4/4 most reliable; 30–60 s and 2–4 min durations are stable, very long outputs may repeat. Repaint takes `repainting_start`/`_end` (3–90 s) with a source audio; repeated repaints extend; repaint "can also smooth the join between two audio clips". `reference_audio` steers timbre and mix, not melody or structure. | [source: ACE-Step, "Tutorial" (docs/en/Tutorial.md), https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/Tutorial.md, read 2026-11-17] |
| S3 | Track names for `lego`/`extract`: vocals, backing_vocals, drums, bass, guitar, keyboard, percussion, strings, synth, fx, brass, woodwinds. `audio_cover_strength` 0–1. Turbo 8 steps (1–20), base 32–64; output 48 kHz, FLAC by default; batch 1–8. No word on loops. | [source: ACE-Step, "INFERENCE" (docs/en/INFERENCE.md), https://github.com/ace-step/ACE-Step-1.5/blob/main/docs/en/INFERENCE.md, read 2026-11-17] |
| S4 | XL SFT: ~4 B DiT, 18.8 GB bf16, 50 steps with CFG, "highest quality", MIT; tasks "Standard" (no extract/lego/complete). XL base: "All (extract, lego, complete)". Commercial use of output allowed; trained on licensed, royalty-free/public-domain and synthetic data. | [source: ACE-Step, "acestep-v15-xl-sft" model card, https://huggingface.co/ACE-Step/acestep-v15-xl-sft, read 2026-11-17]; licence field `mit` on `ACE-Step/acestep-v15-xl-sft` and `-xl-base` via the Hugging Face API, read 2026-11-17 |
| S5 | The technical report: an LM plans a song blueprint (BPM, key, duration, structure) in YAML, a DiT renders it; repaint is masked segment regeneration; cover keeps melody and rhythm through quantised latents; extraction and layering were trained on stem-separated tracks. | [source: Song et al. (ACE Studio), "ACE-Step 1.5: Pushing the Boundaries of Open-Source Music Generation", arXiv 2602.00744, via https://huggingface.co/papers/2602.00744, read 2026-11-17]. arxiv.org reset the connection; the abstract was read on Hugging Face's paper page. |
| S6 | Comfy-Org's repackaged weights (the ones our studio pins) are listed under `apache-2.0`; upstream says MIT. Both are permissive; the licence register should name the upstream MIT. | [source: Comfy-Org, "ACE-Step-1.5" (Hugging Face API), https://huggingface.co/api/models/Comfy-Org/ACE-Step-1.5, read 2026-11-17] |

### 2.2 What ComfyUI's core nodes expose (the studio's ComfyUI 0.40.0)

Read from the running studio (`/object_info`, 2026-11-17) and from ComfyUI's source:

- `TextEncodeAceStepAudio1.5`: tags, lyrics, seed, bpm (int 10–300), duration, timesignature (2/3/4/6), language,
  keyscale (major/minor on 17 roots), `generate_audio_codes` (the LM, "slow but will increase the quality"; turn off
  with a reference), cfg_scale, temperature, top_p/k, min_p.
- `EmptyAceStep1.5LatentAudio`: seconds (1–1000). The latent runs at **25 frames per second** (48 000 / 1920); the
  text encoder's `duration` is not linked to it, so both must be set.
  [source: comfyanonymous, "nodes_ace.py", https://raw.githubusercontent.com/comfyanonymous/ComfyUI/master/comfy_extras/nodes_ace.py, read 2026-11-17]
- `ReferenceTimbreAudio` ("Set Reference Audio"): appends a VAE latent to the conditioning. In the model wrapper a
  reference switches the model to **cover** mode: the reference is tokenised to 5 Hz codes that become the
  structure hint. Without a reference and without LM codes the context is silence (plain text-to-music).
  **`chunk_masks` is always all ones**: the core integration never masks a region, so **ACE's own repaint, lego,
  extract and complete are not reachable** through core nodes.
  [source: comfyanonymous, "ace_step15.py", https://raw.githubusercontent.com/comfyanonymous/ComfyUI/master/comfy/ldm/ace/ace_step15.py, read 2026-11-17];
  [source: comfyanonymous, "model_base.py" (`ACEStep15.extra_conds`), https://raw.githubusercontent.com/comfyanonymous/ComfyUI/master/comfy/model_base.py, read 2026-11-17]
- Generic nodes present: `VAEEncodeAudio`/`VAEDecodeAudio(Tiled)`, `AudioConcat`, `AudioMerge` (add/mean/…),
  `TrimAudioDuration`, `AudioAdjustVolume`, `AudioEqualizer3Band`, `SaveAudio` (FLAC), `SaveAudioOpus`/`Advanced`
  (64–320 kbps), `SetLatentNoiseMask`, `LatentConcat`/`LatentCut`. A generic latent noise mask is a sampler-side
  blend, not ACE's trained repaint; whether it works on 1-D audio latents is untested (pilot follow-up P5).

### 2.3 Capability matrix for our purposes

| Need | Core nodes now | Needs #1103 or new nodes |
|---|---|---|
| Text-to-music, instrumental, structure tags, key, tempo, 10 s–10 min | yes (`campaign-text-headroom.json` + overrides) | — |
| Tempo locked to a grid | yes, by measurement and gating; the half-tempo `bpm` trick locks 190 (pilot: 21 of 28 section takes within 0.15 %) | — |
| Same arrangement in two intensities | partly: cover mode (`ReferenceTimbreAudio`) re-performs a take; earlier rounds found it drifts off the pulse past denoise ≈ 0.55 (`plan/audio-backend.md` metal-v2 table) | ACE `repaint`/`lego` with masks |
| Sections that join (repaint across a seam, extend) | no (chunk masks fixed) — joins are made by bar-line cuts and DSP crossfades | ACE `repaint` (custom node; not to be built in-forge) |
| Stems (drums, bass, guitars …) | no | SFZ renders (Karoryfer, VCSL) through #1103's nodes; ACE `extract` (base) via new nodes |
| Highest quality model | XL turbo and XL base on disk | XL SFT (#1103) |
| Loudness, slicing, seams, Opus | outside ComfyUI: ffmpeg + `tools/soundtrack_check` (Go) | #1103's generic audio nodes would move these into the graph |
| Ukulele bars of the theme | text-to-music can be asked (untested) | sampled ukulele if a CC0 library has one (VCSL contents unverified `[UNSOURCED: plan/provenance-audit.md#soundtrack-vcsl-ukulele]`) |

### 2.4 Measured in the pilot (2026-11-17, `plan/render-runs/soundtrack-pilot.md`)

- 28 section takes (7 sections × 4 seeds, XL turbo, 40 s) took about 6 s of GPU each; two 150 s structured takes
  about 22 s each; two XL base takes (32 steps) 11–16 s.
- Tempo: asked as `bpm` 95 with "190 bpm" in the tags, 21 of 28 section takes measured within 0.15 % of the
  189.9987 BPM grid; the rest were 0.9–2.1 % off and were rejected. One of two base takes drifted 3.3 %.
- Key: F minor ranked first in 23 of 24 F-minor section takes (the 24th ranked it second, behind its relative A♭ major) (Krumhansl profile on a chroma sum); the victory sting asked
  in F major came back F major in 2 of 4, C major (its dominant) in 2.
- Air: energy above 16 kHz ranged from −35 to −64 dB below the total on section takes; 9 of 28 are more than 60 dB
  down there, the "no air" sound the operator called low-bitrate. The checker flags it; picks favour the takes with
  air.
- Structure tags in a 150 s take produced an audible-on-paper arc: per-bar RMS shows a 15-bar quiet intro, a main
  body, an 8-bar breakdown, a climax and a 7-bar fade (seed 7302). Whether it sounds like the tagged sections is a
  listening question.

## 3. The web runtime

| Id | Finding | Source |
|---|---|---|
| W1 | `AudioBufferSourceNode` plays once; nodes are cheap, buffers reusable; `loop`, `loopStart`, `loopEnd` loop inside a buffer; it suits "sounds that must match a specific rhythm and can be kept in memory"; for accurately timed audio that must be **streamed**, use an `AudioWorkletNode`. | [source: Mozilla, "AudioBufferSourceNode", MDN, https://developer.mozilla.org/en-US/docs/Web/API/AudioBufferSourceNode, read 2026-11-17] |
| W2 | An `AudioBuffer` holds 32-bit float linear PCM; "it would be expected that the length of the PCM data would be fairly short (usually somewhat less than a minute)"; longer sounds should stream through `<audio>` and `MediaElementAudioSourceNode`. `currentTime` is the time of the next block to be processed. `decodeAudioData` resamples to the context's rate. | [source: W3C, "Web Audio API 1.1", Working Draft 22 September 2026, https://www.w3.org/TR/webaudio/, read 2026-11-17] |
| W3 | Safari 18.4+ (macOS 15.4+, iOS 18.4+, iPadOS 18.4+) added Opus and Vorbis in Ogg. | [source: acdha / MDN, "Record Safari 18.4+ support for Opus in Ogg containers" (mdn/content PR 39592), https://github.com/mdn/content/pull/39592, read 2026-11-17] |
| W4 | WebM Opus through `decodeAudioData` on iOS from Safari 17.4. | [source: WebKit Bugzilla 238546, https://bugs.webkit.org/show_bug.cgi?id=238546, unread: snippet only] `[UNSOURCED: plan/provenance-audit.md#soundtrack-webm-opus-ios]` |
| W5 | Ogg Opus carries a pre-skip and end trimming in its granule positions, so a decoder can return the exact original sample count (gapless). | [source: Terriberry, Lee, Giles, "Ogg Encapsulation for the Opus Audio Codec", RFC 7845, https://www.rfc-editor.org/rfc/rfc7845.html, unread: connection reset] `[UNSOURCED: plan/provenance-audit.md#soundtrack-opus-gapless]`. Measured instead: our pilot loops decode with ffmpeg to exactly 8 × 60 632 samples. Browser decoders still need the same check (pilot task P3). |
| W6 | The "two clocks" pattern: a JS timer wakes often and schedules audio a little ahead on the audio clock. | [source: Chris Wilson, "A tale of two clocks", web.dev, https://web.dev/articles/audio-scheduling, unread: connection reset] `[UNSOURCED: plan/provenance-audit.md#soundtrack-two-clocks]`. Our `web/audio/demon-audio.js` already does this (25 ms timer, 120 ms lookahead). |

**Memory arithmetic** (our own): decoded stereo float32 at 48 kHz is 384 KB per second. An 8-bar loop at 190 BPM
(10.1 s) is 3.9 MB decoded and about 200 KB as 160 kbps Opus. The pilot's seven carrier sections (73 s) decode to
about 28 MB. A whole route held decoded at once would be several hundred MB, so the runtime must hold only the
current song's reachable sections (design §5.4).

**Formats.** Opus in Ogg at 160 kbps for music (the 80 kbps of the rejected round was "too low",
`music-requirements.md` §4.1). Older iPhones (before iOS 18.4) cannot decode Ogg Opus (W3); the
`battle-metal-radio-rework` spec says AAC fallback is not required. That is an operator decision to confirm
(needs list N6), since the existing runtime still ships `.m4a`.

> **No fallback format (operator, 2026-11-17).** Opus (`.ogg`) is the one shipped audio format: the AAC (`.m4a`) twins were deleted from `web/audio/`, and `tools/music_pipeline.py` and `tools/comms_pipeline.py` no longer encode AAC. A browser that cannot decode Ogg Opus (Safari before 18.4) plays the MIDI score through the synthesizer (`web/audio/demon-score.js`, the MIDI fallback in `demon-audio.js`).

## 4. The pipeline

### 4.1 What exists

- `tools/music_pipeline.py` (numpy + scipy + ffmpeg): text and a2a generation through ComfyUI, tempo gate, window
  pick, seams, HPSS stems, encode, manifest. It needs a Python venv with scipy; the forge prefers Go/Lua
  (CLAUDE.md §9).
- `art/workflows/music/`: `acestep15-cue.json`, `campaign-text-headroom.json` (+ an 8 dB trim before save), a2a
  variants, and `l3-ember-moon-*.json`, which use `Tillandsias*` nodes (MIDI, SFZ render, EQ, compressor,
  saturate, pan, loop WAV) — the #1103 pack, not installed in the studio today.
- Host tools: `studio.run_workflow`/`queue_workflow` (overrides reach any node input as `$node:<id>.<input>`),
  `audio.detect_glitches` (click, dropout, spectral hole, clipping, loop seam) and `audio.transform` (loudness,
  stretch, Opus, AAC). On 2026-11-17 both audio tools refused to run: the tray app (56.11.15.5) is older than the
  enclave images (56.11.16.6). Needs list N3.

### 4.2 What the pilot added (core nodes only)

- `tools/soundtrack_check` (Go, ffmpeg only): `analyze` (tempo fit near the grid, downbeat phase, key with rank of
  the asked key, energy above 12/16 kHz, EBU R128 loudness and true peak, per-bar RMS, a gate),
  `cut` (resample to the exact grid, pick a loop, bridge or tail window on bar lines, borrow the take's own
  continuation for a 120 ms loop seam), `check` (wrap step and wrap flux against the loop's own bar lines, clicks,
  clipping, whole bars).
- `tools/soundtrack_pilot.lua`: ingest studio outputs to `~/.cache/tillandsias-project/soundtrack-pilot`, analyse,
  cut, and encode (two-pass linear loudnorm to −19 LUFS, true peak ≤ −1.5 dBTP, Opus 160 kbps).
- `art/music/soundtrack/pilot-carrier-t1.json`: the recipe (sections, tags, seeds, overrides).

### 4.3 What only #1103 unlocks

XL SFT; SFZ instrument stems (drums, bass, guitars through the pack's EQ/compressor/saturation chain) for true
vertical layers and an intensifiable drum and bass bed; the pack's slicing and transition nodes; and, if the pack
exposes ACE's masked tasks, repaint across seams. Everything else in the design runs on core nodes and CPU tools.

## 5. Sources not reachable from the forge (2026-11-17)

fmod.com, audiokinetic.com, web.dev, arxiv.org, rfc-editor.org and ffmpeg.org reset the connection. Nothing was
routed around the proxy. Their claims are marked above and listed in `plan/provenance-audit.md` Part S.
