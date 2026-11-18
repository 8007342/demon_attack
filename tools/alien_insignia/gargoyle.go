package main

// gargoyle-insignia (openspec/changes/gargoyle-insignia): the rank ladder
// redrawn from fangs and wings, after the operator found the talons read as
// hearts (plan/operator-feedback-2026-11-17.md, I1). The shapes are hand
// authored on the same coarse grid as alien-insignia (1 glyph px = 2 art px
// = 1.35 CSS px at the 40-unit draw, 'o' bone, 'e' ember core, ink outline
// added). Picks and reasons: plan/render-runs/gargoyle-insignia.md.

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// rankGlyphs: the shipped ladder, in rank order (skirmisher .. sentinel).
// Key names are the atlas keys.
var rankGlyphs = []struct{ key, name, who string }{
	{"fang", "FANG", "R1 SKIRMISHER"},
	{"fang2", "TWIN FANGS", "R2 VETERAN"},
	{"wingfang", "WINGED FANG", "R3 HUNTER"},
	{"wingcrown", "WINGED CROWN", "R4 SENTINEL"},
}

func init() {
	// R1 fang: one tusk, root up-left, curving down to a tip that leans
	// right. Asymmetric on purpose (a mirror-symmetric mark at this size
	// reads as a heart or a face). It rhymes with the carrier's ivory
	// tusk-prongs: long, tapering, never a short round hook.
	glyphs["fang"] = []string{
		"oooo...",
		"ooooo..",
		".oooo..",
		"..oooo.",
		"...ooo.",
		"...ooo.",
		"....oo.",
		"....o..",
	}
	// R2 twin fangs: two fangs canted the same way and staggered, never a
	// mirrored pair (a mirrored pair converging is the heart's two lobes,
	// diverging it is a pair of vampire teeth). The count is the read.
	glyphs["fang2"] = []string{
		"ooo.......",
		"oooo..ooo.",
		".oooo.oooo",
		"..ooo..ooo",
		"..ooo..ooo",
		"...oo...oo",
		"...o....oo",
		"........o.",
	}
	// R3 winged fang: one long fang hanging from an ember-cored shoulder,
	// two bat wings swept up and out to sharp tips, scalloped trailing
	// edges. Much wider than tall, and the fang hangs clear below the wings,
	// so the envelope is a T, not a heart's rounded wedge.
	glyphs["wingfang"] = []string{
		"oo.........oo",
		"ooo.......ooo",
		".oooo.o.oooo.",
		"..ooooeoooo..",
		".o.o.ooo.o.o.",
		".....ooo.....",
		"......oo.....",
		"......oo.....",
		"......o......",
	}
	// R4 winged crown: wider wings and three fangs rising as a crown, the
	// centre one tallest, over an ember band. Points up where the hunter's
	// fang points down; widest and tallest mark of the ladder.
	glyphs["wingcrown"] = []string{
		".......o.......",
		"o...o..o..o...o",
		"oo..o.ooo.o..oo",
		"ooo.ooooooo.ooo",
		".ooooooeoooooo.",
		"..oo.ooooo.oo..",
		"..o.........o..",
	}
}

// checkGlyphs panics on a ragged glyph: every row of a shape must be as
// wide as its first (drawGlyph indexes by the first row's width).
func checkGlyphs() {
	for k, g := range glyphs {
		for j, r := range g {
			if len(r) != len(g[0]) {
				panic(fmt.Sprintf("glyph %s row %d: width %d != %d", k, j, len(r), len(g[0])))
			}
		}
	}
}

// --- readability metrics ---------------------------------------------------

// silhouette renders a glyph's outlined mask (fill + ink) at 1 px per
// glyph px.
func silhouette(shape []string) [][]bool {
	h, w := len(shape), len(shape[0])
	on := func(i, j int) bool { return i >= 0 && j >= 0 && i < w && j < h && shape[j][i] != '.' }
	m := make([][]bool, h+2)
	for j := -1; j <= h; j++ {
		m[j+1] = make([]bool, w+2)
		for i := -1; i <= w; i++ {
			near := false
			for dj := -1; dj <= 1; dj++ {
				for di := -1; di <= 1; di++ {
					near = near || on(i+di, j+dj)
				}
			}
			m[j+1][i+1] = near
		}
	}
	return m
}

// fillMask: the bone/ember pixels only (what reads against the ink).
func fillMask(shape []string) [][]bool {
	m := make([][]bool, len(shape))
	for j, r := range shape {
		m[j] = make([]bool, len(r))
		for i := range r {
			m[j][i] = r[i] != '.'
		}
	}
	return m
}

// normalise area-averages a mask into an n x n grid over its bounding
// box: the shape as a blurred glance sees it, size removed.
func normalise(m [][]bool, n int) []float64 {
	h, w := len(m), len(m[0])
	out := make([]float64, n*n)
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			var s, c float64
			for sy := y * h / n; sy < max((y+1)*h/n, y*h/n+1); sy++ {
				for sx := x * w / n; sx < max((x+1)*w/n, x*w/n+1); sx++ {
					if m[sy][sx] {
						s++
					}
					c++
				}
			}
			out[y*n+x] = s / c
		}
	}
	return out
}

// similarity is a soft IoU of two normalised masks (1 = same shape).
func similarity(a, b []float64) float64 {
	var in, un float64
	for i := range a {
		in += math.Min(a[i], b[i])
		un += math.Max(a[i], b[i])
	}
	return in / un
}

// mirror is how left-right symmetric a fill mask is (1 = a mirror image).
func mirror(m [][]bool) float64 {
	var same, all float64
	for _, r := range m {
		for i := range r {
			if r[i] || r[len(r)-1-i] {
				all++
				if r[i] == r[len(r)-1-i] {
					same++
				}
			}
		}
	}
	return same / all
}

// Reference shapes the ladder must not resemble (fill masks).
var lookalikes = map[string][]string{
	"HEART": {
		".oo.oo.",
		"ooooooo",
		"ooooooo",
		".ooooo.",
		"..ooo..",
		"...o...",
	},
	"SMILE": {
		"o.....o",
		"oo...oo",
		".ooooo.",
		"..ooo..",
	},
	"FACE": {
		"ooooooooo",
		"o.ee.ee.o",
		"ooooooooo",
		"o.o.o.o.o",
	},
}

type metricRow struct {
	key                      string
	heart, smile, face, mirr float64
	nearestKey               string
	nearest                  float64
	w, h                     int
}

// ladderMetrics scores each shipped glyph (and the retired ones, for the
// before/after) against the lookalikes and against each other.
func ladderMetrics(set map[string][]string, keys []string) []metricRow {
	const n = 12
	norm := map[string][]float64{}
	for _, k := range keys {
		norm[k] = normalise(fillMask(set[k]), n)
	}
	var out []metricRow
	for _, k := range keys {
		r := metricRow{key: k, w: len(set[k][0]), h: len(set[k])}
		r.heart = similarity(norm[k], normalise(fillMask(lookalikes["HEART"]), n))
		r.smile = similarity(norm[k], normalise(fillMask(lookalikes["SMILE"]), n))
		r.face = similarity(norm[k], normalise(fillMask(lookalikes["FACE"]), n))
		r.mirr = mirror(fillMask(set[k]))
		for _, o := range keys {
			if o == k {
				continue
			}
			// Distinctness keeps the size: two glyphs of one shape at
			// different sizes still differ at a glance.
			s := similarity(norm[k], norm[o]) * math.Min(
				float64(len(set[k][0])*len(set[k]))/float64(len(set[o][0])*len(set[o])),
				float64(len(set[o][0])*len(set[o]))/float64(len(set[k][0])*len(set[k])))
			if s > r.nearest {
				r.nearest, r.nearestKey = s, o
			}
		}
		out = append(out, r)
	}
	return out
}

func metricsText(rows []metricRow) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%-10s %5s %6s %6s %6s %6s  %s\n", "GLYPH", "WxH", "HEART", "SMILE", "FACE", "MIRROR", "NEAREST")
	for _, r := range rows {
		fmt.Fprintf(&b, "%-10s %2dx%-2d %6.2f %6.2f %6.2f %6.2f  %s %.2f\n",
			r.key, r.w, r.h, r.heart, r.smile, r.face, r.mirr, r.nearestKey, r.nearest)
	}
	return b.String()
}

// --- the review sheet ------------------------------------------------------

// legacy: the alien-insignia shapes as shipped before this change.
func legacyShapes() map[string][]string {
	return map[string][]string{
		"talon":   glyphs["talon"],
		"talon2":  stacked(glyphs["talon"], glyphs["talon"], 1),
		"ocellus": glyphs["ocellus"],
		"crown":   stacked(glyphs["crown"], glyphs["ocellus"], 2),
	}
}

var legacyKeys = []string{"talon", "talon2", "ocellus", "crown"}

func newShapes() map[string][]string {
	m := map[string][]string{}
	for _, g := range rankGlyphs {
		m[g.key] = glyphs[g.key]
	}
	return m
}

func newKeys() []string {
	var k []string
	for _, g := range rankGlyphs {
		k = append(k, g.key)
	}
	return k
}

// glyphImage renders one outlined glyph at [px] device px per glyph px.
func glyphImage(shape []string, px int, fill, core color.NRGBA) *image.NRGBA {
	c := newCanvas((len(shape[0])+2)*px, (len(shape)+2)*px, color.NRGBA{})
	drawGlyphPx(c, shape, 0, 0, px, fill, core)
	return c.img
}

// drawGlyphPx is drawGlyph at an arbitrary scale.
func drawGlyphPx(c *canvas, shape []string, x, y, px int, fill, core color.NRGBA) {
	h, w := len(shape), len(shape[0])
	on := func(i, j int) bool { return i >= 0 && j >= 0 && i < w && j < h && shape[j][i] != '.' }
	for j := -1; j <= h; j++ {
		for i := -1; i <= w; i++ {
			var p color.NRGBA
			switch {
			case on(i, j) && shape[j][i] == 'e':
				p = core
			case on(i, j):
				p = fill
			default:
				near := false
				for dj := -1; dj <= 1; dj++ {
					for di := -1; di <= 1; di++ {
						near = near || on(i+di, j+dj)
					}
				}
				if !near {
					continue
				}
				p = ink
			}
			c.rect(x+(i+1)*px, y+(j+1)*px, px, px, p)
		}
	}
}

// onCreature: one neutral-glide creature (species [kind], art px) with
// [shape] seated on its head (bottom-centre one art px above the skull),
// on a 96 art px canvas: the same placement as the ranks sheet.
func onCreature(atlas *image.NRGBA, kind int, shape []string, fill, core color.NRGBA) *image.NRGBA {
	c := newCanvas(96, 96, color.NRGBA{})
	c.blit(cell(atlas, kind, 0, glideCol), pad, pad, 1)
	if shape != nil {
		gw, gh := (len(shape[0])+2)*2, (len(shape)+2)*2
		drawGlyphPx(c, shape, pad+32-gw/2, pad+headTop[kind]-1-gh+2, 2, fill, core)
	}
	return c.img
}

// ingame is the dense formation from test/gargoyle_insignia_review_test.dart:
// the real scene without glyphs (bare), with the shipped glyphs (new), and
// where the painter placed each mark.
type ingame struct {
	bare, bareZoom, real, realZoom *image.NRGBA
	ArenaTop, BandTop              float64
	UnitsPerGlyphPx                float64
	Marks                          []ingameMark
}

type ingameMark struct {
	Key        string
	Rank       string // a rank name, or "cell" for a shield cell
	L, T, W, H float64
	A          float64
}

func loadIngame(dir string) *ingame {
	b, err := os.ReadFile(filepath.Join(dir, "dense-marks.json"))
	if err != nil {
		return nil
	}
	g := &ingame{}
	if err := json.Unmarshal(b, g); err != nil {
		panic(err)
	}
	g.bare = mustLoad(filepath.Join(dir, "dense-bare-360x780.png"))
	g.bareZoom = mustLoad(filepath.Join(dir, "dense-bare-zoom.png"))
	g.real = mustLoad(filepath.Join(dir, "dense-new-360x780.png"))
	g.realZoom = mustLoad(filepath.Join(dir, "dense-new-zoom.png"))
	return g
}

var rankIndex = map[string]int{"skirmisher": 0, "veteran": 1, "hunter": 2, "sentinel": 3}

func toneOf(key string) (color.NRGBA, color.NRGBA) {
	switch {
	case strings.HasSuffix(key, "/angry"):
		return gold, white
	case strings.HasSuffix(key, "/tell"):
		return white, white
	}
	return bone, ember
}

// seat composites one glyph set onto a copy of [base] at the painter's
// anchors (bottom-centre of each placed mark), at [k] device px per arena
// unit, with arena (0, [top]) at device y 0: nearest sampling, as the
// painter's drawAtlas (FilterQuality.none).
func (g *ingame) seat(base *image.NRGBA, set map[string][]string, keys []string, k, top float64) *image.NRGBA {
	c := &canvas{copyOf(base)}
	newSet := newShapes()
	// Cells first, glyphs over them (the painter's order).
	marks := append([]ingameMark{}, g.Marks...)
	sort.SliceStable(marks, func(i, j int) bool { return marks[i].Rank == "cell" && marks[j].Rank != "cell" })
	for _, m := range marks {
		var img *image.NRGBA
		var size float64
		if m.Rank == "cell" {
			fill := map[string]color.NRGBA{"cell/lit": cyan, "cell/spent": cyanLo, "cell/flash": white, "cell/rush": rushCyan}[m.Key]
			img = glyphImage(glyphs["cell"], 1, fill, fill)
			size = m.W / (float64(len(glyphs["cell"][0])+2) * g.UnitsPerGlyphPx)
		} else {
			ri := rankIndex[m.Rank]
			nk := newKeys()[ri]
			size = m.W / (float64(len(newSet[nk][0])+2) * g.UnitsPerGlyphPx)
			fill, core := toneOf(m.Key)
			img = glyphImage(set[keys[ri]], 1, fill, core)
		}
		u := g.UnitsPerGlyphPx * size * k // device px per glyph px
		gw := float64(img.Bounds().Dx()) * u
		gh := float64(img.Bounds().Dy()) * u
		x0 := (m.L+m.W/2)*k - gw/2
		y0 := (m.T+m.H-top)*k - gh
		if m.Rank == "cell" { // cells are placed by their centre
			y0 = (m.T+m.H/2-top)*k - gh/2
		}
		for py := int(math.Floor(y0)); py < int(math.Ceil(y0+gh)); py++ {
			for px := int(math.Floor(x0)); px < int(math.Ceil(x0+gw)); px++ {
				sx := int(math.Floor((float64(px) + .5 - x0) / u))
				sy := int(math.Floor((float64(py) + .5 - y0) / u))
				if sx < 0 || sy < 0 || sx >= img.Bounds().Dx() || sy >= img.Bounds().Dy() {
					continue
				}
				p := img.NRGBAAt(sx, sy)
				p.A = uint8(float64(p.A) * m.A)
				c.over(px, py, p)
			}
		}
	}
	return c.img
}

// meanDiff: mean absolute channel difference (0-255) of two same-size images.
func meanDiff(a, b *image.NRGBA) float64 {
	var s float64
	for i := range a.Pix {
		d := float64(a.Pix[i]) - float64(b.Pix[i])
		s += math.Abs(d)
	}
	return s / float64(len(a.Pix))
}

// gargoyleSheet: art/contact/gargoyle-insignia.png, old against new.
//  1. The ladder at 8x (to read the shape), 2x (the atlas: one device px
//     per art px) and 1x (one device px per glyph px), with the angry and
//     tell tones at 2x.
//  2. On the demons: each species wearing each rank at phone size, 40 CSS
//     px creature at DPR 2 and DPR 1 (area downscale).
//  3. In game: the dense formation from the real scene at phone 360 x 780
//     and a 2x close-up of its band (test/gargoyle_insignia_review_test.dart);
//     the old glyphs are seated at the same anchors the painter used.
//  4. The lookalike scores.
func gargoyleSheet(atlas *image.NRGBA, g *ingame) *image.NRGBA {
	oldS, newS := legacyShapes(), newShapes()
	sets := []struct {
		name string
		set  map[string][]string
		keys []string
	}{{"OLD", oldS, legacyKeys}, {"NEW", newS, newKeys()}}
	const W = 1530
	H := 80 + 2*170 + 40 + 4*96 + 50 + 140
	if g != nil {
		H += 800 + 70
	}
	c := newCanvas(W, H, bg)
	header(c, "GARGOYLE INSIGNIA - FANGS AND WINGS, OLD AGAINST NEW",
		"OPERATOR ROUND 5 / I1: THE TALONS READ AS HEARTS.  R0 DRONES WEAR NONE.  R1 FANG, R2 TWIN FANGS, R3 WINGED FANG, R4 WINGED CROWN.  CARRIER FORMS 1-4 TAKE R1-R4.")
	ranks := []string{"R1 SKIRMISHER", "R2 VETERAN", "R3 HUNTER", "R4 SENTINEL"}
	y := 80
	// 1. The ladder.
	for si, s := range sets {
		c.text(16, y+50, 4, s.name, label)
		x := 110
		for i, k := range s.keys {
			c.text(x, y, 2, ranks[i]+" - "+strings.ToUpper(k), dim)
			big := glyphImage(s.set[k], 8, bone, ember)
			c.blit(big, x, y+18, 1)
			bx := x + 17*8 + 10
			for t, tone := range []struct{ f, e color.NRGBA }{{bone, ember}, {gold, white}, {white, white}} {
				g2 := glyphImage(s.set[k], 2, tone.f, tone.e)
				c.blit(g2, bx, y+18+t*38, 1)
			}
			c.blit(glyphImage(s.set[k], 1, bone, ember), bx+40, y+18, 1)
			x += 17*8 + 10 + 34 + 30 + 160
			_ = si
		}
		y += 170
	}
	c.text(110, y-12, 2, "EACH: 8X  |  2X BONE / ANGRY / TELL (THE ATLAS)  |  1X", dim)
	y += 30
	// 2. On the demons, phone size.
	c.text(16, y, 3, "ON THE DEMONS AT PHONE SIZE: 40 CSS PX CREATURE AT DPR 2, THEN DPR 1", label)
	y += 26
	for kind := 0; kind < 4; kind++ {
		x := 16
		for _, s := range sets {
			c.text(x, y+40, 3, s.name, dim)
			x += 60
			for _, k := range s.keys {
				img := onCreature(atlas, kind, s.set[k], bone, ember)
				d2 := downscale(img, 120, 120).SubImage(image.Rect(14, 4, 106, 94)).(*image.NRGBA)
				c.blit(d2, x, y, 1)
				d1 := downscale(img, 60, 60).SubImage(image.Rect(7, 2, 53, 47)).(*image.NRGBA)
				c.blit(d1, x+94, y+22, 1)
				x += 94 + 48 + 10
			}
			x += 20
		}
		y += 96
	}
	y += 20
	// 3. In game.
	if g != nil {
		c.text(16, y, 3, "IN GAME: DENSE FORMATION, REAL SCENE, PHONE 360 X 780 AT 1:1, AND A 2X CLOSE-UP OF THE BAND", label)
		c.text(16, y+24, 2, "OLD: THE RETIRED GLYPHS SEATED AT THE SAME ANCHORS.  NEW: THE SHIPPED ATLAS AS THE GAME PAINTS IT.  ONE SKIRMISHER AND ONE VETERAN YIELD (OVERLAP RULE).", dim)
		y += 46
		oldPhone := g.seat(g.bare, oldS, legacyKeys, 1, -g.ArenaTop)
		oldZoom := g.seat(g.bareZoom, oldS, legacyKeys, 2, g.BandTop)
		c.blit(oldPhone, 16, y, 1)
		c.blit(g.real, 16+360+12, y, 1)
		c.text(24, y+8, 3, "OLD", label)
		c.text(16+360+12+8, y+8, 3, "NEW", label)
		zx := 16 + 2*(360+12)
		c.blit(oldZoom, zx, y, 1)
		c.blit(g.realZoom, zx, y+400, 1)
		c.text(zx+8, y+8, 3, "OLD 2X", label)
		c.text(zx+8, y+400+8, 3, "NEW 2X", label)
		y += 800 + 24
	}
	// 4. Scores.
	c.text(16, y, 3, "LOOKALIKE SCORES (SOFT IOU OF THE BLURRED FILL AGAINST A PIXEL HEART, SMILE, FACE; LOWER IS BETTER)", label)
	y += 26
	for si, s := range sets {
		rows := ladderMetrics(s.set, s.keys)
		for i, r := range rows {
			c.text(16+si*760, y+i*16, 2, fmt.Sprintf("%-4s %-10s HEART %.2f  SMILE %.2f  FACE %.2f  MIRROR %.2f", s.name, strings.ToUpper(r.key), r.heart, r.smile, r.face, r.mirr), dim)
		}
	}
	return c.img
}

// candidates: the shapes tried for each rank, kept so the picks in
// plan/render-runs/gargoyle-insignia.md can be re-rendered (`go run .
// candidates -root ../.. -out x.png`). The shipped pick is in glyphs.
var candidates = []struct {
	rank, name string
	shape      []string
}{
	{"R1", "A SLASH", []string{"oooo...", "ooooo..", ".oooo..", "..oooo.", "...ooo.", "...ooo.", "....oo.", "....o.."}},
	{"R1", "B SABRE", []string{"ooooo.", "oooooo", ".ooooo", "..oooo", "..oooo", "...ooo", "...oo.", "...o.."}},
	{"R1", "C TOOTH", []string{"ooooooo", ".oooooo", "..ooooo", "..oooo.", "...ooo.", "...ooo.", "....oo.", "....o.."}},
	{"R2", "A QUOTE", []string{"ooo.......", "oooo..ooo.", ".oooo.oooo", "..ooo..ooo", "..ooo..ooo", "...oo...oo", "...o....oo", "........o."}},
	{"R2", "B TEETH", []string{"ooooo......", ".oooo.ooooo", ".oooo..oooo", "..ooo..oooo", "..ooo...ooo", "...oo...ooo", "...o....oo.", "........o.."}},
	{"R2", "C MIRROR", []string{"oooo.oooo", "oooo.oooo", ".ooo.ooo.", ".ooo.ooo.", "..oo.oo..", "..o...o.."}},
	{"R3", "A WINGFANG", []string{"oo.........oo", "ooo.......ooo", ".oooo.o.oooo.", "..ooooeoooo..", ".o.o.ooo.o.o.", ".....ooo.....", "......oo.....", "......oo.....", "......o......"}},
	{"R3", "B ONE WING", []string{"oo.......", "ooo......", ".oooo.ooo", "..oooeoo.", ".o.o.ooo.", ".....oo..", ".....oo..", ".....o..."}},
	{"R4", "A WINGCROWN", []string{".......o.......", "o...o..o..o...o", "oo..o.ooo.o..oo", "ooo.ooooooo.ooo", ".ooooooeoooooo.", "..oo.ooooo.oo..", "..o.........o.."}},
	{"R4", "B CROWN TEETH", []string{"o...o..o..o...o", "oo..o.ooo.o..oo", "ooooooooooooooo", ".ooooooeoooooo.", "..o.o.o.o.o.o.."}},
}

// candidatesSheet: every candidate at 8x, at 2x, and on a creature at
// DPR 2 and DPR 1 phone size, with its lookalike scores.
func candidatesSheet(atlas *image.NRGBA) *image.NRGBA {
	return candidateList(atlas, candidates, "GARGOYLE INSIGNIA - CANDIDATES")
}

// candidateList renders one list of candidates (gargoyle-insignia's, or
// insignia-ranks' elite-grunt marks) and prints their scores.
func candidateList(atlas *image.NRGBA, candidates []struct {
	rank, name string
	shape      []string
}, title string) *image.NRGBA {
	set := map[string][]string{}
	var keys []string
	for _, c := range candidates {
		k := c.rank + " " + c.name
		set[k] = c.shape
		keys = append(keys, k)
	}
	fmt.Print(metricsText(ladderMetrics(set, keys)))
	rows := ladderMetrics(set, keys)
	const rowH = 150
	c := newCanvas(1300, 80+len(candidates)*rowH, bg)
	header(c, title, "8X, 2X, ON A CREATURE AT DPR 2 AND DPR 1.  SCORES: SOFT IOU AGAINST A PIXEL HEART / SMILE / FACE (LOWER IS BETTER).")
	for i, k := range keys {
		y := 80 + i*rowH
		c.text(16, y, 3, k, label)
		r := rows[i]
		c.text(16, y+30, 2, fmt.Sprintf("HEART %.2f  SMILE %.2f\nFACE %.2f  MIRROR %.2f", r.heart, r.smile, r.face, r.mirr), dim)
		c.blit(glyphImage(set[k], 8, bone, ember), 330, y, 1)
		c.blit(glyphImage(set[k], 2, bone, ember), 480, y+20, 1)
		for kind := 0; kind < 4; kind++ {
			img := onCreature(atlas, kind, set[k], bone, ember)
			c.blit(downscale(img, 120, 120), 540+kind*190, y, 1)
			c.blit(downscale(img, 60, 60), 540+kind*190+122, y+30, 1)
		}
	}
	return c.img
}
