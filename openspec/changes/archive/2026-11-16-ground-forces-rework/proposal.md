# Proposal: ground forces rework, a ground war as exciting as the air war

## Why
The operator (2026-11-14): "The ground vehicles need styleguides, some futuristic tank appearance, and a few more assets as they rotate slightly to change directions, like our ship. Similarly for the alien forces, we might want to give them a better appearance, like from StarCraft, with similar asset rich animations. We'll want the battle on the ground to be as exciting as the air coverage we're providing." And: "make sure that enemies at a distance are obscured or fogged out, maybe add some smoke and cloudy layers to add distance effect." And easter eggs: "little dances after a victory, little tanks exploding into pieces, trees coming down releasing flocks of other flying creatures that just fly off, or swarms of other ground creatures running away from ground troop activity."

Today every ground hull has one heading. Demon units are side-on and snap to a mirror image when they cross; allies always face up the plane. Allied vehicles have no style guide of their own. The gargoyle army (`gargoyle-ground-army`) has a style guide and a roster, but a thin animation set, and none of its art is made yet (0 of 28 tasks). Distant units are dimmer but crisp, so the far battlefield reads as a diorama rather than a war seen through weather.

"Like StarCraft" is genre inspiration only: a strategy-game army with strong silhouettes and rich animation. Every design here is original and fits the game's own gargoyle fiction. No unit, name, silhouette or art is taken from any game, and no prompt names one.

## What Changes
- **The Ground Fleet style guide** (`plan/human-ground-forces-style-guide.md`): the human convoy's futuristic look. "Survey gear that learned to fight": faceted plate, 45° chamfers, cyan light lines, compact turrets with long guns. A refreshed roster on the existing ally slots: Sleet (scout rover), Cairn (carrier), Tether (half-track and recovery), Lodestar (main battle tank), Sextant (long gun), Stilt (walker), Skiff (hover tank, a new Carrier-sector slot), and exo-framed troopers. Palette from the existing reserved sets; readability rules at the game's sprite size and camera.
- **Headings and turrets** (`plan/ground-unit-animation.md`): five authored hull headings per vehicle in 22.5° steps, mirrored (9 directions). A turn plays through every intermediate heading, picked by a smoothed, rate-limited tracker with hysteresis, as the gargoyles' banking frames are. Turrets and other articulated layers rotate independently on the same angle grid, from per-heading pivots. Sprites are never rotated at runtime.
- **Rich Host animation**: every Undercroft Host unit gets idle (breathing stone), move per heading, wind-up (channel fill) and release, hit, two damage states, death (crumble, topple or breakup) and an **arrival** in which the unit unearths from below. The Host stays carved living stone, not a grown swarm.
- **Atlas blocks**: per-unit blocks of 20 columns (vehicle 4 rows, walker 5, command 4 double rows, infantry 2 rows), packed per sector. Overlays (channel fill, lights, damage) are sparse cells generated from the rig.
- **Atmosphere art** (`plan/ground-atmosphere.md`): horizon fog, low cloud, two depth-sorted mist banks, cloud shadows, battlefield smoke and a tide dust veil, with stepped alpha, sector tints, a density curve by depth and a lane cap. An interface note for the runtime work, which is out of scope here.
- **Easter eggs** (`plan/ground-easter-eggs.md`): victory dances, light Host vehicles breaking into pieces (with a rare jackpot), falling trees releasing flocks, critters fleeing the troops, all under one "never obscure gameplay" rule.
- **Render plan** (`plan/render-runs/ground-forces-rework.md`): rig, then Qwen-Image-Edit-2511 per heading, Wan2.2 VACE in-betweens, BiRefNet mattes, grid finishing; three new workflows, five family specs, nine review checkpoints, about 1,320 GPU jobs (about 13 GPU hours; a lean option is about 6.5).

## Relation to other changes
- **`gargoyle-ground-army`** keeps the Host's fiction, roster, palette, castes, gameplay hooks, events and proofs. This change takes over its **art production**: the atlas layout (decision 4, now blocks packed per sector, which also settles the sector-tint question in favour of baked variants), the family spec, the tool, the renders, packing and the contact sheets (its tasks 2.2, 2.3, 2.4, 3.1, 3.3–3.6 and the art half of 5.3). Its tasks 1.x (art direction approval) are prerequisites here.
- **`ground-terrain-interaction`** keeps navigation and poses. Its pose frames for the reworked units (climb, descend, jump, wade, pitch, ford, stride-over, crest hop) are produced inside the new blocks.
- **The runtime fog and arrival work** being done in parallel owns placement, opacity, unit tinting and arrival timing; this change supplies the art and the targets (`plan/ground-atmosphere.md`, Section 6).

## Capabilities
### Modified Capabilities
- `arcade-presentation`: ground unit headings and turret articulation, the Ground Fleet look, the Host animation set and arrival, the atmosphere layers and density targets, the ground easter eggs and their budget.

## Impact
- **New docs:** `plan/human-ground-forces-style-guide.md`, `plan/ground-unit-animation.md`, `plan/ground-atmosphere.md`, `plan/ground-easter-eggs.md`, `plan/render-runs/ground-forces-rework.md`.
- **New later (tasks):** `art/families/ground-{fleet,host,infantry,atmosphere,wildlife}.json` with `-runs.json`, `art/families/rigs/`, three workflows under `art/workflows/sprites/`, `tools/ground_blocks/`, the per-sector atlases under `assets/images/`, generated Dart metadata, contact sheets under `art/contact/`.
- **Consumers (runtime, other work):** `lib/game/ground_painter.dart` (headings, turrets, overlays, blocks, eggs), `flyover_background.dart` (atmosphere), tests.
- **Unchanged:** gameplay, the threat front, telegraph timing, homing, scoring, difficulty, the air war. The four threat vehicle rows stay as they are until an optional, flagged phase.
