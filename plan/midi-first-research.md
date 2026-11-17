# MIDI-first soundtrack research (adaptive-soundtrack, revision of 2026-11-17)

Status: research for `openspec/changes/adaptive-soundtrack` (design §11). Decisions live in that design; this file
keeps the evidence and its sources (CLAUDE.md §8). Repo facts name their file. Every web source was fetched on
2026-11-17 unless it is marked `unread`. Claims with no read source are marked `[UNSOURCED: plan/provenance-audit.md#<id>]`
(Part M of the audit). The earlier research for this change is `plan/soundtrack-research.md` (R§ below).

## 0. The brief

The operator, 2026-11-17:

> "If we get the proper soundtrack decompositions, what are the chances that the MIDI soundtrack when properly
> engineered and designed will be the better approach to compose our soundtrack dynamically? We just want the models
> to generate the music because they don't output MIDI, but MIDI is the one with the most compression and plays
> everywhere. And we could play and mix the scores dynamically. Please file the necessary research, let's keep MIDI
> as the fallback, but try to make it so it becomes our first layer instead :D"

> "No fallback format, this project is already asset heavy, no need to duplicate assets."

Five questions: (1) audio to MIDI, (2) generating MIDI directly, (3) playing MIDI well on the web and on phones,
(4) the verdict and the architecture, (5) the pipeline. The answers are in §1 to §5, and a short summary is in §6.

## 0.1 Repo facts and the forge probe (measured 2026-11-17, no downloads)

| Id | Fact | Where |
|---|---|---|
| F1 | A full 96-bar, 15-part multitrack score already exists for L3 Ember Moon: drums (GM), bass, two rhythm guitars with separate palm-mute channels, lead, harmony lead, clean lead, clean arpeggios, choir, organ, brass, strings and timpani. It has a conductor track with tempo, key and section markers. Its generator is deterministic. It was written for the #1103 SFZ render (`TillandsiasSFZRender` with Karoryfer `big-rusty-drums`, `meatbass`, `black-and-green-guitars` and `shinyguitar`). | `tools/score_l3.py`, `art/music/scores/README.md`, `art/workflows/music/l3-ember-moon-dry.json` |
| F2 | **Size:** `full.mid` is 68 514 bytes for 129.3 s (530 B/s), and 33 470 bytes gzipped (259 B/s). Opus at 160 kbps is about 20 000 B/s, so the score is about 38× smaller raw and 77× smaller gzipped. | `lua tools/midi_stats.lua art/music/scores/l3-ember-moon/full.mid` (new probe, this change) |
| F3 | **Voice demand:** the whole L3 arrangement peaks at 25 simultaneous notes. Counting a 0.5-beat release tail per note, it peaks at 50. Per part: drums 4, rhythm guitars 3 each, choir, organ and strings 4 each, bass 1. | same probe, `--release 0.5` |
| F4 | The shipped fallback: 38 SMF type-0 cues (`web/audio/midi/`, 72 KB in all, about 3.1 KB per 8-bar tier). They are played by `demon-audio.js` with one oscillator per note (square, saw or sine; a triangle sweep for drums). They omit hats, cymbals, choir, organ, pads and strings ("keep the fallback light"). This is the synth the operator rejected as thin. | `web/audio/generate-midi.py`, `web/audio/demon-audio.js` `voice()` |
| F5 | The recorded carrier pilot (ACE-Step, seven sections, 73 s) is 1.36 MB of Opus. The design estimates the whole run at about 18 MB of Opus. | `plan/render-runs/soundtrack-pilot.md`, design §3.2 |
| F6 | Forge tools: none of fluidsynth, timidity, sfizz, basic-pitch, omnizart, demucs, sox, aubio or midicsv is installed. There are no SF2, SF3 or SFZ files on disk, and no Python music packages (mido, pretty_midi, numpy, torch). Present: ffmpeg (with `afir` and `firequalizer`), Lua 5.4, Go, Rust, Node. | `command -v`, `find`, `python3 -I` import checks |
| F7 | Local LLMs: ollama at `http://inference:11434` serves qwen2.5 0.5b, 3b, 7b and 14b, and qwen2.5vl 7b. I did not run them (no GPU jobs in this task). | `GET /api/tags` |
| F8 | Separation is already admitted: htdemucs and htdemucs_6s, by the operator's acknowledgement (non-sale, scope demon_attack, until 2027-11-14). The host offers `audio.separate`. Separated audio is **internal analysis and reference only and never ships**. | `licences/acknowledgements/adefossez-htdemucs.yaml`, `plan/audio-studio/music-requirements.md` §5 |
| F9 | The game already emits every event a section graph needs, including the structured carrier events: `bossHatchTier`, `bossTransform`, `bossShieldFailing`, `bossModuleLost`, `bossCoreExposed`, `bossCollapseStart`, `bossCollapseEnd`, `fleetIntact`, `musicIntensity`, `waveStart` and `levelClear`. | `lib/game/*.dart`, design §4.3 |

## 1. From audio to MIDI

### 1.1 Stem separation

| Id | Finding | Source |
|---|---|---|
| T1 | Demucs code is MIT, and the README states no separate licence for the pretrained weights. The repository is archived (2025-01-01). On CPU it takes about 1.5× the track length, and the defaults need about 7 GB (`--segment` lowers that). `htdemucs_6s` adds guitar and piano stems: the guitar stem is "okay quality" and the piano stem has "a lot of bleeding and artifacts". | [source: Meta/facebookresearch, "demucs" README, https://github.com/facebookresearch/demucs, read 2026-11-17] |
| T2 | HT Demucs scores 8.80 dB SDR on the MUSDB-HQ test set (fine-tuned 9.00). | [source: Rouard, Massa, Défossez, "Hybrid Transformers for Music Source Separation", https://huggingface.co/papers/2211.08553, read 2026-11-17] |
| T3 | Multisong SDR: SCNet XL 9.92, BS-RoFormer 9.38, HTDemucs4 9.16. In the 6-stem model, bass is 11.22 and drums 10.22. For splitting a drum stem (MDX23C DrumSep): kick 16.66, snare 11.53, toms 12.33, **hi-hat 4.04, cymbals 6.36**. No weight licences are stated. | [source: ZFTurbo, "pretrained_models.md", https://raw.githubusercontent.com/ZFTurbo/Music-Source-Separation-Training/main/docs/pretrained_models.md, read 2026-11-17] |
| T4 | demucs.cpp: MIT C++17 (Eigen, OpenMP). It runs htdemucs, 6s and ft with ggml weights (licence not stated), trading speed for low memory. | [source: sevagh, "demucs.cpp", https://github.com/sevagh/demucs.cpp, read 2026-11-17] |
| T5 | LarsNet (splitting a drum stem into kick, snare, toms, hi-hat and cymbals): weights are **CC BY-NC 4.0**. | [source: polimi-ispl, "larsnet", https://github.com/polimi-ispl/larsnet, read 2026-11-17] |

### 1.2 Transcription per stem

| Id | Finding | Source |
|---|---|---|
| T6 | basic-pitch: Apache-2.0 for code and the in-repo model. Instrument-agnostic and polyphonic, "works best on one instrument at a time", and outputs pitch bends. Ships TF, CoreML, TFLite and **ONNX** models. | [source: Spotify, "basic-pitch", https://github.com/spotify/basic-pitch, read 2026-11-17] |
| T7 | basic-pitch has about 16.8 k parameters. Note F1 without offsets: **GuitarSet 0.79, Slakh 0.42**, MAESTRO 0.71. A 7 min 45 s file took 24 s on a 2017 laptop CPU, peaking at 951 MB. | [source: Bittner et al., "A Lightweight Instrument-Agnostic Model for Polyphonic Note Transcription and Multipitch Estimation", https://huggingface.co/papers/2203.09893, read 2026-11-17] |
| T8 | basicpitch.cpp: MIT, ONNX Runtime plus libremidi, as a CLI and as **WASM**. | [source: sevagh, "basicpitch.cpp", https://github.com/sevagh/basicpitch.cpp, read 2026-11-17] |
| T9 | MT3: code Apache-2.0; the checkpoints carry no stated licence. | [source: Google Magenta, "mt3", https://github.com/magenta/mt3, read 2026-11-17] |
| T10 | YourMT3+: onset F1 84.6 on Slakh (MT3 76), but non-main instruments score **below 10 % on commercial pop**, which the authors blame on synthetic training data. The code is GPL-3.0 on GitHub, while the HF Space card says apache-2.0, a licence conflict. | [source: Chang et al., "YourMT3+", https://huggingface.co/papers/2407.04822, read 2026-11-17]; [source: mimbres, "YourMT3", https://github.com/mimbres/YourMT3, read 2026-11-17] |
| T11 | Omnizart: MIT, with music, drum, chord, vocal and beat modules. Drum training is buggy, but the shipped drum checkpoints work. | [source: MCTLab, "omnizart", https://github.com/Music-and-Culture-Technology-Lab/omnizart, read 2026-11-17] |
| T12 | ADTOF (5-class drum transcription): **CC BY-NC-SA 4.0** for the whole repository. ADTOF-pytorch scores F 88.51 on MDBDrums++, but its licence is not shown. | [source: Zehren, "ADTOF" LICENSE, https://raw.githubusercontent.com/MZehren/ADTOF/master/LICENSE, read 2026-11-17]; [source: xavriley, "ADTOF-pytorch", https://github.com/xavriley/ADTOF-pytorch, read 2026-11-17] |
| T13 | Monophonic f0: CREPE (MIT), FCPE (MIT, with f0→MIDI), RMVPE (Apache-2.0 code). Weight licences are not separately stated. | [source: MARL, "crepe", https://github.com/marl/crepe, read 2026-11-17]; [source: CNChTu, "FCPE", https://github.com/CNChTu/FCPE, read 2026-11-17]; [source: Dream-High, "RMVPE", https://github.com/Dream-High/RMVPE, read 2026-11-17] |
| T14 | Chords instead of notes: Chordino/NNLS-Chroma (GPL-2.0+ Vamp plugin, chord labels plus chord notes); BTC (MIT). | [source: c4dm, "nnls-chroma", https://github.com/c4dm/nnls-chroma, read 2026-11-17]; [source: jayg996, "BTC-ISMIR19", https://github.com/jayg996/BTC-ISMIR19, read 2026-11-17] |
| T15 | Beat This!: MIT for code **and** weights (beats and downbeats). The `beat-this` Rust crate is MIT and runs on the pure-Rust `rten` backend by default. madmom's models are **CC BY-NC-SA 4.0**. Essentia is AGPL-3.0. | [source: CPJKU, "beat_this", https://github.com/CPJKU/beat_this, read 2026-11-17]; [source: docs.rs, "beat-this", https://docs.rs/crate/beat-this/latest, read 2026-11-17]; [source: CPJKU, "madmom", https://github.com/CPJKU/madmom, read 2026-11-17]; [source: MTG, "essentia", https://github.com/MTG/essentia, read 2026-11-17] |
| T16 | Rust and Go ONNX runners: `ort` (MIT/Apache-2.0, ONNX Runtime 1.31); `onnxruntime_go` (MIT, cgo, and ships no Linux AMD64 library). | [source: pykeio, "ort", https://github.com/pykeio/ort, read 2026-11-17]; [source: yalue, "onnxruntime_go", https://github.com/yalue/onnxruntime_go, read 2026-11-17] |
| T17 | Electric guitar transcription with amp re-rendering (EGDB) is an active topic. | [source: Chen et al., "Towards Automatic Transcription of Polyphonic Electric Guitar Music", https://arxiv.org/abs/2202.09907, unread: snippet only] |
| T18 | Separating drum stems before ADT is "the same or slightly better"; separation artifacts keep transcription below optimal. | [source: Riley & Dixon, "Enhanced ADT via Drum Stem Source Separation", https://webspace.eecs.qmul.ac.uk/s.e.dixon/pub/2024/482_lbd.pdf, unread: snippet only]; [source: MERL, "Tackling the Cocktail Fork Problem", https://merl.com/publications/docs/TR2023-113.pdf, unread: snippet only] `[UNSOURCED: plan/provenance-audit.md#midi-sep-artifacts]` |

### 1.3 Realistic accuracy on our dense metal mixes

No source we read benchmarks transcription of metal: distorted guitar, blast beats or cymbal wash
`[UNSOURCED: plan/provenance-audit.md#midi-metal-transcription]`. The table below extrapolates from T3, T7, T10 and
T12, plus our grid knowledge.

| Part | Expected result | Why | What we do |
|---|---|---|---|
| Kick, snare | **good** | separated well (T3: 16.7 and 11.5 dB); ADT models are at F ≈ 0.88 on general material (T12). Blast beats at 190 BPM put 16ths 79 ms apart, which is within frame resolution but untested. | onset detection on the drum stem plus band-split, snapped to the known 16th grid. The NC-licensed ADTOF, LarsNet and madmom models are **not** used. |
| Toms | fair | 12.3 dB separation | the same, then by ear |
| Hats, ride, cymbals | **poor** | 4–6 dB separation (T3), the hardest classes | written by rule on the grid (hat or ride 8ths or 16ths per section style, crash on phrase downbeats) |
| Bass | **good** | 11–12 dB stem; monophonic pitch trackers (T13) or basic-pitch work on a clean line | basic-pitch or f0 tracking, then snapped to the scale and grid |
| Lead guitar, solo lines | fair | monophonic and prominent, but bleed and distortion harmonics | f0 tracking (T13), then by hand |
| Rhythm guitar (distorted chords) | **poor as notes** | distortion harmonics; 6s guitar only "okay" (T1); polyphony in dense mixes F1 0.42 (T7) | **chord labels** (T14) plus root tracking, then voiced as power chords by rule, with the riff rhythm taken from the guitar stem's onsets |
| Choir, organ, pads | **poor** | in "other" or "piano" (T1), heavy bleed | chord labels, voiced by hand |

**Conclusion for Q1.** Transcription can reliably recover the **skeleton** of a take (tempo, which we already know;
harmony as chord labels; kick and snare pattern; bass line; a lead motif). It cannot recover a finished multitrack
score of a dense metal mix. Use it to **mine motifs** from the takes the operator likes. The arrangement itself
should be written in the score generator (F1), where every part is exact.

## 2. Generating MIDI directly

### 2.1 Models

| Id | Model | Code / weights licence; data caveat | Size | Conditioning | Multitrack, drums | Source |
|---|---|---|---|---|---|---|
| G1 | **Anticipatory Music Transformer** (Stanford CRFM) | Apache-2.0 / Apache-2.0; trained on Lakh MIDI | 128M–780M, large 3.1 GB fp32 | prime MIDI; fixed "control" notes for **infilling and accompaniment**; no text, key or tempo tokens (time in 10 ms steps) | yes: 128 GM programs + drums | [source: J. Thickstun, "anticipation" README, https://github.com/jthickstun/anticipation, read 2026-11-17]; [source: Hugging Face API, "stanford-crfm/music-large-800k", https://huggingface.co/api/models/stanford-crfm/music-large-800k, read 2026-11-17]; [source: Thickstun et al., "Anticipatory Music Transformer", https://huggingface.co/papers/2306.08620, read 2026-11-17]; [source: jthickstun, "anticipation/config.py", https://raw.githubusercontent.com/jthickstun/anticipation/main/anticipation/config.py, read 2026-11-17] |
| G2 | **Clef-0.2B** (new, autumn 2026) | Apache-2.0 / Apache-2.0; public-domain and open symbolic sources (PDMX, KernScores, OpenScore Lieder, The Session); a self-described research artifact | 0.2B | header tokens for **genre, ensemble, tempo (BPM), key and mode, meter**, and a per-track plan; about 35 bars of context | yes, with a drum track (GM numbers) | [source: haster, "Clef-0.2B" model card, https://huggingface.co/haster/Clef-0.2B, read 2026-11-17] |
| G3 | text2midi (AMAAI) | MIT / Apache-2.0; fine-tuned on MidiCaps (CC-BY-SA-4.0, built on Lakh) | n/s | text caption (key, tempo, chords, style, instruments) | multi-instrument | [source: AMAAI Lab, "Text2midi" README, https://github.com/AMAAI-Lab/Text2midi, read 2026-11-17]; [source: Hugging Face API, "amaai-lab/MidiCaps", https://huggingface.co/api/datasets/amaai-lab/MidiCaps, read 2026-11-17] |
| G4 | Text2midi-InferAlign | uses text2midi | — | reward-guided search: correct key 37.5 → 50 %, tempo bin 29.7 → 39.4 % | — | [source: Roy, Puri, Herremans, "Text2midi-InferAlign", https://huggingface.co/papers/2505.12669, read 2026-11-17] |
| G5 | MIDI-LLM (Llama 3.2 1B) | Llama 3.2 Community License ("Built with Llama", naming terms, AUP); GigaMIDI training data is CC-BY-NC | 1B, 16 GB+ | free text, infill | yes | [source: S. Wu, "MIDI-LLM" README, https://github.com/slSeanWU/MIDI-LLM, read 2026-11-17]; [source: slSeanWU, "LICENSE.md", https://raw.githubusercontent.com/slSeanWU/MIDI-LLM/main/LICENSE.md, read 2026-11-17]; [source: Hugging Face API, "Metacreation/GigaMIDI", https://huggingface.co/api/datasets/Metacreation/GigaMIDI, read 2026-11-17] |
| G6 | MuseCoco (Microsoft muzic) | MIT / Apache-2.0; training data not named; repo archived 2026-10-01 | ≈ 200M | attributes: key, tempo, instruments, meter, genre, bar count, emotion | instruments; drums n/s | [source: Microsoft, "muzic/musecoco" README, https://github.com/microsoft/muzic/tree/main/musecoco, read 2026-11-17]; [source: Hugging Face API, "XinXuNLPer/MuseCoco_attribute2music", https://huggingface.co/api/models/XinXuNLPer/MuseCoco_attribute2music, read 2026-11-17] |
| G7 | MIDI-GPT / MMM (Metacreation) | MIT / **CC-BY-NC-4.0**: excluded | small | bar and track infill; density, polyphony, key | yes | [source: Hugging Face API, "Metacreation/MIDI-GPT", https://huggingface.co/api/models/Metacreation/MIDI-GPT, read 2026-11-17] |
| G8 | Composer's Assistant 2 | MIT; the weights licence is inside the download (not read); claims "public domain and permissively-licensed MIDI" | CPU or CUDA | infill inside REAPER; density and range controls | all instruments; drums (snippet) | [source: M. Malandro, "composers-assistant-REAPER" README, https://github.com/m-malandro/composers-assistant-REAPER, read 2026-11-17] |
| G9 | MusicLang predict | GPL-3.0 / no licence on the card (commercial users must contact the authors): excluded | — | chords per bar, template | instruments not controllable | [source: MusicLang, "musiclang_predict" README, https://github.com/MusicLang/musiclang_predict, read 2026-11-17] |
| G10 | Magenta family; Magenta RT | Apache-2.0, archived 2026-01-06. Magenta RT is **audio**, not MIDI. | small | MusicVAE, Coconet, `drums_rnn` | partly | [source: Magenta, "magenta" README, https://github.com/magenta/magenta, read 2026-11-17]; [source: Magenta, "magenta-realtime" README, https://github.com/magenta/magenta-realtime, read 2026-11-17] |
| G11 | NotaGen, ChatMusician, Aria, SongComposer | MIT or Apache, but classical, folk, piano or melody only: wrong domain | — | — | — | [source: NotaGen README, https://github.com/ElectricAlexis/NotaGen, read 2026-11-17]; [source: EleutherAI, "aria" README, https://github.com/EleutherAI/aria, read 2026-11-17] |

**Lakh caveat.** G1, G3 and G6 learned from Lakh MIDI, files scraped from the web whose authors cannot be traced. A
collection licence does not clear each song's copyright
`[UNSOURCED: plan/provenance-audit.md#midi-lakh-licence]` [source: C. Raffel, "The Lakh MIDI Dataset v0.1",
https://colinraffel.com/projects/lmd/, unread: snippet only]. For shipped notes, keep generated material short
(infill and variation of our own motifs) and screen it for long verbatim runs. G2 (public sources) and G8 (claims
permissive data) are cleaner.

### 2.2 Can an LLM write MIDI from the song map?

| Id | Finding | Source |
|---|---|---|
| L1 | GPT-4 produced parseable ABC more than 90 % of the time, but only when asked for ABC explicitly. On musical-form and motif tasks "most samples generated by GPT-4 … contain malformed ABC". Listeners preferred the music-tuned ChatMusician in 76 % of pairs. | [source: Yuan et al., "ChatMusician", https://huggingface.co/papers/2402.16153, read 2026-11-17] |
| L2 | ABC-Eval (2025): bar-count accuracy ranges from 30 % to 99 % across models; detecting injected bar errors scores F1 6–27 for every model; results are sensitive to the prompt. | [source: ABC-Eval authors, "ABC-Eval", https://huggingface.co/papers/2509.23350, read 2026-11-17] |

No source measures qwen2.5 `[UNSOURCED: plan/provenance-audit.md#midi-qwen-composer]`. Our inference: a local
3b–14b model is useful only inside a **strict grid format with a validator in the loop**:
- one JSON object per bar, durations drawn from a fixed list (1/16 to 1 bar), and pitches as scale degrees of the
  section's key;
- the validator checks bar sums, the bar count from the song map, range and scale, then re-prompts;
- the score generator owns the form, tempo, drums and voicing.

It is a cheap drafting aid for motifs and fills, not a composer.

**Conclusion for Q2.** No open model is trained for metal. The realistic, commercially safe set:
- **AMT** (G1): Apache, multitrack with drums, about 3 GB of VRAM. Use it for infill and variation around fixed
  notes.
- **Clef-0.2B** (G2): the only model that takes key, tempo, meter and drums directly. Its data is clean, but its
  metal fitness is untested.
- **The local LLM**: a validator-gated drafting aid, with no download needed.

All three serve the deterministic score generator, which stays in charge.

## 3. Playback in the web build

### 3.1 Sampler runtimes

| Id | Finding | Source |
|---|---|---|
| P1 | spessasynth_lib: **Apache-2.0**. Plays SF2, SF3, DLS and MIDI in an **AudioWorklet**, can render each channel separately, has convolution reverb. spessasynth_core is pure TypeScript and **SF3 plays back Vorbis only** (it decodes in JS); `voiceCap` exists. | [source: Spessasus, "spessasynth_lib", https://github.com/spessasus/spessasynth_lib, read 2026-11-17]; [source: Spessasus, "spessasynth_core", https://github.com/spessasus/spessasynth_core, read 2026-11-17] |
| P2 | The SpessaSynth app does not list Safari among its supported browsers. | [source: Spessasus, "SpessaSynth", https://github.com/spessasus/SpessaSynth, read 2026-11-17] |
| P3 | js-synthesizer (FluidSynth in WASM): BSD-3 wrapper, but the libfluidsynth wasm is **LGPL-2.1**; SF3 needs a special build. | [source: jet2jet, "js-synthesizer", https://github.com/jet2jet/js-synthesizer, read 2026-11-17] |
| P4 | TinySoundFont: MIT, SF2 only, no WASM build or effects. sfizz: BSD-2, no web build. | [source: schellingb, "TinySoundFont", https://github.com/schellingb/TinySoundFont, read 2026-11-17]; [source: sfztools, "sfizz", https://github.com/sfztools/sfizz, read 2026-11-17] |
| P5 | WebAudioFont: **GPL-3.0**, and its bundled sounds carry mixed licences: excluded. midi-js-soundfonts: FluidR3 CC-BY 3.0; MusyngKite and FatBoy **CC-BY-SA**: excluded. | [source: surikov, "webaudiofont", https://github.com/surikov/webaudiofont, read 2026-11-17]; [source: gleitz, "midi-js-soundfonts", https://github.com/gleitz/midi-js-soundfonts, read 2026-11-17] |
| P6 | smplr: MIT, an SFZ-style preset object, loads ogg/m4a/mp3, and its sources include VCSL. Tone.js Sampler: MIT, pitch-shifts between sampled notes, Transport tempo ramps. | [source: danigb, "smplr", https://github.com/danigb/smplr, read 2026-11-17]; [source: Tonejs, "Tone.js", https://github.com/Tonejs/Tone.js, read 2026-11-17] |
| P7 | AudioWorklet support starts at Safari and iOS Safari 14.1, Chrome Android 66 and Firefox Android 76, and needs a secure context. | [source: MDN, "browser-compat-data AudioWorklet.json", https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/AudioWorklet.json, read 2026-11-17]; [source: MDN, "AudioWorklet", https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet, read 2026-11-17] |
| P8 | `baseLatency` from iOS 14.1 and Chrome Android 58; `outputLatency` from iOS **18.4** and Chrome Android 102. | [source: MDN, "browser-compat-data AudioContext.json", https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/AudioContext.json, read 2026-11-17] |
| P9 | Decoded buffers are Float32: channels × frames × 4 bytes. | [source: MDN, "BaseAudioContext.createBuffer", https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/createBuffer, read 2026-11-17] |
| P10 | Safari 18.4 added Opus and Vorbis in Ogg. Before 18.4, `decodeAudioData` cannot decode either. | R§3 W3 [source: acdha / MDN, "Record Safari 18.4+ support for Opus in Ogg containers", https://github.com/mdn/content/pull/39592, read 2026-11-17] |

No measured polyphony, CPU or latency numbers for any WebAudio sampler on phones were found
`[UNSOURCED: plan/provenance-audit.md#midi-phone-polyphony]`. We measure them ourselves (design §11, task 8.4).

**The choice between an in-house sampler and spessasynth.**
- `demon-audio.js` already parses MIDI, schedules every note on the audio clock and holds per-voice gain nodes (F4).
  Swapping its oscillator for an `AudioBufferSourceNode` playing a sample (pitch via `playbackRate` between sampled
  notes) is a small change with no new dependency. It keeps one clock for the score, the layers, the accents and
  the SFX, and per-track gain nodes give mute and solo by intensity for free.
- spessasynth (P1) brings SF2 or SF3 conformance, reverb and chorus, and decodes Vorbis in JS (so it would play
  even where `decodeAudioData` cannot). The costs: a second scheduler, a TypeScript DSP on phones, unverified Safari
  support (P2), and SF3 tied to Vorbis, a second compressed audio format next to the game's Opus. That conflicts
  with the one-format rule unless every sample ships as Vorbis.
- **Decision input:** start with the in-house sampler (Opus samples, the same format as everything else). Keep
  spessasynth as the measured alternative in the bake-off (task 8.4).

### 3.2 Metal guitars, bass and drums that sound good

| Id | Finding | Source |
|---|---|---|
| M1 | `WaveShaperNode.oversample = '4x'` upsamples before the curve to reduce aliasing. | [source: MDN, "WaveShaperNode: oversample", https://developer.mozilla.org/en-US/docs/Web/API/WaveShaperNode/oversample, read 2026-11-17] |
| M2 | neural-amp-modeler-wasm (TONE3000): MIT, single-threaded, no COOP/COEP needed. Its wasm heap is 64 MB and grows to 512 MB, and an earlier double instantiation hit iOS's memory limit. No CPU figures. | [source: TONE3000, "neural-amp-modeler-wasm", https://github.com/tone-3000/neural-amp-modeler-wasm, read 2026-11-17] |
| M3 | WebAudio tube-amp simulators (Buffa and Lebrun) were blind-tested against native amp sims, with Mac latency "comparable to the best native apps". | [source: Web Audio Conference, "Guitarists will be happy…", https://webaudioconf.github.io/demos-and-posters/guitarists-will-be-happy-guitar-tube-amp-simulators-and-fx-pedal-in-a-virtual-pedal-board-and-more, read 2026-11-17] |
| M4 | No CC0 cabinet impulse-response pack was found; one known pack is CC-BY-SA (excluded). | [source: Zach Weeks, "TL806 and Basement 1960B", https://zachweeks.gumroad.com/l/tl806cabir, unread: snippet only] `[UNSOURCED: plan/provenance-audit.md#midi-cab-ir]` |

What we infer for the game:

- **Guitars:** DI samples (sustain and palm mute) → pre-EQ → `WaveShaper` (4x) at two gain stages → a cabinet made
  of our own filters (high-pass about 80 Hz, low-pass about 5–6 kHz, a 2–3 kHz presence peak, a notch near
  400 Hz). The cabinet ships as code, not as an impulse response. Optionally a short CC0 IR **we generate
  ourselves** from that filter.
  - Two chains (left and right, a few cents apart, slightly different curves) make a double-tracked wall from one
    set of DI samples.
  - NAM on phones is ruled out by M2's memory. On desktop it stays a later option.
- **Bass:** DI samples → light drive → a low-pass blend.
- **Drums:** one-shots with velocity layers and round-robins, kick and snare up front. Cymbals are the expensive
  part, because they need stereo and long tails.
- **Sampled power chords** skip the amp's CPU cost but fix the tone and multiply the samples (see the arithmetic
  below). The **DI + amp** route is the one that keeps the bank small and the tone tunable per world.
- **Whether the result meets the operator's bar** is the open risk: they rejected the oscillator synth as thin, and
  dense guitars are where samplers sound cheapest. Only a listening bake-off settles it (task 8.4).

### 3.3 Sample libraries and the size budget

| Id | Finding | Source |
|---|---|---|
| B1 | Karoryfer drums, all **CC0-1.0**: Big Rusty Drums 2.3 GB, Unruly Drums 2 GB, Swirly 1.6 GB, Frankensnare 900 MB. | [source: sfzinstruments, "Drums", https://sfzinstruments.github.io/drums, read 2026-11-17] |
| B2 | Karoryfer guitars, **CC0-1.0**: Black And Green Guitars 500 MB, Shinyguitar 352 MB. | [source: sfzinstruments, "Guitars", https://sfzinstruments.github.io/guitars, read 2026-11-17] |
| B3 | Karoryfer basses, **CC0-1.0**: Growlybass 160 MB, Black And Blue Basses 961 MB, Swagbass 138 MB. **Meatbass** (named in `l3-ember-moon-dry.json`) is not on that list; a news snippet calls it a GPL-3 double bass. | [source: sfzinstruments, "Basses", https://sfzinstruments.github.io/basses, read 2026-11-17]; [source: KVR, "Karoryfer releases free Meatbass", https://www.kvraudio.com/news/karoryfer-releases-free-meatbass---double-bass-sample-library-29343, unread: snippet only] `[UNSOURCED: plan/provenance-audit.md#midi-meatbass-licence]` |
| B4 | Choirs: Karoryfer's Hadziha and Torgbe are commercial. The only CC0 vocal library listed is "272 Merry Orks", which is not a choir pad. War Tuba is CC0, 104 MB. | [source: sfzinstruments, "Vocals", https://sfzinstruments.github.io/vocals, read 2026-11-17]; [source: sfzinstruments, "Brass", https://sfzinstruments.github.io/brass, read 2026-11-17] |
| B5 | Virtuosity Drums (Versilian Studios with Karoryfer): CC0, SFZ, 6 mic positions. | [source: sfzinstruments, "virtuosity_drums", https://github.com/sfzinstruments/virtuosity_drums, read 2026-11-17] |
| B6 | VCSL: **CC0-1.0**, about 3.97 GB, 20–75 MB per instrument. It has pipe and Renaissance organs, timpani, tubular bells, snares, toms, bass drums, gongs, cymbals, harps and pianos. It has **no ukulele, guitar, choir or brass** (the only lip aerophone is a didgeridoo). | [source: sgossner, "VCSL" README, https://github.com/sgossner/VCSL, read 2026-11-17]; [source: GitHub API, "sgossner/VCSL contents", https://api.github.com/repos/sgossner/VCSL/contents/, read 2026-11-17] |
| B7 | VSCO 2 CE: **CC0-1.0**, with brass (F horn, trombones, trumpet, tuba) and organ. | [source: sgossner, "VSCO-2-CE", https://github.com/sgossner/VSCO-2-CE, read 2026-11-17] |
| B8 | GM banks: FluidR3_GM is MIT (Debian); GeneralUser GS (32.3 MB) allows commercial use but **does not explicitly grant redistribution**; TimGM6mb is GPL-2. | [source: Debian, "fluid-soundfont copyright", https://metadata.ftp-master.debian.org/changelogs/main/f/fluid-soundfont/unstable_copyright, read 2026-11-17]; [source: S. Christian Collins, "GeneralUser GS LICENSE.txt", https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/documentation/LICENSE.txt, read 2026-11-17]; [source: Debian, "timgm6mb-soundfont copyright", https://metadata.ftp-master.debian.org/changelogs/main/t/timgm6mb-soundfont/unstable_copyright, read 2026-11-17] |

This answers an open question from R§2.3: **VCSL has no ukulele**, and neither do the Karoryfer lists we read. The
ending's ukulele stays a text-to-music texture, or needs another CC0 source.

**The web bank: a curated extract, not whole libraries.** The libraries total several GB. The game ships a few
seconds per sampled note, trimmed, mono where possible, in Opus. The arithmetic is our own (48 kHz, Float32 decoded:
192 KB per second mono, 384 KB stereo, P9):

| Group | Plan | Seconds | Decoded | Opus (mono 64 kbps ≈ 8 KB/s, stereo 96 kbps ≈ 12 KB/s) |
|---|---|---:|---:|---:|
| Kick, snare, toms (mono close) | 6 pieces × 3 velocities × 2 round-robins × 0.6 s | 22 mono | 4.1 MB | 0.17 MB |
| Hats, ride, crash, china (stereo) | 5 pieces × 3 velocities × 2 round-robins × 1.3 s (hat 0.4 s) | 33 stereo | 12.7 MB | 0.40 MB |
| Bass DI | 10 notes (every 3 semitones, E1–E3) × 2 articulations × 1.5 s | 30 mono | 5.8 MB | 0.24 MB |
| Guitar DI (rhythm and lead, through the amp) | 12 notes × 2 articulations (sustain, palm mute) × 1.5 s | 36 mono | 6.9 MB | 0.29 MB |
| Organ, brass, strings pads (looped) | 3 × 6 notes × 2 s | 36 mono | 6.9 MB | 0.29 MB |
| Timpani, tubular bells, war drum | 3 × 5 notes × 1.5 s | 23 mono | 4.3 MB | 0.18 MB |
| **Full bank** | | 147 mono + 33 stereo | **≈ 41 MB** | **≈ 1.6 MB** |
| **Phone tier** (one velocity layer, one round-robin, half the cymbals) | | | **≈ 16 MB** | (same files, fewer loaded) |

Adding sampled stereo power chords (12 roots × 2 × 2 s) would add 18 MB decoded and 0.6 MB of Opus. That is not
worth it if the DI + amp route passes the bake-off.

**Whole-run size compared** (our arithmetic):
- **MIDI-first:** about 18 minutes of unique section music (design §3.2) × 530 B/s ≈ 0.6 MB of scores (≈ 0.3 MB
  gzipped), plus the 1.6 MB bank, ≈ **2.2 MB**.
- **Rendered audio:** about **18 MB** (F5).

Every further minute costs about 32 KB as score and 1.2 MB as Opus.

### 3.4 Dynamic mixing, tempo and key

- **Per-track layers.** Each score part gets its own gain node. Intensity becomes a **track mask** per tier, a
  vertical layering of one arrangement: the thing the rendered route could not do without stems (R§1.2).
  - Tier 1: drums (kick, snare, hats), bass and rhythm guitar.
  - Tier 2: adds the lead and the crash and ride.
  - Tier 3: adds the double kick, the harmony lead and pads.
  - Tier 4: everything.
- Mask changes land on the next bar line, with 20–60 ms gain ramps.
- **Tempo and key** are just data: a key change is a transpose of the pitched tracks and a tempo change is a
  scheduler parameter, so neither needs resampled audio. Keep each song at one tempo (the grid), and change tempo
  only at song boundaries and in bridges, as today.
- **Precedent.** iMUSE (LucasArts, US5315057A, expired 2011) did exactly this with MIDI. Sequences carried decision
  points; "hooks" jumped, transposed, changed volume or instrument and switched parts on and off; "markers" deferred
  a command to a musically fitting moment. [source: Google Patents, "US5315057A", https://patents.google.com/patent/US5315057A/en, read 2026-11-17]
- **Phones.**
  - **Voice limit:** a fixed cap of 48 voices on desktop and 32 on phones. Steal from pads first and never from
    kick, snare or bass. The L3 score needs 25–50 voices (F3).
  - **Memory:** the phone-tier bank is about 16 MB decoded, against the 48 MB that recorded sections would take
    (design §5.3).
  - **Latency:** score notes are scheduled 120 ms ahead on the audio clock, so output latency does not shift them
    against each other. It only delays music relative to game events, by `baseLatency`, or by `outputLatency` from
    iOS 18.4 (P8).

## 4. The verdict

| Criterion | MIDI-first (score + sampled bank) | Rendered ACE-Step sections |
|---|---|---|
| Size of the whole run | **≈ 2.2 MB** (§3.3) | ≈ 18 MB (F5) |
| Adaptivity | **Full**: per-track layers, same-position intensity, any bar, transposition, stingers in key, exact bar lines by construction | Horizontal only. Vertical layers need stems that may not ship (F8) or wait on #1103. Variants are separate takes that may sound like different bands (design §9). |
| Coherence ("one band, one room") | **Built in**: one bank, one mix chain, the same theme notes everywhere | The main open risk of the pilot |
| Quality ceiling | Bounded by a ~1.6 MB bank and a browser amp. Drums and bass can be good; distorted rhythm guitar is the weak spot. Choir has no CC0 source (B4). | Higher for texture and "real band" density, but with the turbo model's air problems (R§2.4) |
| Authoring | Notes are editable, diffable, deterministic (F1). Every song must be arranged, which is a lot of writing per song; models help only with motifs and infill (§2). | Prompting and picking; fast per take, but every fix is a re-roll |
| Plays everywhere | The oscillator voice plays the same score where Opus or Vorbis cannot decode (Safari < 18.4, F4/P10), with **no second asset** | Opus only; Safari < 18.4 needs the MIDI fallback anyway (N5) |

**Odds (our judgement, not a sourced claim):**
- **About 75 %** that MIDI-first is the better *backbone* for this game. It wins on size, adaptivity and coherence,
  and those three are what "one run as one long song" needs. It also carries the vertical layering the rendered
  route cannot ship.
- **About 50 %** that the browser-sampled guitars alone reach the operator's quality bar on first try. That is why
  the architecture keeps a rendered **texture** layer for what samples do badly, and why a listening bake-off gates
  production.
- **About 85 %** that the combination (MIDI backbone plus a few rendered texture beds) beats rendered-only on the
  operator's whole brief, given the no-duplicates rule.

**Architecture** (design §11):
1. **First layer: the score.** Committed multitrack MIDI per section (drums, bass, rhythm guitars, leads, pads,
   stingers), played by an in-house Web Audio sampler from one curated CC0 bank in Opus. Intensity is a track mask;
   sections, bridges and the boss graph of design §4 move on the score's own bar lines.
2. **Optional texture beds:** rendered ACE-Step audio only for **parts the score does not play**: choir and
   "air" beds, risers, impacts, the worldized ending, the ukulele if no sample exists. Each part lives in exactly one
   layer (the no-duplicates rule): a bed never contains drums, bass or rhythm guitar, and the checker rejects one
   that does. A song may have no bed at all.
3. **Fallback voice:** if the bank has not loaded or cannot decode, the same score plays through the built-in
   oscillator voices. The fallback is a different voice for the same notes, not a second asset.

## 5. The pipeline

**Route A: score-first, the main route, available now.**
1. The song map gives each section its key, grid, bars and character.
2. The score generator writes the multitrack MIDI. Today that is `tools/score_l3.py`, generalised per song; new
   tooling is in Lua per CLAUDE.md §9, with the existing Python motif module read through its JSON export.
3. Gates: whole bars, notes on the grid, out-of-scale notes counted, voice peak within budget (`tools/midi_stats.lua`).
4. Commit the `.mid` files and their recipe.

**Route B: from an ACE-Step take, motif mining.**
1. A picked take goes to `audio.separate` (htdemucs_6s, admitted, internal only, F8).
2. Per stem:
   - drums: onsets in kick and snare bands, snapped to the 16th grid;
   - bass: basic-pitch or an f0 tracker;
   - lead: an f0 tracker;
   - guitar and "other": chord labels plus roots.
3. Cleanup: snap to the known grid (no beat tracking needed), fold to the key's scale, voice rhythm guitar as power
   chords by rule, and write hats and cymbals by rule.
4. The result is a **motif file** that the score generator quotes. Raw transcriptions are never committed as
   shipped scores; the recipe (take, stems, tool versions, cleanup) is.

Tools for route B, per CLAUDE.md §9:
- separation runs on the host (`audio.separate`);
- basic-pitch runs in Rust through `ort` with its Apache-2.0 ONNX model (T6, T16), or as basicpitch.cpp (T8);
- beat checking through the `beat-this` crate (MIT weights, T15) if it is ever needed;
- onsets and f0 through a Go tool on ffmpeg-decoded PCM, beside `tools/soundtrack_check`.

None of these is installed: each needs admission and a download (§6).

**Route C: symbolic generation.**
1. The song map plus our motifs prime AMT (infill and accompaniment), or a Clef header (key, tempo, meter,
   instruments), or a validator-gated qwen2.5 draft.
2. The candidate goes through the same gates as route A, plus a Lakh-overlap screen for G1, G3 and G6.
3. The score generator absorbs the accepted bars.

AMT and Clef run on the GPU (≈ 3 GB) and need admission and download consent. qwen2.5 is already served (F7) and
runs one job at a time on the GPU queue.

**What is blocked on #1103:**
- the CC0 libraries arriving on the host (Karoryfer, VCSL), which are the bank's sources;
- `TillandsiasSFZRender` for offline full-quality auditions and the A/B against the web bank;
- XL SFT for texture beds.

**What runs now on the forge CPU:** the score generator, the gates, the probe, the sampler code (it needs only tiny
synthetic test samples), the oscillator fallback and the song-graph runtime.

## 6. Summary of what is needed

| Need | What | Admission or consent | Blocks |
|---|---|---|---|
| CC0 sample sources | Karoryfer (Big Rusty or Virtuosity Drums, Growlybass, Black And Green Guitars), VCSL (organ, timpani, bells), VSCO 2 CE (brass) | Licences are CC0 (B1–B7). The GB-scale downloads arrive with #1103, or need the operator's consent | the bank, tasks 8.5–8.6 |
| Meatbass | its licence (GPL-3 per a snippet, B3): replace with Growlybass unless verified | — | the L3 workflow's bass |
| A choir | no CC0 choir found (B4): a rendered texture bed, or a CC0 source the coordinator finds | — | choir parts |
| basic-pitch ONNX + `ort` | the Apache-2.0 model; ONNX Runtime (MIT) | host admission and download | route B |
| AMT (music-large-800k), Clef-0.2B | Apache-2.0 weights | admission and download consent; a Lakh screen for AMT | route C |
| Separated stems → MIDI | htdemucs is acknowledged "non-sale", and separated **audio** never ships; does a MIDI motif transcribed from a separated stem count as internal analysis? | **operator** | route B |
