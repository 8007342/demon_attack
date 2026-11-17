# Proposal: Player fire rate down, and streams that do not strobe

## Why
From the operator's round 4 (`plan/operator-feedback-2026-11-17.md`, G2 and P1), after a phone playtest of the live
release:
- **G2.** "It's a bit hard to see everything going on in the screen, we might need to decrease our ships firerate
  overall, keep the demons fire rate intact, just decrease ours. It might need a bit of a difficulty readjustment, as
  usual u_u'"
- **P1, stroboscopic bullets.** "Particularly heavy bullet action has weird harmonics with framewrate and made it look
  choppier even when it wasn't … bullet speed and frequency might need some tunning to avoid these false flickering
  effect".

The causes, read from the code, are in `design.md` §1 and §3:
- the base gun fires every 0.23 s, which is 13.8 model steps, so gaps of 13 and 14 steps alternate in a repeating
  pattern;
- the shots climb 6.5 units per step, and the scene rounds positions to whole units, so steps of 6 and 7 alternate;
- most hostile climb speeds hitch once every 2 to 14 frames for the same reason;
- vsync jitter can make the fixed-step accumulator run 0 steps in one frame and 2 in the next.

## What Changes
- **Fire rate, player only** (design §2):
  - base volleys every 18 steps (0.30 s, was 0.23 s): −23 % rate;
  - Rapid every 8 steps (0.133 s, was 0.105 s): −21 %; Rapid/base stays 2.25 : 1 (was 2.19).
  - Spread, Powerful and Large keep their volley shape on the slower cadence.
  - Demon, sentinel and carrier fire rates are unchanged.
- **Anti-strobe tuning in the model** (design §3):
  - whole-step volley intervals;
  - player shots at 480 u/s (8 u per step, was 390) and Spread's pair at 420 (7 u, was 370);
  - hostile climb speeds snapped to a 15 u/s grid (at most 6.5 % per shot);
  - the fixed-step accumulator and the volley timer take whole steps without float drift.
  - The rendering side (vsync snap, interpolation, smear, sprite shimmer) is `work/phone-performance`'s; design §4
    checks that the two fit (its rule of at most one volley per 0.1 s per stream holds).
- **Rebalance** (design §5), so the game is as hard as before or a little easier:
  - the carrier's hatch pools, core shares and hatch HP floor (2, was 3) are re-chosen to keep the carrier-hatches
    time-to-kill targets and Easy below Normal on every tour;
  - a sentinel's hull is 70 % of what it was;
  - route 0 drops a power every 5 kills (was 8), so the opening is no harder;
  - divers' dive shields lose a point (sentinel 3 + route ÷ 2, elite 2, every other creature 1);
  - the loom cap is 120 s (was 90 s), so tour 5's third launch wave still comes;
  - Supply Run's crates fall every 3 s (was 3.5 s): they are its only powers;
  - Stormfront's bolts deal 2 (was 3), so they stop at the lighter dive shields as they used to.
- **Review sheet** `art/contact/fire-rate-tune.png` and the opt-in `test/fire_rate_tune_review_test.dart` (design §6).
- **Tools:** `tools/strobe/strobe.lua` (the aliasing tables) and `tools/ordinary_wave_probe.dart` (the Average
  pilot's lives and clear times per sector).

## Capabilities

### Modified Capabilities
- `arcade-combat`: the player's cadence and shot speeds, the anti-strobe grid, whole fixed steps, and the
  rebalanced sentinel and carrier hit points and dive shields.

## Impact
- `lib/game/model.dart` (`// --- fire-rate-tune` markers): constants, the volley timer, the shot speeds, `_hostile`,
  the accumulator epsilon, dive shields, the sentinel hull, the loom cap.
- `lib/game/difficulty.dart`: `sentinelHull`. `lib/game/model_bonus.dart`: the bonus par uses it.
  `lib/game/carrier_hatches.dart`: `pools`, `coreShares`, `minLayer`.
  `lib/game/bonus/levels/supply_run.dart`: crates every 3 s. `lib/game/bonus/levels/storm_cell.dart`: bolt damage 2.
- `lib/game/shot_layer.dart`: `smearMax` 16 (was 14), one line.
- `lib/game/ship_painter.dart`: one line, the Spread sprite is chosen by `ArcadeModel.spreadShotSpeed` instead of a
  literal −370. No rendering change.
- Pilots that led targets by a literal 390 u/s now use `ArcadeModel.shotSpeed`.
- `test/boss_endurance_test.dart`: the seconds baseline is unchanged and holds; the hits baseline is re-measured,
  because the carrier has fewer hit points (design §5.4).
- Calibration before and after: `plan/calibration-current.md`, "Fire-rate tune".
