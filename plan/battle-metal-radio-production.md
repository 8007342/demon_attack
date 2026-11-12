# Production checkpoint — 2026-11-12

## Current branch and recovery
Work branch: `work/battle-metal-radio-rework`, based on `game`. First checkpoint bfd19c6 was relayed and accepted by upstream GitHub. Continue pushing this work branch; integrate into `game` when reviewed. Do not claim an unpushed render or local cache will survive forge loss.

## Measured environment
- Host reports 20 logical CPU cores, Intel Core Ultra 7 265KF and 62 GiB physical RAM. Container memory.max is 12 GiB, so use that effective memory ceiling rather than the host RAM figure. cpu.max is unrestricted.
- No GPU, DRI or accelerator device nodes are exposed inside the forge. GPU work uses the host studio; no usable NPU was established.
- Studio status: stopped. Existing model inventory reports ACE-Step XL turbo/base, 0.6B/4B encoders and VAE installed, all listed Apache-2.0. Image models are also installed. No download or render has been started by this change.
- Checkout is a 1.5 GiB tmpfs, about 1.1 GiB available before further builds. Do not store long-form lossless takes here.
- Project cache is on /dev/md127, about 88 GiB available at inspection. This is a capacity observation, not a durability guarantee: the operator explicitly says forge-local work is disposable. Establish remote storage/transfer for masters before multi-day production, with checksums and reconstructible small manifests in Git.

## Existing pipeline constraints
`tools/music_pipeline.py` orchestrates ACE workflows, analyzes takes with numpy/scipy and encodes via ffmpeg. `music_guide.py` and `music_motifs.py` support the synthesized fallback and accents. `tools/comms_pipeline.py` handles voices, processing, encoding and generated Dart bank; `art/comms/audio.json` pins Kokoro and Chatterbox. Python model dependencies are allowed to remain; Lua should replace orchestration without rewriting model internals unnecessarily.

The current recorded tier loops use short bar windows and distinct level keys/tempos. Merely increasing generation duration without updating window selection, manifests and playback would still ship short loops. The score work must update those contracts together. Current cue metadata explicitly states some derived stems were never listened to. Automated timbre/tempo metrics cannot close listening acceptance tasks.

## Verification at first checkpoint
41 comms layout/director checks passed, including explicit mirror-position and retired-opener checks. Analyzer reported no issues for the changed director/view/layout test; including the existing director test surfaces two pre-existing brace-style informational findings in unrelated brood-voice cases. Existing landscape fixture emitted an offscreen START GAME tap warning. A targeted phone test passed, but its /tmp image output was not visible from the forge; do not claim visual screenshot review from that attempt.

## Next independent work
1. Finish paired-card verification and capture representative mobile review images.
2. Inventory full existing render storage and model adapters; implement atomic resumable job records and durable master delivery.
3. Compose the campaign section/bridge map before rendering a full bank; do not let the old eight-bar build stage erase extended arrangements.
4. Build stable alien script/translation behavior and playful exchange text, then render voices and measure mouths against transformed audio.
5. Sibling credits source inspection is now complete after public access was granted. Beach cinematic and our own generated credits remain unimplemented.

## Production launch attempt — 2026-11-12

The user authorized a multi-hour/multi-day orchestration run. `studio.start {}` failed before container startup: Podman NVIDIA CDI injection references `/dev/nvidia-modeset`, which does not exist on the host (exit 127). No GPU render was submitted, no scheduler is running, and no accepted asset was replaced. This is a host device/configuration blocker, not a model download or workflow quality failure. The operator was asked to check the host NVIDIA driver/device configuration. Do not repeatedly restart or bypass the GPU isolation configuration.

Machine-readable recovery record: `plan/render-runs/battle-metal-radio-2026-11-12.json`. After host repair, retry studio.start, verify actual queue/capacity and durable master storage, then complete the resumable runner and composition map before starting full production. The existing OpenSpec tasks remain pending where their full acceptance criteria have not been met.

## Recovery and bounded trials — 2026-11-12, resumed session
The host studio now starts successfully: ComfyUI 0.40.0 sees CUDA RTX A5000 with about 24 GB available; Flutter 3.47.7 works. Two GPU trials completed (12 seconds in 9.1 seconds GPU time; 90 seconds in 16.27 seconds). Lossless outputs and full provenance are pushed under assets/research/battle-metal-radio/forge-trial, not installed in the game. Both raw takes reach 0 dBFS and require clipping/listening review. The longer take requests extended development but has not been judged musically.

Rebuilt the ephemeral voice environment. The first expressive attempt failed because its clean baseline was missing; the adapter now generates baselines and preflights this prerequisite. Pip's teasing, urgent and calm samples succeeded (12.12, 7.36 and 9.71 seconds generation time), with clean baselines, character reference, package versions, per-job hashes and remote checkpoints. These are listening candidates, not proof of improved acting. A reverse/pitch effect experiment uses Pip only as a test source, not as an assigned demon identity.

Lua runner: tools/production/run.lua. Each job records atomic state, hashes inputs and outputs, checks cached outputs before skipping, retries interrupted jobs and pushes each completed research checkpoint. Actual resume skipped all four verified voice jobs. Recovery tests exercise corrupted output, changed input, interrupted status, failed command and retry. The runner remains a bounded-trial tool; full GPU scheduling/composition/acceptance work is pending.

Toast refinement: linked exchanges share one decorated full-width toast, first portrait left and reply right; isolated calls occupy half width, with two available slots. Translations can wrap. Both faction orders pass portrait/landscape tests, including reduced motion. Stable alien alphabet and delayed translation remain pending; task 4 remains open to track that full acceptance requirement.

PWA clarification: operator has no bucket/NAS. Target modern browsers, final Opus media on the PWA origin, no older-browser AAC requirement. Keep lossless masters out of deployed assets and preserve bounded retained masters on remote work branches. Opus bitrate comparison is underway; the existing runtime/legacy codec bank has not yet been migrated. A full-bank run still needs the campaign map, source/output size budget, phrase-aware playback and listening decisions. No unattended scheduler or full-bank render is currently running.

## Large batch launch — 2026-11-12
Full radio queue launched: 385 human lines + 189 original demon performances
across 25 synthetic identities. One guarded resident Kokoro/Chatterbox worker
serves Lua clip jobs; completed masters, Opus files, metadata and atomic ledgers
are pushed per clip with a repository-wide Git checkpoint lock. The first
complete demon candidate (broodTaunt.d0) uses Chatterbox, reversal and down-pitch,
measured -18.72 LUFS, and has no fallback. A vocabulary test caught “warning tap”;
the scheduler was stopped/drained, the source changed to “warning nudge”, all
47 comms/layout checks passed, and hash-verified production resumed. This source
change invalidated old global line-bank hashes; unaffected model takes are
reused only through their own content keys, while candidate metadata is rebuilt.

Campaign map is composed in art/music/campaign.json and plan/campaign-composition.md.
All five 96-bar guides rendered with original recurring theme and evolving
arrangements; four outgoing/pivot/incoming guides also exist. Full music request
set: 27 candidates (~45 minutes), including level variations, bridges, ending
and menu. First level-1 candidate is remotely checkpointed; its raw export still
reaches full scale. Remaining music renders are held to fix headroom before
export. Host refusal of the installed built-in AudioAdjustVolume node is
node_not_pinned; the operator has been asked to refresh the node allowlist.
No direct-API bypass is authorized or used. Radio continues independently.

## Browser PCM preparation and mouth review

Recorded music now serializes decode requests, evicts cached buffers using a
64 MiB byte budget as well as its 14-entry limit, and decodes only the upcoming
tier and reactive sprites during level preloading. Higher arrangements/outros
remain compressed until requested. A five-level test with extended 35-second
tier fixtures proves byte-driven eviction, retention of current playback and
lazy alternatives. Music/comms audio checks pass (16 tests in the targeted run).
This is a cache budget, not proof of total browser memory: active/pending
players and transient overlapping sources can retain additional buffers.
Final phrase segmentation and transition-memory checks remain task 9 work.

The candidate-mouth renderer and Lua muxer retain 30 Hz previews using the actual
runtime painter and newly encoded voices, without promoting a partial bank.
Admiral Hale and Gorrak contact sheets were inspected at 128/48 px: stable face
alignment, visible openings, and a closed/resting tail. Three existing all-cast
mouth-alignment checks also pass. Videos, source hashes and scoped review notes
are remotely retained under research/mouth-review-2026-11-12. Listening and
broader contextual review remain required; task 12 is not complete.

Stable original alphabet, progressive writing, delayed translation, immediate
accessible meaning and full/half toast behavior are implemented. Demons target
40% airtime. Opus-only fetch is implemented; old AAC files remain pending bank
promotion/removal. Flutter comms/layout 47 pass; director checks also pass after
share adjustment; 19 web-audio tests pass and analysis is clean. Full-cast audio,
final mouth review, score selection/bridges and playback integration remain open.
