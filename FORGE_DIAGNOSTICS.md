# Forge diagnostics: local ship-art generation

**Date:** 2026-10-31
**Scope:** Inspect and smoke-test the local image-generation surface available in this Forge session, compare it with the game's ship and enemy-art requirements, and outline a local-only production pipeline. No hosted image-generation service was called. Generated files are research references only; no live game asset or renderer was changed.

## Findings

The Forge has a working local image-generation tool exposed to this agent as `mcp__host_browser__image_generate`. It identifies its engine as `stable-diffusion.cpp`, says inference runs on this computer, and returns output under `/work/tmp/imagegen/`. The tool supports prompt and negative prompt, width, height, steps, seed, count, and tiers `I0` through `I3`. It starts at the smallest tier. Its temporary output directory is deleted when the Forge shuts down.

This is separate from the general built-in `image_gen` tool and the installed `imagegen` skill's API-backed CLI. Those can use hosted image generation and are out of scope for this experiment. The local tool does not require an API key in its exposed interface.

The local text-inference setup and the local image model are different systems. Forge overlay code in `/home/forge/.config-overlay/mcp/lib-dev-env.sh` describes Ollama setup and CPU/NPU/GPU selection for text inference, but no `ollama`, `lmflow`, `lemonade`, or `comfyui` executable or process was visible in this project container. No `TILLANDSIAS_INFERENCE_ENDPOINT` was exposed in the session. Loopback probes from the container found no service on ports 11434 (usual Ollama), 8188 (usual ComfyUI), 1234, or 8765. The container exposes no `/dev/dri`, `/dev/nvidia*`, or `/dev/accel*` device nodes, and has no `nvidia-smi` or `rocm-smi` executable. This does not rule out host-only services or devices that are not mounted into the container.

The working image generator is currently exposed as an agent MCP tool, not as a project CLI or an endpoint that game code can call. Its returned `/work/tmp` file is visible to this session, but there is no visible direct `stable-diffusion.cpp` executable/server in the project container. Therefore an agent can call the tool and hand off files to local scripts, but a user-facing automated `add cannons` command needs an additional local orchestration surface: either an MCP workflow that safely validates a manifest and calls the tool, or an accessible local `stable-diffusion.cpp`/ComfyUI API with the required image-reference and control inputs.

The local image tool did complete a real generation. Its metadata reports `SDXS-512-0.9`, license `openrail++`, tier `I0`, backend `vulkan`, seed `314159`, 512×512 output, 12 steps, 8.22 seconds, `first_use: false`, and no larger-tier offer. The generated file is `/work/tmp/imagegen/img-1793415020293-314159-0.png` and is ephemeral. The generator reported no alpha channel.

Visual review of that smoke-test result found a painterly 3×4 contact-sheet-like arrangement of unrelated industrial forms rather than one isolated pixel-art starfighter. The output did not follow “one ship, centered, no grid” reliably and was not ready to use as a game sprite. This is a useful proof that local inference works; it is also evidence that the default I0 model and current prompt-only interface need a controlled asset-preparation stage and likely a more suitable local model/workflow before they can produce production art.

No ComfyUI sibling project or ComfyUI service was visible in the mounted `/home/forge/src` tree or from this container. A host-managed or unmounted sibling could still exist; it cannot be confirmed from this session.

## Local model asset pass

Three additional local-only calls were made through the same MCP tool at tier I0, model `SDXS-512-0.9`, Vulkan backend, 512×512, 20 steps. All returned `has_alpha=false`, `first_use=false`, and `bigger_tier_offer=null`; no larger model was offered. Raw outputs and exact prompts/negative prompts, seeds, hashes, model metadata, and review decisions are preserved in `assets/research/local-image-pipeline/` and `manifest.json`.

- The ship prompt produced an airplane-like craft in painterly style on a textured orange field, not the requested hard-edged pixel sprite.
- The twin-cannon prompt produced a painterly full vehicle with protrusions, not an isolated attachment.
- The force-field prompt produced a painterly bubble with a craft-like center and opaque pink surroundings, not a transparent, frame-ready game effect.

These candidates are useful as evidence for a repeatable local inference/review loop, but the original ship, cannon, and force-field candidates failed the sprite isolation and transparency gate; the four enemy references are likewise opaque and unsuitable as production frames. They are research sources only and are not in `assets/images/` or used by the live game renderer.

ImageMagick is installed locally as the proposed post-processing utility (`ImageMagick 7.1.2-34`). The Forge's package shim downloaded ImageMagick and its dependencies from the Homebrew package registry to the persistent local tool cache. This was software-tool provisioning, not image inference; all recorded image generations were performed by the local Vulkan model. The follow-up asset processor only uses local files and the local `magick` command.

## Current game-asset contract

The current player ship is row 4, columns 0–3 in `assets/images/combat.png`: four exhaust lengths in a 64×64-cell atlas, authored at 32×32 logical pixels and enlarged 2×. The renderer selects those frames and draws bank, directional highlights, turret barrels, weapon attachments, and shield effects in code. The current ship therefore has some animation and composition support, but most of the weapon/shield look is runtime geometry rather than authored frame art. See `plan/sprite-atlas.md` and `lib/game/scene.dart` (`_playerShip`).

Existing gameplay state already exposes useful art-driving values:

- `shipBank`, `shipVx`, `shipThrust`, `aimAngle`, and nine discrete aim-angle steps from −24° to +24° live in `lib/game/model.dart`.
- `Power.rapid`, `Power.spread`, `Power.large`, and `Power.shield` have independent nine-second timers.
- The player shield renderer currently has healthy, degrading, and critical timer stages, plus spark and impact/invulnerability cues.

The project presentation requirements call for original pixel art on fixed logical grids, bounded palettes, nearest-neighbor display, discrete animation frames, and stepped lighting. Any new ship system should preserve those constraints. It must not trace original Demon Attack sprites or screenshots.

## What the current local tool can and cannot do

| Need | Current support | Consequence |
| --- | --- | --- |
| Local text-to-image inference | Confirmed working through `stable-diffusion.cpp`; reported Vulkan backend | Good for local concept exploration and inexpensive smoke tests |
| Repeatability | Explicit seed, dimensions, steps, and image count | Can reproduce a request at the model/runtime level; does not guarantee semantic consistency |
| Batch candidates | `count` is available | Useful for concept alternatives; not a substitute for separately authored animation poses |
| Background removal | No alpha option in the exposed tool; tested output had `has_alpha: false` | Must add local segmentation/chroma removal or use a workflow/model that emits alpha |
| Reference image / img2img / mask | Not exposed in the tool arguments | Cannot currently feed the canonical in-game ship back as a strict identity reference or protect unchanged areas during an edit |
| Pose, grid, palette, cell anchors | Prompt only; no structured pose/control inputs | Cannot rely on the generator alone for fixed-frame sheets or stable attachment pivots |
| Project-code integration | Agent MCP tool only; no local CLI/server endpoint visible in the container | A reusable command needs a local MCP orchestration flow or a host/sibling local endpoint |
| Quality tier choice | `I0`–`I3` are accepted; larger-tier offer is optional | Do not guess tiers or bypass the offer/consent mechanism; the smoke test returned no offer |
| Persistent assets | Output is under ephemeral `/work/tmp/imagegen/` | Copy an accepted result into the project during a separately scoped asset task and record provenance |

The underlying `stable-diffusion.cpp` project documents broader facilities than this MCP wrapper exposes, including image-to-image, masks, ControlNet, and IP-Adapter inputs in its server API. Those capabilities are candidates for a direct local backend or a more expressive local workflow, but they have **not** been verified as enabled in the Forge's wrapper. See its [server API](https://github.com/leejet/stable-diffusion.cpp/blob/master/examples/server/api.md) and [CLI examples](https://github.com/leejet/stable-diffusion.cpp/tree/master/examples/cli).

ComfyUI is another plausible local backend if the sibling can be made available. Its official project describes reusable graph workflows, a local API, multiple model backends, and a fully offline core when optional API nodes are disabled. That makes it a good fit for explicit, reviewable multi-stage asset graphs, but no ComfyUI installation is currently reachable here. See [ComfyUI's official repository](https://github.com/Comfy-Org/ComfyUI).

## Recommended local-only pipeline

Keep inference local, keep image processing local, and make all generation inputs and outputs reviewable. The text model can translate a short request such as “add twin cannons” into a typed asset change; the diffusion model should create candidate artwork; deterministic tools should enforce the project's art contract. Do not allow a prompt to edit gameplay code or overwrite shipping art directly.

```text
prompt: "add twin cannons"
        |
local text model (optional, Ollama)
        v
validated asset manifest (slots, palette, pivots, frame groups, constraints)
        |
local image backend (stable-diffusion.cpp now; ComfyUI/direct server if needed)
        v
raw candidates + model/seed/prompt provenance
        |
local deterministic processing and validation
        v
contact sheet / GIF preview / pass-fail report
        |
human-selected asset -> atlas packer -> explicit game integration
```

Suggested manifest fields:

- Asset identity and parent design reference (the canonical current ship image and palette).
- Requested operation (`add_attachment`, `new_pose`, `new_light_state`, or `new_effect`) and attachment slot names such as left/right wing hardpoint or central nose mount.
- Logical cell dimensions, frame names/order, frame timing, pivot/anchor coordinates, and expected transparency.
- Palette limits and protected silhouette pixels/regions.
- Prompt, negative prompt, seed, model file hash, runtime/backend, steps, and post-processing recipe.

Local deterministic post-processing should:

1. Crop or segment each generated part; remove the chosen background when alpha is unavailable.
2. Snap to a fixed logical pixel grid, quantize to a named bounded palette, and enlarge with nearest-neighbor sampling.
3. Normalize the pivot and alignment across frames. Keep cannons as independent sprites/layers where practical so weapon combinations do not require regenerating the ship body.
4. Check dimensions, alpha, palette count, empty margins, frame differences, alignment drift, and forbidden text/background pixels.
5. Emit a contact sheet and short preview animation, then wait for explicit human selection before atlas packing or integration.

These steps improve format and consistency but cannot repair a fundamentally wrong silhouette or a model that ignores the requested pose. Generation quality must be judged before building a large atlas.

## Suggested ship art breakdown

Start with one small proof that exercises identity consistency and composability:

1. **Canonical ship sheet:** clean front-facing base hull, exact logical pixel size and palette, visible nose/cockpit, and marked mount points.
2. **Bank set:** nine discrete bank poses at the already supported aim increments (−24°, −18°, −12°, −6°, 0°, +6°, +12°, +18°, +24°), with a common pivot. If this creates excessive frame count, test retaining the existing small bank transform and use art only at the extremes.
3. **Engine loop:** several discrete exhaust frames separated from the bank poses so thrust animation does not multiply the whole pose set.
4. **Modular cannons:** left/right hardpoint art, inactive/active/firing frames, muzzle flash, and small stepped heat/light states. Keep left/right mount geometry symmetric unless the design intentionally differs.
5. **Weapon combinations:** manifest-driven layouts for the current rapid, spread, and large powers. Existing mechanics and timers remain authoritative; asset state follows them.
6. **Force field:** activation, stable loop, hit ripple, timer degradation, critical warning, consume/break, and fade frames. Keep gameplay collision and the existing nine-second timer in the model; the animation only visualizes those state transitions.
7. **Damage/loss:** readable damage overlays and the already existing ship breakup sequence can be reviewed after the core silhouette and attachment workflow works.

Do not generate every angle × weapon × light combination as a separate whole-ship image. That creates a large atlas and increases identity drift. Prefer a small hull-pose set plus separately anchored attachments, firing overlays, exhaust, and shield layers.

## Research basis and limits

The academic paper [Sprite Sheet Diffusion: Generate Game Character for Animation](https://arxiv.org/abs/2412.03685) frames the relevant problem as generating motion frames from both a character reference and pose sequence. It reports better reference/pose alignment from its adapted approach, but also describes consistency limitations and overfitting. This supports testing a reference-plus-pose workflow; it does not establish that a prompt-only 512px model can deliver production-ready pixel frames.

[ControlNet](https://arxiv.org/abs/2302.05543) is a relevant control strategy because it conditions image generation on spatial guides such as edges, depth, segmentation, or pose. For this ship, edge/segmentation guides and attachment masks are more useful than asking a language model to describe every pixel in prose. A local backend must expose the needed model/control weights; API capability alone does not mean those weights are installed or usable.

The existing project art constraints are more exact than the model's output. The generator should be treated as an art assistant for candidate designs and selected component frames, with deterministic geometry or hand cleanup retaining final authority over silhouette, palette, pixel grid, anchors, and gameplay state.

## Recommended next actions

1. **Keep the current MCP smoke-test tool as a local concept generator.** It is already installed, fast on this host's reported Vulkan backend, fixed-seed, and adequate to prove no hosted inference is needed.
2. **Probe the full tier menu only through its documented offer mechanism.** The first call returned no larger-tier offer; do not invent consent tokens or force a tier outside the offer flow.
3. **Check the host/sibling ComfyUI status outside this container.** If present, verify its bind address is local-only, API nodes/cloud nodes are disabled, models are local, and workflow outputs can be copied into the project. If absent, compare exposing `stable-diffusion.cpp`'s local img2img/control inputs with bringing up a local ComfyUI sibling.
4. **Choose a local image model suited to reference-conditioned illustration and record its license/weights.** Do not assume Ollama's text-model tier table also configures image generation; the observed image tool uses a separate SDXS model/tier.
5. **Build the manifest + validator + preview stage before atlas integration.** A future `add cannons` request should produce a reviewable change proposal and a candidate preview, not silently mutate `combat.png` or game code.
6. **Run the next asset experiment against a fixed acceptance checklist:** one ship only, no text/grid/background, matching silhouette and palette, aligned pivots, distinguishable adjacent animation frames, clean transparency, and recognizable appearance at the game's rendered size.

## Reproduction record

- Tool: `mcp__host_browser__image_generate` (local Forge host tool)
- Prompt: `Create one original small arcade starfighter sprite for a vertical scrolling space shooter. Strict crisp pixel art, facing directly upward with its nose at the top, centered, symmetrical compact teal and midnight navy hull, twin small side hardpoints, one bright pale gold cockpit, cyan engine glow. Transparent-looking plain solid dark magenta background for easy later removal. Single isolated ship, no text, no border, no extra objects, no grid, no contact sheet.`
- Negative prompt: `photorealistic, smooth vector art, blur, antialiasing, gradients, multiple ships, text, watermark, frame, interface, cropped silhouette`
- Parameters: 512×512, 12 steps, seed 314159, default tier I0, count default 1
- Result metadata: model SDXS-512-0.9, backend Vulkan, license openrail++, 8.22 seconds, `has_alpha=false`, `first_use=false`, `bigger_tier_offer=null`
- Output: `/work/tmp/imagegen/img-1793415020293-314159-0.png` (ephemeral; not copied into the repository)
- Outcome: local inference succeeded; visual output did not pass the ship-sprite acceptance criteria.

Additional local-generation records (ship, cannon, and force field) are in `assets/research/local-image-pipeline/manifest.json`. The exact PNGs are checked in under its `raw/` directory so the results survive the Forge's ephemeral `/work/tmp/imagegen/` cleanup.

The first local preparation pipeline is `tools/prepare_local_image_candidates.py`. It uses local ImageMagick only, copies the immutable raw sources to a web review directory, creates 32×32 logical / 96×96 display previews with nearest-neighbor scaling and at most 16 palette colors, builds `candidate-atlas.png`, and writes `report.json`. It does not call the image model or any network service. Its report rejects all seven candidates because the originals are opaque and fail the recorded asset review. The local review page is `web/local-image-review/index.html` and is intended to be served at `/local-image-review/`.

`flutter build web --release` succeeded. The managed local Wrangler preview started at `https://www.demon-attack.localhost:18443`; its logs show HTTP 200 for `/`, `/local-image-review/`, the JSON report, the contact sheet, and all six raw/processed candidate PNGs. The host-browser MCP failed to retain a CDP window (`ERR_CONNECTION_CLOSED`) even though Wrangler logged successful page and asset responses, so the review page's full browser interaction and game playability could not be inspected through that browser session. The Wrangler worker also logged a failed DNS lookup for `workers.cloudflare.com` while trying to enrich `Request.cf`; it fell back to a placeholder and the local worker continued serving. No image inference or model request went to a hosted service.


## Enemy-creature reference pass

A follow-up local-only generation pass added references for all remaining enemy types: ordinary demon, shield sentinel, armored sentinel, and carrier boss. Each used the same local Forge `stable-diffusion.cpp` MCP tool, `SDXS-512-0.9`, tier `I0`, Vulkan backend, 512×512, 20 steps, and fixed seeds `731004`–`731007`. The tool reported `has_alpha=false`, `first_use=false`, and `bigger_tier_offer=null` for each; no larger tier was available through its consent flow. The four originals, prompts, negative prompts, seeds, hashes, run times, and review notes are preserved in the manifest and `raw/` directory.

The existing local review processor now builds a two-row contact sheet for all seven samples and provides the same full-size plus 32×32 nearest-neighbor views. These enemy images are reference material for comparing later models on other hardware; they are not passed as game sprites and no live renderer assets changed. The current local model remains an exploration baseline: outputs are opaque and do not establish stable character identity across frames, shield states, damage states, or angles.

## Expanded review page refresh

After the enemy pass, `flutter build web --release` completed successfully and the managed local Wrangler preview was reloaded on the research branch. Wrangler returned HTTP 200 for `/local-image-review/`, `candidate-atlas.png`, `report.json`, and all fourteen raw/preview PNG requests covering the seven candidates. The browser-control window again failed at navigation with `ERR_CONNECTION_CLOSED`; the service log nevertheless records the complete successful page and image request set. The Wrangler `Request.cf` lookup still logs `ENOTFOUND workers.cloudflare.com` and falls back to its local placeholder; the site remains served locally. The review URL is `https://www.demon-attack.localhost:18443/local-image-review/`.


## Astra-crafted prompt comparison pass

An Astra prompt-design agent read `plan/style-guide.md`, `plan/sector-style-guide.md`, `plan/sprite-atlas.md`, and the existing candidate manifest, then drafted nine tailored prompt/negative-prompt pairs: one additional candidate for each of the seven sprite/equipment test sets, plus KRYBOR and RINGFALL portrait background concepts. The sprite prompts specify the shared game palette, orientation, silhouette, logical size/readability, and hard pixel edges. The background prompts specify portrait 2:3 framing, edge-weighted landmarks, a mostly empty dark central firing lane, and subdued scenery so enemy/projectile colors remain brighter. Full prompt text and author attribution are recorded per candidate in the manifest.

All nine images were generated locally through the Forge `stable-diffusion.cpp` MCP tool using `SDXS-512-0.9`, tier `I0`, Vulkan backend, 20 steps, and seeds `731008`–`731016`. The seven sprite variants are 512×512; the two backgrounds are 512×768. Each returned `first_use=false`, `has_alpha=false`, and `bigger_tier_offer=null`. No larger tier was offered, no hosted generation was used, and each raw PNG was copied out of ephemeral storage.

The review atlas now contains fourteen sprite/equipment candidates (the original seven plus Astra-crafted variants). The page also puts two new portrait concepts directly beside the existing production backgrounds: KRYBOR against `assets/images/sector-1.png`, and RINGFALL against `assets/images/sector-2.png`. Visual review rejects both new backgrounds as replacements: the KRYBOR result is a crowded painterly city rather than a dark pixel frontier; the RINGFALL output is noisy/painterly, misses the defining ringed gas giant, and makes the firing lane too bright and busy. Their pairings are useful for later model comparisons. None of the sprite variants meet transparency or multi-frame consistency requirements, so no game artwork or renderer asset was replaced.


The latest expanded build was republished and `service_reload` reports the Wrangler service running at the same local URL. The generated `build/web/local-image-review/` contains a 14-candidate sprite report, two background comparisons, and all paired image files. However, the host-browser navigation again returned `ERR_CONNECTION_CLOSED`, and a container-side curl could not connect to the reverse-proxy URL; this reload's Wrangler log records HTTP 200 for the root only, not the review route. The local service is running, but end-to-end browser confirmation of the expanded route remains unavailable in this session.
