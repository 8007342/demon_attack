# Open-weight image, edit and video models for a 24 GB Ampere host (Nov 2026)

Host: RTX A5000 24 GB (Ampere, sm_86: **no native FP8 or FP4 math**), 62 GB RAM, 20 cores, Linux/podman.
Runtimes: stable-diffusion.cpp (sd.cpp) today, ComfyUI arriving.
Use case: 2D vertical shooter assets (ships, multi-frame demons, bosses, VFX, 2:3 parallax backgrounds). Consistency across assets matters most. **The game ships publicly and commercially**, so licenses decide a lot here.

## Method and confidence

- Web access worked: WebSearch plus WebFetch of primary model cards (Hugging Face, GitHub). Many speed and VRAM numbers come from community or third-party guides. Each is tagged:
  - **[V]**: verified on a primary source (model card, official repo, vendor license page).
  - **[S]**: secondary source (blog, community guide, aggregator).
  - **[K]**: from my own knowledge, not checked in this session. Treat as **unverified**.
- Speed on Ampere: a 24 GB A5000 is roughly 3090-class (about 15–25% slower than a 3090 because of lower clocks and bandwidth). FP8 checkpoints run on Ampere in ComfyUI, but they are upcast to bf16/fp16 for compute. You save VRAM, not time. GGUF Q8_0 and Q5/Q6 are the natural format for sd.cpp. NVFP4 and Nunchaku SVDQuant FP4 speedups need Blackwell; Nunchaku INT4 does work on Ampere **[K]**.
- This is not legal advice. For anything shipped, read the actual license file.

---

## 1. License triage (the hard filter)

| Model | License | Commercial use of weights and outputs for a public game | Source |
|---|---|---|---|
| FLUX.1 [schnell] | Apache 2.0 | **Yes** | [V] https://huggingface.co/black-forest-labs/FLUX.1-schnell ; [S] https://artificialguy.com/blog/flux-licensing-commercial-use/ |
| FLUX.1 [dev] | FLUX (dev) Non-Commercial License v2 | **No / gray.** License text restricts the model to non-commercial use. The model card says outputs may be used commercially. These conflict and nobody has tested it in court. Avoid without a BFL commercial license. | [V] https://bfl.ai/legal/non-commercial-license-terms ; https://huggingface.co/black-forest-labs/FLUX.1-dev/discussions/136 |
| FLUX.1 Kontext [dev] | FLUX.1 [dev] Non-Commercial License (same conflict) | **No / gray** | [V] https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev |
| FLUX.2 [dev] (32B) | FLUX Non-Commercial | **No** | [S] https://botmonster.com/ai/best-local-image-generation-models-2026/ ; BFL repo https://github.com/black-forest-labs/flux2 |
| FLUX.2 [klein] 4B (base + distilled) | Apache 2.0 | **Yes** | [V] https://bfl.ai/blog/flux2-klein-towards-interactive-visual-intelligence |
| FLUX.2 [klein] 9B | FLUX Non-Commercial | **No** | [V] same BFL blog |
| FLUX.3 Image Klein 5.6B (15 Oct 2026) | FLUX Kommunity License | **Yes if annual revenue < $5M**; larger orgs need a license. Repo is gated. | [S] https://bfl.ai/blog/flux-3-image-klein ; https://mer.vin/news/flux-3-klein-open-weights-image-model/ (verify the license text) |
| SD 3.5 Large (8B) / Medium (2.5B) | Stability AI Community License | **Yes if total annual revenue < $1M**; Enterprise license above that | [V] https://huggingface.co/stabilityai/stable-diffusion-3.5-large ; https://stability.ai/license |
| SDXL 1.0 base | CreativeML OpenRAIL++-M | **Yes** (use restrictions only) | [K]/[S] botmonster link above |
| Pony Diffusion V6 XL | Modified OpenRAIL-M (restricts running it as a paid service; outputs OK) | Likely yes for outputs | **unverified [K]** |
| Illustrious-XL | Fair AI Public License 1.0-SD (per secondary sources) | Outputs reportedly OK; monetized model *services* restricted | [S] https://www.ai-image-journey.com/2025/10/sdxl-license.html (**unverified**, read the card) |
| NoobAI-XL | Fair-AI Public License 1.0-SD with an added no-commercialization clause | **No.** Card forbids commercialization, including outputs per some readings. | [V] https://huggingface.co/Laxhar/noobai-XL-1.1/blob/main/README.md |
| Qwen-Image (20B, Aug 2025) and Qwen-Image-2512 (Dec 2025) | Apache 2.0 | **Yes** | [V] https://huggingface.co/Qwen/Qwen-Image-2512 |
| Qwen-Image-Edit / 2509 / 2511 | Apache 2.0 | **Yes** | [S] https://chutes.ai/docs/models/vonkaiser-qwen-image-edit-2511 ; HF mirrors tagged apache-2.0 (confirm on the official card) |
| Qwen-Image-2.1 (7B, gen+edit, RGBA, 20 Sep 2026) | **Qwen Research License (non-commercial)** | **No** | [S] https://www.eesel.ai/blog/qwen-image-2-1 ; https://cellcog.ai/blog/qwen-image-2-1/ |
| Z-Image-Turbo / Z-Image (Base) 6B (Tongyi-MAI) | Apache 2.0 | **Yes** | [S] https://www.therundown.ai/tools/z-image ; https://invideo.io/blog/z-image-ai-image-generator/ (HF card says Apache-2.0 per several sources) |
| Z-Image-Edit | Listed "to be released" as of ~Aug 2026 | n/a | [S] https://localaimaster.com/blog/z-image-base-edit-guide |
| HiDream-I1 (17B) | MIT (model), **but the pipeline needs Llama-3.1-8B (Llama Community License)** + T5 (Apache) | Yes, with the Llama licence attached (fine below 700M MAU) | [V] https://github.com/HiDream-ai/HiDream-I1 |
| Chroma / Chroma1-HD / Radiance (8.9B, FLUX-schnell-derived) | Apache 2.0 | **Yes** | [V] https://huggingface.co/lodestones/Chroma |
| Lumina-Image-2.0 (2B) | Apache 2.0 | **Yes** | [V] https://huggingface.co/Alpha-VLLM/Lumina-Image-2.0 |
| HunyuanImage 2.1 / 3.0 | Tencent Hunyuan Community License: **excludes EU, UK, South Korea**; 100M MAU clause | Risky for a globally distributed game | [V] https://huggingface.co/tencent/HunyuanImage-3.0/blob/main/LICENSE |
| Krea 2 Raw/Turbo (12B, Jun 2026) | Krea 2 Community License: free under ~50 seats; mandatory safety safeguards | Probably yes for a small team; read the text | [S] https://venturebeat.com/technology/enterprise-grade-ai-image-generation-in-2-seconds-is-here-krea-2-raw-and-turbo-available-as-open-weights-under-custom-license |
| Ideogram 4 (quantized open weights) | Ideogram Non-Commercial; paid self-serve commercial tier | **No** without paying | [V] https://ideogram.ai/licensing/ |
| Wan 2.1 / 2.2 (video, also usable as T2I at 1 frame) | Apache 2.0 | **Yes** | [V] https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B |
| Wan 2.5 / 2.6 / 2.7 / 3.0 | API-only per most sources; no confirmed open weights | n/a | [S] https://howaiworks.ai/blog/alibaba-wan-open-weights-stopped-at-2-2 |
| LTX-2 / 2.3 / 2.5 (Lightricks) | LTX-2 Community License: free under $10M revenue | Yes for a small studio | [S] https://magichour.ai/blog/ltx-2-3-vs-wan-2-2 (license text not read) |
| HunyuanVideo 1.5 (8.3B) | Tencent Hunyuan Community (EU/UK/KR excluded per secondary sources) | Risky | [S] https://chatforest.com/reviews/hunyuanvideo-tencent-open-source-video-generation/ (**unverified** for 1.5) |

**Clean for a public commercial game, no thresholds:** FLUX.1 schnell, FLUX.2 klein 4B, SDXL (+ Apache/OpenRAIL LoRAs), Qwen-Image / 2512, Qwen-Image-Edit 2509/2511, Z-Image, Chroma, Lumina 2, Wan 2.1/2.2, HiDream-I1 (with Llama terms).
**OK below a revenue threshold:** SD 3.5 (<$1M), FLUX.3 Klein (<$5M), LTX-2.x (<$10M), Krea 2 (<50 seats).
**Avoid:** FLUX.1 dev, FLUX.1 Kontext dev, FLUX.2 dev, FLUX.2 klein 9B, Qwen-Image-2.1, NoobAI, Ideogram 4, Hunyuan (territory exclusion).

---

## 2. Text-to-image comparison (ranked for this project)

Approximate. "VRAM @1024²" is the diffusion model plus working memory with the text encoder offloaded to RAM, which 62 GB RAM makes cheap. "Speed" is per 1024² image on an A5000-class card.

| Rank | Model | Params | VRAM @1024² (24 GB fit) | Speed (A5000-class) | Prompt adherence | Text | Ecosystem (ControlNet / ref / LoRA training) | ComfyUI | sd.cpp | Sprites / pixel art | License |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Qwen-Image-2512** (+ Lightning 4/8-step LoRA) | 20B MMDiT + Qwen2.5-VL-7B TE | fp8 ≈19–20 GB weights, fits 24 GB with TE offload; GGUF Q4–Q6 ≈11–16 GB | ~35–55 s with 8-step LoRA on a 4090D [S]; expect **~50–90 s on A5000**; ~90–150 s at 20+ steps | Excellent, among the best open | Best open (EN + CJK) | ControlNet union (InstantX/DiffSynth) [K], strong LoRA training (AI-Toolkit, DiffSynth, musubi) [K]; pairs with Qwen-Image-Edit | Native [V] https://docs.comfy.org/tutorials/image/qwen/qwen-image | Yes [V] | Very good with style LoRAs (PixelArtRedmond has a Qwen version [S]) | Apache 2.0 |
| 2 | **Z-Image-Turbo / Z-Image Base** | 6B S3-DiT + Qwen3-4B TE [K] | bf16 ~16 GB; fp8 ~8 GB [S] | 8–9 steps; **~6–12 s** expected on A5000 [K/S] | Very good; strong photoreal bias | Good (EN/CN) | Fast-growing LoRA ecosystem; ControlNet-Union available [K]; Base checkpoint is meant for finetuning | Native [K] | Yes (2025-12-01) [V] | Good. Turbo is photoreal-leaning, so stylized output needs a LoRA. | Apache 2.0 |
| 3 | **FLUX.2 [klein] 4B** | 4B + Qwen3 TE [K] | ~8–13 GB [V/S, sources conflict] | 4-step distilled: **~3–6 s** [K est.] | Good | Decent | **Already has Apache pixel-art and 2×2 sprite-sheet LoRAs** [V] https://huggingface.co/fal/flux-2-klein-4b-spritesheet-lora , https://huggingface.co/Limbicnation/pixel-art-lora; multi-reference editing built in [K] | Native [K] | Yes (2026-01-18) [V] | **Strong candidate for sprites** | Apache 2.0 |
| 4 | **SDXL + finetunes** (Illustrious/Pony, pixel-art LoRAs) | 2.6B | ~8–10 GB fp16 | 4–8 step Lightning/DMD: ~2–4 s; 30-step: ~8–12 s | Weak on composition (CLIP), strong on tags | Poor | **The deepest ecosystem**: ControlNet (all types), IP-Adapter / InstantID, thousands of LoRAs, mature trainers (kohya, OneTrainer) | Native | Yes (current I1) | Best *existing* pixel-art toolchain (PixelArtRedmond, pixel-art-xl, plus downscale/palette nodes). Use Illustrious for painted/anime sprites. Avoid NoobAI. | OpenRAIL++-M (finetunes vary) |
| 5 | **Chroma1-HD** | 8.9B | Q8/fp8 ~10–12 GB [K] | ~25–40 s @ 26 steps [K] | Good; uncensored | Fair | FLUX-style LoRAs partially compatible [K] | Native [K] | Yes [V] | Good stylized range | Apache 2.0 |
| 6 | **FLUX.1 [schnell]** | 12B + T5-XXL | fp8 / Q8 ~12–13 GB; NF4 ~7 GB | 4 steps: **~5–8 s** [K] | Good | Good | Big FLUX ecosystem, but most LoRAs/ControlNets/Redux are dev-trained (non-commercial weights; check each). schnell itself is hard to finetune (distilled). | Native | Yes | OK. Pixel-art LoRAs exist, mostly dev-based. | Apache 2.0 |
| 7 | **FLUX.3 Image Klein** 5.6B | 5.6B | "runs on 8 GB" [S] | fast distilled [S, unverified] | Reportedly strong (new) | Reportedly strong | Very new (Oct 2026); ecosystem thin | likely native [unverified] | Yes (2026-10-16) [V] | Unknown yet | Kommunity <$5M |
| 8 | **SD 3.5 Large / Medium** | 8B / 2.5B | Large fp8 ~14–18 GB, NF4 ~9 GB; Medium ~8–10 GB [K] | Large ~30–45 s @ 28 steps; Large-Turbo 4 steps ~6–8 s [K] | Good, diverse styles | Fair-good | ControlNets (Blur/Canny/Depth) released by Stability [K]; LoRA tooling weaker than FLUX/SDXL; community largely moved on | Native | Yes | OK for painted styles; anatomy weaker | Community <$1M |
| 9 | **HiDream-I1** Full/Dev/Fast | 17B MoE + 4 text encoders incl. Llama-3.1-8B | fp8 ~16 GB, full ~20 GB [S] https://comfyui-wiki.com/en/tutorial/advanced/image/hidream/i1-t2i ; GGUF/NF4 lower | Slow (Full 50 steps ~2–3 min; Fast 16 steps ~30–40 s) [K] | Very good | Good | Limited; LoRA training possible in AI-Toolkit [K] | Native [V] https://docs.comfy.org/tutorials/image/hidream/hidream-i1 | Not in upstream list (HiDream-O1 is) [V] | Fine, but heavy for the benefit | MIT + Llama licence |
| 10 | **Lumina-Image-2.0** | 2B (3B listed) | ~8–12 GB [K] | ~15–25 s [K] | Good for its size | Fair | Small ecosystem | Native [K] | not in upstream list [V] | Niche | Apache 2.0 |
| – | FLUX.1 [dev] / Kontext [dev] / FLUX.2 [dev] | 12B / 12B / 32B | dev fp8 ~12 GB; FLUX.2 dev needs Q4 GGUF + offload on 24 GB [K] | dev ~25–35 s @ 20–28 steps [K] | Excellent | Good–excellent | Largest FLUX ecosystem (Redux, IP-Adapter, ControlNet Union, PuLID) | Native | Yes | Good | **Non-commercial, excluded** |
| – | Qwen-Image-2.1 (7B) | 7B | ~14 GB bf16, 7 GB int8 [S] | fast [S] | strong, plus RGBA output | strong | new | yes | Yes (2026-09-20) [V] | **Native transparency is ideal for sprites, but non-commercial** | Excluded |
| – | HunyuanImage 2.1 / 3.0 | 17B / 80B MoE | 3.0 needs ≥3×80 GB [S] | – | – | – | – | 2.1 yes [K] | no | – | Territory-excluded |
| – | Ideogram 4, Krea 2 | – | Krea 2 12B ≈ fp8 ~13 GB [K] | – | strong | Ideogram best-in-class text | – | Comfy-Org mirrors exist [V] | Yes [V] | – | NC / seat-capped |

### Notes on sprites and pixel art

- **No base model produces true pixel art** (exact grid, limited palette) by itself. Every reliable pipeline is: generate at 1024 with a pixel-art LoRA, then downscale nearest-neighbour by 8–16×, quantize the palette, and clean up alpha. Keep that deterministic post-processing stage in `tools/` whatever model you pick. [K]
- **Transparency:** only Qwen-Image-2.1 (non-commercial) and LayerDiffuse (SDXL, plus a FLUX port) give native alpha. Otherwise use a background-removal pass (BiRefNet / RMBG-2.0, but RMBG-2.0 is non-commercial **[K, verify]**; BiRefNet is MIT **[K]**) or generate on a flat chroma colour.
- **Consistency recipe (any model):** train one **style LoRA** on 20–40 approved house-style assets and lock the seed, sampler and palette. Then add (a) a reference-edit model for "same character, new pose" (section 3) and (b) ControlNet pose/lineart for frame-to-frame structure. A style LoRA on Qwen-Image, Z-Image Base or FLUX.2-klein-4B (all Apache) is the highest-leverage single investment.

---

## 3. Image-edit models ("same character, new pose")

| Model | VRAM (24 GB) | Speed | Consistency | Notes | License |
|---|---|---|---|---|---|
| **Qwen-Image-Edit-2511** | fp8 19 GB file + TE offload fits 24 GB; GGUF Q4–Q6 12–16 GB [S] https://lilting.ch/en/articles/qwen-image-edit-2511-local-specs | ~36 s on a 3090 with the 8-step LoRA (2509, bnb) [S] https://huggingface.co/Qwen/Qwen-Image-Edit/discussions/6 → ~45–60 s on A5000 | **Best open option.** 2511 improves character consistency and reduces drift; multi-image input (up to 3 refs); built-in pose/view LoRAs [S] | ComfyUI native [V] https://docs.comfy.org/tutorials/image/qwen/qwen-image-edit-2511 ; sd.cpp supports the Edit series [V]. Community LoRAs for multi-angle/turnaround exist [K]. | Apache 2.0 |
| Qwen-Image-Edit-2509 | same | same | Good; multi-image; native ControlNet-style pose/depth/canny input [S] | Superseded by 2511 | Apache 2.0 |
| FLUX.2 [klein] 4B (multi-ref editing) | ~8–13 GB | seconds | Good for small edits and style transfer [K] | Pairs with the sprite-sheet LoRA | Apache 2.0 |
| FLUX.1 Kontext [dev] | fp8 ~12 GB | ~25–40 s | Very good | **Non-commercial**, excluded | FLUX NC |
| Qwen-Image-2.1 (gen+edit, 10 refs, RGBA) | ~14 GB | fast | Strong | **Non-commercial**, excluded | Qwen Research |
| LongCat-Image-Edit, Boogu Edit, Mage-Flow-Edit, Fibo 2.0 Edit | ? | ? | ? | In the sd.cpp list [V]; licenses and quality **not verified** in this session | unverified |
| SDXL + IP-Adapter / InstantID + ControlNet OpenPose | ~10 GB | fast | Moderate: identity drifts on non-human designs | Most controllable pose path | OpenRAIL / Apache adapters [K] |

Recommended pose workflow: one hero reference (front view) → Qwen-Image-Edit-2511 with a pose skeleton or a second reference image ("same demon, wings raised") → style-LoRA refine pass → deterministic pixelize/palette step.

---

## 4. Local video models for animation frames

The useful idea is to treat a short I2V clip as an in-between generator: feed the sprite on a flat background, prompt "idle bob / wing flap loop", sample 4–12 frames, then pixelize. Expect cleanup. Video models struggle with tiny stylized sprites and true loops, so FLF2V (first-last-frame) modes help.

| Model | VRAM on 24 GB | Speed (A5000-class est.) | Fit for sprite frames | ComfyUI / sd.cpp | License |
|---|---|---|---|---|---|
| **Wan 2.2 TI2V-5B** | Official README: ≥24 GB at 720p [V]; ComfyUI with offload ~8–12 GB [S] https://www.runpod.io/articles/guides/comfyui-wan-2-2 | ~3–6 min per 5 s 720p clip [K]; far less at 480p / few frames | Good: I2V + T2V in one checkpoint, 24 fps | Native / yes (Wan2.2) [V] | Apache 2.0 [V] |
| **Wan 2.2 A14B I2V / FLF2V** (fp8 or GGUF Q5–Q8, high+low-noise pair) | Fits 24 GB at 480p–640p with TE offload; ~83–89% VRAM at 640² [S] https://www.thundercompute.com/blog/wan-2-2-comfyui-ai-video-model | 6–15 min per 81 frames without speed LoRA; ~1–3 min with lightx2v 4-step LoRA [K] | **Best open quality**; first-last-frame is ideal for loops | Native / yes | Apache 2.0 |
| Wan 2.1 VACE 14B | Q5–Q8 GGUF fits | slow | Pose/depth-driven animation (control video in), so you can drive frames from a skeleton | Native / yes (2025-09-14) [V] | Apache 2.0 |
| LTX-2 / 2.3 / 2.5 (19–22B, audio+video) | fp8 / GGUF + offload on 24 GB [S] | Fastest of the big ones [S] | Good motion; less style-faithful on tiny sprites [K] | Native / yes (2.3/2.5) [V] | LTX-2 Community, free < $10M [S] |
| HunyuanVideo 1.5 (8.3B) | 14 GB min with offload; 24 GB comfortable [S] https://nexgpu.net/en/models/hunyuanvideo/ | moderate | Good | Native / yes [V] | Tencent, territory-excluded (unverified for 1.5) |

**Video pick:** Wan 2.2 (TI2V-5B for fast iteration, A14B FLF2V + lightx2v LoRA for finals). Apache 2.0, supported by both runtimes.

---

## 5. Recommended tiers for this host

Current: **I0** SDXS-512 (previews), **I1** SDXL-Lightning-4step.

### I2: "fast, commercially clean, sprite-friendly" (target ≤10 s/img, ≤14 GB)

**Primary: FLUX.2 [klein] 4B (distilled), Apache 2.0.**
- Runs in both sd.cpp (since 2026-01-18) and ComfyUI. Few-step and fast. Already has Apache-licensed **pixel-art and 2×2 sprite-sheet LoRAs**. Small enough to train house-style LoRAs quickly. Multi-reference editing helps consistency.
- License: Apache 2.0, **4B only**. Make sure the forge cannot silently pull the 9B (non-commercial).

**Alternate: Z-Image-Turbo (6B), Apache 2.0.** Better prompt adherence and text, about 8 steps, ~16 GB bf16 or ~8 GB fp8. In sd.cpp since 2025-12-01. Use Z-Image Base for LoRA training. Leans photoreal, so it needs a style LoRA for sprites.

(Keep SDXL I1 alive. Its ControlNet/IP-Adapter/LoRA ecosystem is still the most mature for pixel art.)

### I3: "quality + edit + consistency" (≤ ~60–90 s/img, fills 24 GB)

**Primary: Qwen-Image-2512 (T2I) + Qwen-Image-Edit-2511 (edit / new pose), Apache 2.0.**
- Best open prompt adherence and text. Same family for generation and editing, so styles and LoRAs carry across. 2511 is explicitly tuned for character consistency and multi-image references.
- Both runtimes support it: ComfyUI natively; sd.cpp for Qwen Image and the Edit series.
- On 24 GB: fp8 (ComfyUI) or GGUF Q6_K/Q8_0 (sd.cpp), text encoder offloaded to RAM, Lightning 8-step LoRA for drafts.
- Caveat: **do not** substitute Qwen-Image-2.1. It is newer and smaller but non-commercial.

**Video add-on (I3-V): Wan 2.2** (TI2V-5B / A14B FLF2V with lightx2v LoRA), Apache 2.0.

### Watch list

- **FLUX.3 Image Klein** (5.6B, Oct 2026): promising and already in sd.cpp. Free commercial use only under $5M revenue, gated repo. Re-evaluate once the ecosystem matures and the license text is read.
- **Chroma1-HD** (Apache): good stylized alternative if Qwen feels too slow.
- **SD 3.5 Large**: fine below $1M revenue, but adds a threshold for little gain over Qwen and Z-Image.
- **Krea 2 Turbo**: strong aesthetics, seat-capped custom license.

### Do not ship with

FLUX.1 dev, FLUX.1 Kontext dev, FLUX.2 dev, FLUX.2 klein 9B, Qwen-Image-2.1, NoobAI-XL, Ideogram 4 (free tier), HunyuanImage/HunyuanVideo (EU/UK/KR exclusion). Also audit every LoRA/ControlNet: many FLUX adapters are trained on dev and inherit its non-commercial terms.

---

## 6. Unverified or conflicting items

- Speeds for the A5000 are extrapolated from 3090/4090 reports and my knowledge. Benchmark on the host before committing.
- FLUX.2 klein 4B VRAM: BFL docs say ~13 GB, the GitHub repo says ~8 GB.
- Qwen-Image-Edit-2511 Apache 2.0 comes from secondary sources and mirrors; confirm on the official card.
- Illustrious-XL and Pony V6 license specifics: unverified.
- FLUX.3 Klein license details (gating, $5M cap): secondary sources only.
- LTX-2.x license text and HunyuanVideo 1.5 territory clause: not read directly.
- Licenses for LongCat, Boogu, Mage-Flow, Fibo 2.0, MOSS-Image, Lens and PiD (all in the sd.cpp list): not researched.
- Wan 2.7 / 3.0 open-weight claims: conflicting and likely API-only.

## Key sources

- sd.cpp supported models and changelog: https://github.com/leejet/stable-diffusion.cpp/blob/master/README.md
- BFL FLUX NC license: https://bfl.ai/legal/non-commercial-license-terms
- FLUX.2 klein licensing: https://bfl.ai/blog/flux2-klein-towards-interactive-visual-intelligence
- FLUX.3 Klein: https://bfl.ai/blog/flux-3-image-klein
- Kontext dev card: https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev
- SD3.5 Large card: https://huggingface.co/stabilityai/stable-diffusion-3.5-large ; https://stability.ai/license
- Qwen-Image-2512 card: https://huggingface.co/Qwen/Qwen-Image-2512
- Qwen-Image-Edit-2511 ComfyUI: https://docs.comfy.org/tutorials/image/qwen/qwen-image-edit-2511
- Qwen-Image-2.1 license: https://www.eesel.ai/blog/qwen-image-2-1
- Z-Image: https://www.therundown.ai/tools/z-image
- HiDream-I1: https://github.com/HiDream-ai/HiDream-I1
- Chroma: https://huggingface.co/lodestones/Chroma
- Lumina 2: https://huggingface.co/Alpha-VLLM/Lumina-Image-2.0
- Hunyuan licence: https://huggingface.co/tencent/HunyuanImage-3.0/blob/main/LICENSE
- NoobAI card: https://huggingface.co/Laxhar/noobai-XL-1.1/blob/main/README.md
- Ideogram licensing: https://ideogram.ai/licensing/
- Krea 2: https://venturebeat.com/technology/enterprise-grade-ai-image-generation-in-2-seconds-is-here-krea-2-raw-and-turbo-available-as-open-weights-under-custom-license
- Wan 2.2: https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B ; https://howaiworks.ai/blog/alibaba-wan-open-weights-stopped-at-2-2
- LTX-2 license: https://magichour.ai/blog/ltx-2-3-vs-wan-2-2
- Pixel-art / sprite LoRAs: https://huggingface.co/Limbicnation/pixel-art-lora ; https://huggingface.co/fal/flux-2-klein-4b-spritesheet-lora ; https://civitai.com/models/144684/pixelartredmond-pixel-art-loras
