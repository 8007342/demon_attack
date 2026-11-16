# Design: ground forces rework

The detail lives in the plan documents; this file records the decisions and why they were made.

| Topic | Document |
| --- | --- |
| Ground Fleet look | `plan/human-ground-forces-style-guide.md` |
| Headings, turrets, atlas blocks, animation sets | `plan/ground-unit-animation.md` |
| Fog, mist, cloud, smoke; interface note for the runtime | `plan/ground-atmosphere.md` |
| Easter eggs | `plan/ground-easter-eggs.md` |
| Render pipeline, workflows, family specs, checkpoints, GPU estimate | `plan/render-runs/ground-forces-rework.md` |
| Undercroft Host fiction and roster (unchanged, built on) | `plan/gargoyle-army-style-guide.md`, `openspec/changes/gargoyle-ground-army/` |

## Goals and non-goals
**Goals**
- Ground vehicles that visibly turn, with turrets that aim on their own.
- A Fleet with its own futuristic design language that can never be confused with the Host.
- A Host whose animation is as rich as a strategy-game army's, without leaving its carved-stone fiction.
- A far battlefield seen through air: fog, mist, cloud and smoke, with arrivals emerging from it.
- Small, rare moments of life that never get in the way.
- An art pipeline that keeps hundreds of frames aligned, with an honest GPU estimate.

**Non-goals**
- No gameplay change: no new threat, no change to telegraph timing, hitboxes, homing, scoring or difficulty.
- No runtime fog or arrival code here (parallel work owns it).
- No GPU run in this change's design phase.

## Decisions

### 1. Five authored headings in 22.5° steps, mirrored
Fleet hulls: 0°, 22.5°, 45°, 67.5°, 90°. Host hulls: 90°, 112.5°, 135°, 157.5°, 180°. Mirrors give 9 directions per faction. Infantry gets 3 (mirrored), the symmetric Chapterhouse 3.
- 22.5° is the existing turret step, so hull and turret share one grid.
- One step moves at least 2 texels of silhouette at mid-field, the terrain guide's visibility floor.
- 45° steps make a 90° turn two pops. 11.25° steps double the art for sub-texel changes.
- Each faction authors only the arc it drives in: the Fleet goes up the plane and reverses to fall back; the Host comes down it. Headings outside the arc clamp.

### 2. Discrete frames with hysteresis, never rotation
The ship banks by rotating the canvas, but ground sprites must stay on the grid (no rotation, no smooth scale). So the runtime follows the gargoyles' `CreatureMotion` pattern: smoothed velocity, a rate-limited heading, an index that moves **one step at a time** after a 3° hysteresis and a minimum hold (0.10–0.40 s by class), and a skid-dust puff on the outside of each step (the ground analogue of the ship's counter-thruster puff). A heavy's 90° turn shows all five headings over about 1.2 s.

### 3. One articulated layer per vehicle
Every vehicle is a hull plus at most one articulated layer (turret, gun pod, cab, Carillon cradle, Hodcrawler jib, Reliquary ridge gunner), drawn from a per-heading pivot with its own angle, rate limit and hysteresis. The layer's plan shape is close to rotationally neutral, so it can sit on any hull heading. The Host's channel-fill overlays are keyed to the layer that carries the weapon.

### 4. Blocks packed per sector, overlays generated
Each unit is a fixed block of 20 columns. Overlays (channel fill, lights, damage) are sparse cells drawn on top, generated from the rig, so 5 headings × 6 overlay states cost no hand-drawn frames. Atlases are packed **per sector**: each sector loads only its units, with the Host's sector stone and kit baked in. This settles `gargoyle-ground-army` decision 4 (sector tint) in favour of baked variants, and bounds memory (about 7 MB RGBA in the busiest sector).

### 5. The Host stays carved; the richness is in motion
"Like StarCraft" means strong silhouettes and rich animation, not a copied swarm. The gargoyle change chose *carved* deliberately, and a grown biomass army would collide with well-known swarm factions. So the Host gets five motion rules instead: it breathes (idle), it rises from below (unearthing arrival), anticipation and follow-through on every attack, secondary motion on membranes and chains, and readable, varied deaths. The prompt negatives keep "insect, chitin, tentacles, slime".

### 6. The Fleet owns the straight line and the cyan line
Fleet: straight, chamfered, horizontal, cyan **strips**, antenna rank, lighter values. Host: curved, pointed, vertical, warm **dots**, spire and gilt rank, darker values. The two read apart in black fill, in greyscale and in colour.

### 7. Rig first, then refinement, then grid finishing
A small Go rig (`tools/ground_blocks`) renders every heading and pose on the grid. Qwen-Image-Edit-2511 redraws each heading from its rig render plus the unit's approved hero (multi-reference, never chained), and Wan2.2 VACE draws organic in-betweens from rig control clips. BiRefNet mattes, then finishing masks the result to the rig silhouette (±1 texel at soft edges), quantises to the family palette, and adds the generated overlays. If the pilot (checkpoint CP1) shows the AI path is not worth it, the fallback is the existing ground-troops method: grid frames plus keyframe shading only.

### 8. Atmosphere: stepped alpha layers in depth-sort slots
Horizon fog and low cloud are bands at fixed screen rows. Two mist banks take part in the ground depth sort (at z 1050 and z 850), so units emerge through them. Unit tint follows `fogMix(z) = 0.82 × smoothstep(700, 1350, z)`, with emissive pixels fogged at half rate so the Host's light patterns show through the murk. Threat units cap at 0.45. Inside the lane below y 300 the combined alpha is at most 0.30. This is the only family with non-binary alpha: 4 steps, no gradients.

### 9. One budget for every easter egg
All eggs ask one `EasterEggBudget`: presentation only, own random stream, out of the lane, below signal colours, suppressed when threats or bosses are on screen, at most two at once, at most 2.5 s, off under reduced motion. Fleet vehicles never break up (allies are only ever totalled).

## Boundaries
| Owner | Owns |
| --- | --- |
| `gargoyle-ground-army` | Host fiction, roster, castes, palette (`demon_gilt`, sector stone), gameplay hooks, events, simulation proofs, art direction approval (its tasks 1.x, 2.1, 3.2, 3.7, 4.x, 5.1, 5.2, 5.4, 5.5) |
| `ground-forces-rework` (this change) | Fleet look; headings and turrets; animation sets for both armies; blocks and atlases; the family specs, tool, renders, packing and contact sheets for the Host (its former tasks 2.2, 2.3, 2.4, 3.1, 3.3–3.6, and the art half of 5.3); atmosphere art; easter egg art and rules |
| `ground-terrain-interaction` | Navigation and the pose state machine; its pose frames for reworked units come from this change's blocks |
| Parallel runtime work | Fog placement and tinting, arrival timing, wiring the layers and the eggs into the painter |

## Risks
- **GPU cost and drift.** About 1,320 jobs. Mitigation: a 90-job pilot gate, the lean option (about 6.5 h), never-chained edits with a hero reference, the temporal gate, and the no-GPU `offline` build so code never waits for art.
- **Memory on phones.** Per-sector packing bounds it; fallback is a half-resolution far atlas for headings h1 and h3 (open question).
- **Clutter.** Unchanged skirmish caps; LOD (fewer headings and no overlays beyond z 900); the terrain guide's cap on non-walk states counts units mid-turn; the egg budget.
- **Turret seating.** Every hull × layer pair is on the CP0 and CP4 sheets and in a contract test.
- **Faction confusion.** Black-fill, greyscale and palette checks for both factions (no warm on the Fleet, no cyan on the Host).
- **Originality.** Names and silhouettes checked against well-known units in a dedicated task; no prompt names a franchise.

## Open questions
1. Approve 5 headings per faction (9 directions), or try 4 (67.5° steps would be skipped) to cut about 20% of the art?
2. Pilot first with the Fleet (Lodestar) and the Host (Crocket) together, or the Host first?
3. Full pipeline (about 13 GPU hours) or the lean option (about 6.5)?
4. Should threat vehicles get headings too (Phase 4)? They are the units the player sees closest, but their telegraphs are a gameplay contract.
5. Is a Carrier-sector Fleet slot (the Skiff) wanted, or should the Carrier keep reusing the Hollow rows?
6. Easter egg rarities: are 1 in 3 dances, 1 in 8 jackpots and 2 in 5 flocks the right "rare but seen" level?
7. Should the Fleet's victory dance also play on `allySaved`, so the player's help gets a thank-you?
