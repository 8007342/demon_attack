package main

import (
	"strings"
	"testing"
)

// The readability rules of openspec/changes/gargoyle-insignia design §1,
// enforced on the shipped ladder (`go test` in tools/alien_insignia).
func TestGargoyleLadder(t *testing.T) {
	checkGlyphs()
	set, keys := newShapes(), newKeys()

	// Rule 8: each rank is wider than the one below.
	for i := 1; i < len(keys); i++ {
		if len(set[keys[i]][0]) <= len(set[keys[i-1]][0]) {
			t.Errorf("%s is not wider than %s", keys[i], keys[i-1])
		}
	}
	// The lookalike ceiling.
	for _, r := range ladderMetrics(set, keys) {
		if r.heart > .5 || r.smile > .5 || r.face > .5 {
			t.Errorf("%s: heart %.2f smile %.2f face %.2f > 0.5", r.key, r.heart, r.smile, r.face)
		}
		// Rule 2: a mirror-symmetric mark is at least 1.4 x wider than tall.
		if r.mirr > .85 && float64(r.w) < 1.4*float64(r.h) {
			t.Errorf("%s: symmetric (%.2f) but %dx%d", r.key, r.mirr, r.w, r.h)
		}
	}
	// Rule 2 for the fangs: single and paired fangs are asymmetric.
	for _, k := range []string{"fang", "fang2"} {
		if m := mirror(fillMask(set[k])); m > .5 {
			t.Errorf("%s: mirror %.2f, want asymmetric", k, m)
		}
	}
	// Rule 6: officers carry one ember cluster on the centre line; fangs none.
	for _, k := range keys {
		var cols []int
		for _, row := range set[k] {
			for i, ch := range row {
				if ch == 'e' {
					cols = append(cols, i)
				}
			}
		}
		officer := strings.HasPrefix(k, "wing")
		if !officer && len(cols) > 0 {
			t.Errorf("%s: ember on a fang", k)
		}
		if officer {
			if len(cols) == 0 {
				t.Errorf("%s: no ember core", k)
			}
			mid := (len(set[k][0]) - 1) / 2
			for _, c := range cols {
				if c < mid-1 || c > mid+1 {
					t.Errorf("%s: ember at column %d, off the centre line %d", k, c, mid)
				}
			}
		}
	}
	// Rules 4 and 7: the twin fangs are two strokes with a gap on every
	// row (the first and last rows hold one fang only: the stagger).
	rows := set["fang2"]
	for j, row := range rows {
		runs, in := 0, false
		for _, ch := range row {
			if ch != '.' && !in {
				runs++
			}
			in = ch != '.'
		}
		want := 2
		if j == 0 || j == len(rows)-1 {
			want = 1
		}
		if runs != want {
			t.Errorf("fang2 row %d: %d strokes, want %d", j, runs, want)
		}
	}
}
