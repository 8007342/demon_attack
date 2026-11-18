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
  - a recipe `name` (default `bank`) names the JSON (`choir.json`) and prefixes the sprites (`choir-3dm.ogg`,
    `choir-4dm.ogg`), and a rebuild replaces only its own sprites;
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
- **Budgets** (its own): 400,000 B of Opus, 9,000,000 B decoded on desktops, 0 on phones.
  - Built: 380,958 B of Opus in 2 sprites (64 kbps mono) and 7,678,832 B decoded.
  - Every zone is normalised per instrument to −1 dBFS peak, as the first bank's are.
- **Phones:** no choir. The first bank's phone tier already uses 14.55 of its 16 MB, so the choir is desktop-only.
  This is an open question (§10).

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

- **Event:** `diveCry`, a structured `GameEvent` (`MusicBridge.diveCryEvent`). `fang-and-wings-comms` queues it when a
  demon dives with a war cry; its design §API is the authority for the name and data. Until that change lands, this
  is the stub name.
  - Data: any (e.g. `speaker`); the music ignores it.
  - It reaches the music through `GameEvents.listen` → `MusicBridge.call`, like every structured event. It is not a
    raw `model.events` string, so `audioSfx` never sees it, and the radio and the music each hear it once.
- **Mapping:** `MusicBridge.diveCryEvent` → `onAccent(MusicBridge.diveCryAccent)`, that is
  `audioAccent('warcry')` → `demonAudio.accent('warcry')`.
- `SongDirector.accent('warcry')` works too: `warcry` is in `scoreAccents`.

### 6.2 JavaScript

| Call | Returns | Notes |
|---|---|---|
| `demonAudio.accent('warcry')` | the anchor time (audio clock), or `null` | `null` when: the bank is off; the stinger played less than 8 beats ago; a radio line is speaking; two stingers are live; the music is muted. |
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

- **`fang-and-wings-comms`** (not pushed on 2026-11-18): when it lands, `git merge origin/work/fang-and-wings-comms`.
  If its event is not named `diveCry`, change `MusicBridge.diveCryEvent` to its name. Its radio war cries keep
  priority by §7.
- **`bank-fidelity`** (not pushed on 2026-11-18): its §12.11 standard (clean, no clipping, honest bitrate) applies to
  the choir's sprites too.
  - So far each zone is peak-normalised to −1 dBFS, encoded at 64 kbps mono like the first bank, and its source
    rate is 48 kHz.
  - The ACE-Step cuts are from 48 kHz FLAC, and their bandwidth is the model's (ledger §2).
  - Re-check against §12.11 once it is pushed.

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
5. Should epic-choir and 272 Merry Orks go to the register (research §8)?
