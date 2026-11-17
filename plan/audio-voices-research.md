# Audio voices research: emotion swings, banter and brood vocals (2026-11-17)

Spec: `openspec/changes/voice-direction/`. Builds on `plan/voice-stack-research.md` (engine survey, licences, VRAM)
and `openspec/changes/voice-stack/` (emotion list, cues, tone list, identities, tiers). This file does not repeat them.

Operator, 2026-11-17: "Don't just re-render, remember we're redesigning, so make sure we research the tools and ensure
the pipelines convey the new chatter with full emotion swings and banter, as well as demon growls and grunting for
those low pitch-reversed audio, which might end up as regular grunts from the new models, please research
accordingly."

**Method.** Three research passes on 2026-11-17 fetched model cards, READMEs, docs, example scripts, source files and
GitHub issues through the forge proxy. The fetch tool returns a model-made digest of each page; quoted strings are as
it returned them, so the admission review re-reads any quote that a decision rests on. **Blocked** (connection reset,
not routed around): arxiv.org (abs, html and pdf), speech.fish.audio, fish.audio blog, boson.ai blog,
blog.criware.com, sound-ideas.com. Where an arXiv paper was needed, its Hugging Face Papers page was read instead.
Engine pins are those of `plan/model-pins-voice.md`. Nothing was downloaded, installed or rendered.

## 1. What changes from voice-stack

`voice-stack` gives each line one `emotion`, an `intensity` 0–3, a `direction` note and inline cues. Three things the
operator asked for do not fit in that:

1. **A swing inside a line** ("Contact low, I can't shake it! Wait, got him! Woohoo!"). One emotion label renders
   one mood.
2. **Banter.** Today's `exchange` triggers pick an opener from one side and a random answer from the other
   (`lib/comms/comms_director.dart`, the `exchange` branch); the two takes were rendered apart and never heard each
   other, so the answer cannot pick up the opener's energy.
3. **Brood that emote.** Brood lines are speech performances reversed and pitched down by resampling plus WSOLA
   (`tools/comms_pipeline.py` `stage_radio`, `art/comms/demon-delivery.json`), with a procedural glottal growl
   (`synth_grunt`). Resampling moves pitch and formants together, which reads as a slowed tape, and the reversal
   hides the emotional contour of the words.

## 2. How each engine takes direction

### 2.1 VoxCPM2 (speech; default engine)

- **Style instruction** in parentheses before the text: "The control instruction is written in parentheses before
  the target text", e.g. `(slightly faster, cheerful tone)This is a cloned voice with style control.` [source:
  OpenBMB, "Usage Guide", https://voxcpm.readthedocs.io/en/latest/usage_guide.html, read 2026-11-17] [source:
  OpenBMB, "openbmb/VoxCPM2 README @7936080", https://huggingface.co/openbmb/VoxCPM2/blob/7936080b41163874f38610f46f438e2c0757f9fd/README.md, read 2026-11-17].
  The demo page shows ramps written into the instruction: "Angry tone, volume gradually increased", "Cheerful and
  laughing, as if sharing good news with a close friend", "Confident, energetic male sports commentator, fast-paced,
  building excitement with every word"; it shows no panic example [source: OpenBMB, "VoxCPM2 demo page",
  https://openbmb.github.io/voxcpm2-demopage, read 2026-11-17].
- **Tags** exist only in the cookbook: `[laughing] [sigh] [Uhm] [Shh] [Question-ah/-ei/-en/-oh] [Surprise-wa]
  [Surprise-yo] [Dissatisfaction-hnn]`, with "Stick to the recommended tags and use them sparingly" and "Avoid
  stacking too many tags into a single sentence". No scream, grunt, growl or cheer tag [source: OpenBMB, "A Voice
  Chef's Guide to VoxCPM2 (Cookbook)", https://voxcpm.readthedocs.io/en/latest/cookbook.html, read 2026-11-17].
- **Controls:** `cfg_value` 1.0–3.0, default 2.0; higher means "stronger adherence … more risk of noise or
  artifacts", and "lowering `cfg_value` toward 1.5–1.6 is often more stable"; `inference_timesteps` 4–30, default
  10; `retry_badcase` retries "abnormally short or long" outputs. No temperature or top_p. Very short text may sound
  weak (training minimum about 1 s of audio) [source: OpenBMB, "Usage Guide", above].
- **Cloning modes.** Controllable cloning: "`reference_wav_path` provides the timbre, and the parenthesized
  instruction controls the style". Hi-Fi ("Ultimate") cloning with the reference transcript preserves "timbre,
  rhythm, emotion, and style", and "When Hi-Fi mode is enabled, the control instruction is ignored" [source: OpenBMB,
  "Usage Guide", above] [source: OpenBMB, "VoxCPM README", https://raw.githubusercontent.com/OpenBMB/VoxCPM/main/README.md, read 2026-11-17].
- **Limits:** "Occasional instability may occur with very long or highly expressive inputs"; generate 1–3 times
  [source: OpenBMB, "openbmb/VoxCPM2 README @7936080", above]. No multi-speaker mode in the official docs.
- 48 kHz out, about 8 GB, RTF about 0.30 on an RTX 4090 [source: same].

**Reading.** VoxCPM2 directs one mood per call, well, through words. It cannot switch mid-call except by a ramp
written into the instruction or a sparse tag. Use controllable cloning, never Hi-Fi, or the identity clip's own
mood overrides the direction.

### 2.2 Fish Audio S2-Pro (challenger: speech, beats, tags)

- **Free-form inline tags at word level**: "open-ended expression control at the word level", "15,000+ unique tags
  supported"; listed examples include `[laughing] [inhale] [chuckle] [excited] [angry] [whisper] [screaming]
  [shouting] [surprised] [exhale] [panting] [sigh] [shocked] [moaning] [interrupting] [volume up] [low voice]`
  [source: Fish Audio, "s2-pro README @1de9996", https://huggingface.co/fishaudio/s2-pro/blob/1de9996b6be38b745688de084d87a5633f714e4e/README.md, read 2026-11-17].
  Tags work "anywhere in the text" [source: Fish Audio, "fish-speech docs/en/index.md",
  https://raw.githubusercontent.com/fishaudio/fish-speech/main/docs/en/index.md, read 2026-11-17], and the report's
  benchmark scores whether a tag is rendered "at the correct positions" [source: Liao et al./Fish Audio, "Fish Audio
  S2 Technical Report", https://huggingface.co/papers/2603.08823, read 2026-11-17]. **The only engine of the four
  that documents an emotion change inside one generation.**
- **Limit:** Fish's own comparison rates S2-Pro's strong emotion ("laughter, crying, whispers") as "Moderate" and
  says its successor makes them "no longer flattened by the reference" [source: Fish Audio, "fish-speech
  docs/en/index.md", above]. So an emotionally flat identity clip flattens S2-Pro's peaks.
- **Sampling:** temperature 0.7, top_p 0.7, top-k 30; `--seed` "does not fix the timbre"; no CFG [source: Fish
  Audio, "fish-speech docs/en/inference.md", https://raw.githubusercontent.com/fishaudio/fish-speech/main/docs/en/inference.md, read 2026-11-17].
- **Multi-speaker** in one pass is claimed ("interleaved dialogues involving multiple distinct speakers in a single
  pass") [source: Fish Audio S2 Technical Report, above]; in S2-Pro "the order of references determines the role"
  [source: fish-speech docs/en/inference.md, above]. No timing or overlap control is documented.
- **VRAM: "at least 24 GB"** [source: Fish Audio, "fish-speech docs/en/install.md",
  https://raw.githubusercontent.com/fishaudio/fish-speech/main/docs/en/install.md, read 2026-11-17]. The ComfyUI
  pack lists about 24 GB bf16, about 20 GB FP8 (Ada or Blackwell only) and about 16 GB NF4 [source: Saganaki22,
  "ComfyUI-FishAudioS2", https://github.com/Saganaki22/ComfyUI-FishAudioS2, read 2026-11-17]. The A5000 is an
  Ampere card with 24 GB, so FP8 is out and bf16 has no headroom: the pilot runs S2-Pro alone, in NF4 if bf16 does
  not fit, and logs which. [UNSOURCED: plan/provenance-audit.md#V-04] (the A5000's architecture is from the
  tillandsias host notes, not a fetched page).
- 44.1 kHz codec [source: Fish Audio S2 Technical Report, above].
- **New:** the fish-speech repo now ships "Drama 3" (35B-A3B, ≥ 48 GB FP8) under a separate "FISH AUDIO COMMUNITY
  LICENSE", while "S2-Pro weights remain under the Fish Audio Research License" [source: Fish Audio, "fish-speech
  README", https://raw.githubusercontent.com/fishaudio/fish-speech/main/README.md, read 2026-11-17]. Drama 3 does not
  fit the GPU; the admission must pin a fish-speech code revision that still runs S2-Pro.

### 2.3 Higgs Audio v2 (challenger: emotion, dialogue)

- **Emotion from the words and a scene prompt**, no emotion tags. EmergentTTS-Eval win rate against
  gpt-4o-mini-tts: Emotions 75.71 % [source: Boson AI, "bosonai/higgs-tts-2-3b-base", https://huggingface.co/bosonai/higgs-tts-2-3b-base, read 2026-11-17].
  The benchmark's Emotions category is "emotion intensification, followed by contrasting emotions" inside quoted
  dialogue [source: Manku et al./Boson AI, "EmergentTTS-Eval", https://huggingface.co/papers/2505.23009, read
  2026-11-17]: the exact swing the operator wants, and the category Higgs scores best on. A request for explicit
  emotion control was answered "We are working on a post-trained model" [source: sxjscience, "Feature Request:
  Emotion Control and Instruct Model", https://github.com/boson-ai/higgs-audio/issues/40, read 2026-11-17].
- **Scene prompt** inside `<|scene_desc_start|>…<|scene_desc_end|>`, default "Audio is recorded from a quiet room."
  [source: Boson AI, "examples/generation.py", https://raw.githubusercontent.com/boson-ai/higgs-audio/main/examples/generation.py, read 2026-11-17].
- **Sound events**: `generation.py` maps `[laugh]`, `[applause]`, `[cheering]`, `[cough]`, humming, music and singing
  to `<SE>` tokens, and strips parentheses, so Dia-style `(laughs)` vanishes [source: same]. Humming and BGM are
  "(Experimental)" [source: Boson AI, "examples README", https://raw.githubusercontent.com/boson-ai/higgs-audio/main/examples/README.md, read 2026-11-17].
  No growl, grunt, snarl, roar, hiss, scream or whoop.
- **Dialogue with audio context.** `[SPEAKER0]`/`[SPEAKER1]` turns, `--ref_audio a,b` assigns voices in order,
  `--chunk_method speaker`, and `--generation_chunk_buffer_size N` keeps the last N generated chunks plus the
  references as context [source: Boson AI, "examples/generation.py", above]. **Each turn hears the previous turns'
  audio**, which is what banter continuity needs. No overlap or timing control.
- **Cloning** needs a `.wav` and its `.txt`; "shallow voice clone"; the model "has not been post-trained yet"
  [source: Boson AI, "examples README", above].
- 24 kHz, "GPU with at least 24GB memory" [source: Boson AI, "README_V2", https://raw.githubusercontent.com/boson-ai/higgs-audio/main/README_V2.md, read 2026-11-17].
- **New:** the repo's main README now covers Higgs Audio v3 under a "Research and Non-Commercial License", with v2 in
  `README_V2.md` [source: Boson AI, "higgs-audio README", https://raw.githubusercontent.com/boson-ai/higgs-audio/main/README.md, read 2026-11-17].
  v3 is out (voice-stack research §10.2). The admission must pin a code revision that runs v2.

### 2.4 Dia 1.6B (non-verbals; default engine)

- **21 tags:** "(laughs), (clears throat), (sighs), (gasps), (coughs), (singing), (sings), (mumbles), (beep),
  (groans), (sniffs), (claps), (screams), (inhales), (exhales), (applause), (burps), (humming), (sneezes), (chuckle),
  (whistles)"; "Use non-verbal tags sparingly" [source: Nari Labs, "dia README", https://raw.githubusercontent.com/nari-labs/dia/main/README.md, read 2026-11-17];
  others "might result in unexpected output" [source: Nari Labs, "Dia-1.6B model card", https://huggingface.co/nari-labs/Dia-1.6B, read 2026-11-17].
- **Two speakers**, `[S1]`/`[S2]` alternating; "under 5s of audio… will sound unnatural", "over 20s… unnaturally
  fast" [source: Nari Labs, "dia README", above].
- **Punctuation drives intensity, too hard:** "Dia seems obsessed with the idea that exclamation marks = shouting or
  screaming"; the audio prompt is "a suggestion, one that Dia can ignore most of the time" [source: GitHub user,
  "Need more nuance in emotions with respect to punctuation", https://github.com/nari-labs/dia/issues/256, read 2026-11-17].
  Single words turn into invented sentences or noise [source: GitHub users, "Single words are being converted to long
  sentences", https://github.com/nari-labs/dia/issues/141, read 2026-11-17]. Long scripts drift unless the last turns
  are carried forward as the next audio prompt [source: GitHub users, "Generate outputs beyond ~25 seconds",
  https://github.com/nari-labs/dia/issues/35, read 2026-11-17].
- **Cloning:** the reference transcript goes before the target text; reference "5~10 seconds" [source: Nari Labs,
  "dia README", above]. The clone example uses `cfg_scale=4.0, temperature=1.8, top_p=0.90, cfg_filter_top_k=50`
  [source: Nari Labs, "example/voice_clone.py", https://raw.githubusercontent.com/nari-labs/dia/main/example/voice_clone.py, read 2026-11-17];
  defaults are `cfg_scale=3.0, temperature=1.2, top_p=0.95, cfg_filter_top_k=45`, 44.1 kHz [source: Nari Labs,
  "dia/model.py", https://raw.githubusercontent.com/nari-labs/dia/main/dia/model.py, read 2026-11-17]. The app's
  `speed_factor` resamples, so it shifts pitch [source: Nari Labs, "app.py", https://raw.githubusercontent.com/nari-labs/dia/main/app.py, read 2026-11-17].
- **Pin drift:** the examples now load `nari-labs/Dia-1.6B-0626`, not our pinned `Dia-1.6B` [source: Nari Labs,
  "example/simple.py", https://raw.githubusercontent.com/nari-labs/dia/main/example/simple.py, read 2026-11-17].
  Dia2 (1B, 2B; Apache-2.0; Mimi codec, per-speaker prefix WAVs, up to 2 minutes) exists [source: Nari Labs, "dia2",
  https://github.com/nari-labs/dia2, read 2026-11-17], and its card does not mention non-verbal tags [source: Nari
  Labs, "Dia2-2B model card", https://huggingface.co/nari-labs/Dia2-2B, read 2026-11-17]. Neither is pinned; the
  pilot keeps the pinned 1.6B.
- VRAM about 4.4 GB bf16 per the README; the card says "around 10GB" [sources above].

## 3. Emotion swings

| Need | VoxCPM2 | Fish S2-Pro | Higgs v2 | Dia 1.6B |
|---|---|---|---|---|
| One mood per line | instruction text (best documented) | tag at the start | words + scene prompt | words, punctuation |
| Swing inside a line | ramp in the instruction, or render per beat and splice | **tags at each beat** | words ("contrasting emotions" is its benchmark category) | punctuation; overshoots |
| Intensity | adverb ladder in the instruction; `cfg_value` 1.6–2.5 | `[volume up]`, `[shouting]`, `[screaming]` | words, caps, punctuation | "!" count (too strong) |
| Laugh / cheer / gasp | `[laughing]`, `[Surprise-wa]` only | `[laughing]`, `[panting]`, `[screaming]`, free-form | `[laugh]`, `[cheering]`, `[applause]` | 21 tags incl. (gasps), (screams), (groans) |

Sources: §2.1–2.4.

**Findings.**
1. **Beats are the engine-neutral unit of a swing.** A line splits into two to four beats, each with an emotion and
   intensity. Per engine: S2-Pro gets a tag before each beat in one generation; Higgs gets the whole line with the
   arc written in the scene prompt and the words; VoxCPM2 renders each beat as its own call (≥ 1 s of audio each,
   §2.1) conditioned on the identity clip, and the takes are spliced at a pause with a short crossfade, or, for
   beats under 1 s, the whole line gets one ramp instruction ("starts calm, then panicked, ends cheering"). Which of
   VoxCPM2's two routes sounds better is a pilot question. [UNSOURCED: plan/provenance-audit.md#V-05] (splicing
   per-beat takes keeps the voice continuous is an assumption to test).
2. **Identity clips must be emotionally neutral but alive.** VoxCPM2 Hi-Fi copies the reference's emotion, S2-Pro's
   peaks are "flattened by the reference", Dia treats the prompt as a suggestion (§2). So each character keeps the
   neutral identity clip from voice-stack and gains an optional **hot reference** (the same voice, shouted and
   excited, rendered once by voice design and committed) for intensity 3 beats on engines that follow the
   reference's energy. Whether a hot reference helps is a pilot question.
3. **Intensity 3 needs a ceiling.** Dia's "!" turns into screaming and VoxCPM2's top `cfg_value` adds artefacts
   (§2.1, §2.4). The engine recipe caps each: Dia lines are written with one "!" at most and the cue carries the
   peak; VoxCPM2 stays at `cfg_value` ≤ 2.5.

## 4. Banter and prosody continuity

- **Context, not just order.** Higgs v2's chunked dialogue keeps previous generated turns as context (§2.3); Dia
  continues from an audio prompt and needs the last turns carried forward (§2.4); S2-Pro takes several speakers in one
  pass (§2.2); VoxCPM2 has no documented dialogue mode, so turn k is rendered with turn k−1's picked take as context
  only if the admitted node exposes a prompt/continuation input (the README lists "Isolated Reference & Continuation"
  [source: OpenBMB, "VoxCPM README", above]); otherwise each turn's instruction names the energy it answers ("answers
  an excited teammate, matching the energy, then calming").
- **Timing and overlap are ours.** No engine documents turn timing or overlap (§2). A thread renders each turn as its
  own clip (or splits a one-pass dialogue into per-speaker tracks: the S2-Pro ComfyUI pack has a "Multi-Speaker Split
  TTS" node that outputs one aligned track per speaker [source: Saganaki22, "ComfyUI-FishAudioS2", above]), and the
  director places turns with an authored `gap` (negative = overlap). Short overlaps on a radio are part of the genre
  [UNSOURCED: plan/provenance-audit.md#V-06]; the director already plays the regroup celebration overlapping with a
  0.3 s stagger (`lib/comms/comms_director.dart`, `overlapStagger`).
- **Lineup.** The lineup is five fleet and two ground members per run (`art/comms/cast.json` `lineup`), so a thread
  naming two non-anchor speakers is playable only on some runs. Threads lean on the Admiral (always on the call) and
  carry several threads per trigger; a coverage check reports, per trigger, the share of lineups that can play at least
  one thread.
- **The tone list is banter material.** The voice-stack allowlist entries carry `retorts`, so a thread can pair a
  taunt and its retort (design §3.2 of voice-stack).

## 5. Brood vocals

### 5.1 What the engines can make

| Sound | VoxCPM2 | Fish S2-Pro | Higgs v2 | Dia 1.6B |
|---|---|---|---|---|
| Laugh, cackle | `[laughing]` | `[laughing]`, `[chuckle]` | `[laugh]` | (laughs), (chuckle) |
| Effort grunt, groan | — | `[moaning]`, free-form untested | — | (groans) |
| Scream, roar raw | — | `[screaming]`, `[shouting]` | — | (screams) |
| Breath, pant, hiss raw | — | `[panting]`, `[inhale]`, `[exhale]` | — | (inhales), (exhales), (gasps) |
| Growl, snarl | none documented | free-form `[growl]` untested | none | none |
| Cheer | — | free-form | `[cheering]` | (applause) |

Sources: §2. **No engine documents a growl or snarl.** Only Dia has a fixed, documented set of human effort
sounds; S2-Pro's free-form tags may make a growl but nothing says so. Screaming in Dia is reported working only in a
built-in demo [source: GitHub users, "Has anyone produced anything useful with this?",
https://github.com/nari-labs/dia/issues/220, read 2026-11-17].

**Findings.**
1. **The operator's expectation holds in part.** The new engines will give the brood real human grunts, groans,
   gasps, screams, laughs and breaths, in each officer's own voice, as raw material. They will not give growls or
   snarls. Those come from the DSP chain over human efforts, layered with the existing procedural glottal growl
   (`synth_grunt`), which already models a throaty creature (subharmonic rasp, formant "wah").
2. **Effort sounds need a carrier.** Dia makes nothing useful from a lone word or a lone tag (§2.4), so a vocal is
   rendered as a reel: one generation of 8–15 s with three to six efforts in a short scripted scene ("[S1] (groans)
   Heavy. (groans) Heavier. (screams)"), then cut at the efforts. Word timestamps from the speech recogniser (§6) find
   the cut points; the words around them are discarded. [UNSOURCED: plan/provenance-audit.md#V-01] (still the
   working assumption from voice-stack).
3. **Free-form growl tags are an experiment**, not a plan: the pilot tries `[growl]`, `[snarl]` and `[grunt]` on S2-Pro
   and `<SE>[Growl]</SE>` on Higgs, and keeps them only if they beat the DSP route by ear.

### 5.2 The DSP chain: from a grunt to a demon

Why today's chain sounds like tape: resampling moves pitch and formants by the same ratio, and reversal turns the
words' contour backwards. Separating pitch from formants keeps the effort's emotion while making the throat bigger.

Tools read:
- **Signalsmith Stretch**, MIT: `setTransposeSemitones()`, `setFormantFactor()`, `setFormantBase()`; the CLI takes
  `--semitones`, `--formant`, `--formant-comp` [source: Signalsmith-Audio, "signalsmith-stretch",
  https://github.com/Signalsmith-Audio/signalsmith-stretch, read 2026-11-17] [source: Signalsmith-Audio,
  "cmd/main.cpp", https://github.com/Signalsmith-Audio/signalsmith-stretch/blob/main/cmd/main.cpp, read 2026-11-17];
  a Rust crate `signalsmith-stretch` 0.1.3, MIT [source: crates.io, "signalsmith-stretch",
  https://crates.io/api/v1/crates/signalsmith-stretch, read 2026-11-17].
- **Rubber Band**, GPL-2.0-or-later: `setFormantScale()` exists only in the R3 engine; the CLI has `-F` (preserve)
  but no formant amount [source: breakfastquay, "RubberBandStretcher.h",
  https://raw.githubusercontent.com/breakfastquay/rubberband/default/rubberband/RubberBandStretcher.h, read 2026-11-17]
  [source: breakfastquay, "main/main.cpp", https://raw.githubusercontent.com/breakfastquay/rubberband/default/main/main.cpp, read 2026-11-17].
  **ffmpeg's `rubberband` filter offers `formant` = `shifted | preserved` only** [source: FFmpeg, "doc/filters.texi",
  https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/doc/filters.texi, read 2026-11-17], so it cannot do the
  formant step.
- **WORLD** vocoder, modified BSD: F0, spectral envelope and aperiodicity separately, so F0, formants and breathiness
  can each be moved; no Rust or Go wrapper listed [source: mmorise, "World", https://github.com/mmorise/World, read 2026-11-17].
- **fundsp**, MIT/Apache-2.0: oscillators, ring modulation by multiplying signals, filters, `shape` (Tanh, Clip,
  Crush), chorus, phaser, offline rendering; no pitch shifter or granular module [source: SamiPerttu, "fundsp",
  https://github.com/SamiPerttu/fundsp, read 2026-11-17].
- **ebur128** crate, MIT, a port of libebur128: momentary, short-term, integrated loudness and true peak [source:
  sdroege, "ebur128", https://github.com/sdroege/ebur128, read 2026-11-17].
- ffmpeg filters for the rest: `areverse` (whole clip in memory), `afreqshift` (`shift`, `level`, `order`),
  `asoftclip` (`type`, `threshold`, `oversample`), `acrusher` (`bits`, `mix`), `tremolo`/`vibrato` (`f`, `d`), `aecho`,
  `chorus`, `adynamicequalizer`, `silencedetect`, `astats`, `loudnorm` (default I −24, TP −2) [source: FFmpeg,
  "doc/filters.texi", above].
- Creature-voice practice notes and papers (CRIWARE, Sound Ideas, a human-to-non-human voice-conversion paper, a
  designed-vocalisations dataset) were seen only as snippets and are not used: [source: CRIWARE, "creature
  vocalizations", https://blog.criware.com/index.php/2023/03/11/creature-vocalizations/, unread: snippet only]
  [source: arXiv, "H2NH-VC", https://arxiv.org/abs/2505.24336v1, unread: snippet only].

**Proposed chain** (a Rust tool `tools/brood_fx`, signalsmith-stretch + fundsp + ebur128, all MIT; deterministic by
seed; every value is a starting point for listening, logged in the pilot ledger):

| # | Step | Tool | Start values | Purpose |
|---|---|---|---|---|
| 0 | Gate the clean take | §6 checks | — | ASR and identity checks run before FX, which would defeat them |
| 1 | Clean | high-pass 70 Hz | — | keep the sub layer clean |
| 2 | `reverse` (selective) | per segment | breaths, efforts and tails only; words optional per character | keep the alien "backwards" signature without hiding the emotional contour of every word |
| 3 | `pitch` + `formant` | signalsmith | −5 to −8 st pitch, −3 to −5 st formant, no compensation | bigger throat, same emotion |
| 4 | `subharmonic` | signalsmith copy | −12 st, formant −6, about −10 dB | weight |
| 5 | `ringmod` | fundsp | 40–70 Hz sine, 15–25 % wet | inharmonic, "not a person" |
| 6 | `drive` | fundsp `shape` Tanh | mild, oversampled | grit |
| 7 | `granular` (optional) | own code | 20–40 ms grains, small jitter | chitter for Skritch and Nibb |
| 8 | `doubler` (optional) | fundsp chorus | 2 voices, ±15 cents | a "brood" chorus for rally lines |
| 9 | `eq` | fundsp | cut 200–300 Hz mud | radio clarity |
| 10 | Growl layer | `synth_grunt` | existing per-officer settings | creature body |
| 11 | Radio chain, loudness, Opus | `tools/comms_pipeline.py` | unchanged | as today |

The steps are a closed set in `demon-delivery.json` v2 (spec "Demon FX chain per character"). Wet and dry renders of
the same take are kept so a beat can cross from demon to person (§5.3).

### 5.3 The reveal

- The ending maps every brood speaker to a restaurant person (`plan/endgame-reveal-ledger.md` §1.3): Gorrak the owner,
  Vexxa the teenage waitress, Skarn the grill cook, Ulgra and Morth brood-side kids, Nibb a toddler, Grunnok a big
  brother, Blatch the takeout worker, Skritch a seagull, Krag the owner's dog, Sliss the cat. Vexxa's lines "may be
  voiced plainly" (`openspec/changes/endgame-cinematic/design.md` §12, decision 1).
- So **the clean performance under the FX is the person's real voice**: each brood identity is re-cast to match the
  person (today Ulgra, a kid, is performed by an adult Kokoro voice, `am_michael`, in `demon-delivery.json`). The
  cinematic line "A rematch. After a short break." has the direction "He growls the first two words in his monster
  voice, then finishes as himself" (`art/comms/endgame-lines.proposal.json`, `endgame.e4`): a beat-level wet/dry
  crossfade on one take, which is why both renders are kept.
- **Child voices:** Ulgra, Morth and Nibb are children in the ending. The fallback for child voices is "Subtitled
  kids, with laughs and groans" (endgame design §12, decision 9). Their brood lines stay transformed; a plain child
  voice waits for the operator's approval.
- **Animals:** Krag (dog), Sliss (cat) and Skritch (gull) are vocal-only by nature. Their FX chains can aim at a
  growl, a hiss and a squawk, so the reveal plays the same sound unprocessed or lightly processed. No engine makes
  animal sounds (§5.1); the source is a human imitation (a Dia or S2-Pro effort) plus DSP. [UNSOURCED:
  plan/provenance-audit.md#V-07] (that a processed human growl can pass as a dog or cat in the ending is a design
  bet, to test in the pilot).

## 6. Takes, rejection, picks

| Check | Tool | Licence | Notes |
|---|---|---|---|
| Words (WER), word timestamps | whisper.cpp | MIT | CPU in the forge; Go bindings, Rust via whisper-rs; word timestamps experimental (`-ml 1`); small model about 852 MB [source: ggml-org, "whisper.cpp", https://github.com/ggml-org/whisper.cpp, read 2026-11-17] |
| same, GPU | faster-whisper | MIT | `word_timestamps=True`, Silero VAD [source: SYSTRAN, "faster-whisper", https://github.com/SYSTRAN/faster-whisper, read 2026-11-17] |
| Whisper weights | openai/whisper | MIT | [source: OpenAI, "whisper", https://github.com/openai/whisper, read 2026-11-17] |
| alt. ASR | Parakeet-TDT-0.6b-v2 | CC-BY-4.0 | English, word timestamps, NeMo [source: NVIDIA, "parakeet-tdt-0.6b-v2", https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2, read 2026-11-17] |
| Identity drift | SpeechBrain ECAPA | Apache-2.0 | `verify_files()` score [source: SpeechBrain, "spkrec-ecapa-voxceleb", https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb, read 2026-11-17] |
| alt. identity | WeSpeaker | code Apache-2.0, VoxCeleb models CC-BY-4.0, ONNX exports | [source: wenet-e2e, "docs/pretrained.md", https://raw.githubusercontent.com/wenet-e2e/wespeaker/master/docs/pretrained.md, read 2026-11-17] |
| Laughter present | laughter-detection | MIT | [source: jrgillick, "laughter-detection", https://github.com/jrgillick/laughter-detection, read 2026-11-17] |
| Emotion (advisory) | emotion2vec_plus | **weights licence unstated** ("model-license") | 9 classes [source: emotion2vec, "emotion2vec_plus_large", https://huggingface.co/emotion2vec/emotion2vec_plus_large, read 2026-11-17]; not admitted until the licence is read |
| Loudness, true peak | ebur128 crate | MIT | §5.2 |
| Silence, clipping | ffmpeg `silencedetect`, `astats` | LGPL | §5.2 |

**Findings.**
1. The speech recogniser runs in the forge on CPU (whisper.cpp through Go or Rust), so take rejection needs no GPU
   admission and keeps the studio queue for synthesis. Whisper weights are MIT; the download still needs the operator's
   consent token like any model.
2. ASR runs on the **clean** take: the brood FX would defeat it. For vocal-only takes the check inverts: recognised
   words mean the engine spoke instead of growling (Dia's single-tag failure, §2.4).
3. Speech emotion recognition trained on human speech is not proven on exaggerated TTS, and emotion2vec's weights
   licence is unread. It stays out of the reject rules; the listening pass judges emotion.
4. Take counts rise from voice-stack's 3/2 to 4/3: expressive inputs are less stable (VoxCPM2 "may vary between
   runs", recommends 1–3 generations; Higgs "different seeds give different audio"; §2), and each automatic reject
   removes a take before anyone listens.

## 7. ComfyUI versus CLI

| Step | Where | Node or tool |
|---|---|---|
| Speech take | studio | VoxCPM2: `VoxCPM2 TTS`, `VoxCPM2 Voice Clone` (Saganaki22/ComfyUI-VoxCPM2, Apache-2.0; inputs `voice_description`, `cfg_value`, `inference_timesteps`, `seed`, `reference_audio`, `prompt_text`) [source: Saganaki22, "ComfyUI-VoxCPM2", https://github.com/Saganaki22/ComfyUI-VoxCPM2, read 2026-11-17] |
| Beats, tags, dialogue (challenger) | studio | Fish S2-Pro: `Fish S2 TTS`, `Voice Clone TTS`, `Multi-Speaker TTS`, `Multi-Speaker Split TTS` (Saganaki22/ComfyUI-FishAudioS2) [source above, §2.2] |
| Dialogue (challenger) | studio | Higgs v2: TTS-Audio-Suite "Higgs Audio Engine" (MIT) [source: diodiogod, "TTS-Audio-Suite", https://github.com/diodiogod/TTS-Audio-Suite, read 2026-11-17]; alternatives ShmuelRonen/ComfyUI-HiggsAudio_Wrapper (no licence stated) and Yuan-ManX/ComfyUI-HiggsAudio (MIT, nodes not shown) [source: ShmuelRonen, "ComfyUI-HiggsAudio_Wrapper", https://github.com/ShmuelRonen/ComfyUI-HiggsAudio_Wrapper, read 2026-11-17] [source: Yuan-ManX, "ComfyUI-HiggsAudio", https://github.com/Yuan-ManX/ComfyUI-HiggsAudio, read 2026-11-17] |
| Vocal reels | studio | Dia: `DiaLoader`, `DiaGenerate` (BobRandomNumber/ComfyUI-DiaTTS, Apache-2.0; `cfg_scale`, `temperature`, `top_p`, `cfg_filter_top_k`, `speed_factor`, `seed`, `audio_prompt`) [source: BobRandomNumber, "ComfyUI-DiaTTS", https://github.com/BobRandomNumber/ComfyUI-DiaTTS, read 2026-11-17] |
| Trim, join, gain, save | studio | core `TrimAudioDuration`, `AudioConcat`, `AudioMerge`, `AudioAdjustVolume`, `SaveAudioAdvanced` (flac) [source: comfyanonymous, "comfy_extras/nodes_audio.py", https://raw.githubusercontent.com/comfyanonymous/ComfyUI/master/comfy_extras/nodes_audio.py, read 2026-11-17]; provenance save through #1103's `tillandsias_audio` save node |
| Rejection checks | forge CLI | whisper.cpp, ECAPA/WeSpeaker, ebur128, ffmpeg (§6) |
| Pick, ledger | forge CLI | Lua production runner + listening page |
| Brood FX | forge CLI | `tools/brood_fx` (Rust) |
| Radio chain, loudness, Opus, verify, dart | forge CLI | `tools/comms_pipeline.py` (unchanged) |

Notes: TTS-Audio-Suite covers Fish S2-Pro and Higgs but not VoxCPM2 or Dia (same source); ComfyUI-Whisper is
CC BY-NC-SA 4.0 [source: yuvraj108c, "ComfyUI-Whisper", https://github.com/yuvraj108c/ComfyUI-Whisper, read
2026-11-17], so ASR stays a CLI step. The audio-effects packs read (GPL-3.0 ComfyUI_SignalProcessing has loudness and
EQ but no pitch) [source: c0ffymachyne, "ComfyUI_SignalProcessing", https://github.com/c0ffymachyne/ComfyUI_SignalProcessing, read 2026-11-17]
do not cover pitch with formant control, so brood FX stays offline. Which pack the coordinator admits is the
coordinator's call; these are the candidates that expose seed and reference inputs.

## 8. Recommendation per engine

| Engine | Role in the pilot | Direction recipe |
|---|---|---|
| **VoxCPM2** | single lines, placeholder, per-beat renders, hot references by voice design | controllable cloning (never Hi-Fi); instruction = emotion phrase + intensity adverb + `direction`; `cfg_value` 2.0 (≤ 2.5; 1.6 if artefacts); `inference_timesteps` 10–20; tags `[laughing]`, `[sigh]` only; beats ≥ 1 s as separate calls, shorter ones as a ramp instruction |
| **Dia 1.6B** | vocal reels (efforts, laughs, screams, gasps), crowd beds | reels of 8–15 s, `[S1]` only for one character, ≤ 1 "!" per sentence, clone example settings (`cfg_scale` 4.0, `temperature` 1.8, `top_p` 0.90, `cfg_filter_top_k` 50) as the start, seed fixed per take |
| **Fish S2-Pro** | challenger for beats and single lines; vocal tags (free-form growl test) | tag before each beat; defaults temperature 0.7, top_p 0.7; hot reference for intensity 3; runs alone on the GPU (bf16 or NF4, logged) |
| **Higgs v2** | challenger for threads | `[SPEAKER0..n]`, references per speaker, `--chunk_method speaker`, buffer 2–3, scene prompt "two pilots on a crackling fleet radio in a dogfight"; `[laugh]`, `[cheering]`; runs alone |

## 9. Open questions

1. **Admission pins.** Dia's examples moved to `Dia-1.6B-0626`; the Higgs and fish-speech repos moved to v3 and Drama
   3. The coordinator pins code revisions that run our pinned weights (§2.2–2.4).
2. **S2-Pro on 24 GB.** bf16 may not fit beside ComfyUI's own memory; NF4 changes quality. The pilot logs which ran.
3. **VoxCPM2 continuation.** Does the admitted node expose a prompt/continuation input for thread turns?
4. **Child voices** for Ulgra, Morth, Nibb in the ending: operator approval (endgame design §12, decision 9).
5. **emotion2vec licence**, Rubber Band GPL as an offline tool (not needed if Signalsmith suffices).
6. **Growl tags** on S2-Pro and Higgs: undocumented; only the pilot can say.
