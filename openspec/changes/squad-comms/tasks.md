# Tasks

- [x] Shared `GameEvent` vocabulary and observer, read-only over the model, with derived events and the fleet tally.
- [x] Cast and line bank specs (`art/comms/cast.json`, `lines.json`) and the generated Dart bank.
- [x] Director: priority, cooldowns, TTL queue, the cap, interrupts, the rotating cast, slots, signature rationing, chains and moods.
- [x] Per-run seeded lineup with an anchor, avoidance of the previous lineup and persistence for resume.
- [x] Call UI: side tiles, the HUD-band stack, static transitions, glow, scanlines, idle motion, demon zoom, glyph subtitles and the banner.
- [x] Voice toggle next to sound; small sectioned `main.dart` hooks.
- [x] Kokoro voices, grunt synthesis, radio chain, Opus/AAC encode and manifest (`tools/comms_pipeline.py`).
- [x] `web/audio/comms-audio.js`: shared context, cap; node test. (Ducking removed by comms-pacing: music volume is constant.)
- [x] Portrait pipeline and atlases (`tools/comms_portraits.py`, `art/workflows/comms/`).
- [x] Tests: director, lineup, events, layout; review renders.
- [x] Docs: audio backend, asset pipeline, provenance.
- [ ] Ground-forces branch: emit `groundForceSighted`, `groundForceInRange`, `homingPickup`, `allyUnderAttack`, `allySaved`, `allyRetreated` (or `allyLost`) from the model; the lines are ready.
- [ ] Music branch: cue a fleet-intact flourish on `flawlessVictory` / `flawlessRun` from the shared stream.
