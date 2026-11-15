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
