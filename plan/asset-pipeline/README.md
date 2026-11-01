# Local generative asset pipeline: research synthesis (2026-11-01)

Goal: produce many visually consistent game assets on local hardware: dynamic
backgrounds, animation frames, more detailed enemies, and VFX. Inference stays
local (RTX A5000 24 GB host), and every asset carries provenance.

Detailed reports in this folder:
- `models-24gb.md`: open models that fit 24 GB, with licences, VRAM, speed and tier picks.
- `consistency-techniques.md`: LoRA, edit-model, ControlNet, transparency, pixelization, backgrounds, VFX, QA and automation.
- Game asset contracts: summarised below, taken from `plan/sprite-atlas.md`, `plan/style-guide.md` and `lib/game/scene.dart`.

## Where we are

| Capability | State |
|---|---|
| Forge `image.generate` I0 SDXS / I1 SDXL-Lightning | Working on this host. I1 needs 1024² at 4 steps. |
| I2 FLUX.1-schnell Q4 / I3 FLUX.1-schnell Q8 (forge-defined, Apache-2.0) | Blocked: the host envelope lacks `accel_vram_gb`. Fix is Tillandsias PR #679. |
| ComfyUI "studio" sibling container (port 8188, HTTP API, no MCP yet) | Not on trunk yet (drafts #791/#793/#794). Our feature list is filed as a work order. |
| Deterministic post-processing (pixelize / palette / alpha / QA) | Only the review thumbnailer exists (`tools/prepare_local_image_candidates.py`). |

## What a drop-in asset must satisfy (the contract)

- RGBA with **binary alpha**, since hit flashes use `srcATop`. Drawn with `FilterQuality.none` at 2× logical size.
- Exact atlas cells: `combat.png` uses 64×64 cells (32 logical), `sentinel-effects.png` uses 128×64, and `boss-carrier.png` uses stacked 368×240 layers.
- **Complete frame sets with one identity**: demons have 4 wing frames, 4 angry frames and 3 molts per species. Sentinels have 8 hover poses plus warning, dive and last-stand frames. The carrier has 4 forms × layers. Explosions have 8 frames.
- Palette: outline #100E2C, teal #39DFCC, violet #A888FF, coral #FF786C, gold #EFBD57, ivory #FFF5C9. Thermal fire is never cyan or violet; force shields are never warm.
- Backgrounds keep the central 60% firing lane dark and contain no characters, ships, bullets or text. Today they are static 1024×1536 paintings under a 50% veil; all parallax is procedural.
- Originality: never trace or copy the 1982 game. Generated combat art must be logged in `plan/asset-provenance.md`. A person accepts each candidate before it ships.

## Licence filter (a public, shipped game)

Shippable (Apache/MIT, no thresholds), subject to the forge operator's own list:
FLUX.1-schnell, FLUX.2-klein-4B, Z-Image(-Turbo), Qwen-Image-2512 /
Qwen-Image-Edit-2511 (open question below), SDXL, Wan 2.2 (video), Qwen3-VL-8B
(judge), BiRefNet/BEN2 (matting), xinsir OpenPose ControlNet, Real-ESRGAN, and
Depth-Anything-V2-**Small**.

Never ship with: FLUX.1-dev and Kontext-dev (and LoRAs, ControlNets and Redux
trained on dev), FLUX.2-dev, klein-9B, Qwen-Image-2.1, SD3.5 (forge ruling),
RMBG-1.4/2.0, 4x-UltraSharp, Depth-Anything-V2 Base/Large, LayerDiffuse-Flux,
InsightFace/FaceID, and HunyuanImage/Video (territory exclusions).

Open question for the forge operator: the forge lists "Qwen-Image" as
never-shippable, but our research finds Qwen-Image-2512 and Edit-2511 under
Apache-2.0 (only 2.1 is non-commercial). Edit-2511 is the best open
"same character, new pose" model, so this ruling matters for animation.

## Proposed pipeline

```
style bible + palette ─┐
approved key art ──────┼─► [generate]  T2I (I2/I3 or ComfyUI + style LoRA), fixed seeds
pose rig / blockout ───┘        │      edit model for pose variants from ONE approved key frame
                                ▼
                         [isolate]  chroma-key bg → BiRefNet/BEN2 matte → binarize alpha, defringe
                                ▼
                         [pixelize] grid detect → nearest downscale to logical size → snap to palette
                                    → despeckle → 1px #100E2C outline   (deterministic, versioned)
                                ▼
                         [QA]      alpha/silhouette, palette compliance, size/cell fit,
                                    similarity to key frame, lane-darkness for backgrounds, local VLM judge
                                ▼
                         [review]  web/local-image-review gallery → human accept/reject
                                ▼
                         [pack]    atlas packer writes cells and provenance (model sha, workflow, seed, LoRA, scores)
```

By asset family:
- **Enemies and animation**: a character LoRA per species, plus edit-model pose variants from the approved key frame (never chained), plus ControlNet from a simple rig. Wan 2.2 first/last-frame clips work for loops; extract frames and snap them to the grid.
- **Backgrounds**: generate far, mid and horizon layers separately with alpha, close vertical seams by roll-and-inpaint, run a lane-darkening pass plus an automated luminance check, and use Real-ESRGAN only for painted layers. This needs a code change for layered, per-route backgrounds (`sector_background.dart`).
- **VFX**: stay procedural for projectiles, sparks and shields. Use generated flipbooks only for big, rare effects such as boss death and carrier breakup.
- **Style consistency**: train a house style LoRA (ai-toolkit/kohya) on 20–60 approved assets and retrain as the approved set grows. This is the single most useful investment.

## Build order

0. **Now, no new models needed**: deterministic isolate/pixelize/palette/QA scripts run over the existing I1 raws, with review-gallery accept/reject and a provenance schema v2.
1. **When #679 lands**: run the consented I2/I3 ladder on the same prompts and seeds, benchmark it, and report back to the forge as validation.
2. **When ComfyUI studio lands**: add versioned API workflow templates (T2I, edit, ControlNet, matte), a batch runner, and model/licence allowlist checks.
3. Train the first style LoRA on accepted assets, then a character LoRA for one demon species and a full frame set as a vertical slice.
4. Code: layered dynamic backgrounds, then generated large-VFX flipbooks.
