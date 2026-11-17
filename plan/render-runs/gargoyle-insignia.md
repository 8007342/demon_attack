# Render ledger: gargoyle insignia (I1)

This ledger covers the alien rank insignia redrawn from fangs and wings. It records each pick with its reasons and
rejections, and how to rebuild everything.
- Direction: `plan/operator-feedback-2026-11-17.md` I1: "The Chevrons for the aliens look a little bit too much like
  hearts … tiny iconography inspired in fangs and wings."
- Change: `openspec/changes/gargoyle-insignia` (design §1 has the diagnosis and the rules).
- Style guide: `docs/styleguide/alien-troops.md` §4 and §4.1.
- Tool: `tools/alien_insignia` (Go, standard library, CPU only). The shapes are in `gargoyle.go`, the candidates in
  its `candidates` list, and the rule checks in `gargoyle_test.go`.

The operator delegated the picks (project memory "autonomy"). They were made on 2026-11-17 on branch
`work/gargoyle-insignia`.

## 0. How to rebuild

```sh
cd tools/alien_insignia
go test ./...                                   # the readability rules on the shipped glyphs
go run . atlas -root ../..                      # assets/images/insignia.png + lib/game/insignia_atlas.dart
go run . candidates -root ../.. -out ../../art/contact/gargoyle-insignia-candidates.png
cd ../..
flock ~/.cache/tillandsias-project/flutter-test.lock \
  flutter test --concurrency=1 --run-skipped --tags review test/gargoyle_insignia_review_test.dart
cd tools/alien_insignia && go run . gargoyle -root ../..   # art/contact/gargoyle-insignia.png
```

- The atlas, the candidates sheet and the static rows of the review sheet are byte-identical across runs.
- The in-game frames come from the review test. It writes them to `.cache/gargoyle-insignia-review/`, which git
  ignores; nothing bulky lands in the checkout.
- `go run . gargoyle` prints the compositor check and the lookalike scores. The final run gave a mean |diff| of 0.006 (phone)
  and 0.069 (2×) out of 255, shield cells included.

## 1. Fidelity: why hand-authored pixel geometry, not Blender or ComfyUI
- A mark is 7–15 glyph px, and one glyph px is 1.35 CSS px. Each pixel is a design decision. A render (a Blender
  clay/normal pass or a ComfyUI img2img) would have to be quantised back onto this grid by hand.
- That would cost GPU queue time and bring nondeterminism (CLAUDE.md §5: re-rendering seeds is not byte-identical),
  for no pixel the grid can hold.
- The pipeline used is therefore the project's CPU art tool: grids authored in Go, judged on the real `combat.png`
  cells, in the real scene, and against lookalike scores.
- No model was downloaded and the studio was not used.

## 2. Diagnosis
- The old R1 talon (`oo...oo / ooo.ooo / .ooooo. / ..ooo.. / ...o...`) is the canonical pixel heart. R2 is two of
  them stacked.
- The R4 crown's two ember dots under five tines read as eyes over teeth.
- All four old glyphs are perfectly mirror-symmetric.
- Lookalike scores (soft IoU against a pixel heart, design §4): talon 0.76, crown 0.64.

## 3. Candidates and picks
The candidates sheet is `art/contact/gargoyle-insignia-candidates.png`. Scores are heart / smile / face, lower is
better.

| Rank | Candidate | Scores | Verdict |
|---|---|---|---|
| R1 | A slash: a curved tusk leaning right | 0.48 / 0.31 / 0.44 | **Pick.** Lowest heart and face scores. It reads as one ivory tusk and rhymes with the carrier's tusk-prongs (long, tapering, never a short round hook). At DPR 1 it is a small hooked stroke, still unlike any other rank. |
| R1 | B sabre: a heavier crescent | 0.69 / 0.40 / 0.62 | Rejected. The heavy root makes a rounded top over a point, which is a heart again. |
| R1 | C tooth: a flat-topped triangle | 0.57 / 0.31 / 0.54 | Rejected. A down-pointing triangle is the heart's lower half; it reads as a "▼" cursor. |
| R2 | A: two A-tusks, staggered | 0.44 / 0.36 / 0.39 | **Pick.** Literally "one more fang": the count reads, it is asymmetric, and it has a gap on every row. Its only misread is a closing quote mark, which is harmless and fades on the creatures. |
| R2 | B teeth: flat-rooted fangs | 0.49 / 0.33 / 0.46 | Rejected. The flat roots read as "77", and the shape drifts from R1, so the count reads less. |
| R2 | C mirror: a mirrored pair | 0.71 / 0.46 / 0.66 | Rejected. It is vampire teeth (a mouth) and, blurred, a heart. Kept on the sheet as the counter-example. |
| R3 | A winged fang | 0.44 / 0.42 / 0.33 | **Pick.** Bat wings with scalloped edges over a hanging fang: a gargoyle in flight, 13 × 9 (a T, not a wedge). The ember core carries over the hunter's old ocellus. |
| R3 | B one wing | 0.48 / 0.45 / 0.37 | Rejected. The asymmetric wing reads as a broken bird or a tick mark, and does not escalate clearly over R2. |
| R4 | A winged crown | 0.41 / 0.44 / 0.43 | **Pick.** The widest mark; three fangs rise as a crown between wide wings, with one ember jewel. It points up where R3 points down. |
| R4 | B crown with teeth | 0.48 / 0.51 / 0.55 | Rejected. The row of points under the band is a mouth (smile 0.51, face 0.55). |

Iteration log:
- **Draft 1, R2.** The two fangs touched on row 2, and with the outline they merged into an "N". The fix keeps at
  least one empty column on every row; `gargoyle_test.go` checks it.
- **Draft 1, R3 and R4.** R3 had lopsided rows (5 left, 4 right) and R4 had a row of teeth under the band. R3 was
  made symmetric and the teeth were removed from R4; the removed version is kept as candidate R4 B.

## 4. Review
The sheet is `art/contact/gargoyle-insignia.png`:
- the ladder, old and new, at 8×, at 2× in bone, angry and tell, and at 1×;
- every species wearing each rank at DPR 2 and DPR 1;
- the dense formation from the real scene at 360 × 780 and as a 2× close-up, old against new.

The "old" in-game frame seats the retired glyphs at the anchors the painter used for the new ones (design §5). The
overlap rule therefore yields the same creatures in both frames: one skirmisher and one veteran.

What it shows:
- **Old:** at phone size, R1 and R2 read as one and two hearts, and the crown reads as a little face.
- **New:** the fangs read as strokes and the winged marks as small bats.
- The ranks separate by width at DPR 1 (7, 10, 13 and 15 glyph px).
- Angry gold and tell white keep the same shapes.

## 5. Open
- An operator phone playtest of the new ladder.
- If R2 still reads as a quote mark on a real phone, the fallback is R2 B (flat-rooted), already on the candidates
  sheet.
