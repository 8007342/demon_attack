# Difficulty calibration: baseline commit 12cde0b

Seed 1982; 318 actual generated ordinary-wave entrances across three modes and five routes. Every initial roster, finite reinforcement and dedicated escort is counted once. Controlled casualties unblock admission; this is a defense-budget audit, not a player skill or clear-time estimate.

Reproduce current data: `dart tools/analyze_difficulty.dart /tmp/difficulty-current`. The command writes per-wave JSON/Markdown plus a compact summary. Historical baseline uses commit `12cde0b`; current formulas are documented in [difficulty-calibration.md](difficulty-calibration.md).

| Mode | Route | Waves | Enemy count range | Standard hit range | Powerful hit range | Peak active | Max elite births | Max whole/opening defense |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| easy | 1 | 14 | 6–16 | 6–32 | 6–16 | 16 | 0 | 1.00 |
| easy | 2 | 18 | 16–40 | 62–226 | 35–123 | 40 | 25 | 3.77 |
| easy | 3 | 22 | 19–44 | 91–287 | 50–156 | 44 | 27 | 3.37 |
| easy | 4 | 26 | 20–47 | 115–345 | 63–185 | 47 | 27 | 2.92 |
| easy | 5 | 26 | 23–49 | 136–362 | 74–194 | 49 | 29 | 2.88 |
| normal | 1 | 14 | 22–34 | 73–104 | 44–56 | 34 | 8 | 9.13 |
| normal | 2 | 18 | 25–51 | 112–292 | 63–159 | 51 | 31 | 4.27 |
| normal | 3 | 22 | 30–59 | 159–395 | 87–212 | 59 | 34 | 3.79 |
| normal | 4 | 26 | 44–72 | 320–627 | 171–332 | 61 | 48 | 4.35 |
| normal | 5 | 26 | 50–76 | 362–671 | 194–355 | 61 | 52 | 4.40 |
| hard | 1 | 14 | 28–42 | 112–149 | 66–79 | 42 | 10 | 11.20 |
| hard | 2 | 18 | 44–76 | 273–551 | 148–294 | 61 | 52 | 6.99 |
| hard | 3 | 22 | 66–103 | 546–953 | 289–503 | 61 | 74 | 8.37 |
| hard | 4 | 26 | 70–103 | 632–1058 | 334–555 | 61 | 74 | 6.13 |
| hard | 5 | 26 | 78–108 | 694–1121 | 367–588 | 61 | 79 | 6.23 |

Standard hits sum actual hull, shield and armor. Powerful hits round each defense layer separately at two damage per hit. Large preserves damage per target: with zero overlap it has the Standard budget; Powerful + Large has the Powerful budget. With perfect simultaneous overlap, an individual arrival group needs at least the largest per-enemy layered hit budget; that is a theoretical coverage bound, not measured throughput. Spread and Large cannot stack, and Rapid and Powerful cannot stack. Current Large radii are Easy 32, Normal 30, Hard 28.
