# Proposal: The Carrier, redesigned (C1)

## Why
From the operator's third playtest on 2026-11-16 (`plan/operator-feedback-2026-11-16.md` C1), after the v2 Thornwake
carriers landed in the game (boss-carrier-wire, 713297fa):
- "The big ship looks great." The zoom-out and the spill off-screen work "great", and together they're "fantastic".
- The angle variations are **way too much** for the ship's size: the discrete 38/45/52° pitch views and the ±12° swerve
  views.
- The force field is still the frigate's 220-unit arc under the deck. It must be redesigned for the new size and shape.
- "The Carrier" must launch the smaller creatures from compartments and gates on its hull. The boss level's first waves
  come off the carrier before it can be hit.
- **The new intro:**
  - the ship approaches from the distance until it is close enough to hit;
  - then it takes off and climbs, and we follow;
  - the ground battle drops lower and smaller and the camera zooms out (the current zoom-out stays);
  - each later carrier zooms out a little more, to show off a larger ship.
- The boss fights should be the most memorable part of the game: "large as fuck", a ginormous ship moving ultra fast.

The research behind every decision, with its sources, is in `plan/carrier-v3-research.md`. The re-render plan is in
`plan/render-runs/carrier-v3.md`.

## What Changes
- **One pitch, bent at runtime** (replaces the 3 × 3 view set):
  - the carrier is drawn from its single hero view (45°, yaw 0) as one textured triangle mesh per pass, the technique
    the terrain already uses;
  - an analytic bend fakes heading lean, bank and pitch: at most 3°, 2.5° and 2° (3° in the take-off beat);
  - the bend is pivoted on the hangar deck, so the hit windows never move;
  - wings and arms lag the hull (follow-through), and every bend is driven by heavy, critically damped springs;
  - the stored 38/52° and ±12° views are retired.
- **Hull-conforming force field** (replaces the arc):
  - a rim-lit membrane that follows the hull's silhouette at an offset that tightens as the shield wears;
  - it is split into 12 regions that go dark from the outer arms inward, so the prow's region falls last;
  - a hex lattice shows only near impacts and in a slow scan;
  - it is drawn by a fragment shader from a baked per-hull distance and region texture;
  - the shield's gameplay intercept surface is unchanged and drawn exactly as the field's front lip, so balance does
    not move.
- **Gates and compartments.**
  - Hull gates (prong gates, flank maws, dorsal compartments, brood sacs) launch creatures:
    - a telegraph of 1.2 s;
    - the doors open (0.5 s);
    - the creatures eject along the gate's normal at 0.12 s intervals;
    - the doors close.
  - The boss level's opening waves (today's loom waves) launch from the approaching carrier's gates instead of the fog.
  - In the fight, the carrier's minion flocks come out of its on-screen gates instead of one bay point.
- **The new intro: Overflight → Approach → Close → Take-off → Climb → fight**:
  - Approach replaces Loom and Rise. The carrier starts far ahead at distance factor D = 4 (a quarter of its fight
    scale, hazed toward the fog colour) and closes as each launch wave is cleared.
  - The Close (D 1.35 → 1 over 4 s) ends at the **hittable threshold** D = 1.
  - The **Take-off** beat (2.4 s) pitches the world, rushes the fog and climbs. The camera follows, the ground battle
    drops lower and smaller, and the zoom eases out.
- **Per-carrier zoom.** Each tour's carrier frames a little wider:

  | Tour | 1 | 2 | 3 | 4 | 5 and later |
  | --- | --- | --- | --- | --- | --- |
  | Minimum zoom | 0.70 (today) | 0.68 | 0.66 | 0.64 | 0.62 |

  The draw-size floors, the bullet floor and the visible envelope are re-derived per tour.
- **Ultra-fast motion cues**, chosen from the research:
  - streaks in the fog;
  - faster, differential cloud-layer flow;
  - vortex trails from the prong and wing tips;
  - torn cloud wisps over the hull;
  - a slow, low buffet in the bend;
  - trauma-based shake on four named beats only;
  - none of them under reduced motion.
- **Composable.** A `CarrierScript` per tour, seeded per run, holds every number above: approach waves, gates, volleys,
  distances, zoom, altitude, bend limits, cue intensities and field style. Tours beyond 5 are seeded within the same
  budgets.
- **Audio events** for the future score:
  - `bossApproach`, `bossGateTelegraph`, `bossGateOpen`, `bossLaunch`, `bossGateClose`;
  - `bossInRange`, `bossTakeoff`, `bossClimbPeak`;
  - `bossFieldImpact` (throttled), `bossSpeedSurge`, `bossCloudPunch`.
- **Re-render** (`plan/render-runs/carrier-v3.md`):
  - one stored view plus the belly;
  - hulls built for bending: under-painted occlusion margins, and a height, distance and region grid;
  - gate and compartment modules with door states;
  - the face and teeth fixes;
  - S2 and S3 looks for tours 2–5;
  - per-tour envelopes;
  - each hull stays within ≤ 16 MB.

## Capabilities
### New Capabilities
(none)

### Modified Capabilities
- `arcade-presentation`:
  - MODIFIED: the boss views (`boss-grandeur`'s "Boss swerve and pitch views") and the carrier camera framing (the
    per-tour zoom);
  - ADDED: the runtime bend, the hull-conforming force field look, the approach presentation, take-off and climb,
    speed cues and reduced motion.
- `arcade-combat`:
  - ADDED: gate launches, gate minion spawns, the hittable threshold, the unchanged shield intercept, and the intro
    events.
- `arcade-progression`:
  - MODIFIED: the boss level's opening waves (`boss-grandeur`'s loom and rise) become carrier launch waves and the
    approach;
  - ADDED: the composable carrier script.

`boss-grandeur` is not archived yet; its requirements that this change modifies exist only in its delta. **Archive
`boss-grandeur` first, then this change** (`openspec validate` notes this order).

## Impact
- **New** (pure Dart where possible):
  - `lib/game/carrier_script.dart`: per-tour scripts and the seeded scripts beyond tour 5;
  - `lib/game/carrier_bend.dart`: the analytic bend, its springs and limits, and the mesh builder;
  - `lib/game/carrier_gates.dart`: the gate state machines and volleys;
  - `shaders/carrier_field.frag`.
- **Changed:**
  - `boss_director.dart`: the Approach, Close and Take-off phases, the bend drivers and the per-tour zoom;
  - `arena_camera.dart`: the per-tour band;
  - `model.dart`: launch waves from gates, gate spawn points in the fight, approach progress replacing emerge;
  - `boss_painter.dart`: the mesh draw, one stored view and the field;
  - `scene.dart`: the approach draw slots, aerial perspective and speed cues;
  - `atmosphere.dart`: streaks and differential flow;
  - `game_events.dart` and `music_director.dart`;
  - `tools/boss_sheet` pack: gates, the data texture and a single view;
  - `tools/rigkit` and `tools/rigsheet`: the bend-ready bake.
- **Assets.** One re-render per hull; until it lands, the bend runs on today's (45°, 0) view with per-module heights.
- **Tests:**
  - bend anchor invariance (±3 units);
  - gate volley determinism;
  - approach steps and cap;
  - hittable threshold;
  - per-tour zoom floors;
  - an identical event log at every zoom;
  - field intercept equivalence;
  - the boss endurance and campaign calibration within the boss-grandeur gates;
  - review strips `art/contact/carrier-v3-*.png`.
