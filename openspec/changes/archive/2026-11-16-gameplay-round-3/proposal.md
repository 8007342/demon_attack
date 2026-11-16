# Proposal: gameplay round 3 (life loss, ground war v2, /console)

## Why
The user played a few levels and gave feedback:
- A lost life was a blink in place. They want an event: an explosion, a breath, and a return.
- The ground war looked good, but they never saw ground fire. Homing missiles hit ground units as fast as air targets, the effects could be richer, and the allies looked like placeholders that scrolled off the screen like scenery.
- Testing late content meant replaying the campaign.

## What Changes
- **Life-loss sequence.**
  - A non-final hit starts a rich pixel explosion, with hull shards and fitted modules flying.
  - A 1.6 s regroup follows. Hostile shots fizzle out, ground missiles in flight end, the swarm flies back to formation, and nothing can hit the player.
  - The reserve ship then flies up from the bottom edge with 2 s of blinking protection, and play resumes.
  - Three new events: `playerDestroyed`, `regroupStart` and `playerRespawn`.
  - Unchanged: scoring, lives and the loadout rules. Module timers freeze while the ship is away.
- **`divePrep`.** Every dive tell is preceded by a 0.5 s beat and a `divePrep` event, so the demons can radio before diving.
- **Ground war v2.**
  - Homing missiles fired at ground targets fly a long perspective arc. They climb away, arc out and dive into the ground plane, shrinking and fogging, and leave a perspective smoke trail. Flight is 0.95–1.75 s by depth. Air targets stay fast.
  - The allies are a convoy. They hold station in the near band beside the ship and advance up the plane only to engage, then fall back. A replacement rolls in from below when needed.
  - Breakthroughs are now visible:
    - L2 has near misses (`groundNearMiss`): the allies stop a unit just short of fire range, and it never fires.
    - L3 and L4 guarantee one telegraphed breakthrough per sector visit (`allyUnderAttack`, then `groundBreakthroughWarning`, then `groundBreakthrough`).
    - L4 keeps regular breakthroughs.
  - Ground art v3 has richer allies (two variants per sector, turrets, squads, walkers) and multi-frame effects.
- **`/console`.** A web route with buttons to start any sector 1–5 on any run 1–5 and difficulty, plus boss and sentinel jumps. Runs start at 0 points and follow the normal top-10 rules.

## Capabilities
### Modified Capabilities
- `arcade-combat`: the life-loss sequence; ground homing flight; allied convoy.
- `arcade-progression`: near misses and guaranteed breakthroughs; console starts.
- `arcade-presentation`: the explosion, regroup and respawn visuals; new events; ground art v3; the console page.

## Impact
- Code: `lib/game/model.dart`, the new `lib/game/life_loss.dart`, `ground_war.dart`, `game_events.dart`, `scene.dart` (the life-loss section), `ground_painter.dart`, `ship_painter.dart`, the ground atlas pipeline, `lib/main.dart` (the console route section) and the new `lib/widgets/dev_console.dart`.
- Tests: the existing tests are adapted to `divePrep` and the life-loss sequence.
- Profiler: `tools/profile_difficulty.dart` reports near misses.
