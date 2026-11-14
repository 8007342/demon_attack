# Ground war easter eggs

Small, rare moments of life on the ground, asked for by the operator: "little dances after a victory, little tanks exploding into pieces, trees coming down releasing flocks of other flying creatures that just fly off, or swarms of other ground creatures running away from ground troop activity." OpenSpec change: `openspec/changes/ground-forces-rework/`. Frame layout: [ground-unit-animation.md](ground-unit-animation.md).

## 1. The rule: never obscure gameplay

Every easter egg obeys all of these. The runtime enforces them in one place (an `EasterEggBudget` in the ground painter), so each egg only asks for permission.

1. **Presentation only.** No hitbox, no score, no event the music or the radio reacts to, no change to any simulation state. Randomness comes from a presentation stream seeded by the entity id and the sector clock, never from `model.random` or `GroundSkirmish.rng`, so replays and the difficulty bots are unaffected.
2. **Out of the lane.** Nothing enters the central lane (x 96–264) below y 300, where the ship flies and hostile shots fall. Flocks fly up and outward toward the horizon and the screen edges; critters run toward the outer edges; debris arcs are clipped at the lane edge (pieces that would cross it land short).
3. **Below the signal colours.** Bodies at luma ≤ 0.34. No `demon_warm` brighter than step 2, no `ally_cyan` brighter than step 1, no gilt. Warm and cyan mean "shot" and "friend"; an easter egg is never either.
4. **Quiet when it matters.** Suppressed while any of these is true: a threat telegraph or ground missile is on screen; a boss or carrier fight is running; the player is on the last life; fewer than 2 s since the player was hit; an arrival hint card is up.
5. **Budget.** At most one egg running per side band and two on screen. Each has a cooldown (below). Debris ≤ 8 pieces per breakup and ≤ 16 on screen; flocks ≤ 9 flyers; critter groups ≤ 8.
6. **Short.** Each lasts at most 2.5 s, except the sector-clear dance (3 s, when the air war is already over).
7. **Reduced motion.** Dances, flocks and critter flights are off. A light vehicle's breakup becomes the plain wreck. Trees still fall (that is the existing vegetation behaviour).
8. **Far is skipped.** Only at z < 900 (where they can be seen), except flocks, which fly *into* the distance.

## 2. Victory dance

| | |
| --- | --- |
| **Who** | Fleet infantry squads (rifle and rocket troopers); Fleet vehicles do a no-new-art flourish |
| **Trigger** | `skirmishWon` for an engagement the squad (or the vehicle carrying it) took part in, with no other Host unit within 200 texels. Guaranteed at **sector clear** for every Fleet squad on screen |
| **Rarity** | 1 in 3 skirmish wins; global cooldown 40 s; sector clear always (once) |
| **What plays** | Troopers: `flourish` 4 frames × 2 loops at 0.12 s, each trooper offset by one frame (a ripple through the squad), then back to `walk`. Variants by squad index: a fist pump, a little hop, a side-step shuffle, a rifle held overhead. Vehicles: a turret twirl (the art layer sweeps a0 → a4 → a0 at 2 steps per frame) and a 1-texel hull hop on beat 3 |
| **Host counterpart** | Rubblings do a 4-frame taunt **jig** when an engaged ally falls back (`allyFallingBack`), 1 in 4, cooldown 60 s. It is cheeky, not hostile; no warm flash |
| **Assets** | `flourish` 4 frames in each infantry block (Fleet rifle, Fleet rocket, Rubbling, Ashlar Guard). No vehicle frames |
| **Never** | No dancing within 1.5 s of a shot landing nearby; no dance while totalled allies are smoking within 100 texels (it would read as gloating over a friend) |

## 3. Little tanks in pieces

| | |
| --- | --- |
| **Who** | Host light vehicles: Crocket, the captured Krybor hulls, the Gutter-runner (once it has a V-block). Heavier Host units crumble (rubble) and drop 3–4 pieces |
| **Trigger** | Destroyed at z < 900 |
| **Rarity** | The **breakup** is the standard death for light Host vehicles (always). The **jackpot** variant, 1 in 8 breakups (cooldown 20 s): the turret or ridge head pops high, spins in quarter turns, bounces once and lands upright; a tiny Rubbling crew of two climbs out of the hull, looks at it, and scampers off into the rubble |
| **What plays** | Frame 0: the existing shock ring and the first 3 explosion frames. Then 5–8 **debris pieces** fly on ballistic arcs (screen space, scaled by depth), each tumbling in quarter turns (0°, 90°, 180°, 270°, mirrored: lossless, no new art) at 8–12 steps/s. Pieces bounce once (40% restitution), slide 2–4 texels and stop; warm seams on stone pieces cool from `demon_warm[2]` to stone over 1.5 s; pieces fade at 2.5 s. The hull itself shows `wreck` then `rubble` |
| **Pieces** | Cut from the unit's own finished frame by the generator along authored seam lines: the turret or gun head, the prow face, two track runs, two hull plates, two ornaments (hooks, horns), plus small chips (12 per unit, two 6-piece debris sheets in the V-block). The captured Krybor hull also sheds one **human** plate in the old grey-blue, the story of a captured machine |
| **Assets** | Debris sheets per vehicle (generated, no GPU); the jackpot crew uses the Rubbling `arrive` and `run` frames |
| **Never** | Pieces never cross into the lane (rule 2); never land on the ship's band; never brighter than the explosion; Fleet vehicles never break up (they are totalled, as always) |

## 4. Trees come down, flocks fly off

| | |
| --- | --- |
| **Who** | The flyover vegetation that can fall (`art/families/flyover-vegetation.json`: frost-pine, cinder-tree, grave-fungus stalks, brood-stalk; crystals shatter and do not release flocks) |
| **Trigger** | A tree enters its `break` frames: pushed over by the convoy or hit within 40 texels by a shell or an explosion |
| **Rarity** | 2 in 5 falls; at most one flock on screen; cooldown 12 s |
| **What plays** | As the tree passes `break-b`, 5–9 small flyers burst from its crown (spawned over 0.3 s), climb steeply, then fly **away**: toward the horizon and outward from the lane, getting smaller with depth and fading into the fog layers ([ground-atmosphere.md](ground-atmosphere.md)). A 2-frame flap at 10–14 fps, each flyer offset in phase; the flock loosens as it climbs. Gone in 2.5 s |
| **Species** (original, one per sector, tiny and muted, nothing like a gargoyle) | Krybor **rime moths**: pale grey-lilac flutterers with frosted wing dots. Ringfall **dust kites**: flat diamond membranes that glide between flaps. Ember **ash flits**: soot-grey with pale tan bellies, quick zig-zags. Hollow **puffwings**: round spore-like bodies with two stubby wings, slow bobbing. Carrier **hull gnats**: dark plum specks that move as a tight cloud |
| **Size** | 6 × 4 to 8 × 6 texels, drawn at the depth of the tree (so 3–6 units on screen). Clearly smaller than the smallest swarm arrival (20 units) |
| **Assets** | `ground-wildlife.png` row per species: flap A/B × 2 directions (up-left, up-right) = 4 cells of 16 × 12; plus a 2-frame leaf or spore burst in the vegetation particles row (existing particle kinds: leaves, spores, ash, shards) |
| **Never** | Never fly toward the camera or into the lane; never at the swarm's altitude band (they stay below y 200 on their way out, then vanish into the fog); never warm-lit (rule 3); never mistaken for a target |

## 5. Critters flee the troops

| | |
| --- | --- |
| **Who** | The existing flyover ground critters, two species per sector (`flyover-backgrounds.json`: frost-hopper, shell-crawler, rock-mite, dust-grazer, cinder-newt, ash-borer, spore-crawler, bone-skitter, brood-larva, hive-tick) |
| **Trigger** | A group of 4–8 critters is placed in a side band near a feature (a rock, a tree line). It scatters when a ground unit comes within 50 texels, or a shell or explosion lands within 70 texels |
| **Rarity** | A group appears in about 1 of 3 terrain features near the action; at most 2 groups fleeing at once; cooldown 8 s per band |
| **What plays** | Every critter turns away from the disturbance (mirrored frames), then runs at 2.5× its walk rate with the new `leap` frames on alternate strides, fanning out toward the outer screen edge. After 1–1.5 s, half of them burrow (the existing `burrow` frames 6–7) and the rest run off screen. A tiny dust puff per leap |
| **Assets** | 2 new `leap` frames per species (A/B) in `ground-wildlife.png` (20 cells); the existing walk, duck and burrow frames in `flyover-creatures.png` |
| **Never** | Never cross the lane (they run outward); stay on the ground plane; luma ≤ 0.34 (the existing creature cap is 0.42, so these use its darker steps) |

## 6. Assets summary

| Asset | Where | Count | GPU |
| --- | --- | --- | --- |
| Infantry `flourish` (dance / jig) | infantry blocks | 4 frames × 4 units | In the infantry in-betweens (render plan) |
| Debris sheets | V-blocks, row 3 cols 18–19 | 12 pieces per Host vehicle | None: cut from finished frames |
| Flock flyers | `ground-wildlife.png` rows 0–4 | 5 species × 4 cells | 5 × 4 transparent sprite candidates |
| Critter leap frames | `ground-wildlife.png` rows 5–14 | 10 species × 2 cells | 10 × 2 pose edits |
| Crown burst | vegetation particles row | reuse | None |

## 7. Review

- A phone-size review clip per egg over its sector, with the swarm and hostile shots on screen: a reviewer confirms that nothing in the egg crosses the lane, sits over a shot, or reads as a target.
- A frame-by-frame check that no egg pixel uses a signal colour (automated palette test on `ground-wildlife.png` and the debris sheets).
- A bot replay with eggs on and off: identical simulation hashes.
