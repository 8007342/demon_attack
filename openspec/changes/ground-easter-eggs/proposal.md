# Proposal: ground war easter eggs

## Why
The operator asked for small, rare moments of life on the ground: "little dances after a victory, little tanks
exploding into pieces, trees coming down releasing flocks of other flying creatures that just fly off, or
swarms of other ground creatures running away from ground troop activity." The design is
[plan/ground-easter-eggs.md](../../../plan/ground-easter-eggs.md); the assets exist (`ground-wildlife.png`
flock flyers and critter leaps, ground-forces-rework §16; the infantry `flourish`, `arrive` and `run` frames
and the Host debris sheets, ground-blocks-runtime). What is missing is the runtime: one budget that decides
when an egg may run, and the eggs themselves. Today the only one is a hard-coded flourish for every third
saved squad (`ground_blocks_painter.dart`), and fleeing critters crouch-leap only when a blast lands.

## What Changes
- **`EasterEggBudget`** (`lib/game/easter_eggs.dart`): the one place that grants eggs. Rarity rolls are a pure
  function of the run seed (`ArcadeModel.seed`, now stored), the egg and a key; cooldowns run on the budget's
  own clock; at most one egg per side band and two on screen; quiet during a ground telegraph or missile, a
  boss fight, the last life, just after the player is hit (life loss or post-hit protection), the arrival
  hint, and a dense fight (six hostile shots or three diving demons); nothing under reduced motion. Operator
  defaults adopted: 1 in 3 dances (cooldown 40 s), 1 in 8 jackpots (20 s), 2 in 5 tree flocks (12 s), 1 in 4
  Host jigs (60 s), critter scatters cooldown 8 s per band.
- **Victory dance**: the existing saved-squad flourish now asks the budget (and also plays after a skirmish
  the squad fought is won), 4 frames at 0.12 s rippling through the squad; never with a Host unit within 200
  texels or a totalled ally within 100. Convoy vehicles with a turret do the no-new-art flourish (a0 → a4 →
  a0 twirl and a one-texel hop). Every Fleet squad and vehicle on screen dances once at sector clear.
- **Host jig**: a Host squad whose foe falls back plays its `flourish` frames as a taunt jig.
- **Breakup and jackpot**: light Host vehicles break into 5–8 authored pieces, heavier Host units 3–4; at most
  16 pieces on screen; pieces thrown from outside the lane land short of it; reduced motion shows the plain
  wreck. One in eight light-vehicle breakups is the jackpot: the turret (or head piece) pops high, spins in
  quarter turns, bounces once and lands upright, and a crew of two Rubblings climbs out, looks at it and
  scampers off outward.
- **Tree flocks**: when a tree or stalk is pushed over, 5–9 flyers of the sector's species burst from the
  crown as it passes its second break frame, flap at 10–14 fps, climb, then fly outward and toward the horizon,
  shrinking and fading into the fog; never into the lane below y 300, gone above y 200 and within 2.5 s.
- **Critter scatter**: up to 8 flyover critters within 50 texels of a ground unit scatter toward the outer
  edge (one group per band, cooldown 8 s per band, two at most), crouch-leaping with a tiny dust puff per
  landing; half of them burrow after 1–1.5 s.
- **Deferred** (hook or note, no assets or no source event): shell-felled trees, Ringfall flocks (no
  fallable tree in Ringfall), placed critter groups by terrain feature, warm seams cooling on stone pieces, the
  captured Krybor hull's human plate, dance variants by squad index.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: rare presentation-only easter eggs on the ground under one budget.

## Impact
- **New code:** `lib/game/easter_eggs.dart`.
- **Changed:** `lib/game/flyover_background.dart` (owns the budget; flocks, critter scatter),
  `lib/game/ground_painter.dart` (dance and jig triggers, breakup caps, jackpot), `lib/game/ground_blocks_painter.dart`
  (flourish timing, jig, turret twirl, jackpot drawing), `lib/game/model.dart` (stores the run seed),
  `lib/game/scene.dart` (one line: the painter shares the flyover's budget).
- **Tests:** `test/ground_easter_eggs_test.dart`.
- **Unchanged:** gameplay, scoring, simulation state and random streams; the radio and music (no egg emits an
  event); the telegraph contract.
