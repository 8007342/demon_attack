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
| IndexTTS2 (bilibili) | 8-value emotion vector, emotion text, emotion reference clip, `emo_alpha` | none | Zero-shot cloning | not stated | bilibili Model Use License: commercial use needs a request | webui; in TTS-Audio-Suite |
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

**Excluded for licence** (weights not usable commercially, or only with a separate agreement): F5-TTS weights CC-BY-NC
[source: SWivid, "SWivid/F5-TTS README", https://github.com/SWivid/F5-TTS, read 2026-11-16]; OpenAudio S1-mini
CC-BY-NC-SA-4.0 and Fish S2-Pro "Fish Audio Research License" [source: Fish Audio, "fishaudio/fish-speech README",
https://github.com/fishaudio/fish-speech, read 2026-11-16] [source: Fish Audio, "fishaudio/s2-pro",
https://huggingface.co/fishaudio/s2-pro, read 2026-11-16]; Higgs Audio v3 non-commercial, and v2 under a community
licence with a 100,000-annual-user cap, a "Built with Higgs Materials" notice and an output-use restriction [source:
Boson AI, "LICENSE", https://huggingface.co/bosonai/higgs-audio-v2-generation-3B-base/blob/main/LICENSE, read
2026-11-16] [source: Boson AI, "boson-ai/higgs-audio README", https://github.com/boson-ai/higgs-audio, read
2026-11-16]; VibeVoice, which Microsoft calls research-only and whose TTS code was pulled in September 2025 [source:
Microsoft, "microsoft/VibeVoice README", https://github.com/microsoft/VibeVoice, read 2026-11-16]; IndexTTS2 (above).
Kyutai TTS weights are CC-BY 4.0 (attribution) but clone only from Kyutai's own voice embeddings [source: Kyutai,
"kyutai/tts-1.6b-en_fr", https://huggingface.co/kyutai/tts-1.6b-en_fr, read 2026-11-16], so it cannot hold our
cast. MOSS-TTSD states no weights licence [source: OpenMOSS, "OpenMOSS/MOSS-TTSD README",
https://github.com/OpenMOSS/MOSS-TTSD, read 2026-11-16].

**Findings.**
1. For emotional speech with a commercial-clean licence, VoxCPM2 is the strongest fit: Apache-2.0 code and weights
   stated as free for commercial use, text style direction per line, voice design for new characters, cloning from
   our committed identity clips, 48 kHz output and a stated ~8 GB (sources above). It has no non-verbal tags.
2. For tags (laughs, groans, screams, applause, gasps), Dia 1.6B has the widest documented set under Apache-2.0 at
   ~4.4 GB, with the caveat that clips under ~5 s sound unnatural and unlisted tags cause artefacts (Dia sources
   above). Maya1 has a comparable set but asks for 16 GB+ and cannot clone, so it cannot hold our cast.
3. Chatterbox-Turbo adds native `[laugh]`/`[chuckle]`/`[cough]` to the engine we already know, under MIT, but the
   project is retired and unmaintained since August 2026 and every output is watermarked (Chatterbox sources above).
   It is the right placeholder engine (§8) and a poor long-term base.

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
   voice: Dia first, Chatterbox-Turbo for laugh/chuckle/cough while it is the placeholder engine (§2).
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
| CPU in the forge (as in 2026-11-12) | 12 GiB cgroup, ~15 cores per worker, slow; Chatterbox-Nano would be 3× realtime on 8 cores (§2) | Placeholder only |
| ollama | Text drafting only | Optional helper (§6) |

VRAM budget on the 24 GB A5000: VoxCPM2 ~8 GB + Dia ~4.4 GB ≈ 12.4 GB, both resident, by the sources' figures (§2).
ACE-Step 1.5 XL needs about 20 GB without offload [source: ACE-Step, "ACE-Step-1.5",
https://github.com/ace-step/ACE-Step-1.5, read 2026-11-16], so voice and music batches cannot share the GPU: run them
one at a time and free memory with `gpu.unload_model` between them.

## 8. Recommendation

**Primary stack**

1. Speech: **VoxCPM2** (2B, Apache-2.0, ~8 GB, 48 kHz) with per-line style text built from `emotion`, `intensity`
   and `direction`, conditioned on each character's committed identity clip. New characters (tip officers, guests)
   by voice design, then frozen as identity clips.
2. Non-verbals and efforts: **Dia 1.6B** (Apache-2.0, ~4.4 GB) in the character's cloned voice, rendered as reels
   and cut into stingers; crowd cheers layered from several identities.
3. Brood: today's reversal and pitch-down on VoxCPM2 performances, plus Dia growls pitched down and the procedural
   growl layer.
4. Radio chain, loudness and encode: unchanged code in `tools/comms_pipeline.py`; later the #1103 audio nodes.
5. Direction: `lines.json` v5 fields, the tone check, optional ollama drafts; takes and picks in
   `plan/render-runs/voice-<batch>/`.

**Fallback**: **Chatterbox-Turbo** (350M, MIT, `[laugh]`/`[chuckle]`/`[cough]`) plus the original Chatterbox
(`exaggeration`) for everything, with a lower ceiling on expressiveness. It is the engine the current bank was made
with, so the cast stays consistent, and Nano runs on CPU. Its retirement means pinning a revision and not expecting
fixes. If VoxCPM2's style text proves too weak in the pilot, **Qwen3-TTS** (Apache-2.0, instruction control,
VoiceDesign) is the next candidate; its VRAM is not stated.

**Do not use** for shipped audio: F5-TTS, Fish/OpenAudio, Higgs v2/v3, VibeVoice, IndexTTS2 (without bilibili's
agreement), AudioLDM2, TangoFlux, MMAudio, AudioGen (§2, §4).

## 9. What this forge needs (for the coordinator, via the lead)

### 9.0 Installed today (checked 2026-11-16)

- Forge: no TTS binary or package (`kokoro`, `torch`, `chatterbox`, `espeak-ng`, `piper`, `flite`, `festival` all
  absent; no Hugging Face cache); ffmpeg 9.0.2 without libflite; no `ollama` CLI.
- Studio (`studio.models`, tray 56.11.15.5): image models and ACE-Step 1.5 XL turbo/base with encoders and VAE. No
  TTS. Studio running, 23.3 GB VRAM free (`gpu.status`).
- Host audio appliance: `audio.transform` (loudness, stretch, Opus/AAC, resample), `audio.detect_glitches`,
  `audio.separate` (Demucs, non-commercial weights). No synthesis.

So no placeholder could be rendered within "already installed, no new download, no new nodes".

### 9.1 Requests, in priority order

| # | What | Size | VRAM (source's figure) | Licence | Form | Why |
|---|---|---|---|---|---|---|
| 1 | **Chatterbox** original + **Turbo** (+ Nano for CPU), pinned (`audio.json` already pins `ResembleAI/chatterbox` rev `5bb1f6ee…`) | 500M + 350M (+110M) | not stated | MIT / MIT, watermarked | Studio node (TTS-Audio-Suite has a Chatterbox engine) or a minimal admitted node | Placeholders now; fallback engine; same voices as today's bank |
| 2 | **VoxCPM2** (OpenBMB) | 2B | ~8 GB | Apache-2.0 / Apache-2.0 | Studio node: text + style prompt + reference clip (+ transcript) → AUDIO, seed input | Primary speech engine |
| 3 | **Dia 1.6B** (Nari Labs) | 1.6B | ~4.4 GB bf16 | Apache-2.0 / Apache-2.0 | Studio node: `[S1]` text with tags + reference clip + transcript → AUDIO, seed | Non-verbals, efforts, cheers, growl sources |
| 4 | An ASR model for the accept rule (word match), e.g. a Whisper-class model | not researched | not researched | to check at admission | Studio node or appliance op | Automatic take rejection |
| 5 | Optional: **RVC** inference node and pretrained base | small | not stated | MIT / MIT | Studio node | Only if engines drift apart in timbre |
| 6 | Optional: **Qwen3-TTS** VoiceDesign 1.7B | 1.7B | not stated | Apache-2.0 tag | Studio node | Second fallback for style control |

Node requirements for every TTS node: seed input; output AUDIO at the native rate (no resample, no normalise); the
admission record carries repo, revision, file hashes and licence; save through the #1103 save node with provenance.
VoxCPM2 + Dia fit resident together (~12.4 GB); voice and ACE-Step music batches run one after the other.
Licence re-check at admission: the Dia, Chatterbox, Qwen3-TTS and Maya1 LICENSE files themselves (cards only were
read here).

### 9.2 Nothing else

No new container, no forge-side GPU, no direct pulls. ollama, which the operator says is available, needs only an endpoint the
forge may call if line drafting (§6) is wanted.
