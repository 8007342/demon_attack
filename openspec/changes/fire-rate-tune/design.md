# Design: fire-rate-tune

## Inputs and citations
- Operator, round 4, 2026-11-17: `plan/operator-feedback-2026-11-17.md`, G2 and P1 (quoted in `proposal.md`).
- `plan/difficulty-calibration.md` (the formulas and the Powers table) and `plan/calibration-current.md` (the gates).
- Read sources (fetched from the forge on 2026-11-17):
  - [source: MDN, "Anatomy of a video game", https://developer.mozilla.org/en-US/docs/Games/Anatomy, read 2026-11-17]:
    "update the simulation at a constant frequency and then draw as much (or as little) of the actual frames as
    possible"; the draw step "can predict a plausible frame" between updates, and "the mandatory interpolation has a
    performance penalty".
  - [source: MDN, "Window: requestAnimationFrame() method",
    https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame, read 2026-11-17]: the callback
    rate "will generally match the display refresh rate … 60hz … though 75hz, 120hz, and 144hz are also widely used".
  - [source: Flutter, "Flutter performance profiling", https://docs.flutter.dev/perf/ui-performance, read
    2026-11-17]: "Flutter aims to provide 60 frames per second (fps) performance, or 120 fps on devices that support
    it"; a dropped frame is "a visible stutter".
  - [source: Flame engine, `packages/flame/lib/src/game/game_loop.dart`,
    https://raw.githubusercontent.com/flame-engine/flame/main/packages/flame/lib/src/game/game_loop.dart, read
    2026-11-17]: each tick passes the measured time between two ticker timestamps as `dt`, with no fixed step and no
    interpolation. The fixed step is ours (`ArcadeModel.update`).
- Seen only as search snippets (Wikipedia, michaelbach.de, MIT, Medium, PubMed Central and Frontiers reset the
  connection from the forge on 2026-11-17; nothing was routed around the proxy):
  - [source: Wikipedia, "Stroboscopic effect", https://en.wikipedia.org/wiki/Stroboscopic_effect, unread: snippet
    only]: the wagon-wheel effect is temporal aliasing of a cyclic motion sampled near its period.
  - [source: M. Bach, "Wagon-wheel effect", https://michaelbach.de/ot/mot-wagonWheel/, unread: snippet only]: the
    visual system matches each spoke to its nearest neighbour in the next frame.
  - [source: T. Glaiel, "How to make your game run at 60fps",
    https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75, unread: snippet only]: snap the
    measured frame time to 1/120, 1/60, 1/30 within a small tolerance.
  - [source: Frontiers in Neuroscience 2023, "SSVEP temporal sensitivity",
    https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2023.1180829/full, unread: snippet
    only], and van den Berg et al. 2011 (seen through the same search): temporal sensitivity peaks around 5–20 Hz,
    depending on luminance and field size.
- The perceptual claims that rest only on these snippets are marked `[UNSOURCED: plan/provenance-audit.md#fr-…]`
  where they are used. The maths in §3 is derived here and checked by `tools/strobe/strobe.lua`.

## 0. What stays, and what is deliberately changed
- **Stays:** every demon, sentinel, carrier and ground fire *rate* (`_enemyFire`, `attackLeft`, `volleyLeft`, the fan
  rate, ground cooldowns); the swarm's counts, rosters, reinforcement groups and ordinary HP (so the 318-wave defence
  budgets are unchanged, apart from the sentinel hull, §5.3); the powers' damage, radii and timers; mutual exclusions.
- **Changed on purpose:** the player's cadence and shot speeds (§2, §3); hostile *climb speeds* by at most 6.5 % per
  shot (§3.2); the carrier's hatch and core HP, the sentinel's hull, dive shields and the loom cap (§5); Supply Run's
  crate interval and Stormfront's bolt damage (§5.4).

## 1. What the operator saw, and why (read from the code)
- `model.dart` fired with `_fire += (rapid ? .105 : .23)`, decremented by the fixed 1/60 s step. 0.23 s is 13.8 steps,
  so the gaps between volleys ran 13, 14, 14, 14, 14, … steps: one short gap in five, a spacing that pulses about
  0.9 times a second. Rapid's 6.3 steps gave 6, 6, 6, 7, … (three long gaps in ten).
- Player shots climbed at 390 u/s: 6.5 units per step. `ShipPainter.paintShot` rounds every projectile to whole
  logical units, so a shot alternated 6- and 7-unit steps at 60 fps (a 30 Hz shimmer); Spread's 370 u/s (6.17 u/step)
  hitched once every six frames (10 Hz).
- Hostile climbs are `base × (1 + 0.04 r) × hostileRate`: 102–292 u/s, 1.7–4.9 u per step. Rounded, most of them take
  one short or long step every 2–14 frames: 178 of the 240 (kind, difficulty, route) × (60, 30 fps) combinations
  hitch between 0 and 15 Hz (`lua tools/strobe/strobe.lua --before`), the band where flicker is most visible
  [UNSOURCED: plan/provenance-audit.md#fr-temporal-sensitivity].
- `update(dt)` adds the measured `dt` (Flame passes the ticker delta) to an accumulator and runs whole 1/60 s steps.
  Vsync jitter puts the accumulator near the step boundary, so one frame runs 0 steps and the next 2: every shot
  stands still for a frame, then jumps twice as far. Nothing interpolates between steps.
- Readability: at 0.23 s and 390 u/s a base stream holds 5.3 shots between the muzzle and the top (474 units), Rapid
  11.6, and Spread 16.4.

## 2. The player's fire rate
| Gun | Interval before | After | Rate before → after | Change |
|---|---|---|---|---:|
| Base (also Spread, Powerful, Large) | 0.23 s (13.8 steps) | 18 steps, 0.300 s | 4.35 → 3.33 volleys/s | −23.3 % |
| Rapid | 0.105 s (6.3 steps) | 8 steps, 0.133 s | 9.52 → 7.50 volleys/s | −21.3 % |

- **Why about 23 %.** The operator asked for "overall" and "a bit". Three constraints chose it:
  1. Whole even step counts, so every gap is the same and a 30 fps phone sees each volley leave at the same phase
     (§3.1).
  2. Rapid at 30 fps must keep the correspondence ratio at most 1/4 (§3.1), which needs Rapid ≥ 8 steps at any speed.
  3. Rapid stays as strong next to the base gun as it was: 18 / 8 = 2.25, was 2.19.

  16 steps (−14 %) did not change the screen enough; 20 steps (−31 %) with Rapid 10 lost Rapid's edge (2.0).
- **Power feel.** Spread still fires three shots per volley and Powerful still deals 2. The single-target DPS table of
  `plan/difficulty-calibration.md` becomes: base 3.33/s (was 4.35), Powerful 6.67/s (was 8.70), Rapid 7.50/s (was
  9.52). Powerful and Rapid stay roughly twice the base gun.
- **Clutter.** With §3's 480 u/s, shots between the muzzle and the top: base 5.3 → 3.3, Rapid 11.6 → 7.4, Spread
  16.4 → 10.3 (−38 % on every gun).
- Bonus `fireScale` powers (none ship one today) scale the step count and round it to whole steps.

## 3. Anti-strobe tuning in the model

### 3.1 The maths
The model steps at h = 1/60 s and the scene draws without interpolation. For a projectile at v u/s, a display at f Hz
and a stream fired every n steps:
- displacement per displayed frame `D_f = v / f` (at 120 Hz the model moves on every second frame: D, then 0);
- stream spacing `S = v · n · h`;
- correspondence ratio `ρ_f = D_f / S = 60 / (f · n)`. It does not depend on v. With nearest-neighbour matching
  [UNSOURCED: plan/provenance-audit.md#fr-nearest-neighbour], ρ < 1/2 reads as forward motion, ρ = 1/2 is ambiguous, 1/2 < ρ < 1 runs
  backwards (the wagon-wheel effect) and ρ = 1 stands still. A project margin: ρ ≤ 1/4 at 30 fps, so the right match
  is at least three times closer than the wrong one (an engineering choice, not a perceptual threshold);
- rounding beat `b_f = f · dist(D_f, ℤ)`: how often the rounded step changes length. It is 0 when D_f is whole.

| Stream | Before: n, S, ρ30, beat60 / beat30 | After: n, S, ρ30, beat60 / beat30 |
|---|---|---|
| Base | 13.8 (13/14 steps), 89.7 u, 0.145, 30 / 0 Hz | 18, 144 u, 0.111, 0 / 0 Hz |
| Rapid | 6.3 (6/7 steps), 40.9 u, 0.317, 30 / 0 Hz | 8, 64 u, 0.250, 0 / 0 Hz |
| Spread pair | 13.8, 85.1 u, 0.145, 10 / 10 Hz | 18, 126 u, 0.111, 0 / 0 Hz |

- **Before, Rapid at 30 fps had ρ = 0.32**, beyond the 1/4 margin and a third of the way to the ambiguous half, with
  spacing that changed by one step in three. No player stream sat at ρ ≥ 1/2: there was no true wagon-wheel. The
  "false flicker" was the irregular spacing, the 6/7-unit rounding shimmer and the 0/2-step frames.
- **At 120 Hz** a 60 Hz model shows every state twice. Speed cannot fix that, only interpolation can (§4). The model
  can keep the cadence regular (§3.3).
- No hostile stream aliases: sentinel volleys are 1.65 s apart (S ≈ 400 u, more than the arena), elite and carrier
  fans are single volleys 1–4 s apart, and ordinary shots come from a random shooter each time. Their problem is the
  rounding beat, §3.2.

### 3.2 The chosen numbers
| Projectile | Before | After | Per step (60 fps) | Per frame (30 fps) |
|---|---|---|---|---|
| Player primary | 390 u/s | **480 u/s** | 8 u | 16 u |
| Spread pair (climb) | 370 u/s | **420 u/s** | 7 u | 14 u |
| Hostile climbs | base × speed | **rounded to 15 u/s** | k · 0.25 u | k · 0.5 u |

- **Player speeds.** Whole units per step remove the rounding beat at 120, 60 and 30 Hz. 480 instead of 420 (7 u)
  because the faster shot also cuts clutter by 12.5 % and gave back the most difficulty on the Average pilot (§5.1).
  Spread's pair keeps one unit per step behind the primary, as 390/370 did.
- **Hostile grid, 15 u/s.** Every hostile climb is a multiple of 0.25 u per step, so the rounded step length changes
  at 0, 15 or 30 Hz at 60 fps and at 0 or 15 Hz at 30 fps. No combination is left in the 0–15 Hz band (178 of 240
  before, 0 after). The largest change is 6.5 % (Easy carrier fan); most are 2–5 %, in both directions. A 30 u/s grid
  (whole units per 30 fps frame) would change some shots by 13.5 %, too much for "slightly". Only the climb is
  snapped; the aim (`vx`) is continuous and its rounding is a slow staircase, a renderer matter (§4).
  - Snapped in one place, `_hostile`, so no future hostile shot escapes it.
- **Fire timer epsilon.** `_fire <= 1e-9` and `_accumulator >= h − 1e-9`: float drift in 18 subtractions of 1/60 would
  otherwise make one gap 19 steps and the next 17.

### 3.3 Whole steps without drift; the vsync snap is the scene's
- The accumulator steps while it holds at least one step less 1e-9 s, and the volley timer fires at ≤ 1e-9 s and never
  carries an overdue step (`_fire = max(0, _fire) + interval`): at the first volley after a reset the old timer
  started 1/60 s overdue and made the first gap 17 steps.
- A first draft also snapped jittered frame times to whole 120 Hz frames inside `ArcadeModel.update`. The
  phone-performance change does the same in the scene (`snapFrameDelta`, before `model.update`), so the model's copy
  was removed: one snap, in one place [UNSOURCED: plan/provenance-audit.md#fr-dt-snap].

## 4. With the renderer (`work/phone-performance` owns scene, painter and `shot_layer.dart`)
The phone-performance change, landing on `game` separately (its agent's note to this change, 2026-11-17):
- frame times are snapped before the fixed step, so no 0- and 2-step frames;
- each shot is drawn at its interpolated position (`stepRemainder`), still rounded to whole units;
- the sprite's two-frame shimmer runs on the shot's own age, a steady 12 Hz (it was keyed to the height: the
  irregular flicker of §1);
- fast shots (≥ 200 u/s) get a one-frame smear of up to 14 u;
- frame-time tiers FULL, LEAN and LITE; on iPhone Low Power Mode (30 Hz) the model steps exactly twice per frame;
- its rule: a stream fires no more often than every 0.1 s.

How the two fit:
- **Cadence.** Rapid's 0.133 s and the base gun's 0.30 s are both slower than the 0.1 s rule (Rapid was 0.105 s).
  Each wing cannon fires every 0.267 s under Rapid.
- **Rounding still matters.** The interpolated position is rounded to whole units, so whole-unit steps still remove
  the rounding beat. At 120 Hz an interpolated player shot moves 4 u a frame (whole), Spread's pair 3.5 u (a 60 Hz
  alternation), and hostile shots multiples of 0.125 u (beats at multiples of 15 Hz, none below).
- **Smear length.** A player shot moves 16 u per 30 Hz frame and Spread's pair 14 u; the smear's 14 u cap covers the
  pair but leaves a 2 u gap on the primary at 30 Hz. Raising `smearMax` to 16 would close it; that is the renderer's
  call.
- **Spacing.** S above (144 u base, 64 u Rapid) is the model's and does not depend on the renderer.

## 5. Recalibration (CLAUDE.md §7)
Measured with every change of §2–§3 in place; the order below is the order of tuning.

### 5.1 Ordinary sectors
Harness: `tools/ordinary_wave_probe.dart`, the Average pilot (not invulnerable; 0.25 s reaction; 70 % aim) over
sectors 1–4 of routes 0–2, lives refilled. First run with only the fire-rate change (8 seeds): lives lost per sector
+20 % Easy, +46 % Normal, +32 % Hard. Where they went (Normal): with a sentinel on the field 15.9 → 25.1, to divers
11.0 → 13.8.

| Lever tried (8 seeds) | Normal lives | Hard lives | Kept |
|---|---:|---:|---|
| Rosters × 0.8 (counts) | 31.5 | 38.5 | no: barely moves; the sector's length is the stream's pacing, not the hit budget |
| Rosters × 0.7 / 0.65 | 31.8 | 35.1 | no |
| Sentinel hull × 0.7 | 30.0 | 39.8 | yes (the sentinel phase is most of the loss) |
| Dive shields −1 | 27.6 | 34.1 | yes (divers are the other half) |
| Shot speed 480 (was 420 in the first draft) | 26.5 | 31.7 | yes |
| A power every 6 kills (was 8; 24 seeds) | 23.1 | 27.0 | no: 10–15 % easier and route 0 neutral, but more powered time on screen, and it moves every drop-count fixture, the bonus balance and the boss endurance |

Final, 24 seeds (`dart run tools/ordinary_wave_probe.dart 24`), before → after:

| Mode | Lives lost per sector | Seconds per sector | Lives per route 0 / 1 / 2 (sum of sectors) |
|---|---|---|---|
| Easy | 11.13 → 11.42 (+2.7 %) | 109.2 → 113.8 (+4.2 %) | 12.6 / 40.2 / 80.8 → 13.1 / 38.7 / 85.3 |
| Normal | 25.83 → 25.80 (−0.1 %) | 194.1 → 198.8 (+2.4 %) | 23.3 / 93.9 / 192.7 → 25.8 / 83.5 / 200.2 |
| Hard | 31.86 → 33.67 (+5.7 %) | 220.4 → 237.3 (+7.7 %) | 28.5 / 113.4 / 240.4 → 32.2 / 108.5 / 263.4 |

Easy and Normal are as hard as before. Hard is about 6 % harder for this pilot (about two standard errors), and
route 0, which has no sentinel or elite to lighten, is 4–13 % harder on every difficulty while route 1 is easier. The
lever that would remove it, more frequent power drops, was measured and set aside (table above); it is the first knob
if play agrees with the pilot (§7).

### 5.2 The carrier (carrier-hatches targets)
The fairness harness (`dart run test/support/boss_fairness.dart`; `test/boss_fairness_test.dart`): the expert's
time-to-kill and lives against the pre-hatches values. Only the fire-rate change: the expert took 505 / 738 / 770 s
(+51 / +39 / +29 % over the hatches' 335 / 530 / 596 s). Scaling the HP by the DPS ratio (× 0.77) gave 410 / 624 / 669
s: still long, because the core door opens in windows and a slower gun misses more of them.

The hatch HP floor of 3 per layer also made most small hatches equal across Easy and Normal (route 0 gave both 24),
which breaks the difficulty order. It is now 2 (`CarrierHatches.minLayer`), and the pools were re-chosen so the order
holds on every route (`campaign_model_test`).

| Lever | Easy | Normal | Hard |
|---|---|---|---|
| Hatch pool (was .5 / .55 / .65, floor 3) | .45 | .425 | .46 (floor 2) |
| Hatch pool per tour 1–5 (was) | 16, 24, 36, 42, 48 (24, 28, 42, 48, 56) | 20, 28, 42, 48, 56 (28, 36, 48, 66, 80) | 24, 32, 42, 54, 64 (32, 44, 60, 78, 88) |
| Core share (was .65 / .8 / .8) | .45 | .55 | .55 |

| Difficulty | Expert s: hatches → now (target vs pre-hatches) | Expert lives: hatches → now (target) | Naive kill share |
|---|---|---|---|
| Easy | 335.0 → 367.0 (−23.0 %; −30..−20) | 49.5 → 53.83 (−25.9 %; −35..−25) | 1.0 → 1.0 |
| Normal | 529.5 → 538.6 (−21.9 %; −25..−15) | 83.5 → 86.17 (−22.9 %; −30..−20) | 0.967 → 1.0 |
| Hard | 595.5 → 573.3 (−13.9 %; −15..−5) | 94.83 → 93.33 (−15.0 %; −20..−10) | 0.867 → 0.933 |

The carrier stays as fair as carrier-hatches shipped, and the naive pilot kills more of them. Easy's core share was
first .41 (341.6 s), which put the protected pilot's endurance 7.9 % under its baseline (§5.4); .45 centres both.

- **The loom cap**, 90 → 120 s (`ArcadeModel.loomCap`). The slower gun stretched tour 5's three launch waves past 90 s
  on Hard, so the carrier closed before the third (the campaign playtest counted 122 entrances, not 123). 120 s is
  90 × 0.30 / 0.23 ≈ 117, rounded up. It is a cap: when the waves finish sooner, nothing changes.

### 5.3 Sentinel hull and dive shields
- `DifficultyPolicy.sentinelHull`: `round(((armoured ? 12 : 9) + 2 · min(route, 4)) × 0.7)`. Shield and armour layers
  are unchanged, so the Powerful/armour rules hold. The bonus par (`sectorPar`) uses the same function.
- Dive shields: sentinel 3 + route ÷ 2 (was 4 + route ÷ 2), elite 2 (was 3), every other creature 1 (the heavier
  species had 2). The three tiers stay (1 / 2 / 3+), and the sentinel's still needs an offensive power.

### 5.4 The other gates
- **Boss endurance** (`test/boss_endurance_test.dart`, the protected campaign pilot, 16 seeds): seconds −2.8 / −8.1 /
  −0.7 %, pooled −3.9 %; see
  `plan/calibration-current.md`, "Fire-rate tune". The seconds stay within the gates of the unchanged seconds
  baseline. Its "hits" are the hits the carrier takes, which fall with its HP by construction (pooled about −25 %), so
  only the hits baseline is re-measured.
- **Campaign playtest:** all bounds hold (123 entrances with the loom cap; ground-missile impacts 0 / 1 / 1 of 10 /
  23 / 27).
- **Perspective parity** and **sentinel rush fairness:** pass unchanged.
- **318-wave defence budgets:** only the sentinel waves change (§5.3). Worst budgets 159 / 213 / 240 → 154 / 207 /
  234 hits; the peak whole/opening ratio rises from 2.25 to 2.37 (the opening roster's sentinel is lighter, so its
  escort weighs more), under the 2.5 ceiling.
- **Bonus balance:**
  - Supply Run's duration ratio rose to 1.150 (band 1.15). Its only powers are crates (no kill drops), so its crates
    now fall every 3 s (was 3.5 s).
  - Stormfront's lives ratio fell to 0.81 (band 0.85): a storm bolt deals 3, and the dive shields that used to stop it
    (3 on an elite, 2 on a heavier species) lost a point, so bolts broke through divers they used to stop. Bolts now
    deal 2 (`StormTuning.damage`), which keeps the old bolt-against-shield outcome; lives −11.5 % pooled.

## 6. Review sheet
`test/fire_rate_tune_review_test.dart` (tag `review`), with `--dart-define=FIRE_RATE_CONTACT=true`, writes
`art/contact/fire-rate-tune.png`:
- row 1: a dense Hard fight (route 3, sector 3) at one frame, four times: base before | after, Rapid before | after.
  Only the player's stream differs;
- rows 2–5: eight consecutive displayed frames of the Rapid stream (an 80 × 480 unit column over the ship): before
  at 60 fps, after at 60 fps, before at 30 fps, after at 30 fps.

"Before" replays the old timer and speed through the same painter. Picks and notes are logged in
`plan/render-runs/fire-rate-tune.md`.

## 7. Risks
- Pilots, not people: the Average pilot does not lead and the fairness experts do. A human who leads shots gains a
  little more from 480 u/s than the Average pilot does.
- **Route 0 and Hard are a little harder for the Average pilot** (§5.1). If play agrees, the first knob is a power
  every 7 or 6 kills (`kills % 8` in `hitDemon`), which measured neutral-to-easier everywhere; it needs the drop-count
  tests and the bonus balance re-run. If play feels easier instead, the knob is the heavier species' dive shield (back
  to 2).
- The carrier's per-hatch HP is now small (4–8). One shot is a bigger share of a hatch, which makes Large's splash
  relatively stronger on the hatches.
