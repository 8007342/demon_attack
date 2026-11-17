# Proposal: Hatch emergence (C6)

## Why
From the operator's round 5 on 2026-11-17 (`plan/operator-feedback-2026-11-17.md`, C6), verbatim:

> "while keeping the large boss ship asset, let's redesign the opening hatches from where demons come out, they should
> also be central and draw attention, since we're shooting at them we'll be looking at them so let's make sure they
> have some nice candy, like the demons having a few extra sprites that play only once as they come out of the hatch,
> of they peeking from the side holding the hatch before they jump off, and taking a little glide from the top hatches
> into fighting distance with our ship, please consult the cinematic guidelines to make this happen, and look at our
> image pipelines with blender and the full enchilada, these are tiny assets so these xtra sprites shouldn't be too bad
> ;)"

Since `carrier-hatches`, the hatches are the fight's targets: the player looks at them the whole first chapter. They
are drawn as small runtime tusk slots, and a launched creature simply appears at the slot in its flight sprite.

## What Changes
- **Hatch candy** (design §1). Each hatch becomes a focal point, without replacing the large hull asset:
  - an inner glow that blooms as the tusks part;
  - a telegraph pulse that quickens toward the opening;
  - steam jets from the tusk roots on each opening, and ichor seeping from a cracked hatch;
  - its own force field as one continuous ring that thins in thickness per hit (the dive-shield-thinning principle,
    S1), with a ripple on each hit;
  - a break: a flash, a shock ring and an ember spray over the existing ivory splinters;
  - staging: a dark vignette under the live tier and sealed tiers sunk in char, so contrast leads the eye.
- **An emergence sequence per launched creature, played once** (design §2): a claw grips the rim, the head and
  shoulders peek out beside the held tusk, it holds the door, crouches, leaps, opens its wings, glides down into
  fighting distance and hands off to its flight sprites. Three variants (peek, vault, spring) per flock.
- **Inside the existing budget** (design §3): the first three beats play inside the hatch's 1.2 s telegraph and
  0.5 s opening, before the creature exists in the simulation; the rest play inside its own entrance (0.55–1.2 s,
  untargetable as before). Presentation only: every arrival moment and calibration number is unchanged.
- **Art through the pipeline** (design §4): a new rig family `art/families/hatch-emergence.json` (12 key poses,
  three species), rigkit key poses, one Qwen-Image-Edit hero per species in the ComfyUI studio, the projection bake
  and a rigsheet pose pack: `assets/images/hatch-emergence.png` (31 KB, 0.72 MB resident).
- **Phone tiers** (design §5): FULL three lurkers a hatch, LEAN one, LITE none and no emergence or vents.

## Capabilities

### Modified Capabilities
- `arcade-presentation`: hatch focal point, the emergence sequence, its variants, tiers and budgets.
- `arcade-combat`: the emergence never changes the simulation (arrival invariance kept).

All requirements are ADDED. They refine carrier-hatches' "Hatch launch presentation" (not archived yet): its 0.3 s
pop-up is now the crouch and leap, and its 0.8 → 1.0 growth is dropped (it was never built, design §D of
carrier-hatches). Reconcile at archive.

## Impact
- **New:** `lib/game/hatch_emergence.dart`, `lib/game/hatch_emergence_painter.dart`, `lib/game/hatch_emergence_atlas.dart`
  (generated), `assets/images/hatch-emergence.png`, `art/families/hatch-emergence.json` and its recipe
  `tools/rigkit/families/hatch_emergence.lua`, the picks under `art/sprites/sources/hatch-emergence/`,
  `tools/rigsheet/posepack.go`, `test/hatch_emergence_test.dart`, `test/hatch_emergence_review_test.dart`,
  `plan/render-runs/hatch-emergence.md`.
- **Changed (small hooks):** `carrier_hatch_painter.dart`, `scene.dart`, `model.dart` (a read-only flock preview),
  `perf/frame_budget.dart`; `tools/rigkit/rigkit.py` (key poses), `tools/rigkit/bake_poses.lua` (`--pack`),
  `tools/rigsheet` (grade, posepack).
- **Balance:** none. The model's only change is a read-only getter and an extracted constant (design §3.3).
