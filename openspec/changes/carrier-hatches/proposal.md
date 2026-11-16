# Proposal: Carrier hatch cascade and component break-up (C4 revised, C5)

## Why
From the operator's rounds 3c and 3d on 2026-11-16 (`plan/operator-feedback-2026-11-16.md`: C4, C5 and the C4
revision):
- "The current huge boss fight is great, it does feel enormous." But **the demons fly under it**: the flocks leave
  the deck bays and prong gates and settle under the prow, which is drawn after them.
- **C4, the hatches.** The hatches open from the **top**, and the demons emerge from them, from lower and lower
  hatches as the carrier is hit.
- **C4 revision.** Every player finds the fight "waaay too difficult". Make it fairer through structure:
  - each upper hatch has hit points and its own force field, and destroying them is the prerequisite;
  - when all of them are destroyed and have fallen, the ship transforms to expose its lower, delicate hatch, and the
    camera zooms in slowly again;
  - three one-line radio hints;
  - subtitles stay on one line so the font can grow.

  This supersedes the first version's "upper hatches not directly shootable".
- **The run as one song.** The boss fights are the heart of it, and the dynamic soundtrack will follow their
  sections.
- **C5, components.** The spikes fell off as one whole layer. Every component must break off and apart on its own.

The research, with its sources, is in `plan/carrier-hatches-research.md`. The causes, read from the code, are in
`design.md` §A1 and §B1.

## What Changes
- **Three chapters** (Part A):
  1. **The hatches.** 2–4 tiers of dorsal hatches (one pair each); only the topmost intact tier launches and is
     vulnerable. Each hatch has its own small field, then hull hit points, from the old shield's HP redistributed
     (×0.85 to start). The armour elsewhere sparks and takes no damage, and there is no hull-wide shield.
  2. **The transformation** (3.5 s, when the last hatch has fallen). No hitbox, no fire and the timers held. The plates
     shed as components, a shutter folds aside to expose the core door, and the camera zooms back in slowly
     (0.04/s).
  3. **The core.** The core door is the only target, hit while it is open, with its window widened to 16 × its
     openness. The side hatches are sealed, and the core-chapter flocks leave through the open door.
- **Fairness aids:**
  - the glide is slowed (×0.35 in the hatch chapter, ×0.6 in the core chapter), so the lead needed falls from
    ≈ 67 to ≈ 40 units;
  - a lead pip on Easy and Normal;
  - three radio hints ("Destroy the hatches!", "Time the open hatch!", "Fire ahead of its position!"), as written
    lines (`"pending": "text"`).
- **Creatures are always seen.**
  - They pop up out of a hatch and cross over the hull.
  - They are drawn over every hull pass, and cannot be targeted above a transit line.
  - The flock timer, sizes, kinds and caps are unchanged, and the arrivals are invariant.
- **Calibration: easier on purpose.** The targets are for the protected expert pilot and a new naive pilot that
  does not lead:
  - time-to-kill −25/−20/−10 % on Easy, Normal and Hard;
  - hits taken −30/−25/−15 %;
  - the naive pilot kills every carrier on Easy and 90 % on Normal.

  `test/boss_endurance_test.dart` re-baselines on the result, and keeps the old values as `preHatches`.
- **Events:**
  - the gate names become `bossHatch*`;
  - new: `bossHatchFieldDown`, `bossHatchDrop`, `bossHatchTier` (song sections), `bossTransform` (the bridge), and
    the hint events;
  - `bossCoreExposed` moves to the transformation's end;
  - the shield-cell and field-impact events are retired for the carrier.

  All are structured events only.
- **Radio subtitles.**
  - The font grows from 13 to 14.5 px on the phone and from 13.5 to 15 on the desktop.
  - A 28-character one-line limit applies to flagged lines, the hints at least, enforced by a test over
    `lines.json`.
  - Measured today: median 37 characters, longest 88. 471 of 695 lines exceed the limit and keep wrapping.
- **Component break-up** (Part B).
  - The art removed between damage states leaves as individual spikes, plates, crystals and door or rim pieces.
    This covers the transformation's shed, form-change modules and destroyed hatches.
  - Releases are staggered (≤ ¼ of a transition per 0.25 s), with a root tear, inherited `v + ω × r`, spin, sink and
    fragments.
  - The final collapse stays cohesive.
- **Art pipeline.** The bake has no per-component data. The rigkit must provide:
  - a `comp` id pass;
  - a component manifest;
  - sockets;
  - dorsal hatches at the new anchors, with door and rim pieces.

  Until then, the runtime derives the components from the layer art.

## Capabilities

### Modified Capabilities
- `arcade-combat`: the hatches, fields, transformation, core chapter, arrival invariance, the easier calibration and
  the events.
- `arcade-presentation`: creatures over the hull; hatch fields, destruction and cascade; the transformation and lead
  pip; component break-up.
- `arcade-progression`: the approach's launch waves leave from the dorsal hatches.
- `squad-comms`: the carrier hints; one-line subtitles at a larger size.

All requirements are ADDED. They supersede, for the carrier, three requirements that are not archived yet:
- carrier-v3's "Carrier gate launches", "Carrier approach and launch events" and "Carrier shield intercept
  unchanged";
- the main spec's side-hatch rule in "Carrier shield and door".

They are reconciled at archive (tasks 10.2).

## Impact
- **New:**
  - `lib/game/carrier_hatches.dart` and `lib/game/carrier_breakup.dart`;
  - `test/carrier_hatches_test.dart`, `test/carrier_breakup_test.dart`, `test/boss_fairness_test.dart` and
    `test/comms_line_length_test.dart`.
- **Changed:**
  - `model.dart`, `carrier_script.dart`, `game_events.dart`, `boss_director.dart`, `arena_camera.dart`,
    `boss_painter.dart`, `carrier_field.dart`, `carrier_presentation.dart` and `scene.dart`;
  - `lib/comms/comms_view.dart`;
  - `art/comms/lines.json`, with `lib/comms/comms_bank.dart` regenerated;
  - `test/campaign_playtest_test.dart` (`steer`), `test/boss_endurance_test.dart` and the event tests;
  - `tools/rigkit`, `tools/boss_sheet` and `art/families/alien-carriers.json`.
- **Not before `work/carrier-v3-render` merges into `game`.** The spec is landed first.
- **Balance.** A deliberate easing with targets (design §A11), recorded in `plan/calibration-current.md`.
