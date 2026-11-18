# Render run: the brood choir pilot (`demon-choir`, `work/demon-choir`, 2026-11-18)

Design: `openspec/changes/demon-choir/design.md`. Research: `plan/demon-choir-research.md`. The picks below are the
agent's, made by measurement per CLAUDE.md §5; the operator overrides them by ear.

## 1. The formant choir (`brood`)

- Recipe `art/music/choir/brood.json` `synth`; command `lua tools/brood_choir/brood.lua render`. Each zone takes
  0.7 s of CPU in Lua.
- 12 zones: oh/ah × C2, F2, A#2, D#3, G#3, C#4. Each zone is 2.6 s, 8 voices, rendered at 96 kHz and decimated to
  48 kHz.
- **Determinism:** a second render reproduced every zone's git blob sha1 (`art/music/bank/choir.manifest.tsv`).
- **Iterations, all checked against spectrograms and measurements:**
  1. Peterson-Barney-style formants and a soft Rosenberg closure (open 0.38, close 0.16). The result was a cliff above
     about 1.3 kHz, with nothing above 4 kHz. Measured on the source alone, the glottal derivative falls only −15.5 dB
     at 2 kHz re 100 Hz, so the darkness is the 5-pole cascade, which is the normal all-pole roll-off.
  2. A sharper closure (open 0.45, close 0.07): hardly any change, which confirms it is the cascade.
  3. **Kept:** a first-order presence shelf above 1.5 kHz (gain 3, up to +12 dB) and Hillenbrand (1995) male means for
     /o/ and /ɑ/, a sourced table (research §7) replacing the unsourced Peterson-Barney values.
  - The result is a dark ensemble whose F1-F2 band is strong and whose F3 sits about 35-45 dB under it.
- **Pitch** (`bank_build.lua --f0-report`, strict): all 12 zones are within 0.14 semitone of their roots, in the
  planned octave. The odd half-partials (`odd_f`) read 0.08-0.30 against about 0.001 for the organ: that is the growl's
  f0/2 energy, by design.

| Zone | f0 Hz | Residual | odd_f | | Zone | f0 Hz | Residual | odd_f |
|---|---:|---:|---:|---|---|---:|---:|---:|
| oh C2 | 65.41 | +0.00 | 0.090 | | ah C2 | 65.71 | +0.08 | 0.243 |
| oh F2 | 87.56 | +0.05 | 0.105 | | ah F2 | 87.11 | −0.04 | 0.152 |
| oh A#2 | 117.08 | +0.08 | 0.076 | | ah A#2 | 116.61 | +0.01 | 0.128 |
| oh D#3 | 154.94 | −0.07 | 0.138 | | ah D#3 | 154.31 | −0.14 | 0.296 |
| oh G#3 | 208.01 | +0.03 | 0.078 | | ah G#3 | 208.25 | +0.05 | 0.213 |
| oh C#4 | 277.18 | +0.00 | 0.143 | | ah C#4 | 277.82 | +0.04 | 0.214 |

## 2. ACE-Step takes (`grunt`, `warcry`)

- Studio: running (`studio.status`); no `studio.start` or `studio.restart` was needed. Workflow
  `art/workflows/music/campaign-text-headroom.json` (XL turbo, 8 steps, −8 dB headroom).
- Models: `acestep_v1.5_xl_turbo_bf16`, `qwen_0.6b_ace15`, `qwen_4b_ace15`, `ace_1.5_vae`, all already in the studio.
  **No consent ask** and no download.
- Three jobs, one at a time, `count` 2 each. The overrides were `$node:5.tags`, `$node:5.lyrics`, `$node:5.bpm`,
  `$node:5.keyscale` (F minor), `$node:5.duration` = `$node:7.seconds`, and `$node:10.filename_prefix`.
- Afterwards `gpu.status` showed no holder and 23.8 GB free, so there was nothing for `gpu.unload_model` to unload.

| Job | Seeds | Tags (abridged) | Lyrics | Length | Verdict |
|---|---|---|---|---|---|
| `st-1794960141040-178` | 8101, 8102 | "a cappella, deep male choir only, no instruments, wordless doom chant, low bass voices … ohh, ahh … 95 bpm" | `[verse] Ohhh ohhh … Ahhh ahhh …` | 30 s | **Not usable:** a broadband sub-bass drone (50-140 Hz) under choppy partials; no single sustained note |
| `st-1794960180966-179` | 8201, 8202 | "unaccompanied male choir, vocals only, choir aahs, long sustained chords … no drums, no bass, no guitar, no synth", 60 bpm | `[verse] Aaaaaah / Ooooooh …` | 30 s | **Not usable for zones:** voices with formants in 0-8 s, but **chords** (several pitches); a bass enters at 8 s |
| `st-1794960198072-180` | 8301, 8302 | "war chant, group of men shouting in unison, rhythmic battle shouts, grunts, tribal war cries, aggressive, vocals only, a cappella, no instruments, 95 bpm" | `[verse] Huh! Ha! Huh! Ha! / Hraaa! …` | 20 s | **Picked:** 8301 has shouts 18-20 dB over a drone; 8302's drone is louder (bursts only about 15 dB over it), but its final cry (14.2-18.6 s) is clean, coming after silence |

Raws: `~/.cache/tillandsias-project/demon-choir/raw/{doom,aah,grunt}-000{0,1}_00001.flac` with their provenance
sidecars. They are not committed (CLAUDE.md §5; operator: no lossless masters) and a forge reset loses them. The
shipped sprite is the record.

**The cuts** (`brood.json` `picks`, `brood.lua cut`): a 4 ms fade-in, a fade-out of 60 ms on grunts and 250-300 ms on
cries. The grunts get a 4-pole high-pass at 100 Hz, which removes the take's C2 drone (65 Hz): before it, 5 of 8 grunt
cuts read 65 Hz in the pitch check.

| Cut | Take | Window s | Measured f0 | Use |
|---|---|---|---|---|
| grunt_a_rr1/2 | 8301 | 0.00-0.40, 0.63-1.00 | drone-dominated before the high-pass | syllable a (velocity 1-80) |
| grunt_b_rr1/2 | 8301 | 2.48-2.85, 3.12-3.50 | 131.0 Hz (C3) on rr1 | b (81-96) |
| grunt_c_rr1/2 | 8301 | 7.48-7.85, 8.12-8.50 | 174.8 Hz (F3), 131.2 Hz (C3) | c (97-110) |
| grunt_d_rr1/2 | 8301 | 10.08-10.45, 10.68-11.05 | drone-dominated before the high-pass | d (111-127), the score's downbeat syllable |
| cry_a_rr1 | 8301 | 5.00-6.60 | 87.9 Hz (F2: reads the octave below, its growl) | warcry root F3 (53) |
| cry_a_rr2 | 8301 | 12.50-14.10 | 174.5 Hz (F3) | warcry root F3 (53) |
| cry_b_rr1 | 8302 | 14.20-15.90 | 220.1 Hz (A3) | warcry root A3 (57) |

The shouts land on the take's key (F minor: C3, F3, and the cry on A3), because ACE-Step writes in key. The grunts
have one nominal root, C3, the clearest measured shout. Pitch-shifting them to a bar's root (E2-F2 in the pilot's
sections) runs 7-8 semitones down, deliberately: lower and bigger. This is the main thing to judge by ear.

## 3. The bank

`forge-guard run -- lua tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json`. The build is
byte-identical on rebuild: a level-only change reproduced both sprites' sha256.

| Sprite | Tier | Zones | Seconds | Opus B | Decoded B | Decoded peak | Bitrate |
|---|---|---:|---:|---:|---:|---:|---:|
| `choir-4dm.ogg` | 4, desktop | 18 | 36.6 | 350,484 | 7,036,800 | −0.82 dBFS | 76 kb/s with Ogg (64k VBR target) |
| `choir-3dm.ogg` | 3, desktop (second round robins) | 5 | 3.3 | 30,474 | 642,032 | −3.64 dBFS | |
| **Total** | | 23 | 40.0 | **380,958** of 400,000 | **7,678,832** of 9,000,000 | no clipping | |

`choir.json` is 15.8 KB. Sources: 7,510,286 B of 32-bit float WAV in `~/.cache/tillandsias-project/demon-choir/src`.

## 4. The score and the gates

- `lua tools/score/score_gen.lua`:
  - `c1/core` has 911 notes and peaks at 30 voices (29 before). An earlier draft with grunts in the core reached 33
    with the 1UP stinger, so the core has root drones only.
  - `k/B` has 724 notes and peaks at 27.
  - `warcry` peaks at 31 at worst, layered over `c1/core`.
  - Only `c1/core.mid`, `k/B.mid`, `score.json` and `song_map.dart` changed.
- `lua tools/midi_stats.lua check`: `check: ok 89 sections, 357076 B of MIDI, peak 30 voices, 0 failure(s)`, with
  brood 29 notes, grunt 10 and warcry 8 keys, all 100 % covered.

## 5. Levels (solo loudness, desktop, tier 4, trims off; a scratch harness masks every other track)

| Track | k:B | c1:core | Notes |
|---|---:|---:|---|
| synth `choir` (bank off) | −39.8 LUFS | −39.1 | the reference pad |
| sampled `organ` | −39.3 | | |
| `brood` at level 1.0 | −39.5 | −42.6 | the core is root-only |
| `brood` at level **1.2** | −38.0 | −41.0 | kept: the pads' loudness |
| sampled `lead` momentary max | −27.2 | −27.4 | |
| `grunts` at level 1.0, momentary max | −36.4 | | 9 dB under the lead: lost in the band |
| `grunts` at level **2.1**, momentary max | −30.0 | | kept: 3 dB under the lead |
| `warcry` at level 2.1 | about 16 dB under the band at its peak | | too quiet to read as music |
| `warcry` at level **5.3** | about 8 dB under the band at its peak (−29.6 against −22.2 per 0.5 s window) | | kept. Measured by subtracting a k:B render without cries from one with cries: the renders are deterministic, so the difference is the cries alone. No change to the peak (−5.35 dBFS). |

`node tools/mix_meter/trim.mjs`: see §6.

## 6. Trims

`forge-guard run -- node tools/mix_meter/trim.mjs`: `217 trims of 227 cases; top -4.97 LUFS, floor -11.81, k 0.2924;
bank: 226 trims, top -4.48 LUFS (offset -0.49 dB), floor -14.59, k 0.1978`. Every rule number is the same as
before.
- The synth block is unchanged: the synth plays no choir note.
- The bank block moved only where the choir sounds:

| Case | Bank LUFS before → after | Bank trim before → after |
|---|---:|---:|
| `c1:core@2` | −5.74 → −5.72 | unchanged |
| `c1:core@3` | −4.72 → −4.70 | unchanged |
| `c1:core@4` | −4.64 → −4.62 | unchanged |
| `k:B@3` (grunts) | −7.03 → −6.90 | 1.6 → 1.5 |
| `k:B@4` (grunts, brood) | −6.94 → −6.73 | 1.5 → 1.3 |

The choir adds 0.02-0.2 LU: it is a layer, not a lead. The war cry's level is outside the trims, because stingers are
not trim cases.

## 7. Listening page

Private page for the operator: https://claude.ai/artifact/2R75iuhVmrs5J5r9BTezmY. It holds 8 clips of Opus (96 kbps;
the kit at 64 kbps), 1.25 MB embedded as data URIs, with a 1.68 MB page. The clips are rendered offline through the
shipped players (a scratch copy of `tools/mix_meter`), on the desktop tier at Full music. They stay in
`~/.cache/tillandsias-project/demon-choir/clips/` and never go in the repo.

| Clip | What | Level |
|---|---|---|
| kit | every shipped zone in turn: ah C2, oh/ah F2, oh G#3, grunts a-d, the three cries | −4 dB (the zones peak at −1 dBFS) |
| brood-solo-core | the `brood` track of `c1:core` at tier 4, alone with its room | +20.5 dB for listening (−41.0 LUFS at game level) |
| grunts-solo | `grunts` and `drums` of `k:B` | +6.5 dB |
| cries-k | `k:B` at tier 4, full sampled mix, a `warcry` asked every 1.9-2.6 s off the grid | +2 dB |
| core-with / core-without | `c1:core` at tier 4, sampled, with and without `choir.json` | +2 dB; −19.02 / −19.04 LUFS |
| k-with / k-without | `k:B` at tier 4, sampled, with and without `choir.json` | +2 dB; −19.42 / −19.63 LUFS |

**The war cries, landed** (k:B, 170 BPM, an 8th = 0.1765 s; times from the section start):

| Asked (s) | Landed (s) | 8ths | |
|---:|---:|---:|---|
| 1.07 | 1.235 | 7.00 | plays |
| 3.35 | | | spaced out |
| 5.99 | 6.176 | 35.00 | plays |
| 7.91 | | | spaced out |
| 10.19 | 10.235 | 58.00 | plays |
| 12.83 | | | spaced out |
| 14.75 | 14.824 | 84.00 | plays |
| 17.03 | | | spaced out |

## 8. Process note

A scratch harness from an earlier session, in the scratchpad (`solo/`), still held symlinks into the `sample-bank`
worktree. The first solo run wrote into that worktree: its `score.json`, `mix-trim.json` and 20 stray symlinks. The
symlinks were removed by their target and the two files restored with `git checkout`, and its status is clean again.
The harness was then rebuilt in a fresh folder. Lesson: never reuse a scratch folder that holds links.

## 9. Round 8: rebuilt to the bank-fidelity standard (2026-11-18, `work/round8`)

Rebuilt from the cached sources (`~/.cache/tillandsias-project/demon-choir/src`, raws in `…/demon-choir/raw/`; nothing
re-rendered, nothing downloaded) after `work/bank-fidelity` merged. Design §4.1 holds the verdicts; the numbers:

```sh
lua tools/bank/bank_audit.lua sources --bank web/audio/bank/choir.json --src ~/.cache/tillandsias-project/demon-choir/src
lua tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json --out OUT --keep-pcm PCM
lua tools/bank/bank_audit.lua bitrate --pcm PCM --bank OUT/choir.json --rates 64,96,128,160
lua tools/bank/bank_audit.lua cut|encode --pcm PCM --bank OUT/choir.json --sprites OUT
forge-guard run -- lua tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json
```

| Instrument | Sources | Clipped | Rate sweep, median magnitude SNR (64/96/128/160) | Pick | End level before → after the fade |
|---|---|---|---|---|---|
| brood | 12, 48 kHz f32 mono, −3 dBFS | 0 | 29.7 / 33.4 / 37.2 / 41.0 dB | 128 kbps | looped (seams −22 to +4.8 dB, kept) |
| grunt | 8, 48 kHz f32 mono, −17 to −13 dBFS | 0 | 26.1 / 29.1 / 32.2 / 34.5 dB | 160 kbps (cap) | −15…−26 → −25…−31 dB (fade 0.15 s) |
| warcry | 3, 48 kHz f32 mono, −14 to −6 dBFS | 0 | 24.2 / 27.4 / 31.0 / 33.8 dB | 160 kbps (cap) | −17…−28 → −49…−61 dB (fade 0.6 s) |

Built: `choir-3d160m.ogg` (5 zones, 72,213 B), `choir-4d128m.ogg` (12, 577,196 B), `choir-4d160m.ogg` (6, 106,957 B):
756,366 B of Opus (budget raised to 800,000), 7,677,400 B decoded (budget 9,000,000). Encoded magnitude SNR, median:
brood 37.2, grunt 34.5, warcry 33.8 dB; −60 dB bandwidth unchanged by Opus. `bank_audit.lua` learned to read the
float WAVs' bit depth (`pcm_f32le`).

Trims regenerated (`forge-guard run -- node tools/mix_meter/trim.mjs`): the synth block is byte for byte bank-fidelity's
(top −4.97 LUFS, floor −11.81, k 0.2924); the bank block keeps its constants (top −4.60, offset −0.37 dB, floor −15.43,
k 0.1847, 222 trims) and moves only where the choir sounds: `c1:core@3-4` −0.1/−0.2 → −0.2/−0.3 dB, `k:B@3-4` +1.9/+1.8
→ +1.7/+1.6 dB (measured loudness `c1:core@2-4` −5.89/−4.84/−4.74 LUFS, `k:B@3-4` −7.19/−7.01).

## 10. Real samples: epic-choir and 272 Merry Orks (2026-11-18, `work/choir-real`)

Design: `openspec/changes/demon-choir/design.md` §11. The picks are the agent's, by measurement (CLAUDE.md §5). The
operator overrides by ear on the listening page.

### 10.1 Fetch and verification

`lua tools/brood_choir/pins.lua fetch` (all 30 rows of `plan/choir-pins.manifest.tsv`):

- **The zip:** `epic-choir-v1.0-B.zip`, 173,859,746 B, sha256
  `3f78e9b59018dc2ef45bb30d1b57cb68f22768d15e1f1c1a4f93d0b5e4b3002f`. It matched the pin, checked on the whole file before
  any member was extracted. It is kept in `~/.cache/tillandsias-project/choir-src/` (never the repo or the tmpfs checkout).
- **The members:** 10, extracted by name to `~/.cache/tillandsias-project/demon-choir/src/thepok/epic-choir/samples/B/`.
  Each matched its size and CRC32 (computed in Lua). The CRC32s also agree with `unzip -v`, and one was re-checked
  with zlib.

| Member | CRC32 | git blob sha1 (pinned for the builder) |
|---|---|---|
| B_oh_f_As2.wav | 10f89a4c | f885b3a654dd390aeb021a1f8f3cd04b371183c4 |
| B_oh_f_D3.wav | ad933881 | 72ef88ab5533cff2faaee99c0c4d0d15668bba2c |
| B_oh_f_Fs3.wav | a828a5da | db24b78079c11508f9fb140e4b590d2d588e1274 |
| B_oh_f_As3.wav | 26766eca | 99a92d59a6f9d783bbe3e9ce26f6588d9429ccf9 |
| B_oh_f_D4.wav | 2b511751 | 746e5e83d3cb94c642276aea558e925a06c7d4cc |
| B_ah_f_As2.wav | 3b202661 | 85c70b96b27dd999f58961ad8bafb5d487269cad |
| B_ah_f_D3.wav | ccfdba51 | 09733b014d9e319b3107cd44239ea7e07d4535fb |
| B_ah_f_Fs3.wav | 6fb1b0bd | 0c906a1459ec08f5c7c14d5d3bd7af88814e14be |
| B_ah_f_As3.wav | 40f6e85a | 5115c0abecd9b22a6efd04ba4ae13d560300677a |
| B_ah_f_D4.wav | 429b247c | d075091da15bd1b6c84afb7c4f56ff929f18b69e |

- **Git blobs:** 19 (epic-choir `LICENSE`, `README.md`, `ATTRIBUTION.txt`, `SOURCE.json`, `B_oh.sfz`, `B_ah.sfz`; Merry Orks
  `LICENSE`, `readme.txt`, `ork_vocals.sfz` and the 10 samples), fetched raw at the pinned commits. Each matched its
  size and the manifest's blob sha1.

### 10.2 Sources (`bank_audit.lua sources`, and a scratch analysis for onset, centroid and the stereo fold)

- **epic-choir:**
  - 44.1 kHz 16-bit stereo, 6.9-8.3 s per file, peaks −0.7 to 0.0 dBFS; 4 files have 15-46 samples above 0.9999;
  - 107-281 ms of digital silence before the onset;
  - head noise −55 to −62 dBFS, −60 dB bandwidth 7.7-9.9 kHz;
  - L/R correlation 0.20-0.44; the (L+R)/2 fold loses −1.6 to −2.3 dB, as decorrelation predicts; 1/3-octave comb s.d. 0.9-1.5 dB.
- **Merry Orks:** 44.1 kHz 24-bit mono, peaks −5.4 to −11.3 dBFS, 0.70-1.41 s, centroid 0.8-1.5 kHz. The word ends
  in silence (quietest 50 ms −62 to −95 dB re the loudest).
- **Pitch** (`bank_build.lua --f0-report`, strict). Residuals per zone:

| Zone | oh | ah |
|---|---:|---:|
| A#2 | −0.03 | +0.22 |
| D3 | +0.05 | +0.15 |
| F#3 | −0.34 | −0.02 |
| A#3 | −0.22 | −0.09 |
| D4 | +0.45 | +0.46 |

  Every zone is in its planned octave. D4 is not played by the current score (brood notes reach 40-57).

### 10.3 Picks and their reasons

| Decision | Tried | Measured | Pick |
|---|---|---|---|
| brood mono | L, R, sum | encoded SNR @160 L 36.1 / sum 36.4 dB; loop seams median L −6.6 / sum −13.4 dB | **sum**: the hall is decorrelated seats, not a spaced pair |
| brood rate | 64/96/128/160 | sum 26.7/31.0/33.8/36.4 dB | **160** (35 dB rule) |
| brood DC | off, `dc: true` | −54.7…−66.7 → −77.7…−111.3 dB | **on** |
| brood clipping | | 85 samples in 6 zones rebuilt (`declip`) | **declip** |
| low drones E2/F2 | A#2 shifted (stretch 6); synth oh/ah C2+F2 under G#2 | envelope steps 2.0-5.3 dB/semitone vs a 21.7-23.4 dB seam; the hybrid 962,800 B Opus / 9.22 MB decoded (over) | **shift** |
| grunt pitch | −4, −7, −12 | centroid median 900 / 740 / 535 Hz (ACE-Step 760); end median −41.7 dB at −7, −31.9 at −12 | **−7** |
| grunt trim | 0.6/0.15, 0.7/0.3, 0.8/0.25, 1.0/0.3 | ends median −20.5, −41.7, −40.6 dB; 1.0 s 800,441 B (over) | **0.7 s, fade 0.3** |
| war cry | ACE-Step cuts; Orks `a_from_car_rr1`/`o_from_pot_rr1` at −7, trim 1.8, fade 0.6 | ends −49.5…−61.3 vs −36.6…−38.9 dB; 3 vs 2 zones; growl f0 unstable (63, 182 Hz) | **ACE-Step** (unchanged) |
| levels | | brood solo at 1.2: −42.32 (k:B), −46.22 (core) vs approved −37.93/−40.88; grunt momentary max at 2.1: −32.5 vs −30.0 | **brood 2.1** (−37.46/−41.36), **grunt 2.8** (−30.0) |

### 10.4 Built (scratch; not active)

- **Build:** `forge-guard run -- lua tools/bank/bank_build.lua --recipe art/music/bank/choir-real-recipe.json --out <scratch>`.
  - 21 zones: `choir-3d160m.ogg` 97,009 B (5 zones, 4.6 s), `choir-4d160m.ogg` 660,882 B (16 zones, 32.9 s), `choir.json` 15,140 B.
  - **757,891 B of Opus** and **7,203,768 B decoded** (budgets 800,000 and 9,000,000).
  - A second build reproduced both sprites' sha256. A second cut reproduced every Orks pick's blob.
- **Audits, real against approved:**
  - brood encoded magnitude SNR 36.7 (min 36.0) against 37.2 dB;
  - grunt 32.9 against 34.5 dB; warcry 34.2 against 33.8 dB (the same cuts in another sprite);
  - −60 dB bandwidth: brood 8.7 against 3.6 kHz, grunt 11.7 against 16.8 kHz (the −7 shift);
  - loop seams −31.5/−5.5/−0.5 against −21.8/−5.8/+4.8 dB; no overs, no onset steps.
- **Coverage:** `lua tools/midi_stats.lua check --choir <scratch>/choir.json` reports `check: ok 89 sections, 357076 B of
  MIDI, peak 30 voices, 0 failure(s)`, with brood 29 notes, grunt 10 and warcry 8 keys, all 100 % covered.
- **The approved build:** rebuilt with the changed builder, it is byte-identical (`choir.json` and all three sprites).

### 10.5 Verdict

- **Recommended:** the real candidate.
- **Not active:** its brood encodes 0.5 dB below the approved synth (36.7 against 37.2 dB), so it does not measure at
  least as clean on every count (design §11.6).
- **Unchanged files:** `web/audio/bank/choir.json`, the score (`score_gen.lua`: byte-identical) and `mix-trim.json`
  (`trim.mjs`, regenerated: byte-identical; `--check` passes).
- **Credits:** `assets/credits.json` changes only its `authors_commit`. The two choir rows stay "coming" until the
  candidate is built into `web/audio/bank/`.

### 10.6 Listening page

https://claude.ai/artifact/BRp5LaDJBJYiiQAG7ioU35 (private), 4.7 MB with 15 clips in Opus at 128 kbps stereo, as data URIs.

- **How the clips were made:** each was rendered offline through the shipped players (desktop, tier 4, Full music, bank
  on), from scratch harnesses that are real copies of `web/` and `tools/mix_meter` with each candidate's `choir.json`.
  The clips stay in `~/.cache/tillandsias-project/choir-real-clips/` and never go in the repo.
- **Loudness:** each clip is set to its strip's loudness, solos −23 LUFS and mixes −18 LUFS. The full mixes measure
  −19.0 ±0.05 LUFS at game level for every candidate.

| Strip | Clips |
|---|---|
| brood solo k:B@4 | approved, real, hybrid (synth under G#2, gainDb −5 to match) |
| brood solo c1:core@4 | approved, real, hybrid |
| grunts with drums k:B@4 | ACE-Step, Orks −7, Orks −12 |
| war cries over k:B@4 (asked every 1.9-2.6 s; three land at 1.235, 6.176, 10.235 s) | approved, real, Orks growls (level 4.1) |
| carrier core c1:core@4 | approved, real, hybrid |
