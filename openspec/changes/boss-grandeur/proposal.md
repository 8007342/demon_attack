# Proposal: the boss level as an event (R4)

## Why
From the operator's second playtest on 2026-11-15 (`plan/operator-feedback-2026-11-15b.md` R4). The approaching
sentinel was "so ominous and impressive" and the final rush "so scary and exciting". The boss, the climax of every
tour, should be an event on that scale. The operator asked for:

**Before the boss**
- One or two ordinary waves open the level while the boss looms in.
- The boss flies in from behind and emerges slowly from under the fog.

**At the front**
- The fight changes dynamically and flies higher.
- The ground falls farther away, with smaller and slower parallax.
- The camera zooms the whole play area out a little, dynamically (and back in), to convey speed, range of motion and
  the ship's size.

**Following the boss**
- It swerves slowly as it changes direction, seen at slightly different angles (e.g. 38°, 45°, 52°) as it glides up
  and down.
- The camera follows it up, down and sideways, shifting the perspective of the ground far below.

**Damage and growth**
- Shields and armour decay visibly; the ship falls apart in stages until it collapses.
- Later runs get larger, scarier, more complex ships.

What the code does today:
- The carrier sector (level 5) starts the fight in its Descent: the flock mills, opens a vacuole, the carrier comes
  down on its retro-burn and the flock pours into its bays (`cinematic-flow` §3.1).
- The carrier then strafes at a fixed `y = 205`, drawn from one frontal view of one of five hull atlases (frigate to
  dreadnought, one per tour).
- Damage is shown by up to three bow overlays and form changes.
- There is no altitude, no zoom, no change of view, and the hull's complexity is baked per class.

## What Changes
- **Boss level structure: Overflight → Loom → Rise → Engage → Climb → Collapse.**
  1. *Overflight* (in the Descent). The boss flies in from behind the camera. Its belly and shadow sweep up the screen
     over the ship (presentation only, no hitbox), shrink toward the horizon, and sink into the far fog with the
     pursued flock streaming after it.
  2. *Loom* (1 wave on tour 1, 2 waves from tour 2). The ordinary waves fight while the boss is a dark mass under the
     fog layers, rising slowly through them, like the sentinel's fade-in. Its lurking shadow (`terrain-shadows`)
     crawls toward the front.
  3. *Rise.* When the last loom wave is cleared, or after a time cap, the boss emerges from under the fog over 4–6 s.
     This keeps the fight-ready rule: no shots, no hitbox until it is fully out.
- **Altitude at the front.** When the boss reaches the front, the fight climbs:
  - a presentation altitude `A` eases 1.0 → 1.45 (to 1.6 on late tours);
  - the ground camera's height scales by `A`, so terrain, ground units, vegetation and shadows become smaller, and
    their parallax slows by 1/A;
  - gameplay lanes and depths are untouched.
- **Dynamic camera zoom.**
  - The play area zooms out to as little as 0.86 and back, driven by the boss's range of motion and its swerves.
  - Pivot at the ship's row centre. Rate ≤ 0.05/s, eased.
  - Strict safety rules: arena-unit hitboxes are unaffected, touch maps through the inverse transform, minimum
    on-screen sizes hold for creatures, bullets and the ship, the HUD and comms are never zoomed, and the zoom is
    static under reduced motion.
- **Camera follow (background only).** The ground and sky pan up to ±24 units sideways and shift the horizon ±20,
  following the boss, so the perspective of the ground far below shifts. The gameplay layer never pans.
- **Swerve and pitch views.**
  - The boss is drawn from a 3 × 3 view set: pitch 38/45/52°, yaw −12/0/+12°.
  - Pitch follows its vertical glide (a bounded `y` oscillation of ±16 units around today's row).
  - Yaw follows its horizontal velocity as it changes direction, with hysteresis and short crossfades.
  - Functional windows (core, bays, turret pivot) stay on the shared simulation geometry in every view.
- **Staged damage and collapse.** Five readable stages derived from existing shield and core state:
  - S0 shielded: hex shield cells go dark one by one;
  - S1 scorched;
  - S2 exposed: plates peel off as falling parts, fires;
  - S3 breaking: modules detach at form changes, the hull lists, smoke trail;
  - S4 collapse: the hull breaks into module wrecks that fall into the fog with their shadows.

  HP, shield and door gameplay are unchanged.
- **Composable boss grammar.**
  - A boss is a spine plus module slots (bow, towers, wing pylons, engine pods, turret blisters, bay pods, sail fins,
    keel, brood sacs) with mounts, symmetry, damage stages, lights, fire points and a detach order.
  - Each tour adds modules and scale: about 5 / 8 / 11 / 14 / 17 modules, extent ×1.0 to ×1.6.
  - Beyond tour 5, a seeded assembly within the same budgets keeps later runs growing.
  - The simulation geometry stays shared, so balance does not move.

## Capabilities
### New Capabilities
(none)

### Modified Capabilities
- `arcade-progression`: ADDED: the boss level opens with loom waves; the boss emerges from the fog.
- `arcade-presentation`: ADDED: overflight, altitude, camera zoom and its safety rules, background follow, view set,
  staged damage and collapse.
- `arcade-combat`: ADDED: boss glide bounds and the composable grammar's gameplay invariants.

## Impact
- **New** (pure Dart where possible):
  - `lib/game/boss_director.dart`: phases, altitude, zoom, follow, view selection;
  - `lib/game/boss_grammar.dart`: module catalogue, tour assembly, seeded assembly;
  - `lib/game/arena_camera.dart`: zoom and follow transforms, inverse touch mapping, safety clamps.
- **Changed:**
  - `lib/game/model.dart`: level-5 wave plan (loom waves), `Carrier` glide (`y` bounded oscillation, own phase),
    boss phase flags;
  - `lib/game/flow_director.dart`: the boss arrival plan becomes Overflight;
  - `lib/game/scene.dart`: arena camera transform, under-fog boss draw slot, view-set boss draw, stage overlays;
  - `lib/game/boss_painter.dart` and `boss_atlas.dart`: view set, module layers and wrecks, consuming the
    `boss-hero-assets` atlases;
  - `lib/game/terrain_field.dart`, `ground_war.dart` and `flyover_background.dart`: `GroundCamera.altitude`;
  - `lib/main.dart`: the input inverse transform;
  - `lib/game/music_director.dart`: phase stingers.
- **Assets** come from `boss-hero-assets` (R5). Until they land, today's single-view atlases are used for every view
  (view selection is a no-op), and the module layers come from today's superstructure, hull and wreck sprites.
- **Tests:**
  - `test/arena_camera_test.dart`: hitbox invariance, touch round-trip, minimum sizes;
  - `test/boss_director_test.dart`: phases, glide bounds, determinism;
  - `test/boss_grammar_test.dart`;
  - boss endurance and calibration stay green (`test/campaign_playtest_test.dart`);
  - review strips `art/contact/boss-grandeur-*.png`.
- **Depends on** `continuous-swarm` (waves), `fog-restoration` (layers), `cinematic-flow` (arrival plan),
  `terrain-shadows` (boss and lurking shadows), `boss-hero-assets` (art).
