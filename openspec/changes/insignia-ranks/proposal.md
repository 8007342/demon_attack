# Proposal: insignia ranks (rare marks, "Fang and Wings!")

## Why
Operator, 2026-11-17 (verbatim): "I like the iconography, the Fang and Wings shall be their self appointed battle cry:
"Fang And Wings!" ... so their insignias on top of the demons are identifiable as Fangs/Wings. Currently there are A
LOT of fangs on top of the demons, they're not meant to mark everything, just higher ranks ... So, how do we deal with
the excess Fang icons on top of the demons? Can we use a bit more of the Winged and Crown loking ones from the elites?
Make simpler versions of those for the regular grunts, to mark that they're elite grunts, but not elite as the
centinels :)"

The cause is the mapping, not the shapes. `gargoyle-insignia` gave every rank above the drone a fang mark, and the rank
follows the behaviour tier (`kind >= 2 || maxHp >= 3`): two species of four, and every creature from tour 5 on. Measured
with the real model (design §3): **52-55 % of the creatures in the fight wore a fang in tours 1-4 and 100 % in tour 5**;
in tour 1 sector 4 every creature did.

## What Changes
- **The mark is rarer than the rank** (`lib/game/insignia_rank.dart`, pure Dart). The behaviour ranks (`AlienRank`,
  `lightningRank`, `ArcadeModel.tierOf`) are unchanged, so no balance number moves.

  | Who | Mark | Fang? |
  |---|---|---|
  | Grunts: drones and the ordinary skirmishers and veterans | none | — |
  | Elite grunt: 1 in 5 of the tough species (2-3), picked by seed | **winglet**: bone wings spread wide (11 × 5) | no |
  | Elite grunt in a sentinel's escort; spear-bearers (parallel change) | **crownlet**: three bone points on a band (7 × 5) | no |
  | Hunters (elites) | **Fang and Wings**: the winged fang, ember core (13 × 9; unchanged glyph) | yes |
  | Sentinels | **winged crown** (15 × 7; unchanged) | yes |
  | Carrier forms 1-4 | fang, twin fangs, Fang and Wings, winged crown (2×) | yes |

- **Measured shares** (`tools/insignia_share.dart`, 212 waves): 10-19 % marked per tour (was 52-100 %), 0-9.4 % with a
  fang; worst single wave 31.8 % marked, 11.4 % fanged.
- **Tooling:** `tools/alien_insignia` gains the winglet and crownlet (`ranks.go`), the `ranks` review sheet, the
  `candidates -set ranks` sheet and `ranks_test.go` (rules, lookalike ceiling, atlas byte-identity). The atlas is
  regenerated.
- **Runtime:** `InsigniaPainter.rank` takes a `RankMark`; the scene asks `InsigniaRanks.markOf`. Size, anchors, tones,
  reveal, overlap and the single `drawAtlas` are unchanged.
- **Review:** `art/contact/insignia-ranks.png`, `art/contact/insignia-ranks-candidates.png`, the gallery's `insignia` page
  (ladder, dense swarm) and a new live `insignia-waves` page (two waves); ledger `plan/render-runs/insignia-ranks.md`.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: the "Alien rank insignia" requirement names the rare-mark ladder; new requirements bound the
  marked share and give the spear-bearers their mark.

## Impact
- Code: `lib/game/insignia_rank.dart` (new), `insignia_painter.dart`, `scene.dart` (three call sites),
  `sprite_atlas.dart` (doc comments), `lib/review/gallery_scenes.dart`, `review_catalog.dart`.
- Generated: `assets/images/insignia.png`, `lib/game/insignia_atlas.dart` (`go run . atlas -root ../..`).
- Tests: `test/insignia_ranks_test.dart` (new), `test/insignia_test.dart`; Go `ranks_test.go`.
- Docs: `docs/styleguide/alien-troops.md` §4.
- Order: archive after `alien-insignia` and `gargoyle-insignia` (the MODIFIED requirement is theirs).
