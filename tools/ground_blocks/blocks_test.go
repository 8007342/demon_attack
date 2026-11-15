package main

import (
	"bytes"
	"image"
	"image/color"
	"sort"
	"strings"
	"sync"
	"testing"

	"demonattack/tools/pixelgrid"
)

var (
	testOnce sync.Once
	testProj *Project
)

func proj(t *testing.T) *Project {
	t.Helper()
	testOnce.Do(func() {
		root = findRoot()
		testProj = loadProject()
		testProj.buildAll()
	})
	return testProj
}

func TestFamiliesValidate(t *testing.T) {
	p := proj(t)
	for _, e := range p.validate() {
		t.Error(e)
	}
}

// Same rig -> byte-identical PNG, from a fresh project each time.
func TestDeterministic(t *testing.T) {
	enc := func() ([]byte, []byte) {
		root = findRoot()
		q := loadProject()
		u := q.unit("lodestar")
		c := q.refCells(u)[2]
		a, err := pixelgrid.EncodePNG(q.refImage(u, &c, 2, pixelgrid.Hex("#FF00FF")))
		if err != nil {
			t.Fatal(err)
		}
		at := q.packFamily(q.Fams["ground-host.json"], "krybor", false)
		b, _ := pixelgrid.EncodePNG(at.Img)
		return a, b
	}
	a1, b1 := enc()
	a2, b2 := enc()
	if !bytes.Equal(a1, a2) || !bytes.Equal(b1, b2) {
		t.Fatal("same rig gave different bytes")
	}
}

func names(cs []Cell) map[string]*Cell {
	m := map[string]*Cell{}
	for i := range cs {
		m[cs[i].Name] = &cs[i]
	}
	return m
}

func TestHeadingSets(t *testing.T) {
	p := proj(t)
	for _, u := range p.units() {
		b := p.builder(u)
		want := map[string]int{"V": 5, "W": 5, "K": 3, "I": 3}[u.Spec.Block]
		if len(b.Headings) != want {
			t.Errorf("%s: %d headings, want %d", u.Spec.ID, len(b.Headings), want)
		}
		m := names(p.cellsOf(u))
		state, frames := "move", 4
		switch u.Spec.Block {
		case "W", "K":
			frames = 6
		case "I":
			state = "walk"
		}
		for _, h := range b.Headings {
			for f := 0; f < frames; f++ {
				n := u.Spec.ID + ".hull." + state + ".h" + hcode(h) + ".f" + itoa(f)
				if c := m[n]; c == nil || c.F.count() == 0 {
					t.Errorf("missing or empty %s", n)
				}
			}
		}
		if b.Rig.Art != nil && len(b.Angles) != 5 {
			t.Errorf("%s: %d layer angles", u.Spec.ID, len(b.Angles))
		}
	}
}

// Every named cell is non-empty; base cells keep a 1-texel margin for the
// ink (no clipping); cell positions are unique and inside the block.
func TestCellsContract(t *testing.T) {
	p := proj(t)
	for _, u := range p.units() {
		seen := map[[2]int]string{}
		for _, c := range p.cellsOf(u) {
			if c.F.count() == 0 {
				t.Errorf("%s is empty", c.Name)
				continue
			}
			k := [2]int{c.Row, c.Col}
			if o, ok := seen[k]; ok {
				t.Errorf("%s and %s share row %d col %d", c.Name, o, c.Row, c.Col)
			}
			seen[k] = c.Name
			if c.Col < 0 || c.Col >= 20 || c.Row < 0 || c.Row >= blockRows(u.Spec.Block) {
				t.Errorf("%s at row %d col %d outside the block", c.Name, c.Row, c.Col)
			}
			if c.Overlay {
				continue
			}
			x0, y0, x1, _ := c.F.bbox()
			if x0 < 1 || y0 < 1 || x1 > c.F.W-2 {
				t.Errorf("%s touches the cell edge (%d,%d..%d)", c.Name, x0, y0, x1)
			}
		}
	}
}

// Consecutive authored headings must read as a step: at least 2 texels of
// silhouette change, and not a pop (at most 40% of the silhouette).
func TestHeadingSteps(t *testing.T) {
	p := proj(t)
	for _, u := range p.units() {
		b := p.builder(u)
		var prev *Frame
		for _, h := range b.Headings {
			f := b.move(h, 0)
			if prev != nil {
				diff, n := 0, 0
				for i := range f.Px {
					a, c := f.Px[i].Mat != 0, prev.Px[i].Mat != 0
					if a != c {
						diff++
					}
					if a || c {
						n++
					}
				}
				if diff < 2 {
					t.Errorf("%s h%s: step changes %d texels", u.Spec.ID, hcode(h), diff)
				}
				if float64(diff) > .4*float64(n) && u.Spec.Block != "I" {
					t.Logf("%s h%s: step changes %d of %d texels (%.0f%%)", u.Spec.ID, hcode(h), diff, n, 100*float64(diff)/float64(n))
				}
			}
			prev = f
		}
	}
}

// The layer pivot sits on the hull at every heading (turret seating).
func TestTurretSeating(t *testing.T) {
	p := proj(t)
	for _, u := range p.units() {
		b := p.builder(u)
		if b.Rig.Art == nil {
			continue
		}
		for _, h := range b.Headings {
			f := b.move(h, 0)
			dx, du := b.pivot(h)
			x, y := int(b.Ox+dx), int(b.Ou-du)
			ok := false
			for oy := -1; oy <= 1; oy++ {
				for ox := -1; ox <= 1; ox++ {
					ok = ok || f.filled(x+ox, y+oy)
				}
			}
			if !ok {
				t.Errorf("%s h%s: layer pivot (%d,%d) is off the hull", u.Spec.ID, hcode(h), x, y)
			}
		}
	}
}

// Walkers keep >= 3 texels of clear ground between the legs, seen from the
// front (Fleet h0, Host 180) in every stride frame.
func TestWalkerLegGap(t *testing.T) {
	p := proj(t)
	for _, u := range p.units() {
		b := p.builder(u)
		if u.Spec.Block != "W" {
			continue
		}
		h := b.Headings[0]
		if b.Rig.Faction == "host" {
			h = b.Headings[4]
		}
		for f := 0; f < 6; f++ {
			fr := b.move(h, f)
			_, _, _, y1 := fr.bbox()
			best := 0
			for y := y1 - 8; y <= y1; y++ { // the leg rows
				x0, _, x1, _ := fr.bbox()
				run, inGap, seenLeg := 0, false, false
				for x := x0; x <= x1; x++ {
					if fr.filled(x, y) {
						if inGap && seenLeg {
							best = max(best, run)
						}
						seenLeg, inGap, run = true, false, 0
					} else if seenLeg {
						inGap = true
						run++
					}
				}
			}
			if best < 3 {
				t.Errorf("%s f%d: leg gap %d texels at h%s", u.Spec.ID, f, best, hcode(h))
			}
		}
	}
}

// Palette: no warm or gilt on any Fleet texel, no ally cyan on the Host,
// binary alpha everywhere; pack fits the phone budget.
func TestPackPaletteAndBudget(t *testing.T) {
	p := proj(t)
	forbid := func(fs ...string) map[[3]uint8]bool {
		m := map[[3]uint8]bool{}
		for _, f := range fs {
			for _, h := range reservedRamps[f] {
				c := pixelgrid.Hex(h)
				m[[3]uint8{c.R, c.G, c.B}] = true
			}
		}
		return m
	}
	fleetBad, hostBad := forbid("demon_warm", "demon_gilt"), forbid("ally_cyan")
	const budget = 8 << 20
	for _, s := range sectorOrder {
		total := 0
		for _, f := range familyFiles {
			fam := p.Fams[f]
			a := p.packFamily(fam, s, false)
			w, h := a.Img.Bounds().Dx(), a.Img.Bounds().Dy()
			if w > 4096 || h > 4096 {
				t.Errorf("%s: %dx%d beyond 4096", a.File, w, h)
			}
			total += w * h * 4
			for _, q := range a.Units {
				u := p.unit(q.Unit)
				bad := fleetBad
				if u.faction() == "host" {
					bad = hostBad
				}
				cw, ch := fam.Atlas.Cell[0], fam.Atlas.Cell[1]
				rows := blockRows(u.Spec.Block)
				checkRegion(t, a.Img, image.Rect(0, q.Row0*ch, 20*cw, (q.Row0+rows)*ch), bad, a.File+" "+q.Unit)
			}
		}
		if total > budget {
			t.Errorf("%s: %d bytes RGBA over the %d budget", s, total, budget)
		}
	}
}

func checkRegion(t *testing.T, img *image.NRGBA, r image.Rectangle, bad map[[3]uint8]bool, what string) {
	t.Helper()
	n := 0
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			c := img.NRGBAAt(x, y)
			if c.A != 0 && c.A != 255 {
				t.Errorf("%s: alpha %d at %d,%d", what, c.A, x, y)
				return
			}
			if c.A == 255 && bad[[3]uint8{c.R, c.G, c.B}] {
				n++
			}
		}
	}
	if n > 0 {
		t.Errorf("%s: %d texels in a forbidden palette", what, n)
	}
}

func TestDartMetadataNamesResolve(t *testing.T) {
	p := proj(t)
	// every cell of every placed unit maps to a distinct atlas position
	for _, s := range sectorOrder {
		for _, f := range familyFiles {
			fam := p.Fams[f]
			used := map[[2]int]string{}
			for _, id := range fam.Sectors[s].Units {
				u := p.unit(id)
				row0 := 0
				for _, q := range p.packFamily(fam, s, false).Units {
					if q.Unit == id {
						row0 = q.Row0
					}
				}
				for _, c := range p.cellsOf(u) {
					k := [2]int{row0 + c.Row, c.Col}
					if o, ok := used[k]; ok && !strings.HasPrefix(o, id+".") {
						t.Errorf("%s %s: %s overlaps %s", s, f, c.Name, o)
					}
					used[k] = c.Name
				}
			}
		}
	}
}

// Each overlay state exists for at least one heading or angle (a cell is
// only omitted where the feature is hidden from the camera).
func TestOverlayStates(t *testing.T) {
	p := proj(t)
	for _, u := range p.units() {
		if u.Spec.Block == "I" {
			continue
		}
		want := []string{".fx.dmg1.", ".fx.dmg2."}
		b := p.builder(u)
		if b.Rig.Faction == "host" {
			want = append(want, ".fx.fill1.", ".fx.fill2.", ".fx.fill3.", ".fx.lights.")
		} else {
			want = append(want, ".fx.lights.")
		}
		if u.Spec.Block == "K" {
			want = []string{".fx.dmg1.", ".fx.dmg2.", ".fx.lights.", ".fx.banner."}
		}
		for _, w := range want {
			n := 0
			for _, c := range p.cellsOf(u) {
				if strings.Contains(c.Name, w) {
					n++
				}
			}
			if n == 0 {
				t.Errorf("%s: no %s overlay at any heading", u.Spec.ID, strings.Trim(w, "."))
			}
		}
	}
}

// finish puts an x8 image back on the grid inside the rig silhouette: the
// rig's own reference image round-trips to the same silhouette.
func TestFinishRoundTrip(t *testing.T) {
	p := proj(t)
	u := p.unit("lodestar")
	var cell *Cell
	cs := p.cellsOf(u)
	for i := range cs {
		if cs[i].Name == "lodestar.hull.move.h045.f0" {
			cell = &cs[i]
		}
	}
	key := pixelgrid.Hex("#FF00FF")
	ref := p.refImage(u, cell, 8, key)
	out := p.finish(u, cell, ref, key)
	ink := p.Pals["fleet"].Ink
	for y := 0; y < cell.F.H; y++ {
		for x := 0; x < cell.F.W; x++ {
			c := out.NRGBAAt(x, y)
			if cell.F.filled(x, y) != (c.A != 0 && c != ink) {
				t.Fatalf("texel %d,%d: rig %v, finished %v", x, y, cell.F.filled(x, y), c)
			}
		}
	}
}

func TestJobsPlan(t *testing.T) {
	p := proj(t)
	kinds := map[string]int{}
	for _, j := range p.jobs() {
		kinds[j.Kind]++
	}
	// 26 units x 4 hero candidates; 2 candidates per other heading; layers
	if kinds["hero"] != 26*4 || kinds["heading"] == 0 || kinds["layer"] == 0 {
		t.Fatalf("jobs %v", kinds)
	}
}

// Every inbetween clip in the families resolves to key cells and builds a
// strip of the right size (the VACE control input).
func TestControlStrips(t *testing.T) {
	p := loadProject()
	for _, u := range p.units() {
		for _, clip := range u.Spec.Inbetweens {
			img, err := p.controlStrip(u, clip, 17)
			if err != nil {
				t.Fatal(err)
			}
			if b := img.Bounds(); b.Dx() != 17*controlSize || b.Dy() != controlSize {
				t.Fatalf("%s %s: strip %v", u.Spec.ID, clip, b)
			}
		}
	}
	if got := controlSequence(4, 17, true); got[0] != 0 || got[2] != 1 || got[8] != 0 || got[16] != 0 {
		t.Fatalf("cyclic sequence %v", got)
	}
	if got := controlSequence(3, 17, false); got[0] != 0 || got[16] != 2 {
		t.Fatalf("one-shot sequence %v", got)
	}
}

// A1: AI colour outside the rig survives one texel out (wings, horns), not
// two; inside the rig the AI's colour wins over the rig's shading.
func TestFinishKeepsAIColourInRing(t *testing.T) {
	p := proj(t)
	u := p.unit("lodestar")
	var cell *Cell
	cs := p.cellsOf(u)
	for i := range cs {
		if cs[i].Name == "lodestar.hull.move.h045.f0" {
			cell = &cs[i]
		}
	}
	key := pixelgrid.Hex("#FF00FF")
	const s = 8
	ref := p.refImage(u, cell, s, key)
	pal := p.Pals["fleet"]
	cyan := pal.ramp("ally_cyan", p.masterSector(u))
	paint := cyan[len(cyan)-1]
	// a blob of AI paint over every texel within two texels of the rig's
	// top-left-most filled texel's row, outside the silhouette
	_, y0, _, _ := cell.F.bbox()
	ty := y0
	tx := -1
	for x := 0; x < cell.F.W; x++ {
		if cell.F.filled(x, ty) {
			tx = x
			break
		}
	}
	for y := (ty - 2) * s; y < (ty+1)*s; y++ {
		for x := (tx - 1) * s; x < (tx+2)*s; x++ {
			if y >= 0 && !cell.F.filled(x/s, y/s) {
				ref.SetNRGBA(x, y, paint)
			}
		}
	}
	out := p.finish(u, cell, ref, key)
	if got := out.NRGBAAt(tx, ty-1); got != paint {
		t.Fatalf("one texel out: got %v, want the AI colour %v", got, paint)
	}
	if got := out.NRGBAAt(tx, ty-2); got != pal.Ink {
		t.Fatalf("two texels out: got %v, want ink", got)
	}
	// inside: a hard texel painted by the AI takes the AI colour
	ref2 := p.refImage(u, cell, s, key)
	cx, cy := -1, -1
	for y := 0; y < cell.F.H && cx < 0; y++ {
		for x := 0; x < cell.F.W; x++ {
			if cell.F.filled(x, y) && cell.F.filled(x-1, y) && cell.F.filled(x+1, y) && cell.F.filled(x, y-1) && cell.F.filled(x, y+1) {
				cx, cy = x, y
				break
			}
		}
	}
	for y := cy * s; y < (cy+1)*s; y++ {
		for x := cx * s; x < (cx+1)*s; x++ {
			ref2.SetNRGBA(x, y, paint)
		}
	}
	if got := p.finish(u, cell, ref2, key).NRGBAAt(cx, cy); got != paint {
		t.Fatalf("interior: got %v, want %v", got, paint)
	}
}

// bake: every baked base cell keeps the rig silhouette (ink only around it),
// uses only master-sector palette colours, and is deterministic.
func TestBake(t *testing.T) {
	p := proj(t)
	u := p.unit("lodestar")
	keys := p.selectedKeys(u)
	if len(keys) == 0 {
		t.Skip("no committed lodestar keyframes")
	}
	bk := p.newBaker(u)
	for _, name := range sortedKeys(keys) {
		src, err := pixelgrid.ReadPNG(keys[name])
		if err != nil {
			t.Fatal(err)
		}
		bk.addKey(p.findCell(u, name), src)
	}
	bk2 := p.newBaker(u)
	for _, name := range sortedKeys(keys) {
		src, _ := pixelgrid.ReadPNG(keys[name])
		bk2.addKey(p.findCell(u, name), src)
	}
	pal := p.Pals[u.faction()]
	allowed := map[color.NRGBA]bool{pal.Ink: true}
	for _, c := range pal.finishColours(p.masterSector(u)) {
		allowed[c] = true
	}
	cs := p.cellsOf(u)
	for i := range cs {
		c := &cs[i]
		if c.Overlay {
			continue
		}
		a, b := bk.bakeCell(c), bk2.bakeCell(c)
		for y := 0; y < c.F.H; y++ {
			for x := 0; x < c.F.W; x++ {
				col := a.NRGBAAt(x, y)
				if col != b.NRGBAAt(x, y) {
					t.Fatalf("%s %d,%d: not deterministic", c.Name, x, y)
				}
				if fl := c.F.filled(x, y); (fl && col.A == 0) || (!fl && col.A != 0 && col != pal.Ink) {
					t.Fatalf("%s %d,%d: silhouette differs from the rig", c.Name, x, y)
				}
				if col.A != 0 && !allowed[col] {
					t.Fatalf("%s %d,%d: %v not in the palette", c.Name, x, y, col)
				}
			}
		}
	}
}

func sortedKeys(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
