# Proposal: ground war v4 — far more war, same threat

## Why
The operator: "The ground effects for the battle on the ground are fantastic, but they're very rare, they need to happen more often, particularly the terrain needs to be far coarser, and the ground troops could be mixed tanks and foot soldiers for more levels, and all of them advancing through the entire screen, not just a vertical line up and down from where they started. Ground enemies might need some new assets as well."

Decided with the operator: **same threat**. Ground fighting becomes much more frequent and visible, but the allies still stop enemies early. Breakthroughs that fire at the player stay a later-level danger, exactly as now.

## What Changes
- **A skirmish layer** (`lib/game/ground_war_v4.dart`) sits on top of the unchanged threat front. Mixed demon forces push in from the horizon in arrival groups, with ebb and flow: a 34 s surge-and-lull tide sets the live cap and the arrival interval. The convoy meets them. Skirmish units hold short of fire range and never fire at the player. They never move the pressure meter or allied strength, and they are not homing targets. A skirmish never totals an ally: a battered ally falls back to its escort slot and repairs. The layer has its own seeded random stream, so the threat front and the air war replay exactly as before. A deterministic before/after simulation proves it.
- **Mixed forces by level, on both sides.** Krybor brings grunts with the sector vehicles. Ringfall adds rocket troopers. Ember and the Hollow add the demon heavy tank. The carrier sector gets a light ground battle of its own. The convoy mixes vehicles with rifle and rocket squads.
- **Full-width manoeuvre.** Skirmish units steer laterally across the whole ground plane; threat units weave inside their side band (their missiles leave from where they always did). It routes along valley floors and around hills, spreads out from its neighbours and flanks its foe. The convoy's escort slots follow the ship. Engaged allies close on their foe, then fall back. Positional and visual only: the rules read depth.
- **Coarser terrain.** Features come one per 520 texels (was 300) at about 2.2× the height and twice the footprint. Rolling hills have long wavelengths. The lane keeps 62% of the relief, with no centre seam, because units cross it now. Shading is stronger, and an additive slope-and-crest light makes the relief read on the darkest grounds.
- **New art.** `assets/images/ground-troops.png`: demon grunts, rocket brutes, a heavy tank, and allied rifle and rocket troopers. The Go pipeline is `tools/ground_troops`, with SDXL + pixel-art-xl + LayerDiffuse keyframe textures.
- **Presentation.** A plant in front of a unit stays in front (depth sort). Allies draw 1.3× larger, with a cyan IFF chevron. New weapon tracers: small arms, arcing rockets and tank shells.
- **Radio.** Six new events in a `// --- ground war v4` block: `groundSkirmish`, `infantryEngaged`, `skirmishWon`, `allyFallingBack`, `heavyArmorSighted` and `groundTide`, rate-limited in the model.

## Capabilities
### Modified Capabilities
- `arcade-combat`: the skirmish layer, fall-back and repair, homing priority.
- `arcade-presentation`: coarse relief and crest light, mixed-force art, full-width manoeuvre, plant depth sort, ally readability, new events.

## Impact
New files: `lib/game/ground_war_v4.dart`, `lib/game/ground_troops_atlas.dart`, `tools/ground_troops/`, `art/families/ground-troops*.json`, `assets/images/ground-troops.png` and tests. Localized hooks are marked `// --- ground war v4` in `ground_war.dart`, `ground_painter.dart`, `terrain_field.dart`, `flyover_background.dart` and `game_events.dart`, plus one part directive in `model.dart` and two lines in `scene.dart`.
