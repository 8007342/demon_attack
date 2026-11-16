package main

// Image helpers: load/save, area downscale, nearest blit, outlines and a 3x5
// bitmap font (the one tools/ground_blocks uses) for sheet labels.

import (
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"math"
	"os"
	"strings"
)

func load(p string) *image.NRGBA {
	f, err := os.Open(p)
	if err != nil {
		fail("%v", err)
	}
	defer f.Close()
	im, err := png.Decode(f)
	if err != nil {
		fail("%s: %v", p, err)
	}
	out := image.NewNRGBA(im.Bounds().Sub(im.Bounds().Min))
	draw.Draw(out, out.Bounds(), im, im.Bounds().Min, draw.Src)
	return out
}

func save(p string, im image.Image) {
	f, err := os.Create(p)
	if err != nil {
		fail("%v", err)
	}
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	if err := enc.Encode(f, im); err != nil {
		fail("%v", err)
	}
	f.Close()
}

// load16 returns a 16-bit grey PNG's values in [0, 1] and its alpha.
func load16(p string) ([]float64, []bool, int, int) {
	f, err := os.Open(p)
	if err != nil {
		fail("%v", err)
	}
	defer f.Close()
	im, err := png.Decode(f)
	if err != nil {
		fail("%s: %v", p, err)
	}
	b := im.Bounds()
	w, h := b.Dx(), b.Dy()
	v := make([]float64, w*h)
	a := make([]bool, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			r, _, _, al := im.At(b.Min.X+x, b.Min.Y+y).RGBA()
			if al > 0 {
				v[y*w+x] = float64(r) / float64(al)
				a[y*w+x] = al > 0x8000
			}
		}
	}
	return v, a, w, h
}

func newCanvas(w, h int, bg color.NRGBA) *image.NRGBA {
	im := image.NewNRGBA(image.Rect(0, 0, w, h))
	fill(im, im.Bounds(), bg)
	return im
}

func fill(dst *image.NRGBA, r image.Rectangle, c color.NRGBA) {
	r = r.Intersect(dst.Bounds())
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			dst.SetNRGBA(x, y, c)
		}
	}
}

// over composites c onto dst at (x, y) with alpha.
func over(dst *image.NRGBA, x, y int, c color.NRGBA) {
	if !(image.Point{x, y}.In(dst.Bounds())) || c.A == 0 {
		return
	}
	if c.A == 255 {
		dst.SetNRGBA(x, y, c)
		return
	}
	d := dst.NRGBAAt(x, y)
	a := float64(c.A) / 255
	mix := func(s, t uint8) uint8 { return uint8(math.Round(float64(s)*a + float64(t)*(1-a))) }
	dst.SetNRGBA(x, y, color.NRGBA{mix(c.R, d.R), mix(c.G, d.G), mix(c.B, d.B), max(d.A, c.A)})
}

// blit draws src scaled by k at (x, y): nearest for k >= 1, area average for k < 1.
func blit(dst, src *image.NRGBA, x, y int, k float64) (int, int) {
	if k < 1 {
		src = areaScale(src, k)
		k = 1
	}
	w, h := src.Bounds().Dx(), src.Bounds().Dy()
	ow, oh := int(math.Round(float64(w)*k)), int(math.Round(float64(h)*k))
	for oy := 0; oy < oh; oy++ {
		for ox := 0; ox < ow; ox++ {
			sx, sy := min(int(float64(ox)/k), w-1), min(int(float64(oy)/k), h-1)
			over(dst, x+ox, y+oy, src.NRGBAAt(sx, sy))
		}
	}
	return ow, oh
}

// areaScale downsamples by k < 1 with premultiplied box filtering.
func areaScale(src *image.NRGBA, k float64) *image.NRGBA {
	w, h := src.Bounds().Dx(), src.Bounds().Dy()
	ow, oh := max(1, int(math.Round(float64(w)*k))), max(1, int(math.Round(float64(h)*k)))
	out := image.NewNRGBA(image.Rect(0, 0, ow, oh))
	fx, fy := float64(w)/float64(ow), float64(h)/float64(oh)
	for oy := 0; oy < oh; oy++ {
		for ox := 0; ox < ow; ox++ {
			var r, g, b, a, n float64
			for sy := int(float64(oy) * fy); sy < int(float64(oy+1)*fy) && sy < h; sy++ {
				for sx := int(float64(ox) * fx); sx < int(float64(ox+1)*fx) && sx < w; sx++ {
					c := src.NRGBAAt(sx, sy)
					al := float64(c.A) / 255
					r += float64(c.R) * al
					g += float64(c.G) * al
					b += float64(c.B) * al
					a += al
					n++
				}
			}
			if a > 0 {
				out.SetNRGBA(ox, oy, color.NRGBA{uint8(r / a), uint8(g / a), uint8(b / a), uint8(math.Round(a / n * 255))})
			}
		}
	}
	return out
}

func rectOutline(dst *image.NRGBA, x0, y0, x1, y1 int, c color.NRGBA) {
	for x := x0; x <= x1; x++ {
		over(dst, x, y0, c)
		over(dst, x, y1, c)
	}
	for y := y0; y <= y1; y++ {
		over(dst, x0, y, c)
		over(dst, x1, y, c)
	}
}

func cross(dst *image.NRGBA, x, y, r int, c color.NRGBA) {
	for d := -r; d <= r; d++ {
		over(dst, x+d, y, c)
		over(dst, x, y+d, c)
	}
}

var font3x5 = map[rune]string{
	'A': "010101111101101", 'B': "110101110101110", 'C': "011100100100011", 'D': "110101101101110",
	'E': "111100110100111", 'F': "111100110100100", 'G': "011100101101011", 'H': "101101111101101",
	'I': "111010010010111", 'J': "001001001101010", 'K': "101101110101101", 'L': "100100100100111",
	'M': "101111111101101", 'N': "110101101101101", 'O': "010101101101010", 'P': "110101110100100",
	'Q': "010101101110011", 'R': "110101110101101", 'S': "011100010001110", 'T': "111010010010010",
	'U': "101101101101111", 'V': "101101101101010", 'W': "101101111111101", 'X': "101101010101101",
	'Y': "101101010010010", 'Z': "111001010100111", '0': "111101101101111", '1': "010110010010111",
	'2': "110001010100111", '3': "110001010001110", '4': "101101111001001", '5': "111100110001110",
	'6': "011100111101111", '7': "111001010010010", '8': "111101111101111", '9': "111101111001110",
	'-': "000000111000000", '.': "000000000000010", ':': "000010000010000", '/': "001001010100100",
	' ': "000000000000000", '(': "010100100100010", ')': "010001001001010", '+': "000010111010000",
	'=': "000111000111000", ',': "000000000010100", '%': "101001010100101", 'x': "000101010101000",
}

func text(dst *image.NRGBA, x, y, scale int, s string, col color.NRGBA) {
	for _, ch := range s {
		g, ok := font3x5[ch]
		if !ok {
			g, ok = font3x5[[]rune(strings.ToUpper(string(ch)))[0]]
		}
		if !ok {
			g = font3x5[' ']
		}
		for i := 0; i < 15; i++ {
			if g[i] == '1' {
				for dy := 0; dy < scale; dy++ {
					for dx := 0; dx < scale; dx++ {
						over(dst, x+(i%3)*scale+dx, y+(i/3)*scale+dy, col)
					}
				}
			}
		}
		x += 4 * scale
	}
}

func fail(f string, a ...any) {
	fmt.Fprintf(os.Stderr, "rigsheet: "+f+"\n", a...)
	os.Exit(1)
}

func hex(s string) color.NRGBA {
	var r, g, b uint8
	fmt.Sscanf(strings.TrimPrefix(s, "#"), "%02x%02x%02x", &r, &g, &b)
	return color.NRGBA{r, g, b, 255}
}
