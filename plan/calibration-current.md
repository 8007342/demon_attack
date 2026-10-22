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
