# Proposal: gargoyle rank insignia (fangs and wings)

## Why
Operator feedback round 5, item I1 (`plan/operator-feedback-2026-11-17.md`): "The Chevrons for the aliens look a
little bit too much like hearts, what can we do to change their rankings in a more gargoyly way? Please have some
agents design some assets for tiny iconography inspired in fangs and wings."

The cause is in the glyph data that `alien-insignia` shipped (`tools/alien_insignia/sheets.go`):
- the R1 **talon** (`oo...oo / ooo.ooo / .ooooo. / ..ooo.. / ...o...`) is, pixel for pixel, the textbook pixel-art
  heart: two lobes split by a top notch over a wedge that tapers to one point;
- the R2 **double talon** is two such hearts stacked;
- the R4 **crown** puts five tines over a band with two ember dots, so it reads as a face with eyes and teeth.

All four old glyphs are exactly mirror-symmetric. At 7–9 glyph px, a mirror-symmetric mark is read as a heart, a
face or a smile first (design §1).

## What Changes
- **A new rank ladder built from fangs and wings**, one glyph per marked rank, hand-authored on the same coarse grid
  (1 glyph px = 2 art px = 1.35 CSS px), the same palette and the same painter:

  | Rank | Who | Old | New |
  |---|---|---|---|
  | R0 Drone | small creatures | none | none |
  | R1 Skirmisher | not-so-small creatures | talon | **fang**: one curved ivory tusk (7 × 8) |
  | R2 Veteran | route-hardened skirmishers | two talons | **twin fangs**: two tusks canted alike, staggered (10 × 8) |
  | R3 Hunter | elites | ocellus | **winged fang**: bat wings over a hanging fang, ember core (13 × 9) |
  | R4 Sentinel | sentinels | crown over ocellus | **winged crown**: three rising fangs between wide wings, ember core (15 × 7) |
  | Carrier forms 1–4 | boss forms | the same ladder | the same ladder |

- **Readability rules for marks of a few pixels** (design §1), written into the troop style guide §4.1.
- **Tooling:** `tools/alien_insignia` gains the new glyphs, the `gargoyle` review-sheet verb, the `candidates` verb and
  lookalike scores; the atlas (`assets/images/insignia.png`, `lib/game/insignia_atlas.dart`) is regenerated.
- **Runtime:** only the glyph keys change (`InsigniaPainter.glyphKey`). Size, anchors, tones, reveal, overlap and the
  one `drawAtlas` per frame are unchanged.
- **Review:** `art/contact/gargoyle-insignia.png` (old against new at 8×, 2× and 1×, on the four species at phone size,
  and in the real scene in a dense formation) and `art/contact/gargoyle-insignia-candidates.png` (every shape tried).
- **Ledger:** `plan/render-runs/gargoyle-insignia.md` (picks and reasons).

## Capabilities
### Modified Capabilities
- `arcade-presentation`: the "Alien rank insignia" requirement (from `alien-insignia`) names the new marks, and a new
  requirement keeps rank marks from reading as hearts, smiles or faces.

## Impact
- Code: `lib/game/insignia_painter.dart` (glyph keys), doc comments in `sprite_atlas.dart` and `scene.dart`.
- Generated: `assets/images/insignia.png`, `lib/game/insignia_atlas.dart` (`go run . atlas`).
- Tests: `test/insignia_test.dart` (keys; a new escalation test), `test/gargoyle_insignia_review_test.dart` (review,
  skipped by default).
- Docs: `docs/styleguide/alien-troops.md` §3, §4, §7, §9.
- Order: `alien-insignia` is still open; archive it before this change, since the MODIFIED requirement is its own.
