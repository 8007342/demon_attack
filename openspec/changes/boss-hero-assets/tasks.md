# Tasks

## 0. Research and smoke (done in this change)
- [x] 0.1 Research macron.dev's Blender + ComfyUI route; record in `plan/round2-research.md` §1–§2
- [x] 0.2 Prove Blender in this forge: `bpy==5.3.0` on Python 3.13 via uv; `tools/boss_rig/bpy_smoke.py` renders 3 × 3 views (clay, depth) in 47 s; sheet `art/contact/boss-hero-bpy-smoke.png`

## 1. Setup and grammar
- [x] 1.1 `tools/boss_rig/setup_bpy.lua`: idempotent uv Python 3.13 + venv + `bpy==5.3.0` in `~/.cache/tillandsias-project/bpy-venv` (preflight of every run)
- [x] 1.2 `art/families/boss-hulls.json` (schema `demon-attack.boss-hulls/v1`): module catalogue as bpy primitive recipes, five tour assemblies, seeded-assembly rules, palettes, originality word list (design §4)
- [x] 1.3 `tools/boss_rig/build.py --check`: grammar validation (symmetry, budgets, anchors unobstructed)

## 2. Rig (CPU) and B0
- [x] 2.1 `tools/boss_rig/build.py`: per hull, 9 views × S0–S3 clay / depth / normal / module-ID passes and `anchors.json`; one process, `-t 8`
- [x] 2.2 Anchor gate: functional anchors within ±3 units of `BossAtlas` in every view (fails the build otherwise)
- [ ] 2.3 Fallback: `tools/ground_blocks boss` verb producing the same passes and anchors by ray casting (Go), with a parity test on the frigate
- [x] 2.4 B0 sheet `art/contact/boss-rig-turntables.png`; operator review

## 3. Heroes (GPU) and B1
- [x] 3.1 Commit `art/workflows/sprites/boss-hero-sdxl-cn.json` (SDXL + ControlNet-union depth + IP-Adapter plus) before its first run; the Qwen path reuses `heading-qwen-edit.json` (image 1 clay, image 2 today's atlas frame)
- [x] 3.2 Frigate pilot: 4 Qwen + 2 SDXL-CN candidates at 45°/0°, mattes, finish; B1 sheet `art/contact/boss-pilot-heroes.png`; log jobs in `boss-hulls-runs.json` and `plan/render-runs/boss-hero-assets.md`

## 4. Projection bake, stages and B2
- [x] 4.1 `tools/boss_rig/project_bake.py`: camera-project the hero onto the mesh from the hero view; render 9 views × modules with clay-tint fill for unseen faces
- [x] 4.2 Stage heroes S1–S3 by Qwen edit of the picked hero (2 candidates each), projected the same way; wrecks from geometry
- [ ] 4.3 Optional seam heal (SDXL-CN depth, denoise ≤ 0.3) gated by interior difference ≤ 12 % against the projection
- [x] 4.4 Finish and pack in `tools/boss_sheet pack` (deviation: the finish already ran in `boss_sheet bakefinish`; the pack lives beside it, not in `tools/ground_blocks`): palette quantise, mask ±1 texel, outline, rig lights / fires / breaches, module layers from ID masks, pages ≤ 4096 × 2048, generated `lib/game/boss_atlas.dart` with views, modules, stages, anchors
- [x] 4.5 B2 sheets `art/contact/boss-pilot-views.png`, `-stages.png`; budget check (≤ 16 MB RGBA)

## 5. All hulls and B3
- [ ] 5.1 Cruiser, battlecruiser, battleship, dreadnought through §3–§4 (one GPU job at a time; push after every checkpoint; selected raws committed under `art/sprites/sources/boss-selected/`)
- [ ] 5.2 B3 sheets `art/contact/boss-hulls-heroes.png`, `-views.png`
- [ ] 5.3 Offline rebuild test: atlases rebuild byte-identically from committed raws without GPU

## 6. Integration
- [ ] 6.1 Hand the atlases to `boss-grandeur` (view selection and module layers); retire `tools/generate_boss_sprites.py`
- [ ] 6.2 Record provenance in `plan/asset-provenance.md`

## Workflow follow-up
- Host/operator asks (non-blocking) in `plan/round2-research.md` §2.3: pinned Blender toolchain or reset-proof venv volume; confirmation of the CPU budget during GPU jobs.
- B4 acceptance happens in `boss-grandeur`'s in-game review; then `openspec archive boss-hero-assets`.
