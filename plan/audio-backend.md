# Audio and global Top10

Implemented in `web/audio/`, `worker/index.mjs`, and `test-worker/`.

## Music direction

Original music only. Each level keeps its original motif (a riff, a lead hook and a chord progression), and every cue of the level is built on it. Round 3 turned the levels into battle music at their own tempos, inspired by the traits of battle and power metal; prompts describe genre traits only and never name a band or song: fast battle-punk metal for Krybor (170 BPM), melodic power metal for Ringfall (160), heavy galloping battle metal for Ember Moon (180), epic doom-battle for The Hollow (150), and blackened battle and death metal for the Carrier (190). Arrivals, outros and travel are symphonic metal (choir, strings, orchestral hits, a wordless soprano vocalise) at the level's tempo. Successes are a military march for the fleet (120 BPM), and game over is a cackling demon laugh followed by a twisted alien victory march (120). No cue quotes or imitates an existing song, band, game or composer. The motifs, tempos, the cue table and the event map are in [style-guide.md](style-guide.md#current-music-score-and-playback).

### Recorded cues (primary)

Every cue ships as `web/audio/music/<cue>.ogg` (Opus, 80 kbps) and `<cue>.m4a` (AAC-LC, 128 kbps, for browsers that cannot decode Ogg Opus). `manifest.json` records each cue's kind, length, loop points, source (seed, denoise, motif similarity) and file hashes.

**How the motif stays consistent: guide audio re-performed by ACE-Step.** The ComfyUI studio exposes these ACE-Step 1.5 paths: text-to-music (`TextEncodeAceStepAudio1.5` + `EmptyAceStep1.5LatentAudio`), audio-to-audio (`VAEEncodeAudio` of a source into the latent, then `KSampler` with denoise < 1), a timbre reference (`ReferenceTimbreAudio`, which conditions on the latent of a reference clip), repaint (`SetLatentNoiseMask` over a time range) and extend (`LatentConcat`/`LatentCut`). Fixed seeds and prompts alone give no motif control. Three takes of one prompt correlate at only 0.09–0.55 in beat chroma (mean 0.28). They share key and tonic, but not riff or rhythm: their onset correlation is −0.09 to 0.49. Picking by similarity would then compare unrelated riffs. The pipeline therefore:

1. writes each level's motif as note events (`tools/music_motifs.py`): an eighth-note riff root per position over 8 bars, a lead hook, the progression and a drum style, and arranges it into four intensity tiers, a 4-bar intro and a 4-bar outro;
2. renders each arrangement to a **guide** with a deterministic numpy synthesizer (`tools/music_guide.py`: double-tracked amp-simulated guitars, bass, drum kit, lead, brass, choir, organ and bells). Loop guides carry two bars of their own end before and two bars of their start after the loop, so the cut window sits in musical context;
3. generates one **genre reference take** per group with text-to-music (`ref-1` … `ref-alien`, not shipped);
4. re-performs every guide **audio-to-audio** (`art/workflows/music/acestep15-a2a.json`: guide → `VAEEncodeAudio` → `KSampler` denoise 0.45, 8 turbo steps, LM audio codes off as the node advises for an audio reference) with the group's reference take as `ReferenceTimbreAudio`. The denoise keeps the guide's riff, harmony, rhythm and bar grid. The genre take sets the instrument sound, and because it is the same for all of a level's cues, their production matches too;
5. picks one of four seeds per cue by `score = chroma + 0.5·onset + 2·reference closeness + 0.5·denoise`, with a penalty under 0.25 chroma and another when the take moved its onsets off the guide grid (best onset lag beyond ±30 ms), and cuts the **guide-aligned window**. That is the same window in every tier, so all four tiers of a level start on the same motif bar and a tier change can keep the loop position.

A sweep on the punk and metal guides settled the settings. At denoise 0.5 without a reference, motif chroma is 0.77, but the result keeps the synthesizer's spectrum (flatness 0.10 against 0.22 for a real ACE take). With the reference, chroma at denoise 0.6–0.8 falls to 0.0–0.14: the motif is lost. At 0.45 with the reference, chroma stays at 0.4–0.8 while the long-term spectrum moves to the genre take (closeness 0.6–0.95). Seeds and denoise are fixed per cue, so a rerun reproduces the selection for the same model files. Two cues needed care. ACE moved the L3 tier-2 gallop a sixteenth early in all four takes at 0.45, so `l3-t2` widens to 8 seeds × denoise 0.45/0.35, and a 0.35 take keeps the grid (lag 0, onset 0.85). `l4-t3` is pinned to seed 41, because the top-scored take left a click-like curvature at its Opus wrap. Pin a candidate with `"pick": <seed>` (and `"pick_denoise"`) in `cues.json`.

**Round 3 (battle metal, tempos).** `tools/music_motifs.py` sets a tempo per level by an integer number of samples per bar at 48 kHz (`BAR_SAMPLES`: L1 67 765 → 169.9993 BPM, L2 72 000 → 160, L3 64 000 → 180, L4 76 800 → 150, L5 60 632 → 189.9987), so every whole-bar cue is sample-exact at its tempo. The arrangements (`battle_drums`, `battle_rhythm`, `battle_lead`, `hey_chants`, `battle_pads`; symphonic `intro_events`/`outro_events`) render at that tempo. Guides are padded to a multiple of 3840 samples, so ACE returns exactly the guide length (`analyze` records `length_ok`). Each level has a battle and a symphonic text-to-music reference take (groups `1`–`5`, `s1`–`s5`) at its tempo; they now serve only the reference-closeness score. **Round 3 drops `ReferenceTimbreAudio`** (workflow `acestep15-a2a-plain.json`): at 150–190 BPM it imposed a foreign ~0.4 s pulse on every take. Measured by circular onset autocorrelation on the L3 tier-2 guide (180 BPM): guide 180.0, VAE round trip 180.3, audio-to-audio without the reference 180.5, with it 150.0. With the reference, onsets fell from 10.8/s to 4.4/s; without it, motif chroma went 0.65 → 0.72 and closeness to the battle take 0.82 → 0.88. Tiers re-perform the guide at denoise 0.45 or 0.55 (chosen per cue); intros and outros pass wordless vowel lyrics. Selection rejects any take whose pulse is not the target tempo, and `verify` checks it (`tempo_check`) and the chroma alignment with the guide. A round-3 experiment found that vocal lyrics (`Hey!`, `Aaah`) change little at 0.45. Onset-envelope lags against the synthetic guide reflect ACE's softer drum transients, not time shifts: shifting a cut by them moved the chroma and mel alignment off zero. So cuts stay at the guide window, which audio-to-audio keeps aligned because its latent frames are positional. `generate --batch 6` queues prompts together so they run back to back on one model load on the shared GPU. The marches, alien victory, cackle and menu are round-2 recordings marked `keep` and are not regenerated. Shipped set: 4.79 MB Opus, 7.18 MB AAC.

Synth cues are rendered directly. The accent sprites `l<n>-accents` hold eight 1.5 s slots (dive, last stand, hatch, reinforcements, ground breakthrough, destroyed, gloat, respawn), rendered at the level's tempo, played in that level's motif pitches and instrumentation. The `cackle` uses formant synthesis: a falling glottal pulse train through /a/ formants, aspirated onsets, a growling octave-down double and a cavernous room, about 4.6 syllables per second, falling from ~360 to ~240 Hz and ending in a long "haaa".

Pipeline (`tools/music_pipeline.py`; python3 + numpy + scipy + ffmpeg with libopus/aac):

```
tools/music_pipeline.py guides                      # motif guides -> build/music/guides/
tools/music_pipeline.py generate --stage refs       # genre reference takes (or `jobs --stage refs` -> studio.run_workflow)
tools/music_pipeline.py refs                        # pick one reference per group -> refs.json
tools/music_pipeline.py generate --stage a2a        # every cue, audio-to-audio (jobs --stage a2a: inputs $guide/$reference)
tools/music_pipeline.py generate --stage text       # text-only cues (menu)
tools/music_pipeline.py analyze && tools/music_pipeline.py build && tools/music_pipeline.py verify
tools/music_pipeline.py report                      # listening proxies; table -> docs
python3 web/audio/generate-midi.py                  # MIDI fallback from the same motifs
```

`generate` talks to ComfyUI directly (`--comfy http://studio:8188`, default) and uploads the guide and reference audio. `jobs` prints the same graphs as `studio.run_workflow` requests whose `inputs` bind the `$guide` and `$reference` `LoadAudio` nodes (copy those files under `/work/tmp/imagegen/` first); `ingest` brings studio outputs back. `build` cuts each a2a cue at the guide offset (4 s for loops, 2 s for intros and fanfares), builds the loop seam (a loop's first 120 ms crossfades from the audio that really follows the window, so the wrap is the original continuous waveform; a tail plays its opening, then a crossfaded copy of its last bar loops), removes DC and normalises loudness. Levels are mastered to −19 LUFS (dense, distorted mixes sound louder than their integrated loudness and mask effects), the marches and the alien theme to −18 LUFS, the accents to −20 and the cackle to −17, all with peaks at or below −1 dBFS. Each codec is primed with real context and trimmed by the container (Opus pre-skip and final granule, MP4 edit list), so decoded files are sample-exact. `verify` decodes both formats and checks exact length, whole-bar loops, the wrap step and curvature, codec edges, peaks, the 120 BPM eighth grid, sprite slot tiling (five slots) and silent slot ends, and the 8 MB Opus budget. `report` measures the shipped Opus files.

### Playback

`web/audio/demon-audio.js` keeps the round-1 architecture: one audio-clock scheduler (25 ms timer, 120 ms lookahead) on a shared 120 BPM grid, cue changes on the next bar, a request counter that discards stale loads, gesture unlock, a 30 ms mute ramp, pause/resume by suspending the context (resume skips only whole beats, so the grid stays locked), and MIDI fallback when every recorded format of a cue fails.

- **Tempo-aware grid.** The scheduler's beat follows the active cue (`levelBarSamples` mirrors `BAR_SAMPLES`; 0.5 s for the 120 BPM cues). Every cue change waits for the current cue's bar line; a cue at another tempo starts its own grid there, so the old bar is always finished. Tier changes within a level keep the loop position. Immediate cues (clear, victory, finale, cackle) reset the grid to their own 120 BPM. The MIDI fallback plays on the same grid.
- **Level scene.** `cue('level', n)` (and `cue('boss', …)` for the carrier) plays `l<n>-intro`. That is 16 beats; then its last bar loops. `intensity(tier)` hands over to `l<n>-t<tier>` when the intro's opening has played. After that, tier changes land on the next bar and start the new tier at the same loop position (`start(at, offset)`, offset = beats since the tier section began, mod 32), because all four tiers share bar 1 of the motif. Rising tiers cut on the downbeat (60 ms out, 20 ms in). Falling tiers fade the old tier over one beat. Repeated carrier `boss` events do not restart the scene; without any `intensity` call the carrier's form picks the tier.
- **Accents.** `accent(name)` plays the current level's sprite slot at the next half-beat (dive, reinforcements), beat (last stand, hatch, breakthrough, gloat, respawn) or sixteenth (destroyed) of the level's grid, at least 30 ms ahead. It never waits on loading (with no decoded sprite yet, it plays a short synthesized figure), never replaces the music, allows each accent once per second and at most two at a time. The scheduled time is returned and logged in `state.accents`.
- **Cue mapping.** `travel` → the cleared level's `l<n>-outro`; `levelclear` → `levelclear`; `victory` → `victory`, or `finale` on the last route (`cycle ≥ 4`); `gameover` → `cackle` (immediate; a repeat notice does not restart it), whose successor `alienwin` starts on the bar line exactly 8 beats later and loops. Clear, victory, finale and the cackle start immediately with a 90 ms music-only fade.
- **Fleet intact.** `fleetIntact()` reports that the whole allied fleet survived. Called before the level clear or campaign finale, or in the same tick right after its cue (while the normal march is still loading), it makes that cue the bigger variant (`levelclear-fleet`, `finale-fleet`: the same march bar for bar, with a trumpet descant, a trombone counterline and a drum corps). Called while the normal cue is playing, it switches to the variant on the next bar at the same position (in the tail loop if the opening has passed). Without the event the normal cue plays. The flag clears at the next non-celebration cue, and `sfx('fleetIntact')` is ignored so the event never plays a hit sound.
- **Life loss.** `accent('destroyed')` (from `playerDestroyed`, or the observer's `lifeLost`) drops the music to 15 % for two bars under the hit; `accent('gloat')` plays during `regroupStart`; `accent('respawn')` brings the music back on its downbeat. Any new cue restores it. The life-loss accents ignore the two-at-once accent cap.
- **Mixing.** Music gain stages: cue gain 0.7 → `drop` (life loss) → `sidechain` (−2 dB for ~150 ms under explosions, hits and life-loss effects) → `music` (the comms layer ducks this one through `demonAudio.graph`) → master. Accents connect after the drop. Effects play at 1.0.
- **Lazy loading.** Only a level's own set is fetched when the level is cued: tier 1 and the accents first, then the other tiers and the outro, and the next level's intro while clearing or travelling. Up to 12 decoded cues are kept, and the current level's set and the level clear are never evicted. Effects play at 0.9 against music at 0.7 (round 1: 0.7 and 0.7), so shots and explosions stay above the denser mixes.
- `demonAudio.state` adds `scene` (level, section, tier), `offset` and the accent log to the read-only diagnostics.

Effects stay on the synthesizer with unchanged trigger timing. Voice limiting steals the oldest voice when an effect exceeds its own cap (shot 4, hit 4, explosion 5) or 14 effect voices are live; explosion and life loss add a short filtered noise layer.

### Game-side event bridge

Music runs on the shared game-event bridge (`lib/game/game_events.dart`: the model queues `GameEvent`s, `main.dart` drains them into `dispatchGameEvent`, and consumers subscribe with `GameEvents.listen`). `MusicDirector` (`lib/game/music_director.dart`) reads the model once per frame and **publishes** music events on that bridge. They are named in `GameEventNames.music`: `musicIntensity` (data `tier`, `level`), `diveTell`, `lastStandTell`, `carrierHatchOpen` and `reinforcementsArrived`. Other layers, such as the commander comms panel, can listen too. The director also **listens**: `allyUnderAttack` and `groundForceInRange` lift the tier for 6 s like a reinforcement arrival, and ground pressure (`model.ground.pressure`, 0–1, read each frame; also published as `groundPressure {level}`) adds a tier from 0.4 and two from 0.8. `groundBreakthrough` (L3–L4) plays the **breakthrough** accent. `MusicBridge` is the one listener that plays music. It sends `musicIntensity` to `audioIntensity(tier)`, the four tells to `audioAccent(dive|laststand|hatch|reinforce)`, and `fleetIntact` to `audioFleetIntact()` (`lib/services/audio_web.dart` → `demonAudio.intensity` / `accent` / `fleetIntact`; no-ops off the web). The director is read-only: it never writes to the model, and a test checks the checkpoint is unchanged. Hook lines, each marked `// --- music event hook`: three in `scene.dart` (the import, the `music` field, and `music.observe(model, dt)` right after `model.update(dt)`, before `onTick` takes the string events, so it sees `reinforcements`), and four in `main.dart` (the import, the listener list, registering both listeners after the scene is built, and removing them in `dispose`). The cue events (`level`, `boss`, `levelclear`, `travel`, `victory`, `defeat`, `gameover`, `completed`) still go through `main.dart`'s `audioCue` unchanged. `fleetIntact` (data `scope`: `level` at sector clear, `campaign` at victory) is drained in the same tick right after the clear cue. The player then starts the fleet variant in place of the still-loading normal march, or switches in place on the next bar if the normal march is already playing.

### MIDI fallback

`generate-midi.py` writes Standard MIDI Format 0 files, each with its cue's tempo meta, for every cue from the same motif events (`tools/music_motifs.py`), keeping riff, bass, lead, kick and snare, and drops cymbals and pads. A tier that fails to load therefore still plays its motif on the same grid. The peril tier has at least 1.3× the note events of tier 1 (tested). The cackle falls back to falling staccato "ha" notes, and the menu keeps its sine-pad motif. The fallback synthesizer voices channel 9 as percussion, 1 as sawtooth, 2 as sine and the rest as square waves.

Integration: load `audio/demon-audio.js` before Flutter bootstrap, then call `window.demonAudio.cue(mode, level, phase, cycle)` for `menu`, `level`, `boss`, `levelclear`, `travel`, `victory` or `gameover`, and `intensity(1..4)` and `accent('dive'|'laststand'|'hatch'|'reinforce')` during play. Other methods: `unlock()`, `mute(boolean)`, `pause()`, `resume()`, `sfx(name)`. Native platforms need a separate audio adapter; this implementation targets the deployed web app.

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

**Round 3 checks (battle metal, tempos).**

- **Pipeline `verify`** passes on all 43 cues. Loops and tails are whole integer bars at each tempo, wraps and codec edges are clean, and the onset grid lines up with the guide by chroma cross-correlation over ±1 beat. No take shows a strong foreign pulse; 20 of the 30 level cues have only weak periodicity (smeared drums), so the tempo estimate is uninformative for them and their alignment rests on the chroma check. Shipped Opus is 4.79 MB.
- **Listening proxies against round 2** (tiers): onsets 7.14 → 9.13/s (tier 1: 4.25 → 8.22), crest factor 11.0 → 10.2 dB. The noise and brightness proxies did not rise overall: flatness 0.119 → 0.094 and high-band share 0.045 → 0.037; only tier 1's flatness rose (0.157 → 0.229). The plain audio-to-audio takes are more tonal than round 2's referenced ones. Symphonic intros and outros: onsets 5.14 → 8.32/s.
- **Headless Chromium** with the shipped Opus files passes 47 of 47 checks. Every cross-tempo hand-over (120 → 170, 170 → 160, 120 → 160, 160 → 180, 180 → 150, 150 → 190, 190 → 120) lands on a bar line of the outgoing cue's grid. Every tier change keeps the loop position, the level clear is immediate, and dive, respawn and destroyed quantize to each level's beat.
- **`test-worker/music.test.mjs`** covers the cross-tempo hand-over (L2 outro → L3 intro), the life-loss drop and re-entry, and that the player's bar table equals the manifest.

`npm run test:worker` runs the worker tests and three music tests on an instrumented audio clock. `test-worker/audio.test.mjs` covers the MIDI fallback: every tier, the carrier intro and tiers, victory cadence, outro, level clear, wave stinger, the synthesized accent fallback, cackle → alien theme, mute and pause/resume. `test-worker/music.test.mjs` covers recorded playback: silent before the gesture, lazy per-level loading, intro → tier on its 16-beat boundary, tier changes on bar lines at the same loop position (short cut rising, one-beat fade falling), accent quantization to the half-beat/beat and the sprite slot, stale requests, phase-preserving pause/resume, immediate level clear / finale / cackle, the alien theme 8 beats after the cackle, the fleet-intact variants (chosen before the cue, or switched in place on a bar), MIDI fallback for a missing tier, and that every cue in `cues.json` ships with whole-bar loops inside the 8 MB Opus budget. `test/music_director_test.dart` checks the event → tier/accent mapping and that the director leaves the model unchanged. `tools/music_pipeline.py verify` checks the encoded files and `report` the listening proxies. `node --check web/audio/demon-audio.js` validates syntax. Subjective listening remains part of browser playtesting.

A real local Wrangler runtime smoke test also passed: GET, valid POST, invalid initials rejected, SQLite-backed persistence, and MIDI asset served. `wrangler deploy --dry-run --no-bundle` passed with the full Flutter build and both bindings. No remote deployment was performed.
