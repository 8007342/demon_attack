# Tasks

## 1. Count
- [x] 1.1 Find which creatures wear which glyph (`CombatAtlas.rankOf`, `ArcadeModel.tierOf`, `lightningRank`)
- [x] 1.2 `tools/insignia_share.dart`: the marked and fanged share of the creatures in the fight, per wave, all tours, Normal and Hard, old and new

## 2. Ladder and art
- [x] 2.1 Decide the ladder: grunts none, elite grunts winglet / crownlet, hunters Fang and Wings, sentinels winged crown, carrier fang to winged crown
- [x] 2.2 Pick the elite-grunt rule (species 2-3, 1 in 5, Weyl roll on the seed) from measured shares (design §3)
- [x] 2.3 Author winglet and crownlet candidates (`ranks.go`, `go run . candidates -set ranks`); pick and log them in `plan/render-runs/insignia-ranks.md`
- [x] 2.4 `ranks_test.go`: rules, lookalike ceiling, notch below the officers, atlas byte-identical on rebuild

## 3. Runtime
- [x] 3.1 `lib/game/insignia_rank.dart`: `RankMark`, `InsigniaRanks.markOf` (pure Dart)
- [x] 3.2 `InsigniaPainter`: marks and the carrier's sigil ladder; `scene.dart` call sites
- [x] 3.3 Regenerate the atlas (`go run . atlas -root ../..`)
- [x] 3.4 `test/insignia_ranks_test.dart` (mapping per rank, even picks, marked share under target); update `test/insignia_test.dart`

## 4. Review and docs
- [x] 4.1 `go run . ranks` writes `art/contact/insignia-ranks.png`: ladder at 8×, 2×, 1×; on the species at phone size; two sample waves before and after at DPR 1 and 2; shares and scores
- [x] 4.2 Gallery: `insignia` page (rank ladder, dense swarm) and a live `insignia-waves` page (two waves)
- [x] 4.3 `docs/styleguide/alien-troops.md` §4; the spear-bearers' slot (design §4)

## Workflow follow-up
- Operator phone playtest of the rare marks; then archive `alien-insignia`, `gargoyle-insignia` and this change, in that order.
- spear-bearers: add their archetype to `InsigniaRanks.markOf` (crownlet) when that branch lands.
