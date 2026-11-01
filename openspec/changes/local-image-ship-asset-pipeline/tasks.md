# Tasks

## 1. Preserve local model outputs

- [x] 1.1 Copy the local ship, cannon, and shield PNGs into a research-only source directory and verify their dimensions and hashes against the local generation results.
- [x] 1.2 Record prompts, negative prompts, model/version, tier, seeds, backend, license metadata, output dimensions, and observed quality limitations; verify the manifest matches all three sources and update `FORGE_DIAGNOSTICS.md`.

## 2. Prepare deterministic candidates

- [x] 2.1 Add a local-only preparation command that creates bounded-palette nearest-neighbor previews and a JSON validation report without changing shipping game assets; verify it runs on the checked-in sources and reports opaque backgrounds as rejected.
- [x] 2.2 Add a locally served review page showing raw sources, pixel previews, per-asset provenance, and validation outcomes; verify every displayed asset is loaded from the research output.

## 3. Local preview integration

- [x] 3.1 Build the Flutter web app and publish it to the managed local preview; verify the game root and review page are both served at their documented local paths.
- [x] 3.2 Inspect the generated contact sheet and host-browser request logs, correct any broken asset paths, and record the visual result and remaining limitations in `FORGE_DIAGNOSTICS.md`.

## 4. Astra prompt and background comparison pass

- [x] 4.1 Have the Astra prompt-design agent derive seven sprite prompts and two background prompts from the project art guides; record prompts and local generation provenance.
- [x] 4.2 Extend local processing and the review page to show the additional sprite candidates and current-vs-generated portrait backgrounds.
- [x] 4.3 Inspect the side-by-side compositions and record rejection reasons without replacing production artwork.

## 5. Large-host model tier comparison

- [x] 5.1 On the RTX A5000 host, follow the tool's bigger-tier offer flow (user-approved) to tier I1 (SDXL-Lightning-4step); record that no I2/I3 offer was returned afterwards.
- [x] 5.2 Re-run the seven Astra sprite prompts and two background prompts at I1 with the same seeds (two images each, 4 steps, 1024² sprites / 832×1216 backgrounds) and preserve raw outputs, hashes, and per-candidate generator provenance in the manifest.
- [x] 5.3 Extend the processor with per-candidate model/tier metadata and the review page with an I0-vs-I1 side-by-side comparison; record visual review notes without replacing production artwork.

## 6. Automated ship asset pipeline (I0 plumbing)

- [x] 6.1 Add `tools/asset_pipeline/` (plan/ingest/process/review/accept/pack) with a `ship` family spec: hull plus combinable weapon modules on a shared 48×48 canvas.
- [x] 6.2 Generate 24 I0 candidates sequentially, then ingest, process, and QA-grade them; publish the review gallery with loadout and wear sheets.
- [x] 6.3 Pack a provisional `ship-parts.png` and draw it in-game as layered modules with wear states and jettisoned critical parts; keep the code-drawn fallback; analyzer clean, 131 tests pass.
- [ ] 6.4 Human acceptance of each part (blocked on review).
- [x] 6.5 Re-run the queue at I1 (24 more candidates in the same gallery; 5 of 6 provisional picks now I1); the shield gets a violet critical ramp per the style guide.
- [ ] 6.6 Re-run at I2/I3 once offered (operator pre-approved the ladder).
