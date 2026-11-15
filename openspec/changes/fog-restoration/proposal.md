# Proposal: fog restoration

## Why
Operator playtest 2026-11-15 (plan/operator-feedback-2026-11-15.md, W2): an earlier fog was much better. The
current fog is dragged by the ship (the controller moves the fog with it), it is again a narrow band in the
middle of the screen, and the sentinel's slow fade-in through the cloud is gone (play felt simpler). The fog
must be a pervasive element: several soft layers that add up over the whole depth of the field, covering
several elements, with incoming waves rising slowly up through the layers beneath them; the late, hovering
sentinel silhouette ("fantastic, keep it") needs those composed layers for its effect. The archaeology in
`design.md` §1 traces each regression to a commit.

## What Changes
- **World-anchored fog.** No fog layer, ground-atmosphere band, cloud shadow or the sentinel's silhouette path
  reads the ship's position or the controls any more. Layers move only with their wind; the ground fog scrolls
  with the terrain (the flyover camera, which does not follow the ship). The atlas' generated `parallax`
  numbers are not used at runtime.
- **The soft layers are back, and deeper.** Installing the ground-atmosphere atlas no longer removes the fBm
  horizon band and far banks: the art's mist banks, horizon fog, cloud shadows and dust veil stay in the
  ground depth sort, its low cloud deck lies (thinner) under the soft horizon band. Two new air layers, an
  upper veil (n .5) and a mid veil (n .565), extend the fog from the top of the field down to the near
  ground; the horizon band and far banks get wider profiles and a little more density; ground fog starts at
  the horizon. Five air layers are now interleaved with the creatures by nearness, so an arrival crosses
  four of them on its way to its slot.
- **Sentinel fade-in through the cloud.** The silhouette is drawn after the horizon band and behind the far
  banks and both veils (three or more soft layers drift across it at their own winds), fades in over 3 s
  instead of 1.5 s, and the sentinel itself flies in from that spot through every layer. Silhouette sheet,
  figure-eight path, growth per wave and the crossfade are unchanged.
- **Near lane kept readable.** Layers that reach the lane (mid veil, ground fog) are thinned over it with a
  soft mask; the combined peak opacity there stays at or under the lane cap (0.3), the sky sheets keep their
  12 % cap over the ship.
- **Softer billows.** The fog shader's wisp cut is wider, so warped billows no longer show hard edges.
- **Kept:** reduced atmosphere (horizon band and ground fog, art's reduced bands), reduced motion (static
  layers), the frame-time guard, the shader/tile split, unit depth tint, battlefield smoke, flock draw order,
  silhouette sheet. Gameplay unchanged (no simulation state reads the fog; the silhouette's position only
  seeds the entering sentinel's untargetable path, which still ends at its slot).

## Capabilities
### Modified Capabilities
- `arcade-combat`: the layered atmosphere is world-anchored and pervasive; the sentinel fades in through it.

## Impact
- **Changed:** `lib/game/atmosphere.dart` (layers, world anchoring, lane clearing, art composition),
  `lib/game/ground_atmosphere.dart` (no ship parallax), `lib/game/scene.dart` (five depth slots, no ship
  input to the fog), `lib/game/model.dart` (`SentinelForeshadow.place()` without the ship, slower fade-in),
  `shaders/fog.frag` (softer cut).
- **Tests:** `test/fog_restoration_test.dart` (new), `test/fog_restoration_review_test.dart` (review frames
  and `art/contact/fog-restoration.png`), `test/ground_atmosphere_test.dart` and
  `test/atmosphere_swarms_test.dart` updated for the world-anchored, additive art.
- **Not touched:** creature paths and wave arrival (`flock.dart`), ground unit painters, HUD.
