# Audio and global Top10

Implemented in `web/audio/`, `worker/index.mjs`, and `test-worker/`.

## Music direction

Original music only. The levels are battle music at their own tempos, inspired by the traits of battle and power metal; prompts describe genre traits only and never name a band or song: fast battle metal for Krybor (170 BPM), melodic power metal for Ringfall (160), heavy galloping battle metal for Ember Moon (180), epic doom-battle for The Hollow (150), and blackened battle metal for the Carrier (190). Arrivals, outros and travel are symphonic metal (choir, orchestra, timpani, wordless operatic soprano pads, heavy guitars) at the level's tempo, and the menu is a dark symphonic-metal theme. Successes are a battle-metal military march for the fleet (120 BPM; bigger `-fleet` variants when the whole fleet survived), and game over is a demonic cackle followed by a sinister alien victory march (120). Everything is instrumental. No cue quotes or imitates an existing song, band, game or composer. Tempos, the cue table and the event map are in [style-guide.md](style-guide.md#current-music-score-and-playback).

### Recorded cues (primary)

Every cue ships as `web/audio/music/<cue>.ogg` (Opus, 80 kbps) and `<cue>.m4a` (AAC-LC, 128 kbps, for browsers that cannot decode Ogg Opus). `manifest.json` records each cue's kind, length, loop points, source (mode, seed, source tempo, window start, seam similarity; for a2a cues the denoise), its timbre measurements (`flat15`, `perc`, `crestDb`, `fluxAbs`, `guideDistance`) and file hashes.

**Metal-v2 (2026-11-10): ACE-Step's own band takes at the exact tempo.** The operator heard the round-3 score on a phone as "still the old simple one". Round 3 re-performed the synthesized motif guides audio-to-audio at denoise 0.45–0.55, and at that strength ACE keeps the guide's synth character: its 1–5 kHz band is tonal (spectral flatness 0.09 on `l1-t3`, where ACE's own metal takes measure 0.26–0.47), the drums stay soft (percussive share 0.20 against 0.30–0.39), and its frame-level log-mel still follows the guide (melR 0.32). The selection score (motif chroma plus closeness to a reference take) rewarded exactly those guide-like takes. A sweep on the `l1-t3` guide ruled out the obvious fixes:

| Setting (L1 t3 guide, 170 BPM) | 1–5 kHz flatness | Onset r to guide | Pulse |
| --- | ---: | ---: | --- |
| round 3: turbo, denoise 0.45 | 0.09 | 0.50 | 170 |
| turbo, denoise 0.6 / 0.7 / 0.8 / 0.9, metal tags | 0.09 / 0.08–0.14 / 0.09–0.16 / 0.21–0.31 | 0.02–0.14 | 107–190, mostly not 170 |
| XL base model, 32 steps, cfg 5, negative "chiptune, synthesizer…" tags, 0.5–0.7 | 0.12–0.29 | 0.02–0.22 | 100–235 |
| LM audio codes on, 0.6–0.8 | 0.20–0.23 | 0.02–0.03 | 140 (foreign) |
| `ReferenceTimbreAudio` with a 170 BPM metal take, 0.45–0.75 | 0.15–0.25 | 0.09–0.25 | 150 (foreign) at every setting but one |
| drums-forward guide (`music_guide.MIX_V2`), 0.6–0.7 | 0.09–0.29 | 0.01–0.25 | mostly not 170 |
| **text-to-music, BPM field 85, "170 bpm" in the tags** | **0.26–0.41** | — | **170.0 in 7 of 8 seeds, drift ≤ 2.5 ms** |

Past about 0.55 the take stops following the guide's rhythm and drifts onto a pulse of its own, so no denoise keeps both the bar grid and a band sound. Text-to-music has the band sound, but asked for 150–180 BPM it mostly settles at 140–150 BPM (7 of 8 takes asked for 170). Asked for **half the tempo** in the encoder's BPM field with the real tempo in the tags, it locks to the real tempo exactly. That is what metal-v2 does:

1. `cues.json` (schema v4) gives every level a battle group (`1`–`5`) and a symphonic group (`s1`–`s5`) with genre tags, key, tempo and `bpm_param` (half the tempo), and groups for the march, the alien theme, the menu and the cackle. Tier tags escalate (1: driving groove, chugging rhythm guitars · 2: relentless double kick, galloping riffs · 3: harmonised twin leads · 4: blast beats, shredding solo, wordless choir, wall of sound); part tags make intros an overture and outros a majestic finale. Lyrics are `[instrumental]`.
2. `generate --stage text` renders six 40 s takes per cue (`acestep15-cue.json`, XL turbo, 8 steps, LM audio codes on; seeds 9101–9106, twelve for `l2-intro`, `l4-intro`, `l5-intro` and `victory`).
3. `analyze` measures each take (`text_scores`): the eighth-note lattice tempo must be within 0.4 % of the cue tempo (27 of 234 takes were rejected), the take is resampled to the exact grid (`BAR_SAMPLES`; measured offsets were ≤ 0.03 %), and the best downbeat window is chosen (`choose_window`, now at any tempo: a loop's next bar must match its first bar, no breakdown; a tail's last bar must match the bar after it). The window is scored as `rank (grid) + 2·window + 2·metal_score`, where `metal_score = 4·min(flat15, 0.45) + 3·min(perc, 0.42) + 1.5·min(gtr, 0.25) − 0.08·max(crest − 10.5, 0)` (`metal_metrics`: 1–5 kHz flatness, percussive share by median-filter HPSS, crest factor and band shares). Takes below 0.16 flatness, with a foreign pulse, or closer than 0.3 to the synth guide's long-term spectrum (`timbre_distance`) lose 2–3 points.
4. `build` picks a level's four tiers **jointly** (`choose_tiers`: the four best takes per tier, every combination scored by the sum of take scores, +1 for each rising and −1.5 for each falling step of window flux), so density rises from tier 1 to tier 4, then cuts, seams, normalises and encodes as before. All tiers of a level share tempo, key and an 8-bar loop that starts on a downbeat, so a tier change still lands on a bar and keeps the loop position; the tiers are now different riffs of one style rather than one motif re-arranged.
5. The fleet variants must be the same march bar for bar (the player switches in place). `derive` writes the take chosen for `levelclear`/`finale` (window plus one bar before and two after) as the source of `levelclear-fleet`/`finale-fleet`, which `generate --stage a2a` re-performs with the XL base model (`acestep15-a2a-base.json`: 32 steps, cfg 5, negative tags "sparse, thin, quiet, … synthesizer, chiptune"), denoise 0.45/0.55, with massed-brass, drum-corps and choir tags. The a2a score for a derived source rewards onset alignment with the source (0.85 and 0.91 picked), band timbre and extra flux; the variants are mastered 1 dB louder.
6. The cackle is the formant laugh (`music_guide.cackle`) re-performed audio-to-audio (turbo, denoise 0.5, seed 41 pinned) with sinister tags (demonic laughter, cavernous reverb, orchestral hit, distorted guitar chord): 0.4 stays the synth (mel r 0.96), 0.6 smears the syllables on most seeds.

The motifs in `tools/music_motifs.py` remain the source of the MIDI fallback and the accent sprites, and the synth guides remain the yardstick of `guideDistance`; the recorded cues no longer carry the motif. Takes at another tempo, wrong key or with vocals are not detectable from the metrics alone beyond the tempo gate; no take was auditioned by ear in this round.

**Old (round 3 / round 2) vs new, decoded Opus** (`tools/music_pipeline.py compare --old <dir>`; band shares of the spectrogram energy below 150 Hz / 150 Hz–1 kHz / 1–5 kHz / above 5 kHz, crest factor, 1–5 kHz flatness, percussive share, distance from the synth guide's long-term spectrum and the frame-level log-mel correlation with it):

| Group (cues) | Round | low / mid / gtr / air | Crest dB | Flat 1–5k | Perc | Guide dist | melR |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Battle tiers (20) | old | 0.38 / 0.45 / 0.16 / 0.008 | 10.2 | 0.177 | 0.197 | 0.38 | 0.34 |
| | new | 0.52 / 0.34 / 0.12 / 0.027 | 9.8 | 0.317 | 0.347 | 0.56 | 0.06 |
| Intros, outros (10) | old | 0.24 / 0.60 / 0.16 / 0.006 | 11.0 | 0.098 | 0.191 | 0.31 | 0.37 |
| | new | 0.43 / 0.44 / 0.12 / 0.019 | 10.0 | 0.239 | 0.317 | 0.46 | 0.12 |
| Marches, alien, menu, cackle (8) | old | 0.30 / 0.50 / 0.16 / 0.032 | 10.7 | 0.128 | 0.301 | 0.13 | 0.60 |
| | new | 0.45 / 0.39 / 0.14 / 0.020 | 11.3 | 0.245 | 0.365 | 0.30 | 0.20 |

| Cue | Old flat / perc / crest / melR | New flat / perc / crest / melR |
| --- | --- | --- |
| `l1-t1` … `l1-t4` | 0.45 / 0.29 / 9.9 / 0.14 · 0.16 / 0.22 / 11.3 / 0.36 · 0.09 / 0.20 / 10.3 / 0.32 · 0.10 / 0.22 / 9.9 / 0.23 | 0.33 / 0.35 / 10.1 / 0.17 · 0.35 / 0.37 / 11.4 / 0.03 · 0.34 / 0.37 / 10.4 / 0.05 · 0.35 / 0.36 / 10.6 / 0.09 |
| `l2-t1` … `l2-t4` | 0.43 / 0.27 / 11.4 / 0.08 · 0.07 / 0.20 / 9.8 / 0.48 · 0.12 / 0.21 / 9.7 / 0.30 · 0.11 / 0.26 / 9.8 / 0.28 | 0.21 / 0.33 / 8.4 / 0.14 · 0.26 / 0.35 / 9.2 / 0.06 · 0.32 / 0.40 / 9.3 / 0.00 · 0.30 / 0.38 / 11.3 / 0.03 |
| `l3-t1` … `l3-t4` | 0.47 / 0.14 / 6.9 / 0.07 · 0.06 / 0.14 / 10.1 / 0.61 · 0.08 / 0.23 / 10.7 / 0.32 · 0.09 / 0.20 / 10.2 / 0.31 | 0.35 / 0.30 / 9.7 / 0.19 · 0.36 / 0.36 / 9.2 / 0.02 · 0.43 / 0.40 / 9.7 / −0.04 · 0.33 / 0.38 / 9.8 / 0.03 |
| `l4-t1` … `l4-t4` | 0.23 / 0.20 / 11.6 / 0.45 · 0.18 / 0.13 / 12.1 / 0.56 · 0.10 / 0.15 / 10.3 / 0.43 · 0.11 / 0.24 / 9.9 / 0.32 | 0.37 / 0.34 / 9.5 / 0.02 · 0.37 / 0.32 / 9.6 / 0.06 · 0.29 / 0.35 / 9.7 / 0.05 · 0.18 / 0.29 / 9.3 / 0.01 |
| `l5-t1` … `l5-t4` | 0.26 / 0.14 / 8.0 / 0.11 · 0.22 / 0.16 / 11.0 / 0.57 · 0.12 / 0.16 / 10.1 / 0.54 · 0.10 / 0.18 / 10.2 / 0.34 | 0.31 / 0.36 / 9.6 / 0.04 · 0.40 / 0.32 / 9.3 / 0.04 · 0.32 / 0.29 / 9.6 / 0.09 · 0.18 / 0.33 / 10.7 / 0.03 |
| intros L1–L5 | 0.06 · 0.10 · 0.13 · 0.18 · 0.10 (flat) | 0.19 · 0.26 · 0.31 · 0.19 · 0.23 |
| outros L1–L5 | 0.06 · 0.06 · 0.07 · 0.11 · 0.12 | 0.24 · 0.21 · 0.22 · 0.23 · 0.32 |
| `levelclear`, `-fleet`, `victory`, `finale`, `-fleet` | 0.07 · 0.11 · 0.11 · 0.13 · 0.12 | 0.34 · 0.26 · 0.25 · 0.24 · 0.20 |
| `menu`, `alienwin`, `cackle` | 0.03 · 0.12 · 0.33 | 0.24 · 0.24 · 0.20 |

The 1–5 kHz flatness roughly doubles (0.18 → 0.32 on the tiers, 0.10 → 0.24 on intros and outros; every shipped cue except the cackle is ≥ 0.17, and `test-worker/music.test.mjs` holds the recorded cues to ≥ 0.16 and the tiers to a guide distance ≥ 0.3), the percussive share rises from 0.20 to 0.35 (real drum transients), and the frame-level correlation with the synth guide falls from 0.34 to 0.06. The "dense 1–5 kHz energy" proxy did not rise: ACE's metal mixes put more energy below 150 Hz (0.38 → 0.52 of the spectrum on the tiers), so their 1–5 kHz share is 0.12 against 0.16; what changed is that this band is now noise-like distortion instead of tonal synth partials. Two round-3 tiers already measured high flatness (`l1-t1`, `l2-t1`, `l3-t1` 0.43–0.47) because they were mostly bass rumble (low share up to 0.97). Tier density rises only modestly within a level (window flux L1 0.37 → 0.42, L2 0.29 → 0.35, L3 0.35 → 0.40, L4 0.34 → 0.41 with a dip at tier 2, L5 0.34 → 0.39): the tier tags change ACE's arrangement less than their wording suggests. The fleet variants are not denser than their source march by flux (levelclear 0.49 → 0.42, finale 0.38 → 0.37); they differ in timbre and are 1 dB louder. Shipped set: 4.46 MB Opus, 7.22 MB AAC (round 3: 4.79 / 7.18).

**Round 3 (superseded).** Round 3 re-performed the motif guides from `tools/music_guide.py` audio-to-audio (`acestep15-a2a-plain.json`, denoise 0.35–0.55, no timbre reference) and selected by `chroma + 0.5·onset + 2·reference closeness + 0.5·denoise`; round 2 did the same at 120 BPM with `ReferenceTimbreAudio`. `tools/music_motifs.py` still fixes each level's tempo as an integer number of samples per bar at 48 kHz (`BAR_SAMPLES`: L1 67 765 → 169.9993 BPM, L2 72 000 → 160, L3 64 000 → 180, L4 76 800 → 150, L5 60 632 → 189.9987), so every whole-bar cue is sample-exact at its tempo; the `a2a`/`refs` stages, guides and `ReferenceTimbreAudio` workflow remain in the pipeline. The timbre reference imposes a foreign ~0.4 s (150 BPM) pulse at these tempos (round 3: L3 tier-2 guide 180.0 BPM, a2a without the reference 180.5, with it 150.0; metal-v2 confirmed it with a 170 BPM reference).

Synth cues are rendered directly. The accent sprites `l<n>-accents` hold eight 1.5 s slots (dive, last stand, hatch, reinforcements, ground breakthrough, destroyed, gloat, respawn), rendered at the level's tempo, played in that level's motif pitches and instrumentation. The cackle's guide is formant synthesis: a falling glottal pulse train through /a/ formants, aspirated onsets, a growling octave-down double and a cavernous room, about 4.6 syllables per second, falling from ~360 to ~240 Hz and ending in a long "haaa".

Pipeline (`tools/music_pipeline.py`; python3 + numpy + scipy + ffmpeg with libopus/aac; candidates live outside the checkout, e.g. `--work ~/.cache/tillandsias-project/tmp/music-v2/work`):

```
tools/music_pipeline.py guides                      # synth motif guides (yardstick; cackle a2a source)
tools/music_pipeline.py generate --stage text       # every text cue: six takes each (jobs --stage text -> studio.run_workflow)
tools/music_pipeline.py generate --stage a2a --cue cackle
tools/music_pipeline.py analyze                     # tempo gate, window, metal metrics, guide distance
tools/music_pipeline.py build                       # joint tier pick, cut, seam, normalise, encode; writes choices.json
tools/music_pipeline.py derive                      # fleet sources from the chosen marches
tools/music_pipeline.py generate --stage a2a --cue levelclear-fleet finale-fleet
tools/music_pipeline.py analyze --cue levelclear-fleet finale-fleet && tools/music_pipeline.py build --cue levelclear-fleet finale-fleet
tools/music_pipeline.py verify
tools/music_pipeline.py report; tools/music_pipeline.py compare --old <previous round>   # listening proxies; table -> docs
python3 web/audio/generate-midi.py                  # MIDI fallback from the motifs
```

Run the numpy stages under `~/.cache/tillandsias-project/bin/forge-guard run --lock heavy --need 3 --`. `generate` talks to ComfyUI directly (`--comfy http://studio:8188`, default), uploads audio inputs and queues `--batch 6` prompts at a time so they run back to back on one model load on the shared GPU (a 40 s turbo take takes about 5 s). `jobs` prints the same graphs as `studio.run_workflow` requests whose `inputs` bind the `$guide` `LoadAudio` node (copy those files under `/work/tmp/imagegen/` first); `ingest` brings studio outputs back. `build` builds the loop seam (a loop's first 120 ms crossfades from the audio that really follows the window, so the wrap is the original continuous waveform; a tail plays its opening, then a crossfaded copy of its last bar loops; a one-shot with `fade_s` 0 ends with a 20 ms release), removes DC and normalises loudness: levels −18 LUFS with tier offsets −1.5/−1/0/+0.5 dB, symphonic cues −18.5, marches, alien theme and menu −18, the fleet variants and the cackle −17, the accents −19, all with peaks at or below −1 dBFS. Each codec is primed with real context and trimmed by the container (Opus pre-skip and final granule, MP4 edit list), so decoded files are sample-exact. `verify` decodes both formats and checks exact length, whole-bar loops, the wrap step and curvature, codec edges, peaks, the eighth-note grid at each cue's tempo (a2a cues: chroma alignment with their source and the pulse check), sprite slot tiling and silent slot ends, and the 8 MB Opus budget; all 86 checks pass.

### Playback

`web/audio/demon-audio.js` keeps the round-1 architecture: one audio-clock scheduler (25 ms timer, 120 ms lookahead) on a shared 120 BPM grid, cue changes on the next bar, a request counter that discards stale loads, gesture unlock, a 30 ms mute ramp, pause/resume by suspending the context (resume skips only whole beats, so the grid stays locked), and MIDI fallback when every recorded format of a cue fails.

- **Tempo-aware grid.** The scheduler's beat follows the active cue (`levelBarSamples` mirrors `BAR_SAMPLES`; 0.5 s for the 120 BPM cues). Every cue change waits for the current cue's bar line; a cue at another tempo starts its own grid there, so the old bar is always finished. Tier changes within a level keep the loop position. Immediate cues (clear, victory, finale, cackle) reset the grid to their own 120 BPM. The MIDI fallback plays on the same grid.
- **Level scene.** `cue('level', n)` (and `cue('boss', …)` for the carrier) plays `l<n>-intro`. That is 16 beats; then its last bar loops. `intensity(tier)` hands over to `l<n>-t<tier>` when the intro's opening has played. After that, tier changes land on the next bar and start the new tier at the same loop position (`start(at, offset)`, offset = beats since the tier section began, mod 32), because all four tiers are 8-bar loops starting on a downbeat of the same grid (metal-v2: different riffs of one style, picked for rising density). Rising tiers cut on the downbeat (60 ms out, 20 ms in). Falling tiers fade the old tier over one beat. Repeated carrier `boss` events do not restart the scene; without any `intensity` call the carrier's form picks the tier.
- **Accents.** `accent(name)` plays the current level's sprite slot at the next half-beat (dive, reinforcements), beat (last stand, hatch, breakthrough, gloat, respawn) or sixteenth (destroyed) of the level's grid, at least 30 ms ahead. It never waits on loading (with no decoded sprite yet, it plays a short synthesized figure), never replaces the music, allows each accent once per second and at most two at a time. The scheduled time is returned and logged in `state.accents`. Since the audio round, `dive` composes layers instead (see [Composable dive layers](#composable-dive-layers-audio-round)); the single dive slot remains its fallback while `l<n>-layers` is not decoded.
- **Cue mapping.** `travel` → the cleared level's `l<n>-outro`; `levelclear` → `levelclear`; `victory` → `victory`, or `finale` on the last route (`cycle ≥ 4`); `gameover` → `cackle` (immediate; a repeat notice does not restart it), whose successor `alienwin` starts on the bar line exactly 8 beats later and loops. Clear, victory, finale and the cackle start immediately with a 90 ms music-only fade.
- **Fleet intact.** `fleetIntact()` reports that the whole allied fleet survived. Called before the level clear or campaign finale, or in the same tick right after its cue (while the normal march is still loading), it makes that cue the bigger variant (`levelclear-fleet`, `finale-fleet`: the same march bar for bar, re-performed audio-to-audio with massed brass, drum-corps and choir tags and mastered 1 dB louder). Called while the normal cue is playing, it switches to the variant on the next bar at the same position (in the tail loop if the opening has passed). Without the event the normal cue plays. The flag clears at the next non-celebration cue, and `sfx('fleetIntact')` is ignored so the event never plays a hit sound.
- **Life loss.** `accent('destroyed')` (from `playerDestroyed`, or the observer's `lifeLost`) drops the music to 15 % for two bars under the hit; `accent('gloat')` plays during `regroupStart`; `accent('respawn')` brings the music back on its downbeat. Any new cue restores it. The life-loss accents ignore the two-at-once accent cap.
- **Mixing.** Music gain stages: cue gain 0.7 → `drop` (life loss) → `sidechain` (−2 dB for ~150 ms under explosions, hits and life-loss effects) → `bright` (high shelf, power-up pickup falling) → `music` (the comms layer ducks this one through `demonAudio.graph`) → `musicLevel` (the player's Music toggle) → master (0.65) → safety limiter → output. Dive layers connect to `music` after the drop; the power layer connects to `drop`. Effects play at 1.0 into the master.
- **Lazy loading.** Only a level's own set is fetched when the level is cued: tier 1 and the accents first, then the other tiers and the outro, and the next level's intro while clearing or travelling. Up to 12 decoded cues are kept, and the current level's set and the level clear are never evicted. Effects play at 0.9 against music at 0.7 (round 1: 0.7 and 0.7), so shots and explosions stay above the denser mixes.
- `demonAudio.state` adds `scene` (level, section, tier), `offset` and the accent log to the read-only diagnostics.

Effects stay on the synthesizer with unchanged trigger timing. Voice limiting steals the oldest voice when an effect exceeds its own cap (shot 4, hit 4, explosion 5) or 14 effect voices are live; explosion and life loss add a short filtered noise layer.

### Volume toggles (audio round)

Two toggles sit in the top bar of the play HUD (left of pause, where the old sound and voice switches were) and in the menu's top bar: **Music** and **Speech**. Each tap cycles **Mute → Low → Full → Mute**; both start at **Full**. Each shows its icon (struck through and red when muted), a two-segment meter (0 / 1 / 2 lit) and the word OFF / LOW / FULL, 38 × 44 logical px (`lib/widgets/level_toggle.dart`, keys `hud-`/`menu-music-level`, `-speech-level`). `test/audio_toggles_test.dart` renders the HUD at 360 × 780 and 1280 × 800 and checks the toggles do not overlap score, lives, hearts or pause.

| Level | Music (`musicLevel` gain) | Music overall (× 0.7 cue × 0.65 master) | Speech (voice bus) |
|---|---|---|---|
| Full | +6 dB (×2.0) | 0.91 (round 3: 0.455) — music is 6 dB louder than before | ×1.26 (the round-3 voice level) |
| Low | −4 dB (×0.63) = 10 dB under Full | 0.29 | ×1.26 × −8 dB (0.50) |
| Mute | 0 (accents and the power layer are skipped) | 0 | 0: voices stop, nothing plays, no ducking |

- **Headroom.** The cues peak at ≤ −1 dBFS, so Full music alone peaks about −1.8 dBFS at the output. Tier crossfades, stacked dive layers and the power layer can sum above that, so the master now feeds a `DynamicsCompressor` used as a limiter (threshold −1.5 dBFS, ratio 20, knee 0, attack 2 ms, release 120 ms). Without the node (old browsers) the master goes straight to the output.
- **Effects** keep their level (master 0.65) whatever the toggles say, except that **both** Music and Speech on Mute mute the master, which is the old sound switch folded in. `demonAudio.mute(bool)` still works as a master mute.
- **Ducking.** The music still ducks to 0.4 under any voice at Full or Low speech (Low speech is −8 dB rather than −10 dB so it still sits near the ducked music); Mute speech plays nothing and so never ducks.
- **Persistence.** `demonAudio.setLevel('music' | 'speech', 'mute' | 'low' | 'full')` applies the level, forwards speech to `commsAudio.setLevel`, and writes `localStorage` keys `demonAttack.musicVolume` / `demonAttack.speechVolume`. Reads happen when the script loads, so the first music after the gesture already plays at the remembered level, and comms-audio.js starts at the remembered speech level. Every storage access is wrapped in try/catch: missing, throwing or full storage falls back to Full and the choice lasts for the session (`setLevel` reports `stored: false`). Dart reads the levels through `demonAudio.levels` (`audioLevel`, stub: Full) and calls `audioSetLevel`; speech Mute also turns the squad voices off (`SquadComms.setVoice(false)`; subtitles stay).

### Composable dive layers (audio round)

Each `dive` accent now adds one **layer** from `l<n>-layers`, a sprite of six two-bar slots cut from the level's own tier masters by `tools/music_pipeline.py` (`mode: stems`, see below), so tempo and key are the level's by construction:

| Layer | Role | Quantum | Sounds | Material |
|---|---|---|---|---|
| `stab` | hit | ½ beat | 7.5 beats | the tier-4 beat with the strongest onset (plus chroma match), re-hit in a 3+3+2 figure over two bars |
| `swell` | hit | 1 beat | 5 beats | the best-matching tier-4 downbeat: its harmonic beat reversed, landing on the chord one beat later |
| `fill` | drums | ½ bar | 6 beats | the densest tier-4 drum half-bar (HPSS percussive part) and the bar it lands on |
| `gallop` | drums | ½ bar | 7.5 beats | two bars of tier-2/3 drums with the most kick onsets (backbeat stays on 2 and 4) |
| `lead` | tone | 1 bar | 7 beats | two bars of the tier-3 harmonic lead band (700 Hz–6 kHz), the pair with the best chroma match |
| `low` | tone | 1 beat | 7 beats | the low band (< 250 Hz) of the tier-4 downbeat whose bass chroma matches best |

- **Composition.** A dive while layers ring adds a *different* layer over them instead of restarting: never one that is sounding, never the same as the previous one, and preferably a role (hit / drums / tone) that is not sounding yet, so three quick dives give a hit, a drum and a tone layer. An empty stack starts with a layer that lands within a beat (stab, swell or low). Choice among the candidates is a seeded LCG (deterministic in tests). Each layer starts on the next multiple of its quantum on the level grid (beat 0 is the tier's loop start), at least 30 ms ahead.
- **Build-up and cap.** At most **4** layers sound at once; the n-th layer plays at 0 / −2 / −3.5 / −5 dB under the cue gain, and the limiter holds the sum. Dives may now come every 0.75 s (`MusicDirector.tellSpacing`, was 2 s; the player accepts one per 0.5 s), so a dive run stacks to three or four layers; when the dives stop no new layer starts and the stack decays as its layers fade out within two bars.
- Muted music plays no layers. Without a decoded layer sprite a dive falls back to the single dive slot of `l<n>-accents` (or its synth figure). `state.layers` lists the sounding layers, `state.layerLog` the last 16.

### Power-up layer (audio round)

`MusicDirector` publishes `musicPowerLayer {active, falling, level}` (declared in the `// --- audio round` block of `game_events.dart`) whenever the number of running power-ups (`model.powerTimers`) or the presence of a falling pickup (`model.pickups`) changes, and a reset to `{0, false}` when play stops. `MusicBridge` forwards it to `demonAudio.powerLayer(active, falling)`. On each bar line the scheduler applies it, in the tier section only:

- **Active power-ups**: `l<n>-power` (the level's tier-4 HPSS percussive part above 3 kHz: cymbals, snare crack, blast top end; an 8-bar loop) starts at the tiers' loop position, at −6 dB with one power and −3 dB with two or more; it survives tier changes (same grid, same position) and fades out over a beat from the bar line after the last power ends, or when the level leaves its tiers.
- **Falling pickup**: a high shelf (+3 dB at 3.5 kHz) on the music opens while a pickup is in the air and closes on the bar after it is caught or lost.

### Stems (`mode: stems`, audio round)

`l<n>-layers` and `l<n>-power` in `cues.json` are not generated. `build --cue l1-layers …` calls `build_stems`, which reads the tier masters (`<work>/l<n>-t<k>.wav`, else the shipped Ogg), splits them by median-filter HPSS (circularly padded, so the parts still loop), filters with zero-phase Butterworth bands (transients stay on their beat) and picks the slices by measurement: onset strength at the grid beat (10 ms flux frames), and chroma correlation (8192-point frames; the 2048-point STFT biased every tier towards F#) with the **level's own mean tier chroma** rather than the nominal key. Slots are normalised to −20 LUFS (power loop −21) with peaks ≤ −1 dBFS, and their last 50 ms are silent (the player stops each layer 40 ms before its slot ends, so Opus pre-echo of the next slot's attack is never played); the manifest records each layer's source tier and beat, key match, peak and `hitOffsetMs` (main onset against its grid point). Why not ACE-Step: text mode cannot be asked for a tight 1–2-bar stem in a given key on a given grid (takes drift to their own tempo below ~150 BPM and their own progression), and an a2a re-performance of a slice would smear the transients the layers exist for; slices of the level's own takes are tempo-, key- and timbre-consistent by construction. **Nobody listened to the layers or the power loops**; they were chosen by the numbers only.

Measured (`manifest.json`; `km` = chroma correlation with the level's mean tier chroma, `@` = source beat in the 32-beat loop, ms = main onset against the grid point at 10 ms frame resolution; power = mean onset strength on beats / eighths / sixteenths):

| Level | Spec key / measured tier key (r) | Layers | Power onsets | Opus (layers + power) |
|---|---|---|---|---|
| L1 | E minor / E major (0.727) | stab t4@4 km 0.81 +10 ms · swell t4@24 km 0.83 -3 ms · fill t4@18 +10 ms · gallop t2@0 +10 ms · lead t3@20 km 0.93 +10 ms · low t4@4 km 0.83 +10 ms | 0.538 / 0.154 / 0.006 | 315 KB |
| L2 | D major / A major (0.821) | stab t4@27 km 0.88 +10 ms · swell t4@12 km 0.94 -5 ms · fill t4@18 +10 ms · gallop t2@28 +10 ms · lead t3@20 km 0.98 +10 ms · low t4@20 km 0.87 +10 ms | 0.4 / 0.227 / 0.01 | 332 KB |
| L3 | E minor / E major (0.83) | stab t4@12 km 0.84 +10 ms · swell t4@12 km 0.96 -3 ms · fill t4@26 +10 ms · gallop t3@28 +10 ms · lead t3@28 km 0.95 +10 ms · low t4@12 km 0.94 +10 ms | 0.497 / 0.319 / 0.024 | 291 KB |
| L4 | C minor / C major (0.614) | stab t4@8 km 0.57 +10 ms · swell t4@20 km 0.84 +0 ms · fill t4@6 +10 ms · gallop t3@28 +10 ms · lead t3@12 km 0.84 +10 ms · low t4@4 km 0.92 +10 ms | 0.311 / 0.593 / 0.017 | 362 KB |
| L5 | F minor / F minor (0.766) | stab t4@18 km 0.71 +10 ms · swell t4@0 km 0.94 -6 ms · fill t4@16 +10 ms · gallop t3@28 +10 ms · lead t3@12 km 0.91 +10 ms · low t4@16 km 0.86 +10 ms | 0.408 / 0.274 / 0.008 | 285 KB |

The measured tier keys are the spec's tonic (L2: its dominant A, the takes sit on A/D) with the major profile winning where the riffs are mostly power chords (no third). Every layer's main onset sits within one 10 ms analysis frame of its grid point. Power loops put their onsets on the beat and eighth grid and almost none on sixteenths (L4's eighth-heavy hats outweigh its half-time beats). `verify` passes all ten files (slot tiling, silent slot ends in the played window, whole-bar loops, wraps, the eighth grid); the full Opus set is 6.01 MB (budget 8 MB), and each level's lazy set stays under 1.4 MB.

### Game-side event bridge

Music runs on the shared game-event bridge (`lib/game/game_events.dart`: the model queues `GameEvent`s, `main.dart` drains them into `dispatchGameEvent`, and consumers subscribe with `GameEvents.listen`). `MusicDirector` (`lib/game/music_director.dart`) reads the model once per frame and **publishes** music events on that bridge. They are named in `GameEventNames.music`: `musicIntensity` (data `tier`, `level`), `diveTell`, `lastStandTell`, `carrierHatchOpen` and `reinforcementsArrived`. Other layers, such as the commander comms panel, can listen too. The director also **listens**: `allyUnderAttack` and `groundForceInRange` lift the tier for 6 s like a reinforcement arrival, and ground pressure (`model.ground.pressure`, 0–1, read each frame; also published as `groundPressure {level}`) adds a tier from 0.4 and two from 0.8. `groundBreakthrough` (L3–L4) plays the **breakthrough** accent. `MusicBridge` is the one listener that plays music. It sends `musicIntensity` to `audioIntensity(tier)`, the four tells to `audioAccent(dive|laststand|hatch|reinforce)`, and `fleetIntact` to `audioFleetIntact()` (`lib/services/audio_web.dart` → `demonAudio.intensity` / `accent` / `fleetIntact`; no-ops off the web). The director is read-only: it never writes to the model, and a test checks the checkpoint is unchanged. Hook lines, each marked `// --- music event hook`: three in `scene.dart` (the import, the `music` field, and `music.observe(model, dt)` right after `model.update(dt)`, before `onTick` takes the string events, so it sees `reinforcements`), and four in `main.dart` (the import, the listener list, registering both listeners after the scene is built, and removing them in `dispose`). The cue events (`level`, `boss`, `levelclear`, `travel`, `victory`, `defeat`, `gameover`, `completed`) still go through `main.dart`'s `audioCue` unchanged. `fleetIntact` (data `scope`: `level` at sector clear, `campaign` at victory) is drained in the same tick right after the clear cue. The player then starts the fleet variant in place of the still-loading normal march, or switches in place on the next bar if the normal march is already playing.

### MIDI fallback

`generate-midi.py` writes Standard MIDI Format 0 files, each with its cue's tempo meta, for every cue from the same motif events (`tools/music_motifs.py`), keeping riff, bass, lead, kick and snare, and drops cymbals and pads. A tier that fails to load therefore still plays its motif on the same grid. The peril tier has at least 1.3× the note events of tier 1 (tested). The cackle falls back to falling staccato "ha" notes, and the menu keeps its sine-pad motif. The fallback synthesizer voices channel 9 as percussion, 1 as sawtooth, 2 as sine and the rest as square waves.

Integration: load `audio/demon-audio.js` before Flutter bootstrap, then call `window.demonAudio.cue(mode, level, phase, cycle)` for `menu`, `level`, `boss`, `levelclear`, `travel`, `victory` or `gameover`, and `intensity(1..4)` and `accent('dive'|'laststand'|'hatch'|'reinforce')` during play. Other methods: `unlock()`, `mute(boolean)`, `pause()`, `resume()`, `sfx(name)`. Native platforms need a separate audio adapter; this implementation targets the deployed web app.

## Squad comms voices

The squad video call's radio lines are short clips in `web/audio/comms/<clip id>.ogg` (Opus) and `.m4a` (AAC-LC), one per line of the bank in `art/comms/lines.json` (clip ids `<trigger>.h<n>` for spoken lines, `<trigger>.d<n>` for demon grunts, in list order). `web/audio/comms/manifest.json` records every clip's speaker, kind, trigger, engine (`chatterbox`, `kokoro` or `grunt`), emotion, any fallback reason, duration, mouth, openness and viseme tracks, loudness, byte sizes and SHA-256, plus the Kokoro and Chatterbox revisions, the SHA-256 of every model and voice file, the emotion table and the reference clips.

### Pipeline (`tools/comms_pipeline.py`)

Specs, all committed: `art/comms/cast.json` (characters, Kokoro voice and speed per human, grunt parameters per demon), `art/comms/lines.json` (triggers and lines, each human line with an `emotion`) and `art/comms/audio.json` (Kokoro and Chatterbox repos + revisions, the reference sentence, the emotion table and accept rules, pronunciation overrides, gibberish syllables, grunt length classes, radio chain and keying, loudness, codecs). Two venvs: the **Kokoro venv** (Python 3.12, torch CPU, kokoro) runs every stage except `expressive`; the **Chatterbox venv** (Python 3.11, torch 2.6 CPU, chatterbox-tts 0.1.7, setuptools < 81 for its watermarker) runs `expressive`. Run every heavy stage through `forge-guard run --` (it queues heavy jobs forge-wide, waits for memory headroom, caps threads and kills a job under memory pressure instead of letting the cgroup stall).

| Stage | Does |
| --- | --- |
| `voices` | Kokoro-82M (CPU) speaks each human line with its character's voice and speed → 24 kHz WAV in `$COMMS_WORK/raw` (default `~/.cache/demon-attack/comms`, outside the checkout). These are the fallback renders and the length yardstick for `expressive`. Cached per clip on (voice, speed, text, revision, overrides). misaki's espeak-ng fallback is disabled (the bundled `espeakng-loader` library aborts on this host); every out-of-vocabulary word is spelt with an explicit phoneme override in `audio.json`. |
| `refs` | One Kokoro reference clip per human character (their voice and speed, the neutral ~9 s sentence in `audio.json`) → `$COMMS_WORK/refs/<id>.wav`, hashes in `refs.json` and the manifest. |
| `hotrefs` | Optional (Chatterbox venv): a derived energetic reference per character, `refs/<id>.<register>.wav` (`chatterbox.registers`). Measured in v4 and not used by any emotion (below). |
| `expressive` | Chatterbox (Resemble AI) clones each character's reference and speaks every line with its emotion's exaggeration / cfg weight / temperature and delivery text, seeded per clip id → `$COMMS_WORK/expressive`. **One model process, never a pool** (`--threads`, ~3–5 GB resident; between lines it pauses while the cgroup's anon+shmem is within 1.5 GB of `memory.high`). Hottest emotions first, one reference after another. A take that fails the accept rules is re-rolled with a new seed up to `accept.retries` (2) times, and the best take is kept. Each clip is written with its cache key as it finishes (cached per engine, revision, reference hash, delivery text and emotion parameters), so a killed run resumes where it stopped; `--limit` renders a batch and `--only` a subset; the log is `expressive.json`. |
| `grunts` | Synthesised demon growls, seeded by clip id (below), with a click and splice check over the whole set; the stage fails on any hit. |
| `radio` | Picks the engine per human clip: the Chatterbox render if it passes the accept rules (present, not silent, < 0.1 % clipped samples, trimmed length 0.55–1.9 × the Kokoro render of the same text, which catches truncation, babble loops and long noise tails, and for urgent/excited/triumphant/panicked lines a pitch-range floor), else the Kokoro render (`--kokoro-only` forces it). Then the emotion's **delivery** post-processing (below), the radio chain, mouth, openness and viseme tracks, and BS.1770 gated loudness normalisation (−18 LUFS human, −18.5 demon, soft limit at −4 dBFS). |
| `prosody` | Pitch range (5–95 %, semitones), pitch sd, energy sd (dB over active 10 ms frames), voiced share and syllables per second, per clip and per emotion, of a folder of clean takes (`--dir`; `--post` measures after delivery; `--out` writes JSON). A numpy YIN tracker, close to librosa's pyin on spot checks. |
| `encode` | ffmpeg: Opus 16 kbps VBR `voip` mono and AAC-LC 24 kbps mono with a 4 kHz cutoff (without it the native AAC encoder spends bits on the empty highs and rings up to 6 dB over the ceiling), 24 kHz, bit-exact; writes the manifest and removes stray files. Re-encoding the same masters reproduces the same bytes. |
| `verify` | Decodes every file: length vs manifest (±60 ms), decoded peak ≤ 0 dBFS, loudness within 1.5 LU, grunt length per class, mouth/openness track lengths, no single-frame mouth flicker, engine recorded, hashes, bank ↔ manifest. |
| `stats` | Median pitch, spectral centroid and speaking rate per character (distinctness check). |
| `dart` | Generates `lib/comms/comms_bank.dart` with the measured durations and tracks. |
| `all` | `voices refs grunts radio encode verify dart` (run `expressive` in its venv between `refs` and `radio`). |

Setup (keep everything off the checkout):

```bash
SCR=<scratch>/comms
G=~/.cache/tillandsias-project/bin/forge-guard
export UV_PYTHON_INSTALL_DIR=$SCR/py UV_CACHE_DIR=$SCR/cache HF_HOME=$SCR/hf HF_HUB_DISABLE_XET=1 COMMS_WORK=$SCR/work
uv python install 3.12 3.11
uv venv --python 3.12 $SCR/venv
uv pip install --python $SCR/venv/bin/python --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple torch
uv pip install --python $SCR/venv/bin/python kokoro soundfile numpy scipy espeakng-loader
uv pip install --python $SCR/venv/bin/python <en_core_web_sm-3.8.0 wheel from the spaCy models release>
uv venv --python 3.11 $SCR/cb-venv
uv pip install --python $SCR/cb-venv/bin/python --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple torch==2.6.0 torchaudio==2.6.0 chatterbox-tts soundfile scipy 'setuptools<81'
$G run -- $SCR/venv/bin/python -I tools/comms_pipeline.py voices
$G run -- $SCR/venv/bin/python -I tools/comms_pipeline.py refs
$G run --threads 6 -- $SCR/cb-venv/bin/python -I tools/comms_pipeline.py expressive
$G run -- $SCR/venv/bin/python -I tools/comms_pipeline.py grunts
$G run -- $SCR/venv/bin/python -I tools/comms_pipeline.py radio
$G run -- $SCR/venv/bin/python -I tools/comms_pipeline.py encode
$SCR/venv/bin/python -I tools/comms_pipeline.py verify && python3 tools/comms_pipeline.py dart
```

(The Hugging Face Xet transfer backend is unreachable from the forge; `HF_HUB_DISABLE_XET=1` downloads the models over plain HTTPS.)

### Expressive delivery (Chatterbox + delivery stage, v4)

Kokoro holds each character's identity: Chatterbox clones the character's own Kokoro reference clip, so a line keeps that character's voice while gaining the emotion's delivery. The operator heard v3 (exaggeration ≤ 0.95) as "still too flat", so v4 measured before choosing (`prosody` stage; test sets of 11 and 20 lines from eight speakers):

| Test (hot emotions) | Pitch range st | Pitch sd st | Energy sd dB | Syll/s | Length > 1.9× |
| --- | ---: | ---: | ---: | ---: | ---: |
| v3 takes (20 lines) | 11.59 | 3.56 | 10.12 | 3.33 | 0 |
| exaggeration 1.0–1.3, cfg 0.5, neutral ref | 11.87 | 3.65 | 9.42 | 3.49 | 0 |
| same, derived energetic reference | 10.85 | 3.40 | 9.61 | 3.44 | 0 |
| exaggeration 1.2–1.6, cfg 0.2–0.3 (11 lines) | 15.18 vs v3 14.23 | 4.33 vs 4.53 | 9.77 vs 10.07 | 3.29 vs 3.96 | 3 of 11 (up to 3.5×) |

Findings:

- **Exaggeration and cfg barely move the measured prosody.** Low cfg (0.2–0.3) slows the delivery, which matches Chatterbox's own guidance that low cfg slows pacing and high exaggeration speeds it up. It also lets lengths run away (babble tails up to 3.5× Kokoro), which the accept rules reject.
- **The energetic reference didn't help.** Each character's reference was re-voiced by Chatterbox at exaggeration 1.5 on an energetic sentence; the widest-pitched of three takes was kept, at speaker similarity 0.78–0.85. It did not widen the lines' pitch.
- **What v4 uses:**
  - exaggeration up to 1.3 at cfg 0.5;
  - a closing "!" for the hot emotions (Chatterbox's own text normaliser turns "..." into ", ", so ellipses buy nothing);
  - a deterministic **delivery** stage that measurably widens the contour.

CAPS for stress is supported (a line's `stress` word list, or a hand-written `say`), but no line uses it, because it is unverified (nobody listens on the forge).

| Emotion | Exaggeration | cfg | Temp | End | Expand | Shift st | Tempo | Dynamics | Lines |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| calm | 0.45 | 0.50 | 0.70 |  | 1.10 | +0.0 | 1.00 | 1.05 | 70 |
| stern | 0.55 | 0.50 | 0.70 |  | 1.10 | +0.0 | 1.00 | 1.10 | 12 |
| warm | 0.60 | 0.50 | 0.75 |  | 1.20 | +0.2 | 1.00 | 1.10 | 47 |
| exhausted | 0.50 | 0.55 | 0.75 |  | 1.05 | -0.3 | 0.97 | 1.00 | 13 |
| teasing | 0.85 | 0.50 | 0.80 |  | 1.30 | +0.3 | 1.03 | 1.15 | 35 |
| urgent | 1.00 | 0.50 | 0.80 | ! | 1.35 | +0.5 | 1.06 | 1.20 | 90 |
| excited | 1.15 | 0.50 | 0.80 | ! | 1.40 | +0.8 | 1.06 | 1.20 | 59 |
| triumphant | 1.20 | 0.50 | 0.80 | ! | 1.40 | +0.6 | 1.03 | 1.20 | 27 |
| panicked | 1.30 | 0.50 | 0.80 | ! | 1.35 | +1.0 | 1.08 | 1.20 | 32 |

**Delivery** (`deliver`, applied in `radio` to the clean take):

- **Intonation expand.** It widens the intonation around the clip's median pitch: the voice is resampled at a rate that follows its own smoothed f0 contour (pitch and formants move together, at most ±3 st).
- **Shift and tempo.** It shifts the pitch by a few tenths of a semitone, then WSOLA restores the length and applies the tempo.
- **Dynamics.** It widens the 30 ms level contour, by at most ±6 dB.

**Accept rules (v4).** Length ratio 0.55–1.9 and < 0.1 % clipped, as before, plus a pitch-range floor on the raw take: urgent 6.5 st, excited, triumphant and panicked 7 st (about v3's 10th–20th percentile). Failing takes are re-rolled up to twice before the Kokoro fallback.

Before and after, the whole bank (medians; v3 = the shipped v3 takes, v4 = what ships, measured on the clean voice before the radio chain):

| Emotion | n | v3 range st | v4 range st | v3 sd | v4 sd | v3 energy sd | v4 energy sd | v3 syll/s | v4 syll/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| calm | 70 | 8.4 | **10.0** | 2.63 | 3.17 | 9.34 | 9.34 | 3.88 | 3.96 |
| stern | 12 | 7.9 | **10.1** | 2.55 | 3.15 | 9.20 | 9.50 | 3.88 | 4.38 |
| warm | 47 | 9.9 | **11.4** | 3.10 | 3.59 | 9.48 | 9.51 | 3.90 | 4.12 |
| exhausted | 13 | 8.1 | **8.8** | 2.55 | 2.84 | 9.71 | 9.64 | 4.27 | 4.48 |
| teasing | 35 | 9.4 | **14.0** | 3.25 | 4.59 | 9.43 | 9.72 | 4.50 | 4.70 |
| urgent | 90 | 10.0 | **15.0** | 3.23 | 4.75 | 9.29 | 9.12 | 4.14 | 4.77 |
| excited | 59 | 11.0 | **16.5** | 3.50 | 5.11 | 9.07 | 9.53 | 4.26 | 4.17 |
| triumphant | 27 | 11.7 | **17.1** | 3.62 | 5.25 | 9.16 | 9.38 | 3.96 | 4.24 |
| panicked | 32 | 11.9 | **14.1** | 3.68 | 4.57 | 9.32 | 9.17 | 4.28 | 4.59 |
| all | 385 | 9.8 | **12.9** | 3.18 | 4.09 | 9.29 | 9.37 | 4.08 | 4.37 |
| hot, same 183 lines | 183 | 10.9 | **15.3** (raw take 12.5) | 3.51 | 4.89 | 9.18 | 9.28 | 4.11 | 4.45 |

Energy variance stays about the same: at 10 ms it is dominated by consonant/vowel swings, which the smooth dynamics gain leaves alone. The widening is in pitch range, pitch movement and pace.

Chatterbox embeds Resemble AI's imperceptible Perth watermark in its output (left on); the radio chain and lossy coding probably weaken it. The v4 render on this shared CPU: one process with 8 threads, 385 lines at a median of 10.4 s per line (7–41 s, re-rolls included), about 75 min in seven resumable batches; 15 takes were re-rolled, and 1 line fell back to Kokoro (`weaponPickup.h0`: pitch range 4.9 st < 7.0). The manifest records each clip's `engine` and any `fallback` reason.

Never run several Chatterbox workers: each holds about 3 GB, and four of them pushed the forge cgroup past `memory.high` into a 1.5 h reclaim stall (see `tools/forge-guard/README.md`).

### Radio chain

Silence trimmed (−42 dB, 15 ms pad) with 10 ms edge fades; 4th-order Butterworth band-pass (human 300–3400 Hz; demon "enemy intercept" 200–3000 Hz), a presence peak (human +3 dB at 1.8 kHz, demon +4 dB at 1.1 kHz), tanh saturation (drive 1.9 / 2.4) and the band-pass again so the harmonics stay in band; a faint band-limited hiss under the transmission (−52 / −48 dB, demons add a 55 Hz + 165 Hz hum at −42 dB).

Keying (v3, much softer than the first pass, which was ear-cutting): levels are relative to the voice peak before loudness normalisation. Key-up: a rounded 30 ms sine "tock" (820 Hz human, 574 Hz demon, 2 ms raised-cosine onset, level 0.07, no noise), a 50 ms breath of carrier noise low-passed at 1.5 kHz (level 0.06), and for fleet radios a quiet 45 ms 1.05 kHz key-up tone (0.035), all within the 70 ms before the voice. Key-down: an 80 ms low-passed noise tail (0.06) and a quieter closing tock. The old pass used a 1.45 kHz click with a noise burst at 0.55, a 3.2 kHz burst and a 160 ms 3.4 kHz squelch tail at 0.32.

### Demon growls (v4)

Unintelligible, cartoonish creature vocalisations, never words. The operator heard v3's brood radio as "a glitchy audio clip rather than a proper growling". The causes:

- **Granular splices:** granulated Kokoro gibberish (70 ms jittered grains).
- **Hard gaps:** syllables cut to digital zero between them.
- **A gated, ringing layer:** per-syllable formant segments overlapped with near-rectangular windows, a ring modulator, and breath noise switched on and off every glottal cycle.

v4 drops the TTS layer: the TTS route (pitch-shifted human nonsense through a monster chain) would bring back the granular smearing. Instead, each growl is **one continuous source-filter synthesis on a single timeline**:

- **Plan.** A syllable plan per gesture (`GRUNT_KINDS`):
  - `order` barks;
  - `rally` whoops;
  - `gloat` chuckles;
  - `alarm` yelps;
  - `roar` bellows;
  - `snarl` snaps;
  - `cackle` (new) laughs in five or six quick rising-falling "heh" pulses;
  - `warcry` (new) swells up into a held roar.
  Syllables come from the brood language spec (`audio.json` → `gibberish` onsets, vowels and codas, biased per gesture: cackles laugh on *h*, war cries roll *gr/kr/br*).
- **Source.** A vocal-fold-like Rosenberg glottal flow on a continuous phase. Both its opening and closing phases are raised-cosine, so the flow derivative has no corner and even a 48 Hz growl never ticks. The pitch contour is eased with raised cosines: a small scoop into each syllable, a glide, a fall-off, vibrato at the speaker's `wobble` and low-passed jitter and shimmer.
- **Growl texture.**
  - Subharmonics: a smooth amplitude alternation at f0/2 (period doubling) scaled by `rasp`.
  - False-fold roughness: 25–90 Hz random amplitude modulation, plus a second, rougher fold pulsing at half the pitch, scaled by `growl`.
  - Throat rasp: breath noise shaped by the glottal flow itself (pulse-synchronous, never gated).
  - A ~28 Hz trill flutter on rolled *r*.
- **Consonants.** Plosives are a 75 % closure with a soft 16 ms burst, nasals a dimmed murmur, fricatives a narrow hiss. A low throat murmur runs under the whole phrase, so between syllables the growl never drops to silence.
- **Vocal tract.** A Klatt cascade of four resonators whose coefficients follow smooth formant tracks sample by sample (no block splices). Formants are scaled by the speaker's `formant` (small creatures up, big ones down) and capped at 3.8 kHz.
- **Finish.** A chest resonance at about 2.2 × the base pitch, a soft tanh saturation by `growl`, a 45 Hz high-pass, a 4.5 kHz low-pass (the demon radio passes 200–3000 Hz anyway) and 15 ms raised-cosine edges.

**Click and splice check** (`discontinuities`, run on every growl by `grunts`; the stage fails on any hit):

- A **spike** is a sample whose second difference exceeds 10× the median level of its 30 ms neighbourhood and 5 % of the peak, and is isolated: 3× above everything 3–60 ms before and after it. A recurring glottal or false-fold pulse never is.
- A **step** is a jump of more than 24 dB between neighbouring 2.5 ms blocks, from near-silence (≤ −48 dB of the peak) to a loud block (> −30 dB) or back: a hard cut or a splice gap.

On v3's grunts the check flags 110 of 137 clips (205 hard-gap steps, 1 spike). The v4 set: 0 of 189 clips (0 spikes, 0 steps). It is tuned for the band-limited growls and is not a general speech click detector: it also trips on 44 of 120 clean Kokoro lines (plosive onsets from silence, sibilant bursts).

**Speakers** (11 on the brood net):

| Speaker | Rank | Base Hz | Formant × | Rasp | Growl | Wobble Hz | Timbre |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Gorrak | Brood Marshal | 70 | 0.62 | 0.35 | 0.55 | 5.5 | deep gravelly bark |
| Vexxa | Wing Colonel | 190 | 1.35 | 0.55 | 0.25 | 9.0 | shrill chittering rasp |
| Skarn | Furnace Major | 105 | 0.85 | 0.7 | 0.45 | 7.0 | snorting bubbly gurgle |
| Morth | Hollow Prelate | 85 | 0.75 | 0.25 | 0.4 | 3.5 | croaking resonant drone |
| Ulgra | Ark Warden | 55 | 0.55 | 0.45 | 0.75 | 4.0 | huge booming bellow |
| Skritch | Scout Imp (minion) | 260 | 1.6 | 0.3 | 0.15 | 12.0 | squeaky chattering giggle |
| Grunnok | Trooper Brute (minion) | 58 | 0.58 | 0.5 | 0.8 | 3.0 | dim slow rumbling huff |
| Blatch | Brood Gunner (minion) | 125 | 0.95 | 0.65 | 0.35 | 8.0 | raspy clicking cackle |
| Nibb | Brood Spriteling (minion) | 330 | 1.8 | 0.15 | 0.1 | 14.0 | tiny giggling squeal |
| Krag | Stone Hulk (minion) | 48 | 0.5 | 0.6 | 0.9 | 2.5 | grinding cavernous growl |
| Sliss | Venom Skulker (minion) | 150 | 1.1 | 0.8 | 0.3 | 10.0 | breathy hissing snarl |

**Length classes** (`audio.json` → `grunt_lengths`):

- **Long:** officer replies in exchanges (the `levelClear`, `bossDefeated` and `broodTaunt` demon lines). The gesture, a breath, then a grumbling coda of two or three lower, slower syllables, capped at 2.0 s raw (final clips ≤ 2.25 s).
- **Short:** the regroup celebration (`regroupStart`) and the battle cries (`divePrep`), time-compressed to ≤ 0.72 s raw (final ≤ 0.9 s), so a cry lands inside the 0.5 s before the dive telegraph.
- **Everything else:** 0.5–1.9 s.

**Brood airtime (v4).**

- **Battle cries.** `divePrep` (fired `ArcadeModel.divePrepBeat` = 0.5 s before a dive telegraph) carries 17 battle cries, 12 of them from the six minions. They have a 7 s cooldown, a 50 % chance and a 0.6 s time-to-live. They may overlap other voices like the regroup cheer: they never cut a line, and the player's three-voice cap drops them if it is full.
- **Reinforcements.** The cheer chains a second, different brood voice (19 variants, mostly minion cackles).
- **Other triggers.** The new minions also chatter (`broodChatter`), cheer the regroup and the waves, and panic in a rout.
- **Variety.** The director's picker never repeats the last variant and prefers speakers who haven't spoken lately. `test/comms_director_test.dart` checks over 10 simulated minutes that the cries cover at least 8 variants and at least 5 voices, with no immediate repeat and no line cut.

### Mouth, openness and viseme tracks

Three tracks per clip, one value per 1/15 s across the whole clip including the keying lead and tail:

- `open`: mouth openness 0..1 written as one digit 0–9 per frame (openness = digit / 9). From the clean voice's RMS per 1/15 s, mapped linearly from 24 dB below the clip's 90th-percentile frame level (closed) up to that level (fully open), so an evenly loud expressive delivery still moves between small and wide mouths; then smoothed with a fast attack (0.7 per frame) and a slower release (0.4 per frame), so the mouth opens on the sound and closes slightly behind it.
- `vis` (v4): a viseme estimate from the clean voice's spectrum, relative to the clip's own open frames.
  - `o` (rounded o/u/w): the most low-heavy fifth (energy at 250–1000 Hz) with little energy at 1.8–3.4 kHz.
  - `e` (spread ee/i, or teeth on s/sh/f/t): the most front-heavy fifth (1.8–3.4 kHz), or a fricative burst (4–11 kHz share in its top 15 %).
  - `-`: plain.
  Runs are held at least two frames.
- `mouth`: portrait frames as the character code 48 + `CommsFrame` index, for tools and `verify`. It quantises openness into five levels (closed, slightly open, half, open, wide; thresholds 0.12, 0.3, 0.52, 0.76), with `o`/`e` turning levels 1–3 into 'oo'/'ee', and the demons' loudest moments (≥ 0.93) into the roar frame. Across the bank: human frames wide 36 %, ee 16 %, closed 15 %, open 10 %, slight 8 %, half 7 %, oo 7 %; growl frames roar 33 %, slight 20 %, wide 17 %, half 16 %, open 13 %, closed 0 %. Every run is held at least two frames; `verify` checks it.

The game (`lib/comms/comms_mouth.dart`) builds its own 30 Hz track from `open` and `vis`:

- it eases the 15 Hz openness linearly, then applies attack/release smoothing;
- it quantises with hysteresis and moves **at most one level per 1/30 s**, so the mouth always passes through the in-between shapes instead of snapping from closed to wide;
- no level blips for a single sample except as a step of a monotone ramp;
- every clip ends closing step by step;
- 'oo'/'ee' replace levels 1–3 for runs where most samples agree;
- the painter cross-fades the first 30 ms of every new shape (a hard cut with reduced motion).

The shapes themselves are drawn on each portrait's measured lips: see [asset-pipeline.md](asset-pipeline.md#squad-comms-portraits).

### Playback (`web/audio/comms-audio.js`)

`window.commsAudio = {prefetch(ids), play(id, priority, demon), stop(id), stopAll(), setVolume(v), setLevel(level), state}`. Audio round: `setLevel('mute' | 'low' | 'full')` (forwarded from `demonAudio.setLevel('speech', …)`, initialised from `demonAudio.levels.speech`) scales the voice bus by 0 / −8 dB / 1 on top of `setVolume`; Mute stops live voices and makes `play` return false, so the music is never ducked. It shares demon-audio.js's AudioContext and master gain through `demonAudio.graph` (one added getter is the only change to demon-audio.js), so master mute and pause (context suspend) silence voices too. Voices run through their own bus gain (+2 dB playback gain × the voice volume; `setVolume(0)` mutes comms and stops live voices) into the master. `play` is a no-op returning false before the first gesture has created the context, at volume 0, or for a clip already playing. At most **3** voices sound at once (the regroup celebration may overlap for about a second). A playing voice is never cut, except by an **urgent** line (priority ≥ 8): that releases the lowest-priority (then oldest) live voice over 40 ms, provided it doesn't outrank the new line. Any other play beyond the cap is dropped (`state.dropped`), so the Dart director queues instead. While any voice is live the music bus ramps to 0.4 (`setTargetAtTime`, 60 ms) and returns to 1 (120 ms) 300 ms after the last voice ends; the effects bus is never ducked. Bytes may be fetched before the gesture; decoding waits for the context. Format order follows `canPlayType('audio/ogg; codecs="opus"')`; a clip whose formats all fail frees its slot. `state` reports `{context, voices, ducked, duckGain, musicGain, volume, loaded, played, dropped, maxConcurrent, cap, formats}`.

### Sizes

| Set | Clips | Audio | Opus | AAC |
| --- | ---: | ---: | ---: | ---: |
| Human lines (384 Chatterbox, 1 Kokoro) | 385 | 1069 s | 2.35 MB | 3.75 MB |
| Demon growls (11 speakers) | 189 | 193 s | 0.44 MB | 0.81 MB |
| **Total** | **574** | **1262 s** | **2.78 MB** | **4.56 MB** |

v3 shipped 478 clips in 2.52 + 4.07 MB; v4 adds 39 spoken lines (the ground war v4 events) and 57 growls, 1.11× the v3 bytes.

The expressive takes run longer than Kokoro's (a mean of 2.9 s per human line), so v3 lowered the bitrates to Opus 16 kbps and AAC 24 kbps; both remain clean for the 3.4 kHz radio band. Clips load lazily (`prefetch` the lines a sector can use), and a typical line is 2–3 s and 5–8 KB of Opus. Growl lengths: long replies 1.45–2.00 s, regroup cheers and battle cries 0.64–0.79 s, all others 0.5–1.9 s. `test-worker/comms-audio.test.mjs` covers:

- the no-op before the gesture and the shared master;
- ducking and its release;
- the three-voice cap: non-urgent lines dropped and never cutting, urgent lines cutting the lowest-priority voice but never a higher one;
- voice volume, and a missing clip freeing its slot;
- every manifest clip shipping both formats within budget.

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

`npm run test:worker` runs the worker tests and three music tests on an instrumented audio clock. `test-worker/audio.test.mjs` covers the MIDI fallback: every tier, the carrier intro and tiers, victory cadence, outro, level clear, wave stinger, the synthesized accent fallback, cackle → alien theme, mute and pause/resume. `test-worker/music.test.mjs` covers recorded playback: silent before the gesture, lazy per-level loading, intro → tier on its 16-beat boundary, tier changes on bar lines at the same loop position (short cut rising, one-beat fade falling), accent quantization to the half-beat/beat and the sprite slot, stale requests, phase-preserving pause/resume, immediate level clear / finale / cackle, the alien theme 8 beats after the cackle, the fleet-intact variants (chosen before the cue, or switched in place on a bar), MIDI fallback for a missing tier, and that every cue in `cues.json` ships with whole-bar loops inside the 8 MB Opus budget. `test/music_director_test.dart` checks the event → tier/accent mapping and that the director leaves the model unchanged. `tools/music_pipeline.py verify` checks the encoded files and `report` the listening proxies. `test-worker/audio-levels.test.mjs` (audio round) covers the toggle gains, the limiter, both-muted master mute, persistence, the storage fallback (absent, throwing getter, throwing setItem) and speech levels with ducking; `music.test.mjs` adds the dive-layer composition (distinct layers, roles, quanta, no repeat, cap, decay, fallback) and the power layer (bar-line start at the loop position, levels, brightening, survives tier changes, removal). `node --check web/audio/demon-audio.js` validates syntax. Subjective listening remains part of browser playtesting.

A real local Wrangler runtime smoke test also passed: GET, valid POST, invalid initials rejected, SQLite-backed persistence, and MIDI asset served. `wrangler deploy --dry-run --no-bundle` passed with the full Flutter build and both bindings. No remote deployment was performed.
