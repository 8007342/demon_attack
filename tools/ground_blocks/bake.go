package main

// bake carries the AI colour of a unit's finished keyframes onto every base
// cell of its block. A keyframe is an AI image of a reference cell
// (<unit>.hull.ref.hNNN, hull and art composed; <unit>.art.ref.aNNN, the
// articulated layer alone), put on the grid by finish. Each keyframe texel
// is a sample at a rig surface point (Px.P: unit-local for the hull,
// art-local before the aim for the layer, so the same point at every
// heading, angle and frame). A sample keeps what the AI changed against the
// rig there:
//   - same ramp as the rig texel: the step offset (seams, dark panels,
//     highlights), re-applied over the target's own rig step, so each cell
//     keeps the lighting of its own heading;
//   - another ramp (a cyan strip, an ember eye on grey plate): the colour
//     itself, an accent.
// A target texel takes the nearest sample on the same primitive and layer
// (hull or art), ties broken toward the keyframe nearest the cell's heading
// or angle; texels no keyframe saw within bakeReach keep the rig colour.
// The rig owns every silhouette (no ring growth here); overlays stay rig.
// Colours stay in the master sector's ramps, so the pack's paintFinished
// remaps them per sector.

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

// bakeReach: the farthest a sample may be from the target point (rig units).
const bakeReach = 1.6

type bakeSample struct {
	P      V3
	angle  float64 // heading or aim of the keyframe
	accent bool
	ramp   string // accent: ramp and step of the AI colour
	step   int
	delta  int // same ramp: AI step - rig step
}

type bakeKey struct {
	art  bool
	prim int16
}

type Baker struct {
	p       *Project
	u       unitRef
	pal     *Palette
	master  string
	seed    int
	samples map[bakeKey][]bakeSample
	rev     map[color.NRGBA][2]any // colour -> ramp, step in the master sector
}

func (p *Project) newBaker(u unitRef) *Baker {
	bk := &Baker{p: p, u: u, pal: p.Pals[u.faction()], master: p.masterSector(u), seed: p.builder(u).Rig.Seed, samples: map[bakeKey][]bakeSample{}, rev: map[color.NRGBA][2]any{}}
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

// addKey finishes one AI image of a reference cell and records its samples.
func (bk *Baker) addKey(ref *Cell, src image.Image) *image.NRGBA {
	key := pixelgrid.Hex(orStr(bk.u.Fam.Sprite.Reference.Key, "#FF00FF"))
	fin := bk.p.finish(bk.u, ref, src, key)
	ang := bk.cellAngle(ref.Name)
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
			s := bakeSample{P: px.P, angle: ang}
			if ramp == rr {
				s.delta = step - rs
			} else {
				s.accent, s.ramp, s.step = true, ramp, step
			}
			k := bakeKey{px.Art, px.Prim}
			bk.samples[k] = append(bk.samples[k], s)
		}
	}
	return fin
}

func angDiff(a, b float64) float64 {
	d := math.Mod(math.Abs(a-b), 360)
	return math.Min(d, 360-d)
}

// colour of one target texel; ok is false when no sample reaches it.
func (bk *Baker) colour(px Px, ang float64) (color.NRGBA, bool) {
	// the keyframe nearest the cell's angle that saw this point wins, so a
	// cell's detail comes from one keyframe wherever it can (no speckle)
	ss := bk.samples[bakeKey{px.Art, px.Prim}]
	best, ba, bd := -1, math.Inf(1), math.Inf(1)
	for i := range ss {
		d := ss[i].P.sub(px.P).len()
		if d > bakeReach {
			continue
		}
		a := angDiff(ss[i].angle, ang)
		if a < ba-1e-9 || (a < ba+1e-9 && d < bd) {
			best, ba, bd = i, a, d
		}
	}
	if best < 0 {
		return color.NRGBA{}, false
	}
	s := ss[best]
	if s.accent {
		r := bk.pal.ramp(s.ramp, bk.master)
		return r[max(0, min(len(r)-1, s.step))], true
	}
	rn, rs := bk.rigTone(px)
	m := bk.pal.Mats.List[px.Mat]
	lo, hi := m.Lo, m.Hi
	if rn != m.Ramp { // a kit ramp: its own range
		lo, hi = 0, len(bk.pal.ramp(rn, bk.master))-1
	}
	r := bk.pal.ramp(rn, bk.master)
	return r[max(0, min(len(r)-1, max(lo, min(hi, rs+s.delta))))], true
}

// bakeCell paints one base cell from the samples (rig colour where none),
// with the ink outline.
func (bk *Baker) bakeCell(c *Cell) *image.NRGBA {
	f := c.F
	out := image.NewNRGBA(image.Rect(0, 0, f.W, f.H))
	ang := bk.cellAngle(c.Name)
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			px := f.at(x, y)
			if px.Mat == 0 {
				if f.filled(x-1, y) || f.filled(x+1, y) || f.filled(x, y-1) || f.filled(x, y+1) {
					out.SetNRGBA(x, y, bk.pal.Ink)
				}
				continue
			}
			col, ok := bk.colour(*px, ang)
			if !ok || px.Prim < 0 {
				col = bk.pal.colour(*px, bk.master, bk.seed)
			}
			out.SetNRGBA(x, y, col)
		}
	}
	return out
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

// cmdBake: bake <unit> [CELL=IMG ...]. With no keys named, the committed
// selected keyframes are used. Writes every base cell to finishedPath.
func cmdBake(args []string) {
	if len(args) < 1 {
		fail(fmt.Errorf("usage: bake <unit> [<unit>.hull.ref.hNNN=IMG | <unit>.art.ref.aNNN=IMG ...]"))
	}
	p := loadProject()
	u := p.unit(args[0])
	keys := map[string]string{}
	for _, a := range args[1:] {
		k, v, ok := strings.Cut(a, "=")
		if !ok {
			fail(fmt.Errorf("want CELL=IMG, got %q", a))
		}
		keys[k] = v
	}
	if len(keys) == 0 {
		keys = p.selectedKeys(u)
	}
	if len(keys) == 0 {
		fail(fmt.Errorf("%s: no keyframes", u.Spec.ID))
	}
	n, err := p.bake(u, keys, true)
	must(err)
	fmt.Printf("baked %d cells of %s from %d keyframes -> %s\n", n, u.Spec.ID, len(keys), filepath.Dir(finishedPath(u.Spec.ID, "x")))
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
