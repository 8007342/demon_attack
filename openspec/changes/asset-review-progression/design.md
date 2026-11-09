# Design

## Decisions

1. **Acceptance lives in `selections.json`.** The review page is static. It reads acceptance and progress from `report.json`, which `pipeline.py review` writes, so accepted state is recorded in the repository rather than in a browser. Only viewer conveniences (the hide switch and which sections are open) use `localStorage`, guarded so the page works without it.
2. **The selected ship uses at most one module per slot group.** The groups are nose (spread, large) and wing (rapid, powerful), declared in the family spec as `slot_groups`. A candidate replaces the selected module from its own group; the first accepted member in part order represents a group.
3. **Retirement deletes working files, not history.** `retire` removes raws, layers and masks for the listed tiers and records them under `retired_tiers` in `runs.json`. Git keeps the earlier files. Retiring a tier that an accepted part comes from is refused.
4. **Orientation is corrected deterministically.** FLUX-schnell runs without CFG and largely ignores negative prompts, so "pointing up" is not reliable. For parts with `"orient": "vertical"`, the processor takes the principal axis of the matte. If the object is elongated (axis ratio ≥ 1.4), it rotates the object upright and puts the narrower end on top, recording the angle as `rotated_deg`. Portrait generation sizes (`gen_size`, 576×1024) reduce how often rotation is needed.
5. **Wing fire moves the shot origin only.** Any wing powerup fits wing cannons, which own the primary shot even with a nose module. Spread keeps its angled pair at the nose, and large keeps enlarging the primary shot, so shot count and balance are unchanged. Without a wing powerup the nose fires and flashes (`noseFlash`). The model alternates `wingSide` on each primary shot and sets a 90 ms `wingRecoil` timer for that side. Fire interval, damage, speed and the steering sling are unchanged. The muzzle comes from `ship-parts.json` (`wing_muzzles`, the topmost opaque pixel of the docked left module), with model defaults when the metadata is missing. The scene draws each half of the wing layer separately so one side can kick back 1–2 px.

## Risks

- The alternating origin shifts single shots up to about 17 px sideways. It plays slightly differently near screen edges; campaign playtests still pass.
- The orientation heuristic can pick the wrong end for symmetric blobs. Those come out unrotated or flagged, and a person still accepts every part.
