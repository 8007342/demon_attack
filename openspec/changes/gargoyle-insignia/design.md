# Design: gargoyle rank insignia

The language is in `docs/styleguide/alien-troops.md` (§4, §4.1). The runtime is unchanged from `alien-insignia`
(painter, anchors, tones, reveal, overlap); this change replaces the shapes.

No external research was used: every conclusion below comes from the glyph data in this repository and from the
sheets and scores this change renders (provenance rule, CLAUDE.md §8).

## 1. Why the old marks read as hearts, and the rules for marks of a few pixels
The old R1 talon is 7 × 5 glyph px: two 2-px lobes split by a 1-px top notch, over a wedge that closes to one pixel.
That is the canonical pixel heart. Once the ink outline is added, the notch is one ink pixel. In the 40-px area
downscale (the ranks sheet's right-hand columns) it fills in, and what is left is a rounded, symmetric wedge: the
heart's envelope. Stacking two of them (R2) gives two hearts. The R4 crown is five 1-px tines over a band with two
ember dots: at a glance that is two eyes over a row of teeth.

The rules, measured on `art/contact/gargoyle-insignia-candidates.png` and `art/contact/gargoyle-insignia.png`:
1. **The envelope speaks first.** At 7–15 glyph px, the outlined silhouette is what survives the downscale; interior
   detail and 1-px notches do not. Judge a mark by its blurred envelope.
2. **Mirror symmetry is a face magnet.** A mirror-symmetric blob of near-square aspect reads as a heart, a face or a
   shield. Small marks are asymmetric (a fang that leans). A symmetric mark must be clearly wider than tall (≥ 1.4 : 1)
   so that it reads as wings, not a head.
3. **No two lobes over a point.** A top notch over a wedge closing to one point is a heart at any size. A point is fine
   when it hangs clear below a wide, thin top (the winged fang's T), or when it is the end of a leaning stroke.
4. **No mirrored pair of hooks or fangs.** Converging, they are the heart's lobes; diverging, under a bar, they are
   vampire teeth. Paired marks lean the same way and are staggered by a pixel (the count is the read).
5. **No row of points under a band.** That is a mouth with teeth (candidate R4 B). Points rise as a crown, or hang as
   a single fang.
6. **At most one ember dot, on the centre line.** Two dots side by side are eyes.
7. **Gaps of at least one glyph px.** The outline turns a one-pixel gap into ink, so two strokes stay two strokes.
   A gap of zero merges them (the first twin-fang draft became an "N").
8. **Escalate by width and by kind.** Each rank is wider than the one below, and the step from fangs to wings (and
   the ember core) marks the officers (R3, R4).

These rules echo the carrier's head-reading guard (`docs/styleguide/alien-capital-ships.md` §3 item 4) at icon size.
The fangs rhyme with its tusk-prongs (§3 item 8): long, ivory, tapering, never a short round hook.

## 2. The ladder
Coarse grid, `o` bone, `e` ember core; the ink outline is added (1 glyph px, 8-connected).

```
R1 fang 7x8     R2 twin fangs 10x8   R3 winged fang 13x9   R4 winged crown 15x7
ooo....         ooo.......           oo.........oo         .......o.......
oooo...         oooo..ooo.           ooo.......ooo         o...o..o..o...o
.oooo..         .oooo.oooo           .oooo.o.oooo.         oo..o.ooo.o..oo
..oooo.         ..ooo..ooo           ..ooooeoooo..         ooo.ooooooo.ooo
...ooo.         ..ooo..ooo           .o.o.ooo.o.o.         .ooooooeoooooo.
...ooo.         ...oo...oo           .....ooo.....         ..oo.ooooo.oo..
....oo.         ...o....oo           ......oo.....         ..o.........o..
....o..         ........o.           ......oo.....
                                     ......o......
```
- **R1 fang:** one ivory tusk. Its root is up-left, and it curves down to a tip that hooks back.
- **R2 twin fangs:** two tusks leaning the same way, the second one glyph px lower, with a gap on every row.
- **R3 winged fang:** bat wings swept up to sharp tips with scalloped trailing edges, an ember shoulder, and a fang
  hanging clear below. The envelope is a T, wider than tall.
- **R4 winged crown:** wide wings and three rising fangs (the centre one tallest) over an ember band. It points up
  where the hunter points down, and it is the widest mark.
- **Tones** are unchanged: bone with ember core, angry gold with white core, tell white.
- **Sizes:** the fang is 9.5 × 10.8 CSS px of fill, above the 9 × 6 minimum. The winged crown is 20.3 × 9.5. At 2×
  on the carrier sigil it is 40.5 × 18.9 units, inside the brood sigil.

## 3. Pipeline and fidelity
- **Hand-authored pixel geometry in `tools/alien_insignia` (Go).** A glyph is 7–15 glyph px. A Blender or ComfyUI
  render would have to be quantised back to exactly this grid by hand, so it would add GPU time and nondeterminism
  for no pixel the grid can hold.
- The candidates were therefore authored as grids and judged on the real `combat.png` cells, at 8×, 2×, DPR 2 and
  DPR 1, and in the real scene. The ledger (`plan/render-runs/gargoyle-insignia.md`) logs this choice and each pick.
- `go run . atlas` writes the atlas and its Dart rects. It is byte-identical across runs.
- `go test` (`gargoyle_test.go`) enforces rules 2, 4, 6, 7 and 8 and the lookalike ceiling on the shipped glyphs.

## 4. Lookalike score
Each glyph's fill mask is area-averaged into a 12 × 12 grid over its bounding box, so size is removed and the shape
is blurred as a glance blurs it. The score is the soft IoU (Σ min / Σ max) against a pixel heart, a smile and a face
(`lookalikes` in `gargoyle.go`). It is a coarse guard, not a perception model: the sheets are the judge, and the score
keeps a future edit from sliding back.

| Glyph | Heart | Smile | Face |
|---|---|---|---|
| old talon | 0.76 | 0.59 | 0.55 |
| old talon2 | 0.53 | 0.41 | 0.56 |
| old ocellus | 0.45 | 0.33 | 0.35 |
| old crown | 0.64 | 0.51 | 0.55 |
| fang | 0.48 | 0.31 | 0.44 |
| twin fangs | 0.44 | 0.36 | 0.39 |
| winged fang | 0.44 | 0.42 | 0.33 |
| winged crown | 0.41 | 0.44 | 0.43 |

The ceiling is 0.5 for every shipped glyph.

## 5. Review
`art/contact/gargoyle-insignia.png` (`go run . gargoyle -root ../..`) shows:
- the ladder, old and new, at 8×, at 2× (the atlas, in bone, angry and tell) and at 1×;
- each species wearing each rank at phone size: a 40 CSS px creature at DPR 2 and DPR 1;
- the dense formation in the real scene, at phone 360 × 780 and as a 2× close-up of the band.

The in-game frames come from `test/gargoyle_insignia_review_test.dart` (review tag). The test paints the formation
with the shipped atlas, then again without the overlay. It also writes every placed mark (key and arena rect) to
`dense-marks.json`. The Go composer seats the retired glyphs at the same anchors for the "old" frame. It is checked
against the painter: seating the new glyphs on the bare frame reproduces the real frame to a mean absolute difference
of 0.006 / 255 (phone) and 0.069 / 255 (2×), shield cells included.
