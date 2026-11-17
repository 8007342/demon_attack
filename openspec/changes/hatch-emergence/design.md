# Design: Hatch emergence (hatch-emergence)

## Inputs and sources
- Direction: `plan/operator-feedback-2026-11-17.md`, Round 5 / C6 (quoted in the proposal).
- As built: `openspec/changes/carrier-hatches/` (design §A3–§A6, §A10, §D): the tiers, the volley state machine
  (`GateRun`: telegraph 1.2 s → opening 0.5 s → launching), the transit `0.3 + max(0.25, 1.1·L/300)` s and the
  arrival invariance (a flock leaves its hatch `transit − 0.55` s early).
- Style: `docs/styleguide/alien-capital-ships.md` §3.4 (the head-reading guard) and §3.8 (the tusk-prong lead motif:
  hatches are tusk-framed slots narrowing inward; damage speaks in tusk shards and ivory splinters; no eyes, no rows of
  teeth, no brows). `plan/sprite-atlas.md` (the gargoyle species, their ramps, the 64-px combat cell).
- Cinematic guidelines: `docs/styleguide/endgame-cinematic.md` §7 (one idea per shot, one fast thing owns the eye),
  `plan/endgame-cinematic-research.md` §A2 (rules R-A2.1–R-A2.6), `plan/carrier-v3-research.md` §1.3 (M1–M5) and §4
  (L3 "anticipation (door), placement, then ejection with a short drop or arc", L7 telegraph fairness).

The principles applied here, with their sources:
- **Anticipation.** "Movement in one direction often begins with movement in the opposite direction. Legs contract
  before a jump." It shows that the action is intended and prepares the audience.
  [source: Microsoft, "Animation Principles - Win32 apps", https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-17]
  [source: UCBUGG Open Course Ware, "Basic Animation", https://ucbugg.github.io/learn.ucbugg/basic-animation/, read 2026-11-17]
- **Staging.** "Effective staging involves understanding how to direct the eye to where you want to communicate";
  lighting and viewing angle are part of it. [source: Microsoft, "Animation Principles - Win32 apps", URL above,
  read 2026-11-17]
- **Timing draws the eye.** "In a normal scenario, rapid motion draws the eye, while in a frenetic environment,
  stationary or slow movements may have the same effect." [source: Microsoft, as above, read 2026-11-17]
- **Follow-through, slow in and out, arcs.** Actions "should not come to a complete stop, but smoothly blend into
  other actions"; "living objects in nature rarely move in a perfectly straight line".
  [source: Microsoft, as above, read 2026-11-17] [source: UCBUGG, as above, read 2026-11-17]
- **No twins.** "Avoid twins: mirroring the position the face, arms, and legs on both sides of the body."
  [source: Microsoft, as above, read 2026-11-17]
- **Launch staging.** Door, placement, then ejection with a short arc `[carrier-v3-research L3]` (that source is
  snippet-only there: `[source: ModDB, "Revamped Hangar Bay and Fighters", https://www.moddb.com/news/revamped-hangar-bay-and-fighters, unread: snippet only]`).

Every number below (beat lengths, hop heights, ring widths, budgets) is ours
`[UNSOURCED: plan/provenance-audit.md#HE-1]`.

## 0. What stays
- The large hull asset (the carrier-v3 render and its bake) is untouched. The hatches stay the runtime tusk slots of
  `carrier-hatches` (`CarrierHatchPainter`); they gain layers drawn in code. No new hull art is rendered: the tusk
  slot already carries the lead motif (§3.8), and drawn layers can pulse, vent and thin per frame where a baked layer
  cannot.
- The simulation. The gate state machine, the flock timer, the transit, the arrival moments, the kill windows and
  the calibration are unchanged (§3).

## 1. Hatch candy: each hatch a focal point
| # | Layer | When | Look |
| --- | --- | --- | --- |
| 1.1 | Inner glow | the tusks part (`door > 0`) | a warm amber bloom out of the slot, ×1.6 the slot, alpha 0.18 × door × glow; two flat ovals, no blur |
| 1.2 | Telegraph pulse | the 1.2 s telegraph | an ember ring expanding from 0.5 to 1.4 slot widths, its rate quickening 2 → 5 Hz toward the opening |
| 1.3 | Steam and ichor | each opening; a cracked hatch | two steam jets from each tusk root as the doors part (pale, growing, 0.9 s); a dark ichor drip every 0.7 s from a hatch whose field is down and hull is hurt; cap 32 |
| 1.4 | Its force field | while its field stands | one continuous ring, radius 24 (the hit radius); **thickness** `1.2 + 5.8·s` units with `s` the field's share, alpha `0.35 + 0.55·s`; the circle never narrows or opens gaps; a white ripple (0.28 s, +6 units) on each hit |
| 1.5 | The break | the hatch is destroyed | a white-amber flash (0.13 s), a shock ring to 50 units (0.45 s), 10 ember sparks, over the existing six ivory splinters and the smoke |
| 1.6 | Staging | the hatch chapter | a dark char vignette (×1.6 field radius) under each live hatch lifts it off the hull; sealed, idle tiers sink under a char disc (alpha 0.45) |

- **1.4 and the dive-shield thinning (round 5 S1, change `dive-shield-thinning`, in parallel).** The operator's rule
  is "a wide arc whose THICKNESS wears down while its angular width stays the same", and "the same principle as the
  carrier's thick force field that thins out". The hatch field now follows it: the old coherent gaps (a narrowing,
  segmented read) are gone. It is also cheaper: two circles instead of up to 48 arcs.
- **Head-reading guard (§3.4, §3.8).** Every layer is a ring, an oval, a jet or a spark: nothing paired above a slot
  (no eyes), no rows (no teeth), no arcs over it (no brows). The vents leave from the tusk roots sideways, not as two
  bright points. The lurkers' faces (§2) belong to a creature whose horns and claws show with them, never to the slot.
- **Reduced motion:** no pulse, no vents, no sparks; the glow, the ring and the flash stay.

## 2. The emergence sequence (played once per launched creature)
### 2.1 The beats
| Beat | Pose(s) | Where in the launch | Seconds |
| --- | --- | --- | --- |
| 1. A claw grips the rim | `grip1`, `grip2` | the last 0.5 s of the hatch's telegraph | 0.25 + 0.25 |
| 2. Head and shoulders peek beside the held tusk | `peek1`, `peek2` (the head turns) | the opening, 0–0.34 s | 0.18 + 0.16 |
| 3. It holds the door | `hold` (chest out, a hand braced high on the tusk) | the rest of the opening, held while the hatch holds | ≥ 0.16 |
| 4. Anticipation crouch | `crouch1`, `crouch2` (the squash, wings cocked high) | its entrance, 0–0.16 s | 0.08 + 0.08 |
| 5. The leap | `leap` (stretched, wings folded) | 0.16–0.28 s; the hop arc rises to 9 units | 0.12 |
| 6. Wings open, glide | `unfurl`, `flare`, `glide1`, `glide2` | 0.28 s to the entrance's end; drawn position blends from the hatch into the model's path over 0.24–0.56 s | 0.08 + 0.08 + 0.16 + rest |
| 7. Hand-off | the flight sprites | the entrance ends (`entering` false) | — |

- Beats 1–3 are **lurkers**: the hatch's volley is scheduled before its creatures exist in the simulation, and the
  run's state and clock say exactly when they will leave (`GateRun.state`, `t`). The lurker is drawn at the hatch
  and clipped at its rim (the body is still inside). A creature that exists but whose entrance clock has not started (its delay) keeps
  its held pose. The held state is read from the entrance clock, not `gateWait`: the fight's core-door flock keeps
  `gateWait` set while its entrance runs, because the fight's entrance path does not read it (found by the
  exactly-once test; the hold of carrier-hatches §A5 is therefore not in effect in the fight, a note for that change).
- Beats 4–6 are drawn over the creature's own entrance. Entering creatures are untargetable and do not fire (as
  before), so the drawn position may differ from the model's for its first 0.56 s at no gameplay cost; it has
  converged before the shortest entrance (0.55 s + 0.01) ends. The glide frames are anchored on the body centre, so
  the hand-off to the flight sprite does not jump.
- Principles: the crouch is the anticipation (R-A2.2), the leap and the hop are the arc, the `glide1 → glide2`
  settle is the follow-through (R-A2.5), the lurkers' slow claw and peek are the "still thing in a frenetic frame"
  that draws the eye to the live hatch, and the peeks are asymmetric (R-A2.4, no twins).

### 2.2 Who plays which variant
A flock (1–3 creatures) leaves one hatch. Its members, by entrance delay, play:

| Member | Variant | Beats 1–3 | Beats 4–6 | Side |
| --- | --- | --- | --- | --- |
| 1 (lead) | **peek** | grip (telegraph), peek1, peek2, hold | crouch1 → glide, hop 9 | the outboard tusk |
| 2 | **vault** | grips as the doors part (grip1, grip2), no peek | crouch1 → glide, hop 12 | the inboard tusk |
| 3 | **spring** | one claw on the rim late in the opening | from `crouch2` (a low spring), hop 6 | the centre |

The flip mirrors the sprite for the left tusk, so two hatches of a pair are mirror images, but a flock never is. The
lurkers a hatch shows are `min(tier budget, the next flock's size)`; the model's read-only `hatchFlockPreview`
gives the size (cap minus the creatures out, 0–3). Only the fight's kinds (violet, coral, gold: `min(3, route + 1)`)
have emergence frames; the approach's distant launches (nearness 0.12–0.2, a few pixels) keep their flight sprites.

### 2.3 Exactly once
`HatchEmergence` registers each creature the first time it is seen entering from a hatch, and never again (an
identity set). It steps its frame from the creature's own entrance clock and drops it at the hand-off. A creature
removed mid-sequence (the level ends) is counted as dropped. `test/hatch_emergence_test.dart` checks
`started == launched`, `finished + active + dropped == started`, and that no emergence shows a pose twice.

## 3. Budgets: timing and balance
### 3.1 The timing fits the existing launch
| Window | Length (s) | Uses |
| --- | --- | --- |
| Telegraph | 1.2 (`CarrierVolleyTiming.telegraph`) | the pulse 0–1.2, the grip 0.7–1.2 |
| Opening | 0.5 (held open until the flock leaves) | peek 0–0.34, hold after |
| Entrance | `transit`: 0.55 (core door) … 1.2 (U1 on tour 5) | crouch, leap, unfurl, flare 0–0.44; glide ≥ 0.11 |

Nothing waits on the art: if a beat would outlast its window, the next window's beats start anyway (a lurker is
replaced by the creature when it leaves; the glide is cut by the hand-off).

### 3.2 Arrival moments unchanged
The model is not written by the emergence. The only model changes are `fightMinionCap` (the existing `maxMinions`
expression, extracted) and the read-only `hatchFlockPreview`. The parity test steps two identical fights 30 s, one
with the director, and compares every creature's position, HP and entrance progress, the carrier's shield and the
score. The calibration gates (`boss_endurance`, `boss_fairness`, `campaign_playtest`) therefore do not move, and
`plan/calibration-current.md` needs no new entry.

## 4. Art: the pipeline
- **Rig** (`art/families/hatch-emergence.json`, generated by `tools/rigkit/families/hatch_emergence.lua`): one
  gargoyle skeleton (torso, head, arms, forearms, thighs, shins, wings, tail; 13 slots), three species as sets
  (violet brute, coral hunter, gold elder: `plan/sprite-atlas.md` silhouettes and ramps). The frame's origin is the
  hatch rim's centre, z = 0 the rim plane, so "inside the hatch" is literal. Hero view: pitch 45 (the fight camera).
- **rigkit key poses** (generic, `rigkit.py`): `articulation.keyposes` names poses of per-slot rigid ops (rotate
  about a pivot, move) with a parent chain (`articulation.parents`). The tilt grid of `flight-joystick` is untouched.
- **Hero** (GPU): the rest pose (`flare`: upright, wings spread, every part visible) as clay + hint colours on the
  green key, cropped round the subject, repainted once per species with the committed
  `art/workflows/sprites/carrier-hero-qwen-fast.json` (Qwen-Image-Edit 2511 + Lightning 4-step). Four seeds each.
- **Bake** (CPU): each pick registered to the clay silhouette (`rigsheet fit … bbox`), projected onto the mesh, and
  every pose rendered with the paint moving with its part (`bake.py --poses 1`).
- **Finish and pack** (`rigsheet posepack`, new): every pose finished at texel 1.2 with the combat ramps, a family
  tone grade (`grade`: gain 1.35, lift 0.03, saturation 1.15; the 12:1 area scale otherwise averages the paint's own
  outlines into mud), one shared cell, a row per species, generated `lib/game/hatch_emergence_atlas.dart`.
- **Rebuild without a GPU:** `lua tools/rigkit/bake_poses.lua art/families/hatch-emergence.json --pack --texel 1.2
  --atlas assets/images/hatch-emergence.png --dart lib/game/hatch_emergence_atlas.dart HatchEmergenceAtlas`
  (16 s, byte-identical). Picks, GPU time and rejects: `plan/render-runs/hatch-emergence.md`.

## 5. Phone tiers and budgets
| Tier (`FrameBudget`) | `emergence` | `lurkers` a hatch | `hatchVents` (vents, pulse rings) |
| --- | --- | --- | --- |
| FULL | yes | 3 | yes |
| LEAN | yes | 1 (the lead) | yes |
| LITE | **no**: the flight sprites as before | 0 | no |

| Budget | Limit | Measured |
| --- | --- | --- |
| Atlas | ≤ 64 KB PNG, ≤ 1 MB resident, cells ≤ 80 × 80 | 852 × 210, 31,194 bytes, 715,680 bytes resident, cell 71 × 70 |
| Frames | 12 poses × 3 species = 36 cells | 36 |
| Emergence draws | one `drawImageRect` per lurker or creature; ≤ 16 a frame | 6 at worst (test `HATCH_BUDGET`, tour 5, 20 s) |
| Hatch draws | ≤ 160 calls a frame on tour 5 (8 hatches, fields, vents, bursts, smoke, splinters) | 100 at worst (same test); the old segmented field alone drew up to 48 arcs a hatch |

## 6. Review
`test/hatch_emergence_review_test.dart` (review-tagged, opt-in) writes to `art/contact/`:
- `hatch-emergence-closeups.png`: the hatch through telegraph, opening with lurkers, field thinning, the break;
- `hatch-emergence-strips.png`: the emergence strip per species (every pose, then the drawn sequence over time);
- `hatch-emergence-fight.png` and `hatch-emergence-fight.gif`: an in-fight frame sequence of one launch.

## 7. Decisions and risks
- **Lurkers before the creature exists.** The alternative, adding the beats to the creature's entrance, would launch
  it earlier, count it against the cap earlier and move the calibration. Rejected.
- **Hidden parts.** The pose renders keep the in-hatch body; the runtime clip at the rim hides it (one clip a lurker).
- **Hatch hull art not re-rendered.** The hull bake stays (operator: "keeping the large boss ship asset"); the candy
  is drawn, so it can pulse and thin per frame.
- **Risk:** the in-hatch claws are 3–5 px at the smallest zoom. The `hold` and `peek` frames carry the read; the grips
  are the anticipation for them.
