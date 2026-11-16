# Proposal: ground forces, allies and homing missiles

## Why
The oblique flyover now shows a living ground plane, but nothing on it matters to play. The user asked for a ground war: demon ground forces approaching on the parallax ground and firing large, dodgeable ground-to-air missiles from close range; allied human units fighting them; and a homing-missile power-up, which is the only way to destroy ground units. The war must arrive very slowly over Krybor, ramp gently to The Hollow, stay out of the carrier level, and keep every difficulty in its calibrated band.

## What Changes
- **Demon ground forces** in sectors 1–4 (none over the carrier). They ride the flyover's own perspective projection: small and fogged at the horizon, growing as they approach, always in the side bands outside the central firing lane. They fire only from the near ground, after a launcher-raise and glow telegraph, with a launch flash.
- **Ground missiles**: large, and growing as they rise and approach, on a fixed path to the player's x sampled at launch. They collide only on reaching the ship's plane, with a hitbox matching their drawn size there. A hit counts like a hostile shot (the shield absorbs it). Player shots pass over ground units and through missiles.
- **Homing missiles**: a new power-up that fires a salvo of three missiles automatically, each after the previous one hits. Ground units come first (the most urgent first); otherwise the highest-ranking air target (open carrier core > sentinel > elite > gold > coral > violet > teal). One missile destroys a ground unit; against air targets it is one heavy hit worth three normal hits.
- **Drops**: a chance per kill while ground units are alive, a pity timer, a fleet airdrop fallback, and a plain kill-count drop over the carrier.
- **Allies**: allied human units (in a cyan/teal friendly colour language) skirmish with some demon units, trading tracers. They never collide with the player or block shots, and they never die: when overwhelmed they are *totalled* and limp off or eject in a pod. Saving one (destroying its attacker) and a "whole fleet intact" level give positive-only score bonuses.
- **Events** go through one no-op-safe dispatcher for the music bridge and the commander comms panel: `groundForceSighted`, `groundForceInRange`, `groundMissileLaunch`, `homingPickup`, `homingLaunch`, `homingHit`, `groundUnitDestroyed`, `allyUnderAttack`, `allySaved`, `allyRetreated` (alias `allyLost`), `fleetIntact`.
- **Presentation**: a ground-forces atlas from a new pipeline; the homing rack, missile, reticle and badge in the ship-weapons atlas; a HOMING HUD row and glyph pylons; two hint cards; four synth SFX.

## Capabilities
### New Capabilities
None (this change extends existing capabilities).
### Modified Capabilities
- `arcade-combat`: ground units, ground missiles, homing missiles with their damage and targeting, and allies.
- `arcade-progression`: the ground-force introduction ramp, the homing drop guarantees and the fleet-intact tally.
- `arcade-presentation`: ground rendering on the flyover camera, telegraphs, HUD, hints, events and SFX.

## Impact
New code lives in `lib/game/ground_war.dart` (a `part` of the model), `game_events.dart`, `ground_painter.dart` and the generated `ground_atlas.dart`. Small marked hooks change `model.dart`, `scene.dart`, `main.dart`, `ship_painter.dart`, the HUD widgets and `web/audio/demon-audio.js`. New assets: `ground-forces.png`, an extra row in `ship-weapons.png`, `tools/ground_forces_assets.py` and `art/families/ground-forces*.json`. No API, score-schema or checkpoint changes; a checkpoint restores an entrance without ground units, as it does for other transient entities.
