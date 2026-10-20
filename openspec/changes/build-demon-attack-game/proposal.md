# Proposal

## Why
Turn the construction page into a playable mobile-first arcade remake: organic demon swarms, an evolving shielded boss, and a repeatable score chase. Honor the original's readable silhouettes with original pixel art, modern parallax worlds, and adaptive synthesized music.

## What Changes
- Replace the construction-only screen with title, play, pause, game-over, victory transition, and Top10 screens.
- Add four progressively difficult levels and a low-flying carrier boss with depleted shield, sliding-door weak point, and spawned flocks.
- Add perpetual fire, touch trackpad and arrow controls, three lives, temporary powers, damage transformations, angry predators, and escalating repeat cycles.
- Generate original graphics and define art, motion, progression, and musical style guides in `plan/`.
- Add MIDI-event synthesized adaptive soundtrack and sound effects with mute and lifecycle control.
- Persist Top10 scores in a Cloudflare Durable Object; accept exactly three A–Z/0–9 initials.
- Work and push checkpoints on `game`; reserve `main` for stable reviewed releases.

## Capabilities

### New Capabilities
- `arcade-combat`: simulation, controls, waves, collisions, powers, boss and repeated runs.
- `arcade-presentation`: original animated pixel artwork, planetary parallax, menus, HUD and adaptive MIDI music.
- `high-scores`: Durable Object Top10 with three-wheel initials entry and network failure handling.

### Modified Capabilities
- `demon-attack`: replace construction-only landing behavior with playable title and Flame game.
- `deployment`: serve score API alongside bundled assets and bind a Durable Object.

## Impact
Flutter/Flame code, generated image and MIDI assets, web audio bridge, same-origin Worker API and Wrangler migration. No production deployment until stable; existing static asset route becomes a Worker-backed route. Scores are casual and bounded, not cheat-proof; no names or free-form text are collected.
