# Proposal

## Why

Combat sprites were drawn on a 32 × 32 grid with four-pose wing toggles, code-drawn elite plates, tinted hit flashes and generic deaths. The user decided to raise the creature grid to 64 × 64 for 16-bit-level detail at the same on-screen size, with fully articulated wing strokes, visible armour, rank insignia and animated weapon mounts, authored cannon hardware and firing for every weapon, and better enemy and carrier animation, produced by a reproducible ComfyUI-assisted pipeline.

## What Changes

- New atlas contract (plan/sprite-atlas.md): combat.png 1024 × 2048 on a 64-grid; ship-weapons.png for hull, modules, recoil, muzzle flashes, deploy transitions, shield bubble and projectiles; sentinel-effects.png on a native 128 × 64 grid with hit-flash, smoke/flame and beak-fire rows; boss-carrier.png at native 368 × 240 with blast doors, side hatches and charred wreck forms.
- Renderer: atlas lookups in lib/game/sprite_atlas.dart and lib/game/ship_painter.dart; scene-side presentation tracking (which creature fired, which died) that reads the model and never writes it.
- Pipeline: art/workflows/sprites (SDXL + pixel-art-xl keyframes, Qwen-Image-Edit molt variants), art/families/sprites (validated family spec, locked palette, seeds, selections, finished detail maps) and tools/sprite_pipeline.py.

## Capabilities

### Modified Capabilities
- `arcade-presentation`: 64-grid sprites with articulated strokes, armour and insignia, authored anticipation, fire, hit and death frames; authored cannon recoil and muzzle flashes per side; carrier hatches and wreck.

## Impact

- No simulation change: rendered sizes (40/44 creatures, 48 ship, 128 × 64 sentinels, 184 × 120 carrier), hitboxes, timings, damage and fire rates are unchanged; muzzle anchors keep the research-branch values.
- `test/pixel_combat_visuals_test.dart` checks the new effects-atlas contract.
