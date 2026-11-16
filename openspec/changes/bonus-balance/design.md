# Design: bonus balance and the run record

## 1. Root cause of the three-second level
`BonusWaves.count` defaulted to 2 and both levels thinned what remained. On Easy route 0 the sector has no
reinforcement groups (`reinforcementFlocks` = 0), so Supply Run sector 2 was `max(3, round(roster × 0.6))` per wave:
two waves of three to five drones (10 kills in the 4-seed probe, 8.9 combat seconds for the protected pilot that
starts without powers). The continuous swarm streams wave 2 in while wave 1 is still dying, and the level ends on its
last kill, so a player with spread or powerful carried over from sector 1 clears it in about three seconds. Nothing
was wrong with the clear condition: the wave set was too small.

## 2. Balance targets
Against the regular sector the level replaces (same difficulty, route, sector):

| Measure | How | Band |
|---|---|---|
| Duration | combat seconds of the protected real-shot pilot (`steer(oracle: false)`) from the level's start to its last kill | ±15 % pooled, ±20 % per difficulty, no cell < 60 % |
| Enemy count | that pilot's kills (it clears every creature) | ±15 % pooled, ±20 % per difficulty, no cell < 85 % |
| Possible score | the pilot's score minus the level's extras plus the level's cap (what a perfect level pays) | ±15 % pooled, ±20 % per difficulty |
| Difficulty | lives the Average pilot (99 lives) loses before the last kill | ±15 % pooled |

Pooled = sum over sum across sectors 2-4, routes 0-1 and the three difficulties, eight seeds each. Routes 0 and 1
are where nine runs in ten meet their bonus level (`routeWeights` 5, 3, 1, 1, 0); routes 2 and 3 are measured for the
record only. Lives lost per cell are too noisy (one sentinel rush moves a cell by 20 %) to gate per difficulty.

Both pilots play a crate level as a player would: they line up under a crate that hangs in range with no creature
between (`chaseCrate`); neither baits lightning.

## 3. Waves
Rather than tuning a smaller level to last as long, a bonus level keeps the sector's waves and changes only what its
twist needs. `BonusWaves.count` null means the sector's count; sentinels and elites default on. Supply Run keeps the
waves as they are: withholding kill drops makes it slower, its crates make up for it. Stormfront's lightning kills
creatures, so its opening rosters are 15 % larger and the storm strikes less often (Normal 3.1-4.5 s, Hard
3.3-4.7 s between bolts, × 1 + 0.1 per route).

## 4. Score
`sectorPar` now counts every creature of the regular sector at face value: opening rosters, finite reinforcement
groups, and on a sentinel wave (`regularSentinelWave`, kept equal to `sentinelFor` by a test) the sentinel and its
escort. A clear pays 1.0-1.35 × par (dives pay 1.5 ×, dive shields 25). A level's kill scale `p` and cap `c` then give
a possible score of about `p · K + c · par ≈ K`; the twist pays the difference (crates, the clear, a flawless run, the
bait bonus).

## 5. The run record
- `runModifierIds`: a pure function of the plan and the run's place (slots at or before the current route and sector,
  in run order, then the run modifier), so a restored checkpoint keeps it.
- Scoreboard: two columns added with defaults by the existing migration loop: `modifiers TEXT NOT NULL DEFAULT ''`
  (comma-joined ids, returned as an array) and `playedOn TEXT` (null on older rows). The client sends its local day;
  the server keeps it when it is within a day of its own (UTC), otherwise stamps its own. At most four ids, each
  `^[a-z][A-Za-z0-9]{0,31}$`, unique. The 512-byte body limit still holds.
- Display: `runTagLabel(id)` gives the level's label or the modifier's label; an unknown id (a newer build's record)
  is spelled out from its camelCase. The medal screen card: medals (of five) and difficulty, score, time and date,
  then the modifier tags or "STANDARD RUN"; under a fifth of a 360 × 780 phone.
