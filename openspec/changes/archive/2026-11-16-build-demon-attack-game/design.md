# Design

## Context
The repository currently renders a Flutter construction screen with a static Flame starfield. It bundles a pinned Flutter web build through Wrangler static assets. See proposal.md for motivation. The operator tests the managed preview and requests changes on game only.

## Goals / Non-Goals
Goals: responsive browser-first play, deterministic testable combat, original crisp sprite assets, shared casual scores, music which can evolve without abrupt cuts.
Non-goals: multiplayer, accounts, personal names, and cheat-proof competition. Native packaging remains compatible but this iteration validates the mobile/desktop web build.

## Decisions
- Keep simulation in a pure Dart model with a bounded fixed timestep and seeded randomness. Flame renders that model; Flutter handles focus, pointer input, overlays and accessible controls. A monolithic component tree is harder to deterministically test.
- Use a portrait logical arena with horizontal-only ship motion. Desktop receives a centered cabinet layout; mobile reserves a controller area below combat so fingers never obscure the ship.
- Use authored pixel-grid sprites rasterized into an atlas with explicit animation frames and generated bitmap sky art. Nearest-neighbor rendering protects pixel edges. Background layers animate independently from combat.
- Four levels precede each boss. Cycle counts increase speed and transformation counts with bounded density, and boss phases change exposed-door timing and spawned demons. Preserve score/lives across loops.
- Audio is a browser Web Audio synthesizer driven by MIDI note events, loaded before Flutter and called through a conditional JS bridge. Tracks switch on phrase boundaries with fades; the initial Start action unlocks audio. A silent native bridge permits non-web compilation.
- The Worker routes /api/scores to one named SQLite Durable Object and delegates everything else to ASSETS. Only exact three-character initials, bounded safe integer scores and bounded request bodies are accepted. No arbitrary strings stored.
- Client scores are untrusted casual scores. Enforce input limits and submission pacing, document that determined players can forge scores; a server-authoritative game would be a separate architecture.

## Risks / Trade-offs
- Generated art can be inconsistent → pixel-grid combat atlas has deterministic silhouettes; generated background is atmospheric with low contrast.
- Audio autoplay restrictions → Start unlocks synthesis; mute remains available and app background pauses.
- High-DPI rendering and multitouch → fixed logical coordinates and clamped pointer deltas with single active pointer.
- Touch move vs desktop keyboard → same model target position, tested boundaries and collision rules.
- Preview runtime/config generations → rebuild web, reload managed Wrangler after binding changes and verify API plus assets.

## Migration Plan
Add a v1 SQLite Durable Object migration and ASSETS binding, validate through local Wrangler, and push game checkpoints. Keep production main unchanged until stable. Rollback code by reverting on game; preserve score storage rather than deleting its migration.
