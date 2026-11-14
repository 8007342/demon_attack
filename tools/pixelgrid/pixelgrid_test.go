package pixelgrid

import "testing"

func TestDeterministicRng(t *testing.T) {
	a, b := NewRng(42), NewRng(42)
	for i := 0; i < 100; i++ {
		if a.F() != b.F() {
			t.Fatal("rng differs")
		}
	}
	if Hash01(1, 2, 3) != Hash01(1, 2, 3) || Hash01(1, 2, 3) == Hash01(1, 3, 2) {
		t.Fatal("hash")
	}
}

func TestOutline(t *testing.T) {
	g := NewGrid(5, 5)
	g.Set(2, 2, 3)
	o := g.Outline(9)
	n := 0
	for _, c := range o.C {
		if c == 9 {
			n++
		}
	}
	if n != 4 {
		t.Fatalf("outline %d", n)
	}
}
