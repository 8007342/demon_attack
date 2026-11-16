# Proposal: The carrier rendering engine (C3)

## Why
From the operator's round 3b on 2026-11-16 (`plan/operator-feedback-2026-11-16.md` C3), after the carrier-v3 runtime
landed on `game` (3ceec704):
- **The collapse.** The components fall apart as separate random assets, each moving linearly, instead of as one
  cohesive unit. The off-screen sections "fall off", which shows they were only partial assets.
- **The bend.** It warps a few separate layers individually and looks worse. "The ship's light deformation might be
  the right way to go, but it needs proper research, spec, and tuning." The bend exists to show the ship's huge size
  through slight turns. The operator lets us drive the rendering-engine research and fixes.
- **The force field.** It should thin out, its thickness and opacity wearing down, instead of its regions narrowing
  inward. It took the operator a while to understand that the field was wearing down.

The research, with its sources, is in `plan/carrier-render-engine-research.md`. The causes, read from the code, are in
`design.md` §1.

## What Changes
- **Compose, then warp.**
  - Each pass of the hull (the back and the prow) is composed once into ONE texture.
  - The texture is cached until the damage state changes.
  - ONE continuous grid mesh with shared vertices warps it, driven by one smooth height field.
  - The per-layer meshes, per-mount heights and wing lag are gone, so no layer can drift against another.
  - The hit windows, the bend's limits and its springs are unchanged.
- **A cohesive collapse.**
  - The hull as it was at death is composed into one texture and cut into a two-level hierarchy: up to three sections
    (the wings and the stern), then chunks inside each.
  - Every piece is a rigid body of one closed-form model. It rides its parent until it is released. At release it
    inherits the parent's velocity at its own pivot (v + ω × r) and spin, plus a small separation kick.
  - The hull sags, cracks along its structure, lists slowly and sheds sections, then chunks. The whole wreck recedes at
    one depth scale and sinks into the cloud deck as one structure.
  - Off-screen parts stay attached and carry their full art out of frame. The cut edges of the art are feathered until
    the re-render's extended art lands.
  - Smoke is emitted in world space from the cracks, and blasts ride the pieces.
- **The field thins in place.**
  - The membrane holds one offset from the hull at every shield level.
  - Its width and opacity wear down with the shield, and coherent patches wear through and crawl.
  - A lost cell's region is worn through where it is, never switched off, so the field never shrinks inward.
  - A low field crackles locally, under the WCAG 2.3.1 flash limits.
  - At shield down it thins to nothing and breaks apart where it is.
  - The gameplay intercept is unchanged.
- **Interfaces for the re-render** (`work/carrier-v3-render`): composable layers, height grids per layer, chunk and
  section masks, tip points, and art past the visible frame. Each has a working fallback on today's art (design §5).
- **Tools.** `tools/gifstrip` (Go, stdlib) packs review frames into the GIF strips.

## Capabilities

### Modified Capabilities
- `arcade-presentation`: how the carrier hull is drawn and bent, how it collapses, and how its field shows wear.

## Impact
- Code: `lib/game/carrier_compose.dart` (new), `lib/game/carrier_wreck.dart` (new), `lib/game/boss_painter.dart`,
  `lib/game/carrier_bend.dart`, `lib/game/carrier_field.dart`, `lib/game/boss_director.dart`,
  `lib/game/carrier_presentation.dart`, `lib/game/scene.dart` (one hook in `_bossWrecks`).
- Tests: `test/carrier_render_engine_test.dart` (new), `test/carrier_render_engine_review_test.dart` (new, `review`),
  `test/carrier_bend_test.dart`.
- Sheets: `art/contact/carrier-render-engine-{bend,collapse,field}.png` and the two GIF strips.
- The model and the balance are untouched: no simulation code changes, and the calibration gates hold.
