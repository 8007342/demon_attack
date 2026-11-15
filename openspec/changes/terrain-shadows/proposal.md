# Proposal: terrain-conforming shadows and the sentinel's lurking shadow (R2)

## Why
From the operator's second playtest on 2026-11-15 (`plan/operator-feedback-2026-11-15b.md` R2):
- "The big sentinel shows a slow lurking shadow on the ground as it approaches the front lines."
- "This lifts all shadow projection, for the sentinel, creatures, ship and boss: shadows follow the terrain relief and
  deformation instead of a flat plane."

The swarm shadows from `continuous-swarm` §8 were praised ("terrific"). Today every shadow still lands on a flat plane:
- `_shadowOf` places it at `Perspective.groundY(nearness)`.
- The relief that `TerrainView` draws (ridges, valleys, mesas, crater walls) and the blend between sector fields during
  travel do not touch the shadows. A shadow slides straight across a ridge, and floats over a valley floor.
- The foreshadowed sentinel casts only a faint (alpha ≤ 0.2) shadow while it circles in the fog. It has no shadow while
  it is on its way to the front.
- The boss casts none.

## What Changes
- **One shadow projector for every caster** (creatures, divers, sentinels, the ship, the boss). Each caster has a world
  position and an altitude. Its shadow is the point where the sun ray from the caster meets the terrain surface,
  found by a short fixed-point march against `TerrainView` heights. On flat ground the result equals today's shadow,
  so nothing that already reads well changes.
- **Shadows drape over the relief.** Each silhouette is drawn as a small warped mesh (3 × 2 cells) whose vertices sit
  on the visible terrain surface:
  - it stretches on slopes facing away from the sun and shortens on slopes facing it;
  - it clips behind a nearer crest, as units already do;
  - it follows the sector-to-sector morph during travel, because it samples the same blended field every frame.
- **The sentinel's lurking shadow.** From the first foreshadow until the sentinel takes its place in the fight:
  - a broad, very soft shadow (about 2.5 × the sentinel's own) creeps along the ground from the far terrain toward the
    ground-war front at walking pace, meandering;
  - it grows darker as the sentinel nears, drawn as an occluder of the ground's light (a desaturating, cool multiply that
    also dims the fog banks above it), so it reads clearly on the darkest grounds without becoming a black blob;
  - ground units it passes over hesitate, using the existing duck reaction;
  - when the sentinel rises out of the fog, the lurking shadow contracts into its normal combat shadow, so there is
    never a second shadow and never a pop.
- **The boss casts a shadow.** It is large, soft and low, and it uses the same projector. `boss-grandeur` reads its
  altitude to make the shadow shrink and fade as the fight climbs.
- **Budgets are unchanged:**
  - at most three blur layers per frame;
  - the reduced atmosphere tier, and devices that cannot keep the frame budget, fall back to today's flat placement
    with one sharp layer;
  - gameplay is untouched: shadows remain presentation only.

## Capabilities
### New Capabilities
(none)

### Modified Capabilities
- `arcade-presentation`: ADDED requirements for terrain-conforming shadow projection, the sentinel's lurking shadow,
  the boss shadow and the shadow fallback tier.

## Impact
- **Changed:**
  - `lib/game/scene.dart`: `_shadowOf` and `_creatureShadows` become a caster list fed to a new projector, with
    per-image `drawVertices` batches inside the existing blur buckets;
  - `lib/game/terrain_field.dart`: a `TerrainView.shadowPoint` and `surfaceAt` reuse, with no new fields;
  - `lib/game/model.dart`: `SentinelForeshadow` gains a lurk track, presentation only, with its own PRNG stream;
  - `lib/game/flyover_background.dart`: the ship-shadow hand-off, and the duck reaction keyed on the lurking shadow.
- **New:** `lib/game/shadow_projector.dart` (pure Dart, testable without a canvas).
- **Tests:**
  - `test/shadow_projector_test.dart`: flat-ground equivalence, slope stretch, crest clipping, morph continuity;
  - `test/terrain_shadows_review_test.dart`: review strips in `art/contact/terrain-shadows-*.png`;
  - the existing shadow-layer-count and performance tests stay green.
- **Depends on** `continuous-swarm` §8 (shadow pass) and `ground-terrain-interaction` (`TerrainView`). It feeds
  `boss-grandeur` (the boss altitude reads the boss shadow).
