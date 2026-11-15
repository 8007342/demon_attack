# Design: transition ascent

Builds on `cinematic-flow` (FlowDirector plans, beats `climb` / `tilt` / `cloud` / `swap` / `pursue` / `slot`, design
§2 and §10) and the playtest fix that made every transition speak only by radio (b0e89ae6).

## 1. Beats (`FlowPlan.sectorChange`)
Today's beats are `climb` (p0 → p1 + 1.6), `tilt` (cloudUp → p1 + 1.8, a flat 46-unit translate) and the flyover
speed `1 + 9 sin(πp)` in `RunMode.travel`. New and changed beats:

| Beat | Envelope (full motion) | Meaning |
|---|---|---|
| `speed` | rises p0 → swap (ease-in cubic), holds to p1, falls p1 → p1 + 2.0 (ease-out) | world speed factor `1 + 7·env` (reduced: `1 + 1·env`) |
| `pitch` | cloudUp → cloudFull, holds, out p1 − 0.3 → p1 + 1.8 | camera pitch-up, 0 → 1 (reduced: gain 0) |
| `roll` | p0 + 0.3 → p0 + 1.5, out p1 → p1 + 1.2 | bank toward `dir`, ≤ 3° (reduced: gain 0) |
| `climb` | unchanged timing, **amplitude 24** (was `plan.climb`) | the ship's own on-screen rise |
| `streaks` | p0 + 0.5 → swap, out p1 → p1 + 1.0 | fog streaks past the ship (reduced: gain 0) |
| `tilt` | kept for the campaign outro and game-over only | the sector change stops using it |

The swap still happens inside the cloud's peak. The new beats only change how the world moves under the cloud, so the
continuity rules of cinematic-flow §2.1 (never a hard cut, one message at a time) are unchanged.

## 2. Camera pitch (the "background tilts as it slides down")
The world layers (sky, flyover ground, ground units, fog bands, shadows) are drawn under one **pitch transform** in
place of the flat translate. With pitch amount `q` (0 to 1):
- **Horizon drop.** The horizon line moves down by `H = 96·q` units.
- **Ground foreshortening.** A ground row at screen y moves to `y' = horizon + H + (y − horizon) · (1 + 0.35 q)`.
  Near rows slide down more than far rows (they leave the bottom edge first). This is a rotation of the ground plane
  about the horizon, which is what makes the ship read as climbing rather than the picture moving.
- **Implementation.** A vertical affine scale plus translate about the horizon row, applied to the ground layers. The
  sky band above the horizon translates by `H` only (no scale), and the uncovered top band is already cloud, as
  `flowTilt` relies on today. No per-pixel warp is needed: both are canvas transforms.
- **Roll.** `roll·3°·dir` is applied about the ship's position, to the world layers only. HUD, comms dock, ship and
  bullets are never rolled.
- **Ship.** It rises ≤ 24 units and keeps its nose-up pose, thrust `1 + 2.5·climb + 1.5·speed`, and a scale nudge of
  `1 − 0.04·speed`. Its own shadow (terrain-shadows) falls away and shrinks with the horizon drop, a free cue that it
  is climbing.

## 3. Acceleration
- `FlyoverBackground.update` takes `factor = 1 + 7·flow.env('speed')` during a flow and drops the `RunMode.travel` sin
  bump.
  - The peak is ×8 (today ×10, but only for an instant mid-travel). The ramp spends longer at high speed, and the
    peak sits in the cloud where nothing needs to be legible.
  - With the reduced tier: `1 + 1·env`.
- The same factor scales:
  - fog layer scroll (`Atmosphere`);
  - ground unit visual drift, presentation only (gameplay is paused in transitions anyway);
  - critter and flock reactions.
- **Streaks.** 10–14 thin fog streaks (2 × 18–40 units, alpha ≤ 0.35, cloud tint) rush down past both sides of the
  ship, at a speed proportional to the factor. They are seeded from the transition's plan seed and drawn in the cloud
  pass.

## 4. Front-line calls
**Selection** (`InterludePlanner.planRadio`, the sector-change slot only):
1. If the destination sector was already visited in this run (the tour index > 0, or the route revisits it), pick
   from `frontCall.<destination>`, then from `frontCall`.
   - Lines are filtered by the existing lineup and recency rules.
   - The destination-specific line wins when both fit the window.
2. Otherwise, or when nothing fits the window, use today's order: the seeded category, then any fresh line, then the
   shortest line.
3. `bossArrival` slots and victory transitions are unchanged.

**Why the destination.** The call comes from the front the squadron is turning back to. Tour after tour this explains
why the same five sectors come round again: the brood keeps pushing the lines the player already cleared.

**Lines** (`art/comms/lines.json`, priority 5, cooldown 45, ttl 3, mood worried):

| Clip id | Speaker | Emotion | Text | Placeholder (plays with its own subtitle) |
|---|---|---|---|---|
| `frontCall.h0` | march | panicked | We're getting overwhelmed here! | `groundPressureHigh.h2` |
| `frontCall.h1` | kessler | panicked | They're everywhere down here! We need you back! | `groundPressureHigh.h0` |
| `frontCall.h2` | voss | panicked | Lantern's being overrun! Anyone up there? | `groundPressureHigh.h1` |
| `frontCall.h3` | admiral | urgent | A ground team is calling for air. Turn around, pilot. | `groundPressureHigh.h4` |
| `frontCall.h4` | mensah | urgent | Granite to air wing. They're back, and there are more of them! | `allyUnderAttack.h7` |
| `frontCall.1.h0` | admiral | urgent | Ground support needed in Krybor! | `groundTide.surge.h4` |
| `frontCall.1.h1` | march | panicked | Bastion to air wing. Krybor's outpost is under attack again! | `allyUnderAttack.h3` |
| `frontCall.2.h0` | admiral | urgent | Ground support needed in Ringfall! | `groundTide.surge.h4` |
| `frontCall.2.h1` | kessler | panicked | Ringfall's line is buckling! Come back! | `groundPressureHigh.h0` |
| `frontCall.3.h0` | admiral | urgent | Ground support needed on Ember Moon! | `groundTide.surge.h4` |
| `frontCall.3.h1` | voss | panicked | The Ember line is overrun! We need you back! | `groundPressureHigh.h1` |
| `frontCall.4.h0` | admiral | urgent | Ground support needed in the Hollow! | `groundTide.surge.h4` |
| `frontCall.4.h1` | mensah | panicked | Granite's surrounded in the Hollow! Help! | `allyUnderAttack.h7` |

**Placeholders.** Until recorded, `tools/comms_pipeline.py dart` resolves each line to its placeholder's clip *and*
that clip's own text and speaker. A player hears and reads the same truthful ground-distress line, for example
"The ground attack is surging. Pilot, support the convoy when you can." in place of "Ground support needed in
Krybor!".
- Every placeholder is a recorded ground-distress line, so the meaning holds before the voices exist.
- The new lines appear in `plan/audio-studio/voice-batch-pending.md`, which is generated (35 pending, 29 with a
  placeholder).
- When tillandsias#1103 unblocks, the batch records them and the placeholders fall away with no code change.

**Category.** The Dart radio pool gets a `RadioCategory.frontCall` that reads the `frontCall*` triggers. It is used
only by the sector-change slot above, never by the seeded category draw, so ordinary interludes are unchanged.

## 5. Validation
- **Unit tests:**
  - the beat envelopes: `speed` is monotonic up to the swap;
  - `pitch`, `roll` and `streaks` are zero in the reduced plan;
  - the ship's on-screen rise is ≤ 24;
  - the HUD and ship transforms are not rolled.
- **Planner tests:**
  - a revisit picks `frontCall.<dest>` or `frontCall`;
  - a first visit picks as today;
  - a boss arrival picks `bossArrival`;
  - a window too short falls back.
- **Review strips** `art/contact/transition-ascent-{full,reduced}.png` (12 frames each, 360 × 780 and 1280 × 720):
  - the horizon drops and the near ground leaves first;
  - the ship stays near its row;
  - streaks are present in full motion and absent in reduced.
- Phone playtest: the operator judges "the ship appears to fly up".

## 6. Decisions taken on the operator's behalf
- **Destination sector, revisits only.** First visits keep their mission briefings: those carry the story, and front
  calls would be odd before the player has seen a sector.
- **Placeholders, not silence.** Each placeholder is a real ground-distress clip with its own subtitle, which is the
  established demon-intelligence §8 rule. A front call with a mismatched subtitle would break the "audio and text
  agree" guarantee, so no line ever shows the new text over an old voice.
- **Speed peak ×8 inside the cloud.** It is slightly lower than today's ×10 instant, but held for longer. Reversible
  by one constant.

## 7. Deviations (recorded during implementation)
- **Roll pivot (§2).** The world banks about the arena's centre (180, 260), not about the ship, with a uniform overscan
  of `1 + 0.09·roll`. A 3° bank about the ship's low row (y ≈ 453–477) uncovers the frame's top corners by ~24 units
  and its bottom corners by ~10, which needs a 14 % overscan and still shows a wedge; about the centre 9 % covers every
  edge. The ship, bullets, HUD and comms dock are still never rolled (the flow ship and the cover are drawn after the
  world). Constants: `DemonScene.rollOverscan`, `FlowPlan.maxRollDegrees`.
- **Sky / ground split (§2).** The flyover is drawn twice while `pitch > 0`: once clipped above the dropped horizon and
  translated only, once clipped below it with the ground transform; the sky clip overlaps the ground by 2 units so the
  seam has no hairline. Ground units, creatures and the rest of the world are drawn once, under the ground transform
  (unclipped, so nothing in the air above the horizon is cut). At `pitch == 0` the single pass is unchanged.
- **Atmosphere (§3, task 3.3).** `atmosphere.dart` needs no change: the fog layers and ground units are anchored to
  the flyover's `distance`, which now advances at the `speed` factor. The Pursuit cloud's billow scroll (`cloudScroll`,
  previously `flow.seconds · 28`) is integrated in the scene at the same factor (`DemonScene.cloudRun`).
- **Reduced motion speed (§3).** The flyover, the fog and the cloud billows are already frozen in reduced motion, and
  they stay frozen: the reduced `speed` factor (`1 + env`, ≤ ×2) is exposed by `FlowPlan.speedFactor` but has nothing
  scrolling to apply to. Reduced motion therefore plays the transition as pure crossfades; the hull nudge is also off.
- **Victory Rout.** In a carrier's fall the flow now owns the flyover speed, so the celebration's own
  `1 + 2.5 p²` ramp gives way to ×1 during the 5.5 s Rout, and the Pursuit's ramp starts after it. The campaign outro
  (no `speed` beat) keeps the old ramp.
- **Streaks (§3).** 12 streaks (the 10–14 range), seeded from the run seed, sector and route rather than a plan seed
  (plans carry no seed); they scroll at `150·factor` units a second.
- **Front-call wiring (§4).** `ArcadeModel.visitedSectors` (reset by `start`, filled by `_beginLevel`) and
  `ArcadeFlow.flowRevisit` (model_flow.dart) decide a revisit: a plain `FlowKind.sectorChange` whose destination
  (`flowDestination`, 1–4) is on a route > 0 or already in the visited set. The carrier's arrival (destination 5) and a
  carrier's fall (`bossVictory`, which also lands on a later route's sector 1) are never revisits, so they keep their
  picks. The transition overlay passes it as `InterludeContext.revisit`. `RadioCategory.drawn` lists the four seeded
  categories; the fallback "any fresh line, then the shortest" walks only those, so a front call can only come from
  the revisit path.
- **Review strips (§5).** `test/transition_ascent_review_test.dart` renders a 2 → 3 sector change on route 1 (a
  revisit), 12 frames evenly across the plan, at 360 × 780 and 1280 × 720. Each sheet crops the letterbox: the top
  two rows are the phone frames' arena, the bottom two the landscape frames' arena (same 360:520 aspect, higher
  source resolution). The sheets are written to `art/contact/` only with
  `--dart-define=TRANSITION_ASCENT_CONTACT=true` (as cinematic-flow's), otherwise to `.cache/transition-ascent-review`.
  The test checks the envelopes the frames were drawn with (pitch, roll and streaks reach 1 in full motion and stay 0
  in reduced, speed ×8 / ×2, rise ≤ 24) and the pitch geometry (`DemonScene.pitchedRow`: horizon drop, near rows move
  further than far rows, the sky only translates); the look is judged on the sheets.
- **Reduced motion spec wording.** The scenario now reads "the world never scrolls faster than twice its speed (a
  still world stays still)" in place of "a gentle speed change", matching the frozen reduced-motion flyover.
