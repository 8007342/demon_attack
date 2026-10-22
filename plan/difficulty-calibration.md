# Research-backed difficulty calibration

Research date: 2026-10-22. This is the accepted implementation calibration, not evidence of human playtesting. Numbers below are project tuning decisions; the cited research supports the design principles, not particular percentages or hit-point values. The formulas below match the implemented policy and are guarded by generated-wave audits and regression tests.

## Evidence and implications

- Michael Booth, Valve, **The AI Systems of Left 4 Dead** (2009), PDF pages 78–82 and 92, describes alternating buildup, sustained intensity, and relaxation. It explicitly distinguishes the timing of threats from their difficulty. Apply that distinction here: a fresh reinforcement group supplies another encounter beat without also upgrading every creature's health and attack repertoire. Keep finite wave endings and the existing interwave recovery. This is an adaptation of the principle; this proposal does not add an adaptive Director. [Original Valve presentation](https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)
- Penelope Sweetser and Peta Wyeth, **GameFlow: A Model for Evaluating Player Enjoyment in Games** (2005), identifies challenge, skills, control, goals and feedback among its evaluation dimensions. Its challenge criteria call for appropriate progression and different challenge levels for different players. Apply this through ordered Easy/Normal/Hard population budgets, readable telegraphs, and small bounded changes across waves. The original evaluation concerned two strategy games; it does not establish an optimal shooter curve. [Original ACM paper](https://doi.org/10.1145/1077246.1077253)
- Mike Ambinder, Valve, **Valve’s Approach to Playtesting: The Application of Empiricism** (GDC 2009), PDF pages 7–10, advocates early measurement and an iterative design/playtest feedback loop. Therefore record actual wave-clear times and damage exposure, and treat automated completion as a regression check rather than proof that people find the game fair. [Original Valve presentation](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf)

## Diagnosis in the inspected implementation

Initial Normal Krybor ordinary enemies have 1 HP. Its first reinforcement group has 3–4 HP and the second 5–6 HP, even on the first route. Every member of the second group is elite, adding aimed three-shot fans and faster dives. A Normal route-index-1 sentinel escort has 10–11 HP; the corresponding parent ordinary roster has 2–5 HP. A final-route Hard escort reaches 17–18 HP. These spikes combine durability, headcount and independent attackers.

The old five-route multipliers also compound: route increases roster size, wave count, ordinary HP, reinforcement HP, number of groups, speed and elite attack frequency. A hostile bullet ceiling prevents unbounded allocation but does not make 120 simultaneous projectiles readable.

The companion analyzer captured 318 generated ordinary-wave configurations before the correction. First-wave Normal required 73 baseline hits across 22 enemies, despite an initial roster requiring only 8 hits: reinforcement arrivals expanded its damage workload to 9.125 times the initial roster. Hard opened at 112 hits across 28 enemies versus 10 initial hits, or 11.2 times. These are generated encounter budgets, not human performance measurements; the analyzer's before/after comparison is the appropriate regression evidence.

## Accepted ordinary-wave budget

Use `r = clamp(route, 0, 4)`, sectors 1–4, and one-based wave numbers. Clamp caller-supplied values before applying formulas. The same ordinary enemy blueprint must supply species, HP and elite eligibility for initial enemies, reinforcements and escorts.

| Setting | Easy | Normal | Hard |
| --- | ---: | ---: | ---: |
| Population factor `m` | 0.8 | 1.0 | 1.2 |
| Initial roster cap | 20 | 24 | 28 |
| Finite reinforcement groups | 0 on route 0; otherwise 1 | 2 | 2 |
| Elite births per complete wave, route 0 | 0 | 0 | 0 |
| Elite births per complete wave, later routes | 1 | 2 | 3 |
| Dedicated escort base | 12 | 13 | 14 |
| Hostile mode rate | 0.90 | 1.00 | 1.05 |

Initial roster: `clamp(round((8 + 2*(sector-1) + (wave-1) + r) * m), 4, cap)`.

Reinforcement size for zero-based group `f`: `round((4 + r~/2) * m) + clamp(f, 0, 1)`. Normal begins with groups of 4 and 5, ending with 6 and 7. The second group adds only one enemy. No sector or group health multiplier applies.

Dedicated sentinel escort size: `base + min(r, 2)`. This preserves a distinct fresh escort larger than every ordinary group, capped at 14/15/16. Its members share ordinary health and the same elite budget. Earlier arrivals do not count as its escort.

Ordinary route evolution: `tier = r~/2`, bounded to 0–2. Health: `min(5, 1 + kind~/2 + tier + (elite ? 1 : 0))`. Typical low/high-species HP over routes 0–4 is **1/2, 1/2, 2/3, 2/3, 3/4**; the scarce elite adds one. Group number never enters this formula. Initial species selection should also be reused for arrivals: first-route Krybor must not suddenly import 2-HP later-sector species. Later routes can retain the current mixed roster.

Select potential elites at every tenth ordinary birth across the whole wave, then apply the mode budget. Track a wave-wide ordinal and elite birth count; do not reset either for reinforcements or the escort. This limits even sequential elite creation, and guarantees no more than three ordinary targeted-fan attackers at once. Escorts are not automatically elite. Sentinels retain their separate identity and existing limit of one.

The whole ordinary-wave enemy count, including an escort, is bounded above by 39/52/59 for Easy/Normal/Hard using the caps above. Actual values can be lower because the roster cap is not reached in every combination. The existing absolute active limit of 61 remains a final safety bound, rather than a target density.

Keep the prompt first-casualty response and 0.6-second initial cooldown. Afterward use a 1.2-second cooldown and two casualties before the second group; a 4.5-second fallback may request entry but must still obey occupancy. For ordinary arrivals, admit a complete group only while `active ordinary + group size <= initial roster + largest ordinary group`. Reserve room for the separate escort; escort admission can use `initial roster + escort size` as its larger bound. A request remains pending until enough enemies leave. When the wave has no targetable enemies, allow a pending arrival promptly so cleanup cannot stall. Timers do not mint additional groups.

Across routes, movement growth is `1 + 0.04*r` instead of `1 + 0.10*r`. Use that consistently in movement and route-dependent dive pacing; avoid retaining the old additional 10%-per-route divisor in the dive interval. Keep existing warning durations. Retain the campaign's wave count/checkpoints to limit scope; do not add further waves or simultaneous shooters as a substitute for removed HP.

Carrier and sentinel health remain unchanged in this correction: their distinct openings, defenses and telegraphs are preserved. Ordinary and escort progression, global route movement growth and mode rate are calibrated here; no additional boss/sentinel health multiplier is introduced.

## Powers, shots to kill, and effective damage

Retain integer health and damage. Baseline and Large deal 1 damage; Powerful and Powerful+Large deal 2. Powerful replaces Rapid; Large replaces Spread. Large grants coverage, not a second damage multiplier. Each explosion must hit each target at most once, including the direct target and carrier. The existing nine-second timers and baseline 0.23-second fire interval remain.

Use Large radius **32/30/28** for Easy/Normal/Hard. With the current ordinary hit allowance of 14, effective center-distance reach is 46/44/42. This modest coverage adjustment can assist Easy without changing weapon identity. It is an efficacy adjustment, not a claim that radius creates a fixed DPS multiplier: enemy spacing and accuracy determine how many targets it hits. Keep raw Powerful damage at 2 in every mode. Raising Easy to 3 would make every 3-HP creature a one-hit kill and changes discrete outcomes far more than the nominal percentage suggests. A floating-point damage rewrite is unnecessary for this correction.

| Ordinary HP | Baseline shots | Large shots per target | Powerful shots | Powerful+Large shots per target |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 1 | 1 | 1 |
| 2 | 2 | 2 | 1 | 1 |
| 3 | 3 | 3 | 2 | 2 |
| 4 | 4 | 4 | 2 | 2 |
| 5 | 5 | 5 | 3 | 3 |

At perfect aim, the time between first and final hits is `(shots-1)*0.23` seconds: baseline 0–0.92 seconds versus Powerful 0–0.46 seconds over the table. This excludes initial bullet travel, missed shots, evasions and invulnerable entrances. Sustained single-target damage is approximately 4.35/s baseline and 8.70/s Powerful. Rapid is approximately 9.52/s at its existing 0.105-second interval, but it cannot stack with Powerful. Fixed simulation timing can quantize individual intervals.

For a layered sentinel, shots required are `ceil(shield/damage) + ceil(armor/damage) + ceil(hull/damage)` because damage does not overflow a layer. For example, the currently implemented first eligible shield sentinel has shield 4, armor 2, hull 11: 17 ordinary/Large hits or 9 Powerful/combined hits. Do not use `ceil(totalHP/damage)` for arbitrary layered enemies. Carrier aperture windows further reduce realized DPS. Powerful plus Large may damage several separate targets; that is intended area coverage and is not extra damage to a single target.

## Acceptance and measurement

1. Enumerate all five routes, four ordinary sectors, valid waves and three modes. Verify finite groups, ordered mode counts, HP at most 5, route tier at most 2, one sentinel, elite births within the entire-wave budget, and absolute active/bullet ceilings.
2. For each generated ordinary species and elite state, assert equal health whether it comes from the parent roster, a reinforcement, or an escort. Assert no group ordinal increases HP and second-group size grows by at most one.
3. Exercise real arrivals, blocked occupancy, waiting sentinels and late cleanup. Every scheduled group must arrive or be explicitly accounted for; waves must clear without a density/escort deadlock.
4. Verify the table through actual projectile collisions, including one explosion damaging the direct target only once. Check layer rounding, radius boundaries, mutually exclusive powers, closed carrier doors and expired powers.
5. Run the existing deterministic real-shot campaign pilot in every mode; record per-wave clear time, peak active enemies, elite count and hostile bullets. Its invulnerability deliberately measures completion and workload, not human survival. Remove old minimum-duration/minimum-kill assertions if their only purpose was to enforce the previous bloated enemy budget; preserve campaign and reward invariants.
6. Before claiming the curve is comfortable, human-play first Normal Krybor, a first sentinel escort, and a late-route wave. Record failures and perceived causes. For automated telemetry, investigate a reinforcement that needs more hits than its same-species parent, an ordinary-wave clear-time jump above 25% within a sector, or an escort that dominates most of a wave's damage workload. These are tuning review triggers, not research-established thresholds or promises of success.

## Independent implementation review

The 318-wave generated audit was independently checked against the shared HP formula, separately rounded shield/armor/hull damage, and Easy ≤ Normal ≤ Hard ordering for both total enemies and baseline-hit budgets. All checks passed. Observed peak active enemies were 33/39/44; elite births never exceeded 1/2/3. Inspection of complete-group admission found no circular dependency: killing ordinary enemies frees escort space, a waiting sentinel does not consume ordinary occupancy, and empty-wave admission permits pending finite groups to proceed.

The two route-tier increases warrant an explicit distinction between a per-creature upgrade and actual encounter pressure. At the tier boundaries, the last ordinary-sector wave before the carrier versus the first Krybor wave afterward requires **63→31 and 112→54** baseline hits on Easy, **80→55 and 151→90** on Normal, and **92→65 and 172→104** on Hard. The new tier therefore coincides with a smaller roster and a sector-pacing reset. Comparing the same sector across routes skips the intervening sectors and carrier and exaggerates the immediate change faced by the player. Retain the simple two-tier cap for this correction; there is no demonstrated need for additional sector-dependent cohort health. First-route species changes and sentinel/escort encounters remain deliberate discrete encounter changes. These budget comparisons do not establish human difficulty or survival rates.


## Measured before/after protected-pilot workloads

Both runs use seed 1982, the same steering and real projectiles, organic power pickups, and invulnerability to guarantee complete-campaign coverage. The baseline model/policy were read from commit 12cde0b into an isolated temporary Dart harness; the current run uses `dart run tools/profile_difficulty.dart /tmp/calibration-pilot.json`. These are comparative workload measurements, not human target times or survival estimates. Cinematic time is excluded.

| Mode | Old active campaign minutes | Current active campaign minutes | Old median ordinary wave seconds | Current median ordinary wave seconds | Current p95 wave seconds | Old peak hostile bullets | Current peak hostile bullets |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Easy |53.1 |33.1 |25.2 |14.9 |24.6 |80 |11 |
| Normal |109.5 |47.6 |52.9 |20.2 |37.6 |120 |12 |
| Hard |188.8 |47.9 |100.3 |21.0 |41.7 |120 |15 |

All runs finished five carriers and earned five medals. Current live-pilot peak enemies were 34/40/45, compared with 46/61/61 before. These may differ from the controlled-casualty spawn audit because trajectories, kills and pickup timing differ. Hard's higher bullet/elite pressure and lack of heart drops matter beyond clear time; similar full-campaign times do not imply equal human challenge. Preserve this fixed harness as a regression baseline, then use actual play feedback for later adjustments.

The complete controlled-arrival tables are [baseline](calibration-baseline.md) and [current](calibration-current.md). They enumerate all 318 mode/route/sector/wave configurations and expose the large sentinel encounter pulses instead of hiding them in an average. For example, opening Normal changes from 73 to 17 baseline hits across the complete wave, and opening Hard 112 to 21. Worst generated wave budgets change from 362/671/1121 to 159/213/240 hits for Easy/Normal/Hard, including any sentinel layers.

Clear-time outliers were also reviewed rather than hidden by the median. For example, first-tour Normal Ember Moon wave 2 clears in 5.8 seconds with Spread active throughout, while wave 3 takes 12.1 seconds with only 1.7 seconds of powered time; wave 4 starts unpowered and takes 17.6 seconds. Those changes track temporary weapon availability and modest roster growth, not a fresh reinforcement HP tier. The profiler records entry powers, powered/area frames and volleys so future reviews can distinguish these effects. This preserves the reward of collecting powers without using larger raw damage multipliers to conceal inflated enemy health.

The generated full-wave/opening defense-budget ratio now peaks at about 2.255, including dedicated escorts. A conservative project regression ceiling of 2.5 guards against recreating the former 9–11× opening-wave workload spikes. This is an engineering budget chosen for this game, not a threshold established by the cited literature; it measures required hits, not perceived intensity.
