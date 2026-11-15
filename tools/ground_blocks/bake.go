package main

// bake carries the AI colour of a unit's finished keyframes onto every base
// cell of its block. A keyframe is an AI image of a reference cell
// (<unit>.hull.ref.hNNN, hull and art composed; <unit>.art.ref.aNNN, the
// articulated layer alone), put on the grid by finish; under the lean hybrid
// (plan §12) it is the unit's one hero. Each keyframe texel is a sample at a
// rig surface point (Px.P: unit-local for the hull, art-local before the aim
// for the layer, so the same point at every heading, angle and frame); how
// the samples become colour is described at "Bake v2" below. Colours stay in
// the master sector's ramps, so the pack's paintFinished remaps them per
// sector.

import (
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"demonattack/tools/pixelgrid"
)

// Bake v2 (lean hybrid, plan §12.1): the rig's shading is the base; the AI
// keyframes only decide each surface region's material and its accents.
//   - A region is one rig primitive, layer (hull or art) and facet (normal
//     binned): one material decision for all of it, so no per-texel noise.
//     Its decision is the median AI step offset against the rig (clamped
//     to ±bakeMaxDelta, applied over every target texel's own rig step), or,
//     when bakeRecolour of its samples fall in one other ramp, that ramp at
//     the majority step relative to the rig (a cyan plate, a violet panel).
//   - Accents (ramps of emissive materials: eyes, glow, light strips) are
//     kept point by point only where they cluster (bakeClusterMin samples
//     within bakeClusterR); a lone speck is dropped.
//   - Regions no keyframe saw borrow the nearest-normal seen region of the
//     same primitive; else the rig colour.
//   - Last, a despeckle: a texel the AI changed whose colour none of its 8
//     same-primitive neighbours shares takes their majority colour.
// Emissive and flat rig materials keep the rig colour. The rig owns every
// silhouette; overlays stay rig.

const (
	bakeMaxDelta   = 1
	bakeClusterR   = 1.5
	bakeClusterMin = 3
	bakeRecolour   = .6 // share of a region's samples another ramp needs to recolour it
	bakeAccentR    = 1.1
)

type bakeSample struct {
	P      V3
	accent bool   // an accent ramp (one an emissive material uses)
	other  bool   // another, non-accent ramp: votes for a region recolour
	ramp   string // accent or other: ramp and step of the AI colour
	step   int
	delta  int // same ramp: AI step - rig step
	rel    int // accent: AI step - rig step (for region recolours)
}

type bakeKey struct {
	art  bool
	prim int16
}

type regionKey struct {
	art  bool
	prim int16
	n    [3]int8
}

type regionMat struct {
	n     V3
	delta int
	ramp  string // "" = the rig's own ramp
	rel   int
}

type Baker struct {
	p       *Project
	u       unitRef
	pal     *Palette
	master  string
	seed    int
	regions map[regionKey][]bakeSample
	accents map[bakeKey][]bakeSample
	mats    map[regionKey]regionMat
	ready   bool
	accentR map[string]bool        // ramps of emissive materials: eyes, glow, light strips
	rev     map[color.NRGBA][2]any // colour -> ramp, step in the master sector
}

func (p *Project) newBaker(u unitRef) *Baker {
	bk := &Baker{p: p, u: u, pal: p.Pals[u.faction()], master: p.masterSector(u), seed: p.builder(u).Rig.Seed,
		regions: map[regionKey][]bakeSample{}, accents: map[bakeKey][]bakeSample{}, rev: map[color.NRGBA][2]any{}, accentR: map[string]bool{}}
	for _, m := range bk.pal.Mats.List {
		if m.Emissive {
			bk.accentR[m.Ramp] = true
		}
	}
	for _, n := range bk.pal.finishNames() {
		for i, col := range bk.pal.ramp(n, bk.master) {
			if _, ok := bk.rev[col]; !ok {
				bk.rev[col] = [2]any{n, i}
			}
		}
	}
	return bk
}

var angleRe = regexp.MustCompile(`\.[ha](\d{3})(\.|$)`)

// cellAngle: the heading or aim a cell name carries (hNNN / aNNN), else the
// unit's travel heading.
func (bk *Baker) cellAngle(name string) float64 {
	if m := angleRe.FindStringSubmatch(name); m != nil {
		v, _ := strconv.Atoi(m[1])
		if v == 22 || v == 67 || v == 112 || v == 157 {
			return float64(v) + .5
		}
		return float64(v)
	}
	b := bk.p.builder(bk.u)
	return b.Headings[b.Travel]
}

// rigTone: the ramp and step the rig paints a texel with in the master sector.
func (bk *Baker) rigTone(px Px) (string, int) {
	m := bk.pal.Mats.List[px.Mat]
	return bk.pal.kitted(px, m.Ramp, bk.master, bk.seed)
}

func nbin(n V3) [3]int8 {
	return [3]int8{int8(math.Round(n[0] * 2)), int8(math.Round(n[1] * 2)), int8(math.Round(n[2] * 2))}
}

func regionOf(px Px) regionKey { return regionKey{px.Art, px.Prim, nbin(px.N)} }

// addKey finishes one AI image of a reference cell and records its samples.
func (bk *Baker) addKey(ref *Cell, src image.Image) *image.NRGBA {
	key := pixelgrid.Hex(orStr(bk.u.Fam.Sprite.Reference.Key, "#FF00FF"))
	fin := bk.p.finish(bk.u, ref, src, key)
	for y := 0; y < ref.F.H; y++ {
		for x := 0; x < ref.F.W; x++ {
			px := ref.F.at(x, y)
			if px.Mat == 0 || px.Prim < 0 {
				continue
			}
			if !px.Art && nearArt(ref.F, x, y, 2) {
				continue // the AI's turret spills over the hull here
			}
			c := fin.NRGBAAt(x, y)
			t, ok := bk.rev[c]
			if !ok || c.A == 0 {
				continue
			}
			ramp, step := t[0].(string), t[1].(int)
			rr, rs := bk.rigTone(*px)
			s := bakeSample{P: px.P}
			if ramp == rr {
				s.delta = step - rs
			} else if bk.accentR[ramp] {
				s.accent, s.ramp, s.step, s.rel = true, ramp, step, step-rs
				k := bakeKey{px.Art, px.Prim}
				bk.accents[k] = append(bk.accents[k], s)
			} else {
				s.other, s.ramp, s.step, s.rel = true, ramp, step, step-rs
			}
			rk := regionOf(*px)
			bk.regions[rk] = append(bk.regions[rk], s)
		}
	}
	bk.ready = false
	return fin
}

// finalize decides every region's material and keeps clustered accents.
func (bk *Baker) finalize() {
	bk.mats = map[regionKey]regionMat{}
	for rk, ss := range bk.regions {
		var deltas []int
		acc := map[string][]int{}
		for _, s := range ss {
			if s.other {
				acc[s.ramp] = append(acc[s.ramp], s.rel)
			} else if !s.accent {
				deltas = append(deltas, s.delta)
			}
		}
		rm := regionMat{n: V3{float64(rk.n[0]) / 2, float64(rk.n[1]) / 2, float64(rk.n[2]) / 2}}
		// a ramp other than the rig's owning most of the region recolours it
		bestR, bestN := "", 0
		for _, r := range sortedStrings(acc) {
			if len(acc[r]) > bestN {
				bestR, bestN = r, len(acc[r])
			}
		}
		if float64(bestN) > bakeRecolour*float64(len(ss)) {
			rm.ramp, rm.rel = bestR, clampI(median(acc[bestR]), -bakeMaxDelta, bakeMaxDelta)
		} else if len(deltas) > 0 {
			rm.delta = clampI(median(deltas), -bakeMaxDelta, bakeMaxDelta)
		}
		bk.mats[rk] = rm
	}
	for k, ss := range bk.accents {
		var kept []bakeSample
		for i := range ss {
			n := 0
			for j := range ss {
				if ss[j].ramp == ss[i].ramp && ss[j].P.sub(ss[i].P).len() <= bakeClusterR {
					n++ // counts itself
				}
			}
			if n >= bakeClusterMin {
				kept = append(kept, ss[i])
			}
		}
		bk.accents[k] = kept
	}
	bk.ready = true
}

func sortedStrings[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func median(v []int) int {
	s := append([]int(nil), v...)
	sort.Ints(s)
	return s[len(s)/2]
}

func clampI(v, lo, hi int) int { return max(lo, min(hi, v)) }

// region: the material of a texel's region, or of the nearest-normal seen
// region of the same primitive and layer.
func (bk *Baker) region(px Px) (regionMat, bool) {
	rk := regionOf(px)
	if m, ok := bk.mats[rk]; ok {
		return m, true
	}
	best, bd, found := regionMat{}, -2.0, false
	for k, m := range bk.mats {
		if k.art != rk.art || k.prim != rk.prim {
			continue
		}
		d := m.n.norm().dot(px.N)
		if d > bd || (d == bd && lessRegion(m, best)) {
			best, bd, found = m, d, true
		}
	}
	return best, found
}

func lessRegion(a, b regionMat) bool {
	if a.ramp != b.ramp {
		return a.ramp < b.ramp
	}
	if a.delta != b.delta {
		return a.delta < b.delta
	}
	return a.rel < b.rel
}

// colour of one target texel; ok is false when nothing reaches it.
func (bk *Baker) colour(px Px, ang float64) (color.NRGBA, bool) {
	if !bk.ready {
		bk.finalize()
	}
	m := bk.pal.Mats.List[px.Mat]
	if m.Emissive || m.Flat || px.Emis {
		return color.NRGBA{}, false
	}
	rn, rs := bk.rigTone(px)
	// a clustered accent at this point
	ss := bk.accents[bakeKey{px.Art, px.Prim}]
	bi, bd := -1, bakeAccentR
	for i := range ss {
		if d := ss[i].P.sub(px.P).len(); d <= bd {
			bi, bd = i, d
		}
	}
	if bi >= 0 {
		r := bk.pal.ramp(ss[bi].ramp, bk.master)
		return r[clampI(rs+ss[bi].rel, 0, len(r)-1)], true
	}
	rm, ok := bk.region(px)
	if !ok {
		return color.NRGBA{}, false
	}
	if rm.ramp != "" {
		r := bk.pal.ramp(rm.ramp, bk.master)
		return r[clampI(rs+rm.rel, 0, len(r)-1)], true
	}
	lo, hi := m.Lo, m.Hi
	if rn != m.Ramp { // a kit ramp: its own range
		lo, hi = 0, len(bk.pal.ramp(rn, bk.master))-1
	}
	r := bk.pal.ramp(rn, bk.master)
	return r[clampI(clampI(rs+rm.delta, lo, hi), 0, len(r)-1)], true
}

// bakeCell paints one base cell (rig colour where nothing reaches), then
// despeckles what the AI changed, then inks the outline.
func (bk *Baker) bakeCell(c *Cell) *image.NRGBA {
	f := c.F
	out := image.NewNRGBA(image.Rect(0, 0, f.W, f.H))
	ang := bk.cellAngle(c.Name)
	rig := make([]color.NRGBA, f.W*f.H)
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			px := f.at(x, y)
			if px.Mat == 0 {
				continue
			}
			rig[y*f.W+x] = bk.pal.colour(*px, bk.master, bk.seed)
			col, ok := bk.colour(*px, ang)
			if !ok || px.Prim < 0 {
				col = rig[y*f.W+x]
			}
			out.SetNRGBA(x, y, col)
		}
	}
	// despeckle (reads the painted cell, writes a copy)
	src := image.NewNRGBA(out.Bounds())
	copy(src.Pix, out.Pix)
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			px := f.at(x, y)
			if px.Mat == 0 || src.NRGBAAt(x, y) == rig[y*f.W+x] {
				continue
			}
			me := src.NRGBAAt(x, y)
			votes := map[color.NRGBA]int{}
			same, n := false, 0
			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					q := f.at(x+dx, y+dy)
					if (dx == 0 && dy == 0) || q == nil || q.Mat == 0 || q.Prim != px.Prim || q.Art != px.Art {
						continue
					}
					c := src.NRGBAAt(x+dx, y+dy)
					n++
					votes[c]++
					if c == me {
						same = true
					}
				}
			}
			if same || n < 3 {
				continue
			}
			var best color.NRGBA
			bn := 0
			for c, v := range votes {
				if v > bn || (v == bn && lessColour(c, best)) {
					best, bn = c, v
				}
			}
			out.SetNRGBA(x, y, best)
		}
	}
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			if !f.filled(x, y) && (f.filled(x-1, y) || f.filled(x+1, y) || f.filled(x, y-1) || f.filled(x, y+1)) {
				out.SetNRGBA(x, y, bk.pal.Ink)
			}
		}
	}
	return out
}

func lessColour(a, b color.NRGBA) bool {
	if a.R != b.R {
		return a.R < b.R
	}
	if a.G != b.G {
		return a.G < b.G
	}
	return a.B < b.B
}

// selectedKeys finds the committed keyframes of a unit:
// art/sprites/sources/ground-blocks-selected/<unit>/hero/<seed>.png (the
// hero heading), heading/hNNN-<seed>.png and layer/aNNN-<seed>.png.
func (p *Project) selectedKeys(u unitRef) map[string]string {
	dir := filepath.Join(root, "art/sprites/sources/ground-blocks-selected", u.Spec.ID)
	keys := map[string]string{}
	if s := u.Spec.Hero.Selected; s != nil {
		f := filepath.Join(dir, "hero", fmt.Sprintf("%d.png", *s))
		if _, err := os.Stat(f); err == nil {
			keys[u.Spec.ID+".hull.ref.h"+hcode(u.Spec.Hero.Heading)] = f
		}
	}
	for sub, kind := range map[string]string{"heading": ".hull.ref.h", "layer": ".art.ref.a"} {
		fs, _ := filepath.Glob(filepath.Join(dir, sub, "*.png"))
		for _, f := range fs {
			b := filepath.Base(f)
			if len(b) >= 4 && (b[0] == 'h' || b[0] == 'a') {
				keys[u.Spec.ID+kind+b[1:4]] = f
			}
		}
	}
	return keys
}

// cmdBake: bake [--with-picks] (--all | <unit> [CELL=IMG ...]). With no keys
// named, the committed hero is used (plus any heading and layer picks with
// --with-picks; they put stray AI accents on other headings, §12.1). --all bakes every unit with
// a selected hero. Writes every base cell to finishedPath.
func cmdBake(args []string) {
	heroOnly, all := true, false
	var rest []string
	for _, a := range args {
		switch a {
		case "--with-picks":
			heroOnly = false
		case "--all":
			all = true
		default:
			rest = append(rest, a)
		}
	}
	if !all && len(rest) < 1 {
		fail(fmt.Errorf("usage: bake [--with-picks] (--all | <unit> [<unit>.hull.ref.hNNN=IMG | <unit>.art.ref.aNNN=IMG ...])"))
	}
	p := loadProject()
	var units []unitRef
	if all {
		for _, u := range p.units() {
			if u.Spec.Hero.Selected != nil {
				units = append(units, u)
			}
		}
	} else {
		units = []unitRef{p.unit(rest[0])}
		rest = rest[1:]
	}
	for _, u := range units {
		keys := map[string]string{}
		for _, a := range rest {
			k, v, ok := strings.Cut(a, "=")
			if !ok {
				fail(fmt.Errorf("want CELL=IMG, got %q", a))
			}
			keys[k] = v
		}
		if len(keys) == 0 {
			keys = p.selectedKeys(u)
			if heroOnly {
				hk := u.Spec.ID + ".hull.ref.h" + hcode(u.Spec.Hero.Heading)
				for k := range keys {
					if k != hk {
						delete(keys, k)
					}
				}
			}
		}
		if len(keys) == 0 {
			if all {
				continue
			}
			fail(fmt.Errorf("%s: no keyframes", u.Spec.ID))
		}
		n, err := p.bake(u, keys, true)
		must(err)
		fmt.Printf("baked %d cells of %s from %d keyframes\n", n, u.Spec.ID, len(keys))
	}
}

// bake builds the samples and paints every base cell; write puts them at
// finishedPath (stale cells of the unit are removed first).
func (p *Project) bake(u unitRef, keys map[string]string, write bool) (int, error) {
	bk := p.newBaker(u)
	names := make([]string, 0, len(keys))
	for k := range keys {
		names = append(names, k)
	}
	sort.Strings(names) // deterministic sample order
	for _, name := range names {
		ref := p.findCell(u, name)
		if ref == nil {
			return 0, fmt.Errorf("no reference cell %s", name)
		}
		src, err := pixelgrid.ReadPNG(keys[name])
		if err != nil {
			return 0, err
		}
		bk.addKey(ref, src)
	}
	if write {
		dir := filepath.Dir(finishedPath(u.Spec.ID, "x"))
		os.RemoveAll(dir)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return 0, err
		}
	}
	n := 0
	cs := p.cellsOf(u)
	for i := range cs {
		c := &cs[i]
		if c.Overlay {
			continue
		}
		img := bk.bakeCell(c)
		if write {
			if err := pixelgrid.WritePNG(finishedPath(u.Spec.ID, c.Name), img); err != nil {
				return n, err
			}
		}
		n++
	}
	return n, nil
}

// cmdBakeSheet OUT <unit> [substr ...]: rig | baked pairs of the unit's base
// cells (those whose name holds one of the substrings, default all), x5,
// three pairs per row, from the finished cells on disk.
func cmdBakeSheet(args []string) {
	if len(args) < 2 {
		fail(fmt.Errorf("usage: bakesheet OUT.png <unit> [name-substring ...]"))
	}
	p := loadProject()
	u := p.unit(args[1])
	pal := p.Pals[u.faction()]
	master, seed := p.masterSector(u), p.builder(u).Rig.Seed
	var cells []*Cell
	cs := p.cellsOf(u)
	for i := range cs {
		c := &cs[i]
		if c.Overlay {
			continue
		}
		ok := len(args) == 2
		for _, s := range args[2:] {
			ok = ok || strings.Contains(c.Name, s)
		}
		if ok {
			cells = append(cells, c)
		}
	}
	if len(cells) == 0 {
		fail(fmt.Errorf("no cells"))
	}
	const k, per, pad, lab = 5, 3, 6, 12
	cw, ch := cells[0].F.W*k, cells[0].F.H*k
	pw := 2*cw + pad
	W := per*(pw+2*pad) + pad
	rows := (len(cells) + per - 1) / per
	H := rows*(ch+lab+pad) + pad
	out := image.NewNRGBA(image.Rect(0, 0, W, H))
	fill(out, out.Bounds(), color.NRGBA{24, 26, 34, 255})
	for i, c := range cells {
		x := pad + (i%per)*(pw+2*pad)
		y := pad + (i/per)*(ch+lab+pad)
		text(out, x, y, 1, strings.TrimPrefix(c.Name, u.Spec.ID+"."), color.NRGBA{200, 200, 210, 255})
		y += lab
		rig := image.NewNRGBA(image.Rect(0, 0, c.F.W, c.F.H))
		pal.paintCell(rig, c, 0, 0, master, seed)
		fill(out, image.Rect(x, y, x+cw, y+ch), color.NRGBA{40, 44, 56, 255})
		fill(out, image.Rect(x+cw+pad, y, x+2*cw+pad, y+ch), color.NRGBA{40, 44, 56, 255})
		blit(out, rig, x, y, k, false)
		if fin := finishedCell(u.Spec.ID, c.Name); fin != nil {
			fn := image.NewNRGBA(fin.Bounds())
			for yy := 0; yy < fin.Bounds().Dy(); yy++ {
				for xx := 0; xx < fin.Bounds().Dx(); xx++ {
					r, g, b, a := fin.At(fin.Bounds().Min.X+xx, fin.Bounds().Min.Y+yy).RGBA()
					fn.SetNRGBA(xx, yy, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), uint8(a >> 8)})
				}
			}
			blit(out, fn, x+cw+pad, y, k, false)
		}
	}
	must(pixelgrid.WritePNG(args[0], out))
	fmt.Println("bake sheet", len(cells), "cells ->", args[0])
}

// nearArt: an articulated-layer texel within r (Chebyshev) of (x, y).
func nearArt(f *Frame, x, y, r int) bool {
	for dy := -r; dy <= r; dy++ {
		for dx := -r; dx <= r; dx++ {
			if q := f.at(x+dx, y+dy); q != nil && q.Mat != 0 && q.Art {
				return true
			}
		}
	}
	return false
}

// cmdBakeReview OUT <unit>:<substr>,<substr> ...: for each unit the matching
// base cells as rig | baked pairs at x4, then the baked cells at 1x in one
// strip, on a dark ground.
func cmdBakeReview(args []string) {
	if len(args) < 2 {
		fail(fmt.Errorf("usage: bakereview OUT.png <unit>:<substr>[,<substr>...] ..."))
	}
	p := loadProject()
	type pair struct {
		rig, fin *image.NRGBA
		name     string
	}
	type block struct {
		id    string
		pairs []pair
	}
	var blocks []block
	const k, pad, lab = 4, 6, 12
	W := 0
	for _, a := range args[1:] {
		id, subs, _ := strings.Cut(a, ":")
		u := p.unit(id)
		pal := p.Pals[u.faction()]
		master, seed := p.masterSector(u), p.builder(u).Rig.Seed
		bl := block{id: id}
		cs := p.cellsOf(u)
		for _, s := range strings.Split(subs, ",") {
			for i := range cs {
				c := &cs[i]
				if c.Overlay || !strings.Contains(c.Name, s) {
					continue
				}
				rig := image.NewNRGBA(image.Rect(0, 0, c.F.W, c.F.H))
				pal.paintCell(rig, c, 0, 0, master, seed)
				var fn *image.NRGBA
				if fin := finishedCell(id, c.Name); fin != nil {
					fn = image.NewNRGBA(image.Rect(0, 0, fin.Bounds().Dx(), fin.Bounds().Dy()))
					for yy := 0; yy < fin.Bounds().Dy(); yy++ {
						for xx := 0; xx < fin.Bounds().Dx(); xx++ {
							r, g, b, aa := fin.At(fin.Bounds().Min.X+xx, fin.Bounds().Min.Y+yy).RGBA()
							fn.SetNRGBA(xx, yy, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), uint8(aa >> 8)})
						}
					}
				}
				bl.pairs = append(bl.pairs, pair{rig, fn, strings.TrimPrefix(c.Name, id+".")})
				break
			}
		}
		blocks = append(blocks, bl)
	}
	// layout: pairs in rows of up to 4
	const per = 4
	H := pad
	for _, bl := range blocks {
		cw, ch := bl.pairs[0].rig.Bounds().Dx()*k, bl.pairs[0].rig.Bounds().Dy()*k
		W = max(W, pad+per*(2*cw+3*pad))
		rows := (len(bl.pairs) + per - 1) / per
		H += lab + rows*(ch+lab+pad) + bl.pairs[0].rig.Bounds().Dy() + 3*pad
	}
	out := image.NewNRGBA(image.Rect(0, 0, W, H))
	fill(out, out.Bounds(), color.NRGBA{24, 26, 34, 255})
	y := pad
	for _, bl := range blocks {
		text(out, pad, y, 2, bl.id, color.NRGBA{230, 230, 240, 255})
		y += lab
		cw, ch := bl.pairs[0].rig.Bounds().Dx()*k, bl.pairs[0].rig.Bounds().Dy()*k
		for i, pr := range bl.pairs {
			x := pad + (i%per)*(2*cw+3*pad)
			yy := y + (i/per)*(ch+lab+pad)
			text(out, x, yy, 1, pr.name, color.NRGBA{190, 190, 200, 255})
			fill(out, image.Rect(x, yy+lab, x+cw, yy+lab+ch), color.NRGBA{40, 44, 56, 255})
			fill(out, image.Rect(x+cw+pad, yy+lab, x+2*cw+pad, yy+lab+ch), color.NRGBA{40, 44, 56, 255})
			blit(out, pr.rig, x, yy+lab, k, false)
			if pr.fin != nil {
				blit(out, pr.fin, x+cw+pad, yy+lab, k, false)
			}
		}
		y += ((len(bl.pairs)+per-1)/per)*(ch+lab+pad) + pad
		x := pad
		for _, pr := range bl.pairs {
			if pr.fin != nil {
				blit(out, pr.fin, x, y, 1, false)
				x += pr.fin.Bounds().Dx() + 2
			}
		}
		y += bl.pairs[0].rig.Bounds().Dy() + 2*pad
	}
	must(pixelgrid.WritePNG(args[0], out))
	fmt.Println("bake review ->", args[0])
}
