# Proposal

## Why

The ship asset pipeline now produces enough good FLUX (I2/I3) candidates that review itself is the bottleneck. The gallery shows every candidate from every tier with equal weight, has no memory of what a person has already accepted, and previews each module on a bare hull instead of the ship being assembled. Small-model (I0/I1) candidates are no longer competitive and clutter the choice. The wing cannons also need a gameplay reason to look like two independent guns: single-shot fire should alternate between them, with a small recoil per shot.

## What Changes

- Give the review page its own capability: per-family progression (accepted / total parts), accepted parts collapsed with their choice and reviewer, a remembered "hide accepted parts" switch, and QA-status and model-tier filters.
- Preview every candidate on the **selected ship**: the accepted hull plus one accepted module per other slot group, with the candidate swapped into its own slot.
- Add `retire --tiers` to drop a tier's raws and candidates from the pipeline (they remain in Git history); refuse to retire a tier that an accepted part comes from.
- Add `plan --round N` so further alternative rounds never reuse seeds, per-part generation sizes (portrait canvases for tall modules), and an orientation step that turns elongated modules upright with the muzzle on top.
- Pack records each wing module's muzzle point in `ship-parts.json`.
- Gameplay: with no powerups the ship is a single shooter firing from the nose, with a nose flash. While a wing powerup (rapid or powerful) is active, wing cannons are fitted and take every primary shot, alternating left and right, and the cannon that fired recoils with a muzzle flash. Spread still adds its angled pair from the nose, and large still enlarges the primary shot.
- Review shows the selected ship as single shooter and wing shooter, and previews nose candidates on both. Acceptances can be withdrawn (kept in history) and rejected prompt rounds removed by seed.

## Capabilities

### New Capabilities
- `asset-pipeline-review`: progression, selected-ship previews, tier retirement and alternative rounds for the local asset review surface.

### Modified Capabilities
- `arcade-combat`: single shooter versus wing-cannon fire, with alternating wing shots and per-side recoil.

## Impact

- `tools/asset_pipeline/pipeline.py`, `tools/asset_pipeline/review.html`, `tools/asset_pipeline/families/ship.json`.
- `lib/game/model.dart` (shot origin and recoil state), `lib/game/scene.dart` (per-side wing drawing, muzzle metadata), new `test/wing_cannons_test.dart`.
- No change to fire rate, damage, shot speed or steering sling: only the origin of single shots moves to the wing muzzles.
