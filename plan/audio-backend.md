# Audio and global Top10

Implemented in `web/audio/`, `worker/index.mjs`, and `test-worker/`.

## Music direction

Original music only: retro sci-fi arcade fused with dark synth and orchestral tension, growing more demonic deeper into the campaign, with boss phases escalating. No cue imitates an existing game's soundtrack, and no prompt names a game, composer or soundtrack. All cues share a 120 BPM 4/4 grid so cues change on a four-beat boundary while release tails overlap.

### Recorded cues (primary)

The shipping music is a set of recorded loops generated locally with ACE-Step 1.5 (apache-2.0) in the project's ComfyUI studio, one per cue, in `web/audio/music/<cue>.ogg` (Opus, 80 kbps) and `<cue>.m4a` (AAC-LC, 96 kbps, fallback for browsers that cannot decode Ogg Opus). `web/audio/music/manifest.json` records every cue's kind, length, loop points, chosen seed, source tempo, cut point and file hashes. See the cue table in [style-guide.md](style-guide.md#current-music-score-and-playback).

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

Integration: load `audio/demon-audio.js` before Flutter bootstrap, then call `window.demonAudio.cue(mode, level, phase, cycle)` for `menu`, `level`, `boss`, `victory`, or `gameover`. Other methods: `unlock()`, `mute(boolean)`, `pause()`, `resume()`, `sfx(name)`. SFX names: `shot`, `explosion`, `hit`, `powerup`, `life`. Native platforms need a separate audio adapter; this first implementation targets the deployed web app.

## Global leaderboard

One SQLite-backed Cloudflare Durable Object owns the worldwide table. `GET /api/scores` returns `{scores:[{rank,initials,score}]}`. `POST /api/scores` accepts only JSON `{initials:"ABC",score:123}` and returns the resulting Top10. It keeps exactly ten rows, orders by descending score, and favors earlier submissions on ties. The submitted initials must match `[A-Z0-9]{3}`; score must be an integer from 0 through 999999999. Requests are streamed with a 256-byte cap, unknown fields are rejected, and cross-origin browser writes are rejected. Responses are uncached. No account, name, IP address, timestamp, or tracking ID is stored in the score database. Cloudflare infrastructure logging remains governed by deployment configuration.

Scores are client reported. Input validation prevents malformed data but does not prove that a game was played or defeat cheating; a determined caller can forge a legal numeric score. Before competitive use, add server-issued run tickets, event/replay validation, and suitable request throttling. The current scope is an arcade honor board rather than a verified tournament service.

Wrangler uses `HIGH_SCORES`, class `HighScores`, with migration `v1` / `new_sqlite_classes`. Assets remain served through `ASSETS` and `/api/*` runs the Worker first. Cloudflare docs: [SQLite storage API](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/) and [Durable Object migrations](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/).

## Validation

`npm run test:worker` runs four tests: score bounds/initials/body shape, persistent Top10 eviction and tie order using real SQLite, HTTP routing/origin checks, and MIDI scheduling/gesture unlock/mute/pause/resume with an instrumented audio clock. `test-worker/music.test.mjs` adds recorded-cue playback on the same instrumented clock (silent before the gesture, bar-aligned starts, release across the bar line, stale requests, phase-preserving pause/resume, immediate level clear, tail loop points, non-looping game over, MIDI fallback for a missing file) and checks that every cue ships with whole-bar loops inside a modest Opus budget. `tools/music_pipeline.py verify` checks the encoded files themselves. `node --check web/audio/demon-audio.js` validates syntax. Actual listening and game-state timing remain part of browser playtesting.

A real local Wrangler runtime smoke test also passed: GET, valid POST, invalid initials rejected, SQLite-backed persistence, and MIDI asset served. `wrangler deploy --dry-run --no-bundle` passed with the full Flutter build and both bindings. No remote deployment was performed.
