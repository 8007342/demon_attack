# Proposal

## Why
Players find the carrier disproportionately hard, and interrupted sessions lose all progress. A finite, narrated campaign with adaptive difficulty unlocks and visible achievements will make progress approachable and rewarding while preserving a demanding Hard mode.

## What Changes
- Add Easy (five starting lives), Normal and Hard (three starting lives), permanent local unlocks, distinct enemy density and points, and mode-specific Top10 boards.
- Save compact, version-tolerant wave-start checkpoints; Resume restarts that wave without powers.
- End the campaign after five boss victories, awarding a difficulty-specific medal and +1UP after each; count only active playtime.
- Add rare complementary heart pieces in Easy/Normal with three unfinished heart slots.
- Expand later-run waves and introduce scarce, armored wide-wing enemies with distinct defeat animation.
- Name all route variants, enrich themed parallax, enlarge story interludes and travel progress, and connect carrier collapse, fleet recognition and the next route.
- Replace boss health bars with symmetric, depleting shield geometry and progressive damage effects; fix controller-label displacement.
- Preserve existing scores and extend rows with five medal slots, time, and finishing lives for completed campaigns.

## Capabilities

### New Capabilities
- `run-persistence`: compatible wave checkpoints and permanent local difficulty unlocks.

### Modified Capabilities
- `arcade-combat`: difficulty tuning, density, armored special enemies and heart collection.
- `arcade-progression`: five-boss ending, rewards and active playtime.
- `arcade-presentation`: medals, readable story scenes, named parallax routes and boss feedback.
- `high-scores`: per-mode boards and backward-compatible achievement metadata.
- `demon-attack`: unlocked mode selection, Resume and named HUD destinations.

## Impact
Flutter/Flame model, scene, backgrounds, story, landing/HUD/controller widgets, a local storage abstraction, score client and Cloudflare Durable Object schema/API; model, widget, migration and browser verification. Existing endless-run expectations must change. Existing scores remain Normal entries with absent metadata defaulted. No production deployment is included.
