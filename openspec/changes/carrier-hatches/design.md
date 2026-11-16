# Design: Carrier hatch cascade and component break-up (carrier-hatches)

## Inputs and citations
- **Operator input:** round 3c, C4 and C5 in `plan/operator-feedback-2026-11-16.md`, quoted in the proposal.
- **Code read on `origin/game` (445f2888):**
  - `lib/game/carrier_gates.dart`, `carrier_script.dart`, `boss_director.dart` and `boss_grammar.dart`;
  - `model.dart`: `Carrier`, `hitBoss`, `_updateApproach`, `_gateLaunch`, the fight flocks in `_updateBoss`, and
    `_bossDecayEvents`;
  - `scene.dart`: the boss block after the creature loop;
  - `tools/rigkit/rig.py` and `rigkit.py`, and `art/families/alien-carriers.json`.
- **The carrier specs this change builds on:**
  - `openspec/changes/carrier-v3/design.md` §4 (gates) and §10 (events);
  - `openspec/changes/carrier-render-engine/design.md` §3 (collapse) and §5 (re-render interfaces);
  - `plan/render-runs/carrier-v3.md` on `origin/work/carrier-v3-render` (K0: what the re-render delivers).
- **Research:** `plan/carrier-hatches-research.md`. Source IDs (`[H1]`, `[B2]` …) are its rows, in the CLAUDE.md §8
  form. Our own choices are marked `[UNSOURCED: plan/provenance-audit.md#CH-n]`.

## 0. What stays
- **The fight's rhythm**, all carrier-v3 numbers:
  - the flock timer (2.4–5.6 s), the flock size (≤ 3), the kinds, and the caps (6, 8 and 10);
  - the volley timing (telegraph 1.2 s, open 0.5 s, 0.12 s apart, close 0.8 s, at most two open).
- **The core's hit rules:**
  - the shield intercept;
  - the centre door and side-hatch cycles;
  - the side hatches sealing on the last form (main spec, "Carrier shield and door").
- **Unchanged:**
  - the decay stages and their events;
  - the intro;
  - the bend;
  - the field;
  - the cohesive collapse.

---

# Part A. The hatch cascade (C4)

## A1. What the operator saw, and why
| Saw | Cause in the code |
| --- | --- |
| "The demons fly under it, so we cannot see them anymore." | The fight's flocks leave `bayL/bayR` (hull-local y 21) or the prong gates (y 52), and settle at `b.y + 70`. The prow spans hull-local y −78 … +66 (`BossHeroSprite` of `prow.thorn`), and `scene.dart` draws the prow (`paintHero(front: true)`), the deck and the gates **after** the creature loop. So every creature over the prow is under its art. |
| Gates are not "from the top". | The tour-1 gates are the deck bays and two pods under the prongs. The dorsal compartments exist only from tour 3, and the aft gates (y −300) lie above the visible arena at zoom 0.86. |

## A2. Hatches in tiers
**The decision.** Launches leave from hatches on the hull's top (dorsal) surface. The view looks down at 45°, so
that surface faces the player and a creature leaving it is in view (§A2, "Visibility"). The hatches are ordered in
**tiers** from the stern (up-screen) toward the deck. Only the **topmost intact tier** launches. Damage knocks out
tiers from the top, so the launches come from lower and lower hatches, closer to the player, until they leave the
openings the player can shoot. One read reference stages this, and one snippet adds context:
- the Star Fox 64 mothership, whose hatches release fighters before its core is summoned, each hatch a target of its own `[H1]` `[H2]`;
- Gradius, where the open hatch is both the threat and the opportunity (`[H3]`, snippet only: context, not a source).

The progressive dismantling of a giant ship is the shmup "battleship raid" (`[P1]`, snippet only); losing parts shows progress better than a health bar `[P3]`. The tier count and positions are
ours `[UNSOURCED: plan/provenance-audit.md#CH-1]`.

**The tiers of one tour.** Upper tiers U1 … Un (one dorsal pair each), then the **deck tier** D (the deck bays
`bayL/bayR` at ±46, y 21, which are already the core's side hatches, plus the core door at (0, 25)), then the **maw
tier** M (the core door alone).

| Tour | Upper tiers n | All tiers | U1 | U2 | U3 | U4 |
| --- | --- | --- | --- | --- | --- | --- |
| 1, 2 | 2 | 4 | y −215, x ±72, `hatch.slab` | y −110, x ±92, `hatch.petal` | — | — |
| 3, 4 | 3 | 5 | −225, ±70, slab | −160, ±96, petal | −95, ±80, `maw.iris` | — |
| 5 and later | 4 | 6 | −235, ±68, slab | −180, ±96, petal | −125, ±84, iris | −70, ±62, `sac.cluster` |

**The coordinates** are hull-local arena units: x to the right, y down-screen, so negative y is up-screen, toward
the stern.
- Normals point up out of the hull: (±0.2, −0.98), as carrier-v3's dorsal compartments do.
- Hatch widths are 22 units.

**Why these places.**
- **Visibility.**
  - At the fight's widest-to-tightest zoom band [0.86, minZ], the arena's top edge at zoom 0.86 is screen
    y = 477 − 477/0.86 ≈ −78.
  - The glide's highest row is b.y = 189, so the U1 hatch at −235 sits at screen y −46. That is 32 units inside, and
    the 0.3 s pop-up (§A5) rises 10 units.
  - The aft gates of carrier-v3 (y −300) fail this test, so they retire as launchers.
- **Width.** |x| ≤ 96 keeps both hatches of a pair inside the arena band [16, 344] for most of the carrier's travel
  (x ∈ [82, 278]). The carrier-v3 skip rule still applies: a hatch off the arena does not launch, and its skein moves
  to the pair's other hatch.
- **Retired as launchers:**
  - the prong pods (y 52: under the prongs, the cause of A1);
  - the flank maws and sacs (|x| ≥ 228, mostly off the arena);
  - the aft gates.

  Their art, when the re-render has it, stays as closed decor (§B9.4).
- **Simulation geometry.** As with the carrier-v3 gates, the hatches are simulation data: the art conforms to them
  within ±3 units through the rig's anchor gate, never the reverse.

## A3. What drops a hatch
**Upper tiers drop on shield-cell thresholds.** The shield has 12 cells (`Carrier.shieldCells`). When the lit count
reaches a threshold, the topmost intact upper tier drops, so both of its hatches drop at once.

| Upper tiers | Thresholds (lit cells) | Shield share per tier (U1 … Un) |
| --- | --- | --- |
| 2 (tours 1–2) | 6, 0 | 50 %, 50 % |
| 3 (tours 3–4) | 9, 6, 0 | 25 %, 25 %, 50 % |
| 4 (tour 5+) | 9, 6, 3, 0 | 25 % each |

- **Why cells.** These are the decay steps the player already sees: the field's regions and insignia cells, and
  S1 at 6 cells. "As we hit it the top hatches drop": shield hits are the hits of the shield phase. The lowest upper
  tier holds longest on tours 3–4, because it is the closest and most pressing tier, so the shield phase escalates
  `[A3]` `[UNSOURCED: plan/provenance-audit.md#CH-2]`.
- **The deck tier** takes over at 0 cells, at the same moment as `bossShieldDown` (S2). Its bays are the core's
  side hatches, so the player can shoot the hatch the creatures come out of.
- **The maw tier** takes over at the last form, when the side hatches seal (the rule today). The bays drop, with
  cause `form`, and the core door is the last hatch. The core fight has no other tier changes: the intermediate
  form changes (tours 2–5) tear modules away (Part B) and quicken the flock timer, as today.
- **Upper hatches have no hit points.** The intercept is unchanged, so shield balance cannot move.
- **The supersession.** carrier-v3 kept its gates indestructible, and the operator approved that. This change
  supersedes it: upper hatches are knocked out by the shield's damage, and the last two tiers are the core's own
  shootable openings.
- **A volley caught by a drop.** Creatures already out keep flying. Creatures still queued move to the same side's
  hatch on the next tier, or the other side when that hatch is off the arena. Their remaining telegraph is shortened
  to at most 0.4 s, and the next tier's shorter transit (§A5) absorbs the rest.

## A4. Launch cadence and roster per tier
The flock timer, flock size, kind (`min(3, cycle + 1)`), hit points and caps are **the same on every tier**: the
calibration gates (§A11) rest on them. A tier changes only three things:
- **The origin.** The active tier's pair, alternating sides from a seeded start (carrier-v3's round-robin, now
  within one tier).
- **The volley shape.** Upper tiers release the flock as a **skein**: the 0.12 s spacing, each creature taking the
  same swoop, offset 14 units outward. Deck and maw launches release it as a **burst**: the same spacing, fanned
  ±25°.
- **The lead.** The telegraph starts `telegraph + open + (transit − 0.55)` before the nominal timer, so the arrival
  stays fixed (§A5).

The operator's "this is just the beginning of the boss fight" leaves room for per-tier rosters later: escorts,
heavier kinds on lower tiers. `CarrierScript.hatches[].roster` is reserved, defaults to today's, and is not used by
this change.

## A5. Transit, arrival invariance and fairness
**The path.**
- **Pop-up, 0.3 s.** The creature rises 10 units out of the hatch along its normal and grows from 0.8 to 1.0, lit by
  the hatch's glow. Every attack advertises itself `[A3]`.
- **The swoop.** A cubic curve from the hatch to the creature's home slot, bowed 40 units outward to its side, at
  300 units/s. It is never aimed at the ship's row: the homes sit at y ≤ b.y + 110 < 330, and the ship's row is
  477 `[A3]`.
- **The transit time:** `transit = 0.3 + max(0.25, 1.1·L/300)` s, where L is the straight distance from the hatch to
  the home, rounded to 0.05 s.
  - A deck bay gives 0.55 s, today's entrance.
  - U1 on tour 5 (L ≈ 305) gives ≈ 1.45 s.

**Arrival invariance.** Today a flock is added when the timer reaches 0, and its entrance ends 0.55 s (+ i·0.06)
later. Under this change:
- the cap and size are decided, and the creatures added at the hatch, when the timer reaches `transit − 0.55`
  instead of 0;
- the timer reloads with `+= period`, so its nominal schedule is unchanged;
- each entrance ends at the moment it ends today.

The flocks therefore pressure the player at the same moments. Only their origin and path change.

**Targetable only below the transit line.** A creature above hull-local y + 40 (just under the deck, above today's
`b.y + 52` entry) cannot be hit. A shot crossing it flies on. Below the line, the entering rules apply as they do
today. The kill windows therefore match today's, while the creature is visible the whole way: "seen, not yet in
play", the carrier-v3 launch rule `[A2]`.

## A6. The shootable tiers ride the door cycles
A deck-tier or maw-tier launch must leave through an opening that is open in the game, or the "hatch we can shoot"
would be a lie. Forcing a door open would add core exposure and move the endurance gate.

**The release opening.** At the release moment (the end of the lead), the model evaluates the closed-form door
cycles:
- `sideDoorLeft/Right ≥ 0.55`;
- the centre door `door ≥ 0.6`;
- the cycles are functions of the level clock and the phase (`_updateBoss`), so a forecast is exact unless the phase
  changes in between.

The rules:
- **Deck tier:** an open bay, alternating; otherwise the open core door.
- **Maw tier:** the core door.
- **When nothing is open,** the volley parks in the opening that opens first: the creatures are unseen and
  untargetable (carrier-v3's `gateWait`). It leaves as that opening opens, at most one door period later (≈ 4.3 s for
  the bays, ≈ 3.5 s for the core door).

So the hatch's doors open, the creatures burst out, and that same opening is the core's hit window: the threat and
the opportunity at once: a hatch that launches and can be destroyed `[H1]`. Only these held arrivals move later, and the calibration measures their share (§A11).

## A7. The approach
The launch waves keep their rosters, counts, D steps and the 90 s cap (carrier-v3 §4.3–§5.3). Only their origin
changes:
- they come out of **all the upper tiers' hatches** (no tier is dropped yet), round-robin, crossing sides and tiers;
- their positions are projected through D, as today;
- the deck bays are not used: "they come out of the top".

The entry nearness is at least the carrier's fog-slot nearness + 0.02. A launched creature is therefore drawn in
front of its hull from its first frame (§A10).

## A8. Events for the music engine
These are all structured `GameEvent`s, queued by `_queueGameEvent`. None is a raw string in `model.events`, so the
radio never speaks twice (CLAUDE.md §3). Every event carries `route`, `tour`, `set`, `variant` and `sector`.

| Event | When | Data | For the score (suggested) |
| --- | --- | --- | --- |
| `bossHatchTelegraph` (was `bossGateTelegraph`) | a hatch's telegraph starts | `hatch`, `tier`, `side`, `kind`, `shootable` | a riser, panned by `side` |
| `bossHatchOpen` (was `bossGateOpen`) | its doors open | `hatch`, `tier`, `shootable` | a mechanical hit on the next beat |
| `bossLaunch` (kept) | the volley leaves | `hatch`, `tier`, `count`, `kind` | a percussion burst sized by `count` |
| `bossHatchClose` (was `bossGateClose`) | its doors close | `hatch`, `tier` | — |
| `bossHatchDrop` (new) | a hatch is knocked out | `hatch`, `tier`, `side`, `cause` (`shield` or `form`), `cellsLeft` | an impact, then a falling figure |
| `bossHatchTier` (new) | the active tier changes, and tier 1 right after `bossInRange` | `tier` (1-based), `tiers`, `depth` = (tier − 1)/(tiers − 1), `shootable`, `from` | **a section change** |

- **Order within one hit:** `bossShieldCellLost` … → `bossShieldFailing` or `bossShieldDown` → `bossHatchDrop`
  (left, then right) → `bossHatchTier`.
- **Order on the last form:** `bossModuleLost` → `bossCoreExposed` → `bossHatchDrop` (the bays, cause `form`) →
  `bossHatchTier`.
- **One name per moment.** The old `bossGate*` names are retired, not emitted alongside the new ones. Nothing maps
  them today (`music_director.dart` maps only `bossApproach`, `bossInRange` and `bossTakeoff`).

**The tiers are the fight's song.** Adaptive scores change sections on game-state cues and move to the next musical
boundary, rather than cutting at the event `[M1]` `[M3]`. So:
- `bossHatchTier` is the section boundary;
- `depth` is a continuous intensity parameter for layering `[M2]`;
- the volley events are hits the engine may quantise to its own next beat.

The game never waits for the music. This is the shape for "one whole run … one smooth play of a long song". The
score itself still waits on tillandsias#1103.

## A9. What changes in the existing code (after the render merge)
- **`carrier_gates.dart` → `carrier_hatches.dart`.** The geometry is replaced (§A2). `GateRun`, `CarrierLaunches`
  and `CarrierVolleyTiming` move across unchanged, except that `pick` takes the active tier's hatches. A deprecated
  re-export stays until carrier-v3 is archived.
- **`CarrierScript`.** `hatches` and `hatchOrder` replace `gates` and `gateOrder`. The seeded variation picks only
  which side starts each tier.
- **`model.dart`:**
  - `_fightGate` and its lead (§A4–§A5);
  - `_gateLaunch` for the approach (§A7);
  - the drops in `hitBoss` and at the form change (§A3);
  - the deck and maw hold (§A6);
  - the events (§A8).
- **`fightReach`.** carrier-v3's `|x| ≤ 150` rule for fight gates is replaced by the active tier.
- **The render's gate map.** `BossHeroHull.gates` and `BossHeroView.doors` from `work/carrier-v3-render` are re-keyed
  to hatch ids (§B9.4). The door layers serve the dorsal hatches. Task 1.1 records what the merge brought.

## A10. Presentation
- **Draw order (the fix for A1).** In the fight, `scene.dart` draws the hull's back pass, then the prow pass, the
  deck, the hatches and the field (membrane and lip), and **then** the creatures, their tells, deaths and muzzle
  flashes.
  - No creature is ever covered by the hull. A creature's swoop is its own read of depth: it flies between the
    carrier and the camera.
  - During the approach, the entry nearness of §A7 orders launches in front of the hull's slot.
- **The hatch.** The door layers from the re-render, when present; otherwise carrier-v3's runtime leaves, iris, slab
  and sac. The telegraph lights and the rail chase are carrier-v3's.
- **The way out.** A creature passing the force field's membrane makes a faint ripple at 0.5 of a hit's strength,
  with no event and no `bossFieldImpact`.
- **The drop (1.0 s).**
  - The hatch's lights flicker for 0.25 s and die.
  - Its door leaves blow off as Part B components, with an ember burst.
  - The opening seals in char, and a world-space smoke emitter puffs at 2 per second for 6 s, then at 0.5 per second
    (sharing the collapse's 90-puff cap).
- **The cascade chase.** From 0.2 s to 1.0 s after the drop, the hull's rail lights run down-screen from the dropped
  tier to the new one, and the new tier's hatches arm with an ember pulse. It tells the player where the creatures
  come from next `[A1]` `[A2]` `[UNSOURCED: plan/provenance-audit.md#CH-3]`.
- **No shake.** Shake stays on carrier-v3's four beats `[J3]`.
- **Reduced motion:**
  - no pop-up growth;
  - the drop flickers once with no ember burst, and its leaves fall without spin;
  - the new tier lights at once, with no chase.

## A11. Calibration plan (CLAUDE.md §7)
**What holds by construction:**
- the timer, sizes, kinds and caps;
- the arrival moments (§A5);
- the core's exposure (§A6, no forced doors);
- the shield intercept.

**What can move the numbers:**
1. **Deck and maw holds.** These arrivals come later, by at most one door period, so the core fight is slightly
   easier.
2. **Re-routing on a drop.** At most 0.4 s.
3. **Swoop positions.** Creatures arrive from above rather than from the deck, so they meet the player's fire
   differently. Untargetable above the transit line, they meet it at the same row.
4. **The approach's origins.** Dorsal rather than mixed, as in carrier-v3 §4.3.

**The gates:**
- boss endurance pooled within 5 % and each difficulty within 10 %;
- the campaign playtest's bounds;
- the boss level's clear time within 10 %;
- every value recorded in `plan/calibration-current.md`.

**Levers, in order, one at a time** `[UNSOURCED: plan/provenance-audit.md#CH-4]`:
1. `deckHoldMax`: cap the hold at 1.5 s, after which the volley leaves through the opening that opens soonest, with
   its doors drawn opening (presentation only).
2. Hold only the maw tier. The deck tier leaves at the nominal time through the bay whose cycle is nearest open.
3. `transitSpeed` 300 → 340 units/s, if the swoops arrive too spread out.

Only if all three fail does the flock timer itself change, as a recorded balance change.

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
- a dropped hatch's doors (§A10).

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
| **Shed** (plates, crystals) | S1 (`bossShieldFailing`): B = S1, A = S2 | Each component is given a shield threshold in (0, 0.5], outer first, matching the field's region order (carrier-v3 §3.2). It releases as the shield passes it, so about 70 % have gone before the shield is down. A field impact within 40 units of an attached component's pivot may release it early (at most 2 per second). At `bossShieldDown`, the remaining ones go over 2.5 s. |
| **Detach** (the module of form r) | `bossArmourShed` for that module (the odd armour step before the form change): B = the current set, A = the set + rank r | 35 % at the armour shed, over ≥ 1.2 s, tips first: the module is cracking. The rest at the form change (`bossModuleLost`), over ≥ 1.6 s. Root stubs stay as sockets (§B9.3). |
| **Hatch drop** | `bossHatchDrop` | The hatch's door leaves (2–4 components) within 0.3 s, outer leaf first (≥ 2, so the rate rule allows it). |

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
   - The dorsal hatch modules sit at the `CarrierHatches` anchors per tour (§A2), with closed and open states, as
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

# C. Decisions taken on the operator's behalf, risks and open questions
**Decisions** (each is one constant or flag; the operator overrides):
1. One change for both workstreams. The hatch drop *is* a break-up (its doors), and both share the events and the
   review.
2. Tiers per tour 4/4/5/5/6, with upper tiers on shield-cell thresholds (§A2–§A3).
3. The deck tier is the core's side hatches, and the maw tier the core door: the shootable hatch already exists in
   the rules, so no new hit box is added.
4. No forced doors. Shootable launches wait for the natural cycle (§A6).
5. Arrival invariance (§A5). The cascade changes where creatures come from, not when.
6. The gate events are renamed to hatch events, rather than kept beside them.
7. Break-up by transition and composite difference (§B3), with an art-derived fallback (§B6).

**Risks:**

| Risk | Mitigation |
| --- | --- |
| The render merge changes the painter, the gates and the doors under this spec | tasks §1 re-reads them first. Design §A9 and §B1 are updated before any code |
| The deck hold makes the core fight easier | measured (task 5.1); the §A11 levers |
| Long top-tier swoops crowd the upper screen with untargetable creatures | the transit line is just under the deck; the skein spacing; review sheet 8.1 |
| The split-composite memory spike on phones | one transition per pass; B released at its end; the phone profile (carrier-render-engine 4.4) |
| The fallback components look wrong on dense sets (forest thorns, crown shards) | the clump merge; the component pass (§B9) replaces it |
| The hatches overlap existing dorsal decor before the re-render | the runtime draws hatch rims over the composite; the clearings rule in the re-render |

**Open questions for the operator:**
- Should lower tiers bring heavier kinds or escorts ("this is just the beginning")? The roster field is reserved
  (§A4).
- Should an upper hatch also be directly shootable, beside the shield thresholds? This change says no, to keep the
  shield's balance.

## Lead decisions on the open questions (2026-11-16)

- **Lower tiers bring heavier creatures?** Not in the first cut: rosters stay as they are today. *Why:* the change is
  balance-neutral by construction, so the boss endurance gate (§7) stays meaningful. Escalation per tier is a
  follow-up tuning task once the cascade is in the operator's hands; it is also a natural hook for the music engine's
  `bossHatchTier` sections.
- **Upper hatches directly shootable?** No. Upper tiers drop only on the shield thresholds. *Why:* the operator's words
  were "until they come out from the hatch we can shoot", so only the last tiers (deck bays, then the maw) are
  targets. Shooting the hull is what drops the upper hatches, which keeps one clear rule: hit the ship, the launches
  move down.
