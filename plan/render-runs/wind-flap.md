# Render run: the brood's wind-flap frames (weather-everywhere §5)

Date: 2026-11-18. Agent session for change `weather-everywhere`. No GPU, no model download, no studio job.

## Pipeline
- Rig: `tools/gargoyle_rig.py` via `tools/generate_sprites.py` (Pillow 13.0.0, numpy 2.5.5 in
  `~/.cache/tillandsias-project/asset-venv`, recreated with `python3 -m venv … && pip install pillow numpy scipy`).
- Determinism check first: 72 shipped `combat.png` flight cells (4 species × intact/m1 × 3 directions × frames
  0/3/8) re-rendered pixel-identical. So new frames match the shipped creatures exactly.
- Generator: `python3 -I tools/generate_wind_flap.py --sheets` (recipe `art/families/wind-flap.json`). A rerun
  reproduces `assets/images/wind-flap.png` byte for byte (md5 f2c44424…).
- Output: `assets/images/wind-flap.png` (1024 × 1536, 178 KB), `lib/game/wind_flap_atlas.dart`,
  `art/contact/wind-flap-candidates.png`, `art/contact/wind-flap-sheet.png`. Nothing else is committed: the frames
  are the render, there are no intermediate raws.

## Candidates (wind blowing right, teal and gold, against the calm flap)
| Id | k | Verdict |
|---|---|---|
| A | 0.55 | Rejected: at phone size (40 units) it reads as the ordinary flap. |
| **B** | **1.0** | **Picked**: the upwind wing clearly beats deeper and higher, the downwind wing tucks and sweeps back, the body leans in; the skull stays upright under the insignia. |
| C | 1.45 | Rejected: the downwind wing folds into the body on the upstroke (frames 4–6) and the silhouette shrinks. |

## Fit pass
With the first view (yaw 0.35, roll 1.3) and upwind sweep 8, frames 0 (raised) and 2 (full span) touched the 64-px
cell edge for teal, coral and gold (the wing tip would be clipped). Tried yaw 0.1–0.6, roll 1.0–1.3, sweep 0–8 and an
elevation cap; kept **upwind elevation ≤ 66°, sweep 4, yaw 0.45, roll 1.1**: no cell touches an edge, every species,
variant and side.

The operator overrides: change `pick` (or a candidate's `k`) in the recipe and rerun the generator.
