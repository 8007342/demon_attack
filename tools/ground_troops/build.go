package main

// Texel-grid authoring of the ground-troops atlas. Every silhouette and
// frame is built from primitives (discs, thick lines, triangles) on a
// 32x24 code grid; shading is an upper-left light on each material ramp
// plus the selected keyframe's -1/0/+1 high-pass texture on the body ramp.

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strings"
)

const (
	CW, CH = 32, 24
	Cols   = 12
	Rows   = 6
	BaseY  = CH - 1
)

// Material codes. Each ramp is dark -> light.
const (
	Empty int8 = iota
	B1
	B2
	B3
	B4
	B5 // body / hide (demons) or armour (allies)
	A1
	A2
	A3 // attire: vest, webbing, fatigues, backpack
	I1
	I2
	I3 // iron: helmets, weapons, treads
	W1
	W2
	W3 // accent glow: warm for demons, cyan for allies
	Line
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

func group(c int8) int {
	switch {
	case c >= B1 && c <= B5:
		return 1
	case c >= A1 && c <= A3:
		return 2
	case c >= I1 && c <= I3:
		return 3
	case c >= W1 && c <= W3:
		return 4
	}
	return 0
}

func (g *Grid) disc(cx, cy, rx, ry float64, c int8) {
	for y := int(cy - ry - 1); y <= int(cy+ry+1); y++ {
		for x := int(cx - rx - 1); x <= int(cx+rx+1); x++ {
			dx, dy := (float64(x)+.5-cx)/rx, (float64(y)+.5-cy)/ry
			if dx*dx+dy*dy <= 1 {
				g.set(x, y, c)
			}
		}
	}
}

func (g *Grid) line(x0, y0, x1, y1 float64, c int8, w float64) {
	n := int(math.Max(math.Abs(x1-x0), math.Abs(y1-y0))*3) + 1
	for i := 0; i <= n; i++ {
		t := float64(i) / float64(n)
		x, y := x0+(x1-x0)*t, y0+(y1-y0)*t
		if w <= 1 {
			g.set(int(math.Floor(x)), int(math.Floor(y)), c)
		} else {
			g.disc(x, y, w/2, w/2, c)
		}
	}
}

func (g *Grid) tri(ax, ay, bx, by, cx, cy float64, c int8) {
	minY, maxY := math.Min(ay, math.Min(by, cy)), math.Max(ay, math.Max(by, cy))
	minX, maxX := math.Min(ax, math.Min(bx, cx)), math.Max(ax, math.Max(bx, cx))
	for y := int(minY); y <= int(maxY); y++ {
		for x := int(minX); x <= int(maxX); x++ {
			px, py := float64(x)+.5, float64(y)+.5
			d1 := (px-bx)*(ay-by) - (ax-bx)*(py-by)
			d2 := (px-cx)*(by-cy) - (bx-cx)*(py-cy)
			d3 := (px-ax)*(cy-ay) - (cx-ax)*(py-ay)
			neg := d1 < 0 || d2 < 0 || d3 < 0
			pos := d1 > 0 || d2 > 0 || d3 > 0
			if !(neg && pos) {
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

// recolour replaces every pixel of group gr inside the box with c.
func (g *Grid) recolour(x0, y0, x1, y1, gr int, c int8) {
	for y := y0; y <= y1; y++ {
		for x := x0; x <= x1; x++ {
			if group(g.at(x, y)) == gr {
				g.set(x, y, c)
			}
		}
	}
}

type rng struct{ s uint64 }

func newRng(seed int) *rng { return &rng{uint64(seed)*6364136223846793005 + 1442695040888963407} }
func (r *rng) f() float64 {
	r.s = r.s*6364136223846793005 + 1442695040888963407
	return float64(r.s>>11) / float64(1<<53)
}

// ---------------------------------------------------------------------------
// Poses
// ---------------------------------------------------------------------------

type pose struct {
	walk   int  // 0-3 stride phase
	stride float64
	aim    bool // weapon levelled (kneeling for allies)
	fire   bool
	hit    bool
}

func strideOf(p pose) (float64, float64, int) {
	ph := float64(p.walk) * math.Pi / 2
	s := math.Sin(ph) * p.stride
	lift := 0
	if math.Cos(ph) > .3 {
		lift = 1
	}
	bob := 0
	if p.walk%2 == 1 {
		bob = -1
	}
	return s, float64(bob), lift
}

// digitigrade leg from the hip to a foot at fx.
func (g *Grid) leg(hx, hy, fx float64, lift int, c int8, thick float64) {
	ky := hy + 3
	g.line(hx, hy, hx+1.2, ky, c, thick+.6)
	fy := float64(BaseY) - float64(lift)
	g.line(hx+1.2, ky, fx-.8, fy-1.4, c, thick)
	g.line(fx-.8, fy-1.4, fx, fy, c, 1)
	g.line(fx, fy, fx+1.6, fy, c, 1)
}

// grunt: a gargoyle-demon soldier (side-on, facing right): a big horned
// head under a small iron helmet, glowing eye, snout and fang, a vest and
// webbing over a hunched stone body, a folded bat wing, a barbed tail and
// digitigrade legs. [brute]: the stocky rocket trooper with ram horns and a
// launcher tube over the shoulder.
func grunt(p pose, brute bool) Grid {
	var g Grid
	s, bob, lift := strideOf(p)
	kx := 0.0
	if p.aim {
		bob += 1
	}
	if p.hit {
		kx = -1
	}
	hx, hy := 15+kx, 18+bob // hip
	tw := 1.3
	if brute {
		tw = 1.9
	}
	// Barbed tail.
	g.line(hx-2.5, hy, hx-6, hy+1.8, B2, 1.3)
	g.line(hx-6, hy+1.8, hx-8, hy+3.6, B2, 1)
	g.tri(hx-9.8, hy+4.6, hx-7.6, hy+2.8, hx-7.8, hy+5.2, B2)
	// Back leg (darker).
	g.leg2(hx-.6, hy, hx-s-.6, 1-lift, B2, tw)
	// Folded bat wing: membrane with a finger bone.
	if brute {
		g.tri(hx-1, hy-6.5, hx-5, hy-.5, hx-1.2, hy-.8, B2)
	} else {
		g.tri(hx-1, hy-6.5, hx-5.2, hy+.2, hx-1.4, hy-.4, B2)
		g.line(hx-1, hy-6.5, hx-4.6, hy-.2, B1, 1)
	}
	// Body.
	if brute {
		g.disc(hx-.2, hy-3.4, 4.4, 3.9, B3)
		g.disc(hx+.6, hy-5.2, 4.0, 2.6, B3)
	} else {
		g.disc(hx, hy-3, 3.2, 3.3, B3)
		g.disc(hx+.6, hy-4.6, 2.8, 2.2, B3)
	}
	// Front leg.
	g.leg2(hx+.6, hy, hx+s+.6, lift, B3, tw)
	// Vest and webbing.
	g.recolour(int(hx-6), int(hy-6), int(hx+6), int(hy-1), 1, A2)
	for x := int(hx - 5); x <= int(hx+5); x++ {
		if group(g.at(x, int(hy-1))) == 2 {
			g.set(x, int(hy-1), A1)
		}
	}
	g.set(int(hx-2), int(hy-1), A3)
	g.set(int(hx+2), int(hy-1), A3)
	g.line(hx-2, hy-6, hx+2, hy-1.5, A1, 1)
	// Head.
	var headX, headY float64
	if brute {
		headX, headY = hx+5, hy-6.2
	} else {
		headX, headY = hx+2.4, hy-8.6
	}
	if !brute {
		// Horns sweep back from under the helmet.
		g.line(headX-2.2, headY-1.6, headX-4.8, headY-4.6, B5, 1.4)
		g.line(headX-4.8, headY-4.6, headX-5, headY-6, B4, 1)
	}
	g.disc(headX, headY, 3.1, 2.7, B3)
	g.rect(int(headX+2), int(headY-.4), int(headX+3.6), int(headY+1.4), B3) // snout
	g.set(int(headX+3.6), int(headY-.2), B4)                                 // nostril ridge
	g.line(headX+1, headY+1.6, headX+3.6, headY+1.6, B1, 1)                  // mouth
	g.set(int(headX+3), int(headY+2.2), B5)                                  // fang
	ey := headY - .6
	if !brute {
		ey = headY + .4
	}
	eye := func() {
		g.set(int(headX+1), int(ey), W3)
		g.set(int(headX+2), int(ey), W2)
	}
	if brute {
		// Ram horns curling round the ear.
		g.line(headX-1.4, headY-2.2, headX-3.6, headY-2.8, B5, 1.4)
		g.line(headX-3.6, headY-2.8, headX-4.2, headY-.4, B5, 1.2)
		g.line(headX-4.2, headY-.4, headX-3, headY+.8, B4, 1)
		// Iron skull cap.
		g.disc(headX-.2, headY-2.4, 2.6, 1.2, I2)
	} else {
		g.disc(headX-.4, headY-2.4, 3.3, 1.5, I2) // helmet
		g.line(headX-3.6, headY-1.4, headX+2.6, headY-1.4, I1, 1)
		g.set(int(headX-.4), int(headY-3.6), I3)
	}
	eye()
	// Weapon.
	if brute {
		ty := hy - 10.2
		g.line(hx-7, ty+.5, hx+8.5, ty-.3, I2, 3)
		g.line(hx-7, ty-.8, hx+8.5, ty-1.4, I3, 1)
		g.rect(int(hx+8), int(ty-2), int(hx+9), int(ty+1), W1) // warhead ring
		g.rect(int(hx-8), int(ty-1), int(hx-7), int(ty+1), I1) // venturi
		g.line(hx+2, ty+1.6, hx+3.6, hy-4, B3, 1.5)            // arm
		if p.fire {
			g.disc(hx+11, ty-.4, 1.8, 1.8, W2)
			g.disc(hx+11, ty-.4, 1, 1, W3)
			g.disc(hx-9.6, ty+.4, 1.6, 1.3, W1) // backblast
		}
	} else if p.aim || p.fire {
		y := hy - 4.6
		g.line(hx-2, y+.8, hx+10.5, y, I1, 1)
		g.line(hx+2, y+.5, hx+6, y+.3, I2, 1.6)
		g.disc(hx+3.6, y+1.2, 1.1, 1, B3) // hands
		if p.fire {
			g.disc(hx+12, y, 1.6, 1.2, W2)
			g.set(int(hx+12), int(y), W3)
			g.set(int(hx+13.4), int(y), W2)
		}
	} else {
		// Port arms while marching.
		g.line(hx-3.5, hy+.2, hx+6.5, hy-6.6, I1, 1)
		g.line(hx-.5, hy-2, hx+2.8, hy-4.4, I2, 1.6)
		g.disc(hx+1.8, hy-2.8, 1.1, 1, B3)
	}
	if p.hit {
		for y := 0; y < CH; y++ {
			for x := 0; x < CW; x++ {
				if c := g[y][x]; group(c) == 1 && c < B5 {
					g[y][x] = c + 1
				}
			}
		}
	}
	return g
}

// leg2: a short digitigrade leg from the hip to a foot at fx.
func (g *Grid) leg2(hx, hy, fx float64, lift int, c int8, thick float64) {
	fy := float64(BaseY) - float64(lift)
	ky := hy + 2.2
	g.line(hx, hy, hx+1, ky, c, thick+.6)
	g.line(hx+1, ky, fx-.6, fy-1.2, c, thick)
	g.line(fx-.6, fy-1.2, fx, fy, c, 1)
	g.line(fx, fy, fx+1.8, fy, c, 1)
}

// fallen: the trooper topples and cracks (stone, never blood).
func fallen(src Grid, r *rng) Grid {
	g := rotate(src, -62, 15, float64(BaseY), CH)
	// Drop to the ground line.
	low := 0
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if g[y][x] != Empty {
				low = y
			}
		}
	}
	var out Grid
	d := BaseY - low
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if g[y][x] != Empty && y+d >= 0 && y+d < CH {
				out[y+d][x] = g[y][x]
			}
		}
	}
	for k := 0; k < 4; k++ {
		x, y := 8+int(r.f()*16), 16+int(r.f()*7)
		if group(out.at(x, y)) == 1 {
			out.set(x, y, W1)
		}
	}
	return out
}

// rubble: what is left, a cracked stone heap with glowing fissures, a
// dropped helmet and a broken horn.
func rubble(r *rng, brute bool) Grid {
	var g Grid
	w := 6.0
	if brute {
		w = 7.5
	}
	g.disc(15, 22, w, 2.2, B2)
	for k := 0; k < 9; k++ {
		x, y := 15+(r.f()-.5)*2*w, 20.5+r.f()*2.5
		c := B3
		if k%3 == 0 {
			c = B4
		}
		g.disc(x, y, 1+r.f(), .9+r.f()*.6, c)
	}
	g.disc(20.5, 21.5, 2.2, 1.3, I2)
	g.line(9, 21, 7.5, 19.5, B5, 1)
	for k := 0; k < 5; k++ {
		x := int(10 + r.f()*10)
		g.set(x, 22, W1)
		if k < 2 {
			g.set(x, 21, W2)
		}
	}
	return g
}

// tank: the demon heavy tank (side-on, facing right).
func tank(f int, fire, recoil, wreck bool, r *rng) Grid {
	var g Grid
	// Treads.
	g.rect(4, 18, 27, 22, I1)
	g.disc(4.5, 20.5, 2.5, 2.5, I1)
	g.disc(27.5, 20.5, 2.5, 2.5, I1)
	for k, wx := range []float64{6.5, 11, 15.5, 20, 24.5} {
		g.disc(wx, 20.6, 1.7, 1.7, I2)
		if (k+f)%2 == 0 {
			g.set(int(wx), 20, I3)
		} else {
			g.set(int(wx), 21, I3)
		}
	}
	for x := 3 + f%4; x < 30; x += 4 {
		g.set(x, 18, I2) // links crawl
		if !wreck {
			g.set(x, 23, B5) // spiked tread
		}
	}
	// Hull with a gargoyle prow.
	g.tri(3, 18, 29, 18, 26, 12.5, B3)
	g.tri(3, 18, 26, 12.5, 6, 12.5, B3)
	g.tri(26, 12.5, 29, 18, 31, 15.5, B3)
	g.line(6, 12.5, 26, 12.5, B4, 1)
	g.set(28, 14, W3) // prow eye
	g.set(29, 14, W2)
	g.set(30, 17, B5) // fangs
	g.set(28, 17, B5)
	g.line(27, 13, 29, 10.5, B5, 1) // prow horn
	g.set(29, 10, B4)
	// Furnace vents.
	for k, vx := range []int{9, 12, 15, 18} {
		c := W2
		if (k+f)%3 == 0 {
			c = W3
		}
		if wreck {
			c = W1
		}
		g.set(vx, 15, c)
		g.set(vx, 16, W1)
	}
	// Turret, horned mantlet and cannon.
	tx := 15.0
	if recoil {
		tx = 14
	}
	g.disc(tx, 10.6, 6, 2.6, B3)
	g.line(tx-5, 9, tx+4, 8.6, B4, 1)
	g.line(tx+5, 9.6, tx+6.5, 6.8, B5, 1.2) // mantlet horn
	g.line(tx+6.5, 6.8, tx+5, 5.4, B5, 1)
	g.set(tx2(tx+3), 10, W2) // gunner's eye slit
	end := 31.0
	if recoil {
		end = 29
	}
	if wreck {
		g.line(tx+5, 11, end-2, 13.5, I2, 1.6) // drooping barrel
	} else {
		g.line(tx+5, 10.4, end, 9.6, I2, 1.8)
		g.line(tx+5, 9.6, end, 8.9, I3, 1)
		g.rect(int(end)-1, 8, int(end), 11, I1)
	}
	if fire {
		g.disc(31, 9.5, 1.6, 2.2, W2)
		g.set(31, 9, W3)
		g.set(31, 10, W3)
	}
	if wreck {
		for y := 0; y < CH; y++ {
			for x := 0; x < CW; x++ {
				if c := g[y][x]; group(c) == 1 && c > B1 {
					g[y][x] = c - 1
				}
			}
		}
		// Torn deck and holes with embers.
		for x := 6; x < 25; x++ {
			if r.f() < .35 {
				g.set(x, 12+int(r.f()*2), Empty)
			}
		}
		for k := 0; k < 4; k++ {
			x, y := 8+int(r.f()*16), 13+int(r.f()*4)
			g.set(x, y, W1)
			if k%2 == f%2 {
				g.set(x, y-1, W2)
			}
		}
	}
	return g
}

func tx2(v float64) int { return int(v) }

// trooper: an allied soldier seen from behind, walking up the plane.
func trooper(p pose, rocket bool) Grid {
	var g Grid
	s, bob, lift := strideOf(p)
	cx := 16.0
	base := float64(BaseY)
	if p.aim || p.fire {
		// Kneeling: one knee down, body lowered.
		g.rect(13, 19, 15, 21, A2)
		g.rect(13, 22, 15, 23, I1)
		g.rect(17, 21, 19, 22, A2)
		g.rect(17, 23, 19, 23, I1)
		bob = 3
	} else {
		// From behind, the forward leg reads shorter (its foot is further up
		// the plane); the planted one reaches the ground row.
		lf := base - 1.2*s - float64(lift)
		rf := base + 1.2*s - float64(1-lift)
		g.line(14.5, 17+bob, 14.2, math.Min(base, lf), A2, 2)
		g.line(17.5, 17+bob, 17.8, math.Min(base, rf), A2, 2)
		g.rect(13, int(math.Min(base, lf)), 15, int(math.Min(base, lf)), I1)
		g.rect(17, int(math.Min(base, rf)), 19, int(math.Min(base, rf)), I1)
	}
	y0 := 11 + bob
	// Torso armour and arms.
	g.disc(cx, y0+1.5, 3.6, 4.2, B3)
	g.line(cx-3.6, y0, cx-4.4, y0+4, B3, 1.6)
	g.line(cx+3.6, y0, cx+4.4, y0+3.6, B3, 1.6)
	// Backpack with a cyan status light.
	g.rect(int(cx-2), int(y0-1.5), int(cx+2), int(y0+3.5), A2)
	g.rect(int(cx-2), int(y0-1.5), int(cx+2), int(y0-1.5), A3)
	g.set(int(cx+1), int(y0+1), W2)
	g.rect(int(cx-2), int(y0+3.5), int(cx+2), int(y0+3.5), A1)
	// Helmet with the visor glinting at the side.
	g.disc(cx, y0-4, 2.7, 2.4, B4)
	g.line(cx-2.6, y0-2.4, cx+2.6, y0-2.4, B2, 1)
	g.set(int(cx+2.4), int(y0-3.4), W3)
	// Weapon, pointing up the plane (up the screen).
	if rocket {
		ty := y0 - 6.5
		if p.aim || p.fire {
			ty = y0 - 8
		}
		g.line(cx+3.4, y0+4.5, cx+4.6, ty, I2, 2.2)
		g.line(cx+2.8, y0+4.5, cx+4, ty, I3, 1)
		g.rect(int(cx+3.6), int(ty-1), int(cx+5.2), int(ty), W1)
		if p.fire {
			g.disc(cx+4.6, ty-2, 1.6, 1.6, W2)
			g.set(int(cx+4.6), int(ty-2), W3)
			g.disc(cx+3.2, y0+6.5, 1.6, 1.2, I1) // backblast toward the camera
		}
	} else {
		top := y0 - 5.5
		if p.aim || p.fire {
			top = y0 - 8.5
		}
		g.line(cx+3.2, y0+3, cx+5.2, top, I1, 1)
		g.line(cx+3.6, y0+1.5, cx+4.4, y0-1, I2, 1.4)
		if p.fire {
			g.disc(cx+5.4, top-1.2, 1.4, 1.4, W2)
			g.set(int(cx+5.4), int(top-1.2), W3)
		}
	}
	if p.hit {
		for y := 0; y < CH; y++ {
			for x := 0; x < CW; x++ {
				if c := g[y][x]; group(c) == 1 && c < B5 {
					g[y][x] = c + 1
				}
			}
		}
		g.set(int(cx-2), int(y0), W3)
		g.set(int(cx+3), int(y0-2), W2)
	}
	return g
}

// ---------------------------------------------------------------------------
// Frame transforms
// ---------------------------------------------------------------------------

// rotate turns the part of g with y < cut by deg clockwise about (px, py).
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
			fx, fy := float64(x)+.5-px, float64(y)+.5-py
			sx := ca*fx + sa*fy + px
			sy := -sa*fx + ca*fy + py
			ix, iy := int(math.Floor(sx)), int(math.Floor(sy))
			if iy < cut {
				if c := g.at(ix, iy); c != Empty {
					out[y][x] = c
				}
			}
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Shading
// ---------------------------------------------------------------------------

func aiTexture(id string, g *Grid) [CH][CW]int8 {
	var tex [CH][CW]int8
	src, err := readPNG(filepath.Join(root, "art/sprites/sources/ground-troops", id+".png"))
	if err != nil {
		return tex
	}
	x0, y0, x1, y1 := CW, CH, -1, -1
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if group(g[y][x]) == 1 {
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

func ramp(gr int) (int8, int8) {
	switch gr {
	case 1:
		return B1, B5
	case 2:
		return A1, A3
	case 3:
		return I1, I3
	}
	return 0, 0
}

// shade lights every material from the upper left: +1 under an open top
// or left edge, -1 at an open right or bottom edge, and the AI texture on
// the body ramp.
func shade(g Grid, tex [CH][CW]int8) Grid {
	out := g
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			c := g[y][x]
			gr := group(c)
			lo, hi := ramp(gr)
			if lo == 0 {
				continue
			}
			v := int(c)
			if group(g.at(x, y-1)) != gr || group(g.at(x-1, y)) != gr {
				v++
			}
			if group(g.at(x+1, y)) != gr && g.at(x+1, y) == Empty {
				v--
			}
			if group(g.at(x, y+1)) != gr && g.at(x, y+1) == Empty {
				v--
			}
			if gr == 1 {
				v += int(tex[y][x])
			}
			out[y][x] = int8(min(int(hi), max(int(lo), v)))
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
			if g.at(x-1, y) > Empty && g.at(x-1, y) != Line ||
				g.at(x+1, y) > Empty && g.at(x+1, y) != Line ||
				g.at(x, y-1) > Empty && g.at(x, y-1) != Line ||
				g.at(x, y+1) > Empty && g.at(x, y+1) != Line {
				out[y][x] = Line
			}
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

func walkPose(f int, stride float64) pose { return pose{walk: f, stride: stride} }

// frames of one unit row; nil cells stay empty.
func rowFrames(u Unit) []*Grid {
	r := newRng(u.Seed)
	var raw []Grid
	switch u.Kind {
	case "grunt", "rocketeer":
		brute := u.Kind == "rocketeer"
		for f := 0; f < 4; f++ {
			raw = append(raw, grunt(walkPose(f, 2.4), brute))
		}
		raw = append(raw,
			grunt(pose{aim: true}, brute),
			grunt(pose{aim: true, fire: true}, brute),
			grunt(pose{hit: true, stride: 1}, brute),
			fallen(grunt(pose{hit: true}, brute), r),
			rubble(r, brute))
	case "tank":
		for f := 0; f < 4; f++ {
			raw = append(raw, tank(f, false, false, false, r))
		}
		raw = append(raw, tank(0, true, false, false, r), tank(0, false, true, false, r),
			tank(0, false, false, true, r), tank(1, false, false, true, r))
	case "rifle", "rocket":
		rocket := u.Kind == "rocket"
		for f := 0; f < 4; f++ {
			raw = append(raw, trooper(walkPose(f, 1.6), rocket))
		}
		raw = append(raw,
			trooper(pose{aim: true}, rocket),
			trooper(pose{aim: true, fire: true}, rocket),
			trooper(pose{hit: true, stride: 1}, rocket),
			trooper(walkPose(1, 2.6), rocket),
			trooper(walkPose(3, 2.6), rocket))
	}
	tex := aiTexture(u.ID, &raw[0])
	out := make([]*Grid, len(raw))
	for i := range raw {
		g := outline(shade(raw[i], tex))
		out[i] = &g
	}
	return out
}

// fxFrames: row 5. 0-1 demon rocket (warm exhaust), 2-3 allied rocket
// (cyan), 4 tank shell, 5-7 stone crumble dust.
func fxFrames() []*Grid {
	var out []*Grid
	rocket := func(f int, cyan bool) *Grid {
		var g Grid
		g.line(11, 12, 20, 12, I2, 2)
		g.line(11, 11, 20, 11, I3, 1)
		g.tri(20, 10.5, 23, 12, 20, 13.5, I1)
		g.tri(10, 9.5, 12, 11, 10, 11, I1)
		g.tri(10, 14.5, 12, 13, 10, 13, I1)
		w := float64(3 + f)
		g.disc(10-w/2, 12, w/2, 1.2, W2)
		g.disc(10-w/4, 12, w/4+.3, .7, W3)
		if cyan {
			g.set(19, 11, W2)
		} else {
			g.set(19, 11, W1)
		}
		o := outline(g)
		return &o
	}
	out = append(out, rocket(0, false), rocket(1, false), rocket(0, true), rocket(1, true))
	var sh Grid
	sh.disc(16, 12, 2, 1.4, W2)
	sh.disc(15.5, 12, 1, .8, W3)
	sh.line(9, 12, 14, 12, W1, 1)
	out = append(out, &sh)
	for f := 0; f < 3; f++ {
		var d Grid
		r := newRng(4100 + f)
		for k := 0; k < 9; k++ {
			a := r.f() * math.Pi
			dist := 2 + float64(f)*2.4*r.f() + float64(f)
			x, y := 16+math.Cos(a)*dist*1.4, 21-math.Sin(a)*dist*.8
			c := B3
			if k%3 == 0 {
				c = B4
			}
			if f == 0 && k < 3 {
				c = W2
			}
			d.disc(x, y, 1.1-float64(f)*.25, 1.1-float64(f)*.25, c)
		}
		o := outline(d)
		out = append(out, &o)
	}
	return out
}

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------

func hexC(h string) color.NRGBA {
	var r, g, b uint8
	fmt.Sscanf(strings.TrimPrefix(h, "#"), "%02x%02x%02x", &r, &g, &b)
	return color.NRGBA{r, g, b, 255}
}

func palette(side string) map[int8]color.NRGBA {
	// Reserved sets of art/families/ground-forces.json.
	t := map[int8]color.NRGBA{}
	set := func(c int8, hs ...string) {
		for i, h := range hs {
			t[c+int8(i)] = hexC(h)
		}
	}
	if side == "ally" {
		set(B1, "#364355", "#4E5E73", "#6E8299", "#98ABC0", "#C4D2E0")
		set(A1, "#232D3B", "#2F5A60", "#4A7A7C")
		set(I1, "#262A32", "#3A3F48", "#555B65")
		set(W1, "#2AA59A", "#70F5D5", "#D2FFF4")
		set(Line, "#0A0F16")
	} else {
		set(B1, "#2E2A33", "#463E4A", "#615664", "#827484", "#A898A6")
		set(A1, "#22221A", "#3A3A2A", "#575640")
		set(I1, "#262A32", "#3A3F48", "#555B65")
		set(W1, "#B8260F", "#FF8A2A", "#FFC85A")
		set(Line, "#0B080E")
	}
	return t
}

func paint(img *image.NRGBA, g *Grid, ox, oy int, tab map[int8]color.NRGBA) {
	for y := 0; y < CH; y++ {
		for x := 0; x < CW; x++ {
			if c := g[y][x]; c != Empty {
				img.SetNRGBA(ox+x, oy+y, tab[c])
			}
		}
	}
}

// content box (union of the move frames), texels.
func contentBox(fr []*Grid) (int, int) {
	x0, y0, x1, y1 := CW, CH, -1, -1
	for _, g := range fr[:4] {
		for y := 0; y < CH; y++ {
			for x := 0; x < CW; x++ {
				if g[y][x] != Empty {
					x0, y0 = min(x0, x), min(y0, y)
					x1, y1 = max(x1, x), max(y1, y)
				}
			}
		}
	}
	return x1 - x0 + 1, y1 - y0 + 1
}

func cmdOffline() {
	s := loadSpec()
	atlas := image.NewNRGBA(image.Rect(0, 0, Cols*CW, Rows*CH))
	sizes := make([]string, len(s.Units))
	for _, u := range s.Units {
		fr := rowFrames(u)
		tab := palette(u.Side)
		for i, g := range fr {
			paint(atlas, g, i*CW, u.Row*CH, tab)
		}
		w, h := contentBox(fr)
		sizes[u.Row] = fmt.Sprintf("(%d, %d)", w, h)
	}
	warm, cyan := palette("demon"), palette("ally")
	for i, g := range fxFrames() {
		tab := warm
		if i == 2 || i == 3 {
			tab = cyan
		}
		paint(atlas, g, i*CW, 5*CH, tab)
	}
	writePNG(filepath.Join(root, "assets/images/ground-troops.png"), atlas)
	var b bytes.Buffer
	fmt.Fprintf(&b, `// GENERATED by tools/ground_troops (go run . offline) - do not edit by hand.
// Source: art/families/ground-troops.json.
//
// Cell layout of assets/images/ground-troops.png (1 texel per pixel). Every
// cell is [cellW] x [cellH] texels; units stand bottom-centred on the last
// row. Demons are side-on facing screen right (mirror for left); allies are
// seen from behind, walking up the plane.

/// Grid contract of the ground-troops atlas (ground war v4).
abstract final class GroundTroopsAtlas {
  static const String file = 'ground-troops.png';
  static const int cellW = %d, cellH = %d, columns = %d, rows = %d;

  // Rows.
  static const int demonGruntRow = 0, demonRocketRow = 1, demonTankRow = 2;
  static const int allyRifleRow = 3, allyRocketRow = 4, fxRow = 5;

  // Trooper columns (demons and allies).
  static const int walkCol = 0, walkFrames = 4;
  static const int aimCol = 4, fireCol = 5, hitCol = 6;
  /// Demons: 7 toppling, 8 cracked stone rubble (never blood).
  static const int fallCol = 7, rubbleCol = 8;
  /// Allies: 7-8 running stride (falling back to the escort slot).
  static const int runCol = 7, runFrames = 2;

  // Heavy tank columns.
  static const int tankMoveCol = 0, tankMoveFrames = 4;
  static const int tankFireCol = 4, tankRecoilCol = 5;
  static const int tankWreckCol = 6, tankWreckFrames = 2;

  // Fx row columns.
  static const int rocketWarmCol = 0, rocketCyanCol = 2, rocketFrames = 2;
  static const int shellCol = 4;
  static const int crumbleCol = 5, crumbleFrames = 3;

  /// Visible content box (texels) per unit row (move frames, outline in).
  static const List<(int, int)> size = [%s];
}
`, CW, CH, Cols, Rows, strings.Join(sizes, ", "))
	must(os.WriteFile(filepath.Join(root, "lib/game/ground_troops_atlas.dart"), b.Bytes(), 0o644))
	contact(atlas)
	fmt.Println("atlas", Cols*CW, "x", Rows*CH, "units", len(s.Units))
}

// contact: the atlas at 4x over a dark and a mid ground, side by side.
func contact(atlas *image.NRGBA) {
	const k = 4
	w, h := atlas.Bounds().Dx(), atlas.Bounds().Dy()
	out := image.NewNRGBA(image.Rect(0, 0, w*k, h*k*2+8))
	for half, bg := range []color.NRGBA{{14, 12, 20, 255}, {58, 56, 62, 255}} {
		oy := half * (h*k + 8)
		for y := 0; y < h*k; y++ {
			for x := 0; x < w*k; x++ {
				c := atlas.NRGBAAt(x/k, y/k)
				if c.A == 0 {
					c = bg
					if (x/(CW*k)+y/(CH*k))%2 == 1 {
						c.R += 6
						c.G += 6
						c.B += 6
					}
				}
				out.SetNRGBA(x, oy+y, c)
			}
		}
	}
	writePNG(filepath.Join(root, "art/contact/ground-troops-contact.png"), out)
}
