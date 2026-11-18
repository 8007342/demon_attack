# Render ledger: insignia ranks (rare marks, "Fang and Wings!")

The ledger for the rank-mark rework that followed the operator's "too many fangs" note of 2026-11-17. It records each
pick with its reasons and rejections, and how to rebuild everything.
- Change: `openspec/changes/insignia-ranks` (design §2 ladder, §3 measured shares, §5 glyph picks).
- Style guide: `docs/styleguide/alien-troops.md` §4.
- Tools: `tools/insignia_share.dart` (shares, from the real model), `tools/alien_insignia` (`ranks.go`: glyphs,
  candidates, review sheet; `ranks_test.go`: rules and atlas byte-identity).
- Picks delegated to the agent (project memory "autonomy"); made 2026-11-18 on `work/insignia-ranks`.

## 0. How to rebuild

```sh
dart run tools/insignia_share.dart ~/.cache/tillandsias-project/insignia-ranks   # table + sample-waves.json (~6 s)
cd tools/alien_insignia
go test ./...                                   # rules, lookalike ceiling, atlas byte-identical
go run . atlas -root ../..                      # assets/images/insignia.png + lib/game/insignia_atlas.dart
go run . candidates -set ranks -root ../.. -out ../../art/contact/insignia-ranks-candidates.png
go run . ranks -root ../.. -waves ~/.cache/tillandsias-project/insignia-ranks   # art/contact/insignia-ranks.png
```
All of these are deterministic. The atlas is byte-identical on rebuild (checked by `TestAtlasByteIdentical`), and the
sheets are too for the same share-tool output.

## 1. Picks

| Slot | Pick | Scores (heart / smile / face) | Rejected, and why |
|---|---|---|---|
| Elite grunt (brood) | winglet G "spread", 11 × 5 | 0.40 / 0.49 / 0.44 | A bat: it read as a crown (its nearest shape was a crown candidate). B swept V, D gull, E headed, F cup: smile 0.60-0.67. C pilot bar, I bar tips: smile 0.59-0.61. G2, G3: smile 0.51, or a centre tail that hangs like a point. H split: asymmetric, smile 0.60 |
| Elite grunt (guard) | crownlet A "three point", 7 × 5 | 0.28 / 0.44 / 0.45 | B wide: too close to the winged crown's top. C five point: a row of teeth over a band (face 0.66) |
| Hunter | Fang and Wings = the shipped winged fang | 0.44 / 0.42 / 0.33 | twin fangs under wings: two hanging fangs are vampire teeth (gargoyle rule 4) |
| Sentinel | winged crown (unchanged) | 0.41 / 0.44 / 0.43 | — |
| Elite-grunt rule | species 2-3, Weyl roll on the seed, 1 in 5 | — | design §3 table (hit-point rules mark tour 5 wholesale; hash rolls clump; 1 in 4 goes over 20 % on Hard) |
| Spear-bearers | crownlet, always | — | winglet: the crown says "guard", which fits the spear and shield line |

Review sheets: `art/contact/insignia-ranks.png` (ladder 8× / 2× / 1×, on the species at phone DPR 2 and DPR 1, two sample
waves before and after, shares, scores) and `art/contact/insignia-ranks-candidates.png`.

## 2. Measured shares (tools/insignia_share.dart output)

Seed 1982. The share of the creatures in the fight that wear a mark (and a fang). A wave's share counts creature-samples (every creature in the fight, every 0.25 s); "mean" averages the tour's waves, "worst wave" is its highest wave, and "peak" is the worst single sample with six or more creatures in the fight. Old: every rank above the drone wore a fang mark. New: lib/game/insignia_rank.dart (elite grunts: species 2-3, 1 in 5).

| Mode | Tour | Waves | Old marked (mean / worst wave / peak) | New marked (mean / worst wave / peak) | New fang (mean / worst wave / peak) | Births: winglet / crownlet / fang-and-wings / winged crown / none |
|---|---:|---:|---|---|---|---|
| normal | 1 | 14 | 51.7 % / 100.0 % / 100.0 % | 10.4 % / 26.4 % / 50.0 % | 0.0 % / 0.0 % / 0.0 % | 34 / 0 / 0 / 0 / 268 |
| normal | 2 | 18 | 54.3 % / 57.4 % / 100.0 % | 16.7 % / 30.0 % / 57.1 % | 8.9 % / 11.4 % / 33.3 % | 32 / 8 / 34 / 7 / 431 |
| normal | 3 | 22 | 54.5 % / 56.7 % / 71.4 % | 18.6 % / 24.3 % / 50.0 % | 8.5 % / 11.4 % / 33.3 % | 57 / 16 / 44 / 9 / 591 |
| normal | 4 | 26 | 54.1 % / 56.3 % / 83.3 % | 16.9 % / 31.1 % / 71.4 % | 8.2 % / 10.6 % / 33.3 % | 68 / 14 / 52 / 11 / 746 |
| normal | 5 | 26 | 100.0 % / 100.0 % / 100.0 % | 16.7 % / 30.6 % / 66.7 % | 7.5 % / 9.2 % / 25.0 % | 76 / 11 / 52 / 10 / 805 |
| hard | 1 | 14 | 51.8 % / 100.0 % / 100.0 % | 10.6 % / 28.8 % / 50.0 % | 0.0 % / 0.0 % / 0.0 % | 41 / 0 / 0 / 0 / 324 |
| hard | 2 | 18 | 54.9 % / 56.5 % / 83.3 % | 19.3 % / 27.5 % / 57.1 % | 9.4 % / 11.0 % / 33.3 % | 48 / 12 / 45 / 7 / 493 |
| hard | 3 | 22 | 54.2 % / 57.3 % / 83.3 % | 18.7 % / 31.8 % / 50.0 % | 9.3 % / 11.4 % / 33.3 % | 63 / 14 / 61 / 9 / 691 |
| hard | 4 | 26 | 54.1 % / 57.2 % / 83.3 % | 18.5 % / 29.1 % / 66.7 % | 9.0 % / 10.8 % / 33.3 % | 78 / 23 / 74 / 11 / 856 |
| hard | 5 | 26 | 100.0 % / 100.0 % / 100.0 % | 17.2 % / 23.2 % / 66.7 % | 8.8 % / 10.7 % / 33.3 % | 82 / 16 / 77 / 10 / 923 |

Worst wave mean, all 212 waves: old marked 100.0 %; new marked 31.8 %; new fang 11.4 %.

Sample frames on the sheet (12 s in): tour 1 sector 4 wave 2, 16 in the fight, 16 fangs before, then 4 winglets and no
fang after; tour 3 sector 3 wave 3, 18 in the fight, 9 fang marks before, then the sentinel's crown alone after.

## 3. Squash record
- `work/insignia-ranks`: squash into `game` by the lead; the remote ref cannot be deleted from the forge (CLAUDE.md §1).
