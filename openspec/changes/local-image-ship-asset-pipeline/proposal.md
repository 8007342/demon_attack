# Proposal

## Why

The local Forge generator can produce image candidates, but the current agent tool emits opaque, prompt-only images that do not meet the game's pixel-grid, transparency, or frame-consistency requirements. We need a repeatable local-only path from model output to reviewable ship, equipment, effect, and enemy-creature prototypes before any generated art enters the combat atlas.

## What Changes

- Add a local asset-preparation command that accepts output from the Forge's local image model, records prompt/model/seed provenance, and deterministically converts sources into pixel-grid previews and a documented sprite sheet.
- Add a local review page for the generated source images and processed ship, weapon, shield, and enemy candidates, including animation/timer-state previews where generated frames can be derived safely.
- Keep generated candidates separate from shipping combat assets until reviewed; do not use hosted image services or transmit prompts/artwork to remote inference services.
- Document the current model's quality limitations and a manifest-based path toward prompt-driven modular additions such as “add cannons.”

## Capabilities

### New Capabilities
- `local-image-asset-pipeline`: Local-only generation handoff, deterministic asset preparation, provenance, validation, and review for game sprite candidates.

### Modified Capabilities
- None. This change adds a developer-facing asset workflow and review surface; it does not alter combat rules or shipping runtime behavior.

## Impact

- Adds local tooling under `tools/`, candidate images and provenance under `assets/research/` or `plan/`, and a review page under `web/`.
- Uses the Forge's existing local `stable-diffusion.cpp` MCP generator for inference and local image-processing tools only; no cloud image API or new runtime dependency.
- Does not replace `assets/images/combat.png` or modify player combat mechanics.
