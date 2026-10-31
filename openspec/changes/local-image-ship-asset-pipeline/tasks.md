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
