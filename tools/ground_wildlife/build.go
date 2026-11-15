package main

import (
	"encoding/json"
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
)

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

func hexRGB(h string) [3]float64 {
	v, _ := strconv.ParseUint(strings.TrimPrefix(h, "#"), 16, 32)
	return [3]float64{float64(v >> 16 & 255), float64(v >> 8 & 255), float64(v & 255)}
}

func luma3(c [3]float64) float64 { return (.2126*c[0] + .7152*c[1] + .0722*c[2]) / 255 }

func lumaN(c color.NRGBA) float64 { return luma3([3]float64{float64(c.R), float64(c.G), float64(c.B)}) }

func chroma3(c [3]float64) float64 {
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

func scaleTo(c [3]float64, target float64) [3]float64 {
	k := target / math.Max(.01, luma3(c))
	return [3]float64{math.Min(255, c[0]*k), math.Min(255, c[1]*k), math.Min(255, c[2]*k)}
}

func nrgba(c [3]float64) color.NRGBA {
	return color.NRGBA{uint8(math.Round(c[0])), uint8(math.Round(c[1])), uint8(math.Round(c[2])), 255}
}

// ramp picks the species' 4 body steps from its sector palette: nearest
// luminance target, pulled toward the species hint hue, chroma capped; a
// target the palette cannot meet takes the hint scaled to that luminance.
func ramp(s Spec, e Species) [4]color.NRGBA {
	pal := loadPalette(e.Sector)
	hint := hexRGB(e.Hint)
	hc := chromaticity(hint)
	var out [4]color.NRGBA
	used := map[int]bool{}
	for i, t := range s.Caps.BodyLuma {
		best, bestCost := -1, math.Inf(1)
		for k, c := range pal {
			if chroma3(c) > s.Caps.Chroma || luma3(c) > s.Caps.MaxLuma {
				continue
			}
			ch := chromaticity(c)
			hd := math.Abs(ch[0]-hc[0]) + math.Abs(ch[1]-hc[1]) + math.Abs(ch[2]-hc[2])
			cost := math.Abs(luma3(c)-t)/t + s.Caps.HintWeight*hd*4
			if used[k] {
				cost += .4
			}
			if cost < bestCost {
				best, bestCost = k, cost
			}
		}
		if best < 0 || bestCost > .45 {
			out[i] = nrgba(scaleTo(hint, t))
			continue
		}
		used[best] = true
		out[i] = nrgba(pal[best])
	}
	// Keep the ramp ordered by luminance.
	sort.Slice(out[:], func(a, b int) bool { return lumaN(out[a]) < lumaN(out[b]) })
	return out
}

// ---------------------------------------------------------------------------
// Flock flyers
// ---------------------------------------------------------------------------

type flyerGeom struct {
	src           *image.NRGBA
	cx, cy, bh, k float64
	sin, cos      float64
	fold, lift    float64
	cellW, cellH  int
}

func opaque(im *image.NRGBA, x, y int) bool {
	b := im.Bounds()
	if x < 0 || y < 0 || x >= b.Dx() || y >= b.Dy() {
		return false
	}
	return im.NRGBAAt(x, y).A >= 128
}

func newGeom(s Spec, src *image.NRGBA) flyerGeom {
	g := flyerGeom{src: src, cellW: s.Atlas.FlockCell[0], cellH: s.Atlas.FlockCell[1],
		fold: s.Flock.FlapFold, lift: s.Flock.FlapLift}
	th := s.Flock.HeadingDeg * math.Pi / 180
	g.sin, g.cos = math.Sin(th), math.Cos(th)
	var sx, sy, n float64
	b := src.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if opaque(src, x, y) {
				sx += float64(x) + .5
				sy += float64(y) + .5
				n++
			}
		}
	}
	g.cx, g.cy = sx/n, sy/n
	g.bh = s.Flock.BodyFrac * float64(b.Dx()) / 2
	// Fit the rotated spread pose into the cell less a 1-texel margin.
	x0, y0, x1, y1 := math.Inf(1), math.Inf(1), math.Inf(-1), math.Inf(-1)
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if !opaque(src, x, y) {
				continue
			}
			dx, dy := float64(x)+.5-g.cx, float64(y)+.5-g.cy
			rx, ry := dx*g.cos-dy*g.sin, dx*g.sin+dy*g.cos
			x0, y0, x1, y1 = math.Min(x0, rx), math.Min(y0, ry), math.Max(x1, rx), math.Max(y1, ry)
		}
	}
	hw, hh := float64(g.cellW-2)/2, float64(g.cellH-2)/2
	g.k = math.Max(math.Max(-x0, x1)/hw, math.Max(-y0, y1)/hh)
	return g
}

// sample maps a cell point back to the source: un-rotate, then un-fold the
// wings for flap B (span pulled toward the body, tips lifted forward).
func (g flyerGeom) sample(u, v float64, flap int) (color.NRGBA, bool) {
	qx, qy := (u-float64(g.cellW)/2)*g.k, (v-float64(g.cellH)/2)*g.k
	dx, dy := qx*g.cos+qy*g.sin, -qx*g.sin+qy*g.cos
	if flap == 1 && math.Abs(dx) > g.bh {
		sg := math.Copysign(1, dx)
		ext := (math.Abs(dx) - g.bh) / g.fold
		dx = sg * (g.bh + ext)
		dy += g.lift * ext
	}
	x, y := int(math.Floor(g.cx+dx)), int(math.Floor(g.cy+dy))
	if !opaque(g.src, x, y) {
		return color.NRGBA{}, false
	}
	return g.src.NRGBAAt(x, y), true
}

// flyer renders one 16x12 cell (heading up-left; mirror for up-right).
func flyer(g flyerGeom, flap int, mirror bool, rp [4]color.NRGBA) *image.NRGBA {
	w, h := g.cellW, g.cellH
	lum := make([]float64, w*h)
	on := make([]bool, w*h)
	const ss = 4
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			hits, sum := 0, 0.0
			for j := 0; j < ss; j++ {
				for i := 0; i < ss; i++ {
					c, ok := g.sample(float64(x)+(float64(i)+.5)/ss, float64(y)+(float64(j)+.5)/ss, flap)
					if ok {
						hits++
						sum += lumaN(c)
					}
				}
			}
			if hits >= 5 {
				on[y*w+x] = true
				lum[y*w+x] = sum / float64(hits)
			}
		}
	}
	// Rank-quantise to the 4 steps (20 / 50 / 82 % quantiles).
	var ls []float64
	for i, o := range on {
		if o {
			ls = append(ls, lum[i])
		}
	}
	sort.Float64s(ls)
	q := func(p float64) float64 {
		if len(ls) == 0 {
			return 0
		}
		return ls[min(len(ls)-1, int(p*float64(len(ls))))]
	}
	t1, t2, t3 := q(.15), q(.4), q(.72)
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if !on[y*w+x] {
				continue
			}
			l := lum[y*w+x]
			st := 0
			switch {
			case l >= t3:
				st = 3
			case l >= t2:
				st = 2
			case l >= t1:
				st = 1
			}
			// The silhouette edge sits one step darker (a soft outline).
			// Only a texel open on three sides (a thin tip) steps down: thin
			// wings would otherwise be all outline at this size.
			open := 0
			for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
				nx, ny := x+d[0], y+d[1]
				if nx < 0 || ny < 0 || nx >= w || ny >= h || !on[ny*w+nx] {
					open++
				}
			}
			if open >= 3 && st > 1 {
				st--
			}
			if flap == 1 && st > 0 && rankWing(g, x, y, w) {
				st-- // raised wings turn from the sky light
			}
			ox := x
			if mirror {
				ox = w - 1 - x
			}
			out.SetNRGBA(ox, y, rp[st])
		}
	}
	return out
}

// rankWing: is cell texel (x, y) outside the body column (in cell space)?
func rankWing(g flyerGeom, x, y, w int) bool {
	qx, qy := (float64(x)+.5-float64(g.cellW)/2)*g.k, (float64(y)+.5-float64(g.cellH)/2)*g.k
	dx := qx*g.cos + qy*g.sin
	return math.Abs(dx) > g.bh*g.fold+g.bh
}

// ---------------------------------------------------------------------------
// Critter leaps
// ---------------------------------------------------------------------------

// isWarm: a red or orange texel (the demon_warm family, rule 3).
func isWarm(c color.NRGBA) bool {
	return float64(c.R) > 1.35*float64(c.G) && float64(c.R) > 1.2*float64(c.B) && c.R > 40
}

// isCool: a cyan-leaning texel (the ally_cyan family, rule 3).
func isCool(c color.NRGBA) bool {
	return float64(c.G) > 1.3*float64(c.R) && float64(c.B) > 1.3*float64(c.R) &&
		int(max(c.G, c.B))-int(c.R) > 51
}

type critter struct {
	sector     int
	id         string
	y, w, h, n int
}

func loadCritters() []critter {
	b, err := os.ReadFile(filepath.Join(root, "lib/game/flyover_atlas.dart"))
	must(err)
	re := regexp.MustCompile(`FlyoverCreature\((\d+), '([a-z-]+)', '[a-z]+', (\d+), (\d+), (\d+), (\d+)\)`)
	var out []critter
	for _, m := range re.FindAllStringSubmatch(string(b), -1) {
		a := func(i int) int { v, _ := strconv.Atoi(m[i]); return v }
		out = append(out, critter{a(1), m[2], a(3), a(4), a(5), a(6)})
	}
	return out
}

func toNRGBA(im image.Image) *image.NRGBA {
	b := im.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			out.Set(x, y, im.At(b.Min.X+x, b.Min.Y+y))
		}
	}
	return out
}

// darken caps a colour at luminance cap (times k), keeping its hue.
func darken(c color.NRGBA, capL, k float64) color.NRGBA {
	l := lumaN(c)
	f := k
	if l*k > capL {
		f = capL / l
	}
	return color.NRGBA{uint8(float64(c.R) * f), uint8(float64(c.G) * f), uint8(float64(c.B) * f), c.A}
}

// leapCell squashes or stretches the critter's walk frame 0 about its feet
// (bottom centre) into a cellW x cellH cell, feet on the bottom row.
func leapCell(sheet *image.NRGBA, cr critter, sq Squash, mirror bool, capL, warmL, k float64, cellW, cellH int) *image.NRGBA {
	out := image.NewNRGBA(image.Rect(0, 0, cellW, cellH))
	ow := min(cellW, int(math.Round(float64(cr.w)*sq.KX)))
	oh := min(cellH, int(math.Round(float64(cr.h)*sq.KY)))
	left, top := (cellW-ow)/2, max(0, cellH-oh-sq.Lift)
	for y := 0; y < oh; y++ {
		for x := 0; x < ow; x++ {
			sx := int(math.Floor((float64(x) + .5) * float64(cr.w) / float64(ow)))
			sy := cr.h - 1 - int(math.Floor((float64(oh-1-y)+.5)*float64(cr.h)/float64(oh)))
			if sy < 0 {
				continue
			}
			c := sheet.NRGBAAt(sx, cr.y+sy)
			if c.A < 128 {
				continue
			}
			c.A = 255
			ox := left + x
			if mirror {
				ox = cellW - 1 - ox
			}
			cl := capL
			if isWarm(c) || isCool(c) {
				cl = warmL
			}
			out.SetNRGBA(ox, top+y, darken(c, cl, k))
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// Offline pack
// ---------------------------------------------------------------------------

func blit(dst *image.NRGBA, src *image.NRGBA, ox, oy, scale int) {
	b := src.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			c := src.NRGBAAt(x, y)
			if c.A == 0 {
				continue
			}
			for j := 0; j < scale; j++ {
				for i := 0; i < scale; i++ {
					px, py := ox+x*scale+i, oy+y*scale+j
					if !(image.Point{px, py}).In(dst.Bounds()) {
						continue
					}
					if c.A == 255 {
						dst.SetNRGBA(px, py, c)
						continue
					}
					d := dst.NRGBAAt(px, py)
					a := float64(c.A) / 255
					mix := func(s, t uint8) uint8 { return uint8(float64(s)*a + float64(t)*(1-a)) }
					dst.SetNRGBA(px, py, color.NRGBA{mix(c.R, d.R), mix(c.G, d.G), mix(c.B, d.B), 255})
				}
			}
		}
	}
}

func fill(dst *image.NRGBA, r image.Rectangle, c color.NRGBA) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			dst.SetNRGBA(x, y, c)
		}
	}
}

// Sector fog tints (plan/ground-atmosphere.md section 2): review backdrops.
var fogTint = map[string]color.NRGBA{
	"krybor":   {0x3A, 0x44, 0x58, 255},
	"ringfall": {0x3D, 0x35, 0x50, 255},
	"ember":    {0x46, 0x30, 0x2C, 255},
	"hollow":   {0x2E, 0x3A, 0x35, 255},
	"carrier":  {0x3A, 0x28, 0x36, 255},
}

var sectorNames = []string{"krybor", "ringfall", "ember", "hollow", "carrier"}

type packed struct {
	atlas    *image.NRGBA
	flock    [][4]*image.NRGBA
	critters []critter
	leaps    [][4]*image.NRGBA
	sources  []*image.NRGBA
}

func pack(s Spec) packed {
	fw, fh := s.Atlas.FlockCell[0], s.Atlas.FlockCell[1]
	cw, ch := s.Atlas.CritterCell[0], s.Atlas.CritterCell[1]
	var p packed
	for _, e := range s.Species {
		src, err := readPNG(filepath.Join(root, "art/sprites/sources/ground-wildlife", e.ID+".png"))
		must(err)
		sn := toNRGBA(src)
		p.sources = append(p.sources, sn)
		g := newGeom(s, sn)
		rp := ramp(s, e)
		var cells [4]*image.NRGBA
		for i := 0; i < 4; i++ {
			cells[i] = flyer(g, i%2, i >= 2, rp)
		}
		p.flock = append(p.flock, cells)
	}
	sheetImg, err := readPNG(filepath.Join(root, s.Critters.Source))
	must(err)
	sheet := toNRGBA(sheetImg)
	byID := map[string]critter{}
	for _, c := range loadCritters() {
		byID[c.id] = c
	}
	for _, id := range s.Critters.IDs {
		cr, ok := byID[id]
		if !ok {
			fail(fmt.Errorf("critter %s not in flyover_atlas.dart", id))
		}
		p.critters = append(p.critters, cr)
		capL := s.Caps.MaxLuma
		p.leaps = append(p.leaps, [4]*image.NRGBA{
			leapCell(sheet, cr, s.Critters.Crouch, false, capL, s.Critters.WarmLuma, .9, cw, ch),
			leapCell(sheet, cr, s.Critters.Leap, false, capL, s.Critters.WarmLuma, 1, cw, ch),
			leapCell(sheet, cr, s.Critters.Crouch, true, capL, s.Critters.WarmLuma, .9, cw, ch),
			leapCell(sheet, cr, s.Critters.Leap, true, capL, s.Critters.WarmLuma, 1, cw, ch),
		})
	}
	flockH := fh * len(s.Species)
	H := flockH + ch*len(p.critters)
	p.atlas = image.NewNRGBA(image.Rect(0, 0, s.Atlas.Width, H))
	for r, cells := range p.flock {
		for i, c := range cells {
			blit(p.atlas, c, i*fw, r*fh, 1)
		}
	}
	for r, cells := range p.leaps {
		for i, c := range cells {
			blit(p.atlas, c, i*cw, flockH+r*ch, 1)
		}
	}
	return p
}

func cmdOffline() {
	s := loadSpec()
	p := pack(s)
	writePNG(filepath.Join(root, s.Atlas.File), p.atlas)
	writeDart(s, p)
	contact(s, p)
	fmt.Println("packed", s.Atlas.File, p.atlas.Bounds().Dx(), p.atlas.Bounds().Dy())
}

func writeDart(s Spec, p packed) {
	fw, fh := s.Atlas.FlockCell[0], s.Atlas.FlockCell[1]
	cw, ch := s.Atlas.CritterCell[0], s.Atlas.CritterCell[1]
	var b strings.Builder
	b.WriteString("// GENERATED by tools/ground_wildlife offline — do not edit by hand.\n")
	b.WriteString("// Source: art/families/ground-wildlife.json, art/sprites/sources/ground-wildlife/.\n\n")
	b.WriteString("import 'dart:ui' show Rect;\n\n")
	b.WriteString("/// Easter-egg wildlife (plan/ground-easter-eggs.md sections 4-5) in\n")
	b.WriteString("/// assets/images/ground-wildlife.png: flock flyers (one species per\n")
	b.WriteString("/// sector, flap A/B x heading up-left/up-right) and leap frames for the\n")
	b.WriteString("/// flyover critters (crouch/leap x facing). Presentation only.\n")
	b.WriteString("abstract final class GroundWildlifeAtlas {\n")
	fmt.Fprintf(&b, "  static const file = '%s';\n", filepath.Base(s.Atlas.File))
	fmt.Fprintf(&b, "  static const width = %d, height = %d;\n", p.atlas.Bounds().Dx(), p.atlas.Bounds().Dy())
	fmt.Fprintf(&b, "  static const flockW = %d, flockH = %d;\n", fw, fh)
	fmt.Fprintf(&b, "  static const critterW = %d, critterH = %d;\n", cw, ch)
	fmt.Fprintf(&b, "  static const critterTop = %d;\n\n", fh*len(s.Species))
	b.WriteString("  /// Flock species by sector (0 Krybor .. 4 Carrier).\n")
	b.WriteString("  static const flockSpecies = <String>[")
	for i, e := range s.Species {
		if i > 0 {
			b.WriteString(", ")
		}
		fmt.Fprintf(&b, "'%s'", e.ID)
	}
	b.WriteString("];\n\n")
	b.WriteString("  /// Critters with leap frames, in row order (ids of FlyoverAtlas.creatures).\n")
	b.WriteString("  static const critterIds = <String>[\n")
	for _, c := range p.critters {
		fmt.Fprintf(&b, "    '%s',\n", c.id)
	}
	b.WriteString("  ];\n\n")
	b.WriteString("  /// Flyer cell of sector [sector]'s species: [flap] 0 (spread) or 1\n")
	b.WriteString("  /// (raised), heading up-left or, with [right], up-right.\n")
	b.WriteString("  static Rect flock(int sector, int flap, {bool right = false}) =>\n")
	b.WriteString("      Rect.fromLTWH(((right ? 2 : 0) + (flap & 1)) * flockW * 1.0,\n")
	b.WriteString("          sector * flockH * 1.0, flockW * 1.0, flockH * 1.0);\n\n")
	b.WriteString("  /// Leap cell of critter row [index]: crouch, or with [leaping] the\n")
	b.WriteString("  /// stretched leap; [mirrored] matches the flyover sheet's mirrored\n")
	b.WriteString("  /// columns. Feet on the bottom row, body centred: anchor bottom-centre.\n")
	b.WriteString("  static Rect leap(int index, {bool leaping = false, bool mirrored = false}) =>\n")
	b.WriteString("      Rect.fromLTWH(((mirrored ? 2 : 0) + (leaping ? 1 : 0)) * critterW * 1.0,\n")
	b.WriteString("          (critterTop + index * critterH) * 1.0, critterW * 1.0, critterH * 1.0);\n")
	b.WriteString("}\n")
	must(os.WriteFile(filepath.Join(root, "lib/game/ground_wildlife_atlas.dart"), []byte(b.String()), 0o644))
	dartFormat(filepath.Join(root, "lib/game/ground_wildlife_atlas.dart"))
}

// contact: CP7 sheet. Top: per flock species on its sector's fog tint, the
// four cells x8, the source of record x2, and a loose flock at 1x and x2.
// Bottom: per critter, walk frame 0 | crouch | leap at x5 (both facings).
func contact(s Spec, p packed) {
	fw, fh := s.Atlas.FlockCell[0], s.Atlas.FlockCell[1]
	cw, ch := s.Atlas.CritterCell[0], s.Atlas.CritterCell[1]
	const W = 1000
	rowF := fh*8 + 12
	rowC := ch*5 + 12
	H := 8 + rowF*len(p.flock) + 8 + rowC*((len(p.critters)+1)/2) + 8
	img := image.NewNRGBA(image.Rect(0, 0, W, H))
	fill(img, img.Bounds(), color.NRGBA{0x0B, 0x0A, 0x12, 255})
	y := 8
	for r, cells := range p.flock {
		e := s.Species[r]
		fill(img, image.Rect(4, y, W-4, y+rowF-4), fogTint[e.Sector])
		for i, c := range cells {
			blit(img, c, 8+i*(fw*8+6), y+4, 8)
		}
		x := 8 + 4*(fw*8+6) + 4
		blit(img, p.sources[r], x, y+4, 1)
		x += 70
		// A loose flock of 7 at 1x and 5 at x2 (alternating flaps/headings).
		for k := 0; k < 7; k++ {
			c := cells[(k%2)+2*((k/3)%2)]
			blit(img, c, x+(k%4)*20+(k/4)*10, y+6+(k/4)*24+(k%3)*4, 1)
		}
		x += 100
		for k := 0; k < 4; k++ {
			blit(img, cells[k], x+k*36, y+8+(k%2)*30, 2)
		}
		y += rowF
	}
	y += 8
	sheetImg, _ := readPNG(filepath.Join(root, s.Critters.Source))
	sheet := toNRGBA(sheetImg)
	for i, cr := range p.critters {
		col := i % 2
		ox := 4 + col*(W/2)
		oy := y + (i/2)*rowC
		fill(img, image.Rect(ox, oy, ox+W/2-8, oy+rowC-4), fogTint[sectorNames[cr.sector]])
		walk := image.NewNRGBA(image.Rect(0, 0, cw, ch))
		for yy := 0; yy < cr.h; yy++ {
			for xx := 0; xx < cr.w; xx++ {
				c := sheet.NRGBAAt(xx, cr.y+yy)
				walk.SetNRGBA((cw-cr.w)/2+xx, ch-cr.h+yy, c)
			}
		}
		blit(img, walk, ox+4, oy+4, 5)
		blit(img, p.leaps[i][0], ox+4+(cw*5+4), oy+4, 5)
		blit(img, p.leaps[i][1], ox+4+2*(cw*5+4), oy+4, 5)
		// 1x strip: walk, crouch, leap, mirrored crouch, leap.
		sx := ox + 4 + 3*(cw*5+4)
		blit(img, walk, sx, oy+8, 1)
		for k := 0; k < 4; k++ {
			blit(img, p.leaps[i][k], sx+(k+1)*(cw+2), oy+8, 1)
		}
	}
	writePNG(filepath.Join(root, "art/contact/ground-wildlife.png"), img)
}

// cmdReview: candidates per species (rows) x seed (cols): raw crop at
// 128 px | flap A x6 | flap B x6, over the sector fog tint.
func cmdReview(out string) {
	s := loadSpec()
	fw := s.Atlas.FlockCell[0]
	blockW := 128 + 2*(fw*6+4) + 12
	img := image.NewNRGBA(image.Rect(0, 0, blockW*s.Sprite.Candidates, 136*len(s.Species)))
	fill(img, img.Bounds(), color.NRGBA{0x0B, 0x0A, 0x12, 255})
	for r, e := range s.Species {
		rp := ramp(s, e)
		for c := 0; c < s.Sprite.Candidates; c++ {
			raw, err := loadRaw(e.ID, e.Seed+c)
			if err != nil {
				continue
			}
			ox, oy := c*blockW, r*136
			fill(img, image.Rect(ox+2, oy+2, ox+blockW-2, oy+134), fogTint[e.Sector])
			blit(img, downscale(crop(raw), 128), ox+4, oy+4, 1)
			g := newGeom(s, downscale(crop(raw), s.Sprite.SourcePx))
			blit(img, flyer(g, 0, false, rp), ox+136, oy+30, 6)
			blit(img, flyer(g, 1, false, rp), ox+136+fw*6+4, oy+30, 6)
		}
	}
	writePNG(out, img)
	fmt.Println("review", out)
}
