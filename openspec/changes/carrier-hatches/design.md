# Design: Carrier hatch cascade and component break-up (carrier-hatches)

## Inputs and citations
- **Operator input:**
  - round 3c, C4 and C5;
  - round 3d, the **C4 revision** in `plan/operator-feedback-2026-11-16.md`.

  Every player finds the fight "waaay too difficult". It must become fairer through structure:
  - each upper hatch has hit points and its own force field, and destroying them is the prerequisite;
  - when all of them are destroyed and have fallen, the ship transforms to expose its lower, delicate hatch, and the
    camera zooms in slowly again;
  - three radio hints;
  - subtitles on one line, so the font can grow.

  The revision supersedes this design's first version: "upper hatches not directly shootable", and the shield-cell
  thresholds.
- **Code read on `origin/game` (445f2888, 3cfe1c32):**
  - `lib/game/carrier_gates.dart`, `carrier_script.dart`, `boss_director.dart` and `boss_grammar.dart`;
  - `model.dart`: `Carrier`, `hitBoss`, `_updateApproach`, `_gateLaunch`, the fight flocks in `_updateBoss`, and
    `_bossDecayEvents`;
  - `scene.dart`: the boss block after the creature loop;
  - `lib/comms/comms_view.dart`: `CommsSubtitle`, the phone dock strip and the desktop tiles;
  - `art/comms/lines.json`;
  - `test/boss_endurance_test.dart` and `test/campaign_playtest_test.dart` (`steer`);
  - `tools/rigkit/rig.py` and `rigkit.py`, and `art/families/alien-carriers.json`.
- **The carrier specs this change builds on:**
  - `openspec/changes/carrier-v3/design.md` §4 (gates) and §10 (events);
  - `openspec/changes/carrier-render-engine/design.md` §3 (collapse), §4 (field wear) and §5 (re-render interfaces);
  - `plan/render-runs/carrier-v3.md` on `origin/work/carrier-v3-render` (K0).
- **Research:** `plan/carrier-hatches-research.md`. Source IDs (`[H1]`, `[B2]` …) are its rows, in the CLAUDE.md §8
  form. Our own choices are marked `[UNSOURCED: plan/provenance-audit.md#CH-n]`.

## 0. What stays, and what is deliberately changed
- **Stays:**
  - the intro (approach, close, take-off, climb);
  - the bend;
  - the cohesive collapse;
  - the flock timer, sizes, kinds and caps;
  - the volley timing (telegraph 1.2 s, open 0.5 s, 0.12 s apart, close 0.8 s, at most two open);
  - the core's armour steps and form changes, and their module detaches (now broken up, Part B).
- **Changed on purpose (the C4 revision): the boss gets easier.**
  - The carrier's hull-wide shield, and its 12-cell intercept, are replaced by the hatches' own small fields.
  - The side hatches no longer take core hits.
  - The glide slows while the hatches are the targets.
  - The core door's hit window widens.

  This is a balance change with its own targets (§A11), not a change to keep within the old gates.

---

# Part A. The hatch cascade (C4, revised)

## A1. What the operator saw, and why
| Saw | Cause in the code |
| --- | --- |
| "The demons fly under it, so we cannot see them anymore." | The fight's flocks leave `bayL/bayR` (hull-local y 21) or the prong gates (y 52), and settle at `b.y + 70`. The prow spans hull-local y −78 … +66 (`prow.thorn`), and `scene.dart` draws the prow (`paintHero(front: true)`), the deck and the gates **after** the creature loop, so the prow covers them `[H5]`. |
| "Waaay too difficult" (every player). | The goal is unclear: one hull-wide shield, with no target to aim at. The core is hit only through doors that cycle on a hull moving at up to ≈ 106 units/s (`forecastX`: amplitude 80 + 10·rage, phase rate 0.7 × up to 1.9). A shot climbs to the door's row in ≈ 0.63 s (390 units/s), so the player must lead the door by up to ≈ 67 units, against a 12-unit half-window. The protected campaign pilot leads exactly (`steer` uses `forecastX`), so the calibration never saw this difficulty. |

## A2. The structure: hatches first, then the transformation, then the core
"Fairer through structure" `[A3]` `[P3]` means the fight becomes three readable chapters, each with one goal and a
radio hint:

| Chapter | Goal | Targets | Launches | Ends when |
| --- | --- | --- | --- | --- |
| **1. Hatches** | "Destroy the hatches!" | the hatches of the topmost intact tier: first their small fields, then their hulls | from the topmost intact tier | every upper hatch is destroyed **and has fallen** (its break-up done, §B4) |
| **2. Transformation** (3.5 s) | — (a breather) | none: no hitbox, no fire, the flock timer paused | none | the core door is exposed |
| **3. Core** | "Time the open hatch!", "Fire ahead of its position!" | the core door, the lower delicate hatch, only while open | from the core door, as it opens | the core dies: the cohesive collapse |

The Star Fox 64 mothership is the read precedent:
- each launch hatch has its own hit points;
- destroying every hatch summons the core;
- each hatch's destruction is a local event `[H1]` `[H2]`.

Losing parts shows progress better than a health bar `[P3]`. The numbers are ours
`[UNSOURCED: plan/provenance-audit.md#CH-1]`.

## A3. Upper hatches: tiers, fields and hit points
**Tiers per tour.** The tier counts of the first version stay: 2, 2, 3, 3 and 4 upper tiers (one pair each), so
4, 4, 6, 6 and 8 upper hatches. Tours beyond 5 use tour 5's. They are moved **lower** than in the first version, so
shots reach them sooner:

| Tour | U1 | U2 | U3 | U4 |
| --- | --- | --- | --- | --- |
| 1, 2 | y −150, x ±72, `hatch.slab` | y −70, x ±92, `hatch.petal` | — | — |
| 3, 4 | −165, ±70, slab | −110, ±96, petal | −55, ±80, `maw.iris` | — |
| 5 and later | −170, ±68, slab | −125, ±96, petal | −80, ±84, iris | −35, ±62, `sac.cluster` |

- **Coordinates.** Hull-local arena units, with y down-screen. The normals are (±0.2, −0.98).
- **Distances.**
  - U1 at −170 sits at screen y ≥ 19 over the glide (b.y ∈ [189, 221]), inside the arena at every fight zoom.
  - A shot reaches it in ≤ 1.17 s.
  - The prong pods, flank maws, sacs and aft gates are not launchers (§A9).

**Only the topmost intact tier is vulnerable**, and it is the tier that launches.
- The other tiers are sealed: shots pass over them (they intercept nothing), and their rims are dark.
- When both hatches of the tier are destroyed, the tier drops. The next tier arms with its field rising over 0.6 s,
  and launches.
- So the creatures come from lower and lower hatches, as in the operator's first request.

**A hatch's field.**
- It is a small hex membrane: radius 18 units around the hatch, with the carrier-render-engine wear look (width and
  opacity by the field's HP, its §4).
- A shot whose path crosses the hatch's row within 18 units of its centre is stopped at the membrane and removes
  1 HP of field (`damage` scales as today).
- At 0 the membrane breaks in place, with shards and `bossHatchFieldDown`.

**A hatch's hull.**
- Once its field is down, a shot within 12 units of its centre hits the hatch (1 HP).
- At 0 the hatch is destroyed (`bossHatchDrop`, cause `shot`). Its doors and rim break off as Part B components
  (§B4), so it has **fallen** when its last component is released, at most 1.2 s later.

**Hit points.** The old shield's HP is redistributed. For a tour, the upper-hatch pool is
`H = round(k·shieldMax)`, split equally over its hatches: 60 % field and 40 % hull, each at least 3.
- The pool factor `k` starts at **0.85** (fewer total hits than the old shield) and is set by calibration (§A11).
- The hull outside a vulnerable hatch's field is armour: a shot there sparks off (the playtest-fixes-3 deflect
  sparks), does no damage, and counts toward the hint of §A7.

**The meter.** The insignia row shows one cell per upper hatch, lit while intact. Its field state is a half-lit cell.

## A4. The transformation (3.5 s) and the camera
When the last upper hatch has fallen:

| t (s) | What happens |
| --- | --- |
| 0 | `bossShieldDown`, `bossTransform` `{stage: start}`. The carrier's hitbox and fire are off, and the flock timer holds (creatures already out keep fighting). The S2 shed (plates and crystals) releases as a Part B transition in a staggered burst over 2.5 s. The armour shutter over the core door begins to part. |
| 0–3.5 | The deck's shutter leaves fold aside (runtime-drawn until the re-render's door layers). The core door's rim lights ember, then amber. |
| 0–(≈4–6) | **The camera zooms in slowly**: from the tour's minimum zoom back toward 0.86, at 0.04/s, so 4 s from 0.70 and 6 s from 0.62. The core door is a small target, so the closer framing makes it readable. The bend's limits halve for the core chapter: a quieter hull. |
| 3.5 | `bossTransform` `{stage: end}`, then `bossCoreExposed` (moved here from the last form). The core chapter starts: the hitbox is on, and the timers resume. |

- **A breather after a goal.** Pacing alternates tension and relief, and a break after a milestone lets the player
  reset. No read source states this; it, the 3.5 s and the zoom rate are ours `[UNSOURCED: plan/provenance-audit.md#CH-2]`.
- **Shake.** None: carrier-v3's four trauma beats stay `[J3]`. The "core exposed" beat (trauma 0.25) moves to
  `bossCoreExposed`.
- **Reduced motion.** The shutter opens as a 1 s fade, and the zoom eases at the same rate.

## A5. The core chapter: the lower, delicate hatch
**The target.**
- The core door at hull-local (0, 25) is the only target.
- The deck bays (side hatches) are sealed for good at the transformation. The main spec's side-hatch rule is
  superseded for the carrier; reconcile it at archive (tasks §10).

**Fairness by structure** (each one constant):
- **The door cycle is unchanged**, `door = clamp(2·(sin(c·(1.55 + 0.22·phase)) − k), 0, 1)`. It is hit at
  door ≥ 0.6, with the hit half-width widened from `12·door` to **`16·door`**, because it is now the only opening.
- **A slower glide.** The lateral motion's phase rate is scaled by **0.6** in the core chapter (and **0.35** in the
  hatch chapter), and the amplitude stays at 80.
  - The core door's maximum speed falls from ≈ 106 to ≈ 64 units/s.
  - The lead needed at its row falls from ≈ 67 to ≈ 40 units.
  - In the hatch chapter, U1's lead is ≤ 44 units for a ≤ 1.17 s flight, at most 2.4 field radii.
- **The lead pip** (Easy and Normal only, after the first `bossHintLead`). A faint ember tick on the door's row,
  where a shot fired now would meet the door's centre. It is drawn under the gameplay layer and is never on Hard.
  Telegraphing where to aim is the readability rule `[A3]`. The pip is ours
  `[UNSOURCED: plan/provenance-audit.md#CH-3]`.

**Forms** still change by core damage. Each change tears a module away (Part B), quickens the flock timer as today,
and emits `bossModuleLost`. The last form no longer emits `bossCoreExposed` (§A4).

**Launches.**
- A core-chapter flock leaves through the core door when it is open (`door ≥ 0.6`).
- When it is closed, the volley parks unseen and untargetable in the door until it opens, at most one period
  (≈ 3.5 s).
- No door is forced open.

So the threat and the opportunity are the same opening `[H1]`.

## A6. Transit, arrival and draw order
**The path.**
- **Pop-up, 0.3 s:** the creature rises 10 units out of the hatch and grows from 0.8 to 1.0, lit by the hatch's
  glow. Every attack advertises itself `[A3]`.
- **The swoop:** a cubic curve to its home slot, bowed 40 units outward, at 300 units/s. It never aims at the ship's
  row: the homes are at y ≤ b.y + 110 < 330, and the ship's row is 477 `[A3]`.
- **The transit time:** `transit = 0.3 + max(0.25, 1.1·L/300)` s, rounded to 0.05.

**Arrival invariance.**
- The flock's cap and size are decided, and the creatures are added at the hatch, when the timer reaches
  `transit − 0.55` instead of 0.
- The timer reloads with `+= period`.
- Each entrance ends when it does today, except when a core-door hold delays it.

The fight's pressure therefore keeps its rhythm, and the balance change comes from the structure, not from the
flocks.

**Not targetable above the transit line** (hull-local y + 40). Shots cross the creature, so its kill window matches
today's while it stays visible the whole way `[A2]`.

**The approach.** Its launch waves keep their rosters, counts, D steps and cap (carrier-v3 §4.3–§5.3). They come out of
all the upper hatches (none is destroyed yet), round-robin across sides and tiers, projected through D. The core door
is not used.

**Draw order (the fix for A1).** In the fight, `scene.dart` draws the hull's back pass, the prow, the deck, the
hatches, the hatch fields, and only then the creatures, their tells, deaths and muzzle flashes. During the approach,
a launched creature's nearness is at least the carrier's slot nearness + 0.02.

## A7. Radio hints (one line each, `"pending": "text"`)
These are model events (structured `GameEvent`s, deterministic) that trigger the hint lines. Each fires at most once
per its cooldown, and never during the transformation.

| Event / trigger | Line (speaker, emotion) | When | Cooldown |
| --- | --- | --- | --- |
| `bossHintHatches` | "Destroy the hatches!" (admiral, urgent) | 2.0 s after `bossTakeoff`; again when ≥ 6 of the player's shots in 4 s spark off the armour or pass a sealed tier | 20 s |
| `bossHintTiming` | "Time the open hatch!" (kestrel, urgent) | at `bossCoreExposed`; again when ≥ 4 shots in 3 s hit the closed core door | 20 s |
| `bossHintLead` | "Fire ahead of its position!" (wisp, urgent) | ≥ 3 shots in 4 s pass the open door's row within 40 units on its trailing side (aimed where it was) | 25 s |

- **`art/comms/lines.json`.** Three new triggers, appended, each with one human line. Each carries `priority` 7,
  `ttl` 3, the cooldown above, `mood` `stern` and `"pending": "text"`.
  - No TTS exists yet, so each shows its own words with the mouth closed and borrows no clip.
  - Then run `python3 -I tools/comms_pipeline.py dart` (CLAUDE.md §4).
  - The borrowed-line count in `test/comms_director_test.dart` does **not** change: written-only lines borrow
    nothing. The test's comment gains the note.
- **Names.** These are distinct trigger names rather than variants. The carrier's event data already carries a
  numeric `variant` (the set combination), which `GameEvent.variant` would read as a trigger suffix.

## A8. Events for the music engine
These are all structured, queued by `_queueGameEvent`. None is a raw string in `model.events` (CLAUDE.md §3). Each
carries `route`, `tour`, `set`, `variant` and `sector`.

| Event | When | Data | For the score (suggested) |
| --- | --- | --- | --- |
| `bossHatchTelegraph`, `bossHatchOpen`, `bossLaunch`, `bossHatchClose` | the volley lifecycle (renamed from carrier-v3's `bossGate*`, which are retired) | `hatch`, `tier`, `side`, `kind`, `shootable`; `count` on `bossLaunch` | riser, hit, burst |
| `bossHatchFieldDown` (new) | a hatch's field breaks | `hatch`, `tier`, `side` | a glass-break accent |
| `bossHatchDrop` (new) | a hatch is destroyed | `hatch`, `tier`, `side`, `cause` (`shot`), `left` (upper hatches remaining) | an impact, then a falling figure |
| `bossHatchTier` (new) | the vulnerable tier changes; tier 1 right after `bossInRange`; the core chapter as the last tier | `tier` (1-based), `tiers` (upper tiers + 1), `depth` = (tier − 1)/(tiers − 1), `shootable`, `from` | **a section change** |
| `bossShieldFailing` (kept) | half the upper hatches are destroyed | — | as today |
| `bossShieldDown` (kept) | the transformation starts | — | as today |
| `bossTransform` (new) | `{stage: start}`, `{stage: end}` | `stage`, `seconds` | the bridge between sections |
| `bossCoreExposed` (moved) | the transformation ends | — | the drop into the last section |
| `bossHintHatches`, `bossHintTiming`, `bossHintLead` (new) | §A7 | `hint` | — (radio only) |

- **Retired for the carrier:** `bossShieldCellLost` and `bossFieldImpact`. The cells and the hull-wide field are gone,
  and per-hatch fields report through `bossHatchFieldDown`.
- **Order of one destroying hit:** `bossHatchDrop` → (`bossShieldFailing`) → `bossHatchTier`.
- **The tiers are the fight's song sections.** Adaptive scores change sections on the game's cues at their own next
  bar `[M1]` `[M3]`, and `depth` is a layering intensity `[M2]`. The transformation is the bridge. The game never
  waits for the music.

## A9. What changes in the existing code (after the render merge)
- **`carrier_gates.dart` → `carrier_hatches.dart`:**
  - geometry (§A3);
  - per-hatch field and hull HP;
  - the vulnerable tier;
  - `GateRun`, `CarrierLaunches` and `CarrierVolleyTiming` moved across;
  - a deprecated re-export until carrier-v3 is archived.
- **`CarrierScript`:** `hatches`, `hatchOrder`, `hatchPool` (`k`), `hatchGlide` (0.35), `coreGlide` (0.6),
  `coreWindow` (16), `transformSeconds` (3.5) and `zoomInRate` (0.04).
- **`model.dart`:**
  - the `Carrier` gains the hatch state and a chapter (hatches, transform, core);
  - `hitBoss` routes a shot to the vulnerable tier's fields and hulls, then the armour, and to the core door only in
    the core chapter;
  - the flocks follow §A5–§A6;
  - the hints follow §A7;
  - the events follow §A8.

  `Carrier.shield`/`shieldMax` remain as the sum of the hatch fields, so the HUD and the existing decay hooks keep
  working.
- **`campaign_playtest_test.dart` `steer`:** aims at the vulnerable hatch nearest its column, with the forecast lead,
  then at the core door when it is open (§A11).
- **`BossDirector`, `ArenaCamera`:** the transformation's zoom-in and the halved bend.
- **`carrier_field.dart`:** the hull-wide membrane is no longer drawn for the carrier. Its wear and dropout functions
  draw each hatch's field. `test/carrier_field_equivalence_test.dart` is retired for the carrier, as a deliberate
  balance change recorded in `plan/calibration-current.md`.
- **The render's gate map and door layers** are re-keyed to hatch ids (§B9.4).

## A10. Presentation
- **Hatches.** The door layers from the re-render, when present; otherwise carrier-v3's runtime leaves. The
  vulnerable tier's rims glow amber. Sealed tiers are dark.
- **Fields.** Each vulnerable hatch's field is a small membrane with the carrier-render-engine wear (width, alpha and
  dropout by its HP). A hit ripples it.
- **Hull hits** on the armour spark (the deflect sparks), so a miss reads as a miss.
- **The way out.** A creature passing a hatch's field makes a faint ripple, with no event.
- **The drop (≤ 1.2 s).**
  - The hatch's lights flicker and die.
  - Its doors and rim break off as Part B components, with an ember burst.
  - The opening seals in char and smokes in world space (2 puffs per second for 6 s, sharing the 90-puff cap).
- **The cascade.** The next tier arms over 0.6 s with a light chase down the hull `[A1]` `[A2]`.
- **The transformation:** §A4.
- **The core door:** an amber rim while open, and the lead pip of §A5.
- **Reduced motion:**
  - no pop-up growth and no chase;
  - fields break without shards;
  - the leaves fall without spin;
  - the shutter fades open.

## A11. Calibration: easier on purpose (CLAUDE.md §7)
**Two pilots, both protected (invulnerable), 16 seeds per difficulty**, as `test/boss_endurance_test.dart` measures
today:
- **The expert:** the real-shot campaign pilot, which leads with the forecast. Its metrics are the carrier's
  **time-to-kill** (combat seconds from fight-ready to the fall, summed over the five carriers) and the **hits taken**
  while it is fight-ready. Each hit taken is a life an unprotected pilot without a shield would lose, so it stands in
  for **life loss**.
- **The naive pilot** (new, `test/boss_fairness_test.dart`): the same steering, but it aims at the target's
  **current** x with no lead, as a new player does. It has a cap of 240 s per carrier. Its metrics are the same, plus
  the share of carriers it kills before the cap.

**Before values.**
- The expert's are the latest recorded (`plan/calibration-current.md`, "Carrier v3 tune"):

  | Difficulty | Seconds | Hits |
  | --- | --- | --- |
  | Easy | 352.64 | — |
  | Normal | 417.29 | — |
  | Hard | 436.03 | — |

  The hits are re-measured on the merge base before any change, together with the naive pilot (task 5.1).

**Targets** (each within ± 5 points) `[UNSOURCED: plan/provenance-audit.md#CH-4]`:

| Difficulty | Expert time-to-kill | Expert hits taken | Naive pilot |
| --- | --- | --- | --- |
| Easy | −25 % | −30 % | kills every carrier before the cap; time ≤ 1.5 × the expert's |
| Normal | −20 % | −25 % | kills ≥ 90 % of carriers; time ≤ 1.75 × the expert's |
| Hard | −10 % | −15 % | measured, no target (Hard stays hard) |

**The levers, in order:**
1. the hatch pool `k`;
2. the core window (16);
3. the glide factors (0.35 and 0.6);
4. `coreMax` per difficulty (`DifficultyPolicy.bossCoreForRoute`);
5. the fan-attack rate in the hatch chapter.

The flock timer is the last resort.

**How `test/boss_endurance_test.dart`'s baseline moves.**
- When the targets are met, `baseline` is replaced by the new expert means.
- The old map is kept as `preHatches`, with the commit it came from.
- A new test asserts that each difficulty's ratio to `preHatches` lies inside its target band. That guards the
  easier boss against regressions.
- The existing ±5 % pooled and ±10 % per-difficulty gates then apply to the new baseline for every later change.

**Also kept:**
- the campaign playtest's bounds (`test/campaign_playtest_test.dart`), with the pilot updated per §A9;
- the boss level's clear time, recorded but no longer gated at +10 %, because it is meant to fall.

**Recorded in `plan/calibration-current.md`:** "Carrier hatches", with the before and after per difficulty, both
pilots, and the commit.

## A12. Radio subtitles on one line, a little larger
**Measured** (`art/comms/lines.json`, 695 lines of text and gloss, on 2026-11-16):

| Statistic | Value |
| --- | --- |
| Median length | 37 characters |
| 90th percentile | 57 characters |
| 99th percentile | 76 characters |
| Longest | 88 (`transmissionMission`), then 81 (`flawlessRun`), then 80 (`flawlessVictory`) |
| Lines of ≤ 28 characters | 224 |
| Lines of ≤ 36 characters | 345 |
| Boss triggers' longest | 57 |

**Today:**
- The phone dock's strip draws the speaker's tag (9.5 px bold) and the text at 13 px, up to 4 lines.
- The desktop tiles draw 13.5 × scale (≤ 1.2), up to 3 lines.
- The app font is `monospace`, about 0.6 em per glyph `[UNSOURCED: plan/provenance-audit.md#CH-9]` (the widget test of §A12 measures it), so a 13 px line is about 7.8 px per character.

On a 360-px phone, a single call's text column is about 360 − 16 (margins) − 40 (portrait) − 8 (gap) − 51 (tag) ≈
245 px. So, at 13 px:
- the longest line (88) needs about 690 px, three lines;
- the median needs about 290 px, two lines.

**The decision:**
- **The font** grows to **14.5 px** in the phone strip (+11.5 %) and to 15 × scale on the desktop. The tag grows to
  10.5 px.
- **One-line lines.** A line flagged by the limit below is drawn with `maxLines: 1`, at full dock width, even when
  another call is on screen.
- **The limit** is ≤ 28 characters of text at 14.5 px. 28 × 8.7 ≈ 244 px fits the 245-px column.
- **The test** (`test/comms_line_length_test.dart`, pure Dart over `lines.json`) enforces the limit on:
  - the in-fight hint triggers (`bossHintHatches`, `bossHintTiming`, `bossHintLead`), at minimum;
  - every trigger listed in its `oneLine` set.

  A widget test lays the three hints out in the phone strip at 360 px with the app's fonts loaded, and asserts
  `didExceedMaxLines` false.

**The rest of the bank.** 471 lines exceed 28 characters, so "every subtitle on one line" would mean rewriting two
thirds of the radio. Those lines keep wrapping (2–4 lines) at the new size. Rewriting them is left to a follow-up for
the cast's writers (open question, §C). The new hints are 20, 20 and 27 characters.

---

# Part B. Component break-up (C5)

## B1. What the operator saw, and why
| Saw | Cause in the code |
| --- | --- |
| "The spikes layer fell off as a whole layer." | A form change calls `BossDirector._detach`, which adds **one** `BossWreck` per module instance of that detach rank. For the spines (`detach: 1`, the first form change), that is one sprite holding 7 great spines and 2 × 8 row spines (`alien-carriers.json`, `spines.ridge`: two `array` prims). At the same time the composite is re-composed without the module, so the whole layer vanishes in one frame and falls as one piece. |
| (The same, less visible) | The S2 stage art sheds every `plate` and `shard` tag (`stages.S2.shed`). At shield down, one re-compose swaps the S0/S1 art for S2 and every scale and crystal is gone at once. The director's `plate` wrecks are generic sprites at random spots (±60 units), unrelated to the art. |
| (On the render branch) | `9ff7bb9f`, "wreck frames for fight detaches only": per-module wreck sprites, the same whole-layer model. |

## B2. The decision
**Every piece of art removed between two damage states leaves as components, released one by one.** This covers:
- the S2 shed;
- a detach group at a form change;
- a destroyed hatch's doors and rim (§A3, §A10).

Each component:
- stays attached, riding the bend, until its release;
- then tears at its root and flies on its own body.

Staggered release, with follow-through and overlapping action, reads as one structure failing piece by piece, not as
a cut-out `[J1]` `[P4]` `[B1]`; overlapping action (`[J6]`, snippet only) is context.

The physics is the carrier-render-engine's closed form (its §3.4): the same `v + ω × r` inheritance `[B2]`, the same
pre-computed fracture `[B1]`, and world-space smoke `[B5]`. So the break-up in the fight and the cohesive final
collapse are one engine at two scales:
- in the fight, components leave a hull that holds;
- at death, the hull itself breaks into sections and chunks.

## B3. Transitions, composites and draw order
- **A transition** is a pair: the *before* state B and the *after* state A of one pass. For example, (S1, S2) for the
  shed, or (detached set, detached set + rank r) for a form change. Its **removed texels** are each layer's alpha in
  B minus its alpha in A, multiplied by (1 − the alpha of every later layer). So a component is only ever the texels
  that were visible.
- **The draw.**
  - The pass draws A's composite (the carrier-render-engine warp mesh).
  - It then draws every component of the transition in **one** `drawVertices` over B's composite texture: the
    attached ones displaced by the hull's bend through the same height field (`bent()`), the released ones by their
    bodies.
  - Before any release, the frame equals B (the "seamless start" scenario).
- **Occlusion.**
  - When a later layer overlaps the removed texels (a crown shard over a spine), the pass is split for the
    transition's duration: A's composite under the module's place, the components, then A's layers above it as a
    second composite. That is one extra `drawVertices`.
  - Otherwise, one composite plus the components.
- **Memory.** B stays resident until the last component of the transition is released: +4–7 MB, transient, inside
  the 16 MB budget's headroom `[UNSOURCED: plan/provenance-audit.md#CH-5]`.
- **Overlap.** One transition runs per pass at a time. If a new one starts first, the old one's attached components
  release in a staggered 0.6 s burst under the same rate rule, and its B is then released.
- **Composes per fight:** carrier-render-engine's ≤ 7, plus ≤ 2 per transition (A, and the split's upper pass).
  That is at most 15, never in steady flight.

## B4. The release schedule (presentation; `BossDirector`, PRNG stream `seed ^ 0xC5B7`)
**The rate rule.** In any 0.25 s, at most `max(2, ⌈25 %⌉)` of a transition's components are released. The gap
between releases is 0.05–0.2 s. No transition releases in under 1.2 s.

**The order.** Outer first: by distance from the hull's centre line, then from the tip. The side of the most recent
hit goes first.

| Transition | Starts | Releases |
| --- | --- | --- |
| **Shed** (plates, crystals) | `bossShieldFailing` (half the upper hatches destroyed): B = S1, A = S2 | Each component is given a share of the upper hatches in (0.5, 1], outer first, nearest a destroyed hatch first. It releases as that share of hatches is destroyed, so about 60 % have gone before the last hatch falls. The rest go in the transformation's staggered burst over 2.5 s (§A4). |
| **Detach** (the module of form r) | `bossArmourShed` for that module (the odd armour step before the form change): B = the current set, A = the set + rank r | 35 % at the armour shed, over ≥ 1.2 s, tips first: the module is cracking. The rest at the form change (`bossModuleLost`), over ≥ 1.6 s. Root stubs stay as sockets (§B9.3). |
| **Hatch destroyed** | `bossHatchDrop` | The hatch's door leaves and rim plates (3–6 components) over 1.2 s, outer first. The hatch has **fallen** when the last one is released, which is the gate of the transformation (§A2). |

**One structure, piece by piece.** The rule is the operator's "make sure components fall off and break apart instead
of as whole layers". The structure follows the progressive-destruction references `[P3]` `[P4]`. The numbers are ours
`[UNSOURCED: plan/provenance-audit.md#CH-6]`.

## B5. Component physics (closed form, deterministic)
A component has:
- a pivot `c` (hull-local, with a height);
- an axis `a` (unit, from the root to the tip);
- a size class: **s** ≤ 20 units, **m** ≤ 60, **l** > 60;
- a release time `t_r`.

**Attached** (before `t_r`): its pose is the hull's, bent exactly like its texels.

**The root tear** (m and l only): for 0.15–0.35 s after `t_r`, it rotates about its pivot by 8–20°, away from the
hull's centre line. It hinges before it breaks, which is a separate rotation effect as in `[J1]`. s components skip it.

**Free flight** (from the end of the tear, `u` = seconds since): carrier-render-engine §3.4's model. The constants below are ours `[UNSOURCED: plan/provenance-audit.md#CH-8]`.
- `V₀ = V_hull + ω_hull × (X₀ − X_hull) + k·a + j`, the point velocity `[B2]`. Here:
  - `V_hull` is the carrier's horizontal velocity and glide rate;
  - `k` is the kick: 22–30 units/s (s), 16–24 (m), 10–16 (l);
  - `j` is a lateral jitter of ±4 units/s.
- `X(u) = X₀ + V₀u + ½g u² ŷ`, with gravity `g` of 60 (s), 45 (m) or 30 (l) units/s² down-screen.
- `A(u) = A₀ + ω₀u`, with `ω₀` of ±(1.2–3.0), ±(0.6–1.6) or ±(0.2–0.6) rad/s, turning away from the centre line.
  Smaller pieces spin faster and fall faster, as in the collapse's table.
- **Depth.** The scale is `1 − 0.45·smoothstep(0, life, u)`: it sinks away toward the cloud deck. Its alpha fades over
  the last 35 % of a life of 2.4–3.6 s.

**Fragments.**
- An m component splits into 2 fragments, and an l into 3, at `u_f` = 0.25–0.7 s.
- The cracks are across the axis at 40–60 % of its length, jittered, and pre-computed at install `[B1]`.
- Each fragment inherits `v + ω × r` from its parent at `u_f` `[B2]`, plus ±6 units/s of separation.

**Debris.** An s component throws 3–6 untextured specks at release. Every release has an ember spark burst (8
sparks, 0.25 s). m and l components emit world-space smoke at 2 per second for 1.5 s `[B5]`, under the shared
90-puff cap.

**Reduced motion:**
- no root tear, spin, fragments, sparks or specks;
- kicks at 40 %;
- releases are still staggered, never a whole layer at once;
- the components still fall, shrink and fade.

## B6. Where the components come from (until the art provides them)
The bake has no per-component data today (§B9). The runtime therefore derives the components at hull install, in the
same asynchronous step as the field's distance transform (carrier-v3 §14), from the layer art:
1. **The removed texels** of each transition (§B3), at the layer's own texel density.
2. **Regions.** Connected regions of the removed texels at alpha > 0.5. A region wider than 48 units is split by a
   Voronoi partition with the carrier-render-engine's noisy metric (its §3.3).
3. **Merging.** Regions under 6 units merge into their nearest neighbour. A transition has **at most 48**
   components: the smallest neighbours merge into clumps of 2–3. The `forest` spines set has 90 thorns, so it breaks
   in clumps.
4. **The pivot** is the centroid of the region's **seam**: removed texels next to texels that stay opaque in A, the
   root where it was attached. A region with no seam takes its point nearest the hull's centre line.
5. **The axis** runs from the pivot to the region's farthest texel.
6. **The size class** comes from that length. The crack lines are placed as in §B5.

When the pack carries `BossHeroData.components` (§B9), its ids, pivots, axes and cracks replace steps 2–6 per
layer. The rest of the pipeline is unchanged.

## B7. Budget
| Item | Limit | How |
| --- | --- | --- |
| Components per transition | ≤ 48 | merging (§B6) |
| Live bodies (components plus fragments) | ≤ 64 components, ≤ 96 fragments | oldest faded first |
| Vertices per frame for the component mesh | ≤ 3,000 (8-unit cells per component) | one `drawVertices` over B's texture |
| Composes per fight | ≤ 15 (§B3) | `composites` counter |
| Install-time extraction | async, with the field's distance transform | timed in the test |

Bodies cost CPU, so keep them few `[B3]`, and allocate their storage once, at the cap `[B4]`. The carrier-render-engine's phone profile (its task 4.4) covers this too. Until it runs, these are vertex counts and
VM timings, not phone frame times.

## B8. Consistency with the cohesive collapse
- **Unchanged.** The collapse (carrier-render-engine §3) keeps its sections, chunks, timeline and depth scale.
- **Still attached at the killing blow.** Components still attached are drawn into the wreck's composite at compose
  time, with their masks, from B over A. They are part of the one structure and break with its chunks.
- **Already released.** Components already free finish their own flight, drawn after the wreck. They are in front of
  it and sink at their own depth scale.
- **No module wrecks.** `BossDirector` makes no module `BossWreck` and no random `plate` wreck for a v2 carrier. The
  frontal hulls keep theirs.
- **Tests.** The carrier-render-engine cohesion and continuity tests run unchanged.

## B9. What the art pipeline must provide
**What exists today** (`origin/game`):
- `tools/rigkit` builds each module instance from its prims. An `array` prim (the spines' `great`, count 7; `row`,
  count 8, mirrored) is built as **one** object per prim.
- The `id` pass colours by **instance** (`rig.py instance_ids`).
- The bake makes layers per module and stage, plus module wreck sprites.

So there is no per-element id, pivot or axis in any output. The rig *knows* the elements, though: an array's path,
count, drop and child frame give each element's root and direction analytically.

**What the re-render adds** (`origin/work/carrier-v3-render`, `plan/render-runs/carrier-v3.md` K0):
- heights per instance;
- the field data;
- fracture **chunks** at 30–40 per hull, about 110 units apart (collapse scale, too coarse for 6–14-unit spikes);
- hinges and vortex points for wings and tendrils;
- door states and a gate map;
- clearings and overscan.

None of this is per-component. **So the current bake does not have the C5 data.**

**What it must add** (tasks §9):
1. **Elements as objects.** Each array element and each door leaf is its own object in `build_hull`, carrying
   `ob['elem']`. A new **`comp` id pass** encodes (instance, element) as 16-bit flat colour. It is rendered at the
   stored view for the S0 layers that the S2 shed removes (tags `plate`, `shard`), for every detachable module's
   layer, and for door leaves.
2. **A component manifest** in the bake's sidecar, packed by `boss_sheet pack` into `BossHeroData.components`. Per
   component:
   - `id`, `layer`, `prim` and `element`;
   - the **pivot** (the element's root, ship-frame x, y, z, projected to hull-local units as the anchors are);
   - the **axis** (the child frame's root-to-tip direction, projected);
   - the size class;
   - for m and l, a **crack** (a plane across the axis at 50 %, projected to a line);
   - plus a per-layer component-id page at the layer's own density, packed only for removable layers (estimated
     ≤ 1.5 MB per hull, inside the 16 MB `rigsheet budget`) `[UNSOURCED: plan/provenance-audit.md#CH-7]`.
3. **Sockets.** In the S3 and later art, each detached element leaves a charred **socket** prim at its root, so a
   released spike uncovers a stump, not clean hull. Until then the runtime draws a char decal at each released
   pivot.
4. **Hatches.**
   - The dorsal hatch modules sit at the `CarrierHatches` anchors per tour (§A3), with closed and open states, as
     the render branch's `hatch.slab`, `hatch.petal`, `maw.iris` and `sac.cluster` already are. Their door leaves
     are components (item 1).
   - The `anchors.verify_dart` check reads `lib/game/carrier_hatches.dart` instead of `carrier_gates.dart`.
   - The pods, flank maws, sacs and aft gates are no longer launchers: they stay closed as decor, or are removed with
     their clearings restored.
   - The `clearings` rule keeps decor elements out of each hatch's radius.
5. **The `rig.py --check` grammar gate** fails when a transition would exceed 48 components after the merge rule, or
   when an element of a removable layer has no root on its parent's surface.

Durability (CLAUDE.md §5): commit the picked raws and the recipe. The run ledger is
`plan/render-runs/carrier-hatches.md`.

---

# C. Decisions, risks and open questions
**The operator's decisions (round 3d), which supersede this design's first version:**
- Upper hatches are shot directly. Each has its own field and hit points, and destroying them is the prerequisite.
  (The first version said "upper hatches not directly shootable" and dropped tiers on shield cells. Both are gone.)
- When all of them have fallen, the ship transforms to expose the lower, delicate hatch, and the camera zooms in
  slowly again.
- Three radio hints, one line each. Subtitles fit one line so the font can grow.
- The boss gets easier through structure.

**Decisions taken on the operator's behalf** (each is one constant or flag; the operator overrides):
1. One change for both workstreams. A destroyed hatch *is* a break-up, and both share the events and the review.
2. The tiers are kept (2/2/3/3/4 upper tiers), moved lower (§A3), with only the topmost intact tier vulnerable, so
   the "lower and lower hatches" of round 3c stays.
3. The old hull-wide shield's HP is redistributed into the hatches at `k` = 0.85 to start. The hull-wide intercept
   and its equivalence test are retired for the carrier.
4. The "lower, delicate hatch" is the core door alone. The side hatches seal at the transformation, and the door's
   window widens to 16·door.
5. The glide slows to 0.35 in the hatch chapter and 0.6 in the core chapter, and the lead pip shows on Easy and
   Normal.
6. Arrival invariance (§A6): the flocks keep their rhythm, and the easing comes from structure.
7. The gate events are renamed to hatch events, and the cell and field-impact events are retired for the carrier.
8. Subtitles: 14.5 px on the phone, and a 28-character one-line limit enforced for the hints. The rest of the bank
   keeps wrapping.
9. Break-up by transition and composite difference (§B3), with an art-derived fallback (§B6).

**Risks:**

| Risk | Mitigation |
| --- | --- |
| The render merge changes the painter, the gates, the doors and the field under this spec | tasks §1 re-reads them first; design §A9 and §B1 are updated before any code |
| The expert pilot shows little change, because it always led perfectly | the naive pilot measures the human difficulty (§A11) |
| Easier overshoots: the fight feels trivial on Normal | the targets are bands (± 5 points); the levers in order; Hard is barely eased |
| Far hatches are hard to hit even slowed | the tiers moved lower; the 18-unit fields; the hint and the lead pip |
| Long top-tier swoops crowd the upper screen with untargetable creatures | the transit line is just under the deck; the skein spacing; review sheet 8.1 |
| The split-composite memory spike on phones | one transition per pass; B released at its end; the phone profile (carrier-render-engine 4.4) |
| The fallback components look wrong on dense sets | the clump merge; the component pass (§B9) replaces it |
| A larger subtitle font overflows the desktop tiles or the dock's height | a widget test at 360 × 640 and 1280 × 720 over every line: no ellipsis at the new size (task 4.5) |

**Open questions for the operator:**
- Should lower tiers bring heavier kinds or escorts? `roster` is reserved.
- Should the rest of the radio bank be rewritten to one line (471 lines exceed 28 characters)?
- Is the lead pip welcome, or should the hint alone teach leading?
