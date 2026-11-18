# Design: demon-choir (the brood choir)

Research: `plan/demon-choir-research.md`. Pilot run ledger: `plan/render-runs/demon-choir.md`. This builds on the
MIDI-first score and its sample bank (`openspec/changes/adaptive-soundtrack` design §11, §12.3, §12.9).

## 1. Goals and limits

- Wordless demon voices become **part of the score**: a low doom choir under the carrier and the battle sections,
  grunts on the downbeats, and the dive war cries landing on the music's grid, in its key.
- They combine at runtime like the rest of the score: they are notes in the section MIDI, played from bank zones, and
  stingers in the section's key. Nothing is a rendered mix.
- **Off by default.** The choir rides the bank switch (`adaptive-soundtrack` §12.9.7). With the bank off, nothing
  new is fetched or scheduled, and the synth score is note for note as before.
- **Only admitted material.** That means our own formant synthesis plus ACE-Step 1.5 XL turbo in the studio (MIT,
  installed, cleared for music pilots). No model download, no TTS (blocked on the register and #1121), and no new
  sample library (each needs a pin and the register's admission; research §5-§6).
  - Round 9: epic-choir and 272 Merry Orks are pinned and cleared; they feed a candidate (§11), not the active choir.

## 2. Sources: why two

| Material | Source | Why |
|---|---|---|
| `brood` doom choir | `tools/brood_choir/brood.lua render`: our Klatt-style cascade formant synth, 8-voice ensemble, Rosenberg pulses with period doubling (the growl) | Zones need one steady pitch per sample. ACE-Step sings chords over a drone (research §1), so its takes cannot be cut into zones. The synth is pitch-exact (12 zones, all within 0.14 semitone), deterministic and ours. |
| `grunt`, `warcry` | ACE-Step 1.5 XL turbo takes (`art/workflows/music/campaign-text-headroom.json`), cut by `brood.lua cut` | Shouts are transients and formant sweeps, which the model does convincingly. Their pitch is loose anyway: the sampler pitches them to the music. |

The recipe (`art/music/choir/brood.json`) holds the synth's parameters, its zones (vowel, note, seed) and the picks
(take, start, end, high-pass). The prompts, seeds and measurements are in the run ledger.
- The synth renders are byte-identical on a rerender, and the manifest checks that.
- ACE-Step re-renders are not byte-identical (GPU). Its raws stay in `~/.cache/tillandsias-project/demon-choir/raw/`,
  and the shipped sprite is the record (CLAUDE.md §5).

**Replacing them later.** The recipe's axes (vowel × pitch, syllable × round robin) are those of the candidate
libraries:
- epic-choir's B part for `brood` (CC BY 4.0, ah/oh, A2-F4);
- 272 Merry Orks (CC0) for `grunt`;
- Dia's `(groans)`/`(screams)` for `warcry`.

Once one is admitted, its files become manifest rows and the zones change. The score and the runtime do not.

## 3. The score

- **Tracks** (`song-map.json`):
  - `brood` (role `brood`, channel 16, GM program 54 "Voice Oohs" for auditions);
  - `grunts` (role `grunt`, channel 16);
  - `cries` (role `warcry`, channel 16). It appears only in the `warcry` stinger.
  - MIDI has 16 channels and the score used 15. The player keys tracks by name, so the three can share one channel.
- **Masks:**
  - the shared masks add `grunts` at tiers 3-4 and `brood` at tier 4;
  - the `core` set adds `brood` at tiers 2-4 and `grunts` at tiers 3-4.
  - A track with no notes in a section costs nothing.
- **Helpers** (`tools/score/arrange.lua`):
  - `A.drones(s, track, harmony, floor, v, b0, b1, rootOnly)`: the root and fifth (or the root alone) of each harmony
    part, from `floor`.
  - `A.grunts(s, track, harmony, floor, every)`: a shout on every downbeat (velocity 120) on the bar's first chord
    root, and on beat 3 of every `every`-th bar a softer one (104).
  - `brood` is a pad role for articulation, so a pad note ends 0.5 beat before the next starts.
  - Both are written **last** in their section, so the section's other humanised velocities (one RNG per section)
    stay as they were. Only `c1/core.mid` and `k/B.mid` changed.
- **The pilot's sections:**
  - **`c1:core`** (F minor, 190 BPM): root drones from F2, "oh" (velocity 72) in bars 1-4 and "ah" (102) in bars
    5-8.
    - The drones are root only and the core has no grunts. Its peak was 29 voices, and the 1UP stinger adds 3, so
      root drones (+1) are all that fit under 32.
    - The core's shouts are the dive war cries.
  - **`k:B`** (Krybor's answer, E minor, 170 BPM): root-and-fifth "oh" drones from E2 (velocity 66), and grunts on
    every downbeat plus beat 3 of bars 4 and 8, on the bar's root from E2. Peak 27 voices.
- **The war cry stinger:** `warcry` is quantum 0.5 (an 8th), spacing 8 beats, `speech: yield`, `over: all`, with one
  note `{ t: 0, len: 2, v: 120, track: cries, deg: 1, oct: 3 }`: the tonic in octave 3 (F3 = 53 in F minor, E3 = 52 in
  E minor). The accent of the same name is in `accents`, so `scoreAccents` (Dart) lists it.

## 4. The bank (`tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json`)

- **Builder changes** (small, shared with the first bank):
  - a recipe `name` (default `bank`) names the JSON (`choir.json`) and prefixes the sprites (`choir-4d128m.ogg`
    and its kin, keyed by tier, rate and channels since bank-fidelity), and a rebuild replaces only its own sprites;
  - a recipe `src` names its source folder (`~/.cache/tillandsias-project/demon-choir/src`);
  - `generatedComment` is the output's comment.
  - `bank.json` is unchanged byte for byte: `name` is absent there.
- **Manifest:** `art/music/bank/choir.manifest.tsv`, written by `brood.lua manifest`, gives each source's bytes and git
  blob sha1, like the pins. `--fetch` does not apply: the sources are made locally.
- **Instruments:**

| Instrument | Zones | Axis | Root | Pitch check | Trim, loop |
|---|---|---|---|---|---|
| `brood` | 12: oh/ah × C2, F2, A#2, D#3, G#3, C#4 (stretch ±3: A1-E4) | velocity: oh 1-84, ah 85-127 | file name | **strict** (all within 0.14 semitone) | 2.6 s, loop from 0.9 s with a 0.4 s crossfade, release 0.35 s |
| `grunt` | 8: syllables a-d × 2 round robins | velocity: a 1-80, b 81-96, c 97-110, d 111-127 | nominal C3 (48); range D#2-G3 | none (shouts; a take's drone reads under several) | 0.45 s, a hit |
| `warcry` | 3: cry_a F3 (2 round robins), cry_b A3 | pitch | measured (173.6/174.5 Hz, 220.1 Hz) | report | 1.8 s, a hit |

- **Roles:** `brood` level 1.2, `grunt` 2.1, `warcry` 5.3, each `cover: full`.
  - `brood`'s solo loudness is matched to the synth choir and organ pads (about −38 to −41 LUFS solo at tier 4).
  - The grunts' momentary maximum is set 3 dB under the lead's (ledger §5).
  - The war cry sits about 8 dB under the band at its peak, measured by subtracting a render without cries (ledger §5).
- **Budgets** (its own): 800,000 B of Opus (400,000 before §4.1), 9,000,000 B decoded on desktops, 0 on phones.
  - Built (round 8, §4.1): 756,366 B of Opus in 3 sprites (128 and 160 kbps mono) and 7,677,400 B decoded; the pilot built 380,958 B in 2 sprites at 64 kbps.
  - Every zone is normalised per instrument to −1 dBFS peak, as the first bank's are.
- **Phones:** no choir. The first bank's phone tier already uses 14.55 of its 16 MB, so the choir is desktop-only.
  This is an open question (§10).

### 4.1 Rebuilt to the bank-fidelity standard (round 8)

`bank-fidelity` (adaptive-soundtrack design §12.11) set the standard for every bank: clean sources, no clipping, an
honest bitrate. The choir was re-measured with its tools (`bank_audit.lua sources | cut | encode | bitrate`, run on the
choir's own sources and `--keep-pcm` sprites) and rebuilt from the cached sources (no new download, no new render):

| Step | Measured | Verdict |
|---|---|---|
| Sources | 23 files, 48 kHz 32-bit float mono; 0 clipped samples; peaks −3 dBFS (brood), −17 to −6 (shouts) | No declip, no mono pick, no resample needed. |
| Encode rate | median magnitude SNR, 64/96/128/160 kbps: brood 29.7/33.4/37.2/41.0 dB; grunt 26.1/29.1/32.2/34.5; warcry 24.2/27.4/31.0/33.8 | §12.11's rule (lowest rate reaching 35 dB, at most 160): **brood 128, grunt 160, warcry 160** (was 64 for all). The shouts are noise-like, like the cymbals, so they stop at the cap. Opus kept each zone's −60 dB bandwidth (no codec low-pass). |
| End of the hits | level 50 ms before the end fade, re the loudest 50 ms: grunt −15 to −26 dB, warcry −17 to −28 (20 ms fade) | **Raised-cosine end fades**: grunt 0.15 s (now −25 to −31 dB, bounded by the 0.4 s picks), warcry 0.6 s (−49 to −61). |
| Loops | brood seam jumps −22 to +4.8 dB re the loop's 90th-percentile step (median −5.8) | Kept: the equal-power crossfade, as §12.11 kept the first bank's. |
| Buses | grunt and warcry on the `voice` bus (gain, room send), brood on the pad bus | No wave shaper in any choir path: §12.11's bass-bus fault does not apply. |

Built: 23 zones in 3 sprites (`choir-3d160m.ogg`, `choir-4d128m.ogg`, `choir-4d160m.ogg`), 40.0 s, **756,366 B of Opus**
(budget raised 400,000 → 800,000 B, as §12.11 raised the first bank's for the rates) and 7,677,400 B decoded on desktops
(budget 9,000,000, unchanged: decoded size follows the trims). Still desktop-only. The role levels are unchanged (the
rate does not move loudness); the trims are regenerated (`mix-trim.json`, both blocks).

## 5. The runtime (`web/audio/demon-score.js`)

- **Loading:** while the switch is on, `bankSpec()` fetches `bank.json` and (on desktops) `choir.json` in parallel.
  - `joinBanks(main, choir)` appends the choir's instruments, roles, zones and sprites after the first bank's and adds
    the budgets.
  - Without `bank.json` there is no bank: the choir never plays alone.
  - The sprites load one at a time in order, so the choir comes last.
- **Sampled-only roles** (`SAMPLED_ONLY = brood, grunt, warcry`):
  - `scheduleNotes` skips their tracks unless the section's track is sampled (bank on and covered);
  - `play()` returns at once for them without the bank;
  - `makeVoice` returns null instead of a synth voice when the zone has not decoded. `play()` then starts nothing and
    steals nothing (the cap's victim is chosen only once a voice exists).
- **Buses:**
  - `brood` goes to the pad bus: dry plus the long room, like the synth choir;
  - `grunt` and `warcry` go to a new `voice` bus, gain 0.8, with an 0.18 send to the room.
  - Every bus feeds the score's output, which feeds demon-audio's music bus, so the music level, the mute, the
    section trims and the speech duck all apply.
- **Voice priority:** `brood` is stolen first, like pads. `grunt` and `warcry` go with the leads.
- **Stingers:**
  - a stinger whose notes are all sampled-only returns null without the bank;
  - a stinger with `speech: yield` returns null while `host.speaking()` reports a radio line holding the speech duck.
  - Otherwise it is an ordinary stinger: anchored on the next multiple of `quantum` beats, transposed to the section's
    tonic and mode, with `spacing` beats between two.
- **State:** `state.score.bank.choir` is true once the choir has joined.

## 6. API

### 6.1 Game to music (Dart)

- **Event:** `diveCry`, a structured `GameEvent` (`MusicBridge.diveCryEvent` = `GameEventNames.diveCry`, round 8).
  `fang-and-wings-comms`' `GameEventObserver` raises it from a `divePrep` its `DiveCryGate` lets cry; its design §API
  is the authority for the name and data.
  - Data: `diveIn` and `tellIn` (seconds from now to the dive's start and to its tell) time the grunt; the rest
    (`rank`, `species`, `intensity`, `mark`) is unused for now (open question 4).
  - **Timing (round 8):** the grunt lands on the dive's start, `now + diveIn`, snapped to the nearest line of the
    stinger's grid (an 8th, so a beat or half beat) when one is within 0.3 s (the radio's dive tolerance); else on the
    tell, `now + tellIn`; never before now + the score's margin. Without `diveIn` it plays on the next 8th as before.
  - It reaches the music through `GameEvents.listen` → `MusicBridge.call`, like every structured event. It is not a
    raw `model.events` string, so `audioSfx` never sees it, and the radio and the music each hear it once.
- **Mapping:** `MusicBridge.diveCryEvent` → `onAccentAt(MusicBridge.diveCryAccent, diveIn, tellIn)`, that is
  `audioAccentAt('warcry', …)` → `demonAudio.accent('warcry', inSeconds, fallbackIn)`; without `diveIn`,
  `onAccent('warcry')`.
- `SongDirector.accent('warcry')` works too: `warcry` is in `scoreAccents`.

### 6.2 JavaScript

| Call | Returns | Notes |
|---|---|---|
| `demonAudio.accent('warcry', inSeconds?, fallbackIn?)` | the anchor time (audio clock), or `null` | round 8: with `inSeconds`, the grid line nearest `now + inSeconds` within 0.3 s, else `now + fallbackIn`. | `null` when: the bank is off; the stinger played less than 8 beats ago; a radio line is speaking; two stingers are live; the music is muted. |
| `demonAudio.setScoreBank(on)` | the new state | unchanged; also switches the choir |
| `demonScore.create(host)` | | `host.speaking()` (new, optional): true while the speech duck holds; demon-audio passes `duckDepthAt(now) > 0` |
| `state.score.bank.choir` | boolean | the choir joined the bank |

### 6.3 Data

- **`song-map.json`:**
  - the tracks `brood`, `grunts`, `cries`;
  - the stinger keys `speech` (`yield`) and sampled-only stingers, documented in `stingers.comment`;
  - the accent `warcry`.
- **`choir.json`:** the bank schema (`demon-attack.bank/v1`) plus `name: "choir"`. Its roles are `brood`, `grunt`
  and `warcry`, each `cover: full`.
- **Recipe JSONs:**
  - `art/music/choir/brood.json` (`demon-attack.brood-choir/v1`): `synth` (seconds, voices, detune, onset, attack,
    release, shimmer, breath, glottis, vibrato, jitter, tractScale, presence, growl per vowel, vowels, zones) and
    `picks` (name, group, take, start, end, fadeOut, highpass);
  - `art/music/bank/choir-recipe.json`: the bank recipe schema plus `name`, `src`, `generatedComment`.

### 6.4 Commands

```sh
lua tools/brood_choir/brood.lua all          # render the synth zones, cut the picks (needs the raws), write the manifest
forge-guard run -- lua tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json   # choir.json + sprites
lua tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json --f0-report          # the pitch table
lua tools/score/score_gen.lua && lua tools/midi_stats.lua check
forge-guard run -- node tools/mix_meter/trim.mjs                                             # both modes' trims
```

## 7. Mix rules

- **The radio outranks the cries.** A cry goes through the music bus, so the speech duck lowers it like the rest of
  the music (`mix-balance`). It also yields entirely while a line speaks, so a musical "HRAAA" never masks a radio war
  cry.
- **Rate:** at most one cry per 8 beats (2.5 s at 190 BPM, 2.8 s at 170 BPM). The stingers' rule of at most two live
  stingers still applies.
- **Levels:** the role levels of §4 are a starting point by measurement, as the first bank's were. The trims of both
  modes are regenerated (`mix-trim.json`).
  - The synth block is unchanged: the synth plays no choir notes.
  - The bank block moves where the choir sounds: `c1:core@2-4` and `k:B@3-4`.

## 8. Coordination

- **`fang-and-wings-comms`** (merged in round 8): its event is `diveCry`; the grunt follows its §API timing (§6.1).
  Its radio war cries keep priority by §7.
- **`bank-fidelity`** (merged in round 8): its §12.11 standard applies to the choir's sprites too; rebuilt (§4.1).
  Before:
  - each zone was peak-normalised to −1 dBFS, encoded at 64 kbps mono like the first bank, and its source
    rate is 48 kHz.
  - The ACE-Step cuts are from 48 kHz FLAC, and their bandwidth is the model's (ledger §2).

## 9. Gates and tests

- `lua tools/midi_stats.lua check` reads `choir.json` (else the choir recipe's plan) next to `bank.json`. The brood,
  grunt and war-cry notes must all be covered (`cover: full`); the stinger is checked in every key.
- `test-worker/music.test.mjs`:
  - the choir plan: roles, desktop only, the vowel axis, and the gate;
  - bank off: no fetch, no cry;
  - bank on: the choir loads last; brood and grunt zones play; grunts sit on beats 1 and 3, pitched to the bar's
    root; the cry lands on an 8th in key; the rate limit; the yield to the radio and its return.
- `test-worker/score.test.mjs`: the player's size limit goes from 56 to 60 KB raw (57.5 KB; gzipped 18.2 KB of 20).
- `test/audio_toggles_test.dart`: `diveCry` → `warcry`, and `warcry` is in `scoreAccents`.

## 10. Open questions

1. The operator's ear:
   - does the formant choir read as a demon choir, or as a synth pad?
   - are the ACE-Step grunts clean enough (a low drone of the take sits about 18 dB under them, high-passed at 100 Hz)?
2. Phones: no choir on phones. Should it get a phone tier once `bank-fidelity` settles the first bank's budget?
3. Which sections carry the choir beyond the pilot's two? The other carrier cores (tours 2-5), the collapse, the
   approach, and every world's battle section?
4. Should the cry follow the dive's demon (pitch by rank, or a cry per speaker) once `fang-and-wings-comms` defines its
   data?
5. Should epic-choir and 272 Merry Orks go to the register (research §8)? Both are pinned (`plan/choir-pins.md`); the
   candidate built from them is §11.
6. Ship the real candidate (§11.6)? It is recommended, but it measures 0.5 dB below the approved brood's codec SNR, so
   it is not active. It needs the operator's listen.
7. The ACE-Step war cries exist only as cuts in the cache and as the shipped sprite (§2). A rebuild of either recipe
   after a forge reset would need the cries re-rendered (not byte-identical) or cut back out of the shipped sprite.

## 11. Real samples: an A/B candidate (`work/choir-real`, 2026-11-18)

The operator approved the brood choir as built (§4.1: formant "oh"/"ah", ACE-Step grunts and war cries) and approved
pinning epic-choir and 272 Merry Orks (`plan/choir-pins.md`; the coordinator checked both pins on the host and confirmed
VocalSet's CC BY 4.0). This section builds a **candidate** from the real samples. It does not replace the approved choir
unless the candidate measures at least as clean, and it does not (§11.6). Numbers and commands: `plan/render-runs/demon-choir.md` §10.

### 11.1 Fetch and verification (`tools/brood_choir/pins.lua`)

- `lua tools/brood_choir/pins.lua fetch` reads `plan/choir-pins.manifest.tsv`. It refuses a file, deletes it and exits 1
  on any mismatch:
  - each git blob (6 epic-choir docs, 3 Merry Orks docs, 10 Merry Orks samples) is checked by size and `git hash-object`;
  - epic-choir's release zip is checked whole (173,859,746 B, sha256 `3f78e9b5…b3002f`) **before** any member is read.
    It lives in `~/.cache/tillandsias-project/choir-src/`, never in the repo or the checkout;
  - each of the 10 members is extracted alone by name (`unzip -p`, so no path from the zip reaches the disk) and checked
    by size and a CRC32 computed in Lua, independently of unzip.
- Result: all 30 rows matched. The members' git blob sha1s are pinned in `art/music/bank/choir-real.manifest.tsv` for the
  builder, whose own check is the blob. `pins.lua verify` re-checks without fetching.

### 11.2 Sources as measured

| Source | Format | Clipping | Noise | Stereo | Pitch |
|---|---|---|---|---|---|
| epic-choir B `f`, oh/ah × A#2 D3 F#3 A#3 D4 | 44.1 kHz 16-bit stereo, 6.9-8.3 s; 107-281 ms of digital silence before the onset (the SFZ's `offset=3528`) | 6 of 10 files reach full scale (15-46 samples): **declipped**, 85 samples in 6 zones | head −55 to −62 dBFS, the approved synth's −54 to −62 | L/R correlation 0.2-0.44; the mono fold loses −1.6 to −2.3 dB, what decorrelation predicts (10·log10((1+r)/2)); 1/3-octave comb s.d. 0.9-1.5 dB | strict check: every zone within ±0.46 semitone of its SFZ keycenter |
| Merry Orks misc (ugh, oh, hey, argh × rr1-2) | 44.1 kHz 24-bit mono, 0.70-1.41 s | none; peaks −5 to −11 dBFS | the word ends in silence 64-98 dB down (ACE-Step cuts: 15-25 dB, the take's drone) | mono | unpitched shouts (as the ACE-Step ones) |

### 11.3 Brood: epic-choir's B part

- **Mono:** the sum, not one microphone. §12.11 took one microphone because spaced pairs comb-filter when summed. This
  hall is decorrelated seats, not a spaced pair. Its fold loss is level, which normalisation restores, and the sum
  measures cleaner than the left channel: encoded SNR 36.4 against 36.1 dB, loop seams median −13.4 against −6.6 dB.
- **Rate:** the 35 dB rule gives 160 kbps (64/96/128/160: 26.7/31.0/33.8/36.4 dB). Encoded at 36.7 dB with DC removed.
- **DC:** the sums carry −55 to −67 dB of DC (re full scale), against the standard's −58. The builder's new `dc: true`
  subtracts each zone's mean (off by default; `bank.json` and the approved `choir.json` rebuild byte for byte). The DC
  now measures −78 to −111 dB.
- **The low drones** (E2, F2: 5-6 semitones under A#2). Measured on tape-shifted renders of each note E2-A#2, by the
  level-normalised 1/3-octave envelope distance (100 Hz-8 kHz) between neighbouring semitones:

| Option | Steps E2→A#2 | Seam | Budget |
|---|---|---|---|
| **Shift A#2 down** (stretch 6) | 2.0-5.3 dB per semitone | none | fits |
| Two formant zones C2, F2 under G#2 (the hybrid) | 4.8-12.6 within the synth | **21.7-23.4 dB** at G2→G#2 | 962,800 B Opus, 9.22 MB decoded: **over** |

  Pick: **the shift**. The timbre darkens gradually (E2 sits 12 dB from the unshifted A#2) instead of changing instrument
  at one key. The hybrid is also over both budgets. It stays on the listening page for the ear.
- **Level:** at the approved role level (1.2) the real brood measured 4.4 dB (k:B) and 5.3 dB (c1:core) quieter. Level
  **2.1** matches it (−37.46/−41.36 LUFS solo against −37.93/−40.88).

### 11.4 Grunts and war cries: Merry Orks

- **Pitch:** the voice is female. `brood.lua cut` pitches each pick tape-style (relabelled rate, the 256-tap sinc), so the
  formants move down with the pitch. Spectral centroid as cut, median: ACE-Step 760 Hz; Orks at −4: 900, **−7: 740**,
  −12: 535. Both are then played from the nominal root C3 down to the bar's root (E2-D3).
  - Pick: **−7**, the approved grunts' brightness at the same runtime shift.
  - −12 doubles each grunt's length, and its ends measure worse (median −31.9 dB against −41.7).
- **Trim:** 0.7 s with a 0.3 s raised-cosine fade. The ends are −26 to −70 dB (median −41.7), against the approved −25 to −36
  (median −28.4). A 0.6 s trim left −15 to −45; 1.0 s goes over the Opus budget.
- **Level:** 2.8, which puts the momentary maximum at −30.0 LUFS, the approved grunts' value (3 dB under the lead).
- **War cries: the ACE-Step cuts stay.** Merry Orks' growled vowels (`a_from_car_rr1`, `o_from_pot_rr1`, −7) were cut
  and measured as cries:
  - their ends are −36.6 to −38.9 dB (ACE-Step −49.5 to −61.3);
  - they have one round robin per cry instead of two;
  - they carry no stable pitch (the f0 report reads 63 and 182 Hz);
  - they encode at 32.5 and 37.2 dB.
  They do not clearly beat the approved cries, so they are not in the recipe (their cut is in the ledger).

### 11.5 The candidate (`art/music/choir/real.json`, `art/music/bank/choir-real-recipe.json`)

- **Same as the approved:** the `name` (`choir`), roles, budgets and runtime. Building it replaces `web/audio/bank/choir.json`
  and its sprites behind the same bank switch; `BANK_DEFAULT` stays false.
- **Built:** 21 zones in 2 sprites (`choir-3d160m.ogg` 97,009 B, `choir-4d160m.ogg` 660,882 B), **757,891 B of Opus** and
  7,203,768 B decoded on desktops (budgets 800,000 and 9,000,000). The approved choir is 756,366 and 7,677,400.
- **Coverage:** `midi_stats.lua check --choir` covers it note for note: brood 29, grunt 10, warcry 8 keys.
- **Determinism:** a second `brood.lua cut` reproduced every pick's blob, and a second build reproduced both sprites' sha256.
- **Credits:** `tools/generate_credits.lua` turns the two "coming" rows live in the same build that ships them. A row goes
  live once `web/audio/bank/choir.json` names its source (`thepok/epic-choir`, `local/orks-picks`), and the epic-choir row
  keeps the change note and licence link CC BY 4.0 asks for. The approved choir names neither, so both rows stay "coming"
  and `assets/credits.json` is unchanged but for its `authors_commit`.

### 11.6 A/B and the verdict

| Instrument | Approved | Real | Cleaner |
|---|---|---|---|
| brood: encoded magnitude SNR, median | 37.2 dB at 128 kbps | 36.7 dB at 160 kbps | approved, by 0.5 dB (both above the 35 dB rule) |
| brood: −60 dB bandwidth | 3.2-3.8 kHz | 7.8-10.0 kHz | real |
| brood: loop seam, median / max | −5.8 / +4.8 dB | −5.5 / −0.5 dB | real |
| brood: clipping, DC | none, ≤ −85 dB | none after declip, ≤ −78 dB | tie |
| grunt: background under the shout | 15-25 dB down | 64-98 dB down | real, by about 40 dB |
| grunt: encoded SNR at the 160 cap | 34.5 dB | 32.9 dB | approved, by 1.6 dB |
| grunt: end SNR (source floor and codec together) | ≈ 19 dB | ≈ 33 dB | real, by about 13.6 dB |
| grunt: level at the end, median | −28.4 dB | −41.7 dB | real |
| warcry | ACE-Step | the same cuts | tie |

- **Recommendation: the real candidate** (epic-choir brood, Merry Orks grunts at −7, ACE-Step war cries). It has a real
  ensemble with 2.4 times the bandwidth, one timbre from E2 to D4, smoother loops, and grunts cleaner end to end.
- **It does not ship active.** The brood encodes 0.5 dB below the approved synth, so the candidate does not measure at
  least as clean on every count. The approved choir stays in `web/audio/bank/`, and the recipe, manifest and tools are
  committed.
- **Listening page:** https://claude.ai/artifact/BRp5LaDJBJYiiQAG7ioU35. It has five strips: the brood solo over k:B and
  c1:core (approved, real, hybrid), the grunts with drums (ACE-Step, Orks −7, Orks −12), the war cries over k:B (approved,
  real, Orks growls) and the carrier core mix. Each strip is at one loudness.
- **To ship it** after a listen:

```sh
lua tools/brood_choir/pins.lua fetch                                   # verified pins into the cache
lua tools/brood_choir/brood.lua cut --recipe art/music/choir/real.json # the Orks picks (the ACE-Step cries must be cut already)
forge-guard run -- lua tools/bank/bank_build.lua --recipe art/music/bank/choir-real-recipe.json
flutter pub deps --json | sed -n '/^{/,$p' > <scratch>/graph.json && lua tools/generate_credits.lua <scratch>/graph.json
lua tools/score/score_gen.lua && lua tools/midi_stats.lua check
forge-guard run -- node tools/mix_meter/trim.mjs                       # the bank block moves where the choir sounds
```
