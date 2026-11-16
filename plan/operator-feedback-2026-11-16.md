# Operator playtest 2026-11-16 (round 3, after the alien carrier landed in game at 713297fa)

The operator's verdicts:
- "The big ship looks great."
- The zoom-out and scaling work "great"; together with spilling off-screen, "fantastic".
- The sentinel's lurking shadows are "fantastic".

Decisions:
- Bonus levels: balance them instead of adding a scoreboard rule. "When you play you get what you get."
- The end-of-run medal screen does record modifiers.
- Tighten the specs and guidelines (G1 below).
- Provenance is mandatory. Research must save its sources (who, where, URL or citation, date read) next to every
  conclusion, not just the conclusions. Earlier research likely saved conclusions without provenance; audit it.

Workstreams. Each gets its own OpenSpec change; agents implement on `work/*` branches.

## G1. Guidelines and specs hardening (change `guidelines-hardening`)
- Write CLAUDE.md and AGENTS.md: branch flow, merge-not-rebase after push, generated files, test gates, tooling
  language, asset pipelines.
- Refresh the openspec config.
- Archive finished changes.
- Promote durable rules into `openspec/specs`.
- Extract `LevelDef` from `model.dart`.
- Fix the 62 blocker entries the blind bonus-level test logged (`plan/bonus-levels-blockers-a.md` / `-b.md`).
- Run a provenance audit of existing research and design docs: list every conclusion without a source, re-source it
  where possible, and mark the rest `UNSOURCED`.

## B1. Bonus balance and the run record (change `bonus-balance`)
- Bonus levels last about as long as regular levels and are about as hard: sometimes a little easier, sometimes a little
  harder. The operator saw one that lasted about 3 seconds; that's a bug.
- Enemy count and possible score points stay about the same as the regular level they replace.
- The end-of-run medal screen shows the number of medals, the run's modifiers, the play date, the play time and the
  score. The scoreboard records the modifiers.

## F1. Playtest fixes (change `playtest-fixes-3`)
- **Diving shields render broken.** The parts don't scale together, leaving gaps.
- **Sentinel final rush:**
  - Sentinels are invincible during the berserk transformation.
  - They then gain a super-powerful diving shield: defeatable with powerups, but dodging the dive should always be the
    better choice.
  - Final rushes happen a bit more often.
- **Sentinel shadow in play:** when lurking, the shadow is big; once the sentinel comes to the front its shadow
  disappears or shrinks. Keep a consistent, properly scaled shadow during play.
- **Background fills the toast area:** extend the dynamic background and parallax to the top of the viewport, through
  the toast area that the bottom alignment freed. No gameplay goes there.
- **Fly-up transition:** it currently reads as flying sideways. Make it fly straight up.

## J1. Flight-joystick hero art (change `flight-joystick`)
- Design a flight-joystick hero render through the Blender + ComfyUI pipeline, reusing `tools/rigkit`.
- Place it in the control pad below the ship, where "drag to pilot" is. The stick tilts in proportion to the ship's
  direction and speed.
- Looking at it should make it obvious to touch and drag there.

## C1. The Carrier, redesigned (change `carrier-v3`). Research and spec first, re-render last.

**Steps 1–6 are planned, awaiting the operator's review** (branch `work/carrier-v3`). Nothing runs in the game or on
the GPU until that review:
- Research, with a source beside every conclusion: [`plan/carrier-v3-research.md`](carrier-v3-research.md).
- Spec: [`openspec/changes/carrier-v3/`](../openspec/changes/carrier-v3/) ([proposal](../openspec/changes/carrier-v3/proposal.md),
  [design](../openspec/changes/carrier-v3/design.md), [tasks](../openspec/changes/carrier-v3/tasks.md), delta specs).
- Re-render plan: [`plan/render-runs/carrier-v3.md`](render-runs/carrier-v3.md).

Decisions, in brief (each is one constant or flag; see the design §13):
- one stored view, plus a runtime bend (≤ 3° lean, ≤ 2.5° bank, ≤ 2° pitch);
- a hull-conforming field in 12 regions that go dark from the arms inward, on an unchanged gameplay surface;
- 4–12 hull gates per tour, each telegraphing for 1.2 s;
- the intro runs Overflight → Approach (D 4 → 1, two or three launch waves) → Close → Take-off → Climb;
- the minimum zoom runs 0.70, 0.68, 0.66, 0.64 and 0.62 by tour;
- the hull moves heavily while the world rushes past it.
1. **Research, with provenance:** how to make a giant ship read as enormous and ultra fast. Authorities on animation,
   storytelling, games and motion, for example:
   - the animation principles (Thomas & Johnston);
   - film VFX scale tricks (atmospheric perspective, parallax, slow mass, camera shake, motion lines);
   - GDC talks on scale and boss design;
   - shmup capital-ship conventions.

   Store the sources with every conclusion.
2. **Angle variation:** too much for the ship's size. Replace or limit the discrete 38/45/52° views with a runtime
   bend, a mesh/grid warp like the terrain bend, so the ship seems to turn and tilt slightly. Research the tricks
   (mesh deformation of 2D sprites, pseudo-3D skew, Mode-7-like warps).
3. **Force field:** redesign it to the new size and shape: a hull-conforming field, not an arc.
4. **Carrier behaviour:** small creatures launch from compartments and gates on the hull. The boss level's first waves
   come off the carrier before it can be hit.
5. **Intro sequence:**
   - the ship approaches from the distance progressively, until it's close enough to hit;
   - then it takes off and flies higher, and the camera follows;
   - the ground battle falls lower and smaller, and the camera zooms out (keep the current zoom-out);
   - each later carrier zooms out a little more to show off a larger ship.
6. **Update the specs and this plan, then re-render:** for example tours 2–5 damage stages, a hull built for bending,
   gate and compartment modules, and the leftover face/teeth readings.
7. **Soundtrack (future, blocked on tillandsias#1103):** doom and epic-metal undertones over the battle-metal score.
   Decay events already feed the event queue.
