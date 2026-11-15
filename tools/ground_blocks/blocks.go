package main

// Block layouts (plan/ground-unit-animation.md §4): V (vehicle, 4 rows),
// W (walker, 5 rows), K (command, 4 double rows) and I (infantry, 2 rows),
// each 20 columns. Every cell has a stable name
// <unit>.<layer>.<state>.h<heading>|a<angle>[.f<frame>].

import (
	"fmt"
	"math"

	"demonattack/tools/pixelgrid"
)

type Cell struct {
	Name    string
	Row     int // block-relative atlas row (K cells span Row and Row+1)
	Col     int
	F       *Frame
	Overlay bool // sparse: drawn on top, no outline
	Pieces  []string
}

func hcode(h float64) string { return fmt.Sprintf("%03d", int(math.Floor(math.Abs(h)))) }

type blockOut struct {
	b     *Builder
	cells []Cell
}

// add names a cell. An overlay with no opaque texel at that heading or angle
// (the feature is hidden from the camera) is not stored or named: the
// runtime draws nothing for a name missing from the layout.
func (o *blockOut) add(row, col int, name string, f *Frame, overlay bool) {
	if overlay && f.count() == 0 {
		return
	}
	o.cells = append(o.cells, Cell{Name: o.b.Rig.ID + "." + name, Row: row, Col: col, F: f, Overlay: overlay})
}

func (b *Builder) poseFrames(state string, n int) [][]Pose {
	ps := b.Rig.Poses[state]
	out := make([][]Pose, n)
	for i := 0; i < n; i++ {
		if len(ps) > 0 {
			out[i] = ps[min(i, len(ps)-1)]
		}
	}
	return out
}

func (b *Builder) move(h float64, f int) *Frame {
	o := b.opt(h)
	o.Frame, o.Moving = f, true
	o.Poses = b.basePoses()
	return b.hull(o)
}

// basePoses: prims that only appear in overlays (banners) are hidden.
func (b *Builder) basePoses() []Pose {
	if b.Rig.Block == "K" {
		return []Pose{{Tag: "banner", Hide: true}}
	}
	return nil
}

func (b *Builder) build() []Cell {
	o := &blockOut{b: b}
	switch b.Rig.Block {
	case "V":
		b.blockV(o)
	case "W":
		b.blockW(o)
	case "K":
		b.blockK(o)
	case "I":
		b.blockI(o)
	}
	return o.cells
}

// artRow: V row 1 (W row 2).
func (b *Builder) artRow(o *blockOut, row int) {
	host := b.Rig.Faction == "host"
	if b.Rig.Art == nil {
		if host {
			for i, h := range b.Headings {
				base := b.move(h, 0)
				for k := 1; k <= 3; k++ {
					o.add(row, 5*k+i, fmt.Sprintf("fx.fill%d.h%s", k, hcode(h)), b.fillOverlay(base, k), true)
				}
			}
		}
		return
	}
	for i, a := range b.Angles {
		ao := defaultOpt("art")
		ao.Aim = a
		base := b.art(ao)
		o.add(row, i, "art.aim.a"+hcode(a), base, false)
		if host {
			for k := 1; k <= 3; k++ {
				o.add(row, 5*k+i, fmt.Sprintf("fx.fill%d.a%s", k, hcode(a)), b.fillOverlay(base, k), true)
			}
			continue
		}
		fo := ao
		fo.Recoil = 2
		fo.Poses = []Pose{{Tag: "muzzle", Show: true, Lit: true}}
		o.add(row, 5+i, "art.fire.a"+hcode(a), b.art(fo), false)
		if len(b.Rig.Art.Elevations) > 0 {
			for e := 1; e <= min(2, len(b.Rig.Art.Elevations)); e++ {
				eo := ao
				eo.Elev = e
				o.add(row, 5+5*e+i, fmt.Sprintf("art.aim.a%s.f%d", hcode(a), e), b.art(eo), false)
			}
		} else {
			o.add(row, 10+i, "fx.dent.a"+hcode(a), b.dmgOverlay(base, 1, 1), true)
		}
	}
}

// fxRow: V row 2 (W row 3): lights, dmg1, dmg2, then arrival or totalled.
func (b *Builder) fxRow(o *blockOut, row int) {
	for i, h := range b.Headings {
		base := b.move(h, 0)
		o.add(row, i, "fx.lights.h"+hcode(h), b.lightsOverlay(base), true)
		o.add(row, 5+i, "fx.dmg1.h"+hcode(h), b.dmgOverlay(base, 1, 0), true)
		o.add(row, 10+i, "fx.dmg2.h"+hcode(h), b.dmgOverlay(base, 2, 0), true)
	}
	t := b.Headings[b.Travel]
	if b.Rig.Faction == "host" {
		for f, fr := range b.arrive() {
			o.add(row, 15+f, fmt.Sprintf("hull.arrive.h%s.f%d", hcode(t), f), fr, false)
		}
		return
	}
	for f, fr := range b.totalled() {
		o.add(row, 15+f, fmt.Sprintf("hull.totalled.h%s.f%d", hcode(t), f), fr, false)
	}
}

func (b *Builder) arrive() []*Frame {
	t := b.Headings[b.Travel]
	hgt := b.Bounds[1][2]
	out := []*Frame{b.slab(0, 2), b.slab(12, 3)}
	o := b.opt(t)
	o.Poses = b.basePoses()
	o.Ground, o.World = 0, V3{0, 0, -hgt * .5}
	out = append(out, merge(b.hull(o), b.shards(2.5, false)))
	o.World = V3{0, 0, -1.2}
	out = append(out, merge(b.hull(o), b.shards(4, true)))
	return out
}

func (b *Builder) totalled() []*Frame {
	var out []*Frame
	sz := b.size()
	run := []Prim{{Kind: "box", At: V3{-sz[0]/2 + 1.5, b.Bounds[0][1] - 4, 0}, Size: V3{2.4, 6, .6}, Mat: "track"}}
	for _, h := range []float64{-8, -14} {
		o := b.opt(h)
		out = append(out, merge(b.hull(o), b.temp(run, b.opt(0))))
	}
	for k := 0; k < 2; k++ {
		o := b.opt(0)
		if k == 1 {
			o.Poses = []Pose{{Tag: "", Lit: true}}
		}
		fr := b.hull(o)
		b.smokePuff(fr, k)
		out = append(out, fr)
	}
	return out
}

func (b *Builder) smokePuff(fr *Frame, k int) {
	x0, y0, x1, _ := fr.bbox()
	if x1 < 0 {
		return
	}
	cx := float64(x0+x1)/2 + 2
	cy := float64(y0) + 2 - float64(k)
	pixelgrid.Disc(matCanvas{fr, b.mat("smoke"), 2}, cx, cy, 2.2, 1.6, 0)
	pixelgrid.Disc(matCanvas{fr, b.mat("smoke"), 3}, cx-.6+float64(k), cy-1.4, 1.2, 1, 0)
}

func (b *Builder) pod(lit bool) *Frame {
	ps := []Prim{
		{Kind: "box", At: V3{0, 0, 0}, Size: V3{6, 7, .3}, Mat: "shadow"},
		{Kind: "ball", At: V3{0, 0, 2.4}, Size: V3{2.6, 3.2, 2.2}, Mat: "plate"},
		{Kind: "box", At: V3{0, -.5, 4.2}, Size: V3{1.2, 1.2, 1}, Mat: "light"},
	}
	o := b.opt(0)
	if lit {
		o.Poses = []Pose{{Lit: true}}
	}
	r := &Rig{ID: b.Rig.ID + "-pod", Faction: "fleet", Hull: ps}
	if lit {
		r.Hull[2].Tags = []string{"x"}
		o.Poses = []Pose{{Tag: "x", Lit: true}}
	}
	fr := r.render(o, b.Cam, b.Mats, b.CW, b.CH, b.Ox, b.Ou)
	for i := range fr.Px {
		fr.Px[i].Prim = -1
	}
	return fr
}

func (b *Builder) composed(h float64, o RenderOpt) *Frame {
	o.Heading = h
	hull := b.hull(o)
	if b.Rig.Art == nil {
		return hull
	}
	ao := defaultOpt("art")
	ao.Aim = h
	for _, ps := range o.Poses {
		if ps.Tag != "" {
			ao.Poses = append(ao.Poses, ps)
		}
	}
	return b.composite(hull, b.art(ao), h)
}

func (b *Builder) wreck(k int) *Frame {
	t := b.Headings[b.Travel]
	o := b.opt(t)
	o.Poses = b.basePoses()
	o.Unit = rotAbout(rollRight(5), V3{})
	fr := b.composed(t, o)
	glow := b.mat("glow")
	for i, p := range fr.Px {
		if p.Mat == 0 {
			continue
		}
		m := b.Mats.List[p.Mat]
		if p.Emis {
			fr.Px[i] = Px{Mat: glow, Step: 0, Prim: p.Prim, T: p.T}
			continue
		}
		fr.Px[i].Step = int8(max(m.Lo, int(p.Step)-1))
		h := pixelgrid.Hash01(b.Rig.Seed+k, i)
		if p.N[2] > .7 && h < .07 {
			fr.Px[i] = Px{}
		} else if h > .965 {
			fr.Px[i] = Px{Mat: glow, Step: int8(2 + k), Prim: p.Prim, T: p.T}
		}
	}
	return fr
}

// statesRow: V row 3 from column c0 (W row 4 uses columns 8-19 at 4).
func (b *Builder) statesRow(o *blockOut, row int) {
	host := b.Rig.Faction == "host"
	axis := []int{0, 1, 2}
	if host {
		axis = []int{2, 3, 4}
	}
	if b.Rig.Block == "V" {
		for k, hi := range axis {
			h := b.Headings[hi]
			up, down := b.pitchOpt(h, 1, 8), b.pitchOpt(h, -1, 8)
			up.Poses, down.Poses = b.basePoses(), b.basePoses()
			o.add(row, 2*k, "hull.pitchUp.h"+hcode(h), b.hull(up), false)
			o.add(row, 2*k+1, "hull.pitchDown.h"+hcode(h), b.hull(down), false)
		}
		t := b.Headings[b.Travel]
		for f := 0; f < 2; f++ {
			fo := b.opt(t)
			fo.Moving, fo.Frame = true, f*2
			o.add(row, 6+f, fmt.Sprintf("hull.ford.h%s.f%d", hcode(t), f), b.ford(fo, 2.5, f), false)
		}
	}
	b.tailStates(o, row, 8)
}

// tailStates: V row 3 columns 8-19, placed from column c in the row.
func (b *Builder) tailStates(o *blockOut, row, c int) {
	host := b.Rig.Faction == "host"
	t := b.Headings[b.Travel]
	ht := hcode(t)
	sp := b.poseFrames("special", 6)
	special := func(f int) *Frame {
		so := b.opt(t)
		so.Poses = append(b.basePoses(), sp[f]...)
		return b.composed(t, so)
	}
	if b.Rig.Class == "light" {
		air := b.pitchOpt(t, 1, 9)
		air.World = V3{0, 0, 2}
		land := b.pitchOpt(t, -1, 5)
		o.add(row, c, "hull.air.h"+ht, b.hull(air), false)
		o.add(row, c+1, "hull.land.h"+ht, b.hull(land), false)
	} else {
		o.add(row, c, fmt.Sprintf("hull.special.h%s.f4", ht), special(4), false)
		o.add(row, c+1, fmt.Sprintf("hull.special.h%s.f5", ht), special(5), false)
	}
	for f := 0; f < 4; f++ {
		o.add(row, c+2+f, fmt.Sprintf("hull.special.h%s.f%d", ht, f), special(f), false)
	}
	if host {
		o.add(row, c+6, "hull.wreck.h"+ht+".f0", b.wreck(0), false)
		o.add(row, c+7, "hull.wreck.h"+ht+".f1", b.wreck(1), false)
		o.add(row, c+8, "hull.rubble.h"+ht+".f0", b.heap(2, false), false)
		o.add(row, c+9, "hull.rubble.h"+ht+".f1", b.heap(1, false), false)
		so := b.opt(t)
		so.Poses = b.basePoses()
		sheets, names := b.debrisSheets(b.composed(t, so))
		for s := 0; s < 2; s++ {
			o.add(row, c+10+s, fmt.Sprintf("debris.sheet.f%d", s), sheets[s], false)
			lo, hi := s*6, min(len(names), s*6+6)
			if lo < hi {
				o.cells[len(o.cells)-1].Pieces = names[lo:hi]
			}
		}
		return
	}
	o.add(row, c+6, "hull.pod.h"+ht+".f0", b.pod(true), false)
	o.add(row, c+7, "hull.pod.h"+ht+".f1", b.pod(false), false)
	o.add(row, c+10, "debris.shards.f0", b.shardSheet(), false)
}

// shardSheet: six small Fleet armour flakes (hit shards, never a breakup).
func (b *Builder) shardSheet() *Frame {
	fr := newFrame(b.CW, b.CH, b.Ox, b.Ou)
	r := pixelgrid.NewRng(b.Rig.Seed + 9)
	plate := b.mat("plate")
	for j := 0; j < 6; j++ {
		sx, sy := float64((j%3)*16), float64((j/3)*20)
		cx, cy := sx+8, sy+14
		s := 2 + r.F()*2
		pixelgrid.Tri(matCanvas{fr, plate, int8(2 + j%3)}, cx-s, cy+s*.6, cx+s*r.F(), cy-s, cx+s, cy+s*.4, 0)
	}
	return fr
}

func (b *Builder) blockV(o *blockOut) {
	for i, h := range b.Headings {
		for f := 0; f < 4; f++ {
			o.add(0, i*4+f, fmt.Sprintf("hull.move.h%s.f%d", hcode(h), f), b.move(h, f), false)
		}
	}
	b.artRow(o, 1)
	b.fxRow(o, 2)
	b.statesRow(o, 3)
}

func (b *Builder) idle(h float64, f int) *Frame {
	io := b.opt(h)
	io.Poses = b.basePoses()
	if f == 1 {
		io.Poses = append(io.Poses, Pose{Tag: "!leg", Move: V3{0, 0, 1.15}})
	}
	io.Poses = append(io.Poses, b.poseFrames("idle", 2)[f]...)
	return b.hull(io)
}

func (b *Builder) blockW(o *blockOut) {
	n := 6
	for i, h := range b.Headings {
		row, c0 := 0, i*6
		if i >= 3 {
			row, c0 = 1, (i-3)*6
		}
		for f := 0; f < n; f++ {
			o.add(row, c0+f, fmt.Sprintf("hull.move.h%s.f%d", hcode(h), f), b.move(h, f), false)
		}
	}
	h2, h3 := b.Headings[2], b.Headings[3]
	o.add(0, 18, "hull.idle.h"+hcode(h2)+".f0", b.idle(h2, 0), false)
	o.add(0, 19, "hull.idle.h"+hcode(h2)+".f1", b.idle(h2, 1), false)
	o.add(1, 12, "hull.idle.h"+hcode(h3)+".f0", b.idle(h3, 0), false)
	o.add(1, 13, "hull.idle.h"+hcode(h3)+".f1", b.idle(h3, 1), false)
	t := b.Headings[b.Travel]
	for f := 0; f < 3; f++ {
		so := b.opt(t)
		so.Moving, so.Frame, so.LiftMul = true, f*2, 2.4
		o.add(1, 14+f, fmt.Sprintf("hull.strideOver.h%s.f%d", hcode(t), f), b.hull(so), false)
	}
	for f := 0; f < 2; f++ {
		co := b.pitchOpt(t, 1, 14)
		co.Moving, co.Frame = true, f*3
		o.add(1, 17+f, fmt.Sprintf("hull.climb.h%s.f%d", hcode(t), f), b.hull(co), false)
	}
	b.artRow(o, 2)
	b.fxRow(o, 3)
	for f := 0; f < 2; f++ {
		do := b.pitchOpt(t, -1, 12)
		do.Moving, do.Frame = true, f*3
		o.add(4, f, fmt.Sprintf("hull.descend.h%s.f%d", hcode(t), f), b.hull(do), false)
		fo := b.opt(t)
		fo.Moving, fo.Frame = true, f*3
		o.add(4, 2+f, fmt.Sprintf("hull.ford.h%s.f%d", hcode(t), f), b.ford(fo, 3.5, f), false)
	}
	b.tailStates(o, 4, 4)
}

// K: double-height cells; Row counts 40-texel atlas rows (2 per double row).
func (b *Builder) blockK(o *blockOut) {
	for i, h := range b.Headings {
		for f := 0; f < 6; f++ {
			o.add(0, i*6+f, fmt.Sprintf("hull.move.h%s.f%d", hcode(h), f), b.move(h, f), false)
		}
	}
	t := b.Headings[b.Travel]
	ht := hcode(t)
	o.add(0, 18, "hull.idle.h"+ht+".f0", b.idle(t, 0), false)
	o.add(0, 19, "hull.idle.h"+ht+".f1", b.idle(t, 1), false)
	for i, h := range b.Headings {
		base := b.move(h, 0)
		o.add(2, i, "fx.lights.h"+hcode(h), b.lightsOverlay(base), true)
		o.add(2, 3+i, "fx.dmg1.h"+hcode(h), b.dmgOverlay(base, 1, 0), true)
		o.add(2, 6+i, "fx.dmg2.h"+hcode(h), b.dmgOverlay(base, 2, 0), true)
		for f := 0; f < 3; f++ {
			bo := b.opt(h)
			bo.Poses = []Pose{{Tag: "!banner", Hide: true}, {Tag: "banner", Show: true}}
			bo.Poses = append(bo.Poses, b.poseFrames("banner", 3)[f]...)
			ov := b.hull(bo)
			// keep only the banner prims, occluded by the body
			body := base
			for j, p := range ov.Px {
				if p.Mat == 0 {
					continue
				}
				if q := body.Px[j]; q.Mat != 0 && q.T < p.T-.01 {
					ov.Px[j] = Px{}
				}
			}
			o.add(2, 9+i*3+f, fmt.Sprintf("fx.banner.h%s.f%d", hcode(h), f), ov, true)
		}
	}
	sp := b.poseFrames("special", 4)
	for f := 0; f < 4; f++ {
		so := b.opt(t)
		so.Poses = append(b.basePoses(), sp[f]...)
		fr := b.hull(so)
		if f >= 2 {
			b.ring(fr, float64(f-1))
		}
		o.add(4, f, fmt.Sprintf("hull.special.h%s.f%d", ht, f), fr, false)
	}
	fp := b.poseFrames("fall", 5)
	for f := 0; f < 5; f++ {
		fo := b.opt(t)
		fo.Poses = append(b.basePoses(), fp[f]...)
		fo.Ground = 0
		fo.World = V3{0, 0, -float64(f) * float64(f) * .45}
		var fr *Frame
		if f == 4 {
			fr = merge(b.heap(2, false), b.hull(fo))
		} else {
			fr = b.hull(fo)
		}
		o.add(4, 4+f, fmt.Sprintf("hull.fall.h%s.f%d", ht, f), fr, false)
	}
	for f, fr := range b.arrive() {
		o.add(4, 9+f, fmt.Sprintf("hull.arrive.h%s.f%d", ht, f), fr, false)
	}
	for k := 0; k < 2; k++ {
		fr := b.heap(int8(2-k), false)
		pixelgrid.Disc(matCanvas{fr, b.mat("glow"), int8(4 - 2*k)}, b.Ox, b.Ou-4, .8, .8, 0)
		o.add(4, 13+k, fmt.Sprintf("hull.rubble.h%s.f%d", ht, k), fr, false)
	}
	so := b.opt(t)
	so.Poses = b.basePoses()
	sheets, names := b.debrisSheets(b.hull(so))
	for s := 0; s < 2; s++ {
		o.add(6, s, fmt.Sprintf("debris.sheet.f%d", s), sheets[s], false)
		lo, hi := s*6, min(len(names), s*6+6)
		if lo < hi {
			o.cells[len(o.cells)-1].Pieces = names[lo:hi]
		}
	}
}

// ring: a stepped warm command-pulse ring on the ground.
func (b *Builder) ring(fr *Frame, k float64) {
	glow := b.mat("glow")
	rx := 6 + k*5
	ry := rx * math.Sin(rad(b.Cam.Elev))
	for a := 0.0; a < 360; a += 4 {
		x := b.Ox + rx*math.Cos(rad(a))
		y := b.Ou - .5 + ry*math.Sin(rad(a))
		p := fr.at(int(math.Floor(x)), int(math.Floor(y)))
		if p != nil && p.Mat == 0 {
			*p = Px{Mat: glow, Step: int8(3 - int(k)), Prim: -1, T: -1}
		}
	}
}

func (b *Builder) blockI(o *blockOut) {
	host := b.Rig.Faction == "host"
	for i, h := range b.Headings {
		for f := 0; f < 4; f++ {
			o.add(0, i*4+f, fmt.Sprintf("hull.walk.h%s.f%d", hcode(h), f), b.move(h, f), false)
		}
	}
	p := b.Headings[b.Primary]
	hp := hcode(p)
	st := func(row, col int, state string, f int, opt RenderOpt) {
		o.add(row, col, fmt.Sprintf("hull.%s.h%s.f%d", state, hp, f), b.hull(opt), false)
	}
	with := func(ps ...[]Pose) RenderOpt {
		x := b.opt(p)
		for _, q := range ps {
			x.Poses = append(x.Poses, q...)
		}
		return x
	}
	o.add(0, 12, "hull.idle.h"+hp+".f0", b.idle(p, 0), false)
	o.add(0, 13, "hull.idle.h"+hp+".f1", b.idle(p, 1), false)
	aim := b.poseFrames("aim", 2)
	st(0, 14, "aim", 0, with(aim[0]))
	st(0, 15, "aim", 1, with(aim[1]))
	st(0, 16, "fire", 0, with(aim[1], []Pose{{Tag: "muzzle", Show: true, Lit: true}}))
	hit := b.hull(with())
	for j, q := range hit.Px {
		if q.Mat != 0 && !q.Emis {
			hit.Px[j].Step = int8(min(b.Mats.List[q.Mat].Hi, int(q.Step)+1))
		}
	}
	o.add(0, 17, "hull.hit.h"+hp+".f0", hit, false)
	front := b.Bounds[1][1]
	for f, deg := range []float64{-35, -82} {
		fo := with()
		if host {
			shift := .5 * b.Bounds[1][2] * math.Sin(rad(-deg))
			fo.Unit = rotAbout(pitchUp(deg), V3{0, 2, 0}).then(move(V3{0, -shift, 0})) // about the toes
			fo.Ground = 0
		} else {
			fo.Unit = rotAbout(pitchUp(deg/6), V3{0, front, 0})
			fo.World, fo.Ground = V3{0, 0, -1.5 * float64(f+1)}, 0
		}
		st(0, 18+f, "fall", f, fo)
	}
	if host {
		o.add(1, 0, "hull.rubble.h"+hp+".f0", b.heap(1, true), false)
		hgt := b.Bounds[1][2]
		for f, dz := range []float64{-hgt * .7, -hgt * .35, -1.2} {
			ao := with()
			ao.World, ao.Ground = V3{0, 0, dz}, 0
			fr := b.hull(ao)
			if f < 2 {
				fr = merge(fr, b.shards(1, f == 1))
			}
			o.add(1, 1+f, fmt.Sprintf("hull.arrive.h%s.f%d", hp, f), fr, false)
		}
	} else {
		ko := with(b.poseFrames("kneel", 1)[0])
		ko.World, ko.Ground = V3{0, 0, -3}, 0
		st(1, 0, "kneel", 0, ko)
		for f, dz := range []float64{3.5, 1.5, -1} {
			ao := with()
			ao.World = V3{0, 0, dz}
			ao.Unit = rotAbout(pitchUp(-6*float64(2-f)), V3{})
			if dz < 0 {
				ao.Ground = 0
			}
			st(1, 1+f, "arrive", f, ao)
		}
	}
	for f := 0; f < 2; f++ {
		ro := with()
		ro.Moving, ro.Frame, ro.StrideMul = true, 1+2*f, 1.6
		ro.Unit = rotAbout(pitchUp(-10), V3{})
		st(1, 4+f, "run", f, ro)
	}
	fl := b.poseFrames("flourish", 4)
	for f := 0; f < 4; f++ {
		do := with(fl[f])
		switch f {
		case 0:
			do.Unit = rotAbout(rollRight(10), V3{})
		case 2:
			do.Unit = rotAbout(rollRight(-10), V3{})
		default:
			do.World = V3{0, 0, 1.2}
			do.Poses = append(do.Poses, aim[0]...)
		}
		st(1, 6+f, "flourish", f, do)
	}
	for f := 0; f < 2; f++ {
		co := with()
		co.Moving, co.Frame, co.StrideMul = true, f*2, .6
		co.Unit = rotAbout(pitchUp(16), V3{})
		st(1, 10+f, "climb", f, co)
		de := with()
		de.Moving, de.Frame, de.StrideMul = true, 1+f*2, .6
		de.Unit = rotAbout(pitchUp(-12), V3{})
		st(1, 12+f, "descend", f, de)
	}
	cr := with()
	cr.Unit, cr.World, cr.Ground = rotAbout(pitchUp(-8), V3{}), V3{0, 0, -1.6}, 0
	st(1, 14, "jump", 0, cr)
	air := with()
	_, top, _, _ := b.idle(p, 0).bbox()
	air.Moving, air.Frame, air.World = true, 1, V3{0, 0, math.Min(2.4, float64(top-1)/math.Cos(rad(b.Cam.Elev)))}
	st(1, 15, "jump", 1, air)
	ld := with()
	ld.World, ld.Ground = V3{0, 0, -1}, 0
	st(1, 16, "jump", 2, ld)
	for f := 0; f < 2; f++ {
		wo := with()
		wo.Moving, wo.Frame = true, f*2
		o.add(1, 17+f, fmt.Sprintf("hull.wade.h%s.f%d", hp, f), b.ford(wo, 4.5, f), false)
	}
	cl := with(aim[0])
	cl.Unit = rotAbout(pitchUp(14), V3{})
	st(1, 19, "climbLine", 0, cl)
}
