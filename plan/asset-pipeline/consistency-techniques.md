# Local generative 2D asset pipeline for a Flutter/Flame vertical shooter

Target: RTX A5000 24 GB, ComfyUI driven over HTTP/WebSocket by scripts or agents, shipping a public commercial game.
Date of research: 2026-11-01. Web search worked. Each license claim is marked:

- **[V]**: verified this session from a model card, official repo, or several agreeing sources (URLs given).
- **[S]**: secondary source only. Check the LICENSE file before shipping.
- **[K]**: from prior knowledge, not re-checked this session. Treat as unverified.

Not legal advice. Before shipping, check the license of every weight file you actually download (by its hash). Repackaged mirrors often mislabel licenses.

---

## 0. TL;DR architecture

```
approved art (20-60 imgs) ──► style LoRA (ai-toolkit / kohya) ──┐
fixed palette (.gpl/.hex) ───────────────────────────────────────┤
                                                                 ▼
 job spec (YAML) ─► template renderer ─► ComfyUI API (/prompt, ws) ─► raw PNG (+ embedded workflow)
                                                                 │
          ┌──────────────────────────────────────────────────────┘
          ▼
 transparency  (chroma-key gen + BiRefNet/BEN2 matte, or LayerDiffuse on SDXL)
          ▼
 pixelize      (downscale to grid → k-means/enforce fixed palette → 1px outline → alpha binarize)
          ▼
 QA scoring    (alpha/silhouette, palette ΔE, DINOv2/CLIP similarity to reference, local VLM judge)
          ▼
 review gallery (accept / reject / send-to-Aseprite) ─► Aseprite CLI pack ─► Flame sprite sheets
          ▼
 provenance manifest (model sha256, LoRA versions, workflow hash, seed, scores, reviewer)
```

**Recommended permissive base-model stack**

| Role | Model | License | Notes |
|---|---|---|---|
| Primary T2I, fast | Z-Image-Turbo (6B, Tongyi-MAI) | Apache-2.0 **[V]** https://huggingface.co/Tongyi-MAI/Z-Image-Turbo, https://github.com/Tongyi-MAI/Z-Image | Few-step, fits 24 GB. LoRA training support in ai-toolkit **[K]** |
| Primary T2I, prompt-faithful | Qwen-Image (20B MMDiT) | Apache-2.0 **[K]** | 24 GB needs fp8/GGUF. LoRA training on 24 GB works with quantization **[S]** https://www.runcomfy.com/trainer/ai-toolkit/qwen-image-2512-lora-training |
| Edit / pose variants | Qwen-Image-Edit (2509/2511) | Apache-2.0 **[S]** https://builderai.tools/blog/ai-image-editing-flux-kontext-qwen-image-edit-step1x | Best permissive alternative to Kontext |
| Small, fast T2I + edit | FLUX.2 [klein] **4B** | Apache-2.0 **[V]** https://huggingface.co/black-forest-labs/FLUX.2-klein-4B | **9B klein is non-commercial [V]** |
| Mature ecosystem (ControlNet, IP-Adapter, LayerDiffuse, pixel LoRAs) | SDXL 1.0 base | CreativeML Open RAIL++-M **[K]**: commercial OK, use-based restrictions | Most tooling exists here. Good for the pixel-art path |
| Video / frame sequences | Wan 2.2 (TI2V-5B fits 24 GB; 14B with fp8/offload) | Apache-2.0 **[V]** https://github.com/Wan-Video/Wan2.2 | |
| Local VLM judge | Qwen3-VL-8B-Instruct | Apache-2.0 **[V]** https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF | |

**Avoid for shipped assets unless you buy a BFL license:** FLUX.1 [dev], FLUX.1 Kontext [dev], FLUX.1 Redux/Fill [dev], FLUX.2 [dev] and FLUX.2 klein 9B. All are under the FLUX (dev) Non-Commercial License. The output clause is disputed: one revision says outputs may be used commercially, another revision removed that line **[V that a dispute exists]** https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev, https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev/discussions/6. FLUX.1 [schnell] is Apache-2.0 **[K]** and can be used.
Community SDXL finetunes (Illustrious, Pony, NoobAI) have their own licenses with extra terms. Not checked this session **[K]**: review each one.

ComfyUI itself is GPL-3.0 **[K]**. That covers the tool, not your outputs. Custom-node code licenses (GPL, MIT, Apache) also don't affect your images, but read node READMEs for any weights they auto-download.

---

## 1. Style consistency across an asset family

**Most reliable approach: a style LoRA trained on your own approved art.**

- **Trainers.** All run locally on 24 GB.
  - **ai-toolkit (ostris)**: MIT **[K]**. Supports Z-Image, Qwen-Image, FLUX.2 klein, Wan, SDXL. YAML configs that are easy to template. https://github.com/ostris/ai-toolkit
  - **kohya sd-scripts / kohya_ss**: Apache-2.0 **[K]**. Best for SDXL. Official doc says SDXL LoRA trains in 8-10 GB **[V]** https://github.com/kohya-ss/sd-scripts/blob/main/docs/train_SDXL-en.md
  - **OneTrainer**: AGPL-3.0 **[K]**. GUI plus CLI. Covers SDXL, FLUX and others.
  - **SimpleTuner**: AGPL-3.0 **[K]**. Strong for FLUX, SD3 and Wan. Script-driven.
  - Trainer licenses don't apply to the LoRA you produce.
- **Dataset.**
  - Style LoRA: 20-60 curated images of *your* approved assets **[S]** (https://localaimaster.com/blog/image-lora-training-local-guide). Use several subjects (ships, demons, props) so the LoRA learns the style, not one object. Mix in the backgrounds you've approved.
  - Train at the model's native resolution. For SDXL that's 1024. Upscale pixel art with nearest-neighbor first, so each art pixel is a clean 8×8 block and isn't blurred.
- **Captions.**
  - Start every caption with a unique trigger token (`dmnatk_style`). Then describe the *content* only ("a horned demon sprite, front view, plain magenta background"). Leave out style words, so the style gets absorbed into the trigger.
  - Auto-caption with Qwen3-VL or Florence-2 (MIT **[K]**), then hand-edit.
- **Time on an A5000.** The A5000 is roughly 60-70% of a 4090 **[K]**.
  - SDXL LoRA, ~40 images, ~2-3k steps: roughly 1-2 h.
  - Z-Image or klein-4B LoRA: about 1-3 h.
  - Qwen-Image LoRA with 3-bit/ARA quantization at 1024: about 3-6 h.
  - All estimates **[S/K]**. Published figures range from 20 min to 3 h for SDXL on 24 GB.
- **Iterate.** Generate, approve the best outputs, add them to the dataset, retrain v2. This bootstrap loop is the main lever for consistency. Version the LoRAs (`style_v3.safetensors` plus sha256 in the manifest).

**Reference-image conditioning (no training).** Use it for quick exploration or to steer one asset.

- **IP-Adapter (SDXL)**
  - ComfyUI node pack `ComfyUI_IPAdapter_plus` (cubiq): GPL-3.0 code **[V]** https://github.com/cubiq/ComfyUI_IPAdapter_plus. Nodes: `IPAdapterUnifiedLoader`, `IPAdapterAdvanced` with `weight_type: style transfer` or `style transfer precise`, `IPAdapterStyleComposition`.
  - Weights from h94/IP-Adapter: the Tencent code is Apache-2.0 **[V]** https://github.com/tencent-ailab/IP-Adapter. The weights' license wasn't confirmed this session (Apache-2.0 per the HF card **[K]**).
  - **FaceID variants depend on InsightFace models, which are non-commercial. Avoid them.**
- **FLUX Redux**: dev license, non-commercial. Avoid.
- **Edit-model style transfer.** Give Qwen-Image-Edit or FLUX.2 klein 4B a style reference image plus "same art style" instructions. Multi-image input is in the Qwen-Image-Edit 2509+ ComfyUI nodes `TextEncodeQwenImageEditPlus` **[K]**.
- **Reference-only / StyleAligned.** SDXL "reference-only" attention sharing via `ComfyUI-Advanced-ControlNet` (`ReferenceCN`) **[K]**. StyleAligned (Google, Apache-2.0 **[K]**) shares attention across a batch, so all images in one batch share a style. Useful for generating a whole asset family in one batch.

**Deterministic controls**

- Fixed seeds per asset ID, stored in the manifest. Fixed sampler, scheduler, steps and CFG per template.
- One locked **master palette** (e.g. 32 colors) enforced in post-processing (§4), not just requested in the prompt. Palette enforcement adds more consistency than any prompt tweak.
- Prompt template with fixed style prefix and suffix, plus a fixed negative prompt for SDXL. Only the subject slot varies.
- Same canvas size per asset class. Same chroma background color in the prompt.

---

## 2. Character consistency for animation frames

The order below runs from most to least controllable.

1. **Character LoRA per hero asset.**
   - Train it for the player ship and each boss: 10-30 images, built by curating early generations and hand-fixed frames. Stack it with the style LoRA (style 0.8, character 0.9).
   - Highest consistency. Costs about 1-2 h of training per character.
2. **Edit models for pose and state variants.**
   - Start from the approved key frame, then instruct: "same demon, wings raised", "same ship banking left 15°", "damaged version with cracks".
   - **Qwen-Image-Edit 2509/2511**: Apache **[S]**. Native ComfyUI nodes `TextEncodeQwenImageEdit` / `...Plus`, `QwenImageDiffsynthControlnet`, plus Lightning 4- or 8-step LoRAs for speed **[K]**.
   - **FLUX.2 klein 4B**: Apache **[V]**. Supports multi-reference editing **[S]**.
   - FLUX.1 Kontext [dev]: best known for this job, but **non-commercial license**. Avoid, or buy the license.
   - Edit-model drift builds up when you chain edits. Always edit **from the key frame**, never from the previous edit.
3. **ControlNet from a rig or 3D blockout.**
   - Build a cheap rig in Blender (Blender is GPL; outputs are yours) or just a 2D stick rig. Render per-frame OpenPose skeletons, depth maps or lineart.
   - SDXL: `xinsir/controlnet-openpose-sdxl-1.0` is Apache-2.0 **[V]** https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0. `xinsir/controlnet-union-sdxl-1.0` covers 10+ control types. Its license wasn't confirmed this session (Apache-2.0 **[K]**).
   - Preprocessors: `comfyui_controlnet_aux` (Fannovel16) **[K]**. Check each annotator: DWPose and OpenPose weights carry their own terms. If you render skeletons from your own rig you need no annotator at all.
   - Qwen-Image: the native "DiffSynth" ControlNets (canny, depth, inpaint) model patches **[K]**.
   - Non-humanoid demons (bats, birds, blobs) fit OpenPose poorly. **Depth or lineart from a blockout works better.** Silhouette plus lineart ControlNet gives frame-locked shapes.
4. **Sprite sheet in one image.**
   - Prompt for "a 4-frame sprite sheet, 4 columns, same character, flapping wings", or use a ControlNet grid of 4 poses on one canvas.
   - All frames share one diffusion pass, so palette and detail stay coherent. Works well with Qwen-Image and edit models. Slice afterwards with a fixed grid.
   - Weakness: the grid isn't always regular. Fix by conditioning with an explicit grid layout (depth or lineart of N silhouettes in cells).
5. **Video models then frame extraction.**
   - **Wan 2.2** (Apache **[V]**). The TI2V-5B and I2V-14B models (fp8/GGUF via `ComfyUI-WanVideoWrapper` (kijai) or native ComfyUI Wan nodes **[K]**) turn a key frame into a short loop: "demon flaps wings, static camera, plain green background".
   - Extract 4-8 evenly spaced frames, or pick by motion, with ffmpeg or `VHS_VideoCombine` / `Load Video` from `ComfyUI-VideoHelperSuite` **[K]**. Then run every frame through the same matte and pixelize steps.
   - Video gives very smooth motion but blurs fine detail. Good for wing flaps, idle bobs and boss "breathing", weaker for snappy arcade poses.
   - **AnimateDiff** (SD1.5/SDXL; code Apache-2.0 **[K]**, motion-module licenses vary **[K]**) is older. Prefer Wan.
   - First-last-frame (FLF2V) mode in Wan lets you give the start and end key poses and have it fill the in-betweens **[K]**.

**Practical recipe for a 4-frame enemy**

1. Key frame from T2I with style LoRA.
2. Human approves it.
3. Qwen-Image-Edit makes 3 pose variants from the key frame, or Wan I2V makes a loop and you pick 4 frames.
4. Matte (§3), pixelize to the shared palette (§4).
5. Aseprite touch-up (§4).

Very few animation frames make it to shipping without a quick manual pass. Budget a few minutes per frame.

---

## 3. Transparency

**Option A (recommended default): chroma background, then matting model, then edge cleanup.**

- Prompt for "isolated on a flat solid #FF00FF background" (or #00FF00 for magenta-heavy demons). Pick a key color that isn't in the palette.
- Remove the background with a matting model:
  - **BiRefNet** (ZhengPeng7): MIT **[S]** https://huggingface.co/zurg70/birefnet-desktop-models (secondary; check https://github.com/ZhengPeng7/BiRefNet LICENSE). General, HR and matting variants.
  - **BEN2 base** (PramaLLC): MIT **[S]**. A paid "full" model also exists.
  - **InSPyReNet / transparent-background**: MIT **[K]**.
  - **rembg** code MIT, U²-Net Apache-2.0 **[K]**.
  - **BRIA RMBG-2.0: CC BY-NC 4.0, non-commercial. Avoid** **[V]** https://github.com/Bria-AI/RMBG-2.0. The same applies to RMBG-1.4 (BRIA non-commercial license) **[K]**.
- ComfyUI node pack `ComfyUI-RMBG` (1038lab) wraps BiRefNet, BEN/BEN2, INSPYRENET, SAM and more **[V]** https://github.com/1038lab/ComfyUI-RMBG. It also exposes RMBG-2.0, so pin the model choice in your templates. `ComfyUI-BiRefNet` and `ComfyUI_essentials` (`RemBG Session`) are alternatives **[K]**.
- **Pixel-art edge cleanup** happens in your own Python step, which beats any node:
  1. Matte at high resolution.
  2. Downscale the alpha with the image (§4).
  3. **Binarize alpha** with a threshold around 0.5. Pixel sprites want 1-bit alpha.
  4. Erode 1 px to remove key-color fringes, then **despill**: any pixel within ΔE < X of the key color becomes transparent.
  5. Add the outline (§4).
  6. Optionally use the chroma key itself as a second mask and AND it with the model mask. That combination is robust.

**Option B: native transparent generation (LayerDiffuse).**

- `ComfyUI-layerdiffuse` (huchenlei): Apache-2.0 code **[V]** https://github.com/huchenlei/ComfyUI-layerdiffuse. Original code Apache-2.0 **[V]** https://github.com/lllyasviel/LayerDiffuse.
- SDXL only for mature use (`LayeredDiffusionApply` with the "SDXL, Attention Injection" config, then `LayeredDiffusionDecodeRGBA`).
- Weight license: the main LayerDiffuse weights come out of SDXL and are treated as CreativeML Open RAIL-M-ish. One mirror warns of extra restrictions **[S]** https://huggingface.co/Geeknasty/LayerDiffusion-SDXL-Attn-Diff. Check the lllyasviel/LayerDiffuse HF card before shipping.
- **LayerDiffuse-Flux** (FireRedTeam) is built on FLUX.1-dev, so it inherits the non-commercial license. Avoid **[S]** https://github.com/FireRedTeam/LayerDiffuse-Flux.
- Gives real soft alpha (glows, smoke). That's useful for VFX stills, less so for hard pixel sprites. Option A is simpler, model-agnostic, and works with any base model.

---

## 4. Pixel-art conversion

The goal is *hard* pixel art: a regular grid, a limited fixed palette, 1-bit alpha and clean outlines. Diffusion output is never on-grid, so post-processing has to be deterministic.

1. **Generate "pixel-ish".**
   - Use a pixel-art LoRA plus your style LoRA. Example: `nerijs/pixel-art-xl` (SDXL), CreativeML Open RAIL++-M **[K]**. Many CivitAI pixel LoRAs carry "no commercial use" or "no selling images" flags, so check each one **[K]**.
   - A style LoRA trained on your own pixel art (nearest-neighbor upscaled) beats generic pixel LoRAs.
   - Prompt for "pixel art, 1px black outline, flat shading, limited palette, no anti-aliasing".
2. **Detect the grid and downscale.**
   - **ComfyUI-PixelArt-Detector** (dimtoneff) wraps Astropulse's pixeldetector, a palette loader from an image, and a palette converter using PIL quantize, OpenCV k-means or MAXCOVERAGE **[V]** https://github.com/dimtoneff/ComfyUI-PixelArt-Detector. Stale: about 3 years without updates.
   - **ComfyUI-PixelGridHelpers** (molbal) is newer. It has Autofixer (grid recovery, palette limit, speck removal), Quantize, Analyze Palette and **Enforce Palette** nodes, with no extra dependencies **[V]** https://github.com/molbal/ComfyUI-PixelGridHelpers. Licenses of both packs not checked **[K: verify]**.
   - Core `ImageQuantize` node: color count plus dithering, no fixed palette **[V]** https://docs.comfy.org/built-in-nodes/ImageQuantize.md.
   - **Recommendation:** run this step as your own Python script (Pillow + numpy + scikit-image, all BSD/MIT-family). That keeps it deterministic and testable:
     a. Estimate the pixel scale from the generation: autocorrelation or edge-gradient periodicity, or Astropulse pixeldetector (MIT **[K]**).
     b. Downscale with *mode/median per cell*, not bilinear, to the target sprite size (e.g. 32×32 enemies, 48×64 boss parts).
     c. Map each pixel to the nearest color in the **fixed master palette** in CIELAB (ΔE2000). Optionally k-means to N colors first, then snap the clusters to the palette, which reduces noise.
     d. Remove orphan pixels (single pixels that differ from all 8 neighbors) and fix alpha (§3).
     e. **Outline enforcement:** dilate alpha by 1 px, and paint the ring pixels with the palette's outline color, which may be a darkened hue per region. Optionally add selective outlining (lighter on the lit side).
     f. Export an indexed PNG.
3. **Hand-off to Aseprite.**
   - Aseprite is a commercial EULA product (paid, source-available) **[K]**. Using it as a tool is fine. LibreSprite is a GPL fork.
   - CLI: `aseprite -b --script-param in=frames/ --script pack.lua`, or `aseprite -b f1.png f2.png --sheet sheet.png --data sheet.json --sheet-type packed --format json-array` **[K]**. Lua scripts can set the palette (`app.command.LoadPalette`), build tags per animation, and export.
   - Workflow: the pipeline writes `asset.aseprite` with a palette and frame tags. The artist touches up and saves. The pipeline re-exports the sheet plus JSON for Flame (`SpriteAnimation.fromAsepriteData` exists in flame **[K]**, or a custom loader).
   - Keep the `.aseprite` file as the source of truth after manual edits. Never regenerate over it.

---

## 5. Backgrounds (vertical scroll)

- **Seamless vertical tiling**
  - Circular (wrap) padding on conv layers during sampling: `ComfyUI-seamless-tiling` (spinagon) provides `SeamlessTile` and `CircularVAEDecode`, with x-only, y-only or both **[K: node names unverified]**. Use **y-only** for vertical scrolling.
  - This works for UNet models (SDXL). For DiT models (Qwen, Z-Image, FLUX) the circular-padding trick is weaker. Use the **roll-and-inpaint** method instead, which is model-agnostic and robust:
    1. Generate the strip.
    2. Roll it by H/2 so the seam sits in the middle.
    3. Inpaint a 15-20% band over the seam with a mask.
    4. Roll it back.
  - Check seamlessness automatically: stack the tile twice and measure the gradient discontinuity at the join.
- **Extending length.** Outpaint upward in chunks: keep the top 25% of the previous tile as context, outpaint the next tile, and repeat. Inpainting uses core `VAEEncodeForInpaint` / `InpaintModelConditioning`, or Qwen/klein edit models **[K]**. Finish with roll-and-inpaint so the last tile wraps to the first.
- **Parallax layer separation**
  - **Depth Anything V2 *Small* only: Apache-2.0. Base, Large and Giant are CC-BY-NC-4.0, so avoid them** **[V]** https://github.com/DepthAnything/Depth-Anything-V2. An open issue questions training-data provenance **[V]** https://github.com/DepthAnything/Depth-Anything-V2/issues/320.
  - Node: `comfyui_controlnet_aux` `DepthAnythingV2Preprocessor` (choose `depth_anything_v2_vits`) **[K]**.
  - Threshold depth into 3-4 bands (far nebula, mid asteroids/structures, near debris). Cut each band with alpha, then **inpaint the holes** left behind in the farther layers so they can scroll independently.
  - **Generating layers separately is usually cleaner than splitting one image.** Do it as: (a) a starfield/nebula pass, (b) mid-layer objects on chroma, matted, (c) near-layer debris on chroma, matted. Use depth splitting only for painted single images you already love.
- **Dark central firing lane**
  - At generation time, condition with a luminance or depth ControlNet map that's dark in the center column: xinsir union "tile/blur" or a depth map with the center pushed "far" **[K]**. Or apply a mask that inpaints the center band with "empty dark space".
  - Post-generation and deterministic (recommended as a guarantee): darken and desaturate a center column with a soft falloff, then QA it. The **mean luminance of the lane must be below the threshold** and contrast against sprites must stay above X.
  - Simplest runtime fix: a vignette or lane overlay in Flame, so the art doesn't have to be perfect.

---

## 6. VFX: generative vs procedural

| Effect | Recommendation | Why |
|---|---|---|
| Projectiles (bullets, lasers) | **Procedural or hand-drawn**, 2-4 frames | Tiny (4-16 px), need exact palette and readability. Diffusion adds nothing |
| Muzzle flashes, hit sparks | Procedural particles (Flame `ParticleSystemComponent`, `ComputedParticle`) | Cheap, random variety each time, tunable |
| Shields / force fields | **Fragment shader** (Flutter `FragmentProgram`, `.frag`): fresnel ring, hex pattern, hit ripple at impact UV | Must react to hit position and health. Animated, resolution-independent |
| Explosions (small enemies) | Procedural (particles + palette-cycled circles) **or** a short generated flipbook | Particles win on variety. Pixel-art flipbooks win on style |
| Boss death / big explosions | **Generative flipbook**: Wan 2.2 I2V "explosion on black", extract 8-12 frames, use luminance as alpha (or LayerDiffuse SDXL for soft alpha), pixelize to palette | Rare, high-impact, worth the art budget |
| Backdrop ambience (nebula drift, ranitas) | Shader or parallax motion | Continuous motion. Video frames would loop visibly |

Rule of thumb: **procedural wins when the effect is small, frequent, must react to gameplay, or must vary**. **Generative wins when the effect is large, rare, and carries style** (boss intro, death, splash art). Generate on black and derive alpha from luminance for additive-blend effects. That's simpler than matting.

---

## 7. Automation and QA

**Driving ComfyUI**

- Export workflows in **API format** (Dev mode, "Save (API)"). Keep them as templates in git, e.g. `pipelines/comfy/sprite_t2i.v3.json`. Parametrize with placeholders that a renderer fills from a job spec: seed, prompt, LoRA name and strength, size, model filename.
- Endpoints **[K]** (stable for years, docs: https://docs.comfy.org):
  - `POST /prompt {prompt, client_id}` returns `prompt_id`.
  - `ws://host:8188/ws?clientId=…` for progress and `executed` events.
  - `GET /history/{prompt_id}`, then `GET /view?filename=…&type=output`.
  - `POST /upload/image` for reference and control images.
  - `GET /object_info` to validate templates against the installed nodes in CI.
  - `GET /queue` and `POST /interrupt`.
- Batch queue: a small Python runner (`websocket-client` + `requests`) reads `jobs/*.yaml`, enqueues, collects outputs into `raw/{asset}/{variant}/{seed}.png`, and retries failures. Keep one ComfyUI instance per GPU; ComfyUI queues internally.
- Pin custom nodes by commit (a `custom_nodes.lock` file, or comfy-cli `comfy node snapshot` **[K]**). Pin model files by sha256.

**Automated scoring.** Each check writes to `report.json`.

1. **Alpha and silhouette:**
   - Percent of opaque pixels within range.
   - Single connected component (or N expected).
   - Not touching the canvas edge (no cropping).
   - Bounding-box aspect within range.
   - Silhouette readable at 1× (filled-area / convex-hull ratio).
   - No semi-transparent pixels after binarization.
2. **Palette compliance:** 100% of opaque pixels are in the palette after snapping. Also report the *pre-snap* mean ΔE: high values mean the generation fought the palette, which is a reject signal. Color count ≤ budget.
3. **Consistency to reference:**
   - **DINOv2** (Apache-2.0 **[K]**) embedding cosine similarity to the approved key frame or style set.
   - CLIP / OpenCLIP (MIT **[K]**) for prompt adherence.
   - **LPIPS** (BSD-2 **[K]**) between consecutive animation frames: should be small but not zero. DreamSim (MIT **[K]**) is an alternative.
4. **Aesthetic:** LAION aesthetic predictor v2 (MIT **[K]**). Weak for pixel art, so use it only as a tie-breaker.
5. **VLM-as-judge:**
   - **Qwen3-VL-8B-Instruct** (Apache-2.0 **[V]**), local via llama.cpp, vLLM or Ollama (GGUF). It shares the 24 GB with ComfyUI, so run it in a separate pass after generation, or unload models between passes (`POST /free` **[K]**).
   - Give it a rubric with a JSON schema: "Is this a single {subject} facing down? Any text/watermark? Extra limbs? Matches reference style (1-5)? Background fully removed?"
   - Use the VLM for *rejection*, not final approval.
6. **Background-specific:** seam discontinuity score, lane luminance, lane clutter (edge density in the lane).

**Human-in-the-loop gallery.** Extend the existing `web/local-image-review/`. Show a static HTML page with a grid per asset showing raw, matted and pixelized versions at 1×/4× on a dark game background, plus scores. Accept, reject and "needs touch-up" buttons write to a decisions JSON. Accepted assets go into the LoRA dataset for the next retrain.

**Provenance manifest.** One per output, plus a rolled-up `manifest.json`:

```json
{ "asset_id": "ordinary-demon/fly/f2", "output_sha256": "…",
  "workflow": {"template": "sprite_t2i", "version": "v3", "sha256": "…"},
  "comfyui_commit": "…", "custom_nodes": {"ComfyUI-RMBG": "abc123"},
  "models": [{"role":"base","file":"z_image_turbo_bf16.safetensors","sha256":"…","license":"Apache-2.0"},
             {"role":"lora","file":"dmnatk_style_v3.safetensors","sha256":"…","strength":0.8}],
  "seed": 1234567, "prompt": "…", "negative": "…", "sampler": "euler", "steps": 8, "cfg": 1.0,
  "post": {"pixelize": "v2", "palette": "master32.gpl", "matte_model": "BiRefNet-general"},
  "scores": {"palette_dE_pre": 6.1, "dino_sim": 0.83, "vlm": {"pass": true}},
  "review": {"by": "…", "decision": "accept", "touched_up": true} }
```

ComfyUI embeds the workflow in PNG `tEXt` chunks. Keep that metadata in raw outputs, and strip it from shipped assets with an optimizer such as `oxipng --strip all`. Add a CI license gate: every model in a shipped asset's manifest must be on an allowlist of license IDs.

---

## 8. Upscalers

For **pixel art, don't use AI upscalers**. Use integer nearest-neighbor scaling at runtime (Flame `FilterQuality.none`). Use AI upscalers only for painted backgrounds, splash art, or before matting, for better edges.

| Model | License | Status |
|---|---|---|
| Real-ESRGAN x4plus / x4plus_anime_6B / realesr-general-x4v3 | BSD-3-Clause **[V/S]** https://github.com/xinntao/Real-ESRGAN | **Safe** |
| 4x-UltraSharp (Kim2091) | **CC BY-NC-SA 4.0** **[V]** https://huggingface.co/Kim2091/UltraSharp, https://openmodeldb.info/models/4x-UltraSharp | **Non-commercial. Avoid.** Some mirrors mislabel it as BSD |
| SwinIR / HAT / DAT originals | Apache-2.0 **[K]** (models trained on DIV2K/DF2K, which may carry research-only terms **[K]**) | Probably OK. Check |
| OpenModelDB community models (e.g. Nomos, 4x-NMKD, ClearReality, Remacri) | Per model, CC0 / CC-BY / CC-BY-NC / WTFPL **[K]** | Filter by license on https://openmodeldb.info |
| SUPIR, CCSR (diffusion upscalers) | SUPIR non-commercial **[K]** | Avoid SUPIR |

ComfyUI: core `UpscaleModelLoader` + `ImageUpscaleWithModel` load ESRGAN-family `.pth`/`.safetensors` via spandrel **[K]**. For large backgrounds use `Ultimate SD Upscale` (ssitu, GPL **[K]**) with the style LoRA at low denoise (0.2-0.35), so added detail stays on-style.

---

## 9. Suggested build order

1. **Post-processing first** (no new models): Python pixelize, palette-snap, alpha-binarize and outline scripts, plus QA metrics, run on the existing raw candidates in `assets/research/local-image-pipeline/raw/`. Biggest quality jump, fully deterministic.
2. Chroma-background prompts plus BiRefNet/BEN2 via ComfyUI-RMBG: transparency solved.
3. ComfyUI API runner plus versioned templates plus the manifest writer. Extend the existing review gallery.
4. Style LoRA v1 on Z-Image-Turbo or SDXL from about 30 approved sprites. Retrain as approvals grow.
5. Animation: Qwen-Image-Edit pose variants from key frames. Then try Wan 2.2 for wing-flap loops and boss explosions.
6. Backgrounds: separate layer generation, roll-and-inpaint seams, lane-luminance QA.
7. Local VLM judge pass and license-gate CI.

## 10. Open items to verify before shipping

- BiRefNet and BEN2 LICENSE files at the original repos (only secondary sources were seen).
- Qwen-Image and Qwen-Image-Edit LICENSE files (Apache claimed; the Qwen-Image base wasn't checked this session).
- xinsir controlnet-union license, IP-Adapter weight license, LayerDiffuse SDXL weight license, nerijs/pixel-art-xl license.
- Licenses of ComfyUI-PixelArt-Detector and PixelGridHelpers, and node names in ComfyUI-seamless-tiling.
- Whether Depth Anything V2 Small's training-data question affects you.
- Any CivitAI LoRA: read its "permissions" icons (sell images, commercial use).

### Sources
- https://huggingface.co/Tongyi-MAI/Z-Image-Turbo · https://github.com/Tongyi-MAI/Z-Image
- https://huggingface.co/black-forest-labs/FLUX.2-klein-4B · https://bfl.ai/blog/flux2-klein-towards-interactive-visual-intelligence · https://github.com/black-forest-labs/flux2/wiki
- https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev · https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev/discussions/6 · https://github.com/black-forest-labs/flux
- https://builderai.tools/blog/ai-image-editing-flux-kontext-qwen-image-edit-step1x
- https://github.com/Wan-Video/Wan2.2
- https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF
- https://www.runcomfy.com/trainer/ai-toolkit/qwen-image-2512-lora-training
- https://github.com/kohya-ss/sd-scripts/blob/main/docs/train_SDXL-en.md · https://localaimaster.com/blog/image-lora-training-local-guide
- https://github.com/cubiq/ComfyUI_IPAdapter_plus · https://github.com/tencent-ailab/IP-Adapter
- https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0 · https://huggingface.co/xinsir/controlnet-union-sdxl-1.0
- https://github.com/Bria-AI/RMBG-2.0 · https://github.com/1038lab/ComfyUI-RMBG · https://huggingface.co/zurg70/birefnet-desktop-models
- https://github.com/lllyasviel/LayerDiffuse · https://github.com/huchenlei/ComfyUI-layerdiffuse · https://github.com/FireRedTeam/LayerDiffuse-Flux · https://huggingface.co/Geeknasty/LayerDiffusion-SDXL-Attn-Diff
- https://github.com/dimtoneff/ComfyUI-PixelArt-Detector · https://github.com/molbal/ComfyUI-PixelGridHelpers · https://docs.comfy.org/built-in-nodes/ImageQuantize.md
- https://github.com/DepthAnything/Depth-Anything-V2 · https://github.com/DepthAnything/Depth-Anything-V2/issues/320
- https://huggingface.co/Kim2091/UltraSharp · https://openmodeldb.info/models/4x-UltraSharp · https://github.com/xinntao/Real-ESRGAN
