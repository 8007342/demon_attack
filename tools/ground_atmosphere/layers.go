package main

// The procedural layers. Each is a grid of alpha levels (0 transparent,
// 1..4 = 0.2..0.8) and colour roles; the pack step paints the roles with a
// sector's tints. Tiled bands use noise that is periodic over the band
// width (integer cycles per 512 texels), so they wrap without a seam.

import (
	"math"

	"demonattack/tools/pixelgrid"
)

// Colour roles.
const (
	roleFog    = iota // the sector fog tint
	roleLit           // a lit top edge
	roleDark          // a cloud underside
	roleSmoke1        // smoke ramp steps (neutral; tinted at runtime)
	roleSmoke2
	roleSmoke3
	roleShadow // cloud shadow ink
)

type Layer struct {
	W, H int
	A    []uint8 // alpha level 0..4
	C    []uint8 // colour role
}

func newLayer(w, h int) *Layer {
	return &Layer{W: w, H: h, A: make([]uint8, w*h), C: make([]uint8, w*h)}
}

func (l *Layer) at(x, y int) uint8 {
	if y < 0 || y >= l.H {
		return 0
	}
	x = ((x % l.W) + l.W) % l.W
	return l.A[y*l.W+x]
}

func (l *Layer) set(x, y int, a, c uint8) {
	if y < 0 || y >= l.H {
		return
	}
	x = ((x % l.W) + l.W) % l.W
	l.A[y*l.W+x] = a
	l.C[y*l.W+x] = c
}

// level quantises a density 0..1 to the 4 alpha steps, capped at max.
func level(d float64, max int) uint8 {
	v := int(math.Floor(d * 5))
	if v < 0 {
		v = 0
	}
	if v > max {
		v = max
	}
	return uint8(v)
}

func maxLevel(alpha float64) int { return int(math.Round(alpha / .2)) }

// --- periodic noise -------------------------------------------------------

// wave is a sum of n sines with integer cycle counts in [kmin, kmax] over
// the width w: periodic, -1..1.
func wave(seed int, x float64, w, kmin, kmax, n int) float64 {
	sum, norm := 0.0, 0.0
	for i := 0; i < n; i++ {
		k := kmin + int(pixelgrid.Hash01(seed, i, 1)*float64(kmax-kmin+1))
		ph := pixelgrid.Hash01(seed, i, 2) * 2 * math.Pi
		a := 1 / math.Sqrt(float64(k))
		sum += a * math.Sin(2*math.Pi*float64(k)*x/float64(w)+ph)
		norm += a
	}
	return sum / norm
}

// vnoise: value noise on a lattice of cw x ch texel cells, periodic in x
// over `period` cells; smooth (quintic) interpolation; 0..1.
func vnoise(seed int, x, y, cw, ch float64, period int) float64 {
	px, py := x/cw, y/ch
	x0, y0 := math.Floor(px), math.Floor(py)
	fx, fy := px-x0, py-y0
	h := func(i, j int) float64 {
		i = ((i % period) + period) % period
		return pixelgrid.Hash01(seed, i, j)
	}
	ix, iy := int(x0), int(y0)
	u := fx * fx * fx * (fx*(fx*6-15) + 10)
	v := fy * fy * fy * (fy*(fy*6-15) + 10)
	a, b := h(ix, iy), h(ix+1, iy)
	c, d := h(ix, iy+1), h(ix+1, iy+1)
	return a + (b-a)*u + (c-a)*v + (a-b-c+d)*u*v
}

// fbm: 3 octaves of vnoise, periodic over w (cw must divide w).
func fbm(seed int, x, y float64, w int, cw, ch float64) float64 {
	sum, amp, norm := 0.0, .5, 0.0
	for o := 0; o < 3; o++ {
		sum += amp * vnoise(seed+o*977, x, y, cw, ch, int(math.Round(float64(w)/cw)))
		norm += amp
		amp *= .5
		cw /= 2
		ch /= 2
		if ch < 1 {
			ch = 1
		}
	}
	return sum / norm
}

// wrapDist: horizontal distance on a ring of width w.
func wrapDist(a, b float64, w int) float64 {
	d := math.Mod(math.Abs(a-b), float64(w))
	return math.Min(d, float64(w)-d)
}

// despeckle replaces a pixel whose level differs from all four neighbours
// with the level its horizontal neighbours share (or the lower of them):
// no lone pixels in the stepped alpha.
func despeckle(l *Layer) {
	src := append([]uint8(nil), l.A...)
	get := func(x, y int) uint8 {
		if y < 0 || y >= l.H {
			return 0
		}
		x = ((x % l.W) + l.W) % l.W
		return src[y*l.W+x]
	}
	for y := 0; y < l.H; y++ {
		for x := 0; x < l.W; x++ {
			v := get(x, y)
			n := [4]uint8{get(x-1, y), get(x+1, y), get(x, y-1), get(x, y+1)}
			if v != n[0] && v != n[1] && v != n[2] && v != n[3] {
				w := n[0]
				if n[1] < w {
					w = n[1]
				}
				l.A[y*l.W+x] = w
			}
		}
	}
}

// litEdges: a pixel whose upper neighbour is thinner takes the lit role.
func litEdges(l *Layer) {
	for y := 0; y < l.H; y++ {
		for x := 0; x < l.W; x++ {
			i := y*l.W + x
			if l.A[i] >= 2 && l.at(x, y-1) < l.A[i]-1 && l.C[i] == roleFog {
				l.C[i] = roleLit
			}
		}
	}
}

// --- bands ----------------------------------------------------------------

// horizonFog: an uneven bank, its top undulating at 64-128 texels, densest
// at the bottom rows, with two or three thin "holes" where far units show.
func horizonFog(b Band, seed, w int) *Layer {
	l := newLayer(w, b.H)
	max := maxLevel(b.AlphaMax)
	rng := pixelgrid.NewRng(seed)
	type hole struct{ x, y, rx, ry float64 }
	holes := []hole{}
	nh := 2 + int(rng.F()*2)
	for i := 0; i < nh; i++ {
		holes = append(holes, hole{
			x:  float64(w) * (float64(i) + .2 + .6*rng.F()) / float64(nh),
			y:  float64(b.H)*.5 + rng.F()*float64(b.H)*.22,
			rx: 18 + rng.F()*16,
			ry: 4 + rng.F()*3,
		})
	}
	H := float64(b.H)
	for x := 0; x < w; x++ {
		fx := float64(x)
		top := H*.27 + H*.15*wave(seed+1, fx, w, 4, 8, 3) + H*.05*wave(seed+2, fx, w, 12, 24, 4)
		bottom := H - 9 + 3*wave(seed+3, fx, w, 10, 30, 4)
		for y := 0; y < b.H; y++ {
			fy := float64(y) + .5
			if fy < top {
				continue
			}
			t := (fy - top) / (H - top)
			d := .2 + .8*math.Pow(t, .75) + .26*(fbm(seed+4, fx, fy, w, 32, 6)-.5)
			for _, h := range holes {
				dx, dy := wrapDist(fx, h.x, w)/h.rx, (fy-h.y)/h.ry
				if e := dx*dx + dy*dy; e < 1 {
					d -= .42 * (1 - e)
				}
			}
			if fy > bottom {
				d -= .13 * (fy - bottom)
			}
			l.set(x, y, level(d, max), roleFog)
		}
	}
	despeckle(l)
	litEdges(l)
	return l
}

type span struct{ x0, n int }

// spans lays pieces around the ring of width w: lengths in [lmin, lmax],
// gaps in [gmin, gmax]; the last gap closes the ring.
func spans(rng *pixelgrid.Rng, w int, lmin, lmax, gmin, gmax float64) []span {
	start := 8 + int(rng.F()*32) // no piece edge on the wrap column
	cur := start
	var out []span
	for {
		n := int(lmin + rng.F()*(lmax-lmin))
		if cur+n > start+w-int(gmin) {
			n = start + w - int(gmin) - cur
		}
		if n < int(lmin*.6) {
			break
		}
		out = append(out, span{cur, n})
		cur += n + int(gmin+rng.F()*(gmax-gmin))
	}
	return out
}

// lowCloud: flat-bottomed deck pieces whose tops are rows of rounded
// billows (stepped by the texel grid), the underside one step darker; the
// bottoms straddle the horizon line.
func lowCloud(b Band, seed, w int) *Layer {
	l := newLayer(w, b.H)
	max := maxLevel(b.AlphaMax)
	rng := pixelgrid.NewRng(seed)
	for _, sp := range spans(rng, w, 60, 170, 20, 70) {
		base := float64(b.H - 8 + int(rng.F()*4)) // 32..35 of 40
		type bump struct{ x, r float64 }
		var bumps []bump
		for x := 0.0; x < float64(sp.n); {
			r := 5 + rng.F()*9
			bell := math.Sin(math.Pi * math.Min(1, math.Max(0, (x+r*.5)/float64(sp.n))))
			bumps = append(bumps, bump{x + r*.6, r * (.45 + .75*bell)})
			x += r * (.9 + rng.F()*.6)
		}
		for xi := 0; xi < sp.n; xi++ {
			fx := float64(xi) + .5
			h := 0.0
			for _, q := range bumps {
				if d := math.Abs(fx - q.x); d < q.r {
					if v := math.Sqrt(q.r*q.r-d*d) * .7; v > h {
						h = v
					}
				}
			}
			// The flat bottom thins toward the piece's ends.
			de := math.Min(fx, float64(sp.n)-fx)
			bot := base - math.Max(0, 3-de*.5)
			top := bot - h
			for y := int(math.Floor(top)); y <= int(bot); y++ {
				fy := float64(y) + .5
				if fy < top || y < 0 {
					continue
				}
				dt := fy - top                          // depth below the billow top
				d := .35 + .2*dt + .04*math.Min(de, 10) // denser inside
				d += .3 * (fbm(seed+7, float64(sp.x0+xi), fy, w, 32, 4) - .5)
				role := uint8(roleFog)
				if fy > bot-1.5 && h > 3 {
					role = roleDark
				}
				l.set(sp.x0+xi, y, level(d, max), role)
			}
		}
		// A thin wisp trailing off some pieces.
		if rng.F() < .6 {
			wy := int(base) - 2 - int(rng.F()*3)
			wn := int(float64(sp.n) * (.25 + .3*rng.F()))
			wx := sp.x0 + sp.n - wn/3
			if rng.F() < .5 {
				wx = sp.x0 - wn*2/3
			}
			for xi := 0; xi < wn; xi++ {
				if l.at(wx+xi, wy) == 0 {
					l.set(wx+xi, wy, 1, roleFog)
				}
			}
		}
	}
	despeckle(l)
	litEdges(l)
	return l
}

// midMist: thin horizontal wisps 3-8 texels tall with long gaps, so the
// bank hides some units and not others (at least emptyMin of the columns
// stay clear).
func midMist(b Band, seed, w int, emptyMin float64) *Layer {
	for attempt := 0; ; attempt++ {
		l := midMistTry(b, seed+attempt*1000, w)
		if emptyColumns(l) >= emptyMin || attempt > 20 {
			return l
		}
	}
}

func emptyColumns(l *Layer) float64 {
	n := 0
	for x := 0; x < l.W; x++ {
		empty := true
		for y := 0; y < l.H; y++ {
			if l.A[y*l.W+x] != 0 {
				empty = false
				break
			}
		}
		if empty {
			n++
		}
	}
	return float64(n) / float64(l.W)
}

func midMistTry(b Band, seed, w int) *Layer {
	l := newLayer(w, b.H)
	max := maxLevel(b.AlphaMax)
	rng := pixelgrid.NewRng(seed)
	wisp := func(x0, n int, cy, th float64, sway float64) {
		for xi := 0; xi < n; xi++ {
			u := 2*(float64(xi)+.5)/float64(n) - 1
			half := th / 2 * math.Pow(1-math.Pow(math.Abs(u), 2.2), .6)
			c := cy + sway*math.Sin(math.Pi*u+float64(x0))
			x := x0 + xi
			for y := 0; y < b.H; y++ {
				dy := math.Abs(float64(y) + .5 - c)
				if dy >= half+.25 {
					continue
				}
				d := 1 - dy/(half+.25)
				lv := 1
				if d > .3 {
					lv = 2
				}
				if d > .6 {
					lv = 3
				}
				if fbm(seed+5, float64(x), float64(y), w, 16, 4) < .32 {
					lv--
				}
				if lv > max {
					lv = max
				}
				if uint8(lv) > l.at(x, y) {
					// The upper half of a wisp catches the sky's light.
					role := uint8(roleFog)
					if lv >= 2 && float64(y)+.5 < c {
						role = roleLit
					}
					l.set(x, y, uint8(lv), role)
				}
			}
		}
	}
	for _, sp := range spans(rng, w, 48, 120, 52, 110) {
		th := 3 + rng.F()*5
		cy := 4 + th/2 + rng.F()*(float64(b.H)-8-th)
		wisp(sp.x0, sp.n, cy, th, .6+rng.F())
		if rng.F() < .55 { // a thinner companion inside the same span
			cn := int(float64(sp.n) * (.35 + .35*rng.F()))
			cx := sp.x0 + int(rng.F()*float64(sp.n-cn))
			dy := 4 + rng.F()*3
			if cy > float64(b.H)/2 {
				dy = -dy
			}
			wisp(cx, cn, cy+dy, 2+rng.F()*2, .4)
		}
	}
	despeckle(l)
	litEdges(l)
	return l
}

// dustVeil: a thin, streaky band (2 alpha steps at most).
func dustVeil(b Band, seed, w int) *Layer {
	l := newLayer(w, b.H)
	max := maxLevel(b.AlphaMax)
	H := float64(b.H)
	for x := 0; x < w; x++ {
		fx := float64(x)
		c := H*.55 + 2*wave(seed+1, fx, w, 3, 9, 3)
		for y := 0; y < b.H; y++ {
			fy := float64(y) + .5
			prof := 1 - math.Abs(fy-c)/(H*.5)
			n := fbm(seed+2, fx, fy, w, 64, 4)
			d := prof * 1.25 * (n - .38) * 2.4
			l.set(x, y, level(d, max), roleFog)
		}
	}
	despeckle(l)
	return l
}

// --- sprites --------------------------------------------------------------

// cloudShadow: a big soft-edged blob at one alpha level.
func cloudShadow(sp Sprite, seed int) *Layer {
	l := newLayer(sp.W, sp.H)
	rng := pixelgrid.NewRng(seed)
	type ell struct{ x, y, rx, ry float64 }
	var es []ell
	n := 4 + int(rng.F()*3)
	W, H := float64(sp.W), float64(sp.H)
	for i := 0; i < n; i++ {
		rx := W*.12 + rng.F()*W*.14
		ry := H*.18 + rng.F()*H*.14
		es = append(es, ell{
			x:  rx + 2 + rng.F()*(W-2*rx-4),
			y:  ry + 2 + rng.F()*(H-2*ry-4),
			rx: rx, ry: ry,
		})
	}
	lv := uint8(maxLevel(sp.AlphaMax))
	for y := 1; y < sp.H-1; y++ {
		for x := 1; x < sp.W-1; x++ {
			best := 9.0
			for _, e := range es {
				dx, dy := (float64(x)+.5-e.x)/e.rx, (float64(y)+.5-e.y)/e.ry
				if v := dx*dx + dy*dy; v < best {
					best = v
				}
			}
			edge := 1 + .35*(pixelgrid.Hash01(seed, x/3, y/2)-.5)
			if best < edge {
				l.A[y*sp.W+x] = lv
				l.C[y*sp.W+x] = roleShadow
			}
		}
	}
	despeckle(l)
	return l
}

type lobe struct{ x, y, r float64 }

// puffs paints overlapping round lobes with the smoke ramp: lit tops,
// dark bottoms, eroded by noise as `thin` grows.
func puffs(l *Layer, lobes []lobe, maxLv int, thin float64, seed int, phase float64) {
	for y := 0; y < l.H; y++ {
		for x := 0; x < l.W; x++ {
			best, rel := 0.0, 0.0
			for _, o := range lobes {
				dx, dy := float64(x)+.5-o.x, float64(y)+.5-o.y
				d := 1 - math.Sqrt(dx*dx+dy*dy)/o.r
				if d > best {
					best, rel = d, dy/o.r
				}
			}
			if best <= 0 {
				continue
			}
			lv := 1 + int(best*float64(maxLv)*1.4)
			if lv > maxLv {
				lv = maxLv
			}
			// Thinning eats the rim first, then lowers the whole puff a
			// step: no holes punched in the middle (they read as faces).
			n := vnoise(seed, float64(x)+phase, float64(y), 5, 4, 1<<20)
			if best < .25+thin*.5 && n < .35+thin {
				lv--
			}
			if best < .15+thin*.3 && n < .5+thin*.5 {
				continue
			}
			if lv <= 0 {
				continue
			}
			role := uint8(roleSmoke2)
			if rel < -.35 {
				role = roleSmoke3
			} else if rel > .4 {
				role = roleSmoke1
			}
			l.set(x, y, uint8(lv), role)
		}
	}
	despeckle(l)
}

// smokeDrift frame f of n: a puff from dense to thin, rising and spreading.
func smokeDrift(sp Sprite, f int) *Layer {
	l := newLayer(sp.W, sp.H)
	rng := pixelgrid.NewRng(sp.Seed)
	p := float64(f) / float64(sp.Frames-1)
	var lobes []lobe
	for i := 0; i < 7; i++ {
		dx := (rng.F() - .5) * 24
		dy := (rng.F() - .5) * 10
		r := 4 + rng.F()*5
		lobes = append(lobes, lobe{
			x: 24 + dx*(1+p*.5),
			y: 21 - p*7 + dy*(1+p*.3),
			r: r * (1 + p*.45),
		})
	}
	maxLv := maxLevel(sp.AlphaMax) - int(math.Round(p*2))
	puffs(l, lobes, maxLv, .12+p*.45, sp.Seed+1, float64(f)*3)
	return l
}

// smokeWall frame f: a long low wall of puffs that churns in a loop.
func smokeWall(sp Sprite, f int) *Layer {
	l := newLayer(sp.W, sp.H)
	rng := pixelgrid.NewRng(sp.Seed)
	ph := 2 * math.Pi * float64(f) / float64(sp.Frames)
	var lobes []lobe
	n := 9
	for i := 0; i < n; i++ {
		a := rng.F() * 2 * math.Pi
		r := 8 + rng.F()*6
		bell := math.Sin(math.Pi * (float64(i) + .5) / float64(n))
		lobes = append(lobes, lobe{
			x: 8 + float64(i)*(float64(sp.W)-16)/float64(n-1) + 1.5*math.Cos(a+ph),
			y: float64(sp.H) - 4 - r*.7 - bell*8 + 2*math.Sin(a+ph),
			r: r * (.8 + .25*bell) * (1 + .08*math.Cos(a-ph)),
		})
	}
	puffs(l, lobes, maxLevel(sp.AlphaMax), .25, sp.Seed+1, 4*math.Sin(ph))
	return l
}
