# Design: insignia ranks

No external research was used. Every number below comes from the game model in this repository, measured with
`tools/insignia_share.dart`, and from the glyph scores in `tools/alien_insignia` (provenance rule, CLAUDE.md §8).

## 1. Where the fangs came from
`CombatAtlas.rankOf` gave the mark from the behaviour tier: sentinel, elite (hunter), then skirmisher when
`kind >= 2 || maxHp >= 3` (veteran at `maxHp >= 4`), else drone. Every rank above the drone wore a fang glyph (fang,
twin fangs, winged fang, winged crown). Two facts made that most of the swarm:
- In tour 1 the species is the sector's (`kind = level - 1`, one in four a step lower): sectors 3 and 4 are all, or
  nearly all, species 2-3.
- From tour 2 the species cycle evenly (half are 2-3), and grunt hit points are `1 + kind ~/ 2 + route ~/ 2`, so in tour 5
  every grunt has 3 or more.

Measured over the creatures in the fight (§3), the old ladder marked **52-55 % in tours 1-4 and 100 % in tour 5**, with a
fang on every mark; single waves reached 100 %.

## 2. The ladder
The mark is now separate from the behaviour rank. `AlienRank`, `lightningRank` (the lightning dodge) and
`ArcadeModel.tierOf` (the planner) are untouched, so no calibration number moves. `InsigniaRanks.markOf` (pure Dart,
`lib/game/insignia_rank.dart`) reads only existing fields:

| Mark | Who | Glyph | Notes |
|---|---|---|---|
| none | grunts: drones, ordinary skirmishers and veterans | — | most of every wave |
| winglet | elite grunt (§3) | 11 × 5, bone wings spread wide | no fang, no ember |
| crownlet | elite grunt in a sentinel's escort; spear-bearers (§4) | 7 × 5, three bone points on a band | no fang, no ember |
| Fang and Wings | hunters (elites) | 13 × 9, the winged fang, ember core | the brood's battle emblem |
| winged crown | sentinels | 15 × 7, three fangs rising between wings, ember core | the top |
| carrier sigil | carrier forms 1-4 | fang, twin fangs, Fang and Wings, winged crown, at 2× | the bare fangs are the boss's alone |

- The two elite-grunt marks are the officers' marks simplified: the hunter's bat wings without its fang and ember, and
  the sentinel's crown without its wings and ember. The wing says "brood", the crown says "guard" (a sentinel's
  escort, and the spear-bearers' shield line). They share one notch.
- Escalation at a glance (gargoyle-insignia rule 8): both elite-grunt marks are narrower and shorter than Fang and
  Wings, which is narrower than the winged crown, and only the fang-bearing marks carry the ember core.
- "Fang and Wings!" reads as a fang hanging from spread wings at sprite size. Its glyph is the shipped winged fang,
  already scored at 0.44 heart, 0.42 smile and 0.33 face. A twin-fang-under-wings variant was not tried because two
  hanging fangs are the vampire teeth of rule 4.
- Overlap priority follows the mark (winged crown first); the carrier draws with the winged crown's priority.

## 3. The elite-grunt pick and the share target
**Rule:** an ordinary, non-elite creature of species 2-3 whose seed roll is under 1/5.
- **Species, not hit points.** Hit points mark every grunt in tour 5 (§1). Species 2-3 are always skirmisher tier (the
  skirmisher's brain and one more hit than the tour's weakest grunt), so a marked grunt really is tougher and smarter,
  and the candidate pool stays about half the swarm in every tour from 2 on.
- **The roll** is `frac(seed × 0.618034 / 1.7)`. Roster seeds step by 1.7 (`_buildRoster`), so a roster's rolls form a
  golden-ratio Weyl sequence: picks come evenly spaced. Any 10 consecutive roster creatures hold 1-3 picks
  (`insignia_ranks_test.dart`). Reinforcement seeds are random, so their picks are a plain 1-in-5 draw. The roll reads
  only the seed, so a creature keeps its mark for life. No model field and no random draw were added, so the
  calibration is untouched.

**Measurement.** `dart run tools/insignia_share.dart <dir>` restores every wave of tours 1-5 on Normal and Hard (seed
1982, 212 waves), plays it the way `tools/analyze_difficulty.dart` does (controlled casualties when admission stalls),
and every 0.25 s counts the creatures in the fight: not the fog reserve, not an approaching skein, not a waiting
sentinel. A wave's share is marked creature-samples over all creature-samples.

| Rule tried | Tour means, marked | Worst wave | Fang, tour means | Why not |
|---|---|---|---|---|
| old ladder | 52-100 % | 100 % | 52-100 % | the complaint |
| skirmisher tier, hash roll, 1 in 4 | 13-34 % | 49 % | 0-10 % | tour 5 marked wholesale |
| skirmisher tier, hash roll, 1 in 8 | 7-20 % | 34 % | 0-10 % | elite grunts rarer than hunters |
| species 2-3, hash roll, 1 in 4 | 14-21 % | 52 % | 0-9.4 % | random clumps |
| species 2-3, Weyl roll, 1 in 4 | 12-23 % | 35 % | 0-9.4 % | over 20 % on Hard |
| **species 2-3, Weyl roll, 1 in 5** | **10-19 %** | **31.8 %** | **0-9.4 % (worst wave 11.4 %)** | shipped |

Shipped, per tour (Normal; Hard is within a point): tour 1 10.4 %, tour 2 16.7 %, tour 3 18.6 %, tour 4 16.9 %, tour 5
16.7 % marked; fang 0, 8.9, 8.5, 8.2 and 7.5 %. The full table is in `plan/render-runs/insignia-ranks.md`.

**Targets and why.**
- **Marked: at most 20 % per tour, at most a third in any wave.** Four of five creatures in the fight wear nothing, so a
  mark stands out. Elite grunts still outnumber hunters in every tour (Normal births: 32-76 winglets against 34-52
  hunters), so the ladder is a pyramid. The worst wave (31.8 %) is a thin late-wave remnant where survivors are few.
- **Fang: at most 10 % per tour, 12.5 % in any wave.** This is above the brief's "about 8 %". The fang is now exactly
  the hunters and sentinels. Hunters are born every tenth ordinary birth (`_ordinaryProfile`, the calibrated elite
  budget), and they live longer than grunts, so they hold about 9 % of the fight. Reaching 8 % would mean hiding the
  mark on some real elites, so a fang would no longer mean "elite". The mean is 7.5-8.9 % on Normal, which is about 8 %.
  The fang share is not a pick to tune here, and it stays an open question for the operator.
- Single-sample peaks (up to 67 % with six creatures in the fight) happen when a sentinel and its last few escorts
  remain. They are not counted against the targets.

## 4. Spear-bearers (parallel change)
The spear-bearer is an armoured spear-and-shield creature: a shield-line trooper above the grunts and below the
hunters. It wears the **crownlet** (the guard's mark), always, with no fang. Hook: add its archetype to
`InsigniaRanks.markOf` **before** the `isLarge` line, because any non-ordinary `EnemyArchetype` reads as a sentinel
there. Its births count toward the §3 bounds, which `test/insignia_ranks_test.dart` enforces. If spear-bearers would
push a tour over 20 % marked, the spear-bearers branch should lower the elite-grunt pick (`eliteGruntOneIn`) rather
than leave them unmarked.

## 5. The glyph picks
Each glyph was authored on the gargoyle-insignia grid and judged at 8×, at 2×, on the four species at DPR 2 and DPR 1,
and against the lookalike score (soft IoU against a pixel heart, smile and face, with a ceiling of 0.5). The sheet is
`art/contact/insignia-ranks-candidates.png`.
- **Winglet: G "spread"** (heart 0.40, smile 0.49, face 0.44). The swept-V candidates (B, D, E, F) are wings by
  construction but scored 0.60-0.67 against the smile. The bat with a raised body (A) scored well but read as a crown:
  its nearest shape was a crown candidate, which would blur the wing/crown split. The spread wings, with their tips up
  and their outer feathers down, read as outstretched wings and as nothing else.
- **Crownlet: A "three point"** (heart 0.28, smile 0.44, face 0.45). The wide crown (B) came too close to the winged
  crown's top. The five-point crown (C) is a row of teeth over a band (rule 5; face 0.66).
- Both marks are mirror-symmetric, at 2.2 : 1 and 1.4 : 1 (rule 2), with no ember (rule 6), and both are at or above the
  7 × 5 glyph-pixel minimum (9 × 6 CSS px).

## 6. Review
- `art/contact/insignia-ranks.png` (`go run . ranks -root ../.. -waves <dir of the share tool>`): the ladder at 8×, 2× in
  three tones, and 1×, plus the carrier sigil; each mark on each species at phone size (DPR 2 and DPR 1); two sample waves
  (tour 1 sector 4 wave 2, the old worst case, and tour 3 sector 3 wave 3, with a sentinel) before and after, at phone DPR 1
  1:1 and at DPR 2; the measured shares; the scores. The wave frames are composed by the Go tool from the model's
  positions on the real `combat.png` cells. The sentinel is drawn as a stand-in at 1.8× a species cell.
- In the gallery, the `insignia` page shows the rank ladder and the dense swarm, and the new live `insignia-waves` page
  plays tour 1 sector 4 and tour 3 sector 3.
