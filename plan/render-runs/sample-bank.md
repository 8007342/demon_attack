# Render run: the CC0 sample bank (`adaptive-soundtrack` §8.5, §8.6; `work/sample-bank`, 2026-11-17)

The first real build of `web/audio/bank/` from the pinned CC0 sources. Design: `openspec/changes/adaptive-soundtrack/design.md`
§12.9.7. Pins: `plan/sample-bank-pins.md` (round 1, 184 rows) and `plan/licences-round-2.md` §5 (round 2, 12 rows).

## 1. Fetch

- The coordinator cleared the fetch on the host: all 196 manifest rows (path, size, git blob sha1) match GitHub's trees
  at the five pinned commits, with the CC0 licence hashes.
- `forge-guard run -- lua tools/bank/bank_build.lua --fetch` fetched 159 round-1 files, then 9 round-2 audio files,
  each from `raw.githubusercontent.com/<repo>/<40-hex commit>/<path>`, never from a branch or a tag. The 3 round-2 SFZ
  maps came through `--fetch-maps --sync-keys`.
- **Every file passed the size and blob sha1 check. Nothing was refused or retried.**
- The raw files stay out of the repo, in `~/.cache/tillandsias-project/sample-bank/src/<owner>/<repo>/<path>`
  (112,002,233 B). A forge reset loses them, so rebuild with `--fetch`; the pins make the refetch exact.

## 2. The pitch check: three tries

1. **YIN as built (one 87.5 ms window at 80 ms after the onset).** Refused 27 zones:
   - 24 "no f0 found": 20 of them bass, plus `gtr-stac staccato_bb3_rr2`, `tbn-stac F1` and `horn-sus G1, A#1`;
   - three organ pipes (C3, F#3, F#4) read an octave high. Open flue pipes speak the octave first, and the window sat
     in the attack.
2. **YIN over up to 6 windows, with the paper's global-minimum fallback (d < 0.35), median.** Worse: 16 refusals,
   because the fallback locks onto subharmonics and noise lags (e.g. `c3_staccato_rr1` read 52.5 Hz).
3. **A verification of the planned root on one spectrum per zone (adopted).** Mono, decimated to 16 kHz behind a
   63-tap low-pass, from 80 ms for up to 1 s, Hann, zero-padded to 2^16 points.
   - **Octave:** the odd-partial test, voted per instrument. Periodicity at f puts partials at odd multiples of f.
     The zone moves down while the energy at odd multiples of F/2 exceeds 0.9 of the energy at multiples of F (and
     0.3 of the peak). It moves up while F's odd partials are under 0.02 of 2F's (and 2F's partials exceed 0.3 of the
     peak).
   - **Note:** the harmonic sum of sqrt-magnitudes (8 partials under 7 kHz), within ±6.5 semitones. The coarse
     10-cent search takes each partial's peak within ±12 cents.
   - On the first round-2 build this method still refused `twang_g6_f_rr1`, reading 625.9 Hz. That file's 4th
     partial is 17 dB over its fundamental, and real partials sit a few cents off exact multiples. With raw
     magnitudes and exact multiples, 626 Hz × 5 landed on that one partial. The sqrt compression and the ±12-cent
     peak tolerance fixed it (782.2 Hz, −0.04).
   - `--f0-report` prints the table below and stops.

**Independent check.** A Go tool in scratch (not committed) measured every pitched zone. It computes the harmonic
sum within ±60 cents of the root, the root −12 and the root +12, plus the same odd-half-partial ratio, over the whole
source file from 40 ms, and prints harmonic profiles in dB. It agreed with (3) zone for zone, and it is where the
staccato and organ conclusions below come from.

## 3. Findings and picks

| Question | Measured | Pick | Why |
|---|---|---|---|
| Growlybass map an octave above the sound (recipe `shift: -12`) | All 20 `bass-sus` zones are within 0.40 semitone of keycenter −12. Odd half-partials 0.000-0.024 of the partials, so nothing sounds an octave lower. Odd partials of the shifted F at 0.34-8.7 of 2F's, so the map's own octave is ruled out. | **Keep −12** | Confirmed by measurement, not only by the readme |
| Bass staccato | 13/20 pass. 7 read noise (11.8 Hz, 25.9 Hz, ±4-6 semitones) on the 0.4 s trims. The independent check on the full files puts all 20 within ≤ 0.6 at −12. | **`verify: report`** | Too short at 35-160 Hz to separate partials from half-partials. Same map as the sustains, which pass strict. |
| Organ octave (round 2 §5.3: VSCO's `OrganLoud.sfz` maps these files an octave higher) | All 8 VCSL pipes within 0.12 semitone of their names (C4 = 60). Odd half-partials 0.001-0.006 (noise). Odd partials of the named root 0.024-1.7 of 2F's; C2's 3rd and 5th partials sit at −18 and −12 dB re the strongest. | **Keep the VCSL names; add `organ-ext` C5/F#5; no C1/F#1 fallback** | The waveform repeats at the named pitch. Caveat for the listening (9.7): the even partials dominate, so the pipes can sound an octave up. If the operator hears that, set `shift: 12` and add the C1/F#1 pins. |
| Round-2 recipe entries (`gtr-hi`, `trumpet-sus`, `glock`, `organ-ext`) | trumpet within 0.05, glockenspiel 0.16, high guitar 0.08, organ C5/F#5 0.01 | **As round 2 §5.4, verbatim** | 1.5 s trims keep the desktop within 41 MB decoded |
| Timpani (`report`) | Scattered (−4.7 to +0.7, 4 zones voting −1). A struck membrane is inharmonic: the check reads its partials, not the heard note. | **Keep the pins doc's table** | The listening decides |
| Tubular bells (`report`) | C4-E5 within 0.30 | **Keep the names** | |

## 4. The bank

168 zones in 8 sprites, 187.1 s of audio:

| Sprite | Tier | Class | Ch | Length | Opus B | Decoded B |
|---|---|---|---|---|---:|---:|
| `bank-1pm.ogg` | 1 | phone | 1 | 35.3 s | 326496 | 6777600 |
| `bank-1dm.ogg` | 1 | desktop | 1 | 13.1 s | 150070 | 2515200 |
| `bank-2pm.ogg` | 2 | phone | 1 | 28.8 s | 273392 | 5529600 |
| `bank-2ps.ogg` | 2 | phone | 2 | 5.9 s | 76902 | 2246400 |
| `bank-2dm.ogg` | 2 | desktop | 1 | 37.7 s | 416992 | 7228800 |
| `bank-2ds.ogg` | 2 | desktop | 2 | 1.4 s | 19562 | 518400 |
| `bank-3dm.ogg` | 3 | desktop | 1 | 46.2 s | 391688 | 8860800 |
| `bank-3ds.ogg` | 3 | desktop | 2 | 18.9 s | 252748 | 7257600 |
| **Total** | | | | | **1,907,850** of 2,000,000 | **40,934,400** of 41,000,000 desktop; **14,553,600** of 16,000,000 phone |

Opus VBR came in 274,626 B over the dry-run's estimate (1,633,224 B), still within the budget.

Coverage (`lua tools/midi_stats.lua check` against the built `bank.json`; `check: ok 89 sections, 356636 B of MIDI, peak
30 voices, 0 failure(s)`, after merging the credits and Crosswind songs from `game`):

| Role | Notes | Covered | Phones |
|---|---:|---:|---:|
| drums | 13,402 | 100 % | 100 % |
| bass | 2,960 | 98.2 % | 98.2 % |
| guitarL / guitarR | 3,791 / 4,524 | 98.6 / 98.2 % | 98.6 / 94.8 % |
| organ | 2,297 | 98.6 % | 94.2 % |
| timpani | 1,091 | 99.8 % | 99.8 % |
| brass | 1,301 | 99.9 % | 13.7 % |
| clean | 956 | 98.6 % | 18.2 % |
| bells | 442 | 100 % | 0 % |

Section tracks played whole from the bank: 801 of 824 (573 on phones). The rest play the synth voice.

## 5. Per-zone pitch check (`--f0-report`, final)

`odd_f`: the summed magnitude at odd multiples of F/2 over that at multiples of F; near 0 means nothing sounds an
octave lower. `odd_2f`: the same at 2F, meaning F's odd partials over 2F's; well above 0 means F is not an octave
low. Residuals are in semitones against the root (after the recipe's shift).

| Instrument | File | Root | f0 Hz | Residual | Octave | odd_f | odd_2f |
|---|---|---:|---:|---:|---:|---:|---:|
| bass-stac | `db2_staccato_rr1.wav` | 25 | 11.78 | +5.32 | -2 | 1.090 | 1.163 |
| bass-stac | `db2_staccato_rr2.wav` | 25 | 12.5 | +6.35 | -2 | 1.012 | 1.090 |
| bass-stac | `e2_staccato_rr1.wav` | 28 | 42.41 | +0.50 | +0 | 0.442 | 1.389 |
| bass-stac | `e2_staccato_rr2.wav` | 28 | 42.02 | +0.34 | +0 | 0.317 | 1.043 |
| bass-stac | `gb2_staccato_rr1.wav` | 30 | 46.49 | +0.09 | +0 | 0.070 | 0.810 |
| bass-stac | `gb2_staccato_rr2.wav` | 30 | 46.44 | +0.07 | +0 | 0.167 | 0.990 |
| bass-stac | `a2_staccato_rr1.wav` | 33 | 38.4 | -6.22 | +0 | 0.891 | 1.036 |
| bass-stac | `a2_staccato_rr2.wav` | 33 | 54.21 | -0.25 | +0 | 0.368 | 1.490 |
| bass-stac | `c3_staccato_rr1.wav` | 36 | 65.18 | -0.06 | +0 | 0.073 | 1.250 |
| bass-stac | `c3_staccato_rr2.wav` | 36 | 65.6 | +0.05 | +0 | 0.121 | 1.143 |
| bass-stac | `eb3_staccato_rr1.wav` | 39 | 93.03 | +3.10 | +0 | 0.338 | 0.724 |
| bass-stac | `eb3_staccato_rr2.wav` | 39 | 78.32 | +0.12 | +0 | 0.059 | 0.618 |
| bass-stac | `gb3_staccato_rr1.wav` | 42 | 25.94 | +1.99 | -2 | 0.988 | 6.413 |
| bass-stac | `gb3_staccato_rr2.wav` | 42 | 92.71 | +0.04 | +0 | 0.122 | 0.956 |
| bass-stac | `a3_staccato_rr1.wav` | 45 | 110.64 | +0.10 | +0 | 0.237 | 1.437 |
| bass-stac | `a3_staccato_rr2.wav` | 45 | 83.22 | -4.83 | +0 | 0.411 | 1.661 |
| bass-stac | `c4_staccato_rr1.wav` | 48 | 102.57 | -4.21 | +0 | 0.535 | 1.328 |
| bass-stac | `c4_staccato_rr2.wav` | 48 | 131.95 | +0.15 | +0 | 0.201 | 1.262 |
| bass-stac | `eb4_staccato_rr1.wav` | 51 | 157.55 | +0.22 | +0 | 0.163 | 0.730 |
| bass-stac | `eb4_staccato_rr2.wav` | 51 | 156.83 | +0.14 | +0 | 0.136 | 1.031 |
| bass-sus | `db2_f_rr1.wav` | 25 | 34.71 | +0.03 | +0 | 0.000 | 1.036 |
| bass-sus | `db2_ff_rr1.wav` | 25 | 35.01 | +0.18 | +0 | 0.013 | 1.399 |
| bass-sus | `e2_f_rr1.wav` | 28 | 41.68 | +0.20 | +0 | 0.002 | 0.341 |
| bass-sus | `e2_ff_rr1.wav` | 28 | 42.17 | +0.40 | +0 | 0.024 | 0.853 |
| bass-sus | `gb2_f_rr1.wav` | 30 | 46.36 | +0.04 | +0 | 0.001 | 0.767 |
| bass-sus | `gb2_ff_rr1.wav` | 30 | 46.38 | +0.05 | +0 | 0.001 | 0.694 |
| bass-sus | `a2_f_rr1.wav` | 33 | 54.9 | -0.03 | +0 | 0.001 | 0.722 |
| bass-sus | `a2_ff_rr1.wav` | 33 | 54.9 | -0.03 | +0 | 0.001 | 1.075 |
| bass-sus | `c3_f_rr1.wav` | 36 | 65.26 | -0.04 | +0 | 0.001 | 2.306 |
| bass-sus | `c3_ff_rr1.wav` | 36 | 65.44 | +0.01 | +0 | 0.000 | 1.268 |
| bass-sus | `eb3_f_rr1.wav` | 39 | 77.78 | +0.00 | +0 | 0.000 | 1.097 |
| bass-sus | `eb3_ff_rr1.wav` | 39 | 78.01 | +0.05 | +0 | 0.001 | 0.627 |
| bass-sus | `gb3_f_rr1.wav` | 42 | 92.29 | -0.04 | +0 | 0.001 | 0.756 |
| bass-sus | `gb3_ff_rr1.wav` | 42 | 92.34 | -0.03 | +0 | 0.001 | 0.591 |
| bass-sus | `a3_f_rr1.wav` | 45 | 109.56 | -0.07 | +0 | 0.004 | 0.714 |
| bass-sus | `a3_ff_rr1.wav` | 45 | 110.13 | +0.02 | +0 | 0.015 | 1.198 |
| bass-sus | `c4_f_rr1.wav` | 48 | 131.49 | +0.09 | +0 | 0.001 | 1.189 |
| bass-sus | `c4_ff_rr1.wav` | 48 | 131.57 | +0.10 | +0 | 0.010 | 8.661 |
| bass-sus | `eb4_f_rr1.wav` | 51 | 156.1 | +0.06 | +0 | 0.000 | 1.299 |
| bass-sus | `eb4_ff_rr1.wav` | 51 | 156.19 | +0.07 | +0 | 0.000 | 1.120 |
| gtr-stac | `staccato_e3_rr1.wav` | 40 | 83.12 | +0.15 | +0 | 0.076 | 1.323 |
| gtr-stac | `staccato_e3_rr2.wav` | 40 | 84.09 | +0.35 | +0 | 0.157 | 1.221 |
| gtr-stac | `staccato_g3_rr1.wav` | 43 | 98.62 | +0.11 | +0 | 0.022 | 1.171 |
| gtr-stac | `staccato_g3_rr2.wav` | 43 | 98.62 | +0.11 | +0 | 0.028 | 1.259 |
| gtr-stac | `staccato_bb3_rr1.wav` | 46 | 116.2 | -0.05 | +0 | 0.058 | 1.293 |
| gtr-stac | `staccato_bb3_rr2.wav` | 46 | 115.94 | -0.09 | +0 | 0.041 | 1.451 |
| gtr-stac | `staccato_db4_rr1.wav` | 49 | 138.67 | +0.01 | +0 | 0.019 | 1.441 |
| gtr-stac | `staccato_db4_rr2.wav` | 49 | 138.35 | -0.03 | +0 | 0.025 | 1.511 |
| gtr-stac | `staccato_e4_rr1.wav` | 52 | 166.15 | +0.14 | +0 | 0.079 | 1.403 |
| gtr-stac | `staccato_e4_rr2.wav` | 52 | 165.86 | +0.11 | +0 | 0.068 | 1.304 |
| gtr-stac | `staccato_g4_rr1.wav` | 55 | 197.02 | +0.09 | +0 | 0.031 | 1.124 |
| gtr-stac | `staccato_g4_rr2.wav` | 55 | 197.02 | +0.09 | +0 | 0.037 | 1.021 |
| gtr-stac | `staccato_bb4_rr1.wav` | 58 | 233.89 | +0.06 | +0 | 0.009 | 1.341 |
| gtr-stac | `staccato_bb4_rr2.wav` | 58 | 234.3 | +0.09 | +0 | 0.015 | 1.245 |
| gtr-stac | `staccato_db5_rr1.wav` | 61 | 277.02 | -0.01 | +0 | 0.016 | 1.093 |
| gtr-stac | `staccato_db5_rr2.wav` | 61 | 277.02 | -0.01 | +0 | 0.014 | 1.178 |
| gtr-stac | `staccato_e5_rr1.wav` | 64 | 329.63 | +0.00 | +0 | 0.038 | 1.564 |
| gtr-stac | `staccato_e5_rr2.wav` | 64 | 329.63 | +0.00 | +0 | 0.021 | 1.852 |
| gtr-stac | `staccato_g5_rr1.wav` | 67 | 392.0 | +0.00 | +0 | 0.017 | 0.926 |
| gtr-stac | `staccato_g5_rr2.wav` | 67 | 388.84 | -0.14 | +0 | 0.080 | 1.170 |
| gtr-stac | `staccato_bb5_rr1.wav` | 70 | 465.36 | -0.03 | +0 | 0.014 | 1.143 |
| gtr-stac | `staccato_bb5_rr2.wav` | 70 | 465.36 | -0.03 | +0 | 0.026 | 1.045 |
| gtr-stac | `staccato_db6_rr1.wav` | 73 | 553.09 | -0.04 | +0 | 0.001 | 2.077 |
| gtr-stac | `staccato_db6_rr2.wav` | 73 | 553.73 | -0.02 | +0 | 0.001 | 1.906 |
| gtr-sus | `twang_e3_f_rr1.wav` | 40 | 82.65 | +0.05 | +0 | 0.000 | 1.097 |
| gtr-sus | `twang_g3_f_rr1.wav` | 43 | 98.45 | +0.08 | +0 | 0.000 | 1.293 |
| gtr-sus | `twang_bb3_f_rr1.wav` | 46 | 117.15 | +0.09 | +0 | 0.001 | 2.655 |
| gtr-sus | `twang_db4_f_rr1.wav` | 49 | 138.19 | -0.05 | +0 | 0.000 | 2.030 |
| gtr-sus | `twang_e4_f_rr1.wav` | 52 | 166.06 | +0.13 | +0 | 0.001 | 25.036 |
| gtr-sus | `twang_g4_f_rr1.wav` | 55 | 197.02 | +0.09 | +0 | 0.003 | 1.435 |
| gtr-sus | `twang_bb4_f_rr1.wav` | 58 | 234.3 | +0.09 | +0 | 0.000 | 36.814 |
| gtr-sus | `twang_db5_f_rr1.wav` | 61 | 277.98 | +0.05 | +0 | 0.001 | 4.211 |
| gtr-sus | `twang_e5_f_rr1.wav` | 64 | 330.01 | +0.02 | +0 | 0.002 | 1.187 |
| gtr-sus | `twang_g5_f_rr1.wav` | 67 | 392.9 | +0.04 | +0 | 0.002 | 1.617 |
| gtr-sus | `twang_bb5_f_rr1.wav` | 70 | 466.43 | +0.01 | +0 | 0.000 | 1.704 |
| gtr-sus | `twang_db6_f_rr1.wav` | 73 | 554.37 | +0.00 | +0 | 0.000 | 2.383 |
| gtr-sus | `twang_g6_f_rr1.wav` | 79 | 782.18 | -0.04 | +0 | 0.005 | 2.036 |
| gtr-sus | `twang_db7_f_rr1.wav` | 85 | 1103.62 | -0.08 | +0 | 0.011 | 29.904 |
| organ | `Rode_Man3Open_C2.wav` | 36 | 65.6 | +0.05 | +0 | 0.005 | 0.076 |
| organ | `Rode_Man3Open_F#2.wav` | 42 | 93.14 | +0.12 | +0 | 0.006 | 0.024 |
| organ | `Rode_Man3Open_C3.wav` | 48 | 130.66 | -0.02 | +0 | 0.001 | 0.096 |
| organ | `Rode_Man3Open_F#3.wav` | 54 | 185.0 | +0.00 | +0 | 0.002 | 0.386 |
| organ | `Rode_Man3Open_C4.wav` | 60 | 261.32 | -0.02 | +0 | 0.001 | 0.777 |
| organ | `Rode_Man3Open_F#4.wav` | 66 | 369.78 | -0.01 | +0 | 0.001 | 0.293 |
| organ-ext | `Rode_Man3Open_C5.wav` | 72 | 523.55 | +0.01 | +0 | 0.001 | 1.736 |
| organ-ext | `Rode_Man3Open_F#5.wav` | 78 | 740.42 | +0.01 | +0 | 0.001 | 0.583 |
| tbn-stac | `tenortbn_stac_F1_v4_rr1.wav` | 41 | 87.71 | +0.08 | +0 | 0.048 | 0.985 |
| tbn-stac | `tenortbn_stac_A#1_v4_rr1.wav` | 46 | 117.01 | +0.07 | +0 | 0.016 | 1.073 |
| tbn-stac | `tenortbn_stac_F2_v4_rr1.wav` | 53 | 173.91 | -0.07 | +0 | 0.009 | 0.863 |
| tbn-stac | `tenortbn_stac_A#2_v4_rr1.wav` | 58 | 233.08 | +0.00 | +0 | 0.010 | 0.843 |
| horn-sus | `MOHorn_sus_G1_v3_1.wav` | 43 | 97.72 | -0.05 | +0 | 0.019 | 0.296 |
| horn-sus | `MOHorn_sus_A#1_v3_1.wav` | 46 | 116.47 | -0.01 | +0 | 0.004 | 0.484 |
| horn-sus | `MOHorn_sus_D2_v3_1.wav` | 50 | 146.66 | -0.02 | +0 | 0.001 | 1.910 |
| horn-sus | `MOHorn_sus_F2_v3_1.wav` | 53 | 174.01 | -0.06 | +0 | 0.004 | 1.412 |
| horn-sus | `MOHorn_sus_A2_v3_1.wav` | 57 | 219.49 | -0.04 | +0 | 0.002 | 0.991 |
| horn-sus | `MOHorn_sus_C3_v3_1.wav` | 60 | 261.47 | -0.01 | +0 | 0.010 | 0.601 |
| tbn-sus | `tenortbn_sus_F1_v3_1.wav` | 41 | 87.31 | +0.00 | +0 | 0.002 | 0.998 |
| tbn-sus | `tenortbn_sus_A#1_v3_1.wav` | 46 | 116.54 | +0.00 | +0 | 0.001 | 1.228 |
| tbn-sus | `tenortbn_sus_D2_v3_1.wav` | 50 | 146.83 | +0.00 | +0 | 0.001 | 1.026 |
| tbn-sus | `tenortbn_sus_F2_v3_1.wav` | 53 | 174.61 | +0.00 | +0 | 0.002 | 0.328 |
| trumpet-sus | `Sum_SHTrumpet_sus_A#3_v3_rr1.wav` | 70 | 466.7 | +0.02 | +0 | 0.003 | 1.888 |
| trumpet-sus | `Sum_SHTrumpet_sus_F4_v3_rr1.wav` | 77 | 697.25 | -0.03 | +0 | 0.002 | 1.637 |
| trumpet-sus | `Sum_SHTrumpet_sus_C5_v3_rr1.wav` | 84 | 1043.48 | -0.05 | +0 | 0.003 | 3.547 |
| timpani | `Timpani1_Hit_v2_rr1_Sum.wav` | 42 | 45.06 | -0.45 | -1 | 0.212 | 3.334 |
| timpani | `Timpani1_Hit_v4_rr1_Sum.wav` | 42 | 46.12 | -0.05 | -1 | 0.349 | 1.623 |
| timpani | `Timpani2_Hit_v2_rr1_Sum.wav` | 46 | 90.02 | -4.47 | +0 | 0.104 | 2.028 |
| timpani | `Timpani2_Hit_v4_rr1_Sum.wav` | 46 | 121.42 | +0.71 | +0 | 0.777 | 1.789 |
| timpani | `Timpani3_Hit_v2_rr1_Sum.wav` | 49 | 141.91 | +0.41 | +0 | 0.056 | 1.000 |
| timpani | `Timpani3_Hit_v4_rr1_Sum.wav` | 49 | 106.07 | -4.63 | +0 | 0.212 | 0.386 |
| timpani | `Timpani4_Hit_v2_rr1_Sum.wav` | 52 | 82.26 | -0.03 | -1 | 0.092 | 1.763 |
| timpani | `Timpani4_Hit_v4_rr1_Sum.wav` | 52 | 87.46 | +1.03 | -1 | 0.180 | 2.403 |
| timpani | `Timpani5_Hit_v2_rr1_Sum.wav` | 54 | 141.26 | -4.67 | +0 | 0.721 | 24.261 |
| timpani | `Timpani5_Hit_v4_rr1_Sum.wav` | 54 | 183.3 | -0.16 | +0 | 0.234 | 3.325 |
| bells | `TB_hit_C4_v4_1.wav` | 60 | 258.62 | -0.20 | +0 | 0.012 | 0.050 |
| bells | `TB_hit_E4_v4_1.wav` | 64 | 335.39 | +0.30 | +0 | 0.023 | 0.045 |
| bells | `TB_hit_G4_v4_1.wav` | 67 | 395.86 | +0.17 | +0 | 0.026 | 0.047 |
| bells | `TB_hit_C5_v4_1.wav` | 72 | 525.67 | +0.08 | +0 | 0.124 | 0.019 |
| bells | `TB_hit_E5_v4_2.wav` | 76 | 664.22 | +0.13 | +0 | 0.062 | 0.112 |
| glock | `glock_medium_C6.wav` | 84 | 1055.61 | +0.15 | +0 | 0.232 | 0.137 |
| glock | `glock_medium_G6.wav` | 91 | 1582.54 | +0.16 | +0 | 1.191 | 0.480 |

## 6. Role levels matched to the synth

The first `trim.mjs` run with the bank on showed a large level gap. The sampled score's loudest case sat 4.6 LU under
the synth's, the spread was 9 LU (synth: 6.7), and 38 bank trims hit the +8 dB cap. The arrival tails and the coda
fell up to 8.8 dB short of the window. The cause was the recipe's role levels, which were never measured against the
synth voices. A scratch copy of the players with a solo hook rendered each role alone, over nine sections (k:B, h:A,
c1:arrival, k:clear, coda:reprise, c1:core, k:arrival, menu:overture, r:C), in both modes, with trims off. Sections
where the role's track stays synth in both modes were left out.

| Role | Sampled − synth (median) | Level before → after | After the match |
|---|---:|---|---:|
| drums | −14.4 dB | 1.0 → 5.25 | +0.3 dB |
| bass | −12.5 dB | 0.7 → 3.7 | about −1 dB (its drive compresses: the median fit gave −3 dB at 2.94, so +2 dB more) |
| clean | −19.2 dB | 0.45 → 4.1 | +0.1 dB |
| organ | −10.3 dB | 0.32 → 1.05 | +0.2 dB |
| brass | −8.0 dB | 0.36 → 0.9 | −0.4 dB |
| timpani | −13.1 dB | 0.85 → 3.84 | −0.9 dB |
| bells | −4.1 dB | 0.36 → 0.58 | −0.3 dB |
| guitarL / guitarR | −0.9 / −0.7 dB | 0.5 (kept) | |

Pick: **match the levels**. The operator approved the synth score's balance (round 6), so the sampled score should
start from that balance. Tuning by ear (9.7) starts from here. The rebuild reproduced every sprite byte for byte;
only `bank.json`'s role levels changed.

`trim.mjs` after the match, and again after merging the credits and Crosswind songs from `game` (227 cases):
- bank `top` −4.48 LUFS (synth −4.97), `offset` −0.49 dB, `floor` −14.59 (synth −11.81);
- 6 trims hit the +8 dB cap, down from 38: the coda's reprise and ukulele 2.5 and 3.3 dB under the window (their uke
  and strings play the synth), the credits song's dawn and drift 2.1 and 2.5 dB, and two bridge pivots ≤ 0.8 dB.
- The A/B clips (§7) were rendered before the credits and Crosswind songs joined. Their cases moved the narrowing's `k` slightly,
  so the clips' trims can differ from the committed file by about 0.1 dB.

## 7. Listening preview (A/B)

Private page for the operator: https://claude.ai/artifact/9GWPRDxFJByguEg56jPmpJ. Seven sections are rendered
offline through the shipped players (`tools/mix_meter/page.mjs`), synth against sampled, each with its own mode's
trims, on the desktop tier at Full music. One +2 dB listening gain applies to every clip; peaks stay under −1 dBFS.
The clips are 96 kbps Opus, 2.3 MB, embedded in the page as data URIs. They live in scratch, never in the repo.

| Clip | Section | Synth LUFS | Sampled LUFS | Bank trim | Notes sampled |
|---|---|---:|---:|---:|---:|
| calm | Krybor A, tier 1 (calm) | -20.54 | -19.93 | 3.6 | 400 |
| clear | Krybor clear (sampled trumpet fanfare) | -22.34 | -22.26 | 2.6 | 160 |
| core | Carrier tour 1, core at tier 4 | -18.97 | -19.05 | -0.4 | 1125 |
| defeat | Defeat (alien victory) | -20.15 | -20.04 | 3.9 | 273 |
| fanfare | Carrier tour 4 victory (brass falls back to synth) | -22.48 | -22.63 | 2.2 | 170 |
| menu | Overture (menu) | -21.2 | -20.87 | 6.4 | 156 |
| world | Krybor B, tier 3 (a world song) | -19.59 | -19.54 | 1.5 | 779 |

The LUFS figures are at game level, before the listening gain. Each pair matches within 0.6 LU. The sampled clips
peak 1-4.5 dB higher at the same loudness: real transients have more crest than the synth.

Picks:
- world = `k:B` at tier 3, the most-played band texture;
- core = `c1:core` at tier 4, the densest arrangement;
- calm = `k:A` at tier 1;
- fanfare = `c4:victory`: with round 2 the trumpet covers brass 99.9 %, but this fanfare reaches E6 (88), above the
  trumpet's top zone, so its brass track plays the synth for the whole section, as asked;
- clear = `k:clear`, a fanfare whose brass is sampled, for contrast;
- menu = `menu:overture`;
- defeat = `defeat:alienwin`.
