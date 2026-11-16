# Proposal: Carrier hatch cascade and component break-up (C4, C5)

## Why
From the operator's round 3c on 2026-11-16 (`plan/operator-feedback-2026-11-16.md`, C4 and C5), after the
carrier-v3 runtime and the carrier-render-engine landed on `game`:
- "The current huge boss fight is great, it does feel enormous." But **the demons fly under it**, so the player
  cannot see them. Today the fight's flocks leave the deck bays and the prong gates (hull-local y 21 and 52) and
  settle at y + 70, and the prow is drawn after the creatures (`scene.dart`, the boss block after the creature loop),
  so the prow covers them.
- **C4, the hatch cascade.** The hatches open on the carrier's **top** surface and the creatures emerge from them.
  "As we hit it the top hatches drop, so demons need to come over from lower and lower hatches, until they come out
  from the hatch we can shoot."
- "This is just the beginning of the boss fight." With the planned dynamic soundtrack, "one whole run of the game
  should feel like one smooth play of a long song", and "it's all about the boss fights".
- **C5, component break-up.** The spikes fell off as one whole layer, not as individual spikes. "Whether we keep the
  spike motif or anything else we use, make sure components fall off and break apart instead of as whole layers."
  Today `BossDirector._detach` turns each detached module into one `BossWreck` sprite, and the S2 stage swap removes
  every scale and crystal in one re-compose (`design.md` §B1).

The research, with its sources, is in `plan/carrier-hatches-research.md`.

## What Changes
- **Launch hatches on the top surface, in tiers** (Part A). This supersedes carrier-v3 §4.1–§4.4 and its
  indestructible gates, which the operator approved earlier.
  - Each tour's carrier has 2–4 **upper tiers** of dorsal hatches (one pair per tier), then the **deck tier** (the
    two deck bays, which are already the core's side hatches) and the **maw tier** (the core door).
  - The tiers per tour are 4, 4, 5, 5 and 6.
  - Only the topmost intact tier launches.
  - **Shield damage drops the upper tiers**, one tier per threshold. The thresholds are the shield-cell counts
    6 and 0 on tours 1–2, 9, 6 and 0 on tours 3–4, and 9, 6, 3 and 0 from tour 5.
  - The shield going down hands the launches to the deck tier, which the player can shoot.
  - The last form seals the side hatches (the rule today), so the maw is the last tier.
- **Creatures are always seen.**
  - They pop up out of a hatch and cross over the hull to their places.
  - In the fight they are drawn over every pass of the hull.
  - They cannot be targeted above a transit line, so the kill windows do not move.
  - Each creature's arrival moment (its entrance's end) is the same as today's.
- **Deck and maw launches ride the existing door cycles.** A deck or maw launch leaves through an opening that is
  open in the game. No door is forced open, so the exposure of the core is unchanged.
- **The approach's launch waves** come out of the upper tiers' dorsal hatches, all of them intact, and are drawn in
  front of the hull.
- **Events for the music engine.**
  - The volley lifecycle is renamed from gates to hatches: `bossHatchTelegraph`, `bossHatchOpen`, `bossLaunch` and
    `bossHatchClose`.
  - `bossHatchDrop` is new: one per hatch knocked out.
  - `bossHatchTier` is new: each tier change, with `tier`, `tiers`, `depth` and `shootable`. The tiers are the
    fight's song sections.
  - All of them are structured events only.
- **Component break-up** (Part B).
  - Art removed between two damage states is no longer dropped as a layer. This covers the plates and crystals of
    the S2 shed, the module of a form change, and a dropped hatch's doors.
  - Each removed spike, plate, crystal or leaf is a **component** with its own pivot, axis and size class.
  - Components stay attached until they are released one by one. The releases are staggered, and no more than a
    quarter of a transition's components go in any 0.25 s.
  - Each released component tears at its root, flies on the carrier-render-engine's closed-form body model
    (`v + ω × r`), spins, sinks and fragments.
  - The final collapse stays the cohesive carrier-render-engine collapse. Components still attached at death are
    composed into the wreck.
- **Art pipeline.** The bake has no per-component data today. The rigkit must provide:
  - a per-element `comp` id pass;
  - a component manifest with pivots, axes, size classes and cracks;
  - stump sockets;
  - dorsal hatch modules at the new hatch anchors.
  
  Until it does, the runtime derives the components from the layer art (`design.md` §B6).

## Capabilities

### Modified Capabilities
- `arcade-combat`: the carrier's launch hatches, their tiers and drops, the deck and maw launches, arrival
  invariance, and the hatch events.
- `arcade-presentation`: creatures drawn over the hull, the hatch and cascade presentation, and the component
  break-up.
- `arcade-progression`: the approach's launch waves leave from the dorsal hatches.

All requirements are ADDED. They supersede carrier-v3's "Carrier gate launches" and "Carrier approach and launch
events" (gate names). carrier-v3 is not archived yet, so the supersession is reconciled when it is archived
(tasks 10.2).

## Impact
- **New:**
  - `lib/game/carrier_hatches.dart` (pure Dart), which replaces `carrier_gates.dart`'s geometry and keeps its volley
    state machine;
  - `lib/game/carrier_breakup.dart` (components, schedule, bodies).
- **Changed:**
  - `model.dart`: the tiers, drops, arrival invariance, deck hold and events;
  - `carrier_script.dart`: the hatches replace the gates;
  - `game_events.dart`: the renamed and new names;
  - `boss_director.dart`: the release schedule, with no module `BossWreck` for carriers;
  - `boss_painter.dart`: the transition composites and the component mesh;
  - `carrier_presentation.dart`: the hatch doors, the pop-up, the cascade chase and the drop effects;
  - `scene.dart`: the creatures are drawn over the hull in the fight;
  - `tools/rigkit`, `tools/boss_sheet` and `art/families/alien-carriers.json`.
- **Not before `work/carrier-v3-render` merges into `game`.** That branch has uncommitted edits to `carrier_bend`,
  `carrier_field`, `carrier_presentation`, `carrier_wreck`, `boss_painter` and `scene.dart`. This change is a spec
  only until then (tasks §1).
- **Calibration.** The flock timer, its sizes, kinds and caps, and the door cycles are unchanged, and the arrivals
  are invariant. Boss endurance, the campaign playtest and the boss level's clear time must stay within the gates
  (CLAUDE.md §7).
