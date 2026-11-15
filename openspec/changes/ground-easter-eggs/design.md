# Design: ground war easter eggs

Contract: [plan/ground-easter-eggs.md](../../../plan/ground-easter-eggs.md) (sections below refer to it);
assets: `lib/game/ground_wildlife_atlas.dart`, `lib/game/ground_blocks_atlas.dart` (ground-forces-rework §14,
§16); runtime: [ground-blocks-runtime](../ground-blocks-runtime/design.md).

## 1. Presentation only (§1 rule 1)
Every egg reads `ArcadeModel` and writes nothing back. No decision draws from `model.random`, a skirmish rng
or any simulation stream: the budget hashes (run seed, egg, key) with the same Park–Miller steps the flyover
uses, and keys come from unit ids. No egg adds a game event, so the radio, the music and the comms director
never react to one. Vegetation `hitAt` is not touched by eggs (a shell-felled tree would change which plants
the convoy later reports to the radio, so it is deferred).

## 2. The budget (`EasterEggBudget`, §1)
- **Owner.** The flyover owns it (`FlyoverBackground.eggs`) because it advances every unpaused frame with the
  model (`update(dt, model)`: clock, suppression, expiry) and knows reduced motion. The scene hands the same
  instance to the ground painter (`GroundPainter.eggs`, one line in `scene.dart`). A painter without a budget
  keeps the pre-egg behaviour (every third saved squad dances), so tools and old tests are unchanged.
- **Grant.** `request(egg, key, band)`: refused when disabled, under reduced motion, while `quiet`, when the
  roll `roll(egg, key)·den ≥ num`, within the egg's cooldown (global, or per band for critters), or when the
  band already runs one egg or the screen two. A grant records the start and the running time (rule 6:
  ≤ 2.5 s, 3 s for the sector-clear dance). `guaranteed` (sector clear) skips everything but reduced motion
  and the switch. `decide(owner, …)` memoises the first answer per simulation object (an `Expando`), for
  questions a painter asks every frame (the jackpot).
- **Quiet** (`quietReason`, rule 4): `boss`; `telegraph` (a ground telegraph or a ground missile);
  `last life`; `player hit` (life loss, or the post-hit protection while in combat); `arrival hint` (the
  transition card); `dense fight` (≥ 6 hostile shots or ≥ 3 demons diving or telling a dive).
- **Rules** (operator defaults): dance 1/3, 40 s global; jig 1/4, 60 s; jackpot 1/8, 20 s; flock 2/5, 12 s;
  critters always, 8 s per band. Caps: flock ≤ 9, critter group ≤ 8, debris ≤ 8 per breakup and ≤ 16 on
  screen. Eggs other than flocks only at z < 900 (rule 8).

## 3. Dances and jigs (§2)
`GroundBlockTrack` carries `flourish`/`flourishLen`, the last engaged foe and whether the sector-clear dance
has played; `observe` advances the flourish once per paint. Triggers (`GroundPainter`):
- saved squad (the existing hook, now through the budget) and won skirmish (the squad's or vehicle's last
  attacker is destroyed by the allies) → `dance`, if no live Host unit is within 200 texels and no totalled
  ally within 100 (ground distance: lateral texels and depth);
- `RunMode.levelClear` → `sectorDance` for every Fleet squad and turreted vehicle on screen, 3 s;
- a Host squad's last foe falls back (`allyFallingBack`) → `jig`, 1 s.
Troopers play `flourish` frame `⌊t / 0.12⌋ + k` (4 frames, each trooper one frame behind the last) only while
standing and not engaged; convoy turrets sweep a0 → a4 → a0 at 0.08 s a step, the hull hopping one texel on
beat 3 (0.36–0.48 s).

## 4. Breakup and jackpot (§3)
In `_wreck` (blocks path, with a budget): light Host vehicles (`unitClass == light`) throw 5–8 pieces, the
rest 3–4 (seeded by id); a running count stops at 16 on screen; a piece thrown from a unit outside the lane is
clamped short of the lane edge below y 300; reduced motion draws the plain wreck for light vehicles. The
jackpot is decided once, in the first 0.2 s of the wreck at z < 900. Its head is the layer at its middle
angle, else the first of `turret, gun, head, hood, heads` in the unit's pieces (Crocket: `gun`), which then
does not also fly as debris. Arc: launch 72 texels/s at 0.12 s, gravity 150, one bounce at 40 % restitution,
drifting outward 10 texels/s; quarter turns at 10 steps/s while flying, upright when landed; fades out by
2.6 s. Crew: two Rubblings (`crewUnit`: the sector's Rubbling, else its rifle cast) from 1.1 s and 1.25 s:
`arrive` f0–f2 (0.45 s), `idle` facing the turret (0.35 s), then `run` outward.

## 5. Tree flocks (§4)
`_pushVegetation` contact: a `tree` or `stalk` whose crown is below y 230 asks for a `flock` keyed by the
plant id. `spawnFlock` makes 5–9 `EggFlyer`s (sector species row of `ground-wildlife.png`, heading up-left on
the left band, up-right on the right), leaving the crown from the second break frame (0.4 s) over 0.3 s.
Motion: initial climb 52–82 px/s easing to 16 px/s, outward 14–40 px/s growing 30 %/s (the flock loosens),
scale 0.26–0.56 × depth shrinking 30 %/s, a virtual depth growing for the fog tint. Clamped out of the lane
below y 300, removed above y 200, off screen or after 2.5 s; opacity fades over the last 0.7 s and over the
40 px above the ceiling. Drawn in one `drawAtlas` after the critters, flap A/B at 10–14 fps per flyer.

## 6. Critter scatter (§5)
`_react` first runs `_scatterFromTroops`: for each ground unit (demon or ally) nearer than z 900, the first
critter within 50 texels not already reacting asks for `critters` in its band. A grant sends up to 8 critters
of that band within 70 texels into the existing flee (outward, `egg` flag), with a burrow after 1–1.5 s for
half of them (by id); burrowing species burrow at once. Each leap landing adds one dust particle (vegetation
particle kind 0). Blast-triggered fleeing is unchanged.

## 7. Verification
Budget determinism, rarities, caps and cooldowns; each suppression reason; reduced motion; flock bounds
(lane, ceiling, 2.5 s, determinism); asset presence for every cell an egg draws in every sector; simulation
parity with eggs on (every roll granted) and off over two sectors; a review frame with a live flock
(`.cache/ground-blocks-review/l1-eggs-flock-*.png`).

## Deferred
Shell-felled trees (would change radio reports, §1); Ringfall flocks (its plants are crystals and scrap);
critter groups placed by terrain feature (the existing critters serve as the group); warm seams cooling on
stone pieces and the captured Krybor hull's human plate (no seam masks or plate cell yet); dance variants by
squad index (one `flourish` set per block); "no dance within 1.5 s of a shot landing nearby" beyond the
Host-proximity rule; quieting eggs on dense radio traffic (no comms-director hook is read).
