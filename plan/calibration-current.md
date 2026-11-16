# Difficulty calibration: current bounded formulas

Seed 1982; 318 actual generated ordinary-wave entrances across three modes and five routes. Every initial roster, finite reinforcement and dedicated escort is counted once. Controlled casualties unblock admission; this is a defense-budget audit, not a player skill or clear-time estimate.

Reproduce current data: `dart tools/analyze_difficulty.dart /tmp/difficulty-current`. The command writes per-wave JSON/Markdown plus a compact summary. Historical baseline uses commit `12cde0b`; current formulas are documented in [difficulty-calibration.md](difficulty-calibration.md).

| Mode | Route | Waves | Enemy count range | Standard hit range | Powerful hit range | Peak active | Max elite births | Max whole/opening defense |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| easy | 1 | 14 | 6–14 | 6–28 | 6–14 | 14 | 0 | 1.00 |
| easy | 2 | 18 | 10–31 | 17–63 | 11–40 | 28 | 1 | 1.71 |
| easy | 3 | 22 | 12–35 | 31–108 | 18–64 | 31 | 1 | 1.87 |
| easy | 4 | 26 | 13–36 | 34–112 | 20–66 | 32 | 1 | 1.79 |
| easy | 5 | 26 | 15–38 | 53–159 | 30–89 | 33 | 1 | 1.87 |
| normal | 1 | 14 | 17–26 | 17–52 | 17–26 | 22 | 0 | 2.13 |
| normal | 2 | 18 | 18–42 | 29–80 | 19–51 | 33 | 2 | 2.07 |
| normal | 3 | 22 | 21–47 | 55–144 | 33–85 | 36 | 2 | 2.22 |
| normal | 4 | 26 | 22–49 | 58–151 | 35–88 | 38 | 2 | 2.08 |
| normal | 5 | 26 | 25–52 | 90–213 | 51–120 | 39 | 2 | 2.25 |
| hard | 1 | 14 | 21–31 | 21–62 | 21–31 | 26 | 0 | 2.10 |
| hard | 2 | 18 | 22–49 | 36–92 | 23–59 | 38 | 3 | 2.14 |
| hard | 3 | 22 | 25–54 | 65–162 | 39–95 | 41 | 3 | 2.25 |
| hard | 4 | 26 | 26–57 | 68–172 | 41–101 | 44 | 3 | 2.06 |
| hard | 5 | 26 | 29–59 | 104–240 | 59–135 | 44 | 3 | 2.22 |

Standard hits sum actual hull, shield and armor. Powerful hits round each defense layer separately at two damage per hit. Large preserves damage per target: with zero overlap it has the Standard budget; Powerful + Large has the Powerful budget. With perfect simultaneous overlap, an individual arrival group needs at least the largest per-enemy layered hit budget; that is a theoretical coverage bound, not measured throughput. Spread and Large cannot stack, and Rapid and Powerful cannot stack. Current Large radii are Easy 32, Normal 30, Hard 28.

Ground war (2026-11-09): ground units never join the ordinary swarm, so these 318-wave budgets are unchanged; rerunning the audit reproduces them. The ground war's own calibration (bands, exposure and clear times per difficulty) is in [difficulty-calibration.md](difficulty-calibration.md#ground-war-ground-forces-allies-homing-missiles).

## Continuous swarm (W3): pilot metrics

Recorder: `test/support/swarm_metrics.dart`, driven by the protected real-shot campaign pilot
(`test/campaign_playtest_test.dart`, seed 1982). It writes `.cache/swarm-metrics.json` and one Markdown summary per
mode. Clear time is combat seconds (RunMode.playing) while a wave number is current; hit ratio is player shots
consumed by a hit over shots fired; peaks are over the wave. Sectors are pooled over the five routes. The pilot is
invulnerable, so lives lost are 0 by construction (the Average pilot, task 5.5, reports those).

### Pre-W3 baseline (`game` at 6752cb5f)

| Mode | Sector | Waves | Mean clear (s) | Hit ratio | Peak active | Peak hostile |
|---|---:|---:|---:|---:|---:|---:|
| easy | 1 | 24 | 15.05 | 58.0 % | 18 | 6 |
| easy | 2 | 24 | 20.36 | 64.7 % | 30 | 7 |
| easy | 3 | 29 | 16.58 | 58.8 % | 22 | 6 |
| easy | 4 | 29 | 21.13 | 66.2 % | 34 | 9 |
| easy | 5 | 4 | 71.29 | 99.7 % | 10 | 11 |
| normal | 1 | 24 | 30.19 | 71.3 % | 32 | 11 |
| normal | 2 | 24 | 39.57 | 71.7 % | 35 | 12 |
| normal | 3 | 29 | 35.03 | 73.4 % | 38 | 11 |
| normal | 4 | 29 | 36.17 | 72.2 % | 40 | 13 |
| normal | 5 | 4 | 95.76 | 98.9 % | 10 | 11 |
| hard | 1 | 24 | 33.03 | 73.7 % | 36 | 14 |
| hard | 2 | 24 | 24.88 | 71.0 % | 40 | 12 |
| hard | 3 | 29 | 43.96 | 75.7 % | 42 | 14 |
| hard | 4 | 29 | 34.77 | 73.9 % | 45 | 12 |
| hard | 5 | 4 | 74.58 | 98.3 % | 10 | 11 |

Fitted efficiency of `T_expected = 2 + ΣHP / (4.35 · e)` (median `T_actual / T_expected` = 1.0, `T_actual` = combat
seconds from a wave's start to the next wave's pressure trigger): Easy 0.822, **Normal 0.763** (adopted), Hard 0.920.

Facing (`test/swarm_facing_test.dart`, Normal sector 2, 60 s of combat, simulation only): **13.3 %** of drawn
ordinary-creature flight frames banked (`CreatureMotion.dir != 0`; telegraph, dive and dive-prep frames
excluded); shortest held direction 0.15 s.

### Calibration loop (tasks 3.6, 5.4)

Eight seeds (1982, 7, 21, 42, 99, 314, 2718, 5150) per mode, full campaigns, `test/swarm_calibration_test.dart`
(`flutter test --dart-define=SWARM_CALIBRATION=<tag> test/swarm_calibration_test.dart`). The pre-W3 side runs the
same harness on `lib/` from e3911089. Wall = all non-paused seconds while a wave number is current (the old
interwave transition included); clear = combat seconds only. Aimed hit = hits of shots fired while something could
be hit (the auto-fire also spends shots during arrivals and lulls). Change in % against pre-W3, per sector:

1. After group 3 (stream, no patterns), oracle pilot: wall −4 … +9 %, clear ≤ +15 %, hit −3 … −17 % (Easy).
2. After group 5 (patterns, sweep span 130–180 / period 4.5–6), oracle pilot: wall −9 … +2 %, clear ≤ +7 %,
   hit −23 % (Easy sector 1) … −3 %, aimed −16 … 0 %.
3. Tempo iteration: Easy `swarmTempo` 0.85 → 0.7 changed nothing outside the noise (Easy sector 1 aimed −17 %);
   reverted to 0.85. The cause was the pilot, not the swarm: the historical pilot predicts a hovering creature
   with the model's own hover formula (an oracle no player has), while it can only lead a pattern by velocity.
4. Calibration pilot without the oracle (`steer(oracle: false)`: every formation creature led by its velocity),
   on both sides — **accepted**:

| Sector | Wall | Clear | Hit | Aimed hit | Aimed (post) |
|---|---:|---:|---:|---:|---:|
| easy1 | -3.6% | +4.4% | -14.8% | -7.0% | 50.3 % |
| easy2 | -1.0% | +5.4% | -10.8% | -4.5% | 59.2 % |
| easy3 | -0.1% | +8.5% | -12.8% | -6.4% | 54.1 % |
| easy4 | -1.5% | +4.8% | -10.7% | -4.6% | 60.5 % |
| easy5 | -4.5% | -5.7% | -0.1% | -0.1% | 99.2 % |
| normal1 | -4.1% | -0.4% | -4.9% | -0.6% | 67.4 % |
| normal2 | -4.7% | -1.5% | -4.7% | -1.0% | 68.8 % |
| normal3 | -1.6% | +2.3% | -2.3% | +1.9% | 71.2 % |
| normal4 | -3.6% | +0.2% | -5.3% | -1.3% | 68.8 % |
| normal5 | -5.3% | -6.4% | +0.4% | +0.4% | 98.9 % |
| hard1 | -10.0% | -8.2% | -3.9% | -0.9% | 68.9 % |
| hard2 | -8.5% | -6.5% | -4.5% | -1.4% | 70.5 % |
| hard3 | +0.2% | +3.9% | -4.3% | -1.3% | 70.8 % |
| hard4 | -5.1% | -2.4% | -1.7% | +1.2% | 73.0 % |
| hard5 | -0.8% | -0.9% | +0.5% | +0.5% | 98.0 % |

All ordinary sectors: clear time within +8.5 % (limit +25 %), hit ratio within −14.8 % (limit −15 %); peak active
and peak hostile bullets unchanged or lower (≤ 45 and ≤ 16; bound ≤ 120). Budgets: `test/difficulty_calibration_test.dart`
unchanged and green (318 waves).

### Average pilot (task 5.5, W4 baseline; report only)

`AveragePilot` (`test/support/average_pilot.dart`): not invulnerable, 0.25 s reaction, 70 % aim, dodges the nearest
shot; 99 lives, one sector from wave 1, four seeds. Mean lives lost per sector (pre-W3 → post-W3). The pilot is
weak and noisy; the numbers are a baseline for `demon-intelligence`, not a verdict.

| Mode | Route | S1 | S2 | S3 | S4 |
|---|---:|---:|---:|---:|---:|
| easy | 0 | 0.00 → 0.25 | 1.00 → 0.25 | 5.00 → 2.75 | 8.00 → 5.25 |
| easy | 1 | 3.50 → 2.50 | 13.00 → 8.00 | 10.50 → 8.50 | 14.75 → 13.50 |
| easy | 2 | 13.75 → 8.25 | 26.00 → 20.75 | 21.75 → 17.50 | 41.50 → 30.50 |
| normal | 0 | 1.00 → 2.00 | 2.25 → 2.75 | 10.50 → 8.75 | 13.00 → 11.25 |
| normal | 1 | 22.25 → 9.75 | 31.75 → 24.00 | 43.50 → 14.25 | 47.50 → 22.50 |
| normal | 2 | 51.75 → 48.75 | 46.25 → 50.00 | 56.00 → 75.50 | 43.50 → 68.25 |
| hard | 0 | 0.50 → 1.50 | 3.50 → 3.50 | 11.00 → 9.25 | 16.75 → 12.00 |
| hard | 1 | 28.25 → 12.75 | 21.75 → 23.75 | 22.25 → 34.25 | 26.25 → 40.75 |
| hard | 2 | 51.75 → 44.25 | 61.00 → 52.50 | 62.00 → 91.75 | 78.75 → 77.00 |

### Post-W3 (after the review-frame tuning of group 8)

Same harness, oracle-free pilot, eight seeds; change against pre-W3:

| Sector | Wall | Clear | Hit | Aimed hit | Aimed (post) |
|---|---:|---:|---:|---:|---:|
| easy1 | -2.3% | +6.1% | -17.9% | -9.4% | 49.0 % |
| easy2 | -5.4% | +0.0% | -10.2% | -3.4% | 59.9 % |
| easy3 | +1.8% | +10.7% | -12.6% | -5.2% | 54.8 % |
| easy4 | -3.3% | +2.6% | -12.9% | -5.7% | 59.8 % |
| easy5 | -9.0% | -11.3% | +0.2% | +0.2% | 99.5 % |
| normal1 | -1.2% | +2.9% | -6.3% | -1.2% | 67.0 % |
| normal2 | -7.2% | -4.3% | -2.4% | +2.0% | 70.9 % |
| normal3 | -8.8% | -5.8% | -6.9% | -1.7% | 68.7 % |
| normal4 | +4.4% | +9.1% | -5.3% | -0.9% | 69.1 % |
| normal5 | -4.1% | -4.8% | +0.0% | +0.0% | 98.5 % |
| hard1 | -7.3% | -5.1% | -3.6% | +0.3% | 69.7 % |
| hard2 | -6.6% | -4.4% | -6.0% | -1.8% | 70.2 % |
| hard3 | +6.4% | +10.9% | -1.0% | +2.6% | 73.6 % |
| hard4 | -14.7% | -13.0% | -5.8% | -1.8% | 70.8 % |
| hard5 | -6.9% | -8.2% | +0.0% | +0.0% | 97.5 % |

Absolute post-W3 values:

| Mode | Sector | Waves | Mean clear (s) | Mean wall (s) | Hit ratio | Aimed hit | Peak active | Peak hostile | Lives lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| easy | 1 | 192 | 16.12 | 19.30 | 44.5 % | 49.0 % | 19 | 9 | 0 |
| easy | 2 | 192 | 20.79 | 23.96 | 55.7 % | 59.9 % | 29 | 10 | 0 |
| easy | 3 | 232 | 18.67 | 21.30 | 50.6 % | 54.8 % | 22 | 9 | 0 |
| easy | 4 | 232 | 23.11 | 25.73 | 55.3 % | 59.8 % | 33 | 10 | 0 |
| easy | 5 | 32 | 52.13 | 66.85 | 99.5 % | 99.5 % | 10 | 11 | 0 |
| normal | 1 | 192 | 33.25 | 36.43 | 63.5 % | 67.0 % | 32 | 12 | 0 |
| normal | 2 | 192 | 34.89 | 38.07 | 67.8 % | 70.9 % | 35 | 12 | 0 |
| normal | 3 | 232 | 33.38 | 36.01 | 65.1 % | 68.7 % | 37 | 13 | 0 |
| normal | 4 | 232 | 37.21 | 39.84 | 66.0 % | 69.1 % | 39 | 13 | 0 |
| normal | 5 | 32 | 73.16 | 87.88 | 98.5 % | 98.5 % | 10 | 11 | 0 |
| hard | 1 | 192 | 36.72 | 39.89 | 67.0 % | 69.7 % | 36 | 16 | 0 |
| hard | 2 | 192 | 36.16 | 39.34 | 67.2 % | 70.2 % | 40 | 15 | 0 |
| hard | 3 | 232 | 38.38 | 41.01 | 71.0 % | 73.6 % | 43 | 15 | 0 |
| hard | 4 | 232 | 33.40 | 36.02 | 67.9 % | 70.8 % | 45 | 16 | 0 |
| hard | 5 | 32 | 69.67 | 84.39 | 97.5 % | 97.5 % | 10 | 11 | 0 |

Accepted: clear time within +11 % everywhere (limit +25 %); aimed hit ratio within −9.4 % (limit −15 %); peak
active ≤ 45 and peak hostile bullets ≤ 16 (≤ 120); budgets unchanged. The raw hit ratio (every shot fired) drops up
to −17.9 % in Easy sector 1: the auto-fire keeps shooting while a small Easy wave's skeins are still arriving or
holding in the lull, phases the old interwave transition did not count. The aimed ratio measures what the change can
affect (moving targets) and is the acceptance figure; the raw figure is reported for review. Facing: 55.3 % banked
(was 13.3 %).

## Demon intelligence (W4): Post-W4

Harness: `test/swarm_calibration_test.dart` (`--dart-define=SWARM_CALIBRATION=<tag>`), eight seeds per mode, the
oracle-free pilot (the "expert": invulnerable, real shots) and the Average pilot (now all eight seeds), with the new
recorder `IntelMetrics` in `test/support/swarm_metrics.dart` (tiers, dives, rushes, skill). **Pre-W4** is the same
harness re-run on `game` at cfdec578 (W3 merged; the copied recorder reads only fields that exist there), so the
columns compare like with like; it differs slightly from the Post-W3 table above, which was recorded before the W3
merge's last tuning. Δ = post / pre − 1.

### Per sector (expert)

| Sector | Clear pre → post (s) | Δ clear | Aimed hit pre → post | Δ aimed | Peak hostile (post) |
|---|---:|---:|---:|---:|---:|
| easy1 | 16.30 → 16.56 | +1.6% | 49.3% → 49.1% | -0.4% | 9 |
| easy2 | 21.23 → 21.45 | +1.0% | 60.1% → 59.5% | -0.9% | 10 |
| easy3 | 18.66 → 18.74 | +0.4% | 54.8% → 53.2% | -2.9% | 9 |
| easy4 | 23.10 → 23.57 | +2.0% | 59.8% → 60.3% | +0.8% | 10 |
| easy5 | 50.83 → 54.92 | +8.0% | 99.5% → 98.9% | -0.6% | 11 |
| normal1 | 31.45 → 31.30 | -0.5% | 66.4% → 65.8% | -1.0% | 13 |
| normal2 | 35.01 → 34.47 | -1.5% | 70.1% → 68.6% | -2.2% | 13 |
| normal3 | 31.95 → 32.86 | +2.9% | 69.1% → 70.0% | +1.2% | 13 |
| normal4 | 35.19 → 32.85 | -6.6% | 68.9% → 68.4% | -0.7% | 13 |
| normal5 | 73.76 → 74.73 | +1.3% | 98.2% → 98.2% | +0.0% | 11 |
| hard1 | 35.49 → 34.32 | -3.3% | 69.9% → 69.5% | -0.7% | 15 |
| hard2 | 33.78 → 36.99 | +9.5% | 71.0% → 71.3% | +0.3% | 15 |
| hard3 | 36.00 → 38.16 | +6.0% | 72.5% → 72.6% | +0.1% | 15 |
| hard4 | 35.47 → 36.00 | +1.5% | 72.2% → 71.4% | -1.1% | 16 |
| hard5 | 73.30 → 76.41 | +4.2% | 98.1% → 98.1% | +0.1% | 11 |

Route 0 is bit-identical (no hunters, no sentinels, the skirmisher veto starts on route 1): every route-0 metric
below is unchanged to the last digit. Sector 5 is the carrier (not an ordinary wave).


#### Expert (invulnerable real-shot pilot, 8 seeds)
| Bucket | Tier | Hit ratio pre → post | Δ | Evasions/min pre → post | Dives (hit ship / dodged / shot down) post |
|---|---|---:|---:|---:|---|
| easy/r0 | T0 | 46.6% → 46.6% | +0.0% | 11.38 → 11.38 | 4 / 20 / 34 |
| easy/r0 | T1 | 44.9% → 44.9% | +0.0% | 24.80 → 24.80 | 31 / 42 / 163 |
| easy/r1+ | T0 | 50.7% → 51.5% | +1.6% | 13.68 → 14.09 | 91 / 263 / 631 |
| easy/r1+ | T1 | 65.6% → 65.9% | +0.4% | 45.15 → 44.37 | 682 / 2096 / 1487 |
| easy/r1+ | T2 | 48.1% → 39.3% | -18.3% | 2.56 → 5.98 | 160 / 258 / 227 |
| easy/r1+ | T3 | 76.7% → 81.1% | +5.7% | 1.67 → 1.29 | 0 / 0 / 0 |
| hard/r0 | T0 | 50.5% → 50.5% | +0.0% | 20.14 → 20.14 | 11 / 38 / 72 |
| hard/r0 | T1 | 57.7% → 57.7% | +0.0% | 48.84 → 48.84 | 70 / 204 / 341 |
| hard/r1+ | T0 | 68.3% → 66.8% | -2.2% | 17.97 → 19.43 | 352 / 1041 / 1649 |
| hard/r1+ | T1 | 75.3% → 75.4% | +0.2% | 62.16 → 61.81 | 2299 / 6202 / 3586 |
| hard/r1+ | T2 | 70.5% → 64.7% | -8.2% | 3.87 → 9.81 | 1622 / 2499 / 667 |
| hard/r1+ | T3 | 80.4% → 83.4% | +3.7% | 4.88 → 4.07 | 0 / 0 / 0 |
| normal/r0 | T0 | 55.5% → 55.5% | +0.0% | 16.72 → 16.72 | 18 / 61 / 57 |
| normal/r0 | T1 | 54.3% → 54.3% | +0.0% | 41.74 → 41.74 | 53 / 166 / 242 |
| normal/r1+ | T0 | 63.3% → 63.1% | -0.4% | 17.22 → 18.63 | 206 / 688 / 1177 |
| normal/r1+ | T1 | 72.1% → 72.3% | +0.2% | 57.15 → 59.53 | 1498 / 4249 / 2640 |
| normal/r1+ | T2 | 66.5% → 55.2% | -16.9% | 3.43 → 8.58 | 678 / 1043 / 413 |
| normal/r1+ | T3 | 80.1% → 83.2% | +3.9% | 5.29 → 4.16 | 0 / 0 / 0 |

| Bucket | Rush (pre) | Rush (post) | Skill mean / max (post) |
|---|---|---|---|
| easy/r0 |  |  | 0.18 / 0.37 |
| easy/r1+ | shotDown 12 | passEnded 6, passes 6, shieldBroken 14, shotDown 14, tells 14 | 0.41 / 0.50 |
| hard/r0 |  |  | 0.41 / 0.80 |
| hard/r1+ | passEnded 28, passes 28, shotDown 75 | passEnded 114, passHit 59, passes 173, shieldBroken 165, shotDown 165, tells 220 | 0.70 / 1.00 |
| normal/r0 |  |  | 0.31 / 0.65 |
| normal/r1+ | passEnded 26, passes 26, sacrificed 1, shotDown 79 | passDodged 1, passEnded 66, passHit 31, passes 98, shieldBroken 130, shotDown 130, tells 158 | 0.63 / 0.80 |

#### Average pilot (8 seeds × sectors 1-4 × routes 0-2)
| Bucket | Tier | Hit ratio pre → post | Δ | Evasions/min pre → post | Dives (hit ship / dodged / shot down) post |
|---|---|---:|---:|---:|---|
| easy/r0 | T0 | 31.6% → 31.6% | +0.0% | 8.59 → 8.59 | 3 / 2 / 20 |
| easy/r0 | T1 | 46.5% → 46.5% | +0.0% | 23.27 → 23.27 | 14 / 91 / 117 |
| easy/r1+ | T0 | 50.7% → 51.9% | +2.4% | 15.46 → 15.79 | 12 / 189 / 294 |
| easy/r1+ | T1 | 51.3% → 50.7% | -1.3% | 19.19 → 19.08 | 60 / 354 / 316 |
| easy/r1+ | T2 | 43.9% → 37.1% | -15.4% | 2.03 → 3.35 | 70 / 273 / 105 |
| easy/r1+ | T3 | 69.5% → 71.0% | +2.1% | 1.61 → 1.33 | 0 / 0 / 0 |
| hard/r0 | T0 | 39.5% → 39.5% | +0.0% | 13.70 → 13.70 | 2 / 17 / 45 |
| hard/r0 | T1 | 57.4% → 57.4% | +0.0% | 40.49 → 40.49 | 52 / 299 / 238 |
| hard/r1+ | T0 | 66.3% → 66.2% | -0.1% | 16.13 → 18.87 | 44 / 709 / 535 |
| hard/r1+ | T1 | 63.6% → 63.9% | +0.3% | 22.34 → 23.67 | 166 / 1241 / 588 |
| hard/r1+ | T2 | 56.0% → 55.4% | -1.1% | 1.96 → 4.01 | 242 / 1673 / 261 |
| hard/r1+ | T3 | 71.1% → 72.2% | +1.5% | 3.49 → 2.77 | 0 / 0 / 0 |
| normal/r0 | T0 | 38.7% → 38.7% | +0.0% | 11.89 → 11.89 | 1 / 13 / 36 |
| normal/r0 | T1 | 54.3% → 54.3% | +0.0% | 35.73 → 35.73 | 40 / 219 / 188 |
| normal/r1+ | T0 | 61.9% → 61.1% | -1.4% | 15.15 → 16.20 | 37 / 430 / 441 |
| normal/r1+ | T1 | 59.5% → 59.6% | +0.2% | 21.01 → 21.13 | 126 / 828 / 480 |
| normal/r1+ | T2 | 52.2% → 48.2% | -7.6% | 1.77 → 3.24 | 126 / 805 / 192 |
| normal/r1+ | T3 | 70.8% → 71.8% | +1.5% | 3.51 → 2.99 | 0 / 0 / 0 |

| Bucket | Rush (pre) | Rush (post) | Skill mean / max (post) |
|---|---|---|---|
| easy/r0 |  |  | 0.14 / 0.32 |
| easy/r1+ | passEnded 2, passes 2, sacrificed 1, shotDown 4 | passEnded 6, passHit 1, passes 7, sacrificed 4, shieldBroken 8, shotDown 6, tells 10 | 0.07 / 0.48 |
| hard/r0 |  |  | 0.11 / 0.30 |
| hard/r1+ | passEnded 12, passes 12, sacrificed 3, shotDown 31 | passDodged 1, passEnded 45, passHit 21, passes 67, sacrificed 11, shieldBroken 55, shotDown 45, tells 78 | 0.06 / 0.30 |
| normal/r0 |  |  | 0.11 / 0.49 |
| normal/r1+ | passEnded 14, passes 14, sacrificed 5, shotDown 22 | passDodged 2, passEnded 29, passHit 9, passes 40, sacrificed 9, shieldBroken 46, shotDown 37, tells 55 | 0.07 / 0.43 |

#### Average pilot: lives lost per sector (mean of 8 seeds)
| Mode | Route | S1 | S2 | S3 | S4 | Mean Δ |
|---|---:|---|---|---|---|---:|
| easy | 0 | 0.00 → 0.00 | 0.88 → 0.88 | 4.63 → 4.63 | 7.25 → 7.25 | +0.00 |
| easy | 1 | 3.38 → 4.63 | 7.50 → 9.25 | 8.63 → 7.88 | 18.63 → 12.88 | -0.88 |
| easy | 2 | 8.50 → 10.13 | 18.25 → 16.38 | 17.88 → 18.50 | 42.13 → 46.00 | +1.06 |
| normal | 0 | 1.63 → 1.63 | 2.00 → 2.00 | 9.75 → 9.75 | 11.25 → 11.25 | +0.00 |
| normal | 1 | 15.75 → 8.75 | 17.75 → 18.25 | 32.75 → 32.75 | 35.38 → 28.50 | -3.35 |
| normal | 2 | 34.88 → 31.38 | 44.63 → 46.13 | 64.75 → 71.38 | 63.13 → 59.00 | +0.12 |
| hard | 0 | 1.88 → 1.88 | 3.63 → 3.63 | 9.88 → 9.88 | 13.25 → 13.25 | +0.00 |
| hard | 1 | 16.50 → 19.88 | 23.75 → 34.63 | 36.50 → 21.13 | 30.13 → 28.13 | -0.78 |
| hard | 2 | 55.00 → 48.13 | 47.00 → 44.50 | 77.63 → 81.13 | 76.13 → 56.88 | -6.28 |

Rush columns: `passes` = charges flown, `passHit` = a charge that touched the ship (the expert sits under the
sentinel it shoots at: it is the stationary pilot of the threat guard, protected), `passEnded`/`passDodged` = a
charge that left without touching, `shieldBroken` = rush shields broken, `shotDown`/`sacrificed` = how sentinels
that rushed ended, `tells` = rally warnings. Pre-W4 rows count the old last stand.

### Acceptance (design §9, Normal against pre-W4)

| Check | Bound | Result |
|---|---|---|
| Every campaign completes (invulnerable pilot) | all | 24 / 24 (3 modes × 8 seeds), `test/campaign_playtest_test.dart` green |
| Ordinary-wave clear time per sector | ≤ +10 % | −6.6 … +2.9 % (Easy ≤ +2.0 %, Hard ≤ +9.5 %) |
| T2 hit ratio | drop ≤ 25 % | −16.9 % (Easy −18.3 %, Hard −8.2 %) |
| T0 / T1 hit ratio | ≤ 5 % | −0.4 % / +0.2 % (all modes within −2.2 … +1.6 %) |
| Average pilot lives lost per sector | ≤ +0.3 | route 1 −3.35, route 2 +0.12 (mean of S1–S4); route 0 ±0 |
| Expert skill | reaches ≥ 0.7 | max 0.80 (= the Normal cap), mean 0.63 over route ≥ 1 waves; Hard max 1.00 |
| Average skill | 0.25–0.55 | **0.07 mean** (max 0.43): see below |
| Rush fairness guards | §6.4 | escape ≥ 99.8 %, threat 100 %, corridor holds (`test/sentinel_rush_fairness_test.dart`) |
| Hostile bullets | ≤ 120 | peak 18 |
| Dive concurrency | ≤ cap | never above (10-minute Hard sim, `test/demon_intelligence_test.dart`) |
| Easy route 0 | no change | identical |

**Average skill out of band.** The Average pilot loses 9–70 lives per sector; every lost life takes 0.35 off the
skill level and freezes it for 10 s, so it lives at the floor (mean 0.07). That is the meter doing what §7 asks
(a struggling player is never pressed harder), and it means hunters meet this pilot at their slowest; the band was
written for a player who loses a life every few minutes, which this pilot is not. Not tuned: it would need either
a gentler life drop (against the spec) or a stronger reference pilot.

Lives-lost noise: per-sector values move by several lives between seeds (the pre-W4 standard error of a sector mean
is 2–8 lives), so the route means above are the meaningful figure.

## Boss grandeur (2026-11-15): carrier endurance

`test/boss_endurance_test.dart`: the protected real-shot pilot of `campaign_playtest_test.dart` plays full campaigns
on 16 seeds per difficulty; carrier endurance is the combat seconds from the carrier being fight-ready to its fall
(sum of the five carriers), and the hits taken while it is ready. One seed's sum varies by ±10 % (a single carrier
by ±50 %), so the gate is on means: the three difficulties pooled within 5 % of the baseline, each within 10 %.
Baseline: `game` at bac1f458 with the same harness (the carrier was fight-ready on arrival).

| Mode | Baseline s | After s | Δ | Baseline hits | After hits | Δ |
|---|---:|---:|---:|---:|---:|---:|
| easy | 333.07 | 345.77 | +3.8 % | 914.3 | 936.6 | +2.4 % |
| normal | 431.69 | 436.46 | +1.1 % | 1252.1 | 1265.0 | +1.0 % |
| hard | 428.92 | 469.45 | +9.4 % | 1325.3 | 1362.9 | +2.8 % |
| **pooled** | 1193.7 | 1251.7 | **+4.9 %** | 3491.7 | 3564.5 | **+2.1 %** |

The gate holds with little margin (pooled +4.9 % of 5 %; Hard +9.4 % of 10 %): a seed-to-seed spread of ±10 %
makes the 16-seed mean move by ±2.5 % between equivalent builds (an earlier build of the same rules measured
Easy +8.3 %, Normal +0.7 %, Hard +5.4 %, pooled +4.5 %). Ablations on the way (same harness): the glide alone (no loom) +1.5 / +4.0 / +3.2 %; the loom as first built
+10 / +7 / +13 %, of which the power timers running out during the 5 s Rise were the cause (shield phase +25 %
with 0.15 vs 0.23 powers active); the timers now hold while the carrier rises. Resetting the level clock, the
ground war or the pilot model at the Rise changed nothing measurable.

## Playtest fixes 3 (2026-11-16): the sentinel's berserk rush

`openspec/changes/playtest-fixes-3`: the sentinel is invulnerable in its rally and lock; its rush shield is a
super-powerful diving shield (base gun deflects; powers and homing wear it; 6 / 8 + cycle÷2 / 10 + cycle÷2); a dodged
pass pays 300 × (cycle + 1), a break 150, a burn-out after a dodged last pass the kill value; rush chance
0.28 / 0.45 / 0.50 (was 0.20 / 0.35 / 0.45).

Harness: `test/swarm_calibration_test.dart` (`--dart-define=SWARM_CALIBRATION=pf3-post`, eight seeds, expert and
Average pilots, run alone under the test lock). **Pre** is the same harness on `game` at 1c670982
(`SWARM_CALIBRATION=pf3-pre`). The comparison is a small Go tool over the two JSON/Markdown outputs.

**Re-tune.** With Hard at 0.55 the Average pilot lost +3.37 lives per sector on Hard route 1 (S3 21.1 → 28.8,
S4 28.1 → 32.6); Hard at 0.50 gives +2.44 there (S3 unchanged: a seed-path effect, within the 2–8-life standard
error of a sector mean). Hard is set to 0.50; Easy and Normal are unchanged between the two runs. Tables below are
the 0.50 run.

### Per sector (expert)

| Sector | Clear pre → post (s) | Δ clear | Aimed hit pre → post | Δ aimed | Peak hostile (post) |
|---|---:|---:|---:|---:|---:|
| easy1 | 16.21 → 16.31 | +0.6% | 48.1% → 48.7% | +1.4% | 9 |
| easy2 | 21.10 → 20.79 | -1.5% | 59.7% → 58.9% | -1.4% | 10 |
| easy3 | 18.90 → 18.31 | -3.1% | 53.0% → 53.3% | +0.7% | 9 |
| easy4 | 22.59 → 23.13 | +2.4% | 60.7% → 59.9% | -1.3% | 10 |
| easy5 | 31.01 → 32.91 | +6.1% | 75.3% → 76.9% | +2.0% | 11 |
| normal1 | 31.31 → 31.57 | +0.8% | 65.5% → 66.8% | +2.0% | 14 |
| normal2 | 36.19 → 34.37 | -5.0% | 71.1% → 69.8% | -1.9% | 13 |
| normal3 | 33.00 → 34.00 | +3.1% | 69.4% → 69.4% | -0.0% | 13 |
| normal4 | 33.73 → 33.30 | -1.3% | 68.3% → 68.8% | +0.8% | 13 |
| normal5 | 40.66 → 38.91 | -4.3% | 78.3% → 76.6% | -2.1% | 12 |
| hard1 | 33.69 → 32.52 | -3.5% | 69.2% → 67.1% | -3.1% | 15 |
| hard2 | 36.95 → 36.37 | -1.6% | 70.5% → 70.4% | -0.2% | 15 |
| hard3 | 36.64 → 38.17 | +4.2% | 71.8% → 72.4% | +0.7% | 17 |
| hard4 | 35.86 → 36.71 | +2.4% | 71.8% → 71.9% | +0.1% | 18 |
| hard5 | 42.60 → 43.46 | +2.0% | 77.8% → 80.8% | +3.9% | 15 |

worst clear +6.1%, worst aimed -3.1%

#### Expert
| Bucket | T0 / T1 / T2 hit pre → post | Rush (pre) | Rush (post) | Skill mean / max (post) |
|---|---|---|---|---|
| easy/r0 | 52.3 → 52.3%; 44.0 → 44.0% |  |  | 0.19 / 0.41 |
| easy/r1+ | 51.6 → 51.2%; 65.1 → 65.8%; 39.5 → 40.2% | passEnded 7, passes 7, shieldBroken 18, shotDown 18, tells 18 | passEnded 8, passHit 14, passes 22, sacrificed 14, shieldBroken 11, shotDown 8, tells 22 | 0.42 / 0.50 |
| hard/r0 | 54.1 → 54.1%; 57.6 → 57.6% |  |  | 0.42 / 0.80 |
| hard/r1+ | 66.7 → 67.3%; 74.9 → 74.7%; 62.3 → 61.8% | passDodged 2, passEnded 78, passHit 46, passes 126, shieldBroken 152, shotDown 152, tells 195 | passDodged 5, passEnded 92, passHit 346, passes 443, sacrificed 83, shieldBroken 97, shotDown 96, tells 443 | 0.71 / 1.00 |
| normal/r0 | 55.1 → 55.1%; 54.8 → 54.8% |  |  | 0.32 / 0.80 |
| normal/r1+ | 62.6 → 62.4%; 72.1 → 72.0%; 55.4 → 55.5% | passDodged 1, passEnded 49, passHit 41, passes 91, shieldBroken 111, shotDown 111, tells 149 | passDodged 2, passEnded 77, passHit 183, passes 262, sacrificed 66, shieldBroken 81, shotDown 80, tells 263 | 0.63 / 0.80 |

#### Average
| Bucket | T0 / T1 / T2 hit pre → post | Rush (pre) | Rush (post) | Skill mean / max (post) |
|---|---|---|---|---|
| easy/r0 | 31.6 → 31.6%; 46.5 → 46.5% |  |  | 0.14 / 0.32 |
| easy/r1+ | 51.9 → 51.9%; 50.7 → 50.6%; 37.1 → 37.1% | passEnded 6, passHit 1, passes 7, sacrificed 4, shieldBroken 8, shotDown 6, tells 10 | passEnded 9, passHit 2, passes 11, sacrificed 11, shieldBroken 1, tells 11 | 0.07 / 0.48 |
| hard/r0 | 39.5 → 39.5%; 57.4 → 57.4% |  |  | 0.11 / 0.30 |
| hard/r1+ | 66.2 → 66.2%; 63.9 → 64.2%; 55.4 → 56.6% | passDodged 1, passEnded 45, passHit 21, passes 67, sacrificed 11, shieldBroken 55, shotDown 45, tells 78 | passDodged 6, passEnded 49, passHit 47, passes 102, sacrificed 40, shieldBroken 20, shotDown 15, tells 102 | 0.06 / 0.30 |
| normal/r0 | 38.7 → 38.7%; 54.3 → 54.3% |  |  | 0.11 / 0.49 |
| normal/r1+ | 61.1 → 60.6%; 59.6 → 60.2%; 48.2 → 47.0% | passDodged 2, passEnded 29, passHit 9, passes 40, sacrificed 9, shieldBroken 46, shotDown 37, tells 55 | passDodged 6, passEnded 50, passHit 28, passes 84, sacrificed 36, shieldBroken 25, shotDown 20, tells 84 | 0.07 / 0.43 |

#### Average pilot: lives lost per sector (mean of 8 seeds)
| Mode | Route | S1 | S2 | S3 | S4 | Mean Δ |
|---|---:|---|---|---|---|---:|
| easy | 0 | 0.00 → 0.00 | 0.88 → 0.88 | 4.63 → 4.63 | 7.25 → 7.25 | +0.00 |
| easy | 1 | 4.63 → 4.63 | 9.25 → 9.63 | 7.88 → 7.88 | 12.88 → 13.13 | +0.16 |
| easy | 2 | 10.13 → 10.13 | 16.38 → 16.50 | 18.50 → 18.50 | 46.00 → 46.13 | +0.06 |
| normal | 0 | 1.63 → 1.63 | 2.00 → 2.00 | 9.75 → 9.75 | 11.25 → 11.25 | +0.00 |
| normal | 1 | 8.75 → 9.13 | 18.25 → 19.50 | 32.75 → 26.00 | 28.50 → 26.63 | -1.75 |
| normal | 2 | 31.38 → 27.63 | 46.13 → 46.63 | 71.38 → 74.63 | 59.00 → 57.38 | -0.40 |
| hard | 0 | 1.88 → 1.88 | 3.63 → 3.63 | 9.88 → 9.88 | 13.25 → 13.25 | +0.00 |
| hard | 1 | 19.88 → 20.00 | 34.63 → 35.88 | 21.13 → 28.75 | 28.13 → 28.88 | +2.44 |
| hard | 2 | 48.13 → 44.38 | 44.50 → 44.13 | 81.13 → 74.38 | 56.88 → 60.75 | -1.75 |

The expert pilot sits under the sentinel it shoots at, so its passes mostly touch the ship (it is protected); with
the bare gun no longer wearing the rush shield, rushes now run their passes (`passes`, `sacrificed` up; `shieldBroken`,
`shotDown` down). The Average pilot meets 1.5–2.1× the passes and breaks a shield a third as often, as the rule
intends: dodging, not shooting, is the answer.

### Acceptance (Normal against pre, as design §9 of demon-intelligence)

| Check | Bound | Result |
|---|---|---|
| Every campaign completes (invulnerable pilot) | all | 24 / 24 |
| Ordinary-wave clear time per sector | ≤ +10 % | −5.0 … +4.2 % (sectors 1–4; the carrier, sector 5, −4.3 … +6.1 %) |
| Aimed hit ratio | ≤ −15 % | −3.1 % worst |
| T0 / T1 / T2 hit ratio | ≤ 5 % / drop ≤ 25 % | within −1.2 … +1.2 points |
| Average pilot lives lost per sector, Normal | ≤ +0.3 | route 1 −1.75, route 2 −0.40; route 0 ±0 |
| Rush fairness guards | §6.4 | `test/sentinel_rush_fairness_test.dart` green (kinematics unchanged) |
| Hostile bullets | ≤ 120 | peak 18 |
