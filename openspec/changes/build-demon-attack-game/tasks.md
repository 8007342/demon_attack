# Tasks

## 1. Research and art direction
- [ ] 1.1 Document cited original-game descriptions and screenshots and deliver level, monster, screen and music style guides in plan/.
- [ ] 1.2 Generate original sky and animated combat sprite assets; verify atlas dimensions and loading in the built game.

## 2. Combat
- [ ] 2.1 Implement deterministic waves, swarm/predator AI, hit transformations, auto-fire, powers and lives; verify model tests for damage, expiry, scores and boundaries.
- [ ] 2.2 Implement shield/door boss, flock spawning, evolving phases and loop escalation; verify protected-core and victory-cycle tests.

## 3. Presentation and input
- [ ] 3.1 Build title, HUD, pause, game-over, victory and controller UI; verify phone/desktop input and responsive layouts.
- [ ] 3.2 Integrate pixel animation, explosions and rising/setting parallax sky; verify browser screenshots.
- [ ] 3.3 Integrate adaptive MIDI synthesis, level/boss/victory cues, mute and lifecycle pause; verify synth sequencing and browser audio activation.

## 4. Persistent scores
- [ ] 4.1 Implement Durable Object Top10, bounded validation and persistence with backend tests; document API and caveats.
- [ ] 4.2 Integrate three-wheel initials UI and scoreboard loading, retry, unavailable and empty states; verify widget/browser behavior.

## 5. Integration
- [ ] 5.1 Wire Worker assets, migration and build; pass analyze, Flutter tests, backend tests, release web build and strict OpenSpec validation.
- [ ] 5.2 Refresh Wrangler preview, verify API persistence and playable browser flow, document test evidence, and push validated checkpoints to game only.

## Workflow follow-up
- Review gameplay tuning on the host browser before merging a stable release into main.
