# Design

## Context

The Forge MCP image tool runs local `stable-diffusion.cpp` inference and writes PNGs to an ephemeral directory. Its current I0 interface accepts prompts and output controls but no image-reference input or transparency control. Multiple actual outputs were therefore captured as research sources; none meets the project's production sprite contract. Astra prompt-designed sprite variants and two paired sector-background concepts extend the comparison set. See `FORGE_DIAGNOSTICS.md` for the measurements and prompt records.

## Goals / Non-Goals

**Goals:**
- Preserve generated sources and provenance in the research branch.
- Produce deterministic, visibly pixelated previews and an automated rejection report using local tools only.
- Serve a local review page that makes model output quality, Astra prompt variants, and local background comparisons easy to inspect.

**Non-Goals:**
- Changing the production combat atlas or player rendering in this experiment.
- Hiding the generator's opaque backgrounds or treating a pixelated image as animation-ready.
- Implementing natural-language parsing or direct model inference from game code.

## Decisions

1. **Use the existing local MCP generator for inference.** It has already completed local Vulkan inference and returned reproducible model/seed metadata. The workflow calls it directly from the agent; no hosted image tool, API key, Ollama image adapter, or unverified ComfyUI sibling is introduced.
2. **Keep raw sources and derived previews separate.** Raw outputs plus prompt/model metadata live under `assets/research/local-image-pipeline/`; processed, web-served candidates live under `web/local-image-review/`. They do not enter `assets/images/combat.png` or Flutter's declared runtime image directory.
3. **Use a local ImageMagick command for deterministic reduction.** Reduce each 512px image to a 32px logical preview with point sampling and a bounded palette, then enlarge with nearest-neighbor scaling. ImageMagick is available through the Forge's local package shim. The processing script fails with a local dependency message if `magick` is unavailable; it never downloads tools or calls a network API itself.
4. **Treat opaque or non-isolated output as rejected.** The processor reports dimensions, alpha presence, palette size, and the explicit quality gate. The current model outputs have no alpha and fail the isolated-sprite gate. The review page shows both raw and reduced forms with the failure visible instead of implying that chroma removal or resizing fixed the art.
5. **Serve a static review surface.** The project build copies a page under `web/`, derived sprite previews, and paired copies of the current sector paintings next to the generated background concepts. The existing local Wrangler service can serve it without changing game routes or the combat renderer.

## Risks / Trade-offs

- **The I0 model may keep ignoring asset constraints.** The page and report are intended to expose that limitation; no rejected image is silently promoted.
- **Palette reduction can hide details or make the art worse.** Raw images remain available beside every preview, and the palette cap is recorded in the manifest.
- **The Forge output directory is ephemeral.** Copying each chosen raw output into the branch preserves the exact source used for the prototype.
- **ImageMagick may not be installed in another environment.** The script checks for it and reports the prerequisite; the Forge shim can install it locally when invoked.

## Migration Plan

No gameplay migration is required. Generate sources locally, copy the selected PNGs and metadata into the research source directory, run the local processor, build/serve the existing project preview, inspect `/local-image-review/`, and leave rejected candidates in research storage. Removing the review page and research directory rolls the prototype back without touching production game assets.

## Open Questions

- Which host-side ComfyUI or direct `stable-diffusion.cpp` service, if any, can expose image references and control inputs? This does not block the prompt-only review prototype.
- Which local model tier and model license are suitable for future higher-fidelity sprite generation? The current generator returned no larger-tier offer, so this experiment stays at I0.
