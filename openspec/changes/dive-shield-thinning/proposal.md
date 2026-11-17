# Proposal: dive shields that thin, not narrow (S1)

## Why
Operator round 5, S1 (`plan/operator-feedback-2026-11-17.md`), after `playtest-fixes-3`:
- "The shield dives are still segmented instead of one continuous asset, they're zoomin in and out or something
  independently of their shields."
- The shields still wear "from the sides to the middle". They should be "a thick shield always wide enough to cover
  the whole demon" that "just thins out": the same arc, thinner per hit, like the carrier's force field.

## What Changes
- Every diving shield (one-point and two-or-three-point divers, elites, the sentinel's dive shield and the sentinel
  rush's super shield) is ONE arc of constant angular width (124°) about the creature's centre, drawn in the
  creature's own transform (its scale, the wing roll of ordinary divers, the sentinel's bank and its pixel-snapped
  centre). It is sized from the atlas silhouettes, so it covers the widest pose of the body at every zoom.
- Spent points no longer switch segments off from the outside in. The shield keeps its arc and centre line and only
  loses thickness: full when whole, one equal step per spent point, a bright hairline on the last point, then it
  flashes out. Glow and heat cool with it; the last point flickers (under 2 Hz); each hit flashes it white.
- No notches, no per-segment sockets, no flame lick that throbs the thickness, no heading turn, no tip embers.
- The rush shield forms in place (it thickens from a hairline through the rally and lock instead of growing 0.55 → 1
  in size), is the thickest shield, and thins with the rush shield's points. The fixed-size cell arc that read the
  rush shield beside it (`_rushShieldRing`) is removed: the thickness is the readout.

## Impact
- Code: new `lib/game/dive_shield.dart` (geometry and painter); `lib/game/scene.dart` (small hooks: ordinary divers,
  `_sentinel`, `_sentinelBerserk`; the playtest-fixes-3 bow code is removed); `lib/game/insignia_painter.dart`
  (`ShieldFx.hitFlash`).
- Gameplay: unchanged. Shield points, breaker damage and hit tests never depended on the drawn shape (any hit on the
  creature's hitbox spends a point), so the old narrowing did not narrow a hitbox. No calibration number moves.
- Specs: `arcade-presentation`. Supersedes playtest-fixes-3's "Diving shields are one coherent shape" requirement
  and the crimson bow's condensing in its berserk requirement.
- Tests: `test/dive_shield_thinning_test.dart`; the bow-shape group in `test/playtest_fixes_3_test.dart` is retired.
- Review: `art/contact/dive-shield-thinning.png` (before | after) and `art/contact/dive-shield-thinning-dive.gif`.
