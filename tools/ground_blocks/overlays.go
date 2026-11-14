package main

// Overlay generators (task 2.4): every overlay is derived from a base cell
// and the rig, never drawn by hand and never by AI, so it lines up with
// its hull at every heading and layer angle.
//   lights      emissive prims at their lit step
//   fill1-3     Host channel stages (and eyes and mouth at fill3)
//   dmg1-2      Host warm crack seams / Fleet dented chips, skirt, vent
//   pitch       nose-up and nose-down re-poses of the rig
//   ford        the hull cut at the water line with a ripple band
//   debris      12 pieces cut along the rig's piece marks plus chips

import (
	"math"
	"sort"

	"demonattack/tools/pixelgrid"
)

// matCanvas paints one material step into a frame (for 2-D marks).
type matCanvas struct {
	f    *Frame
	mat  int8
	step int8
}

func (c matCanvas) Set(x, y int, _ int8) {
	if p := c.f.at(x, y); p != nil {
		*p = Px{Mat: c.mat, Step: c.step, Prim: -1, T: -1}
	}
}

func emptyLike(f *Frame) *Frame { return newFrame(f.W, f.H, f.Ox, f.Ou) }

func (b *Builder) lightsOverlay(base *Frame) *Frame {
	out := emptyLike(base)
	for i, p := range base.Px {
		if p.Mat != 0 && p.Emis {
			q := p
			q.Step = int8(b.Mats.List[p.Mat].LitStep)
			out.Px[i] = q
		}
	}
	return out
}

// fillOverlay lights channel stages 1..k; at k = 3 the eyes and mouth too.
func (b *Builder) fillOverlay(base *Frame, k int) *Frame {
	out := emptyLike(base)
	glow := b.mat("glow")
	for i, p := range base.Px {
		if p.Mat == 0 {
			continue
		}
		pr := b.prim(p.Prim)
		if pr == nil {
			continue
		}
		switch {
		case pr.Stage > 0 && pr.Stage <= k:
			s := int8(3)
			if pr.Stage == k {
				s = 4
			}
			if k == 3 {
				s = 4
			}
			out.Px[i] = Px{Mat: glow, Step: s, Prim: p.Prim, T: p.T}
		case k == 3 && (pr.has("eye") || pr.has("mouth")):
			out.Px[i] = Px{Mat: glow, Step: 5, Prim: p.Prim, T: p.T}
		}
	}
	return out
}

// voronoi3: distances to the nearest and second-nearest jittered feature
// points of a 3-D lattice of spacing s, and the nearest cell's hash.
func voronoi3(seed int, p V3, s float64) (float64, float64, float64) {
	q := p.mul(1 / s)
	ix, iy, iz := int(math.Floor(q[0])), int(math.Floor(q[1])), int(math.Floor(q[2]))
	d1, d2, h := 1e9, 1e9, 0.0
	for dz := -1; dz <= 1; dz++ {
		for dy := -1; dy <= 1; dy++ {
			for dx := -1; dx <= 1; dx++ {
				cx, cy, cz := ix+dx, iy+dy, iz+dz
				f := V3{float64(cx) + pixelgrid.Hash01(seed, cx, cy, cz, 1),
					float64(cy) + pixelgrid.Hash01(seed, cx, cy, cz, 2),
					float64(cz) + pixelgrid.Hash01(seed, cx, cy, cz, 3)}
				d := f.sub(q).len()
				if d < d1 {
					d2, d1, h = d1, d, pixelgrid.Hash01(seed, cx, cy, cz, 4)
				} else if d < d2 {
					d2 = d
				}
			}
		}
	}
	return d1 * s, d2 * s, h
}

func (b *Builder) dmgOverlay(base *Frame, level int, layer int) *Frame {
	out := emptyLike(base)
	seed := b.Rig.Seed*7 + layer
	if b.Rig.Faction == "host" {
		glow := b.mat("glow")
		frac, width := .22, .3
		if level == 2 {
			frac, width = .45, .42
		}
		for i, p := range base.Px {
			if p.Mat == 0 || p.Emis || b.Mats.List[p.Mat].Flat {
				continue
			}
			d1, d2, h := voronoi3(seed, p.P, 3.2)
			if h < frac && d2-d1 < width {
				s := int8(1)
				if level == 2 && d2-d1 < .2 {
					s = 2
				}
				out.Px[i] = Px{Mat: glow, Step: s, Prim: p.Prim, T: p.T}
			}
		}
		if level == 2 {
			// broken ornament: ornament prims lose their tips (drawn as dark stone)
			for i, p := range base.Px {
				if pr := b.prim(p.Prim); pr != nil && pr.has("ornament") && p.P[2] > b.ornamentTop(pr)-1.2 {
					out.Px[i] = Px{Mat: p.Mat, Step: 0, Prim: p.Prim, T: p.T}
				}
			}
		}
		return out
	}
	// Fleet: chips one (two) steps darker, never death imagery.
	frac := .16
	if level == 2 {
		frac = .32
	}
	for i, p := range base.Px {
		if p.Mat == 0 || p.Emis || b.Mats.List[p.Mat].Flat {
			continue
		}
		d1, _, h := voronoi3(seed, p.P, 3.0)
		if h < frac && d1 < 1.25 {
			q := p
			q.Step = int8(max(0, int(p.Step)-level))
			out.Px[i] = q
		}
	}
	if level == 2 {
		// hanging skirt: the right-hand skirt panel sags one texel
		x0, _, x1, _ := base.bbox()
		mid := (x0 + x1) / 2
		for y := base.H - 1; y >= 0; y-- {
			for x := mid; x < base.W; x++ {
				p := base.at(x, y)
				if pr := b.prim(p.Prim); pr != nil && pr.has("skirt") {
					if q := out.at(x, y+1); q != nil {
						*q = *p
					}
				}
			}
		}
		// smoke vent over the rear deck
		bx, by, best := -1, -1, 1e9
		for y := 0; y < base.H; y++ {
			for x := 0; x < base.W; x++ {
				p := base.at(x, y)
				if p.Mat != 0 && p.N[2] > .7 && p.P[1] < best {
					bx, by, best = x, y, p.P[1]
				}
			}
		}
		if bx >= 0 {
			c := matCanvas{out, b.mat("smoke"), 2}
			pixelgrid.Disc(c, float64(bx)+.5, float64(by)-1, 1.4, 1.2, 0)
			matCanvas{out, b.mat("smoke"), 3}.Set(bx, by-2, 0)
		}
	}
	return out
}

func (b *Builder) ornamentTop(pr *Prim) float64 {
	switch pr.Kind {
	case "bar":
		return math.Max(pr.A[2], pr.B[2])
	case "prism":
		return pr.At[2] + pr.H
	case "box":
		return pr.At[2] + pr.Size[2]
	}
	return pr.At[2] + pr.Size[2]
}

// pitchOpt: nose up (dir +1) about the rear contact or down (-1) about the
// front contact.
func (b *Builder) pitchOpt(h float64, dir float64, deg float64) RenderOpt {
	o := b.opt(h)
	if dir > 0 {
		o.Unit = rotAbout(pitchUp(deg), V3{0, b.Bounds[0][1], 0})
	} else {
		o.Unit = rotAbout(pitchUp(-deg), V3{0, b.Bounds[1][1], 0})
	}
	return o
}

// ford: the hull at heading h cut at depth d with a ripple band (A/B).
func (b *Builder) ford(o RenderOpt, depth float64, phase int) *Frame {
	o.Ground = depth
	fr := b.hull(o)
	b.ripple(fr, phase)
	return fr
}

func (b *Builder) ripple(fr *Frame, phase int) {
	water := b.mat("water")
	src := fr.clone()
	for x := 0; x < fr.W; x++ {
		low := -1
		for y := 0; y < fr.H; y++ {
			if src.filled(x, y) {
				low = y
			}
		}
		if low >= 0 && low+1 < fr.H {
			s := int8(2)
			if (x+phase)%3 == 0 {
				s = 3
			}
			*fr.at(x, low+1) = Px{Mat: water, Step: s, Prim: -1, T: -1}
			if (x+phase)%4 == 1 && fr.at(x+1, low+1) != nil {
				*fr.at(x+1, low+1) = Px{Mat: water, Step: 3, Prim: -1, T: -1}
			}
		}
	}
}

// slab: the crypt slab of a Host arrival, seams lit at step s.
func (b *Builder) slab(tilt float64, seam int8) *Frame {
	sz := b.size()
	w, l := math.Max(sz[0], 6)+3, math.Max(sz[1]*.75, 6)
	p := []Prim{{Kind: "box", At: V3{0, 0, 0}, Size: V3{w, l, 1.2}, Mat: "stone_dark", Chamfer: map[string]float64{"top": .6}}}
	o := b.opt(b.Headings[b.Travel])
	if tilt != 0 {
		o.Unit = rotAbout(pitchUp(tilt), V3{0, -l / 2, 0}).then(move(V3{0, 0, .6}))
	}
	fr := b.temp(p, o)
	glow := b.mat("glow")
	for i, px := range fr.Px {
		if px.Mat == 0 || px.N[2] < .5 {
			continue
		}
		d1, d2, h := voronoi3(b.Rig.Seed+31, px.P, 2.6)
		if d2-d1 < .28 && h < .55 {
			fr.Px[i] = Px{Mat: glow, Step: seam, Prim: -1, T: px.T}
		}
	}
	return fr
}

func (b *Builder) shards(spread float64, settled bool) *Frame {
	sz := b.size()
	var ps []Prim
	r := pixelgrid.NewRng(b.Rig.Seed + 77)
	for k := 0; k < 5; k++ {
		side := float64(k%2*2 - 1)
		x := side * (sz[0]/2 + 1 + spread*r.F())
		y := (r.F() - .5) * sz[1] * .7
		z := 0.0
		if !settled {
			z = 1 + 2*r.F()
		}
		ps = append(ps, Prim{Kind: "box", At: V3{x, y, z}, Size: V3{1.4, 1.6, 1.1}, Mat: "stone", Yaw: 30 * r.F()})
	}
	return b.temp(ps, b.opt(b.Headings[b.Travel]))
}

// heap: a rubble heap with cooling seams (A brighter, B cooler).
func (b *Builder) heap(seam int8, small bool) *Frame {
	sz := b.size()
	w, l := math.Max(sz[0]*.9, 5), math.Max(sz[1]*.7, 4)
	if small {
		w, l = math.Max(sz[0], 5), math.Max(sz[1], 3)
	}
	r := pixelgrid.NewRng(b.Rig.Seed + 501)
	var ps []Prim
	n := 11
	if small {
		n = 6
	}
	for k := 0; k < n; k++ {
		x, y := (r.F()-.5)*w, (r.F()-.5)*l
		rr := 1.2 + r.F()*1.6
		if small {
			rr = .9 + r.F()*1.1
		}
		m := "stone"
		if k%3 == 0 {
			m = "stone_dark"
		}
		ps = append(ps, Prim{Kind: "ball", At: V3{x, y, rr * .5}, Size: V3{rr, rr, rr * .8}, Mat: m})
	}
	fr := b.temp(ps, b.opt(b.Headings[b.Travel]))
	glow := b.mat("glow")
	for i, px := range fr.Px {
		if px.Mat == 0 {
			continue
		}
		d1, d2, h := voronoi3(b.Rig.Seed+502, px.P, 1.8)
		if d2-d1 < .32 && h < .5 {
			fr.Px[i] = Px{Mat: glow, Step: seam, Prim: -1, T: px.T}
		}
	}
	return fr
}

// debrisSheets cuts the finished frame into up to 12 pieces: the rig's
// named pieces first, then Voronoi chips of what is left, six per sheet
// in a 3 x 2 grid of 16 x 20 sub-cells.
func (b *Builder) debrisSheets(src *Frame) ([2]*Frame, []string) {
	type piece struct {
		name string
		px   []int
	}
	var pieces []piece
	used := make([]bool, len(src.Px))
	for _, name := range b.Rig.Pieces {
		var idx []int
		for i, p := range src.Px {
			if pr := b.prim(p.Prim); p.Mat != 0 && pr != nil && pr.Piece == name {
				idx = append(idx, i)
				used[i] = true
			}
		}
		if len(idx) >= 3 {
			pieces = append(pieces, piece{name, idx})
		}
	}
	// chips
	var rest []int
	for i, p := range src.Px {
		if p.Mat != 0 && !used[i] {
			rest = append(rest, i)
		}
	}
	need := 12 - len(pieces)
	if need > 0 && len(rest) > 0 {
		sort.Slice(rest, func(a, c int) bool {
			return pixelgrid.Hash01(b.Rig.Seed, rest[a]) < pixelgrid.Hash01(b.Rig.Seed, rest[c])
		})
		sites := rest[:min(need, len(rest))]
		groups := make([][]int, len(sites))
		for _, i := range rest {
			x, y := i%src.W, i/src.W
			best, bj := 1e9, 0
			for j, s := range sites {
				sx, sy := s%src.W, s/src.W
				d := float64((x-sx)*(x-sx) + (y-sy)*(y-sy))
				if d < best {
					best, bj = d, j
				}
			}
			groups[bj] = append(groups[bj], i)
		}
		for j, g := range groups {
			if len(g) >= 3 {
				pieces = append(pieces, piece{"chip" + itoa(j), g})
			}
		}
	}
	if len(pieces) > 12 {
		pieces = pieces[:12]
	}
	var sheets [2]*Frame
	for s := range sheets {
		sheets[s] = emptyLike(src)
	}
	var names []string
	for k, pc := range pieces {
		sh := sheets[k/6]
		j := k % 6
		sx, sy := (j%3)*16, (j/3)*20
		x0, y0, x1, y1 := src.W, src.H, -1, -1
		for _, i := range pc.px {
			x, y := i%src.W, i/src.W
			x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
		}
		w, h := min(x1-x0+1, 14), min(y1-y0+1, 18)
		cx := (x0 + x1 + 1 - w) / 2
		cy := y1 + 1 - h
		dx, dy := sx+1+(14-w)/2, sy+1+(18-h)
		for _, i := range pc.px {
			x, y := i%src.W-cx, i/src.W-cy
			if x < 0 || y < 0 || x >= w || y >= h {
				continue
			}
			q := src.Px[i]
			q.T = -1
			*sh.at(dx+x, dy+y) = q
		}
		names = append(names, pc.name)
	}
	return sheets, names
}

func itoa(i int) string {
	if i == 0 {
		return "0"
	}
	s := ""
	for i > 0 {
		s = string(rune('0'+i%10)) + s
		i /= 10
	}
	return s
}
