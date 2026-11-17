package main

import (
	"image"
	"image/color"
)

// Sheet colours.
var (
	bg    = color.NRGBA{22, 20, 34, 255}
	label = color.NRGBA{210, 204, 228, 255}
	dim   = color.NRGBA{120, 114, 150, 255}
)

// combat.png geometry (lib/game/sprite_atlas.dart, plan/sprite-atlas.md).
const (
	cellPx      = 64
	speciesRows = 9
	glideCol    = 18 // neutral direction (cols 10-19), glide pose 8: lift 0
	leftGlide   = 8  // left-banked glide
	eliteRowOff = 8
	// One arena unit is 64/40 art px: creatures draw at 40 units.
	artPerUnit = 64.0 / 40.0
)

type canvas struct{ img *image.NRGBA }

func newCanvas(w, h int, fill color.NRGBA) *canvas {
	c := &canvas{image.NewNRGBA(image.Rect(0, 0, w, h))}
	for i := 0; i < len(c.img.Pix); i += 4 {
		c.img.Pix[i], c.img.Pix[i+1], c.img.Pix[i+2], c.img.Pix[i+3] = fill.R, fill.G, fill.B, fill.A
	}
	return c
}

func (c *canvas) w() int { return c.img.Bounds().Dx() }
func (c *canvas) h() int { return c.img.Bounds().Dy() }

// over composites one straight-alpha pixel onto the canvas.
func (c *canvas) over(x, y int, p color.NRGBA) {
	if p.A == 0 || x < 0 || y < 0 || x >= c.w() || y >= c.h() {
		return
	}
	i := c.img.PixOffset(x, y)
	d := c.img.Pix[i : i+4]
	a := float64(p.A) / 255
	da := float64(d[3]) / 255
	oa := a + da*(1-a)
	if oa <= 0 {
		return
	}
	for k, s := range []uint8{p.R, p.G, p.B} {
		d[k] = uint8((float64(s)*a + float64(d[k])*da*(1-a)) / oa)
	}
	d[3] = uint8(oa*255 + .5)
}

// blit draws src at (x, y) scaled by an integer factor (nearest).
func (c *canvas) blit(src *image.NRGBA, x, y, scale int) {
	b := src.Bounds()
	for sy := 0; sy < b.Dy(); sy++ {
		for sx := 0; sx < b.Dx(); sx++ {
			p := src.NRGBAAt(b.Min.X+sx, b.Min.Y+sy)
			for dy := 0; dy < scale; dy++ {
				for dx := 0; dx < scale; dx++ {
					c.over(x+sx*scale+dx, y+sy*scale+dy, p)
				}
			}
		}
	}
}

func (c *canvas) rect(x, y, w, h int, p color.NRGBA) {
	for j := 0; j < h; j++ {
		for i := 0; i < w; i++ {
			c.over(x+i, y+j, p)
		}
	}
}

// downscale is a premultiplied area average to an exact size: what a
// phone's bilinear-free nearest draw of a 64 px cell into ~43 CSS px
// averages to on a DPR-1 screen (the worst case).
func downscale(src *image.NRGBA, w, h int) *image.NRGBA {
	b := src.Bounds()
	dst := image.NewNRGBA(image.Rect(0, 0, w, h))
	fx, fy := float64(b.Dx())/float64(w), float64(b.Dy())/float64(h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			var r, g, bl, a, n float64
			for sy := int(float64(y) * fy); sy < int(float64(y+1)*fy+.999); sy++ {
				for sx := int(float64(x) * fx); sx < int(float64(x+1)*fx+.999); sx++ {
					if sx >= b.Dx() || sy >= b.Dy() {
						continue
					}
					p := src.NRGBAAt(b.Min.X+sx, b.Min.Y+sy)
					pa := float64(p.A) / 255
					r += float64(p.R) * pa
					g += float64(p.G) * pa
					bl += float64(p.B) * pa
					a += pa
					n++
				}
			}
			if a > 0 {
				dst.SetNRGBA(x, y, color.NRGBA{uint8(r / a), uint8(g / a), uint8(bl / a), uint8(a / n * 255)})
			}
		}
	}
	return dst
}

// cell copies one 64 px cell of combat.png: species [kind], row offset
// [row] (0 intact, 1-3 molts, 4 angry, 8 elite overlay), column [col].
func cell(atlas *image.NRGBA, kind, row, col int) *image.NRGBA {
	r := kind*speciesRows + row
	return atlas.SubImage(image.Rect(col*cellPx, r*cellPx, (col+1)*cellPx, (r+1)*cellPx)).(*image.NRGBA)
}

// copyOf returns an independent copy (sub-images share pixels).
func copyOf(src *image.NRGBA) *image.NRGBA {
	b := src.Bounds()
	dst := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			dst.SetNRGBA(x, y, src.NRGBAAt(b.Min.X+x, b.Min.Y+y))
		}
	}
	return dst
}

// --- a 3 x 5 pixel font for sheet labels (upper case, digits, a few marks)

var font = map[rune][5]string{
	'A': {"010", "101", "111", "101", "101"}, 'B': {"110", "101", "110", "101", "110"},
	'C': {"011", "100", "100", "100", "011"}, 'D': {"110", "101", "101", "101", "110"},
	'E': {"111", "100", "110", "100", "111"}, 'F': {"111", "100", "110", "100", "100"},
	'G': {"011", "100", "101", "101", "011"}, 'H': {"101", "101", "111", "101", "101"},
	'I': {"111", "010", "010", "010", "111"}, 'J': {"001", "001", "001", "101", "010"},
	'K': {"101", "101", "110", "101", "101"}, 'L': {"100", "100", "100", "100", "111"},
	'M': {"101", "111", "111", "101", "101"}, 'N': {"110", "101", "101", "101", "101"},
	'O': {"010", "101", "101", "101", "010"}, 'P': {"110", "101", "110", "100", "100"},
	'Q': {"010", "101", "101", "110", "011"}, 'R': {"110", "101", "110", "101", "101"},
	'S': {"011", "100", "010", "001", "110"}, 'T': {"111", "010", "010", "010", "010"},
	'U': {"101", "101", "101", "101", "111"}, 'V': {"101", "101", "101", "101", "010"},
	'W': {"101", "101", "111", "111", "101"}, 'X': {"101", "101", "010", "101", "101"},
	'Y': {"101", "101", "010", "010", "010"}, 'Z': {"111", "001", "010", "100", "111"},
	'0': {"111", "101", "101", "101", "111"}, '1': {"010", "110", "010", "010", "111"},
	'2': {"110", "001", "010", "100", "111"}, '3': {"110", "001", "010", "001", "110"},
	'4': {"101", "101", "111", "001", "001"}, '5': {"111", "100", "110", "001", "110"},
	'6': {"011", "100", "111", "101", "111"}, '7': {"111", "001", "010", "010", "010"},
	'8': {"111", "101", "111", "101", "111"}, '9': {"111", "101", "111", "001", "110"},
	'.': {"000", "000", "000", "000", "010"}, ',': {"000", "000", "000", "010", "100"},
	'-': {"000", "000", "111", "000", "000"}, '/': {"001", "001", "010", "100", "100"},
	':': {"000", "010", "000", "010", "000"}, '+': {"000", "010", "111", "010", "000"},
	'%': {"101", "001", "010", "100", "101"}, '(': {"010", "100", "100", "100", "010"},
	')': {"010", "001", "001", "001", "010"}, '=': {"000", "111", "000", "111", "000"},
	'>': {"100", "010", "001", "010", "100"}, '<': {"001", "010", "100", "010", "001"},
}

// text draws upper-cased [s] at (x, y) with pixel size [px].
func (c *canvas) text(x, y, px int, s string, p color.NRGBA) {
	cx := x
	for _, r := range s {
		if r >= 'a' && r <= 'z' {
			r -= 32
		}
		if r == '\n' {
			cx = x
			y += 7 * px
			continue
		}
		g, ok := font[r]
		if ok {
			for j, row := range g {
				for i, b := range row {
					if b == '1' {
						c.rect(cx+i*px, y+j*px, px, px, p)
					}
				}
			}
		}
		cx += 4 * px
	}
}
