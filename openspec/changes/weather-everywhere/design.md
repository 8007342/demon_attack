# Design: weather everywhere

The operator's request is quoted in `proposal.md`. Builds on dynamic-weather (the rain plan, its research and its
flash rationale), crosswind (the wind field, demons fighting the wind, the windsock), lightning-rework (what a bolt
does: stun, zap, rank dodges, rods), demon-intelligence and alien-insignia (the rank ladder), comms-pacing and
squad-comms (cooldowns, groups, written lines) and phone-performance (the tiers).

## 1. How often: the frequencies

| Weather | Plan | Share of eligible regular levels | Eligible |
|---|---|---|---|
| Rain (any tier) | `RainPlan.forLevel`, p = 0.25 | 25 % (22–28 % measured, dynamic-weather) | sectors 1–4, seeded runs |
| Wind (breeze, gale) | `WindPlan.forLevel`, p = 0.2 | 20 % (17–23 % measured, crosswind) | sectors 1–4 except route 0 sector 1 |
| Lightning storm | `StormPlan.forLevel` (this change) | 0.25 × (0.4 × 0.9 + 0.2 × 1.0) = **14 %** (12–16 % tested) | rain/downpour levels of sectors 1–4 except route 0 sector 1 |

So rain > wind ≈ lightning, as asked. A storm is the heavy end of the rain, never a dry-sky event: it needs a level
that rains at the `rain` tier (90 % of those storm) or a `downpour` (all of them); drizzle never storms. The storm
uses its own salt (`'BOLT'`) and draws both its numbers every time, so it shifts none of the rain's, the wind's or the
bonus plan's odds; a storm and a wind may coincide (the gallery shows one). Unseeded runs (the tests, the calibrated
campaign), the carrier's sector and bonus levels never storm (Stormfront keeps its own storm).

Within a stormy level, bolts fall only while the rain's planned intensity (without the gust swell) is at least 0.4
(`StormSpec.activeAt`): a level whose rain starts mid-level or eases off storms only in its heavy middle. The
schedule is Stormfront's `StormCell` with `StormPlan.regular`:

| | Stormfront (Normal) | Regular storm |
|---|---|---|
| First tell | 3.2 s | 6 s after the rain turns heavy |
| Gap after a bolt | 3.3–4.7 s | 6.5–10 s (÷ hostile rate) |
| Tell | 1.15 s | 1.25 s |
| Aimed at the ship | 68 % | 45 % (the rest at the swarm's densest column) |
| Forks | 20 % | never |

Measured in the tests: 9–16 bolts in two minutes at Normal's rate, never closer than 5 s.

## 2. What a bolt does (model, `lib/game/model_weather.dart`)

Exactly lightning-rework's rule, unchanged: `strikeLightning` stuns the column (a stunned creature shot down scores
its ordinary points), `zapShip` strips the ship's powers and never costs a life (protection and the 1.5 s grace
ignore it), and `dodgeLightning` lets the marked ranks sidestep. No rod armour in regular sectors (lightning-rework
fits it in Stormfront only) and no lightning rod drop (Stormfront's power). Hooks (`// --- weather-everywhere`):
`_stormBeginLevel()` at the end of `_windBeginLevel()` (one weather begin per level), `_stormStep(dt)` right after
`_windStep()`. A level without a storm costs one null check per step. Calls: `stormStart` (variant: the rain's tier)
when the storm turns active, `stormStop` when it passes, a ship-aimed tell queues `stormStrike` (every other one
"Avoid lightning!", as Stormfront), and the raw `stormTell` / `stormBolt` sounds; a stun says `lightningStun`.

**No rebalance** (the operator: "no need to rebalance"). A storm is spice both ways (stunned creatures are free
kills, a zap strips the loadout); every calibration gate runs unseeded, so nothing in §7 moves.

## 3. Flash safety (`lib/game/weather/storm_layer.dart`)

dynamic-weather kept lightning out of regular sectors because of WCAG 2.3.1 [source: W3C WAI, "Understanding
Success Criterion 2.3.1: Three Flashes or Below Threshold",
https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold.html, read 2026-11-16 (dynamic-weather
research S4)]: a general flash is a pair of opposing changes of relative luminance of 10 % or more (where the darker
state is under 0.80), over more than a quarter of any 10° field; three or fewer per second pass. The rules every storm
now keeps:

| Rule | How | Tested |
|---|---|---|
| ≤ 3 flashes per second | one wash per bolt (a fork lands in the same instant); regular bolts ≥ 5 s apart (gap ≥ 6.5 s ÷ the fastest rate 1.3, plus the tell) | 15 simulated minutes at rate 1.3: never two bolts in one second |
| Large-area changes under a 10 % step | wash white ≤ 0.06 alpha (Stormfront 0.10), cloud glow ≤ 0.18 (Stormfront 0.34 → 0.2: at 0.34 its centre stepped 15 %) | `FlashSafety.washStep` over every grey backdrop 0–255: worst step 0.029 / 0.050 for the wash (0.06 / 0.10), 0.082 / ≈ 0.09 for the glow (0.18 / 0.2) |
| The bright bolt is small | a 2-unit core in a 9-unit halo, an impact oval ≤ 68 × 16 units: a few percent of a 10° field at phone size | by construction |
| Blinking ≤ 3 Hz | the tell's marker now blinks 1.5 → 3 Hz with its phase integrated from the tell's start (was `sin(time × (10 + 26 p))`, 1.6–5.7 Hz and far faster late in a level, because the phase used the absolute clock); the ship's zap flicker 3 Hz (was 10 Hz) | edges counted at 1 kHz |
| Reduced flashing | `FlashSafety.reduced`: the system's reduced motion, `?flash=low` (`off`, `0`, `reduced`, `none`), or a forced override; no wash, no cloud glow, a steady leader and marker, no ship flicker; the bolt and its tell still draw (they are gameplay) | test |

The marker and flicker caps and the glow cap apply to Stormfront too: they are the same painter and the same ship. The reduced
flashing setting is new (there was none; reduced motion only removed Stormfront's wash). It has no in-game toggle
yet: the address flag and the system setting cover it (open question 2).

Look: `StormLook.regular` (no Stormfront rain streaks, the rain layer is already there); LITE drops the two side
branches (`FrameBudget.sparks`). Drawn by `DemonScene.paintArena`: the cloud glow after the wind's sky (under the
play), the tells, bolts and wash after the bonus painters (over the play). The ship's static before a bolt reads
`BonusPainters.lightningTells`, which now also lists a regular storm's tells.

## 4. Radio (`art/comms/lines.json`, one appended block)

All written lines (`"pending": "text"`, own words, no audio) while voices wait on tillandsias#1103; the borrowed
count stays 55. A new rate-limit family `weather` (`groupGap` 10 s between two squad lines of the family) on every new
trigger, on top of each trigger's cooldown; variants share their event's cooldown key (`_admit`), so a swing right
after a gust stays quiet.

| Trigger | Fires on | Squad | Brood | Pacing |
|---|---|---|---|---|
| `windStart.gale` | a gale rises (crosswind's `windStart`, now with `variant` = tier; a breeze keeps `windStart`) | 3 | 2 | 60 s |
| `windGust.swing` | the wind turns (a big swing, `variant: swing`; a gust keeps `windGust`) | 3 | 2 | 14 s, chance 0.5 |
| `windDive` | a smart demon rides a gust into its dive | 2 | 3 | 25 s, chance 0.5 |
| `stormStart` | the storm turns active | 3 | 2 | 90 s |
| `stormStop` | it passes | 2 | 1 | 90 s, chance 0.6 |
| `rainStart` | a shower begins (dynamic-weather's event, unvoiced until now) | 2 | 1 | 180 s, chance 0.5 |

The brood loves its weather ("Thunder! The sky sings for us!", "Ride the gust! Down we go!"). `fang-and-wings-comms`
owns the dive war cries; `windDive` is a separate event and trigger, so the two never collide.

## 5. Wing flapping in the wind: real frames

**Feasibility.** The combat creatures are not painted sprites: `tools/generate_sprites.py` poses a small 3-D gargoyle
rig (`tools/gargoyle_rig.py`) per frame, with a separate pose for each wing, and rasterises it onto the bounded
palette with the committed hide-detail maps. Re-rendering 72 shipped cells reproduced `combat.png` pixel for pixel
(2026-11-18), so new frames from the same rig match the shipped ones exactly. The ComfyUI studio is not needed (it
only made the hide-detail maps). A painter-level deformation was therefore not used.

**Frames.** `tools/generate_wind_flap.py` (Python because the rig is; Pillow venv per CLAUDE.md §4) renders a separate
atlas, so `combat.png` (shared with `insignia-ranks` and `spear-bearers`) is untouched: 4 species × 5 damage
variants × 2 wind sides × 8 flap frames (320 cells) plus elite armour overlays per side, 1024 × 1536, 178 KB, and
`lib/game/wind_flap_atlas.dart` with the head anchors (calibrated like `combat_anchors.dart`, so the insignia rides
the skull). Pose for a wind blowing to side s at strength k (recipe `art/families/wind-flap.json`):

- upwind wing: elevation × (1 + 0.35k) + 4k (capped at 66°), sweep + 4k, fold − 0.1k, finger curl × (1 + 0.3k): it
  beats deeper and reaches higher, into the wind;
- downwind wing: elevation × (1 − 0.45k) − 4k, sweep − 10k, fold + 0.3k, curl × (1 − 0.4k) + 10k: shallow, swept back,
  half folded, fingers flicked up by the air;
- body: banked (roll 1.1 × 12° k) and turned (yaw 0.45 × 38° k) toward the wind, head turned 10° k into it, tail
  streaming downwind.

**Picks** (logged in `plan/render-runs/wind-flap.md` and on `art/contact/wind-flap-candidates.png`): A k = 0.55,
B k = 1.0, C k = 1.45 against the calm flap. **B**: A reads as the ordinary flap at phone size, C folds the downwind
wing into the body on the upstroke. Fit pass: at yaw 0.35 / sweep 8 frames 0 and 2 touched the 64-px cell edge; the
66° cap, sweep 4 and yaw 0.45 / roll 1.1 clear every cell. Full sheet: `art/contact/wind-flap-sheet.png`.

**Selection** (`lib/game/weather/wind_flap.dart`, presentation only). A creature fights the wind, and swaps its
flight (or flight-flash) cell for the wind-flap cell of its species, damage variant, wind side and flap phase, when
the model's lateral wind is ≥ 0.3 ± 0.06 (a per-creature stagger, so the swarm does not switch at once) and it is not
telling a dive, diving, firing, stunned or a sentinel (the sentinels have their own hero sprite). It beats at 18
frames a second (16 in still air). Divers keep their dive frames: a smart rider is gliding on the gust. The cells are
**virtual rows** of the combat atlas from row 64, so the scene's rim, body, glow, elite overlay and insignia passes take
them unchanged (`DemonScene.sprite` picks the image; `CombatAtlas.headAnchor` the anchors). Draw cost is unchanged
(one image swap, the same calls). Gallery: the weather page's gale tiles, a storm + gale tile and an animated sheet of
every species and side.

## 6. Smart demons ride the wind (`ArcadeWindDive`)

Who reads the wind: the insignia ladder (`lightningRank`): veterans, hunters and sentinels always, skirmishers from
the third tour (route ≥ 2), drones never.

1. **Timing.** When the dive picker draws a creature that reads the wind, `windDiveDelay` scans the wind field (a pure
   function of time) for the first wait w in 0, 0.1 … 2.4 s (prep time) after which the dive would start
   (w + the 0.5 s prep beat + its tell, at the hostile rate) in a tailwind of ≥ 0.45 toward the ship. It holds that
   long (`Demon.windWait`, with `divePrep` = beat + w so it counts as preparing: no second dive, no evasion, its slot
   held), then the ordinary prep begins with its radio beat. No such gust in 2.4 s: across a weak wind it dives now
   and fights it; into a headwind it lets the pick go (`declined`), and the picker tries again after its ordinary
   gap, so the brood never dives more often than in calm air. A stun, a regroup or a pincer ends the wait. The player sees it coming: the windsock and wisps forecast the wind 1.5 s ahead, the
   prep beat and the tell are unchanged.
2. **The ride.** At the dive's start (`_windRide`, from `_windPush`), every dive in a wind is tallied (smart or
   not, aligned or not). A smart diver in a tailwind rides: its aim moves upwind by 0.7 of the expected carry and it
   yields 0.45 of the wind over a 1 s horizon (an ordinary creature yields ≤ 0.24 over 0.6 s, ×0.6 in a dive), so a
   full gale carries it about 23 units: a curve in on the wind. `windDive` tells the radio. Drones and young
   skirmishers fight the wind (crosswind's rule).
3. **Determinism.** No random draws (the picker's own draw is unchanged); in calm air `windDiveDelay` returns at once,
   so every calibration gate is unchanged draw for draw. The dive code itself is untouched (spear-bearers' mid-dive
   throw is independent).

Measured (forced gale, sector 3, route 2, seeds 3, 5, 8, 13, 21, 34, 90 s each): 82 % of smart dives start in a
tailwind of ≥ 0.45 toward the ship against 54 % of the drones'. The first build (hold only, no letting a pick go,
1.6 s) reached 50 % against 35 %; holding 2.4 s and letting headwind picks go made the difference read. The test
asks for ≥ 15 points.

## 7. Calibration

Unchanged: every gate in CLAUDE.md §7 runs unseeded (calm, dry, no storm); no number moves, so
`plan/calibration-current.md` only notes that.

## Open questions

1. dynamic-weather's spec scenario "No lightning outside Stormfront" is superseded by this change; when the two
   are archived in order, its requirement "Rain respects accessibility settings" needs a MODIFIED block here that
   drops that scenario (not written now because dynamic-weather is not yet in the main specs).
2. An in-game "reduced flashing" toggle (today: the system's reduced motion or `?flash=low`).
3. Should a smart rider also dive faster in a tailwind? Not done: it would touch the dive code spear-bearers works in,
   and the curve already reads.
4. Voices for the new lines wait on tillandsias#1103.
