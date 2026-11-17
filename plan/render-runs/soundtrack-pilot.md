# Render run: soundtrack pilot, tour-1 carrier (2026-11-17)

Change: `openspec/changes/adaptive-soundtrack` (design §4, §8). Cleared by the coordinator on 2026-11-17: ComfyUI core
ACE-Step nodes only, one GPU job at a time, raws off the repo.

## Recipe and reproduction

- Recipe: `art/music/soundtrack/pilot-carrier-t1.json` (common tags, per-section tags, keys, seeds).
- Workflow: `art/workflows/music/campaign-text-headroom.json` (XL turbo, 8 steps, LM audio codes on, −8 dB before the
  FLAC save), run with `studio.run_workflow` and these overrides: `$node:5.tags` = common tags + section tags,
  `$node:5.bpm` = 95 (half the tempo; "190 bpm" is in the tags), `$node:5.keyscale`, `$node:5.duration` = 40,
  `$node:7.seconds` = 40, `$node:10.filename_prefix`; `count` 4 from seed 7101. Base takes add
  `$node:1.unet_name` = `acestep_v1.5_xl_base_bf16.safetensors`, `$node:8.steps` = 32, `$node:8.cfg` = 5. The
  long-form takes set `$node:5.lyrics` to the structure tags in the recipe and 150 s.
- Models (studio provenance): `acestep_v1.5_xl_turbo_bf16`, `acestep_v1.5_xl_base_bf16`, `qwen_0.6b_ace15`,
  `qwen_4b_ace15`, `ace_1.5_vae`. ComfyUI 0.40.0, RTX A5000.
- Tools: `cd tools/soundtrack_check && go build -o ~/.cache/tillandsias-project/bin/soundtrack_check .`, then
  `lua tools/soundtrack_pilot.lua ingest <job dir> <section> <model> <seed>`, `… analyze`, `… cut <take> <kind>
  <bars> c1-<section> [start bar]`, `… encode c1-<section>`.
- Raws: `~/.cache/tillandsias-project/soundtrack-pilot/raw/` (FLAC + studio provenance), measurements in
  `analysis/`, cuts in `cut/`. Not committed; a forge reset loses them, the recipe does not.
- GPU: 10 jobs, about 6 s per 40 s turbo take, 22 s per 150 s take, 11–16 s per 32-step base take. A first core and
  tier-1 batch without the headroom trim was discarded (true peaks above 0 dBFS); the same seeds were re-run with it.

## Grid and gates

Grid L5: 60 632 samples per bar at 48 kHz (189.9987 BPM), F minor (victory F major). Gates (design §6): tempo within
0.6 %, asked key in the top three, more than 60 dB down above 16 kHz is a warning ("no air"), loop wrap step ≤ 1 ×
p99.9 and wrap flux ≤ 1.5 × the bar lines' median, whole bars, no clicks or clipping. The host's
`audio.detect_glitches` could not run (the tray app is older than the enclave images), so `soundtrack_check check`
did the seam and click checks.

## Every take

| Take | BPM | Error % | Key (r) | Asked key rank | > 16 kHz dB | LUFS (−8 dB trim) | Gate |
|---|---:|---:|---|---:|---:|---:|---|
| `approach-turbo-7101` | 189.999 | -0 | F minor (0.814) | 1 | -62.2 | -18.3 | no air: > 60 dB down above 16 kHz |
| `approach-turbo-7102` | 189.999 | -0 | F minor (0.865) | 1 | -36.8 | -18.6 |  |
| `approach-turbo-7103` | 191.994 | 1.05 | F minor (0.877) | 1 | -47.3 | -18.4 | tempo 1.05% off |
| `approach-turbo-7104` | 190.094 | 0.05 | F minor (0.717) | 1 | -63.7 | -20 | no air: > 60 dB down above 16 kHz |
| `collapse-turbo-7101` | 189.999 | -0 | Ab major (0.833) | 2 | -43.4 | -18.4 |  |
| `collapse-turbo-7102` | 191.994 | 1.05 | F minor (0.903) | 1 | -33 | -19.2 | tempo 1.05% off |
| `collapse-turbo-7103` | 189.999 | -0 | F minor (0.837) | 1 | -56.1 | -16.8 |  |
| `collapse-turbo-7104` | 189.999 | -0 | F minor (0.817) | 1 | -61.9 | -19.4 | no air: > 60 dB down above 16 kHz |
| `core-base-7201` | 196.269 | 3.3 | F minor (0.67) | 1 | -35.4 | -19.8 | tempo 3.30% off |
| `core-base-7202` | 189.999 | -0 | F minor (0.812) | 1 | -48.4 | -19.1 |  |
| `core-turbo-7101` | 189.999 | -0 | F minor (0.719) | 1 | -62 | -18.6 | no air: > 60 dB down above 16 kHz |
| `core-turbo-7102` | 189.999 | -0 | F minor (0.872) | 1 | -43.2 | -19.4 |  |
| `core-turbo-7103` | 188.004 | -1.05 | F minor (0.851) | 1 | -38 | -18.2 | tempo -1.05% off |
| `core-turbo-7104` | 189.714 | -0.15 | F minor (0.898) | 1 | -57.2 | -21.1 |  |
| `longform-turbo-7301` | 189.999 | -0 | F minor (0.631) | 1 | -52.9 | -20.7 |  |
| `longform-turbo-7302` | 188.004 | -1.05 | F minor (0.8) | 1 | -21.9 | -19.7 | tempo -1.05% off |
| `tier1-turbo-7101` | 189.999 | -0 | F minor (0.734) | 1 | -56.2 | -18.1 |  |
| `tier1-turbo-7102` | 189.999 | -0 | F minor (0.893) | 1 | -34.6 | -17.9 |  |
| `tier1-turbo-7103` | 189.999 | -0 | F minor (0.86) | 1 | -49.2 | -18.5 |  |
| `tier1-turbo-7104` | 189.999 | -0 | F minor (0.749) | 1 | -60.7 | -18.1 | no air: > 60 dB down above 16 kHz |
| `tier2-turbo-7101` | 189.999 | -0 | F minor (0.814) | 1 | -64.2 | -18.7 | no air: > 60 dB down above 16 kHz |
| `tier2-turbo-7102` | 189.999 | -0 | F minor (0.872) | 1 | -35.2 | -19.1 |  |
| `tier2-turbo-7103` | 189.999 | -0 | F minor (0.942) | 1 | -39.4 | -18.2 |  |
| `tier2-turbo-7104` | 189.999 | -0 | F minor (0.816) | 1 | -60 | -18.8 |  |
| `transform-turbo-7101` | 186.104 | -2.05 | F minor (0.847) | 1 | -40.4 | -17.1 | tempo -2.05% off |
| `transform-turbo-7102` | 189.714 | -0.15 | F minor (0.919) | 1 | -34.7 | -18.3 |  |
| `transform-turbo-7103` | 188.289 | -0.9 | F minor (0.884) | 1 | -45.5 | -18.9 | tempo -0.90% off |
| `transform-turbo-7104` | 189.999 | -0 | F minor (0.94) | 1 | -36 | -17.8 |  |
| `victory-turbo-7101` | 188.004 | -1.05 | C major (0.729) | 2 | -64.5 | -19.2 | tempo -1.05% off; no air: > 60 dB down above 16 kHz |
| `victory-turbo-7102` | 186.009 | -2.1 | F major (0.798) | 1 | -42.7 | -19.4 | tempo -2.10% off |
| `victory-turbo-7103` | 189.999 | -0 | C major (0.783) | 3 | -51.9 | -18.1 |  |
| `victory-turbo-7104` | 189.999 | -0 | F major (0.773) | 1 | -61.8 | -17.3 | no air: > 60 dB down above 16 kHz |

## Picks

Picked by the gates and measurements, not yet by ear (CLAUDE.md §5: the agent picks and logs, the operator overrides).
Among takes that pass, the order of preference is: tempo exact, asked key first with high r, more air above 16 kHz,
then the cleaner seam.

| Section | Pick | Window | Why | Wrap check |
|---|---|---|---|---|
| `approach` (loop, 8 bars) | `approach-turbo-7102` | bars 17–24 (22.40 s) | tempo exact, F minor r 0.865, the most air of the four (−36.8 dB); 7103 is 1.05 % off; 7101 and 7104 have no air | step 0.24, flux 0.73 |
| `tier1` = H1 (loop) | `tier1-turbo-7102` | bars 15–22 (19.62 s) | all four lock the tempo; 7102 has the best key fit (r 0.893) and by far the most air (−34.6 dB); its seam similarity is the lowest (0.96) but the wrap check passes | step 0.14, flux 1.06 |
| `tier2` = H2 (loop) | `tier2-turbo-7103` | bars 8–15 (11.34 s) | the best key fit of the pilot (r 0.942), air −39.4 dB, seam 0.992; 7102 has slightly more air but a weaker key fit | step 0.10, flux 0.77 |
| `transform` (bridge, 3 bars) | `transform-turbo-7104` | bars 1–3 (1.85 s) | tempo exact, r 0.94; bars 1–3 build from −36 to −29 dB RMS into the louder bar 4 — a riser into a landing; 7102 has more air but runs 0.15 % slow and its build sits in the first two bars | — |
| `core` (loop) | `core-turbo-7102` | bars 5–12 (7.26 s) | tempo exact, r 0.872, air −43.2 dB, seam 0.997; 7101 has no air, 7103 drifts, 7104 is quiet and airless; the base take 7202 passes but has less air (−48.4) and base 7201 drifted 3.3 % | step 0.13, flux 1.11 |
| `collapse` (tail, 8 bars + 3 s) | `collapse-turbo-7103` | bars 18–25 + its own decay | the take ends by itself at bar 26 (RMS −27 → −41 → −75 dB), which the tail keeps; 7101 reads A♭ major, 7102 drifts, 7104 has no air | — |
| `victory` (tail, 4 bars + 3 s) | `victory-turbo-7104` | bars 20–23 + its own ending (forced start 20) | F major, tempo exact, and it ends by itself after bar 23; it fails the air warning (−61.8 dB), but the other F-major take (7102) is 2.1 % slow and the two others read C major | — |

Encodes (`art/music/soundtrack/pilot/`, Opus 160 kbps VBR, linear loudnorm to −19 LUFS, true peak ≤ −1.5 dBTP;
each loop decodes to exactly 8 × 60 632 samples with ffmpeg):

| File | Bytes | sha256 (first 16) |
|---|---:|---|
| `c1-approach.opus` | 206084 | cf7ce77d2701e160 |
| `c1-collapse.opus` | 285566 | 6bf12afa7a45e839 |
| `c1-core.opus` | 199742 | a1ee78e62e9bd860 |
| `c1-tier1.opus` | 201551 | 97f9740382df1c46 |
| `c1-tier2.opus` | 204754 | 9271a8f1356e11dc |
| `c1-transform.opus` | 93058 | 48be4330e334d8ae |
| `c1-victory.opus` | 169450 | efa85758e36672ac |

## Not picked, kept for A/B (task 1.7)

- `longform-turbo-7302` (150 s, structure tags): per-bar RMS shows a 15-bar intro, a body, an 8-bar breakdown
  (bars 63–70), a climax and a fade; it is 1.05 % slow, so it fails the tempo gate as is. Its air (−21.9 dB above
  16 kHz) is unlike every section take and may be noise; listen before using it. A cut set from one long take
  would be one performance (one band, one mix), which separate section takes are not.
- `longform-turbo-7301`: tempo exact, a long build (bars 0–15) into a steady body; weak key fit (r 0.631).
- `core-base-7202`: passes; less air than the turbo pick. The base model is not better on these measures.

## Findings for the design

- The half-tempo `bpm` field locks 190 BPM: 21 of 28 section takes within 0.15 %.
- Section prompts give sections that differ (doom half-time approach, galloping tier 1, blast-beat tier 2, riser,
  climax, doom collapse, major fanfare) on paper (RMS profile, key). Whether they sound like one band is the open
  question for the operator; it is the risk the long-form cut answers.
- About a third of takes have no air above 16 kHz; the gate catches it.
- Needs #1103 or new nodes: stems for vertical layers, one-arrangement intensity variants, repaint across seams.

## Operator verdicts

Pending (task 1.6). Listening page (private artifact, published 2026-11-17): https://claude.ai/artifact/HRtrGmNgT7rCM1fom8k9me — each section, and a console that drives the fight events through design §4.3 on a Web Audio clock.
