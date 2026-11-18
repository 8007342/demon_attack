# Design: adaptive-soundtrack

Research and sources: `plan/soundtrack-research.md` (§ numbers below as R§). This file records decisions. Repo facts
name their file. The pilot's ledger: `plan/render-runs/soundtrack-pilot.md`.

**Revision of 2026-11-17: MIDI first.** The operator asked that MIDI become the soundtrack's first layer rather than
its fallback, with no duplicated assets. §11 records that decision, and its research is
`plan/midi-first-research.md` (M§ below). Where §2–§7 describe recorded full-mix sections, §11 narrows those
sections to **texture beds**: optional layers holding only parts the score does not play. The song map (§3), the boss
section graph and transition table (§4), the `SongDirector` (§5.1), the pilot (§8) and the gates (§6) stand. The
score now plays those graphs, not the rendered files.

## 1. Goals and limits

- **One run, one long song.** From the menu to the credits the music never stops and never restarts: every change
  lands on a bar line of the music already playing, or passes through a written bridge.
- **The boss fights are the choruses.** Each route builds through four sector songs to its carrier song, the
  loudest, densest and most developed music of the route; the fifth carrier is the climax of the run.
- **The game never waits for the music.** Events request sections; the music moves at its own next bar. A fast
  sequence of events may merge (the latest request wins).
- **Honest layers only.** No shipped stem comes from separating a mix with a separation model
  (`plan/audio-studio/music-requirements.md` §5). Layers are either cut from our own mixes by plain DSP (as the
  dive and power layers are today), generated on the grid, or (after #1103) rendered from samples.
- **The score is the first layer (§11).** Drums, bass, guitars, leads and stingers play from committed multitrack
  MIDI through a sampled bank in the browser. Rendered audio adds only texture the score does not play, and no part
  ships twice (CLAUDE.md §5, one format per asset).
- **Not in this change:** the radio, the effects, the credits list, any gameplay or calibration change.

## 2. Architecture: a hybrid (R§1.2)

| Layer | Mechanism | Prior art | Status |
|---|---|---|---|
| **Score (first layer, §11)** | committed multitrack MIDI per section, played by the in-browser sampler on the song's grid; per-track gains carry intensity (track masks), so sections, variants and layers are one arrangement | iMUSE's MIDI hooks and markers (M§3.4) | score generator now; bank sources with #1103 |
| Sections | whole-bar sections on one grid per song (score sections first; texture-bed files where a song has them); a transition table moves between them on the next bar (or beat), into the destination's start or the same position, with a cut, a fade or a bridge | horizontal re-sequencing (R§1 A1, A3–A5) | core nodes now |
| Intensity inside a section | variants of one section that share its bars (`v1` calm, `v2` peril); switching keeps the position | same-position transitions (A1 `SAME_POSITION`) | core nodes now (as separate takes); one arrangement needs #1103 |
| Layers | stingers (accents), the dive layers and the power layer (HPSS cuts of our own mixes), a riser; later the sampled drum and bass bed | vertical layering (A2), stingers (A5) | stingers and cuts now; beds #1103 |

With §11 the "Intensity" row becomes a track mask on the score (same bars, by construction), and "Layers" become
score tracks plus optional texture beds. The model is the engines' common one (R§1.1): sections plus a transition table keyed on game state, quantised to
the grid, with bridges where a jump needs one, layers synced inside a section, and stingers over it.

## 3. The song map of a run

Source of truth: `art/music/soundtrack/song-map.json` (task 2.1). Grids are integer samples per 4/4 bar at 48 kHz
(`tools/music_motifs.py` `BAR_SAMPLES`); keys and characters from `plan/campaign-composition.md`.

### 3.1 The movements

| Part | Song | Key | Grid (BPM, bar samples) | Sections | Ends with |
|---|---|---|---|---|---|
| Overture | `menu` | E minor | 120, 96 000 | `overture` (loop) | bridge `menu→k` on START |
| Movement *r* (route r = 1…5) | `k` Krybor | E minor | 170, 67 765 | `arrival`, `A`, `B`, `C`, `D` (+ `v2` of each), `clear` | bridge `k→r` |
| | `r` Ringfall | D major | 160, 72 000 | same form | bridge `r→e` |
| | `e` Ember Moon | E minor | 180, 64 000 | same form | bridge `e→h` |
| | `h` The Hollow | C minor | 150, 76 800 | same form | bridge `h→c` (V → i into the boss) |
| | `c<r>` Carrier, tour r | F minor | 190, 60 632 | §4 | `victory` (F major), then bridge `c→k` or the coda |
| Coda | `coda` | F major | 190 → 95 (bar 121 264) | `finale`, `worldized` tail, `ukulele` | credits reprise |
| Defeat | `alienwin` | as today | 120 | `cackle` → `alienwin` | — |

- **Sector songs** (four per route): `arrival` (a tail that hands over on its last bar), then four loopable
  sections visited in order by wave progress (`waveStart` and `MusicDirector`'s wave share: A for the first
  quarter, B, C, then D, the developed recap). Each section has a calm `v1` and a peril `v2` with the same bars;
  `musicIntensity` tiers 1–2 select `v1`, 3–4 `v2`, and tiers 2 and 4 add the power layer. `clear` is the march or
  flourish on `levelClear`. A **bonus level** (Stormfront) swaps the sector's A–D for a `storm` section (half-time,
  same key) and returns to the sector's next section after it.
- **Routes** reuse the world songs until #1103's sampled beds can thicken them per route; each route gets its own
  carrier song (§4), because the fights are the choruses.
- **Bridges** keep today's pivot plan (`plan/campaign-composition.md`): a sparse sustained pivot, no percussion
  while the tempo changes, the next grid starting on the bridge's last bar line. New: `h→c` lands V → i (C minor to
  F minor), and `c→k` pivots F → C → B7 → E minor (R§1.3).
- **Coda (§4.4).** The fifth carrier's victory resolves F minor to F major and hands over to the ending's ukulele.

### 3.2 Length and size

A run is 25 songs. A sector song is four 8-bar sections × two variants, an arrival, a clear, and a bridge: about 11
files, 2.2 MB as Opus 160 kbps. A carrier song (§4) is about 1.4 MB (the pilot's seven files: 1.36 MB). With the
world songs shared by routes: 4 × 2.2 + 5 × 1.4 + overture, coda, defeat ≈ 18 MB in all, fetched one song ahead.

**MIDI first (§11):** the same run as scores is about 18 minutes of unique music × 530 B/s ≈ 0.6 MB (0.3 MB
gzipped; measured on the L3 score, M§0.1 F2), plus one shared sample bank of ≈ 1.6 MB Opus (M§3.3): ≈ 2.2 MB in all,
plus whatever texture beds a song carries (budget §11.5).

## 4. The boss fight as a section graph

### 4.1 Sections of carrier song `c<r>` (tour r, F minor, 190 BPM, bar 60 632)

| Section | Kind | Bars | Character (prompt core in `pilot-carrier-t1.json`) |
|---|---|---|---|
| `arrival` | tail | 4 | the fog and the overflight; doom swell into the approach (pilot: `approach` serves) |
| `approach` | loop | 8 | slow crushing half-time doom groove, tolling bells, brass drones — dread |
| `H1` … `HU` | loop | 8 each | the hatch tiers, one per upper tier (U = 2, 2, 3, 3, 4 for tours 1–5): galloping battle metal rising to blast beats, twin leads, choir |
| `transform` | bridge | 3 | riser: timpani roll, choir and organ crescendo, landing on the core's downbeat |
| `core` | loop | 8 | the climax: blast beats, tremolo, cathedral organ, massive choir |
| `collapse` | tail | 8 (+ decay) | monumental doom finale in half-time: the hull falls |
| `victory` | tail | 4 (+ decay) | F major fanfare; `victory-fleet` with `fleetIntact` |

Bars at 190 BPM: 1 bar = 1.263 s, so an 8-bar loop is 10.1 s and the 3-bar bridge 3.79 s, one bar more than the
3.5 s transformation (carrier-hatches §A4), so the core lands at most 1.3 s after the core door opens.

### 4.2 The graph

```
 level start ('boss')
        │
        ▼
   [arrival] ──auto──▶ [approach] ◀── bossApproach steps: approach stinger, intensity up
                           │
         bossHatchTier{tier:1}  (right after bossInRange)
                           ▼
                        [H1] ──bossHatchTier{tier:2}──▶ [H2] ── … ──▶ [HU]
                                                                     │
                                         bossTransform{stage:start}  │ (≥ 1 bar after the last tier change)
                                                                     ▼
                                                              [transform] (3 bars, one-shot)
                                                                     │ auto, at its end
                                                                     ▼
                                                                  [core] ◀── bossModuleLost: core v2 (same position)
                                                                     │
                                                    bossCollapseStart│
                                                                     ▼
                                                               [collapse] ──bossCollapseEnd / victory cue──▶ [victory]
                                                                                                                │
                                                                         route < 5: bridge c→k    route 5: coda │
```

### 4.3 Transition table

| From | Event (data) | To | Leaves the source at | Enters | Fade |
|---|---|---|---|---|---|
| (any sector) | level start of the carrier (`cue('boss')`) | `arrival` | next bar | start | bridge rules (§3.1) |
| `arrival` | its end | `approach` | end | start | none (written) |
| `approach`, `Hk` | `bossHatchTier` (`tier` = k ≤ U) | `Hk` | next bar | start | 20 ms in, 60 ms out (as tier rises today) |
| `Hk` | `bossShieldFailing` | `Hk` `v2` if authored | next bar | same position | crossfade 1 beat |
| `HU` (or any H) | `bossTransform` `{stage: start}` | `transform` | next bar | start | cut |
| `transform` | its end | `core` | end | start | none |
| `transform` | `bossCoreExposed` | (no move: `core` follows the bridge) | — | — | — |
| `core` | `bossModuleLost` | `core` `v2` if authored | next bar | same position | crossfade 1 beat |
| any carrier section | `bossCollapseStart` | `collapse` | next beat | start | 1-beat fade of the source under the downbeat hit |
| `collapse` | `bossCollapseEnd`, or its end | `victory` (`victory-fleet` after `fleetIntact`) | next bar | start | none |
| `victory` | `travel` | bridge `c→k` | end | start | — |
| any | `gameover` | `cackle` → `alienwin` | immediate (90 ms fade) | start | as today |

Rules:

- **Minimum dwell.** A section requested within 2 bars of the last section start is queued, and the latest queued
  request wins (two hatch tiers falling in quick succession play the later tier only).
- **Tier mapping.** `bossHatchTier.tier` k ≤ U selects `Hk`; k = U + 1 (the core chapter) is reached through the
  transformation and needs no move of its own. If a tour's song has fewer hatch sections than U (pilot: H1, H2),
  `depth` picks the nearest: `H[round(1 + depth·(n − 1))]`.
- **Accents** stay on today's sprite and quanta (`plan/audio-backend.md` "Accents"), re-mapped for the fight:
  `bossHatchTelegraph` → riser (half-beat), `bossLaunch` → hit (beat), `bossHatchFieldDown` → glass (sixteenth),
  `bossHatchDrop` → impact (beat), `bossWreckFalls` → impact (at most 2 per second), `bossOverflight` → gloat,
  `bossInRange` → hatch hit, `bossTakeoff` → respawn. Life loss keeps its drop, gloat and respawn.
- **Pause** suspends the context (as today); **mute** silences the music bus only.

### 4.4 The ending's handoff to ukulele

On the fifth carrier: `victory` becomes `finale` (8 bars, F major). Then, per the cinematic's sound rules
(`plan/endgame-cinematic-research.md` R-A9.2: the metal track carries over the cut, "worldized"), the finale's tail
plays through a band-pass (≈ 300 Hz–4 kHz), mono, small-room chain over S1–S2 (0–8.5 s). From S3 (8.5 s) the
**ukulele** plays the campaign theme in F major at **95 BPM**, half the carrier tempo, on the carrier grid's
doubled bar (121 264 samples, 2.526 s). Eight bars last 20.2 s, which spans S3–S7 (8.5–29.0 s, 20.5 s). The credits
continue with the warm reprise. Ukulele source: text-to-music on core nodes can be tried now; a sampled ukulele
depends on #1103's libraries (contents unverified, R§2.3).

## 5. Runtime

### 5.1 Split of responsibilities

- **`SongDirector` (pure Dart, `lib/game/song_director.dart`, no `dart:ui`).** Listens on the shared bridge
  (`GameEvents.listen`, CLAUDE.md §3), holds the song state (song, section, variant, queued request, dwell), and
  asks the audio layer for a move: `audioSong(song, section, at: bar|beat|end|now, enter: start|same, fade: …)`.
  It reads the structured carrier events (carrier-hatches §A8) and the level and intensity events
  `MusicDirector` already publishes. Unit-testable without audio.
- **`MusicBridge`** keeps the accents and the power layer; its carrier-v3 placeholders (`bossApproach` →
  `reinforce`, …) move to the accent mapping above.
- **`web/audio/demon-audio.js`** keeps its scheduler (one audio clock, 25 ms timer, 120 ms lookahead, R§3 W6) and
  gains a section graph player: each section is an `AudioBuffer`; a looping section is re-scheduled one loop ahead
  with `start(when, offset)` so a same-position switch can begin anywhere; a bridge auto-advances. Tempo changes
  only at a song boundary.
- **Generated data.** `song-map.json` is packed by a Lua generator into the manifest (files, sizes, hashes, loop
  points) and into `lib/game/song_map.dart` (sections and transitions as const data), so Dart and JS read one map.
  The Dart file joins the generated-files table (CLAUDE.md §4).

### 5.2 Formats and loudness

- Ogg Opus, 48 kHz stereo, 160 kbps VBR for music (pilot: 200 KB per 8-bar loop). Whole bars exactly: every loop
  decodes to `bars × barSamples` samples (pilot: verified with ffmpeg; browser check is task 4.4).
- Each section is mastered to −19 LUFS integrated with true peak ≤ −1.5 dBTP by a fixed (linear) gain, so sections
  of one song match in level; the engine's gains, Music toggle and safety limiter stay as today
  (`plan/audio-backend.md`).
- Ogg Opus decodes on Safari only from 18.4 (R§3 W3). No fallback format (operator, 2026-11-17: "No fallback format, this project is already asset heavy, no need to duplicate assets. Just keep the latest, unless the older one is signifficantly smaller in size."): older iPhones get the MIDI fallback. With §11 the score plays there through the oscillator voice (the
  bank's Opus samples cannot decode either), so no second format is needed anywhere.

### 5.3 Loading

- On a song's start the player fetches all its files and decodes the current section and its graph neighbours
  first; the next song's `arrival` and bridge are fetched (not decoded) during the current song's last section.
- **Decoded memory cap: 48 MB** (≈ 125 s of stereo PCM, R§3 memory arithmetic). Least recently used, unreachable
  sections are evicted first; the current section and its neighbours never are.
- A section that has not decoded in time is skipped: the current section keeps looping and the move waits for the
  next bar. If nothing of a song decodes, the MIDI fallback plays (the modified "Adaptive MIDI soundtrack").
- With §11 the 48 MB cap covers the sample bank plus any texture beds. The score itself needs no decoding, and a song
  with no beds never waits for audio to decode.

### 5.4 Diagnostics

`demonAudio.state` adds `song`, `section`, `variant`, `queued`, `decodedBytes` and a log of the last 16 moves (event,
requested time, scheduled time), which the listening page and tests read.

## 6. Pipeline

| Stage | What | Tool | Core nodes now | Needs #1103 |
|---|---|---|---|---|
| 1. Author | `song-map.json`: songs, grids, keys, sections (kind, bars, prompt core, variant tags), transitions, events | by hand; Lua + `jq` schema check | — | — |
| 2. Generate | per section: text-to-music takes (seeds), optional long-form structured take to cut from, optional cover re-performance for a `v2` | `studio.queue_workflow` on `campaign-text-headroom.json` with `$node:` overrides (no new workflow file needed); recipes beside the map | yes (XL turbo, XL base) | XL SFT; SFZ stems; masked repaint |
| 3. Check | tempo within 0.6 % (else reject), asked key in the top 3 (top 1 preferred), energy above 16 kHz > −60 dB (else warn), loudness, true peak | `tools/soundtrack_check analyze` | yes | — |
| 4. Cut | resample to the exact grid; window on bar lines (loop: the bar after must match its first; bridge: rising into a hit; tail: the take's own ending); loop seam borrows the take's continuation | `soundtrack_check cut` | yes | slicing nodes would move it into the graph |
| 5. Check the cut | wrap step ≤ 1 × the file's p99.9 step, wrap flux ≤ 1.5 × its bar lines' median, whole bars, no clicks or clipping; host `audio.detect_glitches` when it runs | `soundtrack_check check` | yes | — |
| 6. Pick | metrics first, then by ear: one pick per section with its reason in `plan/render-runs/<song>.md` and on the listening page | agent picks (CLAUDE.md §5), operator overrides | yes | — |
| 7. Package | linear loudnorm to −19 LUFS, Opus 160 kbps, into `art/music/soundtrack/<song>/`; later into `web/audio/music/` with the manifest | `tools/soundtrack_pilot.lua encode` (→ a general `tools/soundtrack.lua`) | yes | — |

Raw takes live in `~/.cache/tillandsias-project/soundtrack-*` and are never committed; the recipe (map, tags,
seeds, workflow, overrides) is, so a section can be re-generated (not byte-identical, CLAUDE.md §5).

## 7. What waits for tillandsias#1103

- **XL SFT** (the "highest quality" variant, R§2.1 S4): re-render the picked sections' recipes with it.
- **The CC0 sample sources** (Karoryfer, VCSL, VSCO 2 CE) from which §11's web bank is extracted, and
  `TillandsiasSFZRender` for full-quality offline auditions of the scores (the A/B against the web bank).
- **SFZ stems** (Karoryfer, VCSL): true vertical layers in one arrangement (`v1`/`v2` as stem mixes), the drum and
  bass bed that intensifies with `musicIntensity`, the route thickening of shared world songs, and possibly the
  sampled ukulele.
- **Transition and slicing nodes** in the pack, and any node exposing ACE's masked tasks (repaint across a seam,
  `lego` to add a part, `extract`): not buildable in-forge; request through the coordinator (needs N2).

## 8. Pilot (cleared 2026-11-17): the tour-1 carrier, core nodes only

Done in this change (ledger `plan/render-runs/soundtrack-pilot.md`):

1. Recipe `art/music/soundtrack/pilot-carrier-t1.json`: seven sections (approach, H1 = `tier1`, H2 = `tier2`,
   transform, core, collapse, victory), common tags, seeds 7101–7104 (turbo), 7201–7202 (base), 7301–7302
   (150 s structured long-form).
2. 32 takes generated one job at a time through `studio.run_workflow`; 28 section takes analysed, gated, cut and
   seam-checked; one pick per section, encoded to `art/music/soundtrack/pilot/c1-*.opus` (1.36 MB).
3. A listening page that plays each section and simulates the fight's events through the transition rules of §4.3
   on a Web Audio clock.

Follow-ups (tasks 6.x): P1 operator listening; P2 an XL base and a long-form-cut alternative per section for A/B;
P3 the browser decode-length check; P4 `v2` variants by cover re-performance; P5 test `SetLatentNoiseMask` on
audio latents as a seam repair; P6 the coda and ukulele sketch.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Separate takes per section sound like different bands | one prompt core per song; picks compared side by side on the page; long-form-cut alternative (P2); SFZ stems after #1103 |
| Turbo takes lack air above 16 kHz | the checker measures it; picks prefer air; XL SFT after #1103 |
| A section is late because it was not decoded | neighbours decode first; a late move waits a bar instead of glitching |
| Memory on phones | 48 MB decoded cap; per-song loading |
| Metrics pass but music is bad | the operator's ear decides (`music-requirements.md` §2); metrics only screen |

## 10. Needs list for the coordinator

| Id | Need | From | Blocks |
|---|---|---|---|
| N1 | A listening session: the operator plays the pilot page (each section, and the scripted fight) and approves or replaces each pick | operator | task 1.6, all production |
| N2 | tillandsias#1103: its timeline; whether its pack exposes ACE's masked tasks (repaint, lego, extract) or only the 16 generic + 6 core audio nodes; the instrument list of its SFZ libraries (is there a ukulele?) | coordinator / host | §7, tasks 5.4, 6.x |
| N3 | The tray app (56.11.15.5) is older than the enclave images (56.11.16.6), so `audio.detect_glitches` and `audio.transform` refuse to run; update the tray app (not `--force-downgrade`) | operator | the host-side seam check (the Go checker covers it meanwhile) |
| N4 | Licence register: upstream ACE-Step 1.5 code and weights are MIT; the studio's pins list the Comfy-Org repack as apache-2.0. Both permissive; the register should name MIT upstream | coordinator | nothing |
| N5 | **Decided 2026-11-17:** no AAC fallback; one format per asset. Safari before 18.4 plays the MIDI fallback | operator | done |
| N6 | Ownership of `web/audio/demon-audio.js`, `lib/game/music_director.dart` and `main.dart`'s music hook while `battle-metal-radio-rework` and `voice-stack` are open | coordinator | tasks 3–4 |
| N7 | GPU budget for production: about 5 carrier songs × 8 sections × 4 takes and 4 world songs × 11 files × 4 takes, roughly 340 takes at 6–25 s each, under an hour of GPU in one-at-a-time jobs | coordinator | task 5 |
| N8 | **Decided 2026-11-17:** no committed lossless masters; the committed Opus plus the recipe (workflow, seed, pick) is the record. A re-render replaces a pick | operator | done |
| N9 | Route B (§11.6): may MIDI motifs transcribed from htdemucs-separated stems be quoted in shipped scores? The acknowledgement is "non-sale", and separated **audio** never ships; transcribed notes are a derived analysis | operator | task 8.8 |
| N10 | Admission and download consent for basic-pitch's ONNX model (Apache-2.0) and ONNX Runtime (MIT) for route B; for Anticipatory Music Transformer `music-large-800k` and Clef-0.2B (Apache-2.0 weights) for route C | coordinator / operator | tasks 8.8, 8.9 |
| N11 | The CC0 libraries for the bank: whether #1103 delivers Karoryfer (drums, Growlybass, Black And Green Guitars), VCSL and VSCO 2 CE on the host, or the operator consents to fetching them; Meatbass looks GPL-3 (M§3.3 B3), so Growlybass replaces it | coordinator / operator | tasks 8.5, 8.6 |
| N12 | A CC0 choir: none found (M§3.3 B4); a texture bed rendered with ACE-Step carries the choir until a CC0 source turns up | coordinator | task 8.7 |
| N13 | The bake-off verdict (task 8.4): the operator hears one carrier section as score + bank and as the recorded pick, and approves MIDI-first for production | operator | production (task 5) |

## 11. MIDI first: the score as the first layer (revision of 2026-11-17)

Research and sources: `plan/midi-first-research.md` (M§). The operator, 2026-11-17: "let's keep MIDI as the fallback,
but try to make it so it becomes our first layer instead", and "No fallback format, this project is already asset
heavy, no need to duplicate assets."

### 11.1 Decision

The adaptive backbone of the soundtrack is a **committed multitrack MIDI score**: drums, bass, rhythm guitars,
leads, pads and stingers. The score is played in the browser by a **sampler** from one curated CC0 bank, on the song
grids, section graph and transition table of §3–§4. Rendered ACE-Step audio becomes an **optional texture layer**
holding only parts the score does not play. Where the bank cannot play, the same score plays through the built-in
oscillator voices.

Why (M§4): MIDI-first wins on size, adaptivity and coherence, and those three are what "one run, one long song"
needs. Its weak spot is the quality ceiling of sampled distorted guitar in a small web bank. The odds are our
judgement (M§4):

| Outcome | Odds |
|---|---|
| MIDI-first is the better backbone | ≈ 75 % |
| Sampled guitars alone reach the operator's bar on the first try | ≈ 50 % |
| Backbone plus texture beds beats rendered-only on the whole brief | ≈ 85 % |

A listening bake-off (task 8.4, N13) gates production.

| | MIDI-first | Rendered sections (§2–§7 before this revision) |
|---|---|---|
| Whole run | ≈ 0.6 MB of scores + ≈ 1.6 MB bank (M§3.3) | ≈ 18 MB (§3.2) |
| Intensity | track masks on one arrangement: true vertical layers, same position by construction | separate takes per variant; vertical layers wait on #1103 |
| Coherence | one bank, one mix chain | the pilot's main open risk (§9) |
| Key, tempo, stingers | data: transpose and grid are parameters; stingers play in the current key | fixed in the audio |
| Quality ceiling | bounded by the bank and the browser amp; no CC0 choir | higher density and "real band" feel, with the turbo model's air problems |

### 11.2 Layers

| Layer | What | Ships as | Always present |
|---|---|---|---|
| 1. Score | per section: multitrack MIDI (SMF type 1, PPQ 480, a conductor track with tempo, key, time signature and section markers; one track per part, named by role) | `web/audio/score/<song>/<section>.mid` | yes |
| 2. Bank | CC0 instrument samples, curated and trimmed (M§3.3): drums, bass DI, guitar DI, organ/brass/string pads, timpani, bells, war drum | one Opus sprite per instrument group + `bank.json` (zones: key and velocity range, root, offset, length, loop points) | loads progressively |
| 3. Texture beds | rendered ACE-Step audio of parts the score does not play: choir and "air" beds, risers, impacts, the worldized ending, the ukulele (no CC0 ukulele, M§3.3) | Opus sections on the score's grid (§5.2 rules) | optional, per song |
| 4. Fallback voice | the oscillator voices of `demon-audio.js` playing layer 1 | code only, no asset | where layer 2 cannot load or decode |

**No duplicates.** Each part of a section lives in exactly one layer.
- A texture bed may not contain drums, bass or rhythm guitar. Its prompt excludes them, and the gate rejects a bed
  whose percussive share or low-band energy says otherwise (§11.9).
- When a section's score is approved, any recorded full-mix of that section stops being a shipping asset and is
  deleted (the recipe stays the record, §1 N8).
- The old fallback cues in `web/audio/midi/` are deleted as each is replaced by a score section; the manifest maps
  the old cue names to score sections until then.

### 11.3 The score, per section

- **Tracks and roles.** These are the L3 score's parts (`tools/score_l3.py`): `drums` (GM map, channel 10), `bass`,
  `gtrL`, `gtrL-pm`, `gtrR`, `gtrR-pm`, `lead`, `lead2`, `lead-clean`, `clean`, `organ`, `brass`, `strings`,
  `timpani`, `bells`, plus `fill` (dive fills) and `sting` (accents).
  - `choir` stays in the score as a guide part. It is muted where a texture bed carries the choir, and played by the
    organ patch where none does.
- **Intensity masks.** The song map lists, per section, the tracks each `musicIntensity` tier plays. The default
  masks (M§3.4):
  - tier 1: kick, snare, hats, bass, rhythm guitars;
  - tier 2: adds the lead, crash and ride;
  - tier 3: adds the double kick (a separate drum track), `lead2` and the pads;
  - tier 4: all tracks.

  A `v2` (peril) variant is a mask or an extra track of the same file, not a second file.
- **Stingers** are short score files in scale degrees, transposed at play time to the current song's key, and
  quantised as today (§4.3 "Accents").
- **Bridges** stay written score files. The tempo changes only at song boundaries, inside a bridge (§3.1).
- **Size.** Measured on the L3 score: 530 B/s raw, 259 B/s gzipped, peak 25 voices (50 with 0.5-beat release
  tails) (M§0.1 F2–F3).

### 11.4 The sampler runtime (`web/audio/demon-audio.js`)

- **One clock.** Score notes use the existing scheduler (25 ms timer, 120 ms lookahead) and parser
  (`parseMidi`, extended to SMF type 1 with track names). The sampler replaces the oscillator in `voice()` with an
  `AudioBufferSourceNode` on the nearest zone's sample. Pitch is set by `playbackRate` within ±3 semitones of the
  zone root, with a velocity-scaled gain and a release envelope.
  - No new dependency. spessasynth_lib (Apache-2.0, M§3.1 P1) is the measured alternative in the bake-off, but it
    adds a second scheduler, has unverified Safari support, and its SF3 bank is Vorbis, a second compressed format
    beside the game's Opus.
- **Per-track graph.** Each note passes through track gain → instrument bus → music bus → the existing master gain
  and safety limiter (`plan/audio-backend.md`).
  - **Guitar bus:** pre-EQ → `WaveShaper` (`oversample = '4x'`, two gain stages) → a cabinet of our own filters
    (high-pass ≈ 80 Hz, low-pass ≈ 5.5 kHz, a presence peak at 2–3 kHz, a notch near 400 Hz) → a left and right
    double from one DI (a few cents apart, different curves).
  - **Bass bus:** light drive, then a low-pass blend.
  - **Drums:** a dry bus plus a short room.
  - **Pads:** a shared convolution or algorithmic reverb.
  - The amp and cabinet are code, not an impulse response; no CC0 cabinet IR was found (M§3.2). NAM in WASM is
    ruled out on phones by its memory (M§3.2 M2).
- **Intensity.** A mask change ramps track gains (20 ms in, 60 ms out) on the next bar line. Muted tracks keep their
  notes scheduled at zero gain for one bar, then stop scheduling, so unmuting is immediate and bar-exact.
- **Section moves (§4.3) on a score.**
  1. At the move's time, no new notes of the source are scheduled past it.
  2. Held notes are released over 30 ms.
  3. The destination is scheduled from its start, or from the same beat offset for `enter: same`.
  4. A bridge auto-advances at its end.
- **Voices.** The cap is 48 on desktop and 32 on phones (by `navigator.deviceMemory` or the screen class). Stealing
  takes pads first, then leads; it never takes kick, snare or bass. `demonAudio.state` adds `voices`, `stolen`,
  `bankLoaded`, `bankDecodedBytes` and the current mask.
- **Loading.** `bank.json` lists groups by priority:
  1. core: kick, snare, bass sustain, guitar sustain and palm mute;
  2. cymbals and hats, then pads, timpani and bells;
  3. extra velocity layers and round-robins (skipped on phones).

  A note whose zone is not decoded yet plays through the oscillator voice, so the music starts at once and
  sharpens as the bank arrives. The 48 MB decoded cap (§5.3) covers the bank (≈ 41 MB full, ≈ 16 MB phone tier,
  M§3.3) plus texture beds.

### 11.5 Size budget

| Item | Budget | Basis |
|---|---|---|
| Scores, whole run | ≤ 1 MB raw | ≈ 18 min × 530 B/s ≈ 0.6 MB (M§0.1 F2) |
| Bank, compressed | ≤ 2 MB | ≈ 1.6 MB plan (M§3.3) |
| Bank, decoded | ≤ 41 MB desktop, ≤ 16 MB phone tier | M§3.3 |
| Texture beds, whole run | ≤ 4 MB | e.g. 5 carrier choir beds × 8 bars × 2 sections ≈ 2 MB at 160 kbps, plus the coda |
| **Total** | **≤ 7 MB** | against ≈ 18 MB for rendered sections (§3.2) |

### 11.6 Pipeline

| Route | Stages | Tools (CLAUDE.md §9: Lua > Rust > Go) | Runs on | Status |
|---|---|---|---|---|
| **A. Score first** (main) | song map → score generator (motifs from `art/music/campaign.json` and `tools/music_motifs.py`) → gates (§11.9) → committed `.mid` + recipe | today `tools/score_l3.py` (Python, standard library; existing); new generators in Lua reading the motifs' JSON export; `tools/midi_stats.lua` (Lua, new) | forge CPU | **now** |
| **B. From a take** (motif mining) | picked ACE-Step take → `audio.separate` (htdemucs_6s) → drums: kick/snare onsets snapped to the 16th grid; bass: basic-pitch or f0; lead: f0; guitar and "other": chord labels and roots → cleanup: snap to the known grid, fold to the key, voice power chords by rule, hats and cymbals by rule → a motif file the score generator quotes | separation on the host; basic-pitch's ONNX model through Rust `ort`; onsets and f0 in Go beside `tools/soundtrack_check` | host GPU (separation), forge CPU | needs N9, N10 |
| **C. Generate** | song map + our motifs → Anticipatory Music Transformer (infill and accompaniment around fixed notes), Clef-0.2B (key, tempo, meter, instrument header) or a validator-gated qwen2.5 draft (JSON per bar, fixed durations, scale degrees) → the same gates + a Lakh-overlap screen for Lakh-trained models → bars absorbed by the generator | AMT and Clef as admitted studio jobs; qwen2.5 on the served ollama (`inference:11434`), one job at a time | host GPU | qwen now; AMT and Clef need N10 |
| **Bank** | CC0 sources → per-zone pick (note, velocity, round-robin) → trim, mono where possible, −1 dB peak → Opus 64 kbps mono / 96 kbps stereo sprites + `bank.json` (zones, sha256, sizes, sources and licences) | Lua + ffmpeg | forge CPU | sources need N11 |
| **Texture beds** | ACE-Step text-to-music with prompts that exclude drums, bass and guitars → §6 gates + the bed gate (§11.9) → picks → Opus | §6 pipeline unchanged | host GPU | core nodes now |

Every shipped score keeps its recipe beside it: the generator, its inputs and seed, and for route B or C the take
or model, the tool versions and each manual edit. Transcriptions and model outputs are inputs to the generator,
never shipped as they are.

### 11.7 How the game drives the score

The `SongDirector` (§5.1) is unchanged. It sends the same moves, and the runtime plays them on scores.

| Event | Score action |
|---|---|
| `waveStart` (wave share) | next sector section A → B → C → D on the next bar (§3.1) |
| `musicIntensity` tier | the section's mask for that tier on the next bar; tiers 3–4 take the `v2` mask |
| power-up active or falling | the power mask (ride, double kick) instead of the HPSS power layer |
| `dive`, `diveIn` | a 1–2 bar `fill` pattern on the next beat (instead of the dive-layer sprite) |
| `bossHatchTier {tier k}` | section `Hk` on the next bar (§4.3, the minimum dwell and latest-wins rules stand) |
| `bossShieldFailing` | `Hk`'s `v2` mask (adds `lead2` and choir) on the next bar, same position |
| `bossTransform {stage: start}` | the 3-bar `transform` bridge on the next bar; the `core` follows its end |
| `bossModuleLost` | `core`'s `v2` mask, same position |
| `bossCollapseStart` / `bossCollapseEnd` | `collapse` on the next beat / `victory` on the next bar |
| `fleetIntact` | `victory-fleet`: the victory section with the brass fanfare track unmuted |
| accents (§4.3 list) | `sting` scores in the current key, on today's quanta |
| `gameover` | `cackle` → `alienwin` as today |

### 11.8 Fallback ladder (one score, no second asset)

1. The bank group a note needs is decoded: the sampler plays it.
2. It is not decoded yet, or the bank cannot decode (Safari before 18.4 cannot decode Opus, R§3 W3): the oscillator
   voice plays that note. This is today's synth, kept for this purpose.
3. A texture bed that is not decoded is simply absent: the score carries the music.
4. Mute and pause as today.

### 11.9 Gates

**Score gates** (`lua tools/midi_stats.lua`, extended with `check`):
- whole bars of the section's grid;
- every onset on the 1/16 or triplet grid within ±12 ms (humanised timing allowed only inside that window);
- out-of-scale notes ≤ 3 % outside marked chromatic passages;
- every pitch inside the bank's zones for its track;
- peak voices ≤ 32 with a 0.5-beat release (the phone cap);
- sizes recorded.

**Bed gate** (`soundtrack_check`, new `bed` mode). On top of the §6 gates:
- the percussive share from HPSS stays below a threshold;
- the energy below 120 Hz relative to the total stays below a threshold;
- either one failing rejects the take as a duplicate of score parts.

**Bake-off** (task 8.4): one carrier section (the pilot's `core`) as score + bank, and as the recorded pick, on the
listening page. Measured: CPU load and voices on a mid-range Android phone and an iPhone, decoded bytes, and gaps at
moves. Judged by the operator.

### 11.10 Risks

| Risk | Mitigation |
|---|---|
| Sampled distorted guitar sounds cheap next to the rendered takes | bake-off before production (N13); the amp chain is tunable per world; sampled power chords as a measured option (+0.6 MB, M§3.3); rendered texture beds for density |
| No CC0 choir | a texture bed carries the choir (N12); organ doubles it in the fallback |
| Phone CPU or voice cap | 32-voice cap with stealing; phone tier of the bank; measured in the bake-off |
| Authoring every song by hand is slow | generators per song form (A–D sections from motifs), routes B and C for motifs and infill; the L3 score shows the scale of one song |
| Lakh-trained models reproduce existing music | short infill only, an overlap screen, preference for Clef and Composer's Assistant data (M§2.1) |
| Separated-stem transcription is not allowed | route B is optional; route A needs nothing from it (N9) |

## 12. The score runtime as built (`work/score-runtime`, 2026-11-17)

Operator, round 4 (`plan/operator-feedback-2026-11-17.md`): "each one of the little segments is 'fine' … it's combining
them dynamically that has been the problem from day 1." This section records the combining runtime that now plays in
the game. Where it differs from §5 and §11.4, this section is what shipped.

### 12.1 What plays where

As first built. **Superseded by §12.8:** the score now plays the whole run, and nothing recorded remains.

| Where | Music |
|---|---|
| Sector 1 (Krybor), every route | score song `k`: `arrival` → `A` → `B` → `C` → `D` by wave progress, `clear` on the level clear, whose hold bar carries the travel |
| Sector 5 (every carrier, all tours) | score song `c1`: `arrival` → `approach` → `H1`/`H2` by `bossHatchTier` → `transform` → `core` → `collapse` → `victory` |
| Sectors 2–4, the menu, the defeat, the last carrier's finale and the ending | the recorded cues, unchanged (`web/audio/music/`) |

- Tours 2–5 reuse `c1`. Their extra upper tiers map onto H1 and H2 by depth (§4.3 "Tier mapping").
- The last carrier plays the score through the collapse and the victory. On `completed` it hands over to the recorded
  finale, which carries the ending as before.
- The score and the recorded cues hand over on each other's bar lines: the score starts on the playing cue's next bar
  line, and a recorded cue starts on the score's next bar line. Immediate cues (clear, victory, cackle, ending) cut at
  once with a 90 ms fade, as they did before.
- `?score=off`, or the console's RECORDED switch (remembered per device, `demonAttack.score`), plays the recorded cues
  everywhere for an A/B comparison.

### 12.2 The score (route A, §11.6)

- **Source of truth.** `art/music/soundtrack/song-map.json` lists the songs `k` and `c1`. Each has a key, a tempo, a
  grid (`barSamples`), its sections (kind, bars, hold, next, wave or hatch), the tier masks and the v2, power and
  fleet layers, the stingers and the accent map.
- **Generator.** `lua tools/score/score_gen.lua` (Lua 5.4, no libraries) composes each section with the song's
  composer and writes three outputs:
  - `web/audio/score/<song>/<section>.mid`, SMF type 1 at PPQ 480: a conductor track (tempo, 4/4, key, section marker,
    and a `hold` marker), then one track per part, named by its song-map id;
  - `web/audio/score/score.json`, the map plus sizes and sha256, for the player;
  - `lib/game/song_map.dart`, const data for `SongDirector`.

  `--check` regates and compares the outputs byte for byte. The composers are `tools/score/songs/krybor.lua` and
  `carrier.lua`. They are original writing from the game's own motifs (`tools/music_motifs.py` MOTIFS[1] and [5]:
  riff, hook) and the campaign theme and harmony (`art/music/campaign.json`). No model wrote any notes, and the ollama
  route was not needed (§11.6 route C stays a probe).
- **Coherence by construction.** Every section of a song shares its key, tempo, grid, track set, voices and mix. The
  sectors' calm and peril versions are one arrangement: tiers 1–2 are calm, and tiers 3–4 add the double kick, the
  harmony lead and the pads. The carrier's hatch sections share the riff and the hook (gallop in H1, tremolo into
  blasts in H2). The bridge's chromatic climb Db-D-Eb-E is the riff's own bar 7, and it lands on the core's F.
- **Guitar parts carry the root of each power chord.** The guitar voice sounds the fifth, and the right double also
  the octave, so a chord costs one voice, as a power-chord sample would (§11.10).
- **Voice rules.** These are shared by the gate and the player:
  - a key struck again on its track chokes its previous note;
  - lead and bass are monophonic;
  - pad chords end half a beat before the next chord, so their release carries the legato.
- **Gates** (all pass):
  - whole bars;
  - onsets on the 1/16 or triplet grid;
  - out-of-key notes ≤ 3 %. The carrier song (its riff is chromatic by design) and Krybor's Picardy clear are marked
    `chromatic` and only report it;
  - every track in a mask or layer;
  - peak voices ≤ 32 with a 0.5-beat release, with every track sounding: 14 to 29 per section.
- **Size.**
  - 14 sections, 59.8 KB of MIDI, plus a 15.6 KB `score.json`: 22.5 KB gzipped for both songs. That is about
    124 s of unique music at about 480 B/s, against the 1.36 MB of the rendered c1 pilot.
  - The player is `web/audio/demon-score.js`: 37.8 KB, 11.6 KB gzipped.

### 12.3 The player (`web/audio/demon-score.js`, inside demon-audio.js's scheduler)

- **One clock.** demon-audio.js's 25 ms timer calls `tick(now + 0.25)`. Every note is scheduled ahead with `start(when)`
  on the audio clock, so the main thread does a few node creations per tick. The lookahead is 0.25 s for the score
  (0.12 s for the recorded cues), because score moves are quantised to bars anyway. Stingers schedule at once on their
  own anchors.
- **Moves.** `demonAudio.song(move)` takes `{song, section?, at, quantum, enter, tier?, variant?, fleet?, reason,
  fallback?}` and returns the landing time: −1 while loading or before the first gesture (the move then runs once
  ready), or −2 when the score is off (the fallback cue plays).
  - A move lands at `at`. If `at` falls inside the already-scheduled window, it slips to the next line (`state.slipped`).
  - The latest pending move replaces an earlier one.
  - At a move, the left section's held notes are released over 30 ms, and notes scheduled past the move never start.
  - `enter: same` keeps the bar position, modulo the destination's length.
  - Tails and bridges hand over to `next` at their end. A tail without `next` repeats its hold bars.
- **Intensity.** It is a track mask applied on the requested line: newly audible tracks fade in over 20 ms, silenced
  ones fade out over 60 ms, and the notes of silent tracks are not scheduled. Nothing restarts.
  - The power-up layer (cymbals and double kick) follows `powerLayer()` on the next bar line.
  - The bright shelf still opens while a pickup falls.
- **Stingers.** These are scale-degree scores in `score.json`, transposed to the playing section's key (`clear` is in
  E major, `victory` in F major) and anchored on its grid.
  - Lead-ins with negative times end on the anchor; the dive fill ends on the next bar line.
  - Each stinger has a minimum spacing in beats. At most two play at once, except the life-loss accents.
- **Voices** (synthesis: §11.8 step 2, the guaranteed-everywhere layer). Each voice role passes through a bus:

  | Voice | Synthesis | Bus |
  |---|---|---|
  | Kick | sine with a pitch drop, plus a noise click | drum bus |
  | Snare | triangle body plus band-passed noise | drum bus |
  | Hats, ride, crash, china, splash | filtered noise; the ride adds a ping | drum bus |
  | Toms | sines with a pitch drop | drum bus |
  | Bass | saw plus sine through an enveloped low-pass | light tanh drive and a low-pass |
  | Guitars | detuned saws per chord tone, darker and damped when palm-muted (velocity ≤ 92) | §11.4 chain: pre-EQ high-pass → gain → tanh `WaveShaper` (4x oversampled, 2x on phones) → a second shaper → cabinet filters (80 Hz high-pass, −5 dB at 400 Hz, +4 dB presence at 2.4 or 2.9 kHz, 5.5 kHz low-pass) → left and right doubles with different curves |
  | Lead | two saws with delayed vibrato | drive, cabinet and a 0.3 s echo |
  | Organ | additive partials | pad bus |
  | Strings | detuned saws, slow attack | pad bus |
  | Brass | a low-pass envelope swell | pad bus |
  | Choir | band-passed saw and triangle | pad bus |
  | Timpani | pitched sine with a thump | percussion bus |
  | Bells | four inharmonic partials | percussion bus |

  The pad bus has a long generated convolution room (1.7 s, 1.1 s on phones), and the drum bus a little of it.
- **Voice cap.** 48 voices on desktop and 32 on phones (`deviceMemory` ≤ 4 or a coarse pointer). Pads are stolen
  first, then leads; kick, snare and bass never.
- **The sample-bank seam.** `makeVoice(role, pitch, velocity, at, duration, destination)` is the one function a bank
  replaces. With tillandsias#1103 or the operator's consent (N11), it looks up a zone and plays an
  `AudioBufferSourceNode` into the same role bus, falling back to the synth per note until the zone decodes (§11.8).
  The score, the graph player, the buses and `SongDirector` stay as they are.
- **Diagnostics.** `demonAudio.state.score` reports:
  - the section and its start;
  - the pending move, the mask, the audible tracks and the queued masks;
  - voices, the cap, stolen voices and slipped moves;
  - the last 16 moves and stingers.

  `demonAudio.scorePosition` reports the playing section and the time of its beat 0.

### 12.4 `SongDirector` (`lib/game/song_director.dart`, pure Dart)

- **Inputs.**
  - Every scene cue of main.dart goes through `cue(mode, …)`. It returns false where the recorded cue should play.
  - It listens on the shared bridge for `musicIntensity`, `waveStart`/`cohortMerged`, `fleetIntact`,
    `bossHatchTier`, `bossTransform`, `bossCoreExposed`, `bossShieldFailing`, `bossModuleLost`, `bossCollapseStart`
    and `bossCollapseEnd`. These are all structured events or MusicDirector's own; nothing new is emitted, so nothing
    is double-emitted (CLAUDE.md §3).
  - `MusicBridge` keeps the accents and forwards the carrier's accents per §4.3. `bossLaunch` plays a light `stab`
    rather than the full `hit`, because volleys come often.
- **The grid.** The director keeps its own picture of the grid: section starts on the audio clock (`AudioSongClock`
  reads `demonAudio.time`). Each move is sent with an explicit bar-line (or beat-line) time at least 0.3 s ahead. It
  re-syncs from `demonAudio.scorePosition` when the player reports a different section, for example after a slip or a
  deferred start.
- **The rules of §4.3.**
  - Minimum dwell: 2 bars, and 1 bar before the transformation.
  - The latest waiting request wins.
  - Tier mapping by depth.
  - The collapse and the clear land on the next beat; the rest on the next bar.
  - The v2 layer is sticky once the shield fails (hatch sections) or a module is lost (core).
  - The fleet layer joins on `fleetIntact`.
  - Wave progress only moves forward.
- **Tests.** `test/song_director_test.dart` covers the sector sequence, the whole fight graph on bar lines, two quick
  tiers, the dwell, depth mapping, the recorded-cue hand-backs, the deferred sync, the score-off fallback, the fleet
  layer and the move format. `test-worker/score.test.mjs` runs the real player on a mocked audio clock and covers:
  - the score files against the map;
  - bar-exact hand-over, no gap at a move, and latest-wins;
  - the bridge into the core;
  - same position and beat moves, and slip;
  - masks without a restart, and the power, v2 and fleet layers;
  - hand-over in both directions with the recorded cues, and stingers;
  - the score-off fallback, and the voice cap over a long fight.

### 12.5 How to hear it

- **In the game.** Play sector 1, or open `/console`, choose BOSS with FIGHT or FAST DECAY, and launch: the real fight
  drives the score.
- **On `/console`, the SCORE · LISTEN panel** drives the live player through its own `SongDirector`, using the game's
  event names:
  - CARRIER FIGHT plays the fight's events on their own timing (approach tolls, tier 1, telegraph, volley, tier 2, the
    shield failing, the 3.5 s transformation, the core, a module lost, the collapse, the fleet and the victory) in
    about 55 s;
  - SECTOR SONG plays the arrival, four waves with the intensity rising and falling, dives, a last stand and the
    clear;
  - step buttons trigger every section move and every stinger by hand;
  - SCORE / RECORDED switches the game for an A/B comparison.
- **Not verified in a real browser here.** The host preview serves only the operator's checkout, so the synth voices,
  levels and CPU load still need a listen. That is the operator's verdict (N1, N13), together with the mix balance
  between voices, which no metric here measures.

### 12.6 Coexistence with the rendered audio (§11.2)

As first built. **Superseded by §12.8.3:** everything proposed here was done once the operator approved the preview.

- **The rendered pilot sections are not used.** These are `art/music/soundtrack/pilot/c1-*.opus` (7 files, 1.36 MB,
  under `art/`, never shipped). They are full mixes of the same parts the score plays, so under §11.2 they cannot be
  texture beds. A future choir or air bed would be a new no-drums take (task 8.7).
- **Proposed, for the lead to decide (not done here):**
  - once the operator approves the `c1` score by ear, delete the seven pilot encodes. Their recipe stays the record
    (N8);
  - once `k` and `c1` are approved, the recorded `l1-*` and `l5-*` cues in `web/audio/music/` (1.98 MB as Opus) and
    `web/audio/midi/` (22 KB) are reached only through RECORDED or `?score=off`; delete them when the A/B is no longer
    needed.
- **Found in passing.** `web/audio/music/` still ships an `.m4a` (AAC) twin of every cue (9.68 MB in all), although
  N5 decided on one format with no AAC fallback, and demon-audio.js loads only `.ogg` (`formats = ['ogg']`). That is
  dead weight, flagged for the lead. **Done 2026-11-17** (no fallback format, operator): the twins are deleted and the
  pipelines encode Opus only.

### 12.7 What the sample bank would add

The bank (N11, tasks 8.5 and 8.6) is real recorded instruments behind the same seam:

- multi-velocity drum hits with round-robins instead of noise and sine models;
- a DI bass and DI guitars through the same amp and cabinet chain, which is the largest audible step (§11.10);
- organ, brass, strings, timpani and tubular bells from VCSL and VSCO 2 CE.

Its budget stays ≤ 2 MB Opus and ≤ 41 MB decoded (16 MB on phones). There is no CC0 choir: a texture bed carries the
choir (N12), and the synth choir plays meanwhile. Nothing in the score, the graph, the director or the tests changes
when it lands.

### 12.8 The whole run (`work/score-full-run`, 2026-11-17, tasks 9.8 and 9.9)

The operator heard the `k` and `c1` preview and approved the approach and its sound: "That's a pretty sweet preview,
continue with the rest :D" (2026-11-17). This section records the rest of the run in the same generator, player and
director. Where it differs from §12.1-§12.6, this section is what ships.

#### 12.8.1 What plays where

| Scene | Song (`art/music/soundtrack/song-map.json`) | Sections |
|---|---|---|
| Title | `menu` Overture, E minor, 120 | `overture` (loop): the campaign theme on bells, then lead with a half-time band |
| Sector 1, every route | `k` Krybor, E minor, 170 | as §12.1, plus `storm` |
| Sector 2 | `r` Ringfall, D major, 160 | `arrival`, `A`-`D` by wave progress, `storm`, `clear` (D major) |
| Sector 3 | `e` Ember Moon, E minor, 180 | the same form; `clear` in E major |
| Sector 4 | `h` The Hollow, C minor, 150 | the same form; `clear` in C major |
| A Stormfront bonus level | that sector's song | `storm` from the arrival's end until the clear (`bonusStart` `variant: stormfront`); Supply Run keeps the waves |
| Sector 5, tour *t* | `c1`-`c5`, F minor, 190 | `arrival`, `approach`, `H1`-`HU` (U = 2, 2, 3, 3, 4: one per upper tier), `transform`, `core`, `collapse`, `victory` |
| The last carrier's end | `c5` | `victory` (F major resolution) → `finale` (8 bars, F major) → `worldized` (6-bar bridge, mono band-pass) → `coda:ukulele` |
| The ending and the credits | `coda`, F major, 95 (bar 121 264 = the carrier bar × 2) | `ukulele` (8 bars, tail) → `reprise` (loop) |
| Game over | `defeat`, 120 | `cackle` (2-bar bridge, lands 30 ms after the event) → `alienwin` (loop, E Phrygian dominant) |

- **Sector songs** share one composer, `tools/score/songs/sector.lua`. It has the same form, band and mix as Krybor,
  and the world's own riff, hook and harmony (`tools/music_motifs.py` MOTIFS[2-4], `art/music/campaign.json`). The
  campaign theme is written in scale degrees and sung in each world's key. The world's style changes the picking and
  the drums:
  - Ringfall plays 3+3+2 open chords over driving eighths;
  - Ember Moon plays the gallop with its Phrygian F;
  - The Hollow plays half-time doom with the Gb tritone.

  Krybor keeps its own composer and gains only `storm`. Its other sections are byte-identical to the approved preview.
- **Carrier songs.** `c1` is unchanged, byte for byte. Tours 2-5 are `tools/score/songs/carrier_tours.lua`, with the
  same riff, hook and theme. Each tour climbs its own ladder of hatch figures:

  | Tour | Hatch figures, from H1 up |
  |---|---|
  | 2 | skank, then blast |
  | 3 | gallop, skank, blast |
  | 4 | doom march, gallop and blast bar by bar, blast |
  | 5 | gallop, skank, tremolo into blasts, full blast |

  Each hatch section has its own lead writing: the hook answered by the theme, in sixths, in octaves, augmented, or
  in canon, or the choir chanting the theme. The approach, transformation, core, collapse and victory of each tour
  escalate on the tour before: double tolls, choir chants, sixteenth double kick, the climb doubled in octaves, a
  canon in the core. The fights are the choruses (§3.1). Every tier maps natively (`bossHatchTier` tier k → `Hk`).
  The depth fold of §4.3 remains only for a song with fewer sections.
- **The coda's ukulele** is its own track, `uke` (role `uke`, GM program 24). It is an oscillator pluck (a triangle and
  its octave through a soft low-pass) on the clean bus. Its re-entrant G-C-E-A shapes strum the island pattern under
  the theme. A sampled ukulele replaces the pluck at the bank seam (§12.8.5).

#### 12.8.2 Bridges: one run, one song

A bridge is its own song (`form: bridge`, one `pivot` section, `tools/score/songs/bridges.lua`) at the source
song's tempo:

- it holds the campaign's common tone through its pivot chords (`art/music/campaign.json` `bridges`, design §3.1);
- it plays the destination key's theme fragment on bells and clean guitar;
- it has no drums, only a timpani swell into the next downbeat;
- it hands over to the destination's `arrival` on its last bar line (`next: song:section`).

| Bridge | Grid | Pivot | Into |
|---|---|---|---|
| `menu-k` | 120, 1 bar | E under Em → B7 | Krybor's arrival, on START |
| `k-r` | 170, 2 bars | E under Em → G → A7 | Ringfall (D) |
| `r-e` | 160, 2 bars | B under Bm → C → B7 | Ember Moon (Em) |
| `e-h` | 180, 2 bars | G under Em → G → G7 | The Hollow (Cm) |
| `h-c` | 150, 2 bars | C under Cm → Db → C7 (V → i) | the tour's carrier (Fm); SongDirector sends `then: c<t>:arrival` |
| `c-k` | 190, 2 bars | F → C (C held) → B7 | the next route's Krybor |
| `c5/worldized` | 190, 6 bars | F → Bb → F-C → Dm → Bb → C, mono band-pass 300 Hz-4 kHz | the coda's ukulele (F) |

- **When they play.** The travel cue (`travel`) asks for the bridge into the next sector's song (`level + 1`, or
  route + 1's Krybor after a carrier). The bridge lands at the end of the clear's or the victory's written bars, or
  on the next bar line if the hold is already playing. The next level's cue then finds the bridge heading into its
  song and moves nothing. A sector reached with no travel (a console start, a continue after a defeat) starts its
  arrival on the next bar line of whatever plays.
- **The ending.** The cinematic opens about 4 s into the last carrier's victory phase. `ending` moves `c5` into
  `worldized` on its next bar line, and the ukulele enters about 8-9 s later, near S3 (§4.4). Without the cinematic,
  the chain runs on: `victory` → `finale` → `worldized` → `ukulele` → `reprise`. `completed` moves nothing.
- **Coverage.** `test/song_director_test.dart` ("a full five-route campaign plays as one song") drives the director
  with a five-route event trace: arrivals, waves, intensity, a storm, clears, travels, every tour's tiers, the
  transformation, the collapse, the ending. A model of the player's grid checks the song sequence (`menu`, `menu-k`,
  then per route `k`, `k-r`, `r`, `r-e`, `e`, `e-h`, `h`, `h-c`, `c<t>`, with `c-k` between routes, then `coda`). It
  also checks that every section move lands on a bar line of the music playing before it (a beat line for the
  collapse and the clear).

#### 12.8.3 Retired (the one-format rule, §11.2)

Every place a recorded cue played is now covered by the score:

| Recorded cue | Now plays |
|---|---|
| menu | `menu` |
| `l<n>-*` | the world songs and the carriers |
| levelclear(-fleet) | each world's `clear` plus the fleet layer |
| victory | each carrier's `victory` |
| finale(-fleet) | `c5` `finale` |
| ending | `coda` |
| cackle and alienwin | `defeat` |

So the recorded music is deleted, and no recorded cue is kept.

| Retired | Files | Bytes |
|---|---|---|
| `web/audio/music/` (the Opus cues and `manifest.json`) | 53 + 1 | 6 337 063 (Opus 6 301 643, manifest 35 420) |
| `web/audio/midi/` (the MIDI fallback cues) and `web/audio/generate-midi.py` | 38 + 1 | 67 929 + 3 299 |
| `art/music/soundtrack/pilot/c1-*.opus` (rendered pilot sections, never shipped) | 7 | 1 360 205 |
| `test-worker/music.test.mjs`, `test-worker/audio.test.mjs` (the recorded player's tests) | 2 | — |

- **The AAC twins.** `work/one-format-audio` (db685525) had already deleted the 53 `.m4a` twins (9 677 826 B). With
  this branch, the recorded music is gone entirely: 17.4 MB in all since the preview, 7.77 MB of it here.
- **The recipes stay.** `art/music/soundtrack/pilot-carrier-t1.json`, `art/workflows/music/cues.json` and the
  provenance in `plan/asset-provenance.md` remain the record (N8). `tools/music_pipeline.py` and
  `tools/soundtrack_pilot.lua` are kept as tools. They would write into the retired paths, so they are not part of the
  build.
- **The switch is gone.** `demonAudio.cue`, `scoreEnabled`, `?score=off`, the console's SCORE/RECORDED switch and
  `demonAttack.score` are removed. `demon-audio.js` is now the engine only (context, buses, levels, effects, the
  score's scheduler): 15.5 KB, down from 46.2 KB. `SongMove.fallback` is gone. A score that fails to load leaves the
  game silent, with effects only.
- **The review studio** (`/gallery/?page=studio`) lists the score's 85 sections as its music cues. They come from
  `audio/score/score.json` (`song/section`, the MIDI file and its sha256). `lib/review/review_score_audio.dart`
  plays them on the live player.

#### 12.8.4 Sizes and runtime

- **The score.** 85 sections in 18 songs: 340 710 B of MIDI and a 49.6 KB `score.json`, 110 KB gzipped together. That
  is 764 s (12.7 min) of unique music at about 446 B/s.
- **The player.** `demon-score.js` is 40.9 KB (12.7 KB gzipped).
- **Per song** (sections, bytes):

  | Songs | Sections, bytes |
  |---|---|
  | Worlds `k`, `r`, `e`, `h` | 7 each: 31 061, 29 288, 32 253, 28 939 |
  | Carriers `c1`-`c5` | 8, 8, 9, 9, 12: 33 817, 33 712, 40 458, 38 510, 55 753 |
  | Bridges | 711-866 each |
  | Overture, coda, defeat | 2 530, 5 348, 4 119 |

- **Gates.** Every section passes the §11.9 gates. The peak is 12-30 voices with every track sounding (`c5`
  `transform` is 30), under the gate's 32. `score.test.mjs` holds the sizes (MIDI under 400 KB, `score.json` under
  64 KB, under 160 KB gzipped) and the voice cap. The cap is checked on sounding voices: a tier-4, v2, fleet and
  power `c5/H4` stays within 48 on desktop and 32 on phones.
- **Loading.** The player fetches `score.json`, then the songs in the run's order:
  - the overture, the defeat and the bridges into Krybor first, then each world after its bridge, then the carriers
    and the coda;
  - each song's sections in parallel, parsed as they arrive (a few KB each, so no long task);
  - the score is ready after its first song;
  - a move to a song still loading returns -1 and runs on the next bar line once that song has loaded; an
    auto-advance into one holds the section being left.
- **Move rules.** A `now` move (the defeat) lands 30 ms ahead and cancels the notes scheduled past it. A move's `then`
  overrides a bridge's `next`. Stingers, masks, the voice rules and the cap are as §12.3. The new code adds nothing to
  each tick: one boundary check per tick, and one filter retarget per worldized section.

#### 12.8.5 What still waits for the sample bank (N11, tasks 8.5-8.6) and tillandsias#1103

- **The instruments.** Real drums, DI guitars, bass, organ, brass, strings, timpani and bells behind `makeVoice`
  (§12.7) are the largest audible step, and they need no score change.
- **The ukulele.** It plays the oscillator pluck. The bank needs a CC0 ukulele zone, which is not yet found or
  verified (R§2.3, unverified). It drops in as role `uke`.
- **The choir.** It stays synthesized. There is no CC0 choir, so a texture bed carries it later (N12, task 8.7).
- **Route thickening and v1/v2 stem variants** wait for #1103 (tasks 6.2-6.3). The world songs are shared by the five
  routes, so the carriers carry the escalation.
- **The worldized chain** is a band-pass plus mono fold. The design's small-room colour is the shared room reverb.
- **Operator listening (9.7)** of the new songs, the bridges, the coda and the mix balance is still open. None of the
  sound was verified in a real browser here: the host preview serves only the operator's checkout.

### 12.9 The sample bank, ready for its samples (`work/score-sampler`, 2026-11-17, tasks 8.5, 8.10, 8.12, 8.13)

The operator on the live score: "nice and smooth progression". The next layer is real instruments behind `makeVoice`
(§12.3, §12.7), note for note, so the combining stays as it is. **No sample is admitted yet.** The Tillandsias open
register must admit the pins of `plan/sample-bank-pins.md` first, and the coordinator hashes them on the host. So
nothing here downloaded a sample. Everything around the samples is built and tested on synthetic tones, and only the
fetch remains (§12.9.6).

Update: the pins were admitted and the bank is built. It ships off by default behind a switch (§12.9.7).

#### 12.9.1 Recipe and keys

- **`art/music/bank/recipe.json`** is the bank's record (N8). It lists 20 instruments over the manifest's groups. For
  each it gives:
  - the roles it plays and an optional `when`: guitar staccato for velocity ≤ 92, as the palm-mute stand-in; bass
    staccato for notes ≤ 0.2 s; trombone staccato for notes ≤ 0.3 s;
  - the drum keys, or the source of each root (the SFZ map, the file name, or a table);
  - the velocity split of its layers, its trim, its channels and its load tier;
  - its phone rule, its stretch beyond the outer roots, its loop, its release and its gain.

  The roles get a level each. The guitars get their power chords (`[0, 7]` left, `[0, 7, 12]` right, ±7 cents), the
  same chords the synth guitars play. Instruments are tried in order. The velocity splits, trims, stretches, gains and
  levels are our judgement, to be tuned by ear (9.7). The war drum is pinned but not built, because no score track
  plays it. The cello strings are optional (`--with strings`): they reach B3, and the score's string pad sits at C4-C6.
- **`art/music/bank/sfz-keys.json`** is generated by `bank_build.lua --sync-keys` from the eight pinned SFZ maps. The
  maps are manifest rows, each under 100 KB, and the pins doc lists them as fetched. They were fetched again at their
  pins, and every one reproduced its manifest blob sha1.
  [source: Karoryfer/sfzinstruments, "growlybass_dirty.sfz", "growlybass_vicious.sfz" at 4f48326,
  https://raw.githubusercontent.com/sfzinstruments/karoryfer.growlybass/4f483268fc66b5a6d5781d421c0d11b8d08d3fc6/growlybass_dirty.sfz, read 2026-11-17];
  [source: Karoryfer/sfzinstruments, "Programs/modules/maps_black/ord.sfz", "stac.sfz" at f3cf516,
  https://raw.githubusercontent.com/sfzinstruments/karoryfer.black-and-green-guitars/f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9/Programs/modules/maps_black/ord.sfz, read 2026-11-17];
  [source: Versilian Studios/sgossner, "FHornSus.sfz", "TromboneSus.sfz", "TromboneStac.sfz", "CelloEnsSusVib.sfz" at 1.1.0,
  https://raw.githubusercontent.com/sgossner/VSCO-2-CE/28092772094b2d9f1148d84cea97f4545b8c687d/FHornSus.sfz, read 2026-11-17]
  - Growlybass's `c4` regions set no `pitch_keycenter`. They take the SFZ default of 60, which their lokey/hikey of
    59-61 agree with.
  - **Bass octave.** The maps give the bass `e2` keycenter 40 and the guitar `e3` keycenter 40. The Growlybass readme
    calls `db2` the low E string tuned down to C# (`plan/sample-bank-pins.md` §2, which quotes it). A bass's low E
    sounds an octave below a guitar's, so the bass map plays an octave above the sound. The recipe therefore shifts
    the bass by −12. This is our inference, and the f0 check at build decides.
  - VCSL has no maps at the pin. The organ and bells take their pitch from the file name (C4 = 60), and the timpani
    from the pins doc's table.

#### 12.9.2 The builder (`lua tools/bank/bank_build.lua`, Lua + ffmpeg)

1. **Plan** (`tools/bank/bank.lua`, shared with the score gate). There is one zone per manifest file: its note,
   velocity layer and round robin, its root, and a key range. The ranges split halfway between neighbouring roots;
   the outer ends reach the recipe's stretch or the map's own lokey/hikey. Load tiers:
   - tier 1 is the kick, the snare, the bass and the guitars;
   - tier 2 is the cymbals, hats, toms, organ, brass, timpani and bells;
   - tier 3 is every extra velocity layer and round robin.

   There is one sprite per tier, phone class and channel count.
2. **Verify.** Every source must be present at `<src>/<owner>/<repo>/<path>` with its pinned size and git blob sha1
   (`git hash-object --no-filters`). One mismatch refuses the whole build, and nothing is written.
3. **Cut.** ffmpeg removes the leading silence below −60 dB, trims to the recipe's seconds, and folds to the zone's
   channels at 48 kHz.
4. **Check pitch.** An f0 estimate (YIN, 25 Hz-2 kHz) runs on every pitched zone.
   - A whole-octave offset shared by the instrument is corrected and logged.
   - A `strict` instrument refuses any other disagreement over 0.6 semitone. Timpani and bells only report one.
5. **Shape.** Each instrument is normalised to a −1 dBFS peak, so its velocity layers keep their dynamics. Each zone
   gets a 20 ms fade, or an equal-power loop crossfade for the organ, horn and trombone sustains.
6. **Encode.** The zones are packed with 50 ms gaps into the sprites, encoded Opus in Ogg (64 kbps mono, 96 kbps
   stereo) with bit-exact flags, and checked against the budgets.
7. **Write** `web/audio/bank/bank.json`: roles, instruments, sprites (bytes, sha256, decoded bytes) and zones
   (sprite, offset, length, root, range, velocity, round robin, loop, gain, measured f0, source repo, path, blob and
   sha256), plus the sources with their licence and credit.

The same sources give the same bytes: the fixture test builds twice and compares.

`--dry-run` plans from the manifest alone:

| Bank | Zones | Sprites | Opus (est.) | Decoded, desktop | Decoded, phone tier |
|---|---|---|---|---|---|
| Core, as planned | 159 | 8 | 1 519 392 B | 38 256 000 B | 14 553 600 B |
| Budget (§11.5) | | | 2 000 000 B | 41 000 000 B | 16 000 000 B |

This agrees with the pins doc's own arithmetic (≈ 1.45 MB plus the Ogg overhead, ≈ 37.1 MB, ≈ 15 MB).

#### 12.9.3 The sampler (`web/audio/demon-score.js`)

- **Loading.** The sampler fetches `audio/bank/bank.json` beside `score.json`. Once the score has loaded and the
  context exists, it fetches and decodes the sprites one at a time, in the bank's order.
  - Phones load only the phone sprites. Every sprite stays within the tier's decoded budget, 41 MB on desktop and
    16 MB on phones.
  - A sprite that fails to decode is counted and skipped, as in Safari before 18.4. Its notes stay synthesized
    (§11.8).
- **One timbre per part.** A section's track plays from the bank only if the bank covers every one of its notes, with
  every chord tone, on this device's tier. The decision is cached per section and track.
- **A note.** The first instrument whose role and `when` fit picks a decoded zone:
  - the velocity layer that contains the velocity, else the nearest one decoded, so phones play their single layer;
  - the next round robin of that layer.

  The zone plays as an `AudioBufferSourceNode` with `start(at, offset, length)` and `playbackRate = 2^((pitch −
  root)/12)`. Looped sustains use `loopStart` and `loopEnd`. The sources go into a per-note envelope and then the
  track gain and role bus they always used: the guitar amp and cabinet, the bass drive, the drum room, the pad
  reverb. Guitars sound two or three zones as their power chord, and palm-muted notes keep a darker filter before the
  amp. Choke, mono, stealing and the 48/32 cap are unchanged.
- **Until a zone decodes,** the synth voice plays the note (`state.score.bank.synth` counts these).
- **Diagnostics.** `state.score` adds:
  - `bankLoaded` and `bankDecodedBytes`;
  - `bank`: present, tier, sprites, loaded, skipped, failed, the decoded bytes against the budget, zones, ready zones,
    the sampled notes and the synth fallbacks, and the last error.
- **Without a bank** nothing else is fetched or created. `makeVoice` falls through to the unchanged synth code.
  - `node tools/mix_meter/trim.mjs --check` still reproduces `web/audio/score/mix-trim.json` byte for byte.
  - `music.test.mjs` shows that a bank whose sprites never finish decoding starts the same synth sources, at the same
    times, as no bank at all.
- **Size.** The player is 52.3 KB (16.2 KB gzipped). `score.test.mjs` now allows 56 KB raw and 20 KB gzipped.
- **The offline meter** (`tools/mix_meter`) decodes the bank's sprites through ffmpeg, mono or stereo. Its buffer
  source now takes offset, duration and loop points, so `trim.mjs` measures the sampled score once a bank exists.

#### 12.9.4 The score gate (`lua tools/midi_stats.lua check`, task 8.10)

The gate checks every section of `web/audio/score/` and exits 1 with each failure listed:

- whole bars: the file ends on its bars plus hold;
- onsets within 12 ms of the 1/16 or triplet grid at the song's tempo;
- out-of-key share ≤ 3 %, except where the song map marks the music `chromatic`;
- the peak with the score's voice rules and a 0.5-beat release ≤ 32, naming the bar;
- sizes against `score.json`;
- zone coverage against `bank.json`, or the recipe's plan until a bank exists. A role the recipe marks
  `cover: full` (the drums) must be covered note for note, and `--strict-zones` extends that to every role. The rest
  are reported, and a section track the bank cannot cover plays the synth voice (the spec's "A partly covered track").

On the committed score: `check: ok 85 sections, 340710 B of MIDI, peak 30 voices, 0 failure(s)`.

| Role | Notes | Covered (phones) | What the pins miss |
|---|---|---|---|
| drums | 12 915 | 100 % (100 %) | — |
| bass | 2 812 | 98.1 % (98.1 %) | F#0-G#0 (18-20), below Growlybass's drop C# even at −4 |
| guitarL / guitarR | 3 631 / 4 364 | 98.5 / 98.1 % (98.5 / 94.7 %) | F#1-G#1 (30-32) roots, 5 below the guitar's low E |
| timpani | 1 067 | 99.8 % | A1 (33) |
| organ | 2 231 | 94.3 % | F1-F#1 and A#4-A5: the six VCSL pipes span C2-F#4 |
| clean | 668 | 76.3 % (12.4 %) | above E5; on phones the guitar stops at A#4 |
| bells | 442 | 82.1 % (0 %) | above A5; no bells on phones |
| brass | 1 277 | 63.4 % (13.6 %) | above F#4: the horns stop at C4 (+6 by the map), and the score's fanfares sit higher |

So 653 of 796 section tracks play from the bank whole (556 on phones), and the rest play the synth. This is a
finding for the pins, not for the score. The biggest gains would be:

- higher brass: horn notes up to C5, or a trumpet;
- organ pipes above F#4, if VCSL has them;
- tubular bells above E5.

Each needs its own licence check and pin, and the register has to admit it, so this is proposed, not done.

#### 12.9.5 Tests (`test-worker/music.test.mjs`, task 8.13; the name is reused, since the recorded player's file went with §12.8.3)

- The score: the files parse, every section is whole bars, and the masks name real tracks.
- The plan:
  - every drum note is covered, and the main pitched roles are more than 90 % covered;
  - every zone has a real role, a real sprite and a sane range;
  - the budgets hold, and tier 1 loads first;
  - a built `bank.json` matches its sprites' bytes and sha256.
- The gate: `check` passes the committed score and fails a fixture that is half a bar short, 30 ms off the grid and
  out of key.
- The builder, on sine tones made with ffmpeg:
  - the dry-run estimate;
  - the build: a stereo hit, a tone named right, and a tone named an octave high that f0 corrects;
  - trims, the loop, bank.json, sprite sha256 and sizes, a loud zone and a silent gap in the decoded sprite;
  - a byte-identical rebuild;
  - refusal of a source that is not its pin, and of a strict tone that is not its named note.
- The sampler, on a mocked clock with a bank made from the plan:
  - no bank: only `bank.json` is asked for;
  - a bank still decoding gives the identical synth notes;
  - a decoded bank plays zones on their offsets, rates in whole semitones within the stretch, round robins, guitar
    power chords of five sources, and stays under the cap;
  - phones fetch only the phone sprites, stay ≤ 16 MB decoded, and peak ≤ 32 voices in `c5/H4` at tier 4 with v2,
    the fleet and power.

#### 12.9.6 What remains once the pins are admitted

1. One command from the repo root:
   `forge-guard run -- lua tools/bank/bank_build.lua --fetch && forge-guard run -- node tools/mix_meter/trim.mjs`.
   - `--fetch` downloads only the manifest files `~/.cache/tillandsias-project/sample-bank/src` lacks, verifies each
     against its pin, then builds.
   - The trims must be measured again because the music now sounds different.
   - If the coordinator hands over the files instead, put them under `<src>/<owner>/<repo>/<path>` and drop `--fetch`.
2. Read the f0 notes the build prints. The bass octave, and the organ and bell names, are the open questions.
3. Gates and commit: `lua tools/midi_stats.lua check` (now against `bank.json`), the §2 gates, then commit
   `web/audio/bank/` and the new `mix-trim.json`.
4. Credits: `bank.json` carries each source's credit, but the credits screen does not read it yet (task 8.5's
   `assets/credits.json` part).
5. Listen (9.7, 8.4): tune the role levels, the instrument gains and the velocity splits in the recipe, then rebuild.

#### 12.9.7 The real bank, behind a switch (`work/sample-bank`, 2026-11-17, tasks 8.5, 8.6)

**The fetch.** The coordinator cleared it: all 196 manifest rows, round 1 plus the 12 round-2 rows of
`plan/licences-round-2.md` §5, match GitHub's trees at the five pinned commits, with the CC0 licence hashes.
- The forge fetched each file at its pinned commit, never from a branch or a tag.
- Every file passed the size and blob sha1 check. Nothing was refused.
- Round 2 needed the four recipe entries of its §5.4 (`gtr-hi`, `trumpet-sus`, `glock`, `organ-ext`) and a new
  `sfz-keys.json` (11 maps).
- The run, the picks with their reasons and every measurement are in `plan/render-runs/sample-bank.md`.

**The pitch check, replaced.** The first build refused 27 zones:
- YIN on one 87.5 ms window at 80 ms found no f0 for the distorted bass, the short staccatos and the low brass;
- it read three organ pipes an octave high, because open flue pipes speak the octave first;
- a multi-window YIN with the paper's global-minimum fallback was worse, because it locked onto subharmonics.

So the builder now verifies the planned root instead of guessing one. It computes one spectrum per zone: 16 kHz
behind a 63-tap low-pass, from 80 ms for up to 1 s, Hann-windowed, zero-padded to 2^16 points. Then:
- **Octave.** Periodicity at f puts partials at odd multiples of f.
  - A zone moves an octave down while the partials at odd multiples of F/2 carry more than 0.9 of the energy at
    multiples of F, and over 0.3 of the spectrum's peak.
  - It moves up while F's odd partials are under 0.02 of 2F's, and 2F's partials carry over 0.3 of the peak.
  - The instrument takes its zones' majority. A shared offset is corrected and logged.
- **Note.** The harmonic sum of sqrt-magnitudes (8 partials under 7 kHz) is maximised within ±6.5 semitones of the
  octave-corrected root.
  - The coarse 10-cent search takes each partial's peak within ±12 cents. Real partials sit a few cents off exact
    multiples, and `twang_g6`'s 4th partial is 17 dB over its fundamental.
  - A note more than 0.6 semitone off is refused (`strict`) or reported.

`--f0-report` prints the table and stops. An independent Go check agreed zone for zone. It measured the whole
source files and printed harmonic profiles, in scratch only.

**Findings.**
- **Bass −12: confirmed.** All 20 sustain zones sound within 0.40 semitone of the map keycenter −12.
  - Their odd half-partials are 0.002-0.024 of the partials, so nothing sounds an octave lower.
  - The odd partials of the shifted root are 0.34-8.7 of 2F's, so the bass does not sound at the map's own octave.
- **Bass staccato: now `verify: report`.** A 0.4 s trim of a decaying 35-160 Hz note is too short to separate
  partials from half-partials, and 7 of 20 zones read noise. On the full source files, all 20 measure within 0.6
  semitone, and the staccatos use the sustains' map.
- **Organ: the VCSL names stand (C4 = 60).** This answers round 2 §5.3.
  - All eight pipes measure within 0.12 semitone of their names.
  - Their odd half-partials are noise (0.001-0.006).
  - The odd partials of the named root are present (0.024-1.7 of 2F's). C2's 3rd and 5th partials sit at −18 and
    −12 dB re the strongest.
  - VSCO's `OrganLoud.sfz` maps the same files an octave higher, perhaps for the heard register: the even partials
    dominate. The 9.7 listening decides. The fallback is `shift: 12` with the C1/F#1 pins of round 2 §5.1.
- **Guitars, horns, trombones, trumpet, glockenspiel and the upper organ pipes:** every zone is within 0.35 semitone,
  in the mapped octave.
- **Timpani and bells** (`report`): a struck membrane is inharmonic, so the check reads its partials, not the heard
  note. The timpani scatter, and they keep the pins doc's table until the listening. The tubular bells read within
  0.30.

| Bank | Zones | Sprites | Opus | Decoded, desktop | Decoded, phone tier |
|---|---|---|---|---|---|
| Built | 168 | 8 | 1 907 850 B | 40 934 400 B | 14 553 600 B |
| Budget (§11.5) | | | 2 000 000 B | 41 000 000 B | 16 000 000 B |

Opus VBR came in 0.27 MB over the dry-run estimate, still within the budget.

`lua tools/midi_stats.lua check` against the built `bank.json`: `ok 89 sections, 356636 B of MIDI, peak 30 voices, 0
failure(s)` (with the credits and Crosswind songs merged from `game`). Coverage:

| Role | Desktop | Phones |
|---|---|---|
| drums | 100 % | 100 % |
| bass | 98.2 % | 98.2 % |
| guitarL / guitarR | 98.6 / 98.2 % | 98.6 / 94.8 % |
| organ | 98.6 % | 94.2 % |
| timpani | 99.8 % | 99.8 % |
| brass | 99.9 % | 13.7 % |
| clean | 98.6 % | 18.2 % |
| bells | 100 % | 0 % |

801 of 824 section tracks play from the bank whole (573 on phones).

**The switch (operator, round 7: "I would rather preview the music score replacement with the high res assets until
complete").**
- The bank ships **off**. `demon-score.js` `BANK_DEFAULT = false`.
- Each page load decides once: `?bank=1` or `?bank=0` in the URL wins, else the per-device choice
  (`localStorage['demonAttack.scoreBank']`, `on` or `off`), else `BANK_DEFAULT`.
- **While the bank is off, nothing under `audio/bank/` is fetched, not even `bank.json`.** The synth path is the old
  one, note for note (`music.test.mjs`).
- /console's SCORE · LISTEN panel has a **VOICES** row with SYNTH and SAMPLED buttons and a line showing what has
  loaded: sprites loaded, decoded MB and sampled notes. A press stores the choice and applies it from the next
  scheduled notes, through `demonAudio.setScoreBank(on)` and Dart's `audioSetScoreBank`.
- Switching off keeps the decoded sprites until the page reloads, so an A/B is instant.
- **To go live:** set `BANK_DEFAULT = true` in `web/audio/demon-score.js`. That is one line. `?bank=0` and the stored
  `off` still opt out.

**The trims in both modes.** `node tools/mix_meter/trim.mjs` measures every case twice, without the bank and with it
on (desktop tier, every sprite). `mix-trim.json` keeps the synth's `measuredLufs` and `trims` as before, and adds a
`bank` block with its own `rule`, `measuredLufs` and `trims`.
- The bank block narrows the same way, then shifts every trim by `rule.offset` (the synth top minus the bank top).
  The sampled score's loudest case then lands on the synth's loudest, and the score-to-radio balance of the music
  level (§12.8, mix-balance) holds in both modes.
- Bank trims may be negative (the sampled score is louder), capped at ±8 dB.
- The player uses `bank.trims` while the switch is on, else `trims`.
- A phone loads only its tier. A track whose zones have not decoded yet plays the synth with the bank trims, a small
  difference that the 9.7 listening checks.

**Role levels, matched to the synth.** The first two-mode measurement showed a large gap. The sampled score's
loudest case sat 4.6 LU under the synth's, and 38 bank trims hit the +8 dB cap: the arrivals and the coda fell up to
8.8 dB short. The recipe's role levels had never been measured against the synth voices, which the operator approved.
- Each role was soloed over nine sections in both modes (a scratch copy of the players, trims off). Its level moved by
  the median loudness gap: drums 1.0 → 5.25, bass 0.7 → 3.7, clean 0.45 → 4.1, organ 0.32 → 1.05, brass 0.36 → 0.9,
  timpani 0.85 → 3.84, bells 0.36 → 0.58. The guitars were within 1 dB through the amp and keep 0.5.
- Re-measured, every role lands within about ±1 dB of its synth.
- The rebuild reproduced the sprites byte for byte; only `bank.json`'s levels changed.

**The trims, measured** (`mix-trim.json`):
- The synth block is byte for byte the one on `game` (`top` −4.97 LUFS, 217 trims of 227 cases, with the credits and
  Crosswind songs).
- The `bank` block: `top` −4.48, `floor` −14.59, `k` 0.1978, `offset` −0.49 dB, 226 trims from −0.5 to +8 dB.
- Six trims hit the cap. The coda's `reprise` and `ukulele` end 2.5 and 3.3 dB under the window (their uke and
  strings stay synth), the credits song's `dawn` and `drift` 2.1 and 2.5 dB, and `menu-k:pivot` and `k-r:pivot` 0.8 dB
  or less.
- `mix-balance.test.mjs` checks that the bank block covers every case, that its top lands on the synth top, that every
  uncapped case falls in the synth's window, and that the player picks each mode's trims.

**The listening preview** (https://claude.ai/artifact/9GWPRDxFJByguEg56jPmpJ, private to the operator). A/B clips
of seven sections, synth against sampled, rendered offline through the shipped players with each mode's trims:
- a world song (`k:B`), a carrier core (`c1:core`) and a calm section (`k:A`);
- the tour-4 victory, whose fanfare reaches E6 above the trumpet, so its brass falls back to the synth;
- a sampled-trumpet clear;
- the overture and the defeat.

Each pair matches within 0.6 LU. The clips stay in scratch, never in the repo (`plan/render-runs/sample-bank.md` §7).

**Credits.** `tools/generate_credits.lua` adds a "Sampled instruments" section after the models: one row per source,
with the credit line from `bank.json`, the SPDX id and the source at its commit.

What remains: the operator's verdict on the preview, then the default flip (9.7); tuning levels, gains and splits by
ear; the 8.4 bake-off on phones.

### 12.10 Bonus-level music and accents (`work/bonus-music`, 2026-11-17, task group 10)

The operator on the score: "transitions and continuity… amazing", "nice and smooth progression", and asked for "some
new musical accents" for the bonus levels. On the 1UP (2026-11-17, via the coordinator): "Please don't make the 1UP
sound cartoonish, keep it in the spirit of the battle mettal inspired soundtrack, design it properly, as it will be a
sound players will love to hear, for its rarity and its special and desired effects of 1 extra life."

#### 12.10.1 What the bonus levels had

- **Stormfront** has its own music: every world song's `storm` section (§12.8.1), from the arrival's end to the clear.
  Its `stormTell` and `stormBolt` reach only the effects. Nothing musical answers the player's dodge.
- **Supply Run** has none: the sector's waves play (`BonusLevelDef.cue` is still "once one exists"), and its crates
  and catches reach only the radio and the effects.

So each gets one accent, and neither gets a section. A whole song would cost another 4 × 2 sections across the worlds,
while the level is short and already sits in its world's song.
- `cargo` (Supply Run, on `bonusCrate`, a crate shot open): a two-note bell "tick-ting" up a fourth (5 → 8) with a
  rim click, on the next sixteenth, at most once a beat.
- `thunder` (Stormfront, on `stormBait`, a bolt the ship drew that missed it): a palm-muted three-sixteenth riff on
  the tonic, a minor-third push and an open tonic with a floor-tom roll, on the next half beat.

#### 12.10.2 `bonus-wind`, "Crosswind" (the wind bonus level, `crosswind`'s)

| Section | Kind | Bars | Length | MIDI | Peak voices | What plays |
|---|---|---|---|---|---|---|
| `A` Tailwind | loop | 8 | 12.0 s | 5 274 B | 19 | the shuffle riff, the campaign theme swung on lead (thirds below on `lead2`), clean swung arpeggios, high strings, a triplet tom fill into the loop |
| `B` Crosswind | loop | 8 | 12.0 s | 6 575 B | 25 | the lift into G-D-Em-C, triplet chug and gallop, the theme's head called from the third and climbing to the ninth, bells answering, brass stabs on the swung "and" of 4, choir at tier 4 |

- **E minor, 160 BPM, on Ringfall's grid** (72 000 samples a bar). The shuffle sits on the triplet grid the gate
  already allows: a power chord on each beat and a palm-muted one on its last third, the bass walking root, root,
  fifth, octave. So it drives like the punk sections but rolls, which is the swing. Every eighth of the theme is
  swung (5/3 + 1/3 + 1 + 1 for its 1.5/.5/1/1).
- **Airy, in the same palette:** clean guitar in swung arpeggios (at most E5, inside the round-1 guitar zones), high
  strings, bells. The metal stays in the power chords, the triplet double kick and the brass stabs.
- **Masks:** a `wind` mask set. Tier 1 is drums, bass, guitars, clean and bells; tier 2 adds lead, cymbals, strings
  and timpani; tier 3 adds `drums2`, `lead2` and brass; tier 4 adds the choir.
- **Composer:** `tools/score/songs/bonus.lua` (form `bonus`, one table entry per bonus song).
- **Keys at the edges.** The bonus levels play in sectors 2-4 (`BonusLevelDef.sectors`), so the song enters from
  Ringfall's D major, Ember Moon's E minor or The Hollow's C minor arrival, and hands back to that world's clear (D, E
  or C major). Each change is a new song on a bar line (in) or a march flourish on a beat (out), as a sector start
  is. A per-world transposition is an open question for the operator's ear (§12.10.6).

#### 12.10.3 Stingers

| Accent | Quantum | Spacing | Sounds for | Voices alone | Layered peak (over) | JSON |
|---|---|---|---|---|---|---|
| `oneup` | bar (fill 1 beat before) | 16 beats | 6.5 beats: 2.3 s at 170, 2.4 s at 160, 2.1 s at 190 | 16 | 32 (`all`: c5/transform) | 2 459 B |
| `challenge-fail` | beat | 8 | 2.2 beats, about 0.8 s | 3 | 32 (`wave`, `bonus`, `song:bonus-wind`) | 302 B |
| `gust` | beat | 4 | 2.5 beats, about 0.9 s | 5 | 30 (`song:bonus-wind`) | 870 B |
| `cargo` | 1/16 | 1 | 1 beat | 3 | 31 (`wave`) | 226 B |
| `thunder` | 1/2 beat | 4 | 2 beats | 3 | 32 (`bonus`) | 563 B |

- **`oneup`, a stop-time.** A snare-and-tom pickup in sixteenths leads into the next bar line. On it, the band
  stops for one bar (the stinger's `break`), and the 1UP plays alone: a kick, crash, timpani and power-chord hit on
  the tonic, the campaign theme's head (1-3-5-7♯, its own 1.5/.5/1/1 rhythm) on brass in two parts with the lead an
  octave above, a choir triad lifting under it, the guitars and bass moving I → VI → V under a sixteenth double-kick
  roll, a backbeat snare on 2 and 4. The band comes back on the following bar line under the theme's last note, the
  tonic an octave up on lead with the glockenspiel. It is quantised to the bar so the stop lands on the grid of any
  section (bar-safe), it has `always` (it plays over two live stingers), and it is spaced 16 beats. The game's own
  `extraLife` effect still sounds at once; the musical moment follows on the next bar line.
  - Two more variants were rendered for the operator (§12.10.5): **B** "twin-lead gallop" (a stop-time gallop on
    the tonic, the theme in thirds on lead and brass) and **C** "trumpet call" (a brass triplet call into a held
    triad on the octave, the choir entering on it). **A** ships; a pick of B or C is a data change to the stinger.
  - Before this direction a classic arcade arpeggio was drafted. It was dropped without shipping.
- **`challenge-fail`**, in the band's palette: a soft palm-muted ♭VI → V on the guitar with the lead sighing 6 → 5
  over it (the falling half step in minor). It names the miss without a minor-key thud or a sad trombone.
- **`gust`**, the wind's telegraph: a ride swell in sixteenths (velocity 40 → 90), strings on 1 and 5 re-bowed louder
  each half beat, a choir octave on the crest and a crash on its last eighth. It layers; it never changes the
  section.

**`break` and `always`** are new stinger fields, read by the player (`demon-score.js`):
- `break: [from, to]` (beats from the anchor): the playing section's notes are released over 60 ms at `from`, those
  scheduled inside never start, and none is scheduled until `to`. The section's grid runs on, so the band comes back
  on its own line. A move during the break is unaffected; the rest is by time.
- `always: true`: plays even when two stingers are live (like the life-loss accents).
- `over: [...]`: the sections the generator gates the stinger over (below). The player ignores it.

#### 12.10.4 Voices and zones

- **Layered peak.** `score_gen.lua` now gates each stinger against the sections its `over` names (`all`, `wave`,
  `bonus`, `song:<id>`). At each onset of the stinger (and at the end of its break), it adds the stinger's sounding
  voices (the score's voice rules, 0.5-beat release) to the section's peak, wherever in the section that peak falls.
  Inside a break the section counts 0, since it is released at the break. The limit is 32. The sector songs peak at
  28-29, so a stinger heard over them has at most 3 voices outside a break; the 1UP's pickup has 2 and its landing 2,
  and the c5 transformation (30) is its tightest case at exactly 32.
- **Zones.** `midi_stats.lua check` now prints each stinger's coverage in every key of the sections it layers over.
  Against the committed round-1 recipe, the new sections and `cargo`, `thunder`, `gust` and `challenge-fail` are
  fully covered. The 1UP's brass above F♯4 and its glockenspiel octave (84-89) wait for round 2. Against the
  `sample-bank` worktree's round-2 recipe (trumpet G4-D♯6, glockenspiel A♯5-F♯6; `plan/licences-round-2.md` §5), every
  new note is covered on desktop. On phones the 1UP's brass and bells stay synthesized, as every brass part above the
  horns does.

#### 12.10.5 The API (for `crosswind` and `bonus-challenges`)

| Want | Call | Where |
|---|---|---|
| Play the wind level's song | nothing: emit `bonusStart` with `variant: 'crosswind'` (the level id), as every bonus level does | `scoreBonusSongs` maps `crosswind` → `bonus-wind`; if the level's id differs, change that one line of `song-map.json` `bonusSongs` and regenerate |
| Lift into `B` | nothing: `bonusMidway` (the second wave) moves `bonus-wind` to `B` on the next bar line after the dwell | `SongDirector.onGameEvent` |
| End the level | nothing: `levelclear` moves to the sector song's `clear` on the next beat line; the travel bridge follows | `SongDirector.cue` |
| A gust telegraph, a 1UP, a failed challenge | from the model (pure Dart): `_queueGameEvent('musicAccent', {'name': 'gust'})` (or `bonusEvent(...)`); `MusicBridge.accentEvent` is the name | `MusicBridge.call` plays it if `scoreAccents` has the name |
| The same from Flutter code | `songs.accent('oneup')` on main.dart's `SongDirector` returns false for an unknown name; or `audioAccent('oneup')` | `SongDirector.accent`, `lib/services/audio.dart` |
| Start a bonus song by hand | `songs.playBonus('bonus-wind')` returns false (and moves nothing) for an unknown song, a non-bonus song, or when no sector song plays | `SongDirector.playBonus` |
| On the web | `demonAudio.accent(name)` returns the anchor time on the audio clock, or `null` (unknown name, spacing, two live stingers, music muted, no score) | `demon-score.js accent()` |

Names: `oneup`, `challenge-fail`, `gust`, `cargo`, `thunder` (and the older `dive`, `laststand`, `hatch`,
`reinforce`, `breakthrough`, `destroyed`, `gloat`, `respawn`, `riser`, `stab`, `glass`, `impact`, `toll`).
`cargo` and `thunder` are already wired (`bonusCrate`, `stormBait`). Don't also emit the raw string event of the
same name, or both paths fire (CLAUDE.md §3).

#### 12.10.6 Levels, previews and what is open

- **Trims** (`node tools/mix_meter/trim.mjs`, regenerated): `bonus-wind` measures -9.74 to -7.32 LUFS untrimmed across
  tiers 1-4, inside the score's range (top -4.97, floor -11.65, unchanged), so it gets trims of 1.6-3.3 dB like the
  sector loops. No other trim moved.
- **Against the radio** (offline renders through the shipped players, Full/Full, BS.1770): the radio sample
  (48 lines) is -16.48 LUFS. Each new accent's window (its first note to 2.5 s after its anchor) is -20.6 to
  -19.3 LUFS integrated, 2.8-4.1 LU under the radio, with a maximum momentary of -17.4 LUFS (the radio's is -8.9). The
  Crosswind clips are -20.1 to -19.8 LUFS, 3.3-3.6 LU under. The accents play through the music bus, so the speech
  duck lowers them under a line as it lowers the section.
- **Listening page** (operator, private): https://claude.ai/artifact/7YdEZo151RhG5j5DZ8bFeU, with the three 1UP
  variants first (A marked as the pick), the 1UP over Crosswind, both sections and the level's flow, and every
  accent in context. The renders are the synth voices (no bank yet), not a browser.
- **Open, for the operator's ear (task 10.6):**
  - the 1UP pick (A, B or C), and whether the stop-time should keep the drums playing under it;
  - Crosswind's fixed E minor between the D major and C minor worlds, or a transposition per world;
  - whether Supply Run should also get its own section later; it keeps the waves now.


### 12.11 Fidelity audit (`work/bank-fidelity`, 2026-11-18, task 9.12)

The operator's verdict on `?bank=1` (round 8): the sampled parts combine smoothly and follow the game, but "some of
them still sound low res, and some even sound worse than the MIDI", with "compression, low bit-rate, or background
noise", and "a bit of distortion there for the bass ... it dirties the whole soundtrack". Every step of the pipeline
was measured before anything changed, on the bank as built on `game` (d21b2653; the rebuild reproduced its sprites
byte for byte), and again after the fixes. The tools are committed, so any number here can be re-run:

- `lua tools/bank/bank_audit.lua sources | resample | cut | encode | bitrate | shift` (steps 1-4; `cut`, `encode`,
  `bitrate` and `shift` read the pre-encode sprites that `bank_build.lua --keep-pcm DIR` keeps);
- `node tools/mix_meter/bank_fidelity.mjs rates | render` (step 5: the shipped players rendered offline, with probes on
  every wave shaper and on the master limiter; `--web-root` renders an older tree, `--solo ROLE` a stem).

Per-zone tables and the commands are in `plan/render-runs/sample-bank.md` §8.

**Weakest step: the runtime bass drive.** The sampled bass's role level (3.7, set to match the synth's loudness) went
through the bass bus's `tanh` shaper, which was tuned for the synth's 0.7. Its input peaked at 2.5 instead of 0.8, and
the nonlinear residual across the stage (THD+N) was −7.6 dB, against −22.6 dB for the synth. That is the distortion the
operator heard, and since the bass carries the beat it dirtied the whole mix. Second: the sources themselves clip
(28 of the 40 Growlybass files hit 0 dBFS), so the bass was distorted twice. Third: the Opus rates (64 kbps mono,
96 kbps stereo) and the trims that cut cymbals and bells while they still rang.

| # | Step | Metric | Before (`game`) | After | Verdict and fix |
|---|---|---|---|---|---|
| 1 | Sources: format | rate, bits, channels | 168 zones from 44.1 kHz files: drums 16-bit FLAC (48), VCSL/VSCO 16-bit stereo WAV (42), Growlybass and the B&G guitars 24-bit mono WAV (78) | same | Adequate. None is below CD quality. |
| 1 | Sources: noise | quietest 50 ms after the onset (dBFS), SNR re the loudest 50 ms | drums −89 to −95 (16-bit dither), SNR 55-80 dB; guitars hiss at −50 to −57 dBFS before the onset; organ SNR 62-70; tenor trombone sustains SNR 45-61 (the noisiest sustained source); horns, trumpet, timpani, bells 79-108 | guitar pre-onset hiss cut (2 ms kept) | No library is noisy enough to drop. Trombone sustains are kept and named for the listening. No denoising: it would make them worse. |
| 1 | Sources: clipping | samples at full scale; true peak | bass staccato 20/20 files clip (1-71 samples, runs up to 36, up to +1.5 dBTP); bass `ff` sustains 8/10; nothing else | 710 samples rebuilt in 26 zones | **Fixed**: `declip: true` rebuilds each flat run by a cubic through its neighbours. ffmpeg's `adeclip` was rejected: it changed 1 818 samples of a clean file by up to 0.34. |
| 1 | Sources: DC | mean (dB re full scale) | ≤ −58 dB everywhere | ≤ −58 dB | Fine. |
| 1 | Sources: stereo | L/R correlation; loss of the (L+R)/2 fold | cymbals −0.2 to 0.1, organ 0.0-0.5, timpani −0.3-0.7, brass 0.2-0.9, bells 0.3-0.9 (spaced pairs); the mono fold lost 0.2-4.6 dB to comb notches | mono zones take one microphone (`pick`: left; the organ right, whose F#2 fundamental is missing on the left); cymbals stay stereo | **Fixed.** Brass and bells lost level with the sum's correlated part, so their role levels rose 1.0 and 2.2 dB. |
| 2 | Resample 44.1 → 48 kHz | image of a 19 kHz tone | −48 dB (ffmpeg default) | −119 dB | **Fixed**: 256-tap Kaiser (β 12) sinc. libsoxr is not in this ffmpeg build. |
| 2 | Onset | first sample re the zone's peak | up to −8.8 dB (glock), bass staccato −13 dB: `silenceremove`'s 20 ms RMS window started zones inside the attack (a click) | silence in every zone | **Fixed**: onset at −40 dB re the file's peak, 2 ms pre-roll with a raised-cosine fade-in (1 ms minimum). |
| 2 | Truncation | level at the cut re the loudest 50 ms | crash −17 to −19 dB, ride −21, open hat −18, bells −13 to −19, floor tom −22, bass sustain −10 to −24, guitar sustain −6 to −41 (20 ms fade) | crash −79 to −85, ride −71, open hat −62, bells −71 to −81, floor tom −56, bass sustain −39 to −53, guitar −33 to −107 | **Fixed**: trims crash 3.5 s, china 3.0, ride 2.5, open hat 2.0, toms 1.0, timpani 3.0, bells 4.0, glock 2.5, bass sustain 3.0, guitar sustain 2.5, with per-instrument raised-cosine fades (0.15-1.5 s). Held notes longer than their zone: bass 41 → 16, guitar 35 → 0. |
| 2 | Loop seams | jump at the loop point re the loop's 90th-percentile step | up to +6.0 dB (trombone), +1.9 (horn) | at most +0.7 dB (trumpet), most below −4 | Fine; the equal-power crossfade stays. |
| 3 | Normalisation | samples over 0 dBFS; dynamics | 0 overs; per instrument to −1 dBFS, so layers keep their relative levels; the clipped bass tops were normalised as flat tops | 0 overs; the declipped peaks now set the bass's gain | Linear, transparent. |
| 4 | Encode | Opus rate; magnitude SNR (STFT, phase-blind), median | 64 kbps mono / 96 stereo: bass staccato 24.3 dB, bass sustain 27.2, palm-mute guitar 26.8, snare 26.0, toms 27-30, timpani 29.1, organ 30.5, cymbals 8-16 | 96-160 kbps by instrument: bass staccato 37.9, bass sustain 35.3, palm mute 37.3, snare 37.1, toms 36-38, timpani 35.3, organ 37.1, cymbals 14-20 | **Fixed**: each instrument gets the lowest rate whose median magnitude SNR reaches 35 dB in the 64-160 kbps sweep (`bitrate`), at most 160; kick 96 (its SNR is flat above 96); cymbals 160 stereo (noise-like: their SNR is low at any rate). Opus kept the full −60 dB bandwidth of every zone (up to 21 kHz) at both rates: no codec low-pass. |
| 5 | Pitch shift | semitones from the zone's root, by notes; linear interpolation against a high-quality resample | drums 0; bass 90-94 % within ±1.5; guitars 88-89 %; organ 61 %; brass 37-54 %; timpani 42 % within ±1.5 and 49 % beyond 3 (to −7); interpolation error 34-60 dB magnitude SNR, the same at ±1.5 and ±7 | unchanged (no new pins) | The interpolation is not the weak step: its error sits below the codec's. The timpani's −6/−7 shifts change their timbre; that is for the listening. |
| 5 | Bass bus | wave shaper input peak; THD+N across it | synth 0.79, −22.6 dB; **sampled 2.47, −7.6 dB** | sampled bass: no shaper in its path (`bassSampled`, the same gains, linear) | **Fixed: the culprit.** The bass level re-matched +6 dB (3.7 → 7.35) by the median gap over five sections, now in a linear path. |
| 5 | Guitar amp | what it distorts | B&G DI recordings (pins doc §3): one amp, as designed | same | Not double distortion. |
| 5 | Gain staging | per-voice level × (0.35 + 0.65 v) × bus × trim × 0.55 × music level × master 0.65 → limiter (−1.5 dBFS) | master peaks −4 to −6 dBFS, 0 samples over 0 dBFS, the limiter never reduced (both banks, 6 sections) | the same | No master limiter change is needed; the buses are floating point, so the only clipping risk was the shaper. |

**The budgets, raised** (operator, round 8: "high res ... will be several MB, so we better justify that extra weight with properly enjoyable high res audio"):

| Bank | Zones | Sprites | Audio | Opus | Decoded, desktop | Decoded, phone tier |
|---|---|---|---|---|---|---|
| `game` (§12.9.7) | 168 | 8 | 187.1 s | 1 907 850 B | 40 934 400 B | 14 553 600 B |
| This build | 168 | 16 | 288.5 s | 5 050 218 B | 65 314 176 B | 22 675 200 B |
| Budget (recipe) | | | | 6 000 000 B | 72 000 000 B | 24 000 000 B |

- Opus grows by the rates (the larger part) and the longer trims. Sprites are now keyed by tier, phone class, rate
  and channels (`bank-1p128m.ogg`), so each instrument is encoded at its own rate.
- Decoded memory is the audio's resident cost: 48 kHz float, 192 KB a second mono. It grows with the trims only.
  `lib/game/perf/frame_budget.dart` has no audio budget, so the phone tier stays the lighter one: it loads only the
  phone sprites (22.7 MB), and the loader skips any sprite that would pass the budget, whose notes then play the synth.
- The sampled score's loudness is matched to the synth's again (bass, brass and bells re-measured; the medians of drums, organ,
  guitars and timpani within ±0.4 dB of their match) and the trims regenerated (`mix-trim.json`, §12.9.7's rule).

*The trims** (`node tools/mix_meter/trim.mjs`, regenerated): the synth block is byte for byte the one on `game`. The
`bank` block: `top` −4.60 LUFS (was −4.48), `floor` −15.43 (was −14.59), `k` 0.1847, `offset` −0.37 dB, 222 trims
from −0.4 to +8 dB. 16 trims hit the +8 dB cap (was 6): the arrival tails (`c1`-`c3`, `k`, `r`, `e`, `h`), the
bridge pivots, the coda and the credits song. The sampled arrivals measure about 1 dB quieter than before (`c1:arrival`
−15.76 against −14.84), so they end up to 1.1 dB under the synth's window, the coda's reprise 2.6 dB as before. A
higher cap or the arrivals' own levels is for the 9.7 listening.

**A/B listening page**: https://claude.ai/artifact/6xUiifLTpteD5txLxKqZss (private to the operator). Synth, old bank
and new bank, at one loudness per strip: the bass and the drums alone over `k:B@3` and `c1:core@4`, and the full mix
of six sections (`k:A@1`, `k:B@3`, `c1:core@4`, `h:A@4`, `k:clear`, `menu:overture`). Rendered offline through each
tree's own players, Opus 160 kbps stereo, 8.2 MB; the clips stay in scratch.

**A/B listening page**: https://claude.ai/artifact/7gMPsqL8Vkp2xQFbXouYmM (private to the operator). It plays the
bass alone (synth, clean DI, the three chains), bass and drums, and four full-mix sections, synth against bank, each
row at one loudness.

**Open, for the operator's ear:**
- The clean bass has the crest of a DI: −8 dBFS peaks at −25.9 LUFS alone, against the synth's −17 at the same
  loudness. If it sounds too spiky in the mix, a bus compressor (gain, not saturation) is the next step.
- The timpani play half their notes 3-7 semitones below the lowest pinned drum; a lower drum would need new pins.
- The tenor trombone sustains are the noisiest kept source (SNR 45 dB).
- The phone tier now decodes 22.7 MB (was 14.6).
- `BANK_DEFAULT` stays off.

### 12.12 The sampled bass's metal chain (`work/bass-tone`, 2026-11-18, task 9.13)

Operator, after the §12.11 A/B: the clean bank's bass "sounded like the metallic heavy strings of the bass without any
electronic distortion at all ... the old midi synth is the fully postprocessed bass play with some distortion ... Our
audio pipeline is missing the right amount of distortion". Then: "even the old bank was really good, it was just
missing the postprocessing". §12.11's source fixes stay (declipping, rates, trims, the clean bus). This adds the
missing post chain on the sampled bass bus only. Research and sources: `plan/bass-tone-research.md`. Candidates, the
pick and the measurements: `plan/render-runs/sample-bank.md` §9.

**The problem, measured** (`bass_tone.mjs stages`): the DI's fundamental octave sits 20-25 dB under its 250 Hz-4 kHz
content, and its crest is 21 dB, against the synth's 8 dB. Bright, spiky strings with no weight.

**The chain** (`bassTone()` in `web/audio/demon-score.js`, built when the bank is prepared, so it never exists with
the bank off), in signal order:

| Stage | What | Classic (the pick) |
|---|---|---|
| `input` | gain into the chain: the DI's peak (4.9 on the bus) to about 0.9 | 0.18 |
| `comp` | DynamicsCompressorNode before the split, so its 6 ms look-ahead delays both bands alike; hard knee (the meter models only that); then a mono fold (the node always outputs stereo) | −16 dB, 4:1, 5 ms, 120 ms |
| split | Linkwitz-Riley at `split` Hz: two Butterworth sections per side (`Q = -3.0103`: Web Audio reads a pass filter's Q in dB), or LR2 (`order: 2`, the low band inverted). Sums flat within 0.01 dB undriven | 200 Hz, LR4 |
| `low` + `lowEq` | the clean band, given the weight the DI lacks; delayed by the engine's measured WaveShaper latency (`shaperLatency()`: an impulse through an OfflineAudioContext once; Chrome 156: 128 frames at 2x, 192 at 4x), so the bands meet in phase | high-pass 28 Hz, peak 65 Hz Q 0.9 +9 dB |
| `pre` | EQ into the drive | peak 1 kHz Q 0.8 +4 dB |
| `shaper` | `tanh(d(x + b x²)) / d`: unity gain for small signals, so a hotter input only saturates; input under full scale by construction (the meter checks it); oversample 4x (2x on phones); a 30 Hz high-pass removes the bias's DC | d 10, b 0.08 |
| `cab` | biquad cabinet (no convolver: the cheaper node) | 2 × low-pass 3.5 kHz, peak 2.6 kHz Q 2 −3 dB (the guitars' presence slot) |
| `grind` | the driven band's level re the clean band it replaces | 1.0 |
| `post` | EQ on the sum, leaving 400 Hz to the bass (the guitar cabinet notches there) | peak 250 Hz −2 dB, peak 1.2 kHz +3 dB |
| `output` | the loudness match to the synth bass (median of five sections, trims off) | 6.12 |

The parameters are data: `roles.bass.tone` in `art/music/bank/recipe.json`, copied by `bank_build.lua` into
`bank.json`. The candidates live in `art/music/bank/bass-tone.json` (`pick` names the one in the recipe), and
`tools/mix_meter/bass_tone.mjs` measures them (`sine`, `stages`, `match`, `clips`). `toneSpec()` clamps every value:
drive 1-30, input at most 1, output at most 16, filter gains ±12 dB and so on. `tone.phone` overrides the tone on the
phone tier (`phoneClass()`). The classic's phone variant is LR2 with 2x oversampling, measured within 0.34 dB of the
synth.

**Results** (classic):

- Bass alone: within 0.8 dB of the synth in each of five sections (median gap 0.0 dB; 0.34 dB on the phone tier).
- Peaks: the bass now peaks at the synth's level, −17.5 to −18.4 against the synth's −17.4 to −18.0 dBFS. The clean DI
  peaked 9 dB over the synth at one loudness.
- Shaper on the music: input peak at most 0.76 (the shared shaper took 2.47 before §12.11), nonlinear residual −7 dB
  on the driven band only.
- Driven band on sines (220 and 440 Hz): THD+N −9 to −13 dB at the shaper.
- Whole chain on sines below the split: under −46 dB, so the fundamental stays clean.
- Full mix with the bank: master peaks −3.4 to −5.7 dBFS, no samples over full scale, and the limiter never reduces.
  The synth renders byte for byte as before (`test-worker/bass-tone.test.mjs`).

CPU, Chrome 156 (one desktop core in real time):

| Chain | CPU |
|---|---|
| desktop chain | about 0.8 % |
| phone chain | 0.59 % |
| for comparison: one guitar bus | 0.50 % |
| for comparison: the synth bass bus | 0.25 % |

**Drums: unchanged.** The sampled kit's peak-to-loudness ratio is 17-19 dB, against the synth kit's 12-17. In the
full mix the master limiter never reduces gain. The operator hears them as fine clean, and compression would flatten
dynamics he likes. A parallel drum-bus compressor is the next step if a round asks for punch.

**Open, for the operator's ear:** the pick among the three, the amount of grind (`grind`, `drive`), and whether the
6 ms compressor look-ahead is audible against the kick (we expect not).
