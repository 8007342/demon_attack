package main

import (
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strings"
)

func hexRGB(h string) [3]float64 {
	var r, g, b int
	fmt.Sscanf(strings.TrimPrefix(h, "#"), "%02x%02x%02x", &r, &g, &b)
	return [3]float64{float64(r), float64(g), float64(b)}
}

func fill(dst *image.NRGBA, r image.Rectangle, c color.NRGBA) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			dst.SetNRGBA(x, y, c)
		}
	}
}

// over composites src onto dst at (ox, oy), [scale]x nearest-neighbour.
func over(dst, src *image.NRGBA, ox, oy, scale int) {
	b := src.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			c := src.NRGBAAt(x, y)
			if c.A == 0 {
				continue
			}
			for sy := 0; sy < scale; sy++ {
				for sx := 0; sx < scale; sx++ {
					px, py := ox+x*scale+sx, oy+y*scale+sy
					if !(image.Point{px, py}.In(dst.Bounds())) {
						continue
					}
					d := dst.NRGBAAt(px, py)
					a := float64(c.A) / 255
					mix := func(s, t uint8) uint8 { return uint8(float64(s)*a + float64(t)*(1-a) + .5) }
					dst.SetNRGBA(px, py, color.NRGBA{mix(c.R, d.R), mix(c.G, d.G), mix(c.B, d.B),
						uint8(math.Max(float64(d.A), float64(c.A)))})
				}
			}
		}
	}
}

// finish makes the downscaled source a crisp sprite: binary alpha, colours
// pulled a little toward the species hint and posterised to 6 levels per
// channel (a small pixel-art ramp), and a 1 px dark outline so a kite reads
// over bright cloud as well as the night sky.
func finish(src *image.NRGBA, hint string) *image.NRGBA {
	h := hexRGB(hint)
	b := src.Bounds()
	w, ht := b.Dx()+2, b.Dy()+2
	out := image.NewNRGBA(image.Rect(0, 0, w, ht))
	solid := func(x, y int) bool {
		if x < 0 || y < 0 || x >= b.Dx() || y >= b.Dy() {
			return false
		}
		return src.NRGBAAt(x, y).A >= 110
	}
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if !solid(x, y) {
				continue
			}
			c := src.NRGBAAt(x, y)
			ch := [3]float64{float64(c.R), float64(c.G), float64(c.B)}
			var o [3]uint8
			for i := range ch {
				v := ch[i]*.8 + h[i]*.2
				v = math.Round(v/51) * 51
				o[i] = uint8(math.Max(0, math.Min(255, v)))
			}
			out.SetNRGBA(x+1, y+1, color.NRGBA{o[0], o[1], o[2], 255})
		}
	}
	ink := color.NRGBA{0x14, 0x0C, 0x1C, 255}
	for y := -1; y <= b.Dy(); y++ {
		for x := -1; x <= b.Dx(); x++ {
			if solid(x, y) {
				continue
			}
			if solid(x-1, y) || solid(x+1, y) || solid(x, y-1) || solid(x, y+1) {
				out.SetNRGBA(x+1, y+1, ink)
			}
		}
	}
	return out
}

// rotate turns [im] by [deg] about its centre into a w x h cell
// (nearest neighbour, so the pixels stay square and the palette closed).
func rotate(im *image.NRGBA, deg float64, w, h int) *image.NRGBA {
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	b := im.Bounds()
	cx, cy := float64(b.Dx())/2, float64(b.Dy())/2
	r := deg * math.Pi / 180
	cs, sn := math.Cos(r), math.Sin(r)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			dx, dy := float64(x)+.5-float64(w)/2, float64(y)+.5-float64(h)/2
			sx := cs*dx + sn*dy + cx
			sy := -sn*dx + cs*dy + cy
			ix, iy := int(math.Floor(sx)), int(math.Floor(sy))
			if ix < 0 || iy < 0 || ix >= b.Dx() || iy >= b.Dy() {
				continue
			}
			out.SetNRGBA(x, y, im.NRGBAAt(ix, iy))
		}
	}
	return out
}

// torn is the pop frame: the membrane split down the middle, the halves
// thrown apart and turned, a few pixels shed.
func torn(im *image.NRGBA, w, h int) *image.NRGBA {
	b := im.Bounds()
	half := func(left bool) *image.NRGBA {
		o := image.NewNRGBA(b)
		for y := 0; y < b.Dy(); y++ {
			for x := 0; x < b.Dx(); x++ {
				if (x < b.Dx()/2) == left && (x+y)%7 != 0 {
					o.SetNRGBA(x, y, im.NRGBAAt(x, y))
				}
			}
		}
		return o
	}
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	l := rotate(half(true), -18, w, h)
	r := rotate(half(false), 22, w, h)
	over(out, shift(l, -3, -2), 0, 0, 1)
	over(out, shift(r, 3, 2), 0, 0, 1)
	return out
}

func shift(im *image.NRGBA, dx, dy int) *image.NRGBA {
	b := im.Bounds()
	out := image.NewNRGBA(b)
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			sx, sy := x-dx, y-dy
			if sx >= 0 && sy >= 0 && sx < b.Dx() && sy < b.Dy() {
				out.SetNRGBA(x, y, im.NRGBAAt(sx, sy))
			}
		}
	}
	return out
}

type packed struct {
	atlas *image.NRGBA
	ids   []string
	cols  int
}

func frames(s Spec, src *image.NRGBA, hint string) []*image.NRGBA {
	cw, ch := s.Atlas.Cell[0], s.Atlas.Cell[1]
	f := finish(src, hint)
	var out []*image.NRGBA
	for _, d := range s.Atlas.Banks {
		out = append(out, rotate(f, d, cw, ch))
	}
	return append(out, torn(f, cw, ch))
}

func pack(s Spec) packed {
	cw, ch := s.Atlas.Cell[0], s.Atlas.Cell[1]
	cols := len(s.Atlas.Banks) + 1
	p := packed{atlas: image.NewNRGBA(image.Rect(0, 0, cols*cw, len(s.Species)*ch)), cols: cols}
	for _, e := range s.Species {
		im, err := readPNG(filepath.Join(root, "art/sprites/sources/wind-kites", e.ID+".png"))
		must(err)
		for i, f := range frames(s, toNRGBA(im), e.Hint) {
			over(p.atlas, f, i*cw, e.Row*ch, 1)
		}
		p.ids = append(p.ids, e.ID)
	}
	return p
}

func cmdOffline() {
	s := loadSpec()
	p := pack(s)
	writePNG(filepath.Join(root, s.Atlas.File), p.atlas)
	writeDart(s, p)
	contact(s, p)
	fmt.Println("atlas", s.Atlas.File, p.atlas.Bounds().Dx(), p.atlas.Bounds().Dy())
}

func writeDart(s Spec, p packed) {
	var b strings.Builder
	b.WriteString("// GENERATED by tools/wind_kites offline — do not edit by hand.\n")
	b.WriteString("// Source: art/families/wind-kites.json, art/sprites/sources/wind-kites/.\n\n")
	b.WriteString("import 'dart:ui' show Rect;\n\n")
	b.WriteString("/// The Crosswind bonus level's kites (openspec/changes/crosswind design\n")
	b.WriteString("/// §6) in assets/images/wind-kites.png: one row per species, the bank\n")
	b.WriteString("/// frames left to right, then the torn (pop) frame. Presentation only.\n")
	b.WriteString("abstract final class WindKitesAtlas {\n")
	fmt.Fprintf(&b, "  static const file = '%s';\n", filepath.Base(s.Atlas.File))
	fmt.Fprintf(&b, "  static const width = %d, height = %d;\n", p.atlas.Bounds().Dx(), p.atlas.Bounds().Dy())
	fmt.Fprintf(&b, "  static const cellW = %d, cellH = %d;\n\n", s.Atlas.Cell[0], s.Atlas.Cell[1])
	b.WriteString("  /// Species in row order.\n  static const species = <String>[\n")
	for _, id := range p.ids {
		fmt.Fprintf(&b, "    '%s',\n", id)
	}
	b.WriteString("  ];\n\n  /// The bank of each frame column (degrees, + leans right).\n  static const banks = <double>[")
	for i, d := range s.Atlas.Banks {
		if i > 0 {
			b.WriteString(", ")
		}
		fmt.Fprintf(&b, "%g", d)
	}
	b.WriteString("];\n\n")
	fmt.Fprintf(&b, "  /// Column of the torn frame.\n  static const tornFrame = %d;\n\n", len(s.Atlas.Banks))
	b.WriteString("  /// The cell of [species] (row), frame [frame] (column).\n")
	b.WriteString("  static Rect cell(int species, int frame) => Rect.fromLTWH(\n")
	b.WriteString("    (frame * cellW).toDouble(),\n    (species * cellH).toDouble(),\n")
	b.WriteString("    cellW.toDouble(),\n    cellH.toDouble(),\n  );\n\n")
	b.WriteString("  /// The bank column nearest [degrees].\n  static int bankFrame(double degrees) {\n")
	b.WriteString("    var best = 0;\n    for (var i = 1; i < banks.length; i++) {\n")
	b.WriteString("      if ((banks[i] - degrees).abs() < (banks[best] - degrees).abs()) best = i;\n")
	b.WriteString("    }\n    return best;\n  }\n}\n")
	out := filepath.Join(root, "lib/game/bonus/levels/wind_kites_atlas.dart")
	must(os.WriteFile(out, []byte(b.String()), 0o644))
	dartFormat(out)
}

// sky paints the contact sheet's backdrop: a night gradient with a band of
// bright cloud across the middle (the kite must read on both).
func sky(im *image.NRGBA) {
	b := im.Bounds()
	for y := 0; y < b.Dy(); y++ {
		t := float64(y) / float64(b.Dy())
		c := color.NRGBA{uint8(10 + 30*t), uint8(14 + 26*t), uint8(34 + 40*t), 255}
		if math.Abs(t-.5) < .16 {
			c = color.NRGBA{0x9A, 0xA4, 0xC4, 255}
		}
		fill(im, image.Rect(0, y, b.Dx(), y+1), c)
	}
}

func contact(s Spec, p packed) {
	const k = 5
	w, h := p.atlas.Bounds().Dx()*k+16, p.atlas.Bounds().Dy()*k+16
	im := image.NewNRGBA(image.Rect(0, 0, w, h))
	sky(im)
	over(im, p.atlas, 8, 8, k)
	writePNG(filepath.Join(root, "art/contact/wind-kites.png"), im)
}

// cmdReview lays out every candidate: the raw crop over a checker (160 px)
// and its finished frames at x5.
func cmdReview(out string) {
	s := loadSpec()
	cw, ch := s.Atlas.Cell[0], s.Atlas.Cell[1]
	cols := len(s.Atlas.Banks) + 1
	rowW := 170 + cols*cw*5 + 10
	rows := len(s.Species) * s.Sprite.Candidates
	im := image.NewNRGBA(image.Rect(0, 0, rowW, rows*(ch*5+12)))
	sky(im)
	r := 0
	for _, e := range s.Species {
		for c := 0; c < s.Sprite.Candidates; c++ {
			y := r * (ch*5 + 12)
			raw, err := loadRaw(e.ID, e.Seed+c)
			if err != nil {
				continue
			}
			cr := bodyCrop(raw)
			for yy := 0; yy < 150; yy++ {
				for xx := 0; xx < 160; xx++ {
					v := uint8(60)
					if (xx/10+yy/10)%2 == 0 {
						v = 90
					}
					im.SetNRGBA(4+xx, y+4+yy, color.NRGBA{v, v, v, 255})
				}
			}
			over(im, downscale(cr, 150), 9, y+4, 1)
			for i, f := range frames(s, downscale(cr, s.Sprite.SourcePx), e.Hint) {
				over(im, f, 170+i*cw*5, y+4, 5)
			}
			r++
		}
	}
	writePNG(out, im)
	fmt.Println("review", out)
}
