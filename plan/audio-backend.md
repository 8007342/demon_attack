# Audio and global Top10

Implemented in `web/audio/`, `worker/index.mjs`, and `test-worker/`.

## Music direction

Original music only: retro sci-fi arcade fused with dark synth and orchestral tension, growing more demonic deeper into the campaign, with boss phases escalating. No cue imitates an existing game's soundtrack, and no prompt names a game, composer or soundtrack. All cues share a 120 BPM 4/4 grid so cues change on a four-beat boundary while release tails overlap.

### Recorded cues (primary)

The shipping music is a set of recorded loops generated locally with ACE-Step 1.5 (apache-2.0) in the project's ComfyUI studio, one per cue, in `web/audio/music/<cue>.ogg` (Opus, 80 kbps) and `<cue>.m4a` (AAC-LC, 128 kbps, fallback for browsers that cannot decode Ogg Opus). `web/audio/music/manifest.json` records every cue's kind, length, loop points, chosen seed, source tempo, cut point and file hashes. See the cue table in [style-guide.md](style-guide.md#current-music-score-and-playback).

Pipeline, all committed and reproducible:

- `art/workflows/music/acestep15-cue.json` — API-format ComfyUI workflow: `UNETLoader` (acestep_v1.5_xl_turbo_bf16) → `ModelSamplingAuraFlow` (shift 3) → `KSampler` (8 steps, cfg 1, euler/simple) with `TextEncodeAceStepAudio1.5` (qwen_0.6b_ace15 + qwen_4b_ace15 via `DualCLIPLoader` type `ace`; tags, `[instrumental]` lyrics, bpm 120, 4/4, key, duration) and a zeroed negative, `EmptyAceStep1.5LatentAudio`, `VAEDecodeAudio` (ace_1.5_vae), `SaveAudio` (48 kHz stereo FLAC). Both the text-encoder and the sampler nodes are titled `$seed`, so one seed (and `count` consecutive seeds) drives both the audio-code LM and the diffusion noise.
- `art/workflows/music/cues.json` — the cue spec: per cue its kind, beats, generation length, key, tags, seeds, and an optional `pick` to pin a seed; shared tags (`instrumental, no vocals, …, 120 bpm, 4/4, steady tempo`), target loudness −18 LUFS, −1 dBFS peak ceiling, codec bitrates.
- `tools/music_pipeline.py` (python3 + numpy + scipy + ffmpeg with libopus/aac):
  - `jobs` prints one `studio.run_workflow` request per (cue, seed); `generate --comfy URL` posts the same graphs straight to a ComfyUI server when no studio tool is available; `ingest JOB_DIR --cue NAME` copies studio outputs to `build/music/<cue>-s<seed>.flac` (seeds read from the provenance sidecars).
  - `analyze` measures each candidate: tempo on an eighth-note onset lattice (coarse 104–136 BPM, then 0.02 BPM steps), grid contrast (on-grid vs. off-grid onset strength), drift of the grid phase across the four quarters, bar phase from chord-change novelty + low-band onsets + broadband onsets, onset rate.
  - `build` picks per cue the candidate with the best rank (grid contrast, downbeat confidence, tempo error, drift, seam similarity, and a density bias that prefers calmer menus and denser late levels/bosses), resamples it to exactly 120 BPM if needed, cuts on a detected downbeat a window of exactly `beats × 24000` samples, and builds the seam: a **loop** cue's first 120 ms equal-power crossfades from the audio that really follows the window into the window start, so the wrap from the last sample to the first is the original continuous waveform (no zero-crossing search needed, no gap, no click); a **tail** cue (victory, level clear) plays its 8-beat opening and then a crossfaded copy of its last bar, which loops; a **oneshot** (game over) gets 8 beats plus a 0.6 s fade. DC is removed, loudness normalised (BS.1770 K-weighted, gated) and each codec is primed with real context: the encoder sees the loop end before the start and the loop start after the end, and the container hides both (Opus pre-skip + final granule position, MP4 edit list), so decoded files are sample-exact and the codec edge never lands on the wrap.
  - `verify` decodes both formats and checks exact length, whole-bar loop regions, the wrap step and curvature against the loop's own 99.9th percentile, codec edge error against the master, peak, and that onsets fall on the 120 BPM eighth grid. `table` prints the docs table.

Rerun everything: generate the candidates (`tools/music_pipeline.py jobs` → `studio.run_workflow` with the printed overrides, or `generate --comfy http://studio:8188`), `ingest`, then `analyze && build && verify`. Fixed seeds make the selection deterministic for the same model files; pin a choice with `"pick": <seed>` in `cues.json`.

### Playback

`web/audio/demon-audio.js` keeps the original architecture: one audio-clock scheduler (25 ms timer, 120 ms lookahead) on a shared 120 BPM beat grid, cue changes queued to the next bar, an immediate level-clear flourish with a 90 ms music-only fade, a request counter that discards stale loads, gesture unlock, a 30 ms mute ramp, and pause/resume by suspending the context. A recorded cue is an `AudioBufferSourceNode` started exactly on the bar time; loops use `loop`/`loopStart`/`loopEnd` (whole file; or the appended last bar for tail cues), and the previous cue releases over 120 ms across the bar line. Resume no longer re-phases the grid: it only skips whole beats that fell behind, so the grid stays locked to the playing loop. Files load lazily per cue (bytes may be fetched before the first gesture; decoding waits for the context), the likely next boss phase is prefetched, level-clear and travel are decoded after unlock, and at most six decoded cues are kept. Format order follows `canPlayType('audio/ogg; codecs="opus"')`; if every format fails, that cue falls back to its MIDI score through the synthesizer. `demonAudio.state` exposes read-only diagnostics for browser checks.

Effects stay on the synthesizer with unchanged trigger timing. Voice limiting steals the oldest voice when an effect exceeds its own cap (shot 4, hit 4, explosion 5) or 14 effect voices are live; explosion and life loss add a short filtered noise layer.

### MIDI fallback

`generate-midi.py` creates actual Standard MIDI Format 0 assets with tempo, note-on, note-off, and end-of-track events. Four level cues increase note density; four boss phases introduce stronger chromatic tension and increasingly rapid figures. Each boss phase has an evolved loop variant for subsequent runs. Victory changes to a major arpeggio and sustained chord; game over descends chromatically. Victory plays a finite triumphant opening and repeats its final four-beat major cadence until the next level cue, avoiding silence if the transition scene lasts longer than the MIDI opening. Game over remains finite. The fourth boss phase adds the fastest chromatic arpeggios, with another density increase for evolved runs. Menu music is quiet and spacious.

The fallback is a custom MIDI event synthesizer. These portable `.mid` files can also be played by external MIDI software. Browser audio starts after an actual pointer/key gesture; mute has a short gain ramp; pausing freezes the audio clock. Backgrounding pauses playback.

Integration: load `audio/demon-audio.js` before Flutter bootstrap, then call `window.demonAudio.cue(mode, level, phase, cycle)` for `menu`, `level`, `boss`, `victory`, or `gameover`. Other methods: `unlock()`, `mute(boolean)`, `pause()`, `resume()`, `sfx(name)`. SFX names: `shot`, `explosion`, `hit`, `powerup`, `life`. Native platforms need a separate audio adapter; this first implementation targets the deployed web app. `demonAudio.graph` exposes the shared `{context, master, music, effects}` nodes read-only, for `comms-audio.js`.

## Squad comms voices

The squad video call's radio lines are short clips in `web/audio/comms/<clip id>.ogg` (Opus) and `.m4a` (AAC-LC), one per line of the bank in `art/comms/lines.json` (clip ids `<trigger>.h<n>` for spoken lines, `<trigger>.d<n>` for demon grunts, in list order). `web/audio/comms/manifest.json` records every clip's speaker, kind, trigger, duration, mouth track, loudness, byte sizes and SHA-256, plus the Kokoro revision and the SHA-256 of every model and voice file used.

### Pipeline (`tools/comms_pipeline.py`)

Specs, all committed: `art/comms/cast.json` (characters, Kokoro voice and speed per human, grunt parameters per demon officer), `art/comms/lines.json` (triggers and lines) and `art/comms/audio.json` (Kokoro repo + revision, pronunciation overrides, gibberish syllables, radio chain, loudness, codecs). Stages, run with the comms venv (`-I`):

| Stage | Does |
| --- | --- |
| `voices` | Kokoro-82M (CPU, 6 torch threads) speaks each human line with its character's voice and speed → 24 kHz WAV in `$COMMS_WORK/raw` (default `~/.cache/demon-attack/comms`, outside the checkout). Cached per clip on (voice, speed, text, revision, overrides). misaki's espeak-ng fallback is disabled (the bundled `espeakng-loader` library aborts on this host); every out-of-vocabulary word is spelt with an explicit phoneme override in `audio.json` (`Krybor`, `Ringfall`, `Woohoo`, `flyboy`, `Brrrrt`). |
| `grunts` | Synthesised demon grunts, seeded by clip id (below). |
| `radio` | The radio chain (below), mouth track, BS.1770 gated loudness normalisation (−18 LUFS human, −18.5 demon, soft limit at −3 dBFS). |
| `encode` | ffmpeg: Opus 20 kbps VBR `voip` mono and AAC-LC 28 kbps mono with a 4 kHz cutoff (without it the native AAC encoder spends bits on the empty highs and rings up to 6 dB over the ceiling), 24 kHz, bit-exact; writes the manifest and removes stray files. Re-encoding the same masters reproduces the same bytes. |
| `verify` | Decodes every file: length vs manifest (±60 ms), decoded peak ≤ 0 dBFS, loudness within 1.5 LU, grunts 0.5–1.9 s, mouth track length, hashes, bank ↔ manifest. |
| `stats` | Median pitch, spectral centroid and speaking rate per character (distinctness check). |
| `dart` | Generates `lib/comms/comms_bank.dart` with the measured durations and mouth tracks. |
| `all` | `voices grunts radio encode verify dart`. |

Setup (keep everything off the checkout):

```bash
SCR=<scratch>/comms
export UV_PYTHON_INSTALL_DIR=$SCR/py UV_CACHE_DIR=$SCR/cache HF_HOME=$SCR/hf HF_HUB_DISABLE_XET=1 COMMS_WORK=$SCR/work
uv python install 3.12 && uv venv --python 3.12 $SCR/venv
uv pip install --python $SCR/venv/bin/python --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple torch
uv pip install --python $SCR/venv/bin/python kokoro soundfile numpy scipy espeakng-loader
uv pip install --python $SCR/venv/bin/python <en_core_web_sm-3.8.0 wheel from the spaCy models release>
$SCR/venv/bin/python -I tools/comms_pipeline.py all
```

(The Hugging Face Xet transfer backend is unreachable from the forge; `HF_HUB_DISABLE_XET=1` downloads the model over plain HTTPS.)

### Radio chain

Silence trimmed (−42 dB, 15 ms pad) with 10 ms edge fades; 4th-order Butterworth band-pass (human 300–3400 Hz; demon "enemy intercept" 200–3000 Hz), a presence peak (human +3 dB at 1.8 kHz, demon +4 dB at 1.1 kHz), tanh saturation (drive 1.9 / 2.4) and the band-pass again so the harmonics stay in band; band-limited hiss under the transmission (−44 / −40 dB, demons add a 55 Hz + 165 Hz hum). Key-up: a 9 ms click (1.45 kHz human, 0.98 kHz demon) and a 50 ms burst of open-carrier noise, 70 ms before the voice. Key-down: a 160 ms decaying squelch tail ("kssh") and a closing click.

### Demon grunts

Unintelligible, cartoonish creature vocalisations, never words. Each grunt is a plan of syllables per gesture (`GRUNT_KINDS`): `order` barks two or three falling syllables, `rally` rises into a long whoop, `gloat` chuckles in five bouncing pulses, `alarm` yelps high/low, `roar` swells one long bellow (more growl and rasp), `snarl` is a short raspy snap. Two layers share the syllable envelope:

1. **Growl**: a glottal pulse train at the officer's base pitch (Gorrak 70 Hz, Vexxa 190, Skarn 105, Morth 85, Ulgra 55) following the syllable's pitch contour, with wobble vibrato and jitter; every other cycle is weakened by the officer's `rasp` (period doubling, the throaty creature texture) plus pulse-synchronous breath noise; filtered through three cartoon-vowel formant resonators scaled by the officer's `formant` factor, sliding ("wah") from one vowel to another across each syllable.
2. **Gibberish**: random nonsense syllables (onsets/vowels/codas in `audio.json`) spoken by Kokoro from phonemes with a voice no character uses (`am_echo`), resampled down by the officer's formant factor (pitch and formants drop together), granulated back to the grunt length with 70 ms jittered grains (smearing any phonetic detail), ring-modulated at half the base pitch and band-limited.

They are mixed by the officer's `growl` weight, softly saturated and faded, then sent through the demon radio chain. The clip id seeds every random choice. Mouth tracks for grunts use frames 0, 3, 4 and 7 (the roar frame at the loudest moments, which drives the portrait zoom).

### Mouth tracks

One portrait frame per 1/15 s across the whole clip (`mouth` in the manifest and the Dart bank), from the clean voice's RMS relative to the clip's loudest 1/15 s (median-filtered): `0` closed (< −28 dB), `2` slightly open, `3` half, `4` wide (≥ −8 dB), and `5` (rounded) for the most low-frequency-heavy fifth of the open frames. Lead-in and squelch tail frames are `0`.

### Playback (`web/audio/comms-audio.js`)

`window.commsAudio = {prefetch(ids), play(id, priority, demon), stop(id), stopAll(), setVolume(v), state}`. It shares demon-audio.js's AudioContext and master gain through `demonAudio.graph` (one added getter is the only change to demon-audio.js), so master mute and pause (context suspend) silence voices too. Voices run through their own bus gain (+2 dB playback gain × the voice volume; `setVolume(0)` mutes comms and stops live voices) into the master. `play` is a no-op returning false before the first gesture has created the context, at volume 0, or for a clip already playing. At most **2** voices sound at once: beyond the cap the lowest-priority (then oldest) voice is released over 40 ms if the new priority is at least as high, otherwise the new clip is dropped (`state.dropped`). While any voice is live the music bus ramps to 0.4 (`setTargetAtTime`, 60 ms) and returns to 1 (120 ms) 300 ms after the last voice ends; the effects bus is never ducked. Bytes may be fetched before the gesture; decoding waits for the context. Format order follows `canPlayType('audio/ogg; codecs="opus"')`; a clip whose formats all fail frees its slot. `state` reports `{context, voices, ducked, duckGain, musicGain, volume, loaded, played, dropped, maxConcurrent, cap, formats}`.

### Sizes

| Set | Clips | Audio | Opus | AAC |
| --- | ---: | ---: | ---: | ---: |
| Human lines | 207 | 547 s | 1.46 MB | 2.18 MB |
| Demon grunts | 63 | 68 s | 0.19 MB | 0.31 MB |
| **Total** | **270** | **615 s** | **1.64 MB** | **2.49 MB** |

Clips load lazily (`prefetch` the lines a sector can use); a typical line is 2–3 s and 5–8 KB of Opus. `test-worker/comms-audio.test.mjs` covers the no-op before the gesture, the shared master, ducking and its release, the two-voice cap with steal-by-priority and drop, voice volume, a missing clip freeing its slot, and that every manifest clip ships both formats within budget.

## Global leaderboard

One SQLite-backed Cloudflare Durable Object owns the worldwide table. `GET /api/scores` returns `{scores:[{rank,initials,score}]}`. `POST /api/scores` accepts only JSON `{initials:"ABC",score:123}` and returns the resulting Top10. It keeps exactly ten rows, orders by descending score, and favors earlier submissions on ties. The submitted initials must match `[A-Z0-9]{3}`; score must be an integer from 0 through 999999999. Requests are streamed with a 256-byte cap, unknown fields are rejected, and cross-origin browser writes are rejected. Responses are uncached. No account, name, IP address, timestamp, or tracking ID is stored in the score database. Cloudflare infrastructure logging remains governed by deployment configuration.

Scores are client reported. Input validation prevents malformed data but does not prove that a game was played or defeat cheating; a determined caller can forge a legal numeric score. Before competitive use, add server-issued run tickets, event/replay validation, and suitable request throttling. The current scope is an arcade honor board rather than a verified tournament service.

Wrangler uses `HIGH_SCORES`, class `HighScores`, with migration `v1` / `new_sqlite_classes`. Assets remain served through `ASSETS` and `/api/*` runs the Worker first. Cloudflare docs: [SQLite storage API](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/) and [Durable Object migrations](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/).

## Validation

`npm run test:worker` runs four tests: score bounds/initials/body shape, persistent Top10 eviction and tie order using real SQLite, HTTP routing/origin checks, and MIDI scheduling/gesture unlock/mute/pause/resume with an instrumented audio clock. `test-worker/music.test.mjs` adds recorded-cue playback on the same instrumented clock (silent before the gesture, bar-aligned starts, release across the bar line, stale requests, phase-preserving pause/resume, immediate level clear, tail loop points, non-looping game over, MIDI fallback for a missing file) and checks that every cue ships with whole-bar loops inside a modest Opus budget. `tools/music_pipeline.py verify` checks the encoded files themselves. `node --check web/audio/demon-audio.js` validates syntax. Actual listening and game-state timing remain part of browser playtesting.

A real local Wrangler runtime smoke test also passed: GET, valid POST, invalid initials rejected, SQLite-backed persistence, and MIDI asset served. `wrangler deploy --dry-run --no-bundle` passed with the full Flutter build and both bindings. No remote deployment was performed.
