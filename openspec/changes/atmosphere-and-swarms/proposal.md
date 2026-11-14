# Proposal: atmosphere and swarm arrivals

## Why
The operator, after the wave-pressure playtest (2026-11-14): "What a delicious fog! … we can add several layers
of fog, covering diverse areas of the game area, including the bottom, fog over the ground, to add to the
distance effect." Also:
- "When enemies are coming and are still at the fog, let's not display their shield and armor effects, it
  breaks the illusion a little." (Done in f050241f; this change stages it properly.)
- "Just like missiles to ground targets take a parabolic trajectory with depth, let's make all waves and
  reinforcements fly in from within the fog, at slightly different speeds; if they all swarm in at the same
  speed and time then they look like a boring blocky animation … research flock and swarm movement, so the
  incoming waves can be seen through multiple layers of fog as they're approaching us."
- "Special sprites for the big sentinel, so we show it one or two waves in advance, as a black large
  silhouette flying in figure of eight from the back; as the previous waves come in the sentinel would increase
  size and fly closer, until flying in with its massive swarms of enemies."
- "Let us play with showing the enemies' shadows as they're coming."
- "One or two layers of very thin fog sliding slowly over large sections of the gameplay area including our
  ship and our enemies, as long as it's thin and moving … the combined effect of fog and the 45-degree angled
  parallax ground."
- "We're going to need not to wing these animations … search for proper online authorities on parallax
  trickery, fog and volumetric effects, distance, colour occlusion, and swarm and flock dynamics. We might
  need a few extra assets for that."

Research: [plan/atmosphere-research.md](../../../plan/atmosphere-research.md) (aerial perspective, fog layers,
parallax and shadows, silhouettes, boids, depth arrivals, swarm aesthetics, figure-eight paths, readability).

## What Changes
1. **A fog stack in depth.** Back to front: sky and horizon band (waves hold here), distant fog banks
   interleaved with the far terrain, ground (height) fog over the lower terrain, the gameplay plane, and one or
   two very thin sky sheets drifting over the whole arena, ship included. Animated with fBm and domain warping
   so it evolves instead of scrolling; one fragment-shader pass where available, tiled noise textures as the
   fallback. Bullets, the player's hitbox and tells are never fogged.
2. **Creatures fly through the layers.** Creatures are drawn between the fog layers their nearness puts them
   between, and one transmittance value per creature drives tint, saturation, contrast and detail reveal
   (silhouette → outline → shields and armour → full colour; eyes punch through). Replaces the double-draw haze.
3. **Swarm arrivals.** Every wave and reinforcement flies in from inside the fog as a flock: 2–4 squadrons per
   wave, each with a leader on a curved path from the horizon; followers steer with arrive-to-slot plus
   separation, alignment and cohesion with their 7 nearest neighbours, plus wander; per-creature speed, launch
   delay and wingbeat phase; a parabolic altitude arc like the ground missiles; a smooth hand-off into the
   formation slot. Seeded and deterministic. Timing, rosters and targetability rules are unchanged.
4. **Shadows lead the arrival.** Incoming creatures cast soft ground shadows (offset by altitude along the sun
   direction, softer and fainter when high, fading through ground fog) that cross the terrain before the bodies
   clear the horizon band.
5. **The sentinel is foreshadowed.** One or two waves before a sentinel arrives, a giant dark silhouette flies a
   figure-eight far behind the fog, nearer and larger each wave, then arrives with its swarm (an insect-style
   swarm bound to it). New silhouette sprites from the studio.
6. **A reduced-atmosphere setting** that also serves as the low-end performance tier.

## Not in this change
- The ground-atmosphere art atlas (`plan/ground-atmosphere.md` on `work/ground-forces-design`) plugs into the
  same layer slots when it is rendered; until then the layers are procedural.
- Voiced, illustrated tips and growlier demon voices: separate work (radio and voice batches).

## Impact
- `lib/game/scene.dart` (draw order, fog layers, tint), `lib/game/perspective.dart` (transmittance),
  `lib/game/model.dart` (arrival flock, sentinel foreshadow state), new `lib/game/flock.dart`,
  `lib/game/atmosphere.dart`, a fog shader under `shaders/`, settings.
- Assets: sentinel silhouette frames (2 species × 8 banking frames × 2 blur levels), 3 pre-blurred shadow
  sprites, optional fog-noise tiles and light-shaft sprites.
- Tests: determinism of flock arrivals, arrival timing parity with today (no balance change), detail-reveal
  stages, never-fogged bullets and player, frame-time budget for the fog pass.
