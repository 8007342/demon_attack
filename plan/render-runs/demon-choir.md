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
