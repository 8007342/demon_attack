# Refinement pilot (2026-11-13)

Three existing sprites redrawn with the big models on the A5000, for operator review before the full refinement run.

- Render: `art/workflows/sprites/variant-qwen-edit.json` (Qwen-Image-Edit-2511 fp8, Lightning 4-step), source sprite as the
  reference image, about 13 s per image at about 1 MP. Matte: `art/workflows/comms/matte-birefnet.json` (BiRefNet), about 4 s.
- `*-master.png`: high-res RGBA master. `*-game.png`: plain area downscale to the source size (no palette finish yet;
  the family pipelines do that). Provenance sidecars are beside each.
- Picks: gargoyle seed 641101 (641100 grew stray chains), turret 641200, rifleman 641300.
- Sheets: `review-gargoyle.png` and `review-allies.png` (source, then two seeds), `review-mattes.png`.
- The demon tank was left out on purpose: it is a generic WWII tank and waits for the gargoyle-army style guide.
