package main

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Cell geometry (texels). Plants stand bottom-centred on the last row; the
// wide cell leaves room for a toppled tree lying to the right.
const (
	CW, CH  = 48, 32
	Cols    = 16
	Rows    = 11
	Frames  = 8
	BaseX   = 24
	BaseY   = 31
	PartRow = 10
	PartPx  = 8
)

// Codes of the authoring grid.
const (
	Empty  = 0
	Body1  = 1 // darkest .. Body5 highlight
	Body5  = 5
	Accent = 6
	Glint  = 7
	Line   = 9 // outline
)

type Grid [CH][CW]int8

func (g *Grid) at(x, y int) int8 {
	if x < 0 || y < 0 || x >= CW || y >= CH {
		return Empty
	}
	return g[y][x]
}

func (g *Grid) set(x, y int, c int8) {
	if x >= 0 && y >= 0 && x < CW && y < CH {
		g[y][x] = c
	}
}

func body(c int8) bool { return c >= Body1 && c <= Glint }

// rng: a seeded LCG (deterministic everywhere).
type rng struct{ s uint64 }

func newRng(seed int) *rng { return &rng{uint64(seed)*6364136223846793005 + 1442695040888963407} }
func (r *rng) f() float64 {
	r.s = r.s*6364136223846793005 + 1442695040888963407
	return float64(r.s>>11) / float64(1<<53)
}
func (r *rng) i(n int) int { return int(r.f() * float64(n)) }

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------

func (g *Grid) line(x0, y0, x1, y1 float64, c int8, w int) {
	n := int(math.Max(math.Abs(x1-x0), math.Abs(y1-y0))*2) + 1
	for k := 0; k <= n; k++ {
		t := float64(k) / float64(n)
		x := x0 + (x1-x0)*t
		y := y0 + (y1-y0)*t
		for d := 0; d < w; d++ {
			g.set(int(math.Floor(x))+d-w/2, int(math.Floor(y)), c)
		}
	}
}

func (g *Grid) tri(ax, ay, bx, by, cx, cy float64, c int8) {
	minY := int(math.Floor(math.Min(ay, math.Min(by, cy))))
	maxY := int(math.Ceil(math.Max(ay, math.Max(by, cy))))
	minX := int(math.Floor(math.Min(ax, math.Min(bx, cx))))
	maxX := int(math.Ceil(math.Max(ax, math.Max(bx, cx))))
	edge := func(px, py, qx, qy, x, y float64) float64 { return (qx-px)*(y-py) - (qy-py)*(x-px) }
	area := edge(ax, ay, bx, by, cx, cy)
	for y := minY; y <= maxY; y++ {
		for x := minX; x <= maxX; x++ {
			px, py := float64(x)+.5, float64(y)+.5
			e0 := edge(bx, by, cx, cy, px, py) / area
			e1 := edge(cx, cy, ax, ay, px, py) / area
			e2 := edge(ax, ay, bx, by, px, py) / area
			if e0 >= 0 && e1 >= 0 && e2 >= 0 {
				g.set(x, y, c)
			}
		}
	}
}

func (g *Grid) ellipse(cx, cy, rx, ry float64, c int8) {
	for y := int(cy - ry - 1); y <= int(cy+ry+1); y++ {
		for x := int(cx - rx - 1); x <= int(cx+rx+1); x++ {
			dx, dy := (float64(x)+.5-cx)/rx, (float64(y)+.5-cy)/ry
			if dx*dx+dy*dy <= 1 {
				g.set(x, y, c)
			}
		}
	}
}

func (g *Grid) rect(x0, y0, x1, y1 int, c int8) {
	for y := y0; y <= y1; y++ {
		for x := x0; x <= x1; x++ {
			g.set(x, y, c)
		}
	}
}

// ---------------------------------------------------------------------------
// Species silhouettes (upright, unshaded: tones 2-4 and accents)
// ---------------------------------------------------------------------------

func buildPine(r *rng) Grid {
	var g Grid
	g.line(BaseX, BaseY, BaseX-1, 5, 2, 2)
	tiers := 6
	for k := 0; k < tiers; k++ {
		y := 27 - float64(k)*3.7
		half := 8.5 - float64(k)*1.2 + r.f()*.8
		top := y - 5.5
		g.tri(BaseX-half, y, BaseX+half, y+.6, BaseX-.5+r.f()-.5, top, 3)
		// needle tips droop at the ends
		g.set(int(BaseX-half), int(y)+1, 2)
		g.set(int(BaseX+half), int(y)+1, 2)
		// icicles under each tier
		for i := 0; i < 2; i++ {
			ix := int(BaseX - half + 2 + r.f()*(2*half-4))
			g.set(ix, int(y)+1, Accent)
			if r.f() < .5 {
				g.set(ix, int(y)+2, Accent)
			}
		}
	}
	g.set(BaseX-1, 3, 3)
	g.set(BaseX-1, 4, 3)
	g.set(BaseX-1, 2, Glint)
	return g
}

func buildCrystals(r *rng, tall bool) Grid {
	var g Grid
	n := 5 + r.i(2)
	for k := 0; k < n; k++ {
		base := float64(BaseX) - 6 + float64(k)*12/float64(n-1) + r.f() - .5
		lean := (base - BaseX) * .35
		h := 6 + r.f()*7
		if tall {
			h = 9 + r.f()*11
		}
		if k == n/2 {
			h += 4
		}
		w := 1.6 + r.f()*1.2
		tx, ty := base+lean, float64(BaseY)-h
		g.tri(base-w, BaseY+.5, base+w, BaseY+.5, tx, ty, 3)
		g.tri(base-w, BaseY+.5, tx, ty, tx-w*.6, ty+2.5, 4)
		g.set(int(tx), int(ty)+1, Glint)
	}
	// Rock collar.
	g.ellipse(BaseX, BaseY-.5, 8, 1.8, 2)
	return g
}

func buildScrap(r *rng) Grid {
	var g Grid
	// A bent solar panel (cell grid) propped on a broken truss, scrap beside.
	for v := 0; v <= 7; v++ {
		for u := 0; u <= 14; u++ {
			x := BaseX - 11 + u + v
			y := BaseY - 1 - v
			c := int8(3)
			if u%4 == 0 || v%4 == 0 {
				c = 2
			}
			g.set(x, y, c)
			if v == 7 && u%5 == 2 {
				g.set(x, y, Accent)
			}
		}
	}
	g.line(BaseX+4, BaseY-8, BaseX+9, BaseY, 4, 1)
	g.line(BaseX+6, BaseY-4, BaseX+11, BaseY-4, 4, 1)
	g.line(BaseX+9, BaseY, BaseX+13, BaseY-3, 2, 1)
	g.rect(BaseX+11, BaseY-2, BaseX+13, BaseY, 2)
	g.line(BaseX-14, BaseY, BaseX-12, BaseY-3, 4, 1)
	g.set(BaseX-2, BaseY-6, Glint)
	_ = r
	return g
}

func branch(g *Grid, r *rng, x, y, ang, length float64, depth int, w int) {
	x1 := x + math.Sin(ang)*length
	y1 := y - math.Cos(ang)*length
	g.line(x, y, x1, y1, 2, w)
	if depth == 0 {
		g.set(int(x1), int(y1), 3)
		return
	}
	nw := max(1, w-1)
	branch(g, r, x1, y1, ang-.45-r.f()*.3, length*.68, depth-1, nw)
	branch(g, r, x1, y1, ang+.4+r.f()*.3, length*.66, depth-1, nw)
}

func buildCinderTree(r *rng) Grid {
	var g Grid
	g.line(BaseX, BaseY, BaseX+1, BaseY-9, 3, 3)
	g.line(BaseX+1, BaseY-9, BaseX-1, BaseY-14, 3, 2)
	branch(&g, r, BaseX-1, BaseY-14, -.15, 6, 3, 2)
	// Ember cracks in the bark.
	g.set(BaseX, BaseY-3, Accent)
	g.set(BaseX+1, BaseY-6, Accent)
	g.set(BaseX, BaseY-11, Accent)
	// Root flare.
	g.line(BaseX-3, BaseY, BaseX, BaseY-2, 2, 1)
	g.line(BaseX+4, BaseY, BaseX+1, BaseY-2, 2, 1)
	return g
}

func buildBrush(r *rng, thorns int8) Grid {
	var g Grid
	g.ellipse(BaseX, BaseY-4, 9, 4.5, 2)
	for k := 0; k < 26; k++ {
		a := -math.Pi/2 + (r.f()-.5)*2.6
		l := 3 + r.f()*6
		x0 := BaseX + (r.f()-.5)*10
		y0 := float64(BaseY) - 2 - r.f()*3
		x1, y1 := x0+math.Cos(a)*l*1.3, y0+math.Sin(a)*l
		c := int8(3)
		if k%3 == 0 {
			c = 4
		}
		g.line(x0, y0, x1, y1, c, 1)
		if k%4 == 0 {
			g.set(int(x1), int(y1), thorns)
		}
	}
	return g
}

func buildFungus(r *rng) Grid {
	var g Grid
	for k, dx := range []float64{-5, 1, 6} {
		h := []float64{17, 24, 13}[k] + r.f()*2
		top := float64(BaseY) - h
		g.line(BaseX+dx, BaseY, BaseX+dx*1.15+r.f()-.5, top+2, 3, 1)
		rx := []float64{3.5, 4.5, 3}[k]
		g.ellipse(BaseX+dx*1.15, top+1, rx, 2.2, 4)
		g.rect(int(BaseX+dx*1.15-rx+.5), int(top+2), int(BaseX+dx*1.15+rx-.5), int(top+2), 2)
		g.set(int(BaseX+dx*1.15-1), int(top), Accent)
		g.set(int(BaseX+dx*1.15+1), int(top+1), Accent)
	}
	return g
}

func buildRubble(r *rng) Grid {
	var g Grid
	// A fallen fluted column segment and blocks.
	g.rect(BaseX-11, BaseY-5, BaseX+3, BaseY, 3)
	for x := BaseX - 10; x <= BaseX+2; x += 3 {
		g.rect(x, BaseY-4, x, BaseY-1, 2)
	}
	g.ellipse(BaseX+3, BaseY-2.5, 2, 3, 4)
	g.rect(BaseX+5, BaseY-4, BaseX+10, BaseY, 2)
	g.rect(BaseX+6, BaseY-7, BaseX+9, BaseY-5, 3)
	g.rect(BaseX-13, BaseY-2, BaseX-11, BaseY, 2)
	g.set(BaseX-6, BaseY-5, Glint)
	_ = r
	return g
}

func buildBroodStalk(r *rng) Grid {
	var g Grid
	g.line(BaseX, BaseY, BaseX+1, BaseY-16, 3, 3)
	for y := BaseY - 2; y > BaseY-16; y -= 3 {
		g.set(BaseX-1, y, 2)
		g.set(BaseX+1, y, 2)
	}
	g.ellipse(BaseX+1, BaseY-20, 4.5, 5.5, 3)
	g.ellipse(BaseX, BaseY-21, 2, 3, 4)
	g.set(BaseX+2, BaseY-18, Accent)
	g.set(BaseX, BaseY-10, Accent)
	g.set(BaseX+1, BaseY-6, Accent)
	g.line(BaseX-3, BaseY, BaseX-1, BaseY-2, 2, 1)
	g.line(BaseX+4, BaseY, BaseX+2, BaseY-2, 2, 1)
	_ = r
	return g
}

func build(e Species) Grid {
	r := newRng(e.Seed)
	switch e.ID {
	case "frost-pine":
		return buildPine(r)
	case "ice-crystal-shrub":
		return buildCrystals(r, false)
	case "ring-crystal":
		return buildCrystals(r, true)
	case "satellite-scrap":
		return buildScrap(r)
	case "cinder-tree":
		return buildCinderTree(r)
	case "ash-thorn":
		return buildBrush(r, Accent)
	case "grave-fungus":
		return buildFungus(r)
	case "ruin-rubble":
		return buildRubble(r)
	case "sinew-thorn":
		return buildBrush(r, Glint)
	case "brood-stalk":
		return buildBroodStalk(r)
	}
	fail(fmt.Errorf("no builder for %s", e.ID))
	return Grid{}
}

// ---------------------------------------------------------------------------
// Shading: upper-left light on the body ramp plus the AI texture
// ---------------------------------------------------------------------------

func aiTexture(id string, g *Grid) [CH][CW]int8 {
	var tex [CH][CW]int8
	src, err := readPNG(filepath.Join(root, "art/sprites/sources/vegetation", id+".png"))
	if err != nil {
		return tex
	}
	// Body bounding box.
	x0, y0, x1, y1 := CW, CH, -1, -1
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if body(g[y][x]) {
				x0, y0 = min(x0, x), min(y0, y)
				x1, y1 = max(x1, x), max(y1, y)
			}
		}
	}
	if x1 < 0 {
		return tex
	}
	w, h := x1-x0+1, y1-y0+1
	b := src.Bounds()
	lum := make([]float64, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			sx0 := b.Min.X + x*b.Dx()/w
			sx1 := max(sx0+1, b.Min.X+(x+1)*b.Dx()/w)
			sy0 := b.Min.Y + y*b.Dy()/h
			sy1 := max(sy0+1, b.Min.Y+(y+1)*b.Dy()/h)
			var s, n float64
			for yy := sy0; yy < sy1; yy++ {
				for xx := sx0; xx < sx1; xx++ {
					r, gg, bb, _ := src.At(xx, yy).RGBA()
					s += .2126*float64(r>>8) + .7152*float64(gg>>8) + .0722*float64(bb>>8)
					n++
				}
			}
			lum[y*w+x] = s / n
		}
	}
	hp := make([]float64, w*h)
	var sum, sq float64
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			var s, n float64
			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					xx, yy := min(w-1, max(0, x+dx)), min(h-1, max(0, y+dy))
					s += lum[yy*w+xx]
					n++
				}
			}
			v := lum[y*w+x] - s/n
			hp[y*w+x] = v
			sum += v
			sq += v * v
		}
	}
	n := float64(w * h)
	sd := math.Sqrt(math.Max(1e-9, sq/n-(sum/n)*(sum/n)))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			v := hp[y*w+x]
			if v > 1.4*sd {
				tex[y0+y][x0+x] = 1
			} else if v < -1.4*sd {
				tex[y0+y][x0+x] = -1
			}
		}
	}
	return tex
}

func shade(g Grid, tex [CH][CW]int8) Grid {
	out := g
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			c := g[y][x]
			if c < Body1 || c > Body5 {
				continue
			}
			v := int(c)
			if !body(g.at(x-1, y)) || !body(g.at(x, y-1)) {
				v++
			}
			if !body(g.at(x+1, y)) {
				v--
			}
			if y >= BaseY-1 {
				v--
			}
			v += int(tex[y][x])
			out[y][x] = int8(min(Body5, max(Body1, v)))
		}
	}
	return out
}

func outline(g Grid) Grid {
	out := g
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if g[y][x] != Empty {
				continue
			}
			if body(g.at(x-1, y)) || body(g.at(x+1, y)) || body(g.at(x, y-1)) || body(g.at(x, y+1)) {
				out[y][x] = Line
			}
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Frame transforms (nearest neighbour, about a pivot)
// ---------------------------------------------------------------------------

// rotate turns the part of g with y < cut (all of it when cut >= CH) by deg
// clockwise about (px, py); the rest stays.
func rotate(g Grid, deg, px, py float64, cut int) Grid {
	var out Grid
	a := deg * math.Pi / 180
	ca, sa := math.Cos(a), math.Sin(a)
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if y >= cut && g[y][x] != Empty {
				out[y][x] = g[y][x]
			}
		}
	}
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if out[y][x] != Empty {
				continue
			}
			// Inverse map the destination pixel centre.
			dx, dy := float64(x)+.5-px, float64(y)+.5-py
			sx := ca*dx + sa*dy + px
			sy := -sa*dx + ca*dy + py
			ix, iy := int(math.Floor(sx)), int(math.Floor(sy))
			if iy < cut && iy >= 0 {
				if c := g.at(ix, iy); c != Empty {
					out[y][x] = c
				}
			}
		}
	}
	return out
}

// squash scales heights about the base row and widens a little.
func squash(g Grid, ky, kx, shear float64) Grid {
	var out Grid
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			up := float64(BaseY) + .5 - (float64(y) + .5)
			sy := float64(BaseY) + .5 - up/ky
			lean := shear * (up / 12)
			sx := (float64(x)+.5-lean-BaseX)/kx + BaseX
			out[y][x] = g.at(int(math.Floor(sx)), int(math.Floor(sy)))
		}
	}
	return out
}

func sway(g Grid, px float64) Grid { return squash(g, 1, 1, px) }

func scatter(g Grid, r *rng, n int, c int8, xMin, xMax int) Grid {
	for k := 0; k < n; k++ {
		x := xMin + r.i(xMax-xMin+1)
		g.set(x, BaseY-r.i(2), c)
	}
	return g
}

func frames(e Species, up Grid) [Frames]Grid {
	r := newRng(e.Seed + 77)
	var f [Frames]Grid
	switch e.Kind {
	case "tree":
		cut := BaseY - 4
		f[0] = up
		f[1] = sway(up, 1)
		f[2] = rotate(up, 10, BaseX, BaseY+.5, CH)
		f[3] = rotate(up, 22, BaseX, BaseY+.5, CH)
		f[4] = rotate(up, 42, BaseX, float64(cut)+.5, cut)
		f[5] = rotate(up, 64, BaseX, float64(cut)+.5, cut)
		f[6] = scatter(rotate(up, 82, BaseX, float64(cut)+.5, cut), r, 4, 2, BaseX-6, BaseX+4)
		f[7] = scatter(rotate(up, 86, BaseX, float64(cut)+.5, cut), r, 3, 2, BaseX-5, BaseX+3)
	case "stalk":
		cut := BaseY - 3
		f[0] = up
		f[1] = sway(up, 1)
		f[2] = rotate(up, 14, BaseX, BaseY+.5, CH)
		f[3] = rotate(up, 28, BaseX, BaseY+.5, CH)
		f[4] = rotate(up, 52, BaseX, float64(cut)+.5, cut)
		f[5] = rotate(up, 78, BaseX, float64(cut)+.5, cut)
		f[6] = scatter(rotate(up, 94, BaseX, float64(cut)+.5, cut), r, 3, Accent, BaseX-6, BaseX+12)
		f[7] = rotate(up, 96, BaseX, float64(cut)+.5, cut)
	case "brush":
		f[0] = up
		f[1] = sway(up, 1)
		f[2] = squash(up, .82, 1.03, 2)
		f[3] = squash(up, .66, 1.07, 3)
		f[4] = squash(up, .52, 1.1, 3)
		f[5] = squash(up, .4, 1.13, 2)
		f[6] = squash(up, .32, 1.16, 1)
		f[7] = squash(up, .28, 1.18, 0)
	case "crystal":
		f[0] = up
		f[1] = up
		// The glint walks to another facet.
		for y := 0; y < CH; y++ {
			for x := 0; x < CW; x++ {
				if up[y][x] == Glint {
					f[1][y][x] = 4
					f[1].set(x-1, y+2, Glint)
				}
			}
		}
		f[2] = sway(up, 1)
		f[3] = crack(sway(up, 1), r)
		f[4] = shatter(crack(up, r), 1.5, 1, newRng(e.Seed+1))
		f[5] = shatter(up, 4, .75, newRng(e.Seed+2))
		f[6] = shatter(up, 7, .4, newRng(e.Seed+3))
		f[7] = scatter(stump(up, BaseY-3), r, 6, 3, BaseX-10, BaseX+11)
	case "debris":
		px := float64(BaseX + 11)
		f[0] = up
		f[1] = up
		f[2] = rotate(up, 5, px, BaseY+.5, CH)
		f[3] = rotate(up, 10, px, BaseY+.5, CH)
		f[4] = rotate(up, 16, px, BaseY+.5, CH)
		f[5] = rotate(up, 22, px, BaseY+.5, CH)
		f[6] = rotate(up, 26, px, BaseY+.5, CH)
		f[7] = rotate(up, 28, px, BaseY+.5, CH)
		for k := 2; k < Frames; k++ {
			f[k] = settle(f[k])
		}
	}
	return f
}

// settle drops a rotated shape back onto the base row.
func settle(g Grid) Grid {
	bottom := -1
	for y := CH - 1; y >= 0 && bottom < 0; y-- {
		for x := 0; x < CW; x++ {
			if g[y][x] != Empty {
				bottom = y
				break
			}
		}
	}
	shift := BaseY - bottom
	if bottom < 0 || shift == 0 {
		return g
	}
	var out Grid
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if g[y][x] != Empty {
				out.set(x, y+shift, g[y][x])
			}
		}
	}
	return out
}

// shatter flings each body pixel above the collar outward and down (a
// burst of shards), keeping a share of them.
func shatter(g Grid, amount, keep float64, r *rng) Grid {
	var out Grid
	for y := BaseY - 2; y < CH; y++ {
		out[y] = g[y]
	}
	for y := 0; y < BaseY-2; y++ {
		for x := 0; x < CW; x++ {
			c := g[y][x]
			if !body(c) || r.f() > keep {
				continue
			}
			up := float64(BaseY - y)
			dx := (float64(x)-BaseX)*.35*amount/4 + (r.f()-.5)*amount
			dy := amount * (.6 + .5*r.f()) * (1 - up/40) // shards fall
			out.set(x+int(math.Round(dx*1.4)), y+int(math.Round(dy)), c)
		}
	}
	return out
}

func crack(g Grid, r *rng) Grid {
	out := g
	for k := 0; k < 3; k++ {
		x := BaseX - 5 + r.i(11)
		for y := BaseY - 2; y > BaseY-12; y-- {
			if body(out.at(x, y)) {
				out[y][x] = Body1
			}
			if r.f() < .4 {
				x += r.i(3) - 1
			}
		}
	}
	return out
}

func stump(g Grid, from int) Grid {
	var out Grid
	for y := from; y < CH; y++ {
		out[y] = g[y]
	}
	return out
}

// ---------------------------------------------------------------------------
// Particles (8x8, two frames each)
// ---------------------------------------------------------------------------

type particle [PartPx][PartPx]int8

func particles() [6][2]particle {
	var p [6][2]particle
	dot := func(q *particle, x, y int, c int8) {
		if x >= 0 && y >= 0 && x < PartPx && y < PartPx {
			q[y][x] = c
		}
	}
	// dust: a soft puff, then a thinner one
	for y := 0; y < PartPx; y++ {
		for x := 0; x < PartPx; x++ {
			dx, dy := float64(x)-3.5, float64(y)-3.5
			d := dx*dx + dy*dy
			if d < 9 {
				p[0][0][y][x] = 2
				if d < 3 {
					p[0][0][y][x] = 3
				}
			}
			if d < 6 && (x+y)%2 == 0 {
				p[0][1][y][x] = 2
			}
		}
	}
	// leaves / needles
	for _, q := range [][3]int{{2, 3, 1}, {5, 5, 0}} {
		dot(&p[1][0], q[0], q[1], 4)
		dot(&p[1][0], q[0]+1, q[1]+q[2], 3)
	}
	dot(&p[1][1], 3, 4, 4)
	dot(&p[1][1], 4, 4, 3)
	// shards
	for _, q := range [][2]int{{3, 2}, {2, 3}, {3, 3}, {4, 3}, {3, 4}} {
		dot(&p[2][0], q[0], q[1], Glint)
	}
	dot(&p[2][0], 3, 3, 4)
	dot(&p[2][1], 3, 3, Glint)
	dot(&p[2][1], 4, 4, 4)
	// splinters
	for k := 0; k < 4; k++ {
		dot(&p[3][0], 2+k, 5-k, 3)
	}
	dot(&p[3][1], 3, 4, 3)
	dot(&p[3][1], 4, 3, 2)
	// spores
	dot(&p[4][0], 2, 2, Accent)
	dot(&p[4][0], 5, 4, Accent)
	dot(&p[4][0], 3, 6, 4)
	dot(&p[4][1], 4, 3, Accent)
	// ash with an ember
	dot(&p[5][0], 2, 3, 2)
	dot(&p[5][0], 5, 2, 2)
	dot(&p[5][0], 4, 5, Accent)
	dot(&p[5][1], 3, 4, 2)
	return p
}

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

func hexRGB(h string) [3]float64 {
	h = strings.TrimPrefix(h, "#")
	v, _ := strconv.ParseUint(h, 16, 32)
	return [3]float64{float64(v >> 16 & 255), float64(v >> 8 & 255), float64(v & 255)}
}

func luma(c [3]float64) float64 { return (.2126*c[0] + .7152*c[1] + .0722*c[2]) / 255 }

func chroma(c [3]float64) float64 {
	return (math.Max(c[0], math.Max(c[1], c[2])) - math.Min(c[0], math.Min(c[1], c[2]))) / 255
}

func chromaticity(c [3]float64) [3]float64 {
	s := c[0] + c[1] + c[2] + 1
	return [3]float64{c[0] / s, c[1] / s, c[2] / s}
}

func loadPalette(sector string) [][3]float64 {
	b, err := os.ReadFile(filepath.Join(root, "art/palettes/flyover-"+sector+".json"))
	must(err)
	var p struct {
		Colors []string `json:"colors"`
	}
	must(json.Unmarshal(b, &p))
	var out [][3]float64
	for _, h := range p.Colors {
		out = append(out, hexRGB(h))
	}
	return out
}

// colours maps codes to RGB: the body ramp from the sector palette (nearest
// luminance target, pulled toward the species hue), accents from the
// species accent at the glow cap, the outline from the darkest palette entry.
func colours(s Spec, e Species) map[int8]color.NRGBA {
	pal := loadPalette(e.Sector)
	hint := chromaticity(hexRGB(e.Hint))
	tab := map[int8]color.NRGBA{}
	used := map[int]bool{}
	for i, t := range s.Caps.BodyLuma {
		best, bestCost := 0, math.Inf(1)
		for k, c := range pal {
			if chroma(c) > s.Caps.Chroma {
				continue
			}
			ch := chromaticity(c)
			hd := math.Abs(ch[0]-hint[0]) + math.Abs(ch[1]-hint[1]) + math.Abs(ch[2]-hint[2])
			cost := math.Abs(luma(c)-t)/t + s.Caps.HintWeight*hd*4
			if used[k] {
				cost += .4
			}
			if cost < bestCost {
				best, bestCost = k, cost
			}
		}
		used[best] = true
		c := pal[best]
		tab[int8(Body1+i)] = color.NRGBA{uint8(c[0]), uint8(c[1]), uint8(c[2]), 255}
	}
	acc := hexRGB(e.Accent)
	scale := func(c [3]float64, target float64) color.NRGBA {
		k := target / math.Max(.01, luma(c))
		return color.NRGBA{uint8(math.Min(255, c[0]*k)), uint8(math.Min(255, c[1]*k)), uint8(math.Min(255, c[2]*k)), 255}
	}
	tab[Accent] = scale(acc, s.Caps.GlowLuma*.8)
	tab[Glint] = scale(acc, s.Caps.GlowLuma)
	darkest, dl := pal[0], 9.0
	for _, c := range pal {
		if l := luma(c); l < dl {
			darkest, dl = c, l
		}
	}
	tab[Line] = color.NRGBA{uint8(darkest[0]), uint8(darkest[1]), uint8(darkest[2]), 255}
	return tab
}

// Neutral particle colours (shared by every sector; tinted by the fog).
var particleTab = map[int8]color.NRGBA{
	2:      {0x3A, 0x3F, 0x48, 255},
	3:      {0x55, 0x5B, 0x65, 255},
	4:      {0x6E, 0x78, 0x80, 255},
	Accent: {0x9A, 0xB8, 0x8A, 255},
	Glint:  {0xA8, 0xC8, 0xE0, 255},
}

// ---------------------------------------------------------------------------
// Offline pack
// ---------------------------------------------------------------------------

func paint(img *image.NRGBA, g Grid, ox, oy int, tab map[int8]color.NRGBA, mirror bool) {
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			c := g[y][x]
			if c == Empty {
				continue
			}
			dx := x
			if mirror {
				dx = CW - 1 - x
			}
			img.SetNRGBA(ox+dx, oy+y, tab[c])
		}
	}
}

func cmdOffline() {
	s := loadSpec()
	atlas := image.NewNRGBA(image.Rect(0, 0, Cols*CW, Rows*CH))
	type meta struct {
		e    Species
		w, h int
	}
	var metas []meta
	for _, e := range s.Species {
		up := build(e)
		up = shade(up, aiTexture(e.ID, &up))
		fs := frames(e, up)
		tab := colours(s, e)
		for k := 0; k < Frames; k++ {
			g := outline(fs[k])
			paint(atlas, g, k*CW, e.Row*CH, tab, false)
			paint(atlas, g, (Frames+k)*CW, e.Row*CH, tab, true)
		}
		// Content box of the idle frame (outline included).
		g := outline(fs[0])
		x0, y0, x1 := CW, CH, -1
		for y := 0; y < CH; y++ {
			for x := 0; x < CW; x++ {
				if g[y][x] != Empty {
					x0, x1, y0 = min(x0, x), max(x1, x), min(y0, y)
				}
			}
		}
		metas = append(metas, meta{e, x1 - x0 + 1, CH - y0})
	}
	ps := particles()
	for k := 0; k < 6; k++ {
		for f := 0; f < 2; f++ {
			for y := 0; y < PartPx; y++ {
				for x := 0; x < PartPx; x++ {
					if c := ps[k][f][y][x]; c != Empty {
						atlas.SetNRGBA((k*2+f)*CW+x, PartRow*CH+y, particleTab[c])
					}
				}
			}
		}
	}
	writePNG(filepath.Join(root, "assets/images/flyover-vegetation.png"), atlas)

	var b strings.Builder
	b.WriteString("// GENERATED by tools/vegetation (go run . offline) — do not edit by hand.\n")
	b.WriteString("// Source: art/families/flyover-vegetation.json.\n\n")
	b.WriteString("/// One species row inside assets/images/flyover-vegetation.png; [w] and\n")
	b.WriteString("/// [h] are the idle frame's content box (texels, outline included).\n")
	b.WriteString("class VegetationSpecies {\n  const VegetationSpecies(this.sector, this.id, this.kind, this.row, this.w, this.h);\n")
	b.WriteString("  final int sector;\n  final String id, kind;\n  final int row, w, h;\n}\n\n")
	b.WriteString("abstract final class VegetationAtlas {\n")
	fmt.Fprintf(&b, "  static const cellW = %d, cellH = %d, columns = %d, frames = %d;\n", CW, CH, Cols, Frames)
	b.WriteString("  /// Frame columns (facing right; +8 mirrored).\n")
	b.WriteString("  static const idleA = 0, idleB = 1, bendA = 2, bendB = 3, breakA = 4, breakB = 5, breakC = 6, down = 7;\n")
	fmt.Fprintf(&b, "  static const particleRow = %d, particleSize = %d;\n", PartRow, PartPx)
	b.WriteString("  static const particles = ['dust', 'leaves', 'shards', 'splinters', 'spores', 'ash'];\n")
	b.WriteString("  static const species = <VegetationSpecies>[\n")
	sectors := map[string]int{"krybor": 0, "ringfall": 1, "ember": 2, "hollow": 3, "carrier": 4}
	for _, m := range metas {
		fmt.Fprintf(&b, "    VegetationSpecies(%d, '%s', '%s', %d, %d, %d),\n", sectors[m.e.Sector], m.e.ID, m.e.Kind, m.e.Row, m.w, m.h)
	}
	b.WriteString("  ];\n}\n")
	must(os.WriteFile(filepath.Join(root, "lib/game/vegetation_atlas.dart"), []byte(b.String()), 0o644))
	contact(s, atlas)
	fmt.Println("packed", len(metas), "species")
}

// contact: every row on its sector's ground tile at 3x, frames left to right.
func contact(s Spec, atlas *image.NRGBA) {
	const k = 3
	out := image.NewNRGBA(image.Rect(0, 0, Cols*CW*k/2, Rows*CH*k))
	for _, e := range s.Species {
		ground, _ := readPNG(filepath.Join(root, "assets/images/flyover-"+e.Sector+"-ground.png"))
		for y := 0; y < CH*k; y++ {
			for x := 0; x < Cols*CW*k/2; x++ {
				oy := e.Row*CH*k + y
				c := color.NRGBA{10, 12, 20, 255}
				if ground != nil {
					gb := ground.Bounds()
					r, g, bb, _ := ground.At(x/k%gb.Dx(), (y/k+e.Row*37)%gb.Dy()).RGBA()
					c = color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(bb >> 8), 255}
				}
				// Frames 0-7 only (the mirrors are implied).
				src := atlas.NRGBAAt(x/k, e.Row*CH+y/k)
				if src.A > 0 {
					c = src
				}
				out.SetNRGBA(x, oy, c)
			}
		}
	}
	for y := 0; y < CH*k; y++ {
		for x := 0; x < Cols*CW*k/2; x++ {
			c := color.NRGBA{10, 12, 20, 255}
			if src := atlas.NRGBAAt(x/k, PartRow*CH+y/k); src.A > 0 {
				c = src
			}
			out.SetNRGBA(x, PartRow*CH*k+y, c)
		}
	}
	writePNG(filepath.Join(root, "art/contact/flyover-vegetation-contact.png"), out)
}
