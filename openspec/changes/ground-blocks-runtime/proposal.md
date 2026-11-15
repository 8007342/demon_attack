# Proposal: ground blocks in the game runtime

## Why
`ground-forces-rework` produced per-sector ground-block atlases (`assets/images/ground-blocks/`, three per
sector: Fleet, Host, infantry) and their generated metadata (`lib/game/ground_blocks_atlas.dart`): five hull
headings per vehicle in 22.5° steps, independently articulated turrets on per-heading pivots, sparse overlays
(channel fill, lights, damage), arrivals, wrecks, totalled states, pitch and ford frames, infantry action sets.
None of it is drawn yet: the painter still uses `ground-forces.png` and `ground-troops.png`, where every hull
has one heading and demons snap to a mirror image when they cross. Its tasks 7.1–7.2 hand the metadata
contract to "the runtime work"; this is that work.

## What Changes
- **Load the current sector's three block atlases** through the generated placement table (only one sector
  resident; the previous one is evicted on a sector change), and ship `assets/images/ground-blocks/` in
  `pubspec.yaml`.
- **A cast table** maps every game ground unit to a block unit per sector: the sector's threat vehicle
  (Spout-runner, Scrapmason, Kiln Ox, Belfry), skirmish vehicles from the sector's Host roster, the heavy tank
  as the Tympanum, demon squads as Rubbling or Ashlar troops (with a Prior or Knell-bearer leading where the
  sector has one), rocket pairs as Corbel Brutes, convoy vehicles from the sector's Fleet roster, allied squads
  as rifle and rocket troopers. A unit with no cast in the loaded sector draws with the old atlases.
- **`GroundHeading`**, a presentation-only turn tracker per unit (smoothed velocity, rate limit, hysteresis,
  minimum hold, one authored step at a time, mirrored half), drives the hull heading from the unit's travel
  direction; a second tracker drives the articulated layer's angle toward the foe, seated on the per-heading
  pivot, with recoil and the per-angle muzzle as the friendly tracer's origin.
- **States**: move cycles (tracks backward while a convoy vehicle falls back), idle, aim and fire, the threat
  vehicles' telegraph on their V-block special frames with exactly the old timing, hit flash, wreck then
  rubble with authored debris pieces, totalled (thrown track, limp, crew pod), pitch frames on slopes from the
  relief pose, walker bob, infantry walk, idle, aim, fire, hit, fall, rubble, run, and a victory flourish for
  saved squads. Ford, crest hop and unearthing have hooks; nothing in the simulation exposes them yet.
- **Overlays** (`fill1–3`, `lights`, `dmg1–2`, Fleet turret dents) drawn on top of the hull or layer cell they
  belong to, and the level-of-detail rule (overlays except `lights` dropped beyond z 900; turret snapped to
  a0/a2/a4 from z 900; headings h0/h2/h4 and turret following the hull from z 1200). A missing overlay name
  draws nothing.
- **Feature switch** `GroundPainter.useBlocks` (default true) keeps the old atlases as a full fallback path for
  comparison.
- **Contract tests** (the runtime half of `ground-forces-rework` task 7.2): every cell the painter can request
  exists for every cast unit in every sector, tracker determinism and step limits, turret seating on the hull
  for every heading and angle pair.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: ground units drawn from the per-sector block atlases with headings, articulated
  layers, overlays and level of detail.

## Impact
- **New code:** `lib/game/ground_heading.dart` (tracker), `lib/game/ground_blocks_cast.dart` (cast and cell
  selection), `lib/game/ground_blocks_painter.dart` (loading, per-unit state, drawing).
- **Changed:** `lib/game/ground_painter.dart` (delegates bodies to the blocks layer, keeps every effect),
  `lib/game/scene.dart` (sync and reduced motion), `pubspec.yaml`.
- **Tests:** `test/ground_blocks_runtime_test.dart`.
- **Unchanged:** gameplay, simulation state, random streams, the telegraph timing contract, the effects
  (explosions, flames, smoke, tracers, missiles) and the generated metadata.
