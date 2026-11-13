# Proposal: the Undercroft Host, a gargoyle ground army

## Why
The ground war (v3, v4) has the right amount of fighting, but the demon side is a handful of unrelated machines:
- a captured buggy, a salvage crawler, an artillery beast and a siege tower;
- grunts, rocket brutes and one heavy tank.

They share a palette but not a design language. Seen side by side they don't read as one army, and they don't read as the *gargoyle* army whose swarm fills the sky above. The question this change answers: **what would a gargoyle army build?**

The answer is researched in `plan/gargoyle-army-research.md` and specified in `plan/gargoyle-army-style-guide.md`: **a cathedral that walks to war.** The Host is carved, not built and not grown:
- living stone on cast-iron frames;
- every gun a gargoyle's spout-mouth fed by a glowing channel;
- every rank a higher, more gilded spire.

The design is original. It uses architectural and masonry vocabulary and general readability principles, and no franchise's units, names or shapes.

Contract kept from v4: **same threat.** Every new unit lives in the skirmish layer. Breakthroughs and ground shots at the player are unchanged.

## What Changes
- **Faction art direction.** The Undercroft Host has six pillars:
  - the spout rule;
  - architecture as anatomy;
  - rank as height and gilt;
  - one dominant shape per role;
  - a corruption gradient across sectors;
  - friendly-scary, with no gore and no religious symbols.

  It has four castes (Rubble, Ashlar, Tracery, Spire), a silhouette grammar with a black-fill test, and three reading distances matched to the flyover camera.
- **Roster.** Tier A, the first production set:
  - Rubblings (swarm infantry);
  - Knell-bearers (rally support);
  - Prior (officer);
  - Crocket (light tank);
  - Reliquary (troop carrier);
  - Carillon (bell-mortar artillery);
  - Buttress Strider (walker);
  - Hodcrawler (field repair);
  - Chapterhouse (mobile command).

  Tier B, the stretch set: Narthex (super-heavy), Rosegun (rotary rocket artillery), Thurible (smoke) and Cistern (slag tanker).

  The existing units take Host names and a refresh direction, keeping their atlas rows:
  - Gutter-runner, Scrapmason Crawler, Kiln Ox and Belfry (the threat vehicles);
  - Ashlar Guard, Corbel Brutes and Tympanum (the existing troops and heavy tank).
- **Palette.** The sector stone ramps sit at the existing `demon_ramp` lumas. `demon_warm` stays the only blinking accent: eyes, mouths, channels and telegraphs. A new non-blinking **`demon_gilt`** ramp marks rank. Ally cyan and teal stay forbidden on Host hulls.
- **Art families and atlases.**
  - A new family `art/families/ground-host.json` produces the new atlas `assets/images/ground-host.png`: 48 × 40 texel cells for vehicles and walkers, plus an fx row.
  - `ground-troops.json` gains three appended rows: Rubblings, Knell-bearers and Prior. Existing rows and columns keep their indices.
  - A Go tool `tools/ground_host` (it extends the `tools/ground_troops` approach: grid-authored frames plus selected keyframe shading).
- **Gameplay hooks (skirmish layer only).** New `GroundForce` kinds and behaviours:
  - the Reliquary unloads a squad;
  - the Carillon stands off and lobs arcing slag shells at the convoy;
  - the Hodcrawler mends Host units;
  - the Knell-bearers ring on the tide surge to hasten nearby units;
  - the Chapterhouse speeds arrivals while alive, and its fall routs nearby Rubblings and pushes the tide into a lull.

  None of them fires at the player, moves pressure or allied strength, draws from `model.random`, or becomes a homing target.
- **Radio events.** Five new events, each rate-limited: `reliquaryUnloading`, `artilleryRanging`, `walkerSighted`, `hostCommandSighted` and `hostCommandFallen`.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: the Host art language, the silhouette grammar, the palette and gilt rules, the role animations, reading distances, new events.
- `arcade-combat`: the Host skirmish forces and behaviours, and the same-threat proof.

## Impact
- **New:**
  - `art/families/ground-host.json` and `ground-host-runs.json`;
  - `tools/ground_host/` (Go, standard library);
  - `assets/images/ground-host.png`;
  - the generated `lib/game/ground_host_atlas.dart`;
  - `art/contact/ground-host-contact.png`;
  - tests.
- **Changed:**
  - `art/families/ground-troops.json`, `assets/images/ground-troops.png` and the generated `lib/game/ground_troops_atlas.dart` (appended rows only);
  - `lib/game/ground_war_v4.dart` (forces, behaviours, mix table);
  - `lib/game/ground_painter.dart` (the Host atlas, telegraph and special frames);
  - `lib/game/game_events.dart` (events);
  - `plan/style-guide.md` and `plan/asset-pipeline.md` (links and the family table).
- **Unchanged:** the threat front (`GroundFront` rules and schedule), `ground-forces.png` rows 0–3 and their frame contract, the air war, homing rules, scoring and difficulty.
- **Optional, later:** an art refresh of the four threat vehicles inside their existing cells, and new radio clips for the five events. The radio bank (574 clips) is complete on this branch, so the events first map onto existing generic ground lines.
