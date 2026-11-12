# Voice review candidates

Original character Pip, Kokoro voice `am_liam`, with Chatterbox cloning the character's own generated reference. Full pinned model configuration is in art/comms/audio.json; actual Kokoro cache resolved to the configured f3ff357 revision. All clean baselines, expressive takes and references are preserved here. `environment.txt` captures the package environment; model weights remain reconstructible external dependencies.

| File stem | Emotion | Text | Generation time |
|---|---|---|---|
| sectorStart.h4 | teasing | Cadet Pip, reporting for awesome! I mean, for duty! | 12.12 s |
| diveWarning.h4 | urgent | They're coming straight down! | 7.36 s |
| waveStart.h5 | calm | More of them? Okay. Okay! I'm ready. | 9.71 s |

Each `.baseline.wav` is the clean Kokoro comparison. Each plain `.wav` is the clean Chatterbox take before the existing deterministic delivery/radio chain. The Opus trials are loudness-treated copies for review; none has replaced the game bank. Metrics are in baseline-metrics.json and expressive-metrics.json. Three different lines are not a controlled same-text emotion experiment. Pitch range alone does not establish acting quality: expressive pitch spans were 14.81/10.11/9.10 semitones (teasing/urgent/calm); the baseline urgent line actually has a wider span. Listen for cadence, intent, intelligibility and retained identity.

`reverse-pitch-experiment.wav` is an effect test from the teasing source, not a new demon casting decision. FFmpeg 9.0.2 filter: `areverse,asetrate=19049,aresample=24000,atempo=1.25992,highpass=f=100,alimiter=limit=0.63:level=false`. At 24 kHz this is approximately a four-semitone downward shift with compensated duration. Clean and transformed originals are retained. No final demon preset or lip timing has been accepted.

The Lua trial runner successfully resumed by verifying and skipping every finished job; remote pushes were verified by the Git relay. First attempt's missing-baseline failure is documented in the handoff; repaired run succeeded.
