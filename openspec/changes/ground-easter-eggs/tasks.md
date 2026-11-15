# Tasks

Prerequisites: `ground-blocks-runtime` (blocks drawn, flourish frames, debris pieces), ground-forces-rework
task 6.3 (`ground-wildlife.png`, §16).

## 1. Budget
- [x] 1.1 `EasterEggBudget` (`lib/game/easter_eggs.dart`): seeded rolls from the run seed (`ArcadeModel.seed`
      stored), rules (rarity, cooldown, per-band, duration), one per band and two on screen, `decide` memo,
      debris counts, master switch, reduced motion
- [x] 1.2 Suppression: telegraph or ground missile, boss, last life, player hit, arrival hint, dense fight
- [x] 1.3 Owned by the flyover (updated in `advance`), shared with the ground painter (one line in
      `scene.dart`); a painter without a budget keeps the old behaviour

## 2. Eggs
- [x] 2.1 Victory dance through the budget on save and on a won skirmish, Host-proximity and smoking-ally
      gates, 0.12 s rippled frames; sector-clear dance for every squad and turreted vehicle on screen
- [x] 2.2 Convoy turret twirl a0 → a4 → a0 with a one-texel hop
- [x] 2.3 Host jig on `allyFallingBack`
- [x] 2.4 Breakup: 5–8 / 3–4 pieces, 16 on screen, lane clip, plain wreck under reduced motion
- [x] 2.5 Jackpot: turret or head pop, quarter-turn spin, one bounce, upright landing; Rubbling crew of two
- [x] 2.6 Tree flocks from falling trees and stalks (5–9 flyers, 10–14 fps, outward, fog fade, lane and
      ceiling bounds, 2.5 s)
- [x] 2.7 Critter scatter from ground units (≤ 8, per-band cooldown, outward, half burrow, dust per leap)

## 3. Verification
- [x] 3.1 `test/ground_easter_eggs_test.dart`: determinism, rarities, caps and cooldowns, suppression, reduced
      motion, flock bounds and determinism, jackpot arc, asset presence in every sector, simulation parity
      eggs on/off, budget wiring
- [x] 3.2 Review frame with a live flock (`.cache/ground-blocks-review/l1-eggs-flock-*.png`)
- [x] 3.3 `flutter analyze`, `flutter test`

## 4. Deferred (not in this change)
- [ ] 4.1 Shell-felled trees releasing flocks (needs a vegetation path that does not change radio reports)
- [ ] 4.2 Ringfall flocks (no tree or stalk in Ringfall; dust kites are ready in the atlas)
- [ ] 4.3 Critter groups placed by terrain feature (1 in 3 features near the action)
- [ ] 4.4 Warm seams cooling on stone pieces; the captured Krybor hull's human plate
- [ ] 4.5 Dance variants by squad index (fist pump, hop, shuffle, rifle overhead): one flourish set per block
- [ ] 4.6 "No dance within 1.5 s of a shot landing nearby"; quiet on dense radio traffic (comms director)
- [ ] 4.7 Phone-size review clip per egg with the swarm and hostile shots on screen (plan §7)
