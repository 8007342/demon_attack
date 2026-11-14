package main

// Ray-cast rendering of a rig layer onto one cell: every texel centre casts
// one orthographic ray; the nearest solid gives the material, the facet
// normal (flat shading from the upper-left light), the unit-local point
// (for procedural cracks, chips and kits that stay put as the unit turns)
// and the primitive (for overlays and debris cuts).

import (
	"math"
)

type Px struct {
	Mat  int8 // index into Materials (0 = empty)
	Step int8 // ramp step
	Prim int16
	Art  bool // articulated layer texel
	Emis bool
	N    V3 // world normal
	P    V3 // unit-local hit point (before heading)
	T    float64
}

type Frame struct {
	W, H   int
	Ox, Ou float64 // origin (unit ground centre or art pivot) in cell coords: x from left, u = rows from top
	Px     []Px
}

func newFrame(w, h int, ox, ou float64) *Frame {
	return &Frame{W: w, H: h, Ox: ox, Ou: ou, Px: make([]Px, w*h)}
}

func (f *Frame) at(x, y int) *Px {
	if x < 0 || y < 0 || x >= f.W || y >= f.H {
		return nil
	}
	return &f.Px[y*f.W+x]
}

func (f *Frame) filled(x, y int) bool {
	p := f.at(x, y)
	return p != nil && p.Mat != 0
}

func (f *Frame) clone() *Frame {
	o := *f
	o.Px = append([]Px(nil), f.Px...)
	return &o
}

func (f *Frame) count() int {
	n := 0
	for _, p := range f.Px {
		if p.Mat != 0 {
			n++
		}
	}
	return n
}

// bbox of filled texels (x0, y0, x1, y1 inclusive); x1 < 0 when empty.
func (f *Frame) bbox() (int, int, int, int) {
	x0, y0, x1, y1 := f.W, f.H, -1, -1
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			if f.Px[y*f.W+x].Mat != 0 {
				x0, y0 = min(x0, x), min(y0, y)
				x1, y1 = max(x1, x), max(y1, y)
			}
		}
	}
	return x0, y0, x1, y1
}

type Material struct {
	Name     string `json:"-"`
	Ramp     string `json:"ramp"`
	Lo       int    `json:"lo"`
	Hi       int    `json:"hi"`
	Emissive bool   `json:"emissive"`
	LitStep  int    `json:"lit"`
	Pattern  string `json:"pattern"` // links | spokes | ""
	Flat     bool   `json:"flat"`    // no lighting, always lo
	Top      *int   `json:"top"`     // step of up-facing faces (deck tops), if set
}

// Materials is the resolved material table of one faction; index 0 empty.
type Materials struct {
	List  []Material
	Index map[string]int8
}

type RenderOpt struct {
	Layer              string  // hull | art
	Heading            float64 // hull heading, screen degrees
	Aim                float64 // art angle, screen degrees
	Frame              int     // move-cycle frame
	Moving             bool
	Poses              []Pose
	Unit               Xf      // unit-level transform before the heading (pitch, fall)
	World              V3      // offset after the heading
	Ground             float64 // occluding ground height (world z)
	Elev               int     // barrel elevation step
	Recoil             float64 // barrel recoil, texels
	NoRim              bool
	StrideMul, LiftMul float64
}

func defaultOpt(layer string) RenderOpt {
	return RenderOpt{Layer: layer, Unit: idXf(), Ground: math.Inf(-1)}
}

func axisRot(axis string, deg float64) M3 {
	switch axis {
	case "x":
		return pitchUp(deg)
	case "y":
		return rollRight(deg)
	}
	return yawCW(deg)
}

// solids places every primitive of the layer for opt in world space.
type placed struct {
	Solid
	id  int
	lit bool
}

func (r *Rig) solids(opt RenderOpt) []placed {
	var prims []Prim
	base := 0
	if opt.Layer == "art" {
		if r.Art == nil {
			return nil
		}
		prims = r.Art.Prims
		base = len(r.Hull)
	} else {
		prims = r.Hull
	}
	var out []placed
	g := r.Gait
	for i := range prims {
		p := &prims[i]
		// visibility
		show := !p.has("hidden")
		lit := false
		var px Xf = idXf()
		for _, ps := range opt.Poses {
			if ps.Tag != "" && !p.has(ps.Tag) {
				continue
			}
			if ps.Hide {
				show = false
			}
			if ps.Show {
				show = true
			}
			if ps.Lit {
				lit = true
			}
			if ps.Deg != 0 {
				px = px.then(rotAbout(axisRot(ps.Axis, ps.Deg), ps.Pivot))
			}
			if ps.Move != (V3{}) {
				px = px.then(move(ps.Move))
			}
		}
		if !show {
			continue
		}
		// gait
		var foot V3
		if g != nil && (p.Kind == "leg" || p.has("leg") || p.has("swing")) && opt.Moving {
			n := float64(max(1, g.Frames))
			ph := 2 * math.Pi * (float64(opt.Frame)/n + p.Phase)
			sm, lm := opt.StrideMul, opt.LiftMul
			if sm == 0 {
				sm = 1
			}
			if lm == 0 {
				lm = 1
			}
			foot = V3{0, sm * g.Stride * math.Sin(ph), lm * g.Lift * math.Max(0, math.Cos(ph))}
			if p.has("swing") {
				foot = V3{0, -.6 * g.Stride * math.Sin(ph), 0}
			}
		}
		if g != nil && opt.Moving && g.Bob != 0 && !(p.Kind == "leg" || p.has("leg")) && opt.Frame%2 == 1 {
			px = px.then(move(V3{0, 0, g.Bob}))
		}
		// move cycles of vehicles
		if opt.Layer == "hull" && opt.Moving {
			switch r.Move {
			case "hover":
				if !p.has("shadow") && opt.Frame%2 == 1 {
					px = px.then(move(V3{0, 0, 1.2}))
				}
			case "wheels":
				if p.has("body") && opt.Frame%2 == 1 {
					px = px.then(move(V3{0, 0, 1.2}))
				}
			}
		}
		// barrel recoil and elevation (art-local, before the aim)
		if opt.Layer == "art" && p.has("barrel") {
			if opt.Elev > 0 && r.Art != nil && opt.Elev <= len(r.Art.Elevations) {
				px = px.then(rotAbout(pitchUp(r.Art.Elevations[opt.Elev-1]), V3{0, 0, p.A[2]}))
			}
			if opt.Recoil != 0 {
				px = px.then(move(V3{0, -opt.Recoil, 0}))
			}
		}
		var lx Xf
		if opt.Layer == "art" {
			lx = px.then(Xf{R: yawCW(opt.Aim)})
		} else {
			lx = px.then(opt.Unit).then(Xf{R: yawCW(opt.Heading)}).then(move(opt.World))
		}
		for _, s := range expand(p, foot) {
			ps := placed{Solid: s, id: base + i, lit: lit}
			ps.Shape = s.Shape.xf(lx)
			ps.Local = s.Local.then(lx) // prim frame -> world
			out = append(out, ps)
		}
	}
	return out
}

// render casts the layer into a w x h cell with the origin at (ox, ou).
func (r *Rig) render(opt RenderOpt, cam Camera, mats *Materials, w, h int, ox, ou float64) *Frame {
	fr := newFrame(w, h, ox, ou)
	sol := r.solids(opt)
	unitInv := Xf{R: yawCW(opt.Heading)}.then(move(opt.World)).inv()
	preInv := opt.Unit.inv()
	for py := 0; py < h; py++ {
		for px := 0; px < w; px++ {
			sx, su := float64(px)+.5-ox, ou-(float64(py)+.5)
			o := cam.Right.mul(sx).add(cam.Up.mul(su)).sub(cam.Fwd.mul(400))
			best, bi := math.Inf(1), -1
			var bn V3
			for i := range sol {
				t, n, ok := sol[i].Shape.hit(o, cam.Fwd)
				if !ok || t >= best {
					continue
				}
				if hp := o.add(cam.Fwd.mul(t)); hp[2] < opt.Ground-1e-6 {
					continue
				}
				best, bi, bn = t, i, n
			}
			if bi < 0 {
				continue
			}
			s := sol[bi]
			p := s.Prim
			mi, ok := mats.Index[p.Mat]
			if !ok {
				fail(errf("%s: unknown material %q", r.ID, p.Mat))
			}
			m := mats.List[mi]
			hit := o.add(cam.Fwd.mul(best))
			var local V3
			if opt.Layer == "art" {
				local = Xf{R: yawCW(opt.Aim)}.inv().apply(hit)
			} else {
				local = preInv.apply(unitInv.apply(hit))
			}
			pp := s.Local.inv().apply(hit) // prim-local
			step := m.Lo
			emis := m.Emissive
			if emis {
				if s.lit {
					step = m.LitStep
				}
			} else if !m.Flat {
				l := bn.dot(cam.Light)
				t := math.Max(0, math.Min(1, (l-cam.LMin)/(cam.LMax-cam.LMin)))
				step = m.Lo + int(math.Round(t*float64(m.Hi-m.Lo)))
				if m.Top != nil && bn[2] > .9 {
					step = *m.Top
				}
			}
			switch m.Pattern {
			case "links":
				k := int(math.Floor(pp[1]+float64(opt.Frame))) & 3
				if opt.Layer == "hull" && k == 0 {
					step = max(m.Lo, step-1)
				}
			case "spokes":
				rr := math.Hypot(pp[0], pp[1])
				a := math.Atan2(pp[1], pp[0])*180/math.Pi + float64(opt.Frame)*22.5
				if rr < p.R*.38 {
					step = m.Hi
				} else if int(math.Floor(a/45))&1 == 0 {
					step = max(m.Lo, step-1)
				}
			}
			*fr.at(px, py) = Px{Mat: mi, Step: int8(step), Prim: int16(s.id), Emis: emis, Art: opt.Layer == "art", N: bn, P: local, T: best}
		}
	}
	if !opt.NoRim {
		rim(fr, mats)
	}
	return fr
}

// rim lights the upper-left silhouette edge one step (not emissive or flat
// materials): the guides' rim light from the upper left.
func rim(fr *Frame, mats *Materials) {
	src := fr.clone()
	for y := 0; y < fr.H; y++ {
		for x := 0; x < fr.W; x++ {
			p := src.at(x, y)
			if p.Mat == 0 || p.Emis {
				continue
			}
			m := mats.List[p.Mat]
			if m.Flat {
				continue
			}
			if !src.filled(x, y-1) || !src.filled(x-1, y) {
				fr.at(x, y).Step = int8(min(m.Hi, int(p.Step)+1))
			}
		}
	}
}

// tagMatch: "" matches every prim, "!leg" every prim that is not a leg.
func tagMatch(p *Prim, tag string) bool {
	if tag == "" {
		return true
	}
	if tag[0] == '!' {
		return !tagMatch(p, tag[1:])
	}
	if tag == "leg" {
		return p.Kind == "leg" || p.has("leg")
	}
	return p.has(tag)
}
