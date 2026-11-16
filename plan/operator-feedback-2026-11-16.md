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

# Round 3b (same day, after the carrier-v3 runtime, bonus-balance and playtest-fixes-3 merges)

The operator's verdicts:
- "Much improvement."
- "The big boss fight is fantastic."
- Stormfront, the lightning bonus level: "SUPER AWESOME!!"
- "The big ship has great progress."

Requests:

## B2. Clear bonus missions and mission medals (change `mission-medals`)
- **Supply Run was not understood.** "Was that like a magnet? Some powerups were different but they were just
  holding." The instructions were unclear, or went by too fast, if there were any. The goal and the mechanic must read
  at a glance:
  - a readable briefing that stays long enough;
  - an in-level cue for the mechanic (what to do with the crates or pickups);
  - feedback when the player does it right.
- **Final scores use no text for modifiers.** Replace the modifier text with badges: special mission medals with
  little ribbons or accents per mission, shown instead of (or beside) the regular medals. Hero art goes through the
  shared asset pipeline.

## C2. /console boss launcher (folded into `carrier-v3-tune`)
The boss now has intro waves, so /console needs an easy way to launch the carrier fight straight away and to defeat
it quickly: skip the intro and launch waves, and offer a defeat or "fast-forward the decay" control for testing.

**Done** (`work/carrier-v3-tune`): with SECTOR 5 picked, the console's BONUS LEVEL row becomes CARRIER: APPROACH,
FIGHT (in range at once) or FAST DECAY (one decay step every 2.5 s, through to the collapse). It is debug only: ranked
runs ignore it. Sheet: `art/contact/console-carrier-row.png`.

## W1. Dynamic weather (change `dynamic-weather`)
Random levels of dynamic rain on regular levels, from a drizzle to heavy rain. The thunderstorm, with lightning, stays
exclusive to the Stormfront bonus level.

## C3. Carrier rendering engine (change `carrier-render-engine`): research and spec first, then tune
- **The collapse:** the components fall apart as separate random assets, each moving linearly, instead of as one
  cohesive unit. The off-screen sections also "fall off", which shows they were only partial assets. The breakup must
  read as one giant structure failing: cohesive, with continuity off-screen.
- **The bend:** it currently warps a few separate layers individually and looks worse. Research it properly, spec it
  and tune it, e.g. compose the hull to one texture and then warp that. The operator lets us drive the rendering engine
  research and fixes.
- **The force field:** it should thin out (thickness or opacity wearing down) instead of narrowing inward. It took a
  while to understand that the fields were wearing down.

**Spec'd and implemented on today's art** (branch `work/carrier-render-engine`):
- Research, with a source beside every conclusion: [`plan/carrier-render-engine-research.md`](carrier-render-engine-research.md).
- Spec: [`openspec/changes/carrier-render-engine/`](../openspec/changes/carrier-render-engine/) (design §1 has the
  causes; §5 has the interfaces the re-render on `work/carrier-v3-render` is expected to provide).
- Sheets and clips: `art/contact/carrier-render-engine-{bend,collapse,field}.png`, `-collapse.gif`, `-bend-sweep.gif`.

## Round 3c, V1. Voice stack: expressive radio voices on local models (2026-11-16, change `voice-stack`)
Research in [`plan/voice-stack-research.md`](voice-stack-research.md) (recommends VoxCPM2 for speech and Dia 1.6B for
laughs, whoops, cheers and growls, with Chatterbox-Turbo as fallback, all as admitted studio nodes; §9 is the request
list for the coordinator). Spec [`openspec/changes/voice-stack/`](../openspec/changes/voice-stack/): emotion,
intensity, direction and non-verbal cues in `lines.json`, a PG tone check with a pseudo-swear allowlist ("frak",
"blast it", "son of a glitch"), take/pick ledgers, loudness, and the placeholder-to-final swap. No placeholders were
rendered: no TTS engine is installed in the forge or the studio today (design §6).

# Round 3c (same day, after the carrier-render-engine landed): C4 and C5

The operator's verdict: "The current huge boss fight is great, it does feel enormous." The boss fights are the heart of
the run, and with the planned dynamic soundtrack "one whole run of the game should feel like one smooth play of a long
song with a game to match".

Both workstreams are in one change, [`openspec/changes/carrier-hatches/`](../openspec/changes/carrier-hatches/)
([proposal](../openspec/changes/carrier-hatches/proposal.md), [design](../openspec/changes/carrier-hatches/design.md),
[tasks](../openspec/changes/carrier-hatches/tasks.md)). Research, with a source beside every conclusion:
[`plan/carrier-hatches-research.md`](carrier-hatches-research.md). **Spec only (branch `work/carrier-hatches`).** The
implementation follows the merge of `work/carrier-v3-render`.

## C4. Hatch cascade (design Part A)
- **The request:** "the demons fly under it so we cannot see them anymore." The hatches open from the top and the
  demons emerge from them. Hitting the carrier drops the top hatches, so the demons come from lower and lower
  hatches, until they come out of the hatch we can shoot. "This is just the beginning of the boss fight."
- **The spec:**
  - dorsal hatch tiers, 4, 4, 5, 5 and 6 per tour, with the topmost intact tier launching;
  - the upper tiers drop on shield-cell thresholds;
  - then the deck bays (the core's side hatches) and finally the core door, both shootable, launch on their own door
    cycles;
  - creatures are drawn over the hull, and each arrives at the same moment as today;
  - new events: `bossHatchDrop` and `bossHatchTier` (the song's sections).

## C5. Component break-up (design Part B)
- **The request:** "the spikes layer fell off as a whole layer instead of individual spikes … make sure components
  fall off and break apart instead of as whole layers."
- **The spec:**
  - every spike, plate, crystal or door leaf leaves on its own, staggered (at most a quarter of a transition per
    0.25 s), tearing at its root, spinning and fragmenting;
  - the final collapse stays cohesive;
  - the bake has no per-component data yet. The rigkit needs a `comp` id pass, a component manifest (pivots, axes,
    cracks) and stump sockets, and the runtime derives the components from the layer art until it has them.

# Round 3d (same day, after the voice-stack and carrier-hatches specs)

## V1 addendum: licences and a two-layer tone list (change `voice-stack`)
- "We're not using them commercially, our software is free and open source, and so are our games." Re-evaluate the
  non-commercial models against what the repo actually ships under: GPL-3.0 code, plus the asset licences in
  `licences/`. The question is whether a model's licence restricts its *outputs*, and whether NC-restricted audio can
  sit in a GPL repo that others may reuse commercially.
- The curated, family-friendly pseudo-swear list is a feature: the cast trades lines back and forth with it. Theme it
  in two layers. Young players relate to the surface; older players find hidden layers and double entendres that nod
  to older games and pop culture. The nods are original phrasing, never quoted or copied material.

## E1. The end-game cinematic (change `endgame-cinematic`), led by a Fable agent
- A few seconds long, with a few cinematic shots and transitions, its own exclusive dialogue, and Pixar-level
  production as the bar. Research it and plan it first: storyboard, shot list, guidelines, and whether it needs its
  own ComfyUI or Blender pipeline.
- **The reveal:** the kids imagined the whole game while playing a board game in a restaurant.
  - The radio cast appears as bystanders: the Admiral is the mom telling them it's time to go home; the grumpy General
    is the always-smiling restaurant owner; the sassy purple cadet (a prominent character from now on) is the teenage
    waitress who teases the kids and gives them free soda refills.
  - Krybor is the restaurant's name.
  - The gargoyles, ships and tanks are little plastic figures on the board.
- After it, every detail of the game should take on a new meaning on a second run. Collect details from everywhere in
  the game (cast, lines, art, sectors, bosses, sounds) so a player who finished once thinks "I wanna finish it again so
  I can see if…". The radio dialogue plants these details, so players pay attention to it.

## C4 revision: the hatch cascade made fairer (change `carrier-hatches`)
- Every player says the current boss fight is "waaay too difficult" (the operator loves it). Make it easier through
  structure:
  - Each upper hatch has hit points and its own force field. Shooting the upper hatches is the prerequisite.
  - Only after all the upper hatches are exhausted, destroyed and fallen does the ship transform to expose its lower,
    delicate hatch. The camera then zooms in slowly again.
  - This supersedes the lead's earlier "upper hatches not directly shootable".
- Radio hints, one line each: "Destroy the hatches!", "Time the open hatch!", "Fire ahead of its position!". Radio
  subtitles stay on one line so the font can grow a little.
