# Proposal

## Why
Single short waves and static title cards make sector progression feel abrupt. Extend each level into a paced sequence and reward completion with continuous animated and musical interludes before a more durable boss encounter.

## What Changes
- Three waves in LV1–2 and four in LV3–4, with growing roster variety and short animated entrances.
- Four-second level-clear victory sequence, four-second travel cutscene, and eased arrival rather than an immediate scene reset.
- Distinct original MIDI level-clear and travel cues with responsive victory onset and smooth track handoff.
- Fourfold boss shield endurance (72 + 18 per cycle) and core 24 + 10 per cycle.
- Wave HUD, transition progress, safety from damage and frozen power timers during cutscenes.

## Capabilities
### New Capabilities
- `arcade-progression`: wave pacing, cinematic level flow and boss endurance.
### Modified Capabilities
None. Existing in-flight combat and presentation requirements remain compatible; this change specifies the detailed pacing defaults.

## Impact
Pure Dart combat model, Flame scene, Flutter HUD/interlude overlay, MIDI generator/scheduler, progression tests and plan guides. Work and push on game; rebuild and reload local Wrangler. No production/main update requested.
