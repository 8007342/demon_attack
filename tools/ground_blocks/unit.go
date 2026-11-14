package main

// Per-unit build context: camera, cell geometry, origin and pivot
// placement, and helpers shared by the cell generators.

import (
	"errors"
	"fmt"
	"math"
)

func errf(format string, a ...any) error { return errors.New(fmt.Sprintf(format, a...)) }

type ClassInfo struct {
	OmegaHull, MinHold, OmegaArt float64
}

// classTable: the turn tracker numbers of plan/ground-unit-animation.md §5.
var classTable = map[string]ClassInfo{
	"infantry": {360, 0.10, 0},
	"light":    {180, 0.12, 270},
	"heavy":    {75, 0.20, 120},
	"walker":   {90, 0.18, 150},
	"command":  {30, 0.40, 0},
}

type Builder struct {
	Spec     *UnitSpec
	Rig      *Rig
	Pal      *Palette
	Mats     *Materials
	Cam      Camera
	CW, CH   int
	Headings []float64
	Angles   []float64
	Ox, Ou   float64 // hull origin in the cell
	AOx, AOu float64 // art pivot in the art cell
	Travel   int     // travel heading index
	Primary  int     // primary (non-heading states) index for infantry
	Bounds   [2]V3   // hull local bounds (min, max), from renders
}

func newBuilder(u *UnitSpec, r *Rig, fam *Family, pal *Palette, cw, ch int) *Builder {
	b := &Builder{Spec: u, Rig: r, Pal: pal, Mats: pal.Mats, CW: cw, CH: ch}
	b.Cam = newCamera(fam.Camera.Elevation, fam.Camera.Light, fam.Camera.LMin, fam.Camera.LMax)
	b.Headings = u.Headings
	if r.Art != nil {
		b.Angles = fam.ArtAngles
		if r.Faction == "host" && len(b.Angles) == 0 {
			b.Angles = fam.Headings
		}
		if u.Art != nil && len(u.Art.Angles) > 0 {
			b.Angles = u.Art.Angles
		}
	}
	switch {
	case r.Block == "I" && r.Faction == "host":
		b.Travel, b.Primary = 1, 1
	case r.Block == "I":
		b.Travel, b.Primary = 0, 0
	case r.Block == "K":
		b.Travel, b.Primary = 1, 1
	case r.Faction == "host":
		b.Travel, b.Primary = 3, 3
	}
	b.place()
	return b
}

// place fixes the hull origin so the lowest texel of any heading and move
// frame sits on the cell's last row, centred; and the art pivot so the
// union of all art angles is centred in the art cell.
func (b *Builder) place() {
	const big = 160
	ox, ou := float64(big)/2, float64(big)/2
	lowest, top := 0, big
	mn, mx := V3{1e9, 1e9, 1e9}, V3{-1e9, -1e9, -1e9}
	for _, h := range b.Headings {
		for f := 0; f < b.frames(); f++ {
			o := defaultOpt("hull")
			o.Heading, o.Frame, o.Moving = h, f, true
			fr := b.Rig.render(o, b.Cam, b.Mats, big, big, ox, ou)
			_, y0, _, y1 := fr.bbox()
			if y1 > lowest {
				lowest = y1
			}
			top = min(top, y0)
			for _, p := range fr.Px {
				if p.Mat != 0 {
					for i := 0; i < 3; i++ {
						mn[i], mx[i] = math.Min(mn[i], p.P[i]), math.Max(mx[i], p.P[i])
					}
				}
			}
		}
	}
	b.Bounds = [2]V3{mn, mx}
	// Origin row: lowest texel lands on row CH-2 (one row left for ink).
	drop := float64(lowest) + .5 - ou
	b.Ox = float64(b.CW) / 2
	b.Ou = float64(b.CH-2) + .5 - drop
	if b.Rig.Art != nil {
		y0, y1 := big, -1
		for _, a := range b.Angles {
			for e := 0; e <= len(b.Rig.Art.Elevations); e++ {
				o := defaultOpt("art")
				o.Aim, o.Elev = a, e
				fr := b.Rig.render(o, b.Cam, b.Mats, big, big, ox, ou)
				_, ay0, ax1, ay1 := fr.bbox()
				if ax1 < 0 {
					continue
				}
				y0, y1 = min(y0, ay0), max(y1, ay1)
			}
		}
		// centre the union vertically, keep the pivot x at the cell centre
		cy := float64(y0+y1+1) / 2
		b.AOx = float64(b.CW) / 2
		b.AOu = float64(b.CH)/2 + (ou - cy)
	}
}

func (b *Builder) frames() int {
	if b.Rig.Gait != nil && b.Rig.Gait.Frames > 0 {
		return b.Rig.Gait.Frames
	}
	return 4
}

func (b *Builder) hull(o RenderOpt) *Frame {
	o.Layer = "hull"
	if o.Unit.R == (M3{}) {
		o.Unit = idXf()
	}
	return b.Rig.render(o, b.Cam, b.Mats, b.CW, b.CH, b.Ox, b.Ou)
}

func (b *Builder) art(o RenderOpt) *Frame {
	o.Layer = "art"
	if o.Unit.R == (M3{}) {
		o.Unit = idXf()
	}
	return b.Rig.render(o, b.Cam, b.Mats, b.CW, b.CH, b.AOx, b.AOu)
}

func (b *Builder) opt(h float64) RenderOpt {
	o := defaultOpt("hull")
	o.Heading = h
	return o
}

// pivot: the art pivot projected at hull heading h, texels from the hull
// origin (dx right, dy up).
func (b *Builder) pivot(h float64) (float64, float64) {
	if b.Rig.Art == nil {
		return 0, 0
	}
	p := yawCW(h).apply(b.Rig.Art.Pivot)
	return b.Cam.project(p)
}

// muzzle at art angle a: texels from the pivot (dx right, dy up).
func (b *Builder) muzzle(a float64) (float64, float64) {
	if b.Rig.Art == nil {
		return 0, 0
	}
	return b.Cam.project(yawCW(a).apply(b.Rig.Art.Muzzle))
}

// composite draws the art cell over the hull cell at heading h.
func (b *Builder) composite(hull, art *Frame, h float64) *Frame {
	out := hull.clone()
	if art == nil {
		return out
	}
	dx, du := b.pivot(h)
	// art texel (x, y) -> hull texel: hull origin + pivot - art pivot
	offX := b.Ox + dx - b.AOx
	offY := (b.Ou - du) - b.AOu
	ix, iy := int(math.Round(offX)), int(math.Round(offY))
	for y := 0; y < art.H; y++ {
		for x := 0; x < art.W; x++ {
			p := art.at(x, y)
			if p.Mat == 0 {
				continue
			}
			if q := out.at(x+ix, y+iy); q != nil {
				*q = *p
				q.T = -1 // drawn on top
			}
		}
	}
	return out
}

// merge keeps the nearer texel of two frames of the same cell.
func merge(a, c *Frame) *Frame {
	out := a.clone()
	for i, p := range c.Px {
		if p.Mat != 0 && (out.Px[i].Mat == 0 || p.T < out.Px[i].T) {
			out.Px[i] = p
		}
	}
	return out
}

// temp renders extra primitives (slabs, heaps, pods) with the unit's camera.
func (b *Builder) temp(prims []Prim, o RenderOpt) *Frame {
	r := &Rig{ID: b.Rig.ID + "-temp", Faction: b.Rig.Faction, Hull: prims}
	o.Layer = "hull"
	if o.Unit.R == (M3{}) {
		o.Unit = idXf()
	}
	fr := r.render(o, b.Cam, b.Mats, b.CW, b.CH, b.Ox, b.Ou)
	for i := range fr.Px {
		fr.Px[i].Prim = -1
	}
	return fr
}

func (b *Builder) mat(name string) int8 {
	i, ok := b.Mats.Index[name]
	if !ok {
		fail(errf("%s: material %q missing from the family", b.Rig.ID, name))
	}
	return i
}

func (b *Builder) prim(id int16) *Prim {
	all := b.Rig.allPrims()
	if id >= 0 && int(id) < len(all) {
		return &all[id]
	}
	return nil
}

func (b *Builder) size() V3 { return b.Bounds[1].sub(b.Bounds[0]) }
