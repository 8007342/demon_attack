// Package pixelgrid is the texel-grid rasteriser shared by the ground art
// tools (tools/ground_troops, tools/ground_blocks): 2-D primitives on a
// material-code grid, a seeded generator, PNG input and output, and the
// keyframe high-pass shading texture. Go standard library only.
//
// Every function here is deterministic: the same inputs give the same
// codes, so atlases built with it are byte-identical on every run.
package pixelgrid

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"strings"
)

// Canvas is anything that takes material codes on a texel grid. Writes
// outside the canvas are ignored by the implementation.
type Canvas interface {
	Set(x, y int, c int8)
}

// Disc fills an axis-aligned ellipse centred on (cx, cy).
func Disc(g Canvas, cx, cy, rx, ry float64, c int8) {
	for y := int(cy - ry - 1); y <= int(cy+ry+1); y++ {
		for x := int(cx - rx - 1); x <= int(cx+rx+1); x++ {
			dx, dy := (float64(x)+.5-cx)/rx, (float64(y)+.5-cy)/ry
			if dx*dx+dy*dy <= 1 {
				g.Set(x, y, c)
			}
		}
	}
}

// Line draws a stroke of width w (1 = single texels, else a chain of discs).
func Line(g Canvas, x0, y0, x1, y1 float64, c int8, w float64) {
	n := int(math.Max(math.Abs(x1-x0), math.Abs(y1-y0))*3) + 1
	for i := 0; i <= n; i++ {
		t := float64(i) / float64(n)
		x, y := x0+(x1-x0)*t, y0+(y1-y0)*t
		if w <= 1 {
			g.Set(int(math.Floor(x)), int(math.Floor(y)), c)
		} else {
			Disc(g, x, y, w/2, w/2, c)
		}
	}
}

// Tri fills a triangle (texel centres inside or on the edge).
func Tri(g Canvas, ax, ay, bx, by, cx, cy float64, c int8) {
	minY, maxY := math.Min(ay, math.Min(by, cy)), math.Max(ay, math.Max(by, cy))
	minX, maxX := math.Min(ax, math.Min(bx, cx)), math.Max(ax, math.Max(bx, cx))
	for y := int(minY); y <= int(maxY); y++ {
		for x := int(minX); x <= int(maxX); x++ {
			px, py := float64(x)+.5, float64(y)+.5
			d1 := (px-bx)*(ay-by) - (ax-bx)*(py-by)
			d2 := (px-cx)*(by-cy) - (bx-cx)*(py-cy)
			d3 := (px-ax)*(cy-ay) - (cx-ax)*(py-ay)
			neg := d1 < 0 || d2 < 0 || d3 < 0
			pos := d1 > 0 || d2 > 0 || d3 > 0
			if !(neg && pos) {
				g.Set(x, y, c)
			}
		}
	}
}

// Rect fills the inclusive box.
func Rect(g Canvas, x0, y0, x1, y1 int, c int8) {
	for y := y0; y <= y1; y++ {
		for x := x0; x <= x1; x++ {
			g.Set(x, y, c)
		}
	}
}

// Rng is a 64-bit LCG: small, seedable and identical on every platform.
type Rng struct{ s uint64 }

func NewRng(seed int) *Rng { return &Rng{uint64(seed)*6364136223846793005 + 1442695040888963407} }

// F returns the next value in [0, 1).
func (r *Rng) F() float64 {
	r.s = r.s*6364136223846793005 + 1442695040888963407
	return float64(r.s>>11) / float64(1<<53)
}

// Hash01 is a stateless hash of integer coordinates to [0, 1).
func Hash01(seed int, v ...int) float64 {
	h := uint64(seed)*0x9E3779B97F4A7C15 + 0x632BE59BD9B4E019
	for _, x := range v {
		h ^= uint64(int64(x)) + 0x9E3779B97F4A7C15 + (h << 6) + (h >> 2)
		h *= 0xBF58476D1CE4E5B9
		h ^= h >> 31
	}
	return float64(h>>11) / float64(1<<53)
}

// Hex parses #RRGGBB.
func Hex(h string) color.NRGBA {
	var r, g, b uint8
	fmt.Sscanf(strings.TrimPrefix(h, "#"), "%02x%02x%02x", &r, &g, &b)
	return color.NRGBA{r, g, b, 255}
}

// HexString formats an opaque colour as #RRGGBB.
func HexString(c color.NRGBA) string { return fmt.Sprintf("#%02X%02X%02X", c.R, c.G, c.B) }

// Luma is the Rec. 709 luma of an sRGB colour, 0..1.
func Luma(c color.NRGBA) float64 {
	return (.2126*float64(c.R) + .7152*float64(c.G) + .0722*float64(c.B)) / 255
}

// ReadPNG decodes a PNG file.
func ReadPNG(p string) (image.Image, error) {
	f, err := os.Open(p)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return png.Decode(f)
}

// EncodePNG encodes with the best compression (deterministic bytes).
func EncodePNG(im image.Image) ([]byte, error) {
	var buf bytes.Buffer
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	if err := enc.Encode(&buf, im); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// WritePNG encodes im to p, creating the directory.
func WritePNG(p string, im image.Image) error {
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	b, err := EncodePNG(im)
	if err != nil {
		return err
	}
	return os.WriteFile(p, b, 0o644)
}

// KeyframeTexture box-samples src onto a w x h grid, high-passes its luma
// against the 3 x 3 mean and returns +1 / -1 where the residual is beyond
// 1.4 standard deviations, 0 elsewhere: the "keyframe shading" texture the
// ground tools add to a body ramp. tex[y][x].
func KeyframeTexture(src image.Image, w, h int) [][]int8 {
	tex := make([][]int8, h)
	for i := range tex {
		tex[i] = make([]int8, w)
	}
	b := src.Bounds()
	lum := make([]float64, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			sx0 := b.Min.X + x*b.Dx()/w
			sx1 := max(sx0+1, b.Min.X+(x+1)*b.Dx()/w)
			sy0 := b.Min.Y + y*b.Dy()/h
			sy1 := max(sy0+1, b.Min.Y+(y+1)*b.Dy()/h)
			var s, n float64
			for yy := sy0; yy < sy1; yy++ {
				for xx := sx0; xx < sx1; xx++ {
					r, gg, bb, _ := src.At(xx, yy).RGBA()
					s += .2126*float64(r>>8) + .7152*float64(gg>>8) + .0722*float64(bb>>8)
					n++
				}
			}
			lum[y*w+x] = s / n
		}
	}
	hp := make([]float64, w*h)
	var sum, sq float64
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			var s, n float64
			for dy := -1; dy <= 1; dy++ {
				for dx := -1; dx <= 1; dx++ {
					xx, yy := min(w-1, max(0, x+dx)), min(h-1, max(0, y+dy))
					s += lum[yy*w+xx]
					n++
				}
			}
			v := lum[y*w+x] - s/n
			hp[y*w+x] = v
			sum += v
			sq += v * v
		}
	}
	n := float64(w * h)
	sd := math.Sqrt(math.Max(1e-9, sq/n-(sum/n)*(sum/n)))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			v := hp[y*w+x]
			if v > 1.4*sd {
				tex[y][x] = 1
			} else if v < -1.4*sd {
				tex[y][x] = -1
			}
		}
	}
	return tex
}

// Grid is a variable-size material-code grid (0 = empty).
type Grid struct {
	W, H int
	C    []int8
}

func NewGrid(w, h int) *Grid { return &Grid{W: w, H: h, C: make([]int8, w*h)} }

func (g *Grid) At(x, y int) int8 {
	if x < 0 || y < 0 || x >= g.W || y >= g.H {
		return 0
	}
	return g.C[y*g.W+x]
}

func (g *Grid) Set(x, y int, c int8) {
	if x >= 0 && y >= 0 && x < g.W && y < g.H {
		g.C[y*g.W+x] = c
	}
}

func (g *Grid) Clone() *Grid {
	o := &Grid{W: g.W, H: g.H, C: make([]int8, len(g.C))}
	copy(o.C, g.C)
	return o
}

// Outline sets line on every empty texel 4-adjacent to a filled texel
// that is not itself line.
func (g *Grid) Outline(line int8) *Grid {
	out := g.Clone()
	for y := 0; y < g.H; y++ {
		for x := 0; x < g.W; x++ {
			if g.At(x, y) != 0 {
				continue
			}
			for _, d := range [4][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}} {
				if c := g.At(x+d[0], y+d[1]); c > 0 && c != line {
					out.Set(x, y, line)
					break
				}
			}
		}
	}
	return out
}
