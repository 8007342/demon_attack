# Design: adaptive-soundtrack

Research and sources: `plan/soundtrack-research.md` (§ numbers below as R§). This file records decisions. Repo facts
name their file. The pilot's ledger: `plan/render-runs/soundtrack-pilot.md`.

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
- **Not in this change:** the radio, the effects, the credits list, any gameplay or calibration change.

## 2. Architecture: a hybrid (R§1.2)

| Layer | Mechanism | Prior art | Status |
|---|---|---|---|
| Sections | whole-bar files on one grid per song; a transition table moves between them on the next bar (or beat), into the destination's start or the same position, with a cut, a fade or a bridge | horizontal re-sequencing (R§1 A1, A3–A5) | core nodes now |
| Intensity inside a section | variants of one section that share its bars (`v1` calm, `v2` peril); switching keeps the position | same-position transitions (A1 `SAME_POSITION`) | core nodes now (as separate takes); one arrangement needs #1103 |
| Layers | stingers (accents), the dive layers and the power layer (HPSS cuts of our own mixes), a riser; later the sampled drum and bass bed | vertical layering (A2), stingers (A5) | stingers and cuts now; beds #1103 |

The model is the engines' common one (R§1.1): sections plus a transition table keyed on game state, quantised to
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
- Ogg Opus decodes on Safari only from 18.4 (R§3 W3). No fallback format (operator, 2026-11-17: "No fallback format, this project is already asset heavy, no need to duplicate assets. Just keep the latest, unless the older one is signifficantly smaller in size."): older iPhones get the MIDI fallback.

### 5.3 Loading

- On a song's start the player fetches all its files and decodes the current section and its graph neighbours
  first; the next song's `arrival` and bridge are fetched (not decoded) during the current song's last section.
- **Decoded memory cap: 48 MB** (≈ 125 s of stereo PCM, R§3 memory arithmetic). Least recently used, unreachable
  sections are evicted first; the current section and its neighbours never are.
- A section that has not decoded in time is skipped: the current section keeps looping and the move waits for the
  next bar. If nothing of a song decodes, the MIDI fallback plays (the modified "Adaptive MIDI soundtrack").

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
