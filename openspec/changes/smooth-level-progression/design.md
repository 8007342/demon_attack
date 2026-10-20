# Design

## Context
Current levels clear after one roster and immediately reset into a static 2.3-second card. Only boss death emits a victory cue; its shield has18HP. See proposal for requested pacing changes and plan/transition-research.md for cited animation/music research.

## Goals / Non-Goals
Goals: longer levels, readable moments of release between action, deterministic cinematic timing, no combat damage during interludes, and a boss with a substantially longer shield phase.
Non-goals: prerecorded video, new engine or assets, and production deployment. Reuse the pixel atlas and MIDI synthesizer.

## Decisions
- Add explicit levelClear and travel states to the fixed-step model. Shared transitionDuration/transitionProgress drives both Flame motion and Flutter overlays; do not add independent timers which could drift or continue during pause.
- Separate wave advancement from level advancement. Three/three/four/four rosters, modestly more enemies in later waves, with mixed species introduced only after their initial level. Preserve powers and pickups during short same-level entrances; freeze power expiry while combat is suspended.
- Preserve the defeated sector during celebration. Move the destination/environment during travel, then spawn the next encounter under an eased entrance. Keep ship motion continuous with cubic/smoothstep easing and star streaks, rather than just fading a text card.
- Use deterministic procedural sparks, carrier debris, flight trails and letterboxing with existing sprites. This keeps loading and pixel style consistent.
- Add an immediate level-clear musical stinger with a brief voice fade; bridge and encounter cues retain beat/bar alignment. All durations use the existing120BPM musical grid.
- Increase shield to72+18*cycle and core24+10*cycle. Keep shield finite and door mechanics unchanged; damage feedback remains tied to health.

## Risks / Trade-offs
- Longer interludes may slow repeat play → short wave entrances; reserve full celebration/travel for sector completion.
- Multiple waves can remove an uncollected power → preserve pickups across same-level entrances.
- Pause can desynchronize animated UI and world → derive all motion from model progress and use presentationMode while paused.
- Stronger shield can feel like a sponge → retain impacts/health feedback and boss flock pressure; tune after host playtest.

## Migration Plan
Add no storage migrations or dependencies. Validate model progression, paused rendering, cue timing, phone/desktop layout and release build. Push game and reload local managed Wrangler; do not merge main in this task.
