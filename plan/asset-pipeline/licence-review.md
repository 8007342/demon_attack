# Local model licence review

> **Operator decision (2026-11-01, relayed by the host coordinator), verbatim:** "For our own projects we shall have a standing approval to use all of those free models, we'll not be selling any of those assets."
> This covers the allowlist-clean rows below for Tillandsias projects (demon_attack, kumbia-kombat). Rows flagged as problematic are excluded. Fetching still goes through the forge licence register, and gated click-through terms (FLUX.1-schnell) still need the operator's own acceptance. If any project's assets are later sold, revisit the OpenRAIL and use-restriction notes.


**Prepared for operator approval.** The operator approves each model against its official model card. This page is a record of what those cards say. It is not legal advice and it does not approve anything.

- Prepared: 2026-11-01
- Method: the operator asked for official cards only. Licence ids come from the publisher's own Hugging Face repo: the `cardData.license` field in `https://huggingface.co/api/models/<repo>`, checked against the README front matter (`/raw/main/README.md`) or the rendered card page. GitHub code licences come from `https://api.github.com/repos/<repo>/license`, which reports the repo's SPDX id. Mirrors and blogs were not used.
- **VERIFIED** means the official card or repo was fetched and its licence field was seen. **UNVERIFIED** means it could not be fetched; the reason is given.

## Operator lists

**Allowlist (licence ids):** `apache-2.0`, `mit`, `bsd-2-clause`, `bsd-3-clause`, `creativeml-openrail-m`, `openrail++`

**Never-shippable:** sd-turbo, sdxl-turbo, sd3.5, flux.1-dev, rmbg-1.4, rmbg-2.0

## Summary table

| # | Model | Official card | Declared licence | Derived from a non-commercial or never-shippable base? | On allowlist as-is? | Status |
|---|---|---|---|---|---|---|
| 1 | FLUX.1-schnell | https://huggingface.co/black-forest-labs/FLUX.1-schnell | `apache-2.0` | No. Distilled ("latent adversarial diffusion distillation") from a teacher the card does not name. The card does not say FLUX.1-dev | Yes | VERIFIED |
| 2a | FLUX.2-klein-4B | https://huggingface.co/black-forest-labs/FLUX.2-klein-4B | `apache-2.0` (LICENSE.md = Apache 2.0 text) | No. Distilled; the undistilled sibling is FLUX.2-klein-base-4B (`apache-2.0`) | Yes | VERIFIED |
| 2b | FLUX.2-klein-9B (for contrast) | https://huggingface.co/black-forest-labs/FLUX.2-klein-9B | `other` / `flux-non-commercial-license` | Is itself non-commercial | **No** | VERIFIED (metadata; card body gated) |
| 3a | Z-Image-Turbo | https://huggingface.co/Tongyi-MAI/Z-Image-Turbo | `apache-2.0` | No. Distilled from Z-Image (`apache-2.0`) | Yes | VERIFIED |
| 3b | Z-Image (base) | https://huggingface.co/Tongyi-MAI/Z-Image | `apache-2.0` | No (undistilled foundation model) | Yes | VERIFIED |
| 4a | Qwen-Image-2512 | https://huggingface.co/Qwen/Qwen-Image-2512 | `apache-2.0` | No | Yes | VERIFIED |
| 4b | Qwen-Image | https://huggingface.co/Qwen/Qwen-Image | `apache-2.0` | No | Yes | VERIFIED |
| 5a | Qwen-Image-Edit-2511 | https://huggingface.co/Qwen/Qwen-Image-Edit-2511 | `apache-2.0` | No | Yes | VERIFIED |
| 5b | Qwen-Image-Edit-2509 | https://huggingface.co/Qwen/Qwen-Image-Edit-2509 | `apache-2.0` | No | Yes | VERIFIED |
| 6 | Qwen-Image Lightning LoRAs | https://huggingface.co/lightx2v/Qwen-Image-Lightning (also `lightx2v/Qwen-Image-2512-Lightning`, `lightx2v/Qwen-Image-Edit-2511-Lightning`) | `apache-2.0` | No. Distilled from Qwen-Image, Qwen-Image-2512 and Qwen-Image-Edit-2511 (all `apache-2.0`) | Yes, but the publisher is ModelTC/LightX2V, not Qwen (see notes) | VERIFIED |
| 7a | Wan2.2-TI2V-5B | https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B | `apache-2.0` | No | Yes | VERIFIED |
| 7b | Wan2.2-I2V-A14B | https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B | `apache-2.0` | No | Yes | VERIFIED |
| 7c | Wan2.2-FLF2V-A14B | No such repo (`Wan-AI/Wan2.2-FLF2V-A14B` returns not-found). The official first/last-frame model is https://huggingface.co/Wan-AI/Wan2.1-FLF2V-14B-720P | Wan2.1-FLF2V: `apache-2.0` | No | Wan2.1-FLF2V: Yes | UNVERIFIED for a Wan2.2 FLF2V (no official repo); Wan2.1 FLF2V VERIFIED |
| 8 | Qwen3-VL-8B-Instruct | https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct | `apache-2.0` | No | Yes | VERIFIED |
| 9a | BiRefNet | https://huggingface.co/ZhengPeng7/BiRefNet | `mit` | No base model. Training data: DIS-TR (DIS5K). Dataset terms not checked | Yes | VERIFIED |
| 9b | BEN2 | https://huggingface.co/PramaLLC/BEN2 | `mit` | No base model. Training data: DIS5K plus a 22K proprietary set | Yes | VERIFIED |
| 10a | xinsir controlnet-openpose-sdxl-1.0 | https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0 | `apache-2.0` | Trained for SDXL base 1.0 (`openrail++`, allowlisted). Not turbo | Yes | VERIFIED |
| 10b | xinsir controlnet-union-sdxl-1.0 | https://huggingface.co/xinsir/controlnet-union-sdxl-1.0 | `apache-2.0` | Same as 10a | Yes | VERIFIED |
| 11 | Real-ESRGAN | https://github.com/xinntao/Real-ESRGAN | `BSD-3-Clause` (code repo; weights ship as release assets of the same repo) | No | Yes (`bsd-3-clause`) | VERIFIED |
| 12a | Depth-Anything-V2-Small | https://huggingface.co/depth-anything/Depth-Anything-V2-Small | `apache-2.0` | No | Yes | VERIFIED |
| 12b | Depth-Anything-V2-Base / -Large | https://huggingface.co/depth-anything/Depth-Anything-V2-Base, https://huggingface.co/depth-anything/Depth-Anything-V2-Large | `cc-by-nc-4.0` | Non-commercial | **No** | VERIFIED |
| 13a | SDXL base 1.0 | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0 | `openrail++` | No | Yes | VERIFIED |
| 13b | SDXL-Lightning | https://huggingface.co/ByteDance/SDXL-Lightning | `openrail++` | Distilled from SDXL base 1.0 (`openrail++`). Not sdxl-turbo | Yes | VERIFIED |
| 14 | LayerDiffuse (weights) | https://huggingface.co/LayerDiffusion/layerdiffusion-v1 (code: https://github.com/lllyasviel/LayerDiffuse) | Weights: `creativeml-openrail-m`; code: `Apache-2.0` | `layer_xl_*` files are trained on SDXL base (`openrail++`); `layer_sd15_*` files on SD 1.5 | Yes | VERIFIED |
| 15a | ostris ai-toolkit | https://github.com/ostris/ai-toolkit | `MIT` | n/a (code) | Yes | VERIFIED |
| 15b | kohya-ss sd-scripts | https://github.com/kohya-ss/sd-scripts | `Apache-2.0` | n/a (code) | Yes | VERIFIED |
| 16a | Pixel-art LoRA: Limbicnation/pixel-art-lora | https://huggingface.co/Limbicnation/pixel-art-lora | `apache-2.0` (repo has LICENSE) | Base: FLUX.2-klein-4B (`apache-2.0`) | Yes | VERIFIED |
| 16b | Pixel-art LoRA: adirik/pixel-art-lora-flux.2-klein-4B | https://huggingface.co/adirik/pixel-art-lora-flux.2-klein-4B | `apache-2.0` | Base: FLUX.2-klein-base-4B (`apache-2.0`) | Yes | VERIFIED |
| 16c | Pixel-art LoRA: nerijs/pixel-art-xl | https://huggingface.co/nerijs/pixel-art-xl | `creativeml-openrail-m` | Base: SDXL base 1.0 (`openrail++`) | Yes, but it is OpenRAIL, not Apache/MIT | VERIFIED |

## Per-row notes

### 1. FLUX.1-schnell
- Card: https://huggingface.co/black-forest-labs/FLUX.1-schnell. Licence `apache-2.0` appears in the API metadata and on the rendered card ("Released under the apache-2.0 licence, the model can be used for personal, scientific, and commercial purposes").
- Licence file: the repo has no LICENSE file. The card links the Apache 2.0 text at https://www.apache.org/licenses/LICENSE-2.0.
- **Gated** (`gated: auto`). You must be logged in to Hugging Face and accept the terms (approval is automatic) before downloading files or `README.md`. The licence itself is still Apache 2.0.
- Do not confuse it with FLUX.1-dev (`flux-1-dev-non-commercial-license`, on the never-shippable list). The schnell card does not name its distillation teacher.
- GGUF conversion: https://huggingface.co/city96/FLUX.1-schnell-gguf declares `apache-2.0` with base_model FLUX.1-schnell. It is a conversion, not a new model.
- Text encoders (T5-XXL, CLIP-L) ship from their own repos with their own licences. They were not reviewed here.

### 2. FLUX.2-klein-4B (and 9B)
- 4B card: https://huggingface.co/black-forest-labs/FLUX.2-klein-4B, `license: apache-2.0`. Licence file https://huggingface.co/black-forest-labs/FLUX.2-klein-4B/blob/main/LICENSE.md, which is the full Apache 2.0 text (fetched). The card says it is "Fully open under Apache 2.0" and available for commercial use. Not gated.
- It is a distilled 4-step model. The undistilled sibling https://huggingface.co/black-forest-labs/FLUX.2-klein-base-4B is also `apache-2.0` and is the better base for LoRA training.
- The card *encourages* NSFW/protected-content filters for 4B but does not require them. For 9B it *requires* filters or manual review under the FLUX Non-Commercial License.
- Official fp8: https://huggingface.co/black-forest-labs/FLUX.2-klein-4b-fp8, `apache-2.0`.
- GGUF conversion: https://huggingface.co/unsloth/FLUX.2-klein-4B-GGUF, `apache-2.0` (has LICENSE.md). `city96/FLUX.2-klein-4B-gguf` does not exist. ComfyUI repack: https://huggingface.co/Comfy-Org/Flux-2-Klein-4B, `apache-2.0`.
- **9B, for contrast:** https://huggingface.co/black-forest-labs/FLUX.2-klein-9B declares `license: other`, `license_name: flux-non-commercial-license`, and is gated. Licence file: https://huggingface.co/black-forest-labs/FLUX.2-klein-9B/blob/main/LICENSE.md (gated, not read). **Not shippable.** FLUX.2-dev is the same: `flux-non-commercial-license`, gated.

### 3. Z-Image-Turbo / Z-Image
- Turbo card: https://huggingface.co/Tongyi-MAI/Z-Image-Turbo, `apache-2.0`. The card calls it "A distilled version of Z-Image", made with Decoupled-DMD and DMDR. Base card: https://huggingface.co/Tongyi-MAI/Z-Image, `apache-2.0`, an "undistilled foundation" the card recommends for LoRA and ControlNet training.
- No LICENSE file in either HF repo; the licence comes from the metadata. Neither repo is gated.
- Conversions: https://huggingface.co/unsloth/Z-Image-Turbo-GGUF (`apache-2.0`), https://huggingface.co/jayn7/Z-Image-Turbo-GGUF (`apache-2.0`), and the ComfyUI repack https://huggingface.co/Comfy-Org/Z-Image-Turbo (`apache-2.0`).

### 4. Qwen-Image-2512 / Qwen-Image
- https://huggingface.co/Qwen/Qwen-Image-2512 and https://huggingface.co/Qwen/Qwen-Image both declare `apache-2.0`. The Qwen-Image card has a "License Agreement" section: "Qwen-Image is licensed under Apache 2.0." Not gated. No LICENSE file in the HF repos.
- Conversions: https://huggingface.co/unsloth/Qwen-Image-2512-GGUF (`apache-2.0`) and https://huggingface.co/city96/Qwen-Image-gguf (`apache-2.0`, original Qwen-Image). `QuantStack/Qwen-Image-2512-GGUF` does not exist. ComfyUI bf16/fp8: https://huggingface.co/Comfy-Org/Qwen-Image (`apache-2.0`). That repo also packages `DiffSynth-Studio/Qwen-Image-Distill-Full`, which was not reviewed here, so pick files from it one at a time.

### 5. Qwen-Image-Edit-2511 / 2509
- https://huggingface.co/Qwen/Qwen-Image-Edit-2511 and https://huggingface.co/Qwen/Qwen-Image-Edit-2509 both declare `apache-2.0`. The 2511 card says "Qwen-Image is licensed under Apache 2.0." Not gated.
- Conversions: https://huggingface.co/unsloth/Qwen-Image-Edit-2511-GGUF (`apache-2.0`) and https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF (`apache-2.0`, "a direct conversion of Qwen/Qwen-Image-Edit-2509"). `QuantStack/Qwen-Image-Edit-2511-GGUF` does not exist.
- The ComfyUI repack https://huggingface.co/Comfy-Org/Qwen-Image-Edit (`apache-2.0`) also packages `FireRedTeam/FireRed-Image-Edit-1.0`, which was not reviewed. Take only the Qwen files.

### 6. Qwen-Image Lightning LoRAs (lightx2v)
- https://huggingface.co/lightx2v/Qwen-Image-Lightning: `apache-2.0`, base_model `Qwen/Qwen-Image`. The card says the LoRAs are distilled from Qwen-Image and points to https://github.com/ModelTC/Qwen-Image-Lightning. The GitHub README says the models are "licensed under the Apache 2.0 License", with a LICENSE.txt.
- Variants: https://huggingface.co/lightx2v/Qwen-Image-2512-Lightning (`apache-2.0`, base Qwen-Image-2512) and https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning (`apache-2.0`, base Qwen-Image-Edit-2511).
- **Who publishes them:** ModelTC/LightX2V publishes these. The repos are official for that publisher but are **not Qwen-official**. Neither the Qwen-Image nor the Qwen-Image-2512 card mentions lightx2v or Lightning.
- The GitHub README warns that the LoRAs show grid artifacts on the naive `qwen_image_fp8_e4m3fn` checkpoint. Use bf16, or the fp8-specific LoRA variants that the README lists.

### 7. Wan2.2
- https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B and https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B both declare `apache-2.0`. Their cards say: "We claim no rights over the your generated contents…" and add use restrictions (no illegal or harmful content, no misinformation, no targeting vulnerable groups). Code: https://github.com/Wan-Video/Wan2.2 (`Apache-2.0`, LICENSE.txt). Not gated. A diffusers variant exists: `Wan-AI/Wan2.2-I2V-A14B-Diffusers`.
- **FLF2V:** there is no `Wan-AI/Wan2.2-FLF2V-A14B` (not-found), and the Wan2.2 cards and README do not mention FLF2V. The official first/last-frame model is https://huggingface.co/Wan-AI/Wan2.1-FLF2V-14B-720P (`apache-2.0`). Any "Wan2.2 FLF2V" is a community workflow built on I2V-A14B. Its licence follows I2V-A14B, but no official card exists to approve it against.
- Conversions: https://huggingface.co/QuantStack/Wan2.2-TI2V-5B-GGUF (`apache-2.0`) and https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF (`apache-2.0`). The ComfyUI repack https://huggingface.co/Comfy-Org/Wan-2.2 (`apache-2.0`) bundles many third-party bases, including alibaba-pai Fun, nvidia ChronoEdit and lightx2v distill LoRAs. Review each of those on its own before using it.

### 8. Qwen3-VL-8B-Instruct
- https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct, `apache-2.0`, not gated.
- GGUF: the official https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF (`apache-2.0`, published by Qwen, so not a third-party conversion). Alternative: https://huggingface.co/unsloth/Qwen3-VL-8B-Instruct-GGUF (`apache-2.0`).

### 9. BiRefNet / BEN2
- BiRefNet: https://huggingface.co/ZhengPeng7/BiRefNet, `license: mit`, with a License-MIT badge linking the repo LICENSE. Code: https://github.com/ZhengPeng7/BiRefNet (`MIT`). The card says this checkpoint was "trained on DIS-TR". The DIS5K dataset's own terms were not checked. The weights' licence is MIT, but flag the dataset if your policy covers training data. Other BiRefNet variants (for example `-HR`, `-matting`, `_lite`) are separate repos and were not reviewed.
- BEN2: https://huggingface.co/PramaLLC/BEN2, `license: mit`. Code: https://github.com/PramaLLC/BEN2 (`MIT`). It was trained on DIS5K plus a proprietary 22K set. The open "Base model" is MIT. PramaLLC sells a separate full commercial model (sales@backgrounderase.com), which this licence does not cover.
- Neither is derived from RMBG-1.4/2.0 (both never-shippable). The BEN2 card only *compares* itself to RMBG 2.0.

### 10. xinsir ControlNets
- https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0 (`apache-2.0`; the card also lists "License: apache-2.0") and https://huggingface.co/xinsir/controlnet-union-sdxl-1.0 (`apache-2.0`). Not gated. No LICENSE file in either repo.
- They condition SDXL base 1.0 (`openrail++`). At inference, the SDXL licence (with its use restrictions) applies to the base model you pair them with.

### 11. Real-ESRGAN
- https://github.com/xinntao/Real-ESRGAN, licence file https://github.com/xinntao/Real-ESRGAN/blob/master/LICENSE (`BSD-3-Clause`).
- The pretrained weights (for example `RealESRGAN_x4plus.pth` and `RealESRGAN_x4plus_anime_6B.pth`) are GitHub release assets of this repo and have no separate weight licence. `ai-forever/Real-ESRGAN` on HF is a third party with no licence field; do not use it.

### 12. Depth-Anything-V2
- Small: https://huggingface.co/depth-anything/Depth-Anything-V2-Small (`apache-2.0`). Transformers port: https://huggingface.co/depth-anything/Depth-Anything-V2-Small-hf (`apache-2.0`). Code: https://github.com/DepthAnything/Depth-Anything-V2 (`Apache-2.0`).
- **Base and Large are `cc-by-nc-4.0`, which makes them non-commercial and not shippable.** Use only Small.

### 13. SDXL base 1.0 / SDXL-Lightning
- SDXL: https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0, `openrail++`, licence file https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md. OpenRAIL++ carries use-based restrictions (Attachment A) that must pass downstream.
- SDXL-Lightning: https://huggingface.co/ByteDance/SDXL-Lightning, `openrail++`, licence file https://huggingface.co/ByteDance/SDXL-Lightning/blob/main/LICENSE.md. The card says: "Our models are distilled from stabilityai/stable-diffusion-xl-base-1.0". It is not derived from sdxl-turbo. The repo has 1/2/4/8-step UNet checkpoints and LoRAs. The 1-step model is labelled experimental.
- Do **not** mix in sdxl-turbo or turbo merges (never-shippable).

### 14. LayerDiffuse
- Weights: https://huggingface.co/LayerDiffusion/layerdiffusion-v1 declares `creativeml-openrail-m`. The card has metadata only. SDXL files: `layer_xl_transparent_attn.safetensors`, `layer_xl_transparent_conv.safetensors`, `vae_transparent_decoder.safetensors`, `vae_transparent_encoder.safetensors`, `layer_xl_fg2ble/fgble2bg/bg2ble/bgble2fg.safetensors`. SD1.5 files: `layer_sd15_*`.
- Code: https://github.com/lllyasviel/LayerDiffuse (`Apache-2.0`). The ComfyUI node https://github.com/huchenlei/ComfyUI-layerdiffuse is also `Apache-2.0`.
- `huggingface.co/lllyasviel/LayerDiffuse` does not exist. `lllyasviel/LayerDiffuse_Diffusers` declares `openrail`, which is *not* on the allowlist, so use `LayerDiffusion/layerdiffusion-v1` instead.
- The SDXL files are trained against SDXL base (`openrail++`), so the SDXL licence also applies at inference.

### 15. Training tools (code)
- ostris ai-toolkit: https://github.com/ostris/ai-toolkit, LICENSE https://github.com/ostris/ai-toolkit/blob/main/LICENSE (`MIT`).
- kohya-ss sd-scripts: https://github.com/kohya-ss/sd-scripts, LICENSE https://github.com/kohya-ss/sd-scripts/blob/main/LICENSE.md (`Apache-2.0`).
- The code licence says nothing about the model you train with it. A LoRA inherits the constraints of the base it was trained on.

### 16. Pixel-art LoRAs
1. **Limbicnation/pixel-art-lora**: https://huggingface.co/Limbicnation/pixel-art-lora, `apache-2.0` (LICENSE in repo). base_model `black-forest-labs/FLUX.2-klein-4B`. Dataset https://huggingface.co/datasets/Limbicnation/pixel-art-character (`apache-2.0`). The card claims the images are "CC0 curated + synthetic" with a provenance manifest; the manifest was not audited. About 7.2k downloads. Aimed at game sprites with transparent backgrounds.
2. **adirik/pixel-art-lora-flux.2-klein-4B**: https://huggingface.co/adirik/pixel-art-lora-flux.2-klein-4B, `apache-2.0`. Trained on FLUX.2-klein-base-4B (the card's code loads `black-forest-labs/FLUX.2-klein-base-4B`) at 512x512. Data: 463 images from https://huggingface.co/datasets/bghira/free-to-use-pixelart (`mit`). Trigger word: `PXART4`.
3. **nerijs/pixel-art-xl** (SDXL): https://huggingface.co/nerijs/pixel-art-xl, `creativeml-openrail-m` (allowlisted, but not Apache/MIT). base_model SDXL base 1.0. The most widely used SDXL pixel LoRA (about 34.6k downloads). No training-data provenance is given.
- Reputation caveat: options 1 and 2 are recent and from individual authors with limited track records. Option 3 is widely used but does not document its data.
- Also seen and **not recommended**: `ntc-ai/SDXL-LoRA-slider.pixel-art` declares `mit` with SDXL base, but its usage example loads an **sdxl-turbo** merge (never-shippable). `svntax-dev/pixel_spritesheet_4walk_small_lora_v1` (`apache-2.0`, klein-base-4B) trains on a CC-BY-4.0 template, which requires attribution.

## Status roll-up

- **Allowlist-clean (VERIFIED):** 1, 2a, 3a, 3b, 4a, 4b, 5a, 5b, 6, 7a, 7b, Wan2.1-FLF2V (7c alt), 8, 9a, 9b, 10a, 10b, 11, 12a, 13a, 13b, 14 (`LayerDiffusion/layerdiffusion-v1` only), 15a, 15b, 16a, 16b, 16c.
- **Problematic:** 2b FLUX.2-klein-9B (non-commercial); FLUX.2-dev (non-commercial); 12b Depth-Anything-V2-Base/Large (`cc-by-nc-4.0`); `lllyasviel/LayerDiffuse_Diffusers` (`openrail`, not allowlisted); `ntc-ai/SDXL-LoRA-slider.pixel-art` (turbo-merge example).
- **Caveats to approve explicitly:** FLUX.1-schnell is gated (auto-accept login). The lightx2v LoRAs are not Qwen-official. BiRefNet and BEN2 train on DIS5K (dataset terms not checked). Comfy-Org repacks bundle unreviewed third-party models. OpenRAIL use restrictions apply to SDXL and its derivatives.
- **UNVERIFIED:** 7c "Wan2.2-FLF2V-A14B". No official repo exists, so there is no card to approve against.

## Addendum (2026-11-01): DINOv2-small

| Model | Official card | Licence id (card metadata) | Non-commercial base? | Allowlist | Status |
|---|---|---|---|---|---|
| DINOv2-small (embedding model for identity-similarity QA) | https://huggingface.co/facebook/dinov2-small | `apache-2.0` | No | Yes | VERIFIED (HF API `cardData.license`, not gated) |

The forge's format owner (calmecacpilli) confirms this falls under the operator's standing approval.
