# Voice stack research: expressive radio voices on local models (2026-11-16)

Workstream V1 of `plan/operator-feedback-2026-11-16.md` (Round 3c). Spec: `openspec/changes/voice-stack/`.

Operator, 2026-11-16: the existing voices are "somewhat flat of emotion"; most radio speech will be re-rendered "once
we figure out how to add proper emotion and excitement, as well as a bit of cheering, wooing, grunting, growling";
find out whether we need different models, pipelines or a different suite; "a few PG-13 cleared pseudo-swearing ;)
keep it family friendly".

**Method.** Pages were fetched from the forge on 2026-11-16 (two research agents plus spot checks). Hugging Face,
GitHub, raw.githubusercontent.com and w3.org loaded. These hosts reset every connection and were not routed around:
stability.ai, sonniss.com, freesound.org, ffmpeg.org, breakfastquay.com, tech.ebu.ch, ebu.ch, itu.int, aes.org,
audiokinetic.com, audiogang.org, gamefromscratch.com. Where a project gives no separate weights licence, the Hugging
Face card's licence tag is used, which is weaker than a LICENSE file: re-read the LICENSE before admission (§9).
"Not stated" means the page read does not say. VRAM figures are the sources' own, not measured here.

## 1. Where we start

- The bank: 574 clips, 380 Chatterbox, 188 Chatterbox reverse-pitch (brood), 5 Kokoro, 1 synthesized grunt
  (`web/audio/comms/manifest.json`). Characters are Kokoro-82M preset voices re-voiced by Chatterbox from a reference
  clip (`art/comms/audio.json`, `art/comms/cast.json`). Emotion is one label per line mapped to Chatterbox
  `exaggeration` / `cfg_weight` / `temperature` plus a post-shaping step. There are no non-verbal tags.
- It rendered on CPU in a forge venv: the Chatterbox torch build saw no CUDA, the worker used about 15 cores under a
  12 GiB cgroup (`plan/handoff-battle-metal-radio-2026-11-12.md`). That venv and its weights are gone (§9.0).
- tillandsias#1103 batch 1 is music only (ComfyUI `tillandsias_audio` nodes, ACE-Step 1.5 XL-SFT, CC0 SFZ) plus a
  CPU audio appliance; it has no expressive TTS (coordinator via the lead, 2026-11-16). `plan/render-runs/RESUME.md`
  had expected VoxCPM2 in batch 1; that is now out of #1103.
- The host GPU is one RTX A5000, 24 GB, shared by ComfyUI and ACE-Step; TTS must be a studio capability behind the
  admission and licence register, not a second container (coordinator, 2026-11-16).

Why flat: Chatterbox has one global expressiveness knob. Its card says `exaggeration` defaults to 0.5 and suggests
about 0.7 or higher with `cfg` about 0.3 for dramatic speech [source: Resemble AI, "ResembleAI/chatterbox",
https://huggingface.co/ResembleAI/chatterbox, read 2026-11-16]. Our emotion table tops out at 1.0 for `urgent` and
0.45–0.6 for half the emotions, and there is no way to ask for a laugh, a whoop or a grunt inside a line. More
expressive results need a model that takes richer direction (text instructions, emotion vectors or tags), not only a
higher knob.

## 2. Expressive TTS (emotion, style, paralinguistic tags)

| Model | Direction | Non-verbal tags | Identity | Size, VRAM | Licence (code / weights) | Runtime, ComfyUI |
|---|---|---|---|---|---|---|
| VoxCPM2 (OpenBMB) | Text style prompt in parentheses, e.g. `(slightly faster, cheerful tone)` | none stated | Voice design from a description; cloning from a clip (+ transcript for "ultimate" cloning) | 2B; ~8 GB; 48 kHz output | Apache-2.0 / Apache-2.0, "free for commercial use" | Python; community ComfyUI nodes (snippet only) |
| Chatterbox / -Turbo / -Nano (Resemble AI) | `exaggeration`, `cfg_weight` (original) | Turbo, Nano: `[laugh]`, `[chuckle]`, `[cough]` "and more" | Zero-shot cloning | 500M / 350M / 110M (Nano 3× realtime on 8 CPU cores); VRAM not stated | MIT / MIT; Perth watermark on every output; **retired, unmaintained since Aug 2026** | pip; in TTS-Audio-Suite |
| Dia 1.6B (Nari Labs) | Speaker tags `[S1]`/`[S2]` | 21: (laughs), (sighs), (gasps), (groans), (screams), (inhales), (exhales), (applause), (claps), (chuckle), (whistles) … | Cloning from a 5–10 s reference + transcript | ~4.4 GB bf16; clips under ~5 s sound unnatural | Apache-2.0 / Apache-2.0 (card: "research and educational use", no identity misuse) | Python, Gradio, CLI; not in TTS-Audio-Suite |
| Orpheus 3B (Canopy Labs) | 8 preset voices | `<laugh> <chuckle> <sigh> <cough> <sniffle> <groan> <yawn> <gasp>` | Cloning listed, notebook unfinished | Llama-3.2-3B base; VRAM not stated | Apache-2.0 / Apache-2.0 tag, gated; Llama licence inheritance not addressed | vLLM, llama.cpp |
| Qwen3-TTS (Qwen) | Instruction text ("angry tone") | none stated | VoiceDesign 1.7B from a description; Base 0.6B/1.7B 3 s cloning | VRAM not stated | Apache-2.0 / Apache-2.0 tag | pip `qwen-tts`; in TTS-Audio-Suite |
| Maya1 (Maya Research) | `<description="…">` voice design | 20: `<laugh> <laugh_harder> <chuckle> <giggle> <sigh> <gasp> <gulp> <scream> <cry> <whisper> <angry> <excited>` … | Design only, no cloning | 3.3B; 16 GB+ recommended | Apache-2.0 | vLLM |
| IndexTTS2 (bilibili) | 8-value emotion vector, emotion text, emotion reference clip, `emo_alpha` | none | Zero-shot cloning | 2.5: ~0.8B, ~6 GB | bilibili Model Use License: royalty-free; outputs count as Derivative Works (§10) | webui; in TTS-Audio-Suite |
| Zonos v0.1 (Zyphra) | Emotion vector (happiness, anger, sadness, fear), rate, pitch | not stated | Cloning from 10–30 s | 6 GB+ | Apache-2.0 / Apache-2.0 | Gradio, Docker |
| Step-Audio-EditX (StepFun) | Edit pass: 14 emotions, 32 styles | 22 (sigh, laugh, chuckle, breath, clears throat …) | Zero-shot | 3B; 12–16 GB, 6–8 GB memory-efficient | Apache-2.0 / not stated | in TTS-Audio-Suite |
| CosyVoice 3 (FunAudioLLM) | Instruct (emotion, speed, volume) | `[breath]`; suite lists breath, laughter, cough | Zero-shot | 0.5B; not stated | Apache-2.0 / Apache-2.0 tag | many; in TTS-Audio-Suite |
| Kokoro-82M | none | none | 54 presets | 82M | Apache-2.0 | pip + espeak-ng |

Sources for the table, row by row:
VoxCPM2 [source: OpenBMB, "OpenBMB/VoxCPM README", https://github.com/OpenBMB/VoxCPM, read 2026-11-16]
[source: Saganaki22, "ComfyUI-VoxCPM2", https://github.com/Saganaki22/ComfyUI-VoxCPM2, unread: snippet only];
Chatterbox [source: Resemble AI, "resemble-ai/chatterbox README", https://github.com/resemble-ai/chatterbox, read 2026-11-16]
[source: Resemble AI, "ResembleAI/chatterbox-turbo", https://huggingface.co/ResembleAI/chatterbox-turbo, read 2026-11-16];
Dia [source: Nari Labs, "nari-labs/dia README", https://github.com/nari-labs/dia, read 2026-11-16]
[source: Nari Labs, "nari-labs/Dia-1.6B", https://huggingface.co/nari-labs/Dia-1.6B, read 2026-11-16];
Orpheus [source: Canopy Labs, "canopyai/Orpheus-TTS README", https://github.com/canopyai/Orpheus-TTS, read 2026-11-16]
[source: Canopy Labs, "canopylabs/orpheus-3b-0.1-ft", https://huggingface.co/canopylabs/orpheus-3b-0.1-ft, read 2026-11-16];
Qwen3-TTS [source: Qwen, "QwenLM/Qwen3-TTS README", https://github.com/QwenLM/Qwen3-TTS, read 2026-11-16]
[source: Qwen, "Qwen3-TTS-12Hz-1.7B-VoiceDesign", https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign, read 2026-11-16];
Maya1 [source: Maya Research, "maya-research/maya1", https://huggingface.co/maya-research/maya1, read 2026-11-16];
IndexTTS2 [source: bilibili Index team, "index-tts/index-tts README", https://github.com/index-tts/index-tts, read 2026-11-16]
[source: IndexTeam, "IndexTeam/IndexTTS-2", https://huggingface.co/IndexTeam/IndexTTS-2, read 2026-11-16];
Zonos [source: Zyphra, "Zyphra/Zonos README", https://github.com/Zyphra/Zonos, read 2026-11-16];
Step-Audio-EditX [source: StepFun, "stepfun-ai/Step-Audio-EditX README", https://github.com/stepfun-ai/Step-Audio-EditX, read 2026-11-16];
CosyVoice 3 [source: FunAudioLLM, "FunAudioLLM/CosyVoice README", https://github.com/FunAudioLLM/CosyVoice, read 2026-11-16]
[source: FunAudioLLM, "Fun-CosyVoice3-0.5B-2512", https://huggingface.co/FunAudioLLM/Fun-CosyVoice3-0.5B-2512, read 2026-11-16];
Kokoro [source: hexgrad, "hexgrad/Kokoro-82M", https://huggingface.co/hexgrad/Kokoro-82M, read 2026-11-16].

**Licence status.** The first pass (2026-11-16, morning) excluded every model whose weights were non-commercial. The
operator then said the software and games are free and open source and not used commercially (Round 3d, V1
addendum), so §10 re-reads each licence text for what it says about the generated audio and about a GPL-3.0 repo.
The IndexTTS2 row above was wrong in the first pass: the bilibili licence text is royalty-free with very high user and
revenue thresholds (§10). The licence column of this table states the weights' licence only; §10 has the verdicts.
Kyutai TTS weights are CC-BY 4.0 (attribution) but clone only from Kyutai's own voice embeddings [source: Kyutai,
"kyutai/tts-1.6b-en_fr", https://huggingface.co/kyutai/tts-1.6b-en_fr, read 2026-11-16], so it cannot hold our
cast. MOSS-TTSD states no weights licence [source: OpenMOSS, "OpenMOSS/MOSS-TTSD README",
https://github.com/OpenMOSS/MOSS-TTSD, read 2026-11-16].

**Findings.**
1. For emotional speech with a licence that puts no condition on the audio, VoxCPM2 is the strongest fit: Apache-2.0 code and weights
   stated as free for commercial use, text style direction per line, voice design for new characters, cloning from
   our committed identity clips, 48 kHz output and a stated ~8 GB (sources above). It has no non-verbal tags.
2. For tags (laughs, groans, screams, applause, gasps), Dia 1.6B has the widest documented set under Apache-2.0 at
   ~4.4 GB, with the caveat that clips under ~5 s sound unnatural and unlisted tags cause artefacts (Dia sources
   above). Maya1 has a comparable set but asks for 16 GB+ and cannot clone, so it cannot hold our cast.
3. Chatterbox-Turbo adds native `[laugh]`/`[chuckle]`/`[cough]` to the engine we already know, under MIT, but the
   project is retired and unmaintained since August 2026 and every output is watermarked (Chatterbox sources above).
   The operator dropped it on 2026-11-16 (§10.4); VoxCPM2 renders placeholders too.

## 3. Voice identity for a consistent cast

- VoxCPM2 and Dia both clone from a reference clip plus its transcript (§2), so one committed clip per character can
  condition every take. That is the simplest identity lock and matches what the current pipeline does with
  Chatterbox.
- RVC trains a voice model from about 10 minutes of speech; code MIT; its base model was trained on about 50 h of
  VCTK [source: RVC-Project, "Retrieval-based-Voice-Conversion-WebUI", https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI, read 2026-11-16];
  pretrained weights listed MIT [source: lj1995, "lj1995/VoiceConversionWebUI", https://huggingface.co/lj1995/VoiceConversionWebUI, read 2026-11-16].
  A trained RVC model per character, applied after any engine, would make timbre identical across engines (VoxCPM2
  speech, Dia non-verbals).
- OpenVoice V2: MIT, "free for commercial use", tone-colour cloning [source: MyShell, "myshell-ai/OpenVoiceV2",
  https://huggingface.co/myshell-ai/OpenVoiceV2, read 2026-11-16]. Chatterbox also ships a voice-conversion API
  [source: Resemble AI, "example_vc.py", https://raw.githubusercontent.com/resemble-ai/chatterbox/master/example_vc.py, read 2026-11-16].
- Seed-VC is GPL-3.0 (code and weights) and was archived on 2025-11-21 [source: Plachtaa, "seed-vc",
  https://github.com/Plachtaa/seed-vc, read 2026-11-16]. Usable as an offline tool, not recommended.
- TTS-Audio-Suite offers voice conversion through RVC, Chatterbox and CosyVoice3 [source: diodiogod,
  "TTS-Audio-Suite", https://github.com/diodiogod/TTS-Audio-Suite, read 2026-11-16].

**Finding.** Identity = a committed reference clip per character, used by every engine; RVC per character is the
second stage only if a listening pass hears the speech and non-verbal engines drift apart.

## 4. Non-verbal vocalisations, efforts, creatures, crowds

- General sound generators do not do voices: Stable Audio Open 1.0 and Small say they cannot generate realistic
  vocals; their Stability AI Community Licence ends above USD 1M annual revenue and requires "Powered by Stability
  AI" when distributing the materials [source: Stability AI, "stabilityai/stable-audio-open-1.0",
  https://huggingface.co/stabilityai/stable-audio-open-1.0, read 2026-11-16] [source: Stability AI, "LICENSE.md
  (stable-audio-open-1.0)", https://huggingface.co/stabilityai/stable-audio-open-1.0/blob/main/LICENSE.md, read
  2026-11-16] [source: Stability AI, "stabilityai/stable-audio-open-small", https://huggingface.co/stabilityai/stable-audio-open-small, read 2026-11-16].
- AudioLDM2 (CC BY-NC-SA 4.0) [source: CVSSP, "cvssp/audioldm2", https://huggingface.co/cvssp/audioldm2, read
  2026-11-16], TangoFlux (non-commercial) [source: declare-lab, "declare-lab/TangoFlux",
  https://huggingface.co/declare-lab/TangoFlux, read 2026-11-16], MMAudio (checkpoints CC-BY-NC 4.0) [source:
  hkchengrex, "MMAudio", https://github.com/hkchengrex/MMAudio, read 2026-11-16] and AudioGen (weights CC-BY-NC 4.0)
  [source: Meta, "audiocraft", https://github.com/facebookresearch/audiocraft, read 2026-11-16] are non-commercial.
- ACE-Step 1.5 (installed) is a music model: lyrics, repaint, cover; neither its README nor its card claims
  vocalisations or sound effects [source: ACE-Step, "ACE-Step-1.5", https://github.com/ace-step/ACE-Step-1.5, read
  2026-11-16] [source: ACE-Step, "ACE-Step/Ace-Step1.5", https://huggingface.co/ACE-Step/Ace-Step1.5, read 2026-11-16].
  It may still make a wordless chanted crowd "hey!" bed for the score, which is a music task.
- Sound libraries: the Sonniss GDC bundle and Freesound licence pages were blocked. A snippet says the Sonniss bundle
  forbids AI training since 2024 [source: GameFromScratch, "Sonniss 27.5GB+ Sound Effect Giveaway at GDC 2024",
  https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/, unread: snippet only]. Not usable
  until the licence itself is read.

**Findings.**
1. Human non-verbals (laughs, whoops, cheers, grunts, efforts, gasps) come from tagged TTS in the character's own
   voice: Dia (Chatterbox, which also had laugh/chuckle/cough tags, was dropped on 2026-11-16, §10.4).
2. Because Dia's short clips sound unnatural (§2), a stinger is rendered inside a short carrier phrase and trimmed at
   word boundaries, or rendered as a 5–8 s "reel" of several cues and cut. [UNSOURCED: plan/provenance-audit.md#V-01]
   (a working assumption to test in the pilot, not a documented technique).
3. A crowd cheer is a layered bed: 6–10 Dia takes of `(applause)`/cheering from different cast identities, offset and
   panned to mono, plus the radio chain. No crowd model is needed.
4. Brood voices keep the shipped technique (performance, then reversal and pitch-down; `plan/battle-metal-radio-research.md`)
   and gain growls and snarls from Dia `(groans)`/`(screams)` takes pitched down, layered with the pipeline's existing
   procedural glottal growl (`tools/comms_pipeline.py` `grunts` stage).

## 5. Radio FX and loudness

- Our radio chain is our own code in `tools/comms_pipeline.py` (band-pass, presence peak, tanh saturation, hiss,
  squelch keying; `audio.json` `radio`). It works and stays. The #1103 node pack's EQ, Saturate, Compressor and
  NormalizeLoudness nodes (`plan/render-runs/RESUME.md`) can host the same chain in the studio later.
- Offline helpers: Spotify pedalboard (Bitcrush, filters, GSMFullRateCompressor, MP3Compressor; GPLv3, bundles Rubber
  Band) [source: Spotify, "pedalboard", https://github.com/spotify/pedalboard, read 2026-11-16]; Rubber Band
  GPL-2.0-or-later [source: Breakfast Quay, "rubberband", https://github.com/breakfastquay/rubberband, read
  2026-11-16]; LSP plugins LGPLv3 [source: LSP, "lsp-plugins", https://github.com/lsp-plugins/lsp-plugins, read
  2026-11-16]; ffmpeg is LGPL 2.1+ by default and GPL with librubberband [source: FFmpeg, "LICENSE.md",
  https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/LICENSE.md, read 2026-11-16]. Offline rendering with GPL
  tools puts no obligation on the shipped audio files; only linking them into the game would. ffmpeg's `loudnorm`
  defaults to I −24, TP −2 and needs two passes for linear mode [source: FFmpeg, "af_loudnorm.c",
  https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/libavfilter/af_loudnorm.c, read 2026-11-16]. The host
  `audio.transform` appliance already offers loudness normalisation, rubberband stretch and Opus encode with
  provenance sidecars (tool description, 2026-11-16).
- Loudness meters: momentary loudness is the last 400 ms and short-term the last 3 s [source: jiixyj, "libebur128
  ebur128.h", https://raw.githubusercontent.com/jiixyj/libebur128/master/ebur128/ebur128.h, read 2026-11-16].
  Integrated loudness is gated over 400 ms blocks, so a stinger shorter than that has no complete block
  [UNSOURCED: plan/provenance-audit.md#V-02] (ITU-R BS.1770 and EBU Tech 3341 were blocked).
- Game targets: snippets attribute −18 LUFS ±2 LU and −1 dBTP for mobile and −24 for console to an Audiokinetic
  article [source: Audiokinetic, "Mastering a Game with Wwise Part 1", https://www.audiokinetic.com/en/blog/mastering-a-game-with-wwise-part1, unread: snippet only]
  and −16 mobile to GANG IESD [source: GANG IESD, "IESD Mix Ref Levels v03.02", https://www.audiogang.org/wp-content/uploads/2015/04/IESD-Mix-Ref-Levels-v03.02.pdf, unread: snippet only].
  Not sourced: [UNSOURCED: plan/provenance-audit.md#V-03]. Our −18 LUFS speech target is a project decision already
  tuned in play (`audio.json` `loudness`), not a claim from these documents, so it stays.

## 6. Authoring and direction

- SSML 1.1 has `prosody` (pitch, rate, volume), `emphasis` and `break` [source: W3C, "Speech Synthesis Markup Language
  (SSML) Version 1.1", https://www.w3.org/TR/speech-synthesis11/, read 2026-11-16]. None of the open models read
  claims to honour SSML; each has its own syntax (parenthesised style text, bracket or angle tags, knobs, vectors).
  So the script format is engine-neutral fields (emotion, intensity, direction, cues) translated per engine, not SSML.
- TTS-Audio-Suite (ComfyUI, code MIT, each engine keeps its own licence) has `[Alice]` character switching, `[pause:1s]`,
  SRT timing, IndexTTS-2 emotion vectors and Step-Audio-EditX edits, 19 engines [source: diodiogod,
  "TTS-Audio-Suite", https://github.com/diodiogod/TTS-Audio-Suite, read 2026-11-16]. It is the most complete ComfyUI
  front end, but it does not cover VoxCPM2 or Dia (same source), and it would be a large third-party node pack to
  admit. Our script, takes and picks already live in `lines.json`, the Lua production runner and the render ledgers.
- Ollama: MIT, local REST server; its `format` parameter accepts a JSON schema [source: Ollama, "ollama",
  https://github.com/ollama/ollama, read 2026-11-16] [source: Ollama, "api.md",
  https://raw.githubusercontent.com/ollama/ollama/main/docs/api.md, read 2026-11-16]. Use: draft `emotion`,
  `intensity`, `direction` and cue placements, and alternative wordings, against a schema; every draft passes the
  tone check and an agent's review before it enters `lines.json`. It never writes the bank directly.
- No open "voice director" tool for takes and picks was found. The take/pick ledger is ours (spec).

## 7. Fit: ComfyUI, ollama, separate container

| Option | Fit | Verdict |
|---|---|---|
| TTS as admitted ComfyUI nodes in the existing studio | One GPU queue, admission and licence register, provenance; the #1103 audio nodes chain after it | **Chosen** (coordinator's frame) |
| A standalone TTS server container (Gradio/FastAPI/vLLM) | Second GPU tenant beside ComfyUI | Ruled out by the coordinator |
| CPU in the forge (as in 2026-11-12) | 12 GiB cgroup, ~15 cores per worker, slow; no CPU engine is planned since Chatterbox was dropped (§10.4) | Not planned |
| ollama | Text drafting only | Optional helper (§6) |

VRAM budget on the 24 GB A5000: VoxCPM2 ~8 GB + Dia ~4.4 GB ≈ 12.4 GB, both resident, by the sources' figures (§2).
ACE-Step 1.5 XL needs about 20 GB without offload [source: ACE-Step, "ACE-Step-1.5",
https://github.com/ace-step/ACE-Step-1.5, read 2026-11-16], so voice and music batches cannot share the GPU: run them
one at a time and free memory with `gpu.unload_model` between them.

## 8. Recommendation (operator decisions of 2026-11-16 applied, §10.4)

**Stack**

1. Speech, placeholders and final: **VoxCPM2** (2B, Apache-2.0, ~8 GB, 48 kHz) with per-line style text built from
   `emotion`, `intensity` and `direction`, conditioned on each character's committed identity clip. A placeholder is
   a quick single take; a final is a picked take (spec, "Placeholder to final swap"). New characters (tip officers,
   guests) by voice design, then frozen as identity clips.
2. Non-verbals and efforts: **Dia 1.6B** (Apache-2.0, ~4.4 GB) in the character's cloned voice, rendered as reels
   and cut into stingers; crowd cheers layered from several identities.
3. Brood: today's reversal and pitch-down on the speech performances, plus Dia growls pitched down and the
   procedural growl layer.
4. Radio chain, loudness and encode: unchanged code in `tools/comms_pipeline.py`; later the #1103 audio nodes.
5. Direction: `lines.json` v5 fields, the tone check, optional ollama drafts; takes and picks in
   `plan/render-runs/voice-<batch>/`.

**Pilot bake-off for the speech engine.** Two stronger expressive models compete with VoxCPM2 on the same 20 pilot
lines (spec task 6.1), from the same identity clips. Their licences leave the audio ours, and the operator accepts
non-commercial use with a credit line (§10.4). Both need the operator's `/accept-licence` signature first
(`plan/licences-to-sign.md`):

- **Fish Audio S2-Pro**: free-form inline tags and emotion ("fine-grained inline control of prosody and emotion"),
  multi-speaker, cloning [source: Fish Audio, "fishaudio/s2-pro", https://huggingface.co/fishaudio/s2-pro, read
  2026-11-16]. It could do speech *and* non-verbals in one engine, which fits the cue design best. Credit: "Built
  with Fish Audio".
- **Higgs Audio v2**: the highest published emotion score of the set (75.7 % win rate over gpt-4o-mini-tts on
  Emotions) [source: Boson AI, "bosonai/higgs-audio-v2-generation-3B-base",
  https://huggingface.co/bosonai/higgs-audio-v2-generation-3B-base, read 2026-11-16], multi-speaker. Credit: the
  "Built with Higgs Materials … and Meta Llama 3 …" line; the Llama 3 terms come with it.

If a challenger wins most lines, it becomes the speech engine (and, for Fish S2-Pro, possibly the non-verbal engine
too). VoxCPM2 + Dia stay the fallback with no licence conditions. **Qwen3-TTS** (Apache-2.0, instruction control,
VoiceDesign) is the next candidate if all three disappoint; VRAM not stated.

**Dropped:** Chatterbox, Chatterbox-Turbo and -Nano (operator, 2026-11-16). The shipped 2026-11-12 bank keeps its
Chatterbox takes, and the credits keep crediting them, until each clip is re-rendered.

**IndexTTS-2.5 stays out** (operator, 2026-11-16). Condition for revisiting it: a need that VoxCPM2, Fish S2-Pro and
Higgs v2 cannot meet, such as exact duration control to fit a line to a cue or a cinematic shot. IndexTTS 2.5 has a
`duration_factor` speed control [source: bilibili Index team, "index-tts/index-tts README",
https://github.com/index-tts/index-tts, read 2026-11-16]; if such a need appears, its licence questions (§10.2) come
back to the operator with it.

**Still out** (§10.2): Higgs v3 and Coqui XTTS-v2 (their licences restrict the outputs themselves), Echo-TTS
(outputs CC-BY-NC-SA by its own README), Fish S1-mini (CC-BY-NC-SA, licence text gated and unread), VibeVoice (TTS
code removed; an audible AI disclaimer in every file), F5-TTS (no emotion control, so nothing to gain). AudioLDM2,
TangoFlux, MMAudio and AudioGen stay out of the voice work because none of them does vocals (§4).

## 9. What this forge needs (for the coordinator, via the lead)

### 9.0 Installed today (checked 2026-11-16)

- Forge: no TTS binary or package (`kokoro`, `torch`, `chatterbox`, `espeak-ng`, `piper`, `flite`, `festival` all
  absent; no Hugging Face cache); ffmpeg 9.0.2 without libflite; no `ollama` CLI.
- Studio (`studio.models`, tray 56.11.15.5): image models and ACE-Step 1.5 XL turbo/base with encoders and VAE. No
  TTS. Studio running, 23.3 GB VRAM free (`gpu.status`).
- Host audio appliance: `audio.transform` (loudness, stretch, Opus/AAC, resample), `audio.detect_glitches`,
  `audio.separate` (Demucs, non-commercial weights). No synthesis.

So no placeholder could be rendered within "already installed, no new download, no new nodes". Placeholders now wait
for VoxCPM2's admission.

### 9.1 Requests, in priority order

"VRAM" is the source's own figure. Where the source states none, the weights-only size at bf16 (2 bytes per
parameter) is given as an arithmetic floor, marked "est."; real use needs more. "OK for this repo?" is from §10.

| # | Model | Params | VRAM | Licence (weights) | OK for this repo? | Reason | Role |
|---|---|---|---|---|---|---|---|
| 1 | **VoxCPM2** | 2B | ~8 GB | Apache-2.0 | **Yes** | Apache-2.0, "free for commercial use"; no condition on audio | Speech: placeholders and final |
| 2 | **Dia 1.6B** | 1.6B | ~4.4 GB bf16 | Apache-2.0 | **Yes** | Apache-2.0 LICENSE; the card's "research and educational use" and misuse rules are not in the licence; we clone only our own synthetic voices | Non-verbals |
| 3 | **Fish Audio S2-Pro** | ~5B | "at least 24GB" (fish-speech docs); runs 4-bit NF4 on the A5000, exclusive (2026-11-17, `plan/audio-voices-research.md` §2.2) | Fish Audio Research License | **Yes** (operator, 2026-11-16; signature pending) | Outputs are ours and not Derivative Works; non-commercial use with the credit "Built with Fish Audio" | Pilot challenger (speech + tags) |
| 4 | **Higgs Audio v2** (3B base) | ~6B total | not stated; est. ≥ 12 GB | Boson Higgs Audio 2 Community License + Meta Llama 3 Community License | **Yes** (operator, 2026-11-16; two signatures pending) | Outputs unrestricted except training other LLMs; credit line; under 100k annual active users; Llama 3 terms and Acceptable Use Policy | Pilot challenger (emotion) |
| 5 | A Whisper-class ASR model | not researched | not researched | check at admission | — | Not researched | Take rejection |
| 6 | Optional: **RVC** | small | not stated | MIT | **Yes** | MIT code and weights | Timbre lock if engines drift |
| 7 | Optional: **Qwen3-TTS** VoiceDesign 1.7B | 1.7B | not stated; est. ≥ 3.4 GB | Apache-2.0 | **Yes** | Apache-2.0 LICENSE | Second fallback |
| — | IndexTTS-2.5 | ~0.8B | ~6 GB | bilibili Model Use License | **No** (operator, 2026-11-16) | Revisit only for a need the others cannot meet, e.g. exact duration control | — |
| — | Chatterbox, -Turbo, -Nano | | | MIT | Dropped (operator, 2026-11-16) | VoxCPM2 covers placeholders | — |
| — | Higgs v3, XTTS-v2, Echo-TTS, Fish S1-mini, VibeVoice, F5-TTS | | | | **No** | §10.2 | — |

Node requirements for every TTS node: seed input; output AUDIO at the native rate (no resample, no normalise); the
admission record carries repo, revision, file hashes, licence and the required credit line; save through the #1103
save node with provenance. VoxCPM2 + Dia fit resident together (~12.4 GB); a challenger runs alone, unloaded with
`gpu.unload_model` between engines; voice and ACE-Step music batches run one after the other. Re-check the Maya1
LICENSE at admission if it is ever proposed (card only read).

### 9.2 Nothing else

No new container, no forge-side GPU, no direct pulls. ollama, which the operator says is available, needs only an
endpoint the forge may call if line drafting (§6) is wanted.

## 10. Licence re-evaluation for a free GPL-3.0 game (Round 3d, 2026-11-16)

Operator: "We're not using them commercially, our software is free and open source, and so are our games." This
section reports what the licence texts say. It is not legal advice; the points where the operator must decide are
marked **Decide**; §10.4 records how the operator resolved them.

### 10.1 What the repo ships under

- The repo's only licence file is `LICENSE`, GPL-3.0. GPL-3.0 §0: "The Program" refers to any copyrightable work
  licensed under this License. §10: "You may not impose any further restrictions on the exercise of the rights
  granted or affirmed under this License." §7 lists the only additional terms allowed (warranty disclaimers,
  preserved notices or author attributions, no misrepresentation of origin, limits on publicity use of names,
  trademarks, indemnification); "All other non-permissive additional terms are considered 'further restrictions'".
  §5 lets separate, independent works sit beside a covered work as an "aggregate" without the GPL applying to them.
  §2: output of a covered work is covered "only if the output, given its content, constitutes a covered work".
  [source: SPDX, "GPL-3.0-only.txt", https://raw.githubusercontent.com/spdx/license-list-data/main/text/GPL-3.0-only.txt, read 2026-11-16]
  (the same text as the repo's `LICENSE`).
- `licences/` holds one signed acknowledgement (Demucs, `use: non-sale`, internal analysis only); its spec says
  "every shipped sound is rendered from the project's own sources by tools whose licences allow commercial use"
  (`openspec/specs/third-party-licence-demucs-weights-unstated/spec.md`). No file in the repo gives the audio,
  art or other assets a licence other than the root GPL-3.0, so a reader will take them as GPL-3.0.
- `plan/asset-pipeline/licence-review.md` records the operator's standing approval for free models "we'll not be
  selling any of those assets" (2026-11-01) and an allowlist of licence ids (apache-2.0, mit, bsd, openrail).
- The production site, demonattack.tlatoani.net, is free to play. The repo has no ads, payments or donation links
  (searched `README.md`, `web/`, `lib/`). **Resolved (§10.4):** the game is free and the operator accepts non-commercial licences
  with a credit line; several definitions below still turn on "monetary compensation" or "generate revenue …
  indirectly", so any future revenue (ads, donations, sponsorship) reopens them.
- The FSF's FAQ on game data under other licences (gnu.org) and Creative Commons' FAQ on AI outputs
  (creativecommons.org) were blocked, so neither informs this section.

**What follows for NC audio.** A clip under a licence that forbids commercial use cannot be offered under GPL-3.0,
because GPL-3.0 lets anyone sell copies and forbids further restrictions (§10 above). It could still sit in the repo
as a separate work under its own terms (§5 aggregate), with a licence note naming those files. Then the repo is
"GPL code plus some non-free audio": third parties could not reuse those clips commercially, and a strict
free-software packager would treat them as non-free. **Resolved (§10.4):** no separately licensed audio; IndexTTS stays
out. The recommendation (§8) avoids needing that decision: every "Yes" row leaves the audio unrestricted.

### 10.2 Per licence: does it restrict the outputs?

| Model | Licence read | Outputs restricted? | Commercial / NC terms | Credit or notice | OK for this repo? |
|---|---|---|---|---|---|
| VoxCPM2 | Apache-2.0 LICENSE | No | Free for commercial use | Apache notice for the weights only (not shipped) | **Yes** |
| Dia 1.6B | Apache-2.0 LICENSE; card adds "intended for research and educational use" and bans identity misuse, deception, illegal use | No (card rules are about use; we clone only synthetic voices) | none in the licence | none for audio | **Yes** |
| Chatterbox / Turbo | MIT LICENSE | No; every file carries an imperceptible Perth watermark | none | none | Yes by licence; dropped by the operator (§10.4) |
| Qwen3-TTS | Apache-2.0 LICENSE | No | none | none | **Yes** |
| Fish S2-Pro | Fish Audio Research License (2026-03-07) | **No.** Derivative Works "do not include the output of any Model"; "You own any outputs" | Grant for "Research or Non-Commercial Purpose"; Non-Commercial includes "personal use (i.e., hobbyist)"; Commercial includes "distributing Your product or service" and use "for which You charge a fee or generate revenue, whether directly or indirectly" | Credit "Built with Fish Audio" on a related website | **Yes** (operator, 2026-11-16: non-commercial with credit is acceptable); audio itself can be GPL |
| Higgs Audio v2 | Boson Higgs Audio 2 Community License (Llama 3 based, incorporated by reference) | Only: no use of outputs to improve other LLMs | Royalty-free, commercial allowed; expanded licence above 100,000 annual active users | "Built with Higgs Materials licensed from Boson AI USA, Inc. …" displayed prominently | **Yes** (operator, 2026-11-16; credit line; Llama 3 terms signed with it) |
| IndexTTS2 / 2.5 | bilibili Model Use License Agreement | **Yes, in part**: outputs fall under "Derivative Work", which must keep notices and a copy of the agreement, carry a non-endorsement disclaimer when distributed, follow content rules, and not be used to improve other AI models except non-commercial ones | Royalty-free; thresholds 100M monthly users or RMB 1bn revenue | Notices + licence copy with every Derivative Work | **No** (operator, 2026-11-16): the conditions follow the clips, so they could not be plain GPL; revisit only for a need the others cannot meet (§8) |
| Higgs Audio v3 | Boson Higgs TTS 3 Research and Non-Commercial License ("not an open source license") | **Yes**: outputs used for a Commercial Purpose need a licence, and Commercial Purpose includes "any use made available to end users outside Your organization" | Creator Use Grant covers podcasts and videos, not an application | several | **No**: a public website is outside the grant |
| Coqui XTTS-v2 | Coqui Public Model License 1.0.0 | **Yes**: "only non-commercial use of a machine learning model and its outputs"; anyone who gets the output must get the terms | NC only; no direct or indirect payment | Terms travel with outputs | **No**: incompatible with GPL audio |
| Echo-TTS | weights CC-BY-NC-SA-4.0; README | **Yes**: "audio outputs are CC-BY-NC-SA-4.0 due to the dependency on the Fish Speech S1-DAC autoencoder" | NC-SA | CC attribution | **No** |
| Fish S1-mini | CC-BY-NC-SA-4.0 per card; LICENSE gated (HTTP 401), unread | Not established; Echo-TTS's README says the S1 codec makes outputs NC-SA | NC-SA | — | **No** (unverifiable; superseded by S2-Pro) |
| F5-TTS | weights CC-BY-NC "due to the training data Emilia"; code MIT | Not addressed; CC-BY-NC reaches an output only if it is "Adapted Material" needing permission | NC: "not primarily intended for … commercial advantage or monetary compensation" | CC attribution | **No**: unclear, and it has no emotion control, so nothing to gain |
| VibeVoice | MIT LICENSE; card: "limited to research purpose", "not recommended … in commercial or real-world applications" | Not by the licence, but every file embeds an audible "This segment was generated by AI" disclaimer and a watermark; TTS code removed from the repo (2025-09-05) | — | — | **No**: unusable for game lines |
| Stable Audio Open (ambience only) | Stability AI Community License | No: "You own any outputs"; outputs are not Derivative Works; no use of outputs to train foundation models | Licence ends above USD 1M annual revenue | "Powered by Stability AI" when distributing the materials | Yes for crowd ambience, if wanted |

Sources for 10.2:
VoxCPM2 [source: OpenBMB, "VoxCPM LICENSE", https://raw.githubusercontent.com/OpenBMB/VoxCPM/main/LICENSE, read 2026-11-16];
Dia [source: Nari Labs, "dia LICENSE", https://raw.githubusercontent.com/nari-labs/dia/main/LICENSE, read 2026-11-16]
[source: Nari Labs, "nari-labs/Dia-1.6B", https://huggingface.co/nari-labs/Dia-1.6B, read 2026-11-16];
Chatterbox [source: Resemble AI, "chatterbox LICENSE", https://raw.githubusercontent.com/resemble-ai/chatterbox/master/LICENSE, read 2026-11-16]
[source: Resemble AI, "resemble-ai/chatterbox README", https://github.com/resemble-ai/chatterbox, read 2026-11-16];
Qwen3-TTS [source: Qwen, "Qwen3-TTS LICENSE", https://raw.githubusercontent.com/QwenLM/Qwen3-TTS/main/LICENSE, read 2026-11-16];
Fish S2-Pro [source: Fish Audio / 39 AI, Inc., "FISH AUDIO RESEARCH LICENSE AGREEMENT", https://huggingface.co/fishaudio/s2-pro/raw/main/LICENSE.md, read 2026-11-16]
[source: Fish Audio, "fishaudio/s2-pro", https://huggingface.co/fishaudio/s2-pro, read 2026-11-16];
Higgs v2 [source: Boson AI, "LICENSE", https://huggingface.co/bosonai/higgs-audio-v2-generation-3B-base/raw/main/LICENSE, read 2026-11-16]
[source: Boson AI, "bosonai/higgs-audio-v2-generation-3B-base", https://huggingface.co/bosonai/higgs-audio-v2-generation-3B-base, read 2026-11-16];
IndexTTS [source: bilibili, "LICENSE", https://raw.githubusercontent.com/index-tts/index-tts/main/LICENSE, read 2026-11-16]
[source: bilibili, "LICENSE", https://huggingface.co/IndexTeam/IndexTTS-2.5/raw/main/LICENSE, read 2026-11-16]
[source: IndexTeam, "IndexTeam/IndexTTS-2.5", https://huggingface.co/IndexTeam/IndexTTS-2.5, read 2026-11-16];
Higgs v3 [source: Boson AI, "LICENSE", https://huggingface.co/bosonai/higgs-audio-v3-tts-4b/raw/main/LICENSE, read 2026-11-16];
XTTS-v2 [source: Coqui, "LICENSE.txt", https://huggingface.co/coqui/XTTS-v2/raw/main/LICENSE.txt, read 2026-11-16];
Echo-TTS [source: jordandare, "echo-tts README", https://raw.githubusercontent.com/jordandare/echo-tts/main/README.md, read 2026-11-16]
[source: jordand, "jordand/echo-tts-base", https://huggingface.co/jordand/echo-tts-base, read 2026-11-16];
Fish S1-mini [source: Fish Audio, "fishaudio/openaudio-s1-mini", https://huggingface.co/fishaudio/openaudio-s1-mini, read 2026-11-16];
F5-TTS [source: SWivid, "F5-TTS README", https://raw.githubusercontent.com/SWivid/F5-TTS/main/README.md, read 2026-11-16]
[source: SWivid, "SWivid/F5-TTS", https://huggingface.co/SWivid/F5-TTS, read 2026-11-16];
CC BY-NC 4.0 [source: SPDX, "CC-BY-NC-4.0.txt", https://raw.githubusercontent.com/spdx/license-list-data/main/text/CC-BY-NC-4.0.txt, read 2026-11-16];
VibeVoice [source: Microsoft, "VibeVoice LICENSE", https://raw.githubusercontent.com/microsoft/VibeVoice/main/LICENSE, read 2026-11-16]
[source: Microsoft, "microsoft/VibeVoice-1.5B", https://huggingface.co/microsoft/VibeVoice-1.5B, read 2026-11-16]
[source: Microsoft, "VibeVoice README", https://raw.githubusercontent.com/microsoft/VibeVoice/main/README.md, read 2026-11-16];
Stable Audio Open [source: Stability AI, "LICENSE.md (Stability AI Community License)", https://huggingface.co/stabilityai/stable-audio-open-1.0/blob/main/LICENSE.md, read 2026-11-16].
Licence quotes came through a page summariser that returns fragments of long clauses; the fragments are exact, and
the admission review reads the full texts.

### 10.3 What the production site needs

- For every "Yes" row: nothing on the site beyond what the credits already do, plus the credit line where one is
  required (Fish S2-Pro "Built with Fish Audio"; Higgs v2 "Built with Higgs Materials licensed from Boson AI USA,
  Inc., Copyright Boson AI USA, Inc., All Rights Reserved and Meta Llama 3 licensed under the Meta Llama 3 Community
  License, Copyright Meta Platforms, Inc., All Right Reserved", the full line in the licence text, read 2026-11-16
  for `plan/licences-to-sign.md`). The credits page lists every production model, so the lines go there
  (`tools/generate_credits.lua` → `assets/credits.json`).
- The manifest records each clip's engine and licence (spec), so the credits can be generated from what actually
  shipped, and a later licence change can be traced to the clips it touches.
- IndexTTS is out (§10.4), so no separately licensed clips ship.
- The credit lines are generated into `assets/credits.json` by `tools/generate_credits.lua` (done 2026-11-16).
- No weights are ever shipped or committed (the studio holds them), so no model's redistribution terms reach the
  repo.

### 10.4 Operator decisions (2026-11-16, relayed by the coordinator)

1. **Chatterbox is dropped** (with Turbo and Nano). VoxCPM2 renders placeholders and final speech; Dia renders the
   non-verbals. Its pin left `art/comms/audio.json`; the CPU worker tools that ran it were removed from
   `tools/production/`; the credits keep it for the shipped 2026-11-12 takes until they are re-rendered.
2. **Non-commercial with a credit line is acceptable**: the game is free and open source, and the credits page lists
   every model and licence. Fish Audio S2-Pro and Higgs Audio v2 are pilot challengers; their credit lines are in
   `assets/credits.json`. The signatures are prepared in `plan/licences-to-sign.md` (Fish Audio Research License,
   Boson Higgs Audio 2 Community License, Meta Llama 3 Community License with its Acceptable Use Policy).
3. **IndexTTS-2.5 stays out**, revisited only for a need the others cannot meet, such as exact duration control to
   fit a cue (§8).
4. Restricted licences are signed through `/accept-licence`, project by project; Apache-2.0 and MIT need no
   signature.
