package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func fresh(t *testing.T) *Output {
	t.Helper()
	root = findRoot()
	return build(loadSpec())
}

// Same spec -> byte-identical atlas, Dart and provenance.
func TestDeterministic(t *testing.T) {
	a, b := fresh(t).files(), fresh(t).files()
	for i := range a {
		if !bytes.Equal(a[i].data, b[i].data) {
			t.Errorf("%s differs between two builds", a[i].path)
		}
	}
}

// The committed atlas, Dart metadata and runs are what the generator makes.
func TestCommittedMatchesGenerator(t *testing.T) {
	for _, f := range fresh(t).files() {
		old, err := os.ReadFile(filepath.Join(root, f.path))
		if err != nil || !bytes.Equal(old, f.data) {
			t.Errorf("%s is stale: run go run . pack", f.path)
		}
	}
}

func TestLayout(t *testing.T) {
	o := fresh(t)
	if o.Atlas.Bounds().Dx() != 512 || o.H != 872 || o.SectorRows != 152 {
		t.Fatalf("atlas %v, %d rows per sector: want 512 x 872, 152", o.Atlas.Bounds(), o.SectorRows)
	}
	if len(o.Bands) != 25 || len(o.Sprites) != 13 {
		t.Fatalf("%d bands, %d sprites", len(o.Bands), len(o.Sprites))
	}
}

func TestSteppedAlphaAndCaps(t *testing.T) {
	o := fresh(t)
	for _, p := range append(append([]Placed{}, o.Bands...), o.Sprites...) {
		max := 0
		for _, a := range p.L.A {
			if int(a) > max {
				max = int(a)
			}
		}
		cap := 0
		for _, b := range o.Spec.Bands {
			if b.ID == p.ID {
				cap = maxLevel(b.AlphaMax)
			}
		}
		for _, s := range o.Spec.Sprites {
			if s.ID == p.ID {
				cap = maxLevel(s.AlphaMax)
			}
		}
		if max == 0 || max > cap {
			t.Errorf("%s/%d: max level %d, cap %d", p.ID, p.Index, max, cap)
		}
	}
	for i := 3; i < len(o.Atlas.Pix); i += 4 {
		if a := o.Atlas.Pix[i]; a%51 != 0 || a > 204 {
			t.Fatalf("alpha %d is not a step", a)
		}
	}
}

func colDiff(l *Layer, a, b int) int {
	d := 0
	for y := 0; y < l.H; y++ {
		v := int(l.at(a, y)) - int(l.at(b, y))
		if v < 0 {
			v = -v
		}
		d += v
	}
	return d
}

// A tiled band's wrap (column 511 -> 0) is no harder than its worst
// interior column step, and every noise field is periodic over 512.
func TestSeamless(t *testing.T) {
	o := fresh(t)
	for _, p := range o.Bands {
		worst := 0
		for x := 0; x < p.L.W-1; x++ {
			if d := colDiff(p.L, x, x+1); d > worst {
				worst = d
			}
		}
		if d := colDiff(p.L, p.L.W-1, 0); d > worst {
			t.Errorf("%s/%d: seam %d > worst interior %d", p.ID, p.Index, d, worst)
		}
	}
	for x := 0.0; x < 8; x++ {
		if a, b := fbm(3, x, 5, 512, 32, 4), fbm(3, x+512, 5, 512, 32, 4); a != b {
			t.Fatalf("fbm not periodic at %v: %v %v", x, a, b)
		}
		if a, b := wave(3, x, 512, 4, 8, 3), wave(3, x+512, 512, 4, 8, 3); a-b > 1e-9 || b-a > 1e-9 {
			t.Fatalf("wave not periodic at %v", x)
		}
	}
}

func TestMistGaps(t *testing.T) {
	o := fresh(t)
	for _, p := range o.Bands {
		if p.ID == "midMistA" || p.ID == "midMistB" {
			if e := emptyColumns(p.L); e < o.Spec.MistEmptyMin {
				t.Errorf("%s/%d: %.2f of the columns clear", p.ID, p.Index, e)
			}
		}
	}
}

func TestTintCaps(t *testing.T) {
	o := fresh(t)
	tc := o.Spec.Tint
	for i, x := range o.Tints {
		if l := luma(x.Fog); l < tc.Luma[0] || l > tc.Luma[1] {
			t.Errorf("sector %d fog luma %.3f", i, l)
		}
		if c := chroma(x.Fog); c > tc.ChromaMax {
			t.Errorf("sector %d fog chroma %.3f", i, c)
		}
		if nearSignal(x.Fog) || nearSignal(x.Lit) {
			t.Errorf("sector %d tint near a signal hue", i)
		}
		if luma(x.Lit) > tc.LitLumaMax || luma(x.Dark) > tc.Luma[1] {
			t.Errorf("sector %d lit/dark luma", i)
		}
	}
}
