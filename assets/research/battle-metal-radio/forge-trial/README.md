# Forge recovery trial — 2026-11-12

Research candidates only; no shipped bank replaced and no listening acceptance claimed.

- Studio restored: ComfyUI 0.40.0, CUDA RTX A5000 (25,297,420,288 bytes VRAM), empty initial queue.
- `metal-12s.flac`: studio job `st-1794463787959-0`, seed 26111201, 12 seconds requested, E minor, instrumental power metal, BPM parameter 75 with 150 BPM in tags. ACE-Step XL turbo; full model/workflow provenance alongside the FLAC. GPU run 9.1 seconds, tool total 10.529 seconds.
- Flutter 3.47.7 / Dart 3.13.5 runs. Layout/director suite: 41 passed; existing landscape START GAME tap warning remains.
- Voice environments and masters from the prior forge are missing. Rebuilding isolated CPU model adapters before a bounded voice trial.
- Linked compact calls now share one decorated full-width toast, opener left and reply right. Independent calls reserve half width each. Stable alphabet/delayed translation and final visual review are still pending; the task stays open.

Small trial masters are committed here so a remote push preserves them. This does not establish storage for a full campaign's lossless masters; large-scale rendering must wait for a verified durable destination.

## Longer test

`overture-90s.flac`: job `st-1794464067796-1`, seed 26111202, same pinned workflow/models, 90 seconds requested and decoded. Prompt requests a quiet opening, recurring guitar theme, contrasting bridge and climax. GPU run 16.27 seconds (17.827 seconds total). This is a longer backend trial, not the composed campaign map or an accepted replacement.

Both raw music trials decode as 48 kHz stereo, mean volume -14.0 dB, maximum 0.0 dBFS. Full-scale samples require inspection before production acceptance; reducing volume alone cannot repair any clipping already in the master. No audition or structure assessment has been claimed.
\n
## Completed voice and compression trials

Three expressive Pip takes and their clean baselines are under voices/, with metrics, package versions and a labelled reverse/pitch experiment. Every successful job was pushed separately; actual resume skipped all finished jobs after verifying their hashes. See voices/README.md for listening instructions and limitations.

The 90-second music candidate compresses from 8,736,587 bytes FLAC to 1,645,965 bytes at Opus 128 kb/s or 2,039,091 bytes at 160 kb/s (VBR). Both decode to exactly 4,320,000 stereo samples/channel at 48 kHz: 90 seconds. Three 48 kb/s Opus voice previews are 8–20 KB each. Encoding settings/inputs/output hashes are recorded in tools/production/encode-trial.lua and plan/render-runs/opus-trial-2026-11-12/. The music preview's -3 dB gain provides codec headroom but does not repair clipping in a source. None is a production quality acceptance.

45 layout/director tests pass, analysis is clean, and OpenSpec validation passes. Four additional focused reruns cover both conversation orders in portrait and landscape after loading actual portrait/font assets. Representative review PNGs are in review/: layout and readable text were inspected, using Noto Sans loaded as the review font. The pre-existing landscape start-button fixture warning remains. Full motion/audio synchronization is still pending final voices.
