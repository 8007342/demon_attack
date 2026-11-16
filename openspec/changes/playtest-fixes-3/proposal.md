# Proposal: playtest fixes, round 3 (F1)

## Why
From the operator's playtest on 2026-11-16 (`plan/operator-feedback-2026-11-16.md`, F1), after the alien carrier
landed in `game`:
- Diving shields render broken: their parts do not scale together and leave gaps.
- The sentinel's final rush: it should be invulnerable during its berserk transformation, then gain a super-powerful
  diving shield that powerups can defeat while dodging stays the better choice; final rushes should come a bit more
  often.
- The sentinel's lurking shadow is big, but once the sentinel comes to the front its shadow disappears or shrinks.
- The playfield sits on the pilot dock to leave room for toasts; with no toast the band above it is empty.
- The fly-up transition reads as flying sideways.

## What Changes
- **Diving shields** are drawn as one crescent per shield (shared leading edge, thickness profile and flame lick for
  every colour band, thin notches between segments, spent segments kept as ember outlines), turned toward the dive.
  The rush's crimson bow uses the same shape.
- **Sentinel rush:** invulnerable through the rally and lock (deflect sparks, no hit flash); the rush shield becomes a
  super-powerful diving shield (base gun deflects, offensive powers and homing break it; 6 / 8 + cycle÷2 /
  10 + cycle÷2 points); each dodged pass pays 300 × (cycle + 1), a break 150 × (cycle + 1), and a sentinel that burns
  out after a dodged last pass pays its kill value; rush chance 0.28 / 0.45 / 0.50.
- **Sentinel shadow:** one occluder-style shadow, sized by one rule from lurk to rush; the in-play sentinel, which
  published no altitude, now always casts.
- **Band above the arena:** the sky (baked with headroom), sector parallax, high fog and cloud cover reach the top of
  the viewport; gameplay stays clipped to the arena.
- **Ascent:** no world bank in the sector change, the pitch starts with the climb, the uncovered band is deep sky, and
  the pursued flock climbs ahead of the ship instead of streaming sideways.

## Impact
- Code: `lib/game/scene.dart`, `sentinel_rush.dart`, `model.dart`, `difficulty.dart`, `atmosphere.dart`,
  `sector_background.dart`, `flyover_background.dart`, `flow_director.dart`, `model_flow.dart`.
- Specs: `arcade-combat` (rush rules), `arcade-presentation` (shields, shadow, band, ascent).
- Supersedes numbers in `demon-intelligence` (rush chance, rush shield) and refines `terrain-shadows` §4 (hand-off)
  and `transition-ascent` §1–§2 (roll, pitch timing).
- Review sheets: `art/contact/playtest-fixes-3-*.png`.
