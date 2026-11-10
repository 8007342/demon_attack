// Command widescreen_assets is the reproducible pipeline for the wide-screen
// backdrops: the scenery beside the centred game column on desktop
// (lib/widgets/widescreen_backdrop.dart).
//
// It is driven by art/families/widescreen-backdrops.json (prompts, seeds,
// strengths, luminance caps) and art/workflows/widescreen/img2img-wide.json.
// Standard library only.
//
//	layouts  compose each scene's img2img input (1536 x 640; the wall 1024 x 1024)
//	         from seeded primitives, or from the sector painting for gameplay
//	jobs     write the generation queue (one ComfyUI run per scene)
//	run      execute the queue against a ComfyUI HTTP endpoint (optional;
//	         agents normally run each job with studio.run_workflow, then ingest)
//	ingest   copy raw outputs ({scene id: path} JSON) into the raw cache
//	process  pixel finish: box-sample onto the 384 x 160 logical grid, cap the
//	         luminance, quantise to the scene palette, write indexed PNGs to
//	         assets/images/widescreen/
//	contact  contact sheet of the finished scenes (art/contact/widescreen-contact.png)
//	all      layouts, jobs, process, contact (no GPU)
//
// Run from anywhere inside the checkout:
//
//	cd tools/widescreen_assets && go run . all
//
// Every random choice is seeded from the spec, so identical raw inputs give
// identical bytes.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"math"
	"math/rand/v2"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"
)

// ---------------------------------------------------------------- spec

type Scene struct {
	ID       string  `json:"id"`
	Use      string  `json:"use"`
	Layout   string  `json:"layout"`
	Prompt   string  `json:"prompt"`
	Seed     uint64  `json:"seed"`
	Strength float64 `json:"strength"`
	Cap      float64 `json:"cap"`
	Colors   int     `json:"colors"`
	Painting string  `json:"painting"`
	Palette  string  `json:"palette"`
	CropTop  float64 `json:"crop_top"`
	Size     []int   `json:"size"`
	NegExtra string  `json:"negative_extra"`
}

type Spec struct {
	Logical  []int   `json:"logical"`
	Workflow string  `json:"workflow"`
	Negative string  `json:"negative_prompt"`
	Style    string  `json:"style"`
	Scenes   []Scene `json:"scenes"`
	Wall     Scene   `json:"wall"`
}

var root, work, rawDir, assets string

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func findRoot() string {
	dir, err := os.Getwd()
	must(err)
	for {
		if _, err := os.Stat(filepath.Join(dir, "pubspec.yaml")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			must(fmt.Errorf("pubspec.yaml not found above the working directory"))
		}
		dir = parent
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func loadSpec() Spec {
	data, err := os.ReadFile(filepath.Join(root, "art/families/widescreen-backdrops.json"))
	must(err)
	var s Spec
	must(json.Unmarshal(data, &s))
	return s
}

func (s Spec) all() []Scene { return append(append([]Scene{}, s.Scenes...), s.Wall) }

// ---------------------------------------------------------------- canvas

type RGB [3]float64

type Canvas struct {
	W, H int
	Px   []RGB
}

func newCanvas(w, h int, c RGB) *Canvas {
	cv := &Canvas{w, h, make([]RGB, w*h)}
	for i := range cv.Px {
		cv.Px[i] = c
	}
	return cv
}

func (c *Canvas) set(x, y int, col RGB) {
	if x >= 0 && y >= 0 && x < c.W && y < c.H {
		c.Px[y*c.W+x] = col
	}
}

func (c *Canvas) gradient(stops [][2]any) {
	for y := 0; y < c.H; y++ {
		t := float64(y) / float64(c.H-1)
		var col RGB
		for i := 0; i < len(stops)-1; i++ {
			p0, p1 := stops[i][0].(float64), stops[i+1][0].(float64)
			if t >= p0 && t <= p1 {
				a, b := stops[i][1].(RGB), stops[i+1][1].(RGB)
				k := (t - p0) / math.Max(p1-p0, 1e-9)
				for ch := 0; ch < 3; ch++ {
					col[ch] = a[ch] + (b[ch]-a[ch])*k
				}
				break
			}
		}
		for x := 0; x < c.W; x++ {
			c.Px[y*c.W+x] = col
		}
	}
}

func (c *Canvas) glow(cx, cy, rx, ry float64, col RGB, strength float64) {
	for y := 0; y < c.H; y++ {
		for x := 0; x < c.W; x++ {
			dx, dy := (float64(x)-cx)/rx, (float64(y)-cy)/ry
			k := math.Exp(-(dx*dx+dy*dy)*2.2) * strength
			p := &c.Px[y*c.W+x]
			for ch := 0; ch < 3; ch++ {
				p[ch] = p[ch]*(1-k) + col[ch]*k
			}
		}
	}
}

func (c *Canvas) rect(x0, y0, x1, y1 float64, col RGB) {
	for y := int(math.Floor(y0)); y <= int(math.Floor(y1)); y++ {
		for x := int(math.Floor(x0)); x <= int(math.Floor(x1)); x++ {
			c.set(x, y, col)
		}
	}
}

// ellipse fills the ellipse inside the box; clip, when non-nil, limits the
// fill to pixels inside another ellipse box.
func (c *Canvas) ellipse(x0, y0, x1, y1 float64, col RGB, clip []float64) {
	inside := func(x, y float64, b []float64) bool {
		cx, cy, rx, ry := (b[0]+b[2])/2, (b[1]+b[3])/2, (b[2]-b[0])/2, (b[3]-b[1])/2
		dx, dy := (x-cx)/rx, (y-cy)/ry
		return dx*dx+dy*dy <= 1
	}
	box := []float64{x0, y0, x1, y1}
	for y := int(y0); y <= int(y1)+1; y++ {
		for x := int(x0); x <= int(x1)+1; x++ {
			fx, fy := float64(x)+.5, float64(y)+.5
			if inside(fx, fy, box) && (clip == nil || inside(fx, fy, clip)) {
				c.set(x, y, col)
			}
		}
	}
}

func (c *Canvas) ring(cx, cy, rx, ry, width float64, col RGB) {
	for y := int(cy - ry - width); y <= int(cy+ry+width); y++ {
		for x := int(cx - rx - width); x <= int(cx+rx+width); x++ {
			dx, dy := (float64(x)-cx)/rx, (float64(y)-cy)/ry
			d := math.Sqrt(dx*dx+dy*dy) - 1
			if math.Abs(d)*math.Min(rx, ry) < width/2 {
				c.set(x, y, col)
			}
		}
	}
}

func (c *Canvas) polygon(pts [][2]float64, col RGB) {
	minY, maxY := math.Inf(1), math.Inf(-1)
	for _, p := range pts {
		minY, maxY = math.Min(minY, p[1]), math.Max(maxY, p[1])
	}
	for y := int(minY); y <= int(maxY); y++ {
		fy := float64(y) + .5
		var xs []float64
		for i := range pts {
			a, b := pts[i], pts[(i+1)%len(pts)]
			if (a[1] <= fy) != (b[1] <= fy) {
				xs = append(xs, a[0]+(fy-a[1])/(b[1]-a[1])*(b[0]-a[0]))
			}
		}
		sort.Float64s(xs)
		for i := 0; i+1 < len(xs); i += 2 {
			for x := int(math.Ceil(xs[i] - .5)); x <= int(math.Floor(xs[i+1]-.5)); x++ {
				c.set(x, y, col)
			}
		}
	}
}

func (c *Canvas) line(x0, y0, x1, y1, width float64, col RGB) {
	n := int(math.Max(math.Abs(x1-x0), math.Abs(y1-y0))) + 1
	for i := 0; i <= n; i++ {
		t := float64(i) / float64(n)
		x, y := x0+(x1-x0)*t, y0+(y1-y0)*t
		c.rect(x-width/2, y-width/2, x+width/2, y+width/2, col)
	}
}

func (c *Canvas) fillBelow(top []float64, col RGB) {
	for x := 0; x < c.W; x++ {
		for y := int(math.Max(0, math.Ceil(top[x]))); y < c.H; y++ {
			c.Px[y*c.W+x] = col
		}
	}
}

// blur is three box passes (an approximate Gaussian).
func (c *Canvas) blur(r int) {
	tmp := make([]RGB, len(c.Px))
	pass := func(src, dst []RGB, horizontal bool) {
		n, m := c.W, c.H
		if !horizontal {
			n, m = c.H, c.W
		}
		for j := 0; j < m; j++ {
			at := func(i int) int {
				i = max(0, min(n-1, i))
				if horizontal {
					return j*c.W + i
				}
				return i*c.W + j
			}
			var acc RGB
			for i := -r; i <= r; i++ {
				for ch := 0; ch < 3; ch++ {
					acc[ch] += src[at(i)][ch]
				}
			}
			for i := 0; i < n; i++ {
				for ch := 0; ch < 3; ch++ {
					dst[at(i)][ch] = acc[ch] / float64(2*r+1)
					acc[ch] += src[at(i+r+1)][ch] - src[at(i-r)][ch]
				}
			}
		}
	}
	for k := 0; k < 3; k++ {
		pass(c.Px, tmp, true)
		pass(tmp, c.Px, false)
	}
}

// resize area-averages (box filter) for downscaling.
func (c *Canvas) resize(w, h int) *Canvas {
	out := newCanvas(w, h, RGB{})
	sx, sy := float64(c.W)/float64(w), float64(c.H)/float64(h)
	for y := 0; y < h; y++ {
		y0, y1 := int(float64(y)*sy), max(int(float64(y)*sy)+1, int(float64(y+1)*sy))
		for x := 0; x < w; x++ {
			x0, x1 := int(float64(x)*sx), max(int(float64(x)*sx)+1, int(float64(x+1)*sx))
			var acc RGB
			n := 0.0
			for yy := y0; yy < min(y1, c.H); yy++ {
				for xx := x0; xx < min(x1, c.W); xx++ {
					p := c.Px[yy*c.W+xx]
					acc[0], acc[1], acc[2] = acc[0]+p[0], acc[1]+p[1], acc[2]+p[2]
					n++
				}
			}
			out.Px[y*w+x] = RGB{acc[0] / n, acc[1] / n, acc[2] / n}
		}
	}
	return out
}

func (c *Canvas) crop(x0, y0, w, h int) *Canvas {
	out := newCanvas(w, h, RGB{})
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			out.Px[y*w+x] = c.Px[(y+y0)*c.W+x+x0]
		}
	}
	return out
}

func (c *Canvas) flipX() *Canvas {
	out := newCanvas(c.W, c.H, RGB{})
	for y := 0; y < c.H; y++ {
		for x := 0; x < c.W; x++ {
			out.Px[y*c.W+x] = c.Px[y*c.W+c.W-1-x]
		}
	}
	return out
}

func (c *Canvas) paste(src *Canvas, ox, oy int) {
	for y := 0; y < src.H; y++ {
		for x := 0; x < src.W; x++ {
			c.set(x+ox, y+oy, src.Px[y*src.W+x])
		}
	}
}

func readPNG(path string) *Canvas {
	f, err := os.Open(path)
	must(err)
	defer f.Close()
	img, _, err := image.Decode(f)
	must(err)
	b := img.Bounds()
	c := newCanvas(b.Dx(), b.Dy(), RGB{})
	for y := 0; y < c.H; y++ {
		for x := 0; x < c.W; x++ {
			r, g, bl, _ := img.At(b.Min.X+x, b.Min.Y+y).RGBA()
			c.Px[y*c.W+x] = RGB{float64(r >> 8), float64(g >> 8), float64(bl >> 8)}
		}
	}
	return c
}

func writePNG(path string, img image.Image) int {
	must(os.MkdirAll(filepath.Dir(path), 0o755))
	var buf bytes.Buffer
	must((&png.Encoder{CompressionLevel: png.BestCompression}).Encode(&buf, img))
	must(os.WriteFile(path, buf.Bytes(), 0o644))
	return buf.Len()
}

func (c *Canvas) rgba() *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, c.W, c.H))
	for i, p := range c.Px {
		img.Pix[i*4], img.Pix[i*4+1], img.Pix[i*4+2], img.Pix[i*4+3] = clamp8(p[0]), clamp8(p[1]), clamp8(p[2]), 255
	}
	return img
}

func clamp8(v float64) uint8 { return uint8(math.Max(0, math.Min(255, math.Round(v)))) }

func luma(p RGB) float64 { return (0.2126*p[0] + 0.7152*p[1] + 0.0722*p[2]) / 255 }

// ---------------------------------------------------------------- layouts

const LW, LH = 1536, 640

type Rng struct{ *rand.Rand }

func newRng(seed uint64) Rng { return Rng{rand.New(rand.NewPCG(seed, 0x5eed))} }

func (r Rng) between(a, b float64) float64 { return a + r.Float64()*(b-a) }

func (c *Canvas) stars(r Rng, n int, y1 float64, pal ...RGB) {
	if len(pal) == 0 {
		pal = []RGB{{200, 210, 240}, {112, 245, 213}, {244, 202, 121}}
	}
	for i := 0; i < n; i++ {
		x, y := float64(r.IntN(c.W)), r.between(0, y1)
		s := 3.0
		if r.Float64() > .85 {
			s = 7
		}
		col := pal[0]
		if r.Float64() > .8 && len(pal) > 1 {
			col = pal[1+r.IntN(len(pal)-1)]
		}
		c.rect(x, y, x+s, y+s, col)
	}
}

func ridge(r Rng, w int, base, amp float64, rough, smooth int) []float64 {
	n := make([]float64, w/smooth+4)
	for i := range n {
		n[i] = r.NormFloat64()
	}
	jag := make([]float64, w/rough+2)
	for i := range jag {
		jag[i] = r.NormFloat64() * .25
	}
	out := make([]float64, w)
	for x := 0; x < w; x++ {
		t := float64(x) / float64(w-1) * float64(len(n)-3)
		i := int(t)
		f := t - float64(i)
		out[x] = base - amp*(n[i]*(1-f)+n[i+1]*f+jag[x/rough])
	}
	return out
}

func (c *Canvas) capitalShip(x, y, l float64, hull, light RGB) {
	c.polygon([][2]float64{{x, y}, {x + l, y + l*.06}, {x + l*.15, y + l*.16}, {x - l*.05, y + l*.1}}, hull)
	c.polygon([][2]float64{{x + l*.2, y + l*.02}, {x + l*.32, y - l*.07}, {x + l*.4, y + l*.03}}, hull)
	c.rect(x-12, y+l*.03, x-4, y+l*.09, light)
	for k := 0.0; k < 3; k++ {
		lx := x + l*(.35+.18*k)
		c.rect(lx, y+l*.07, lx+4, y+l*.07+4, light)
	}
}

func (c *Canvas) fighter(x, y, s float64, hull, light RGB) {
	c.polygon([][2]float64{{x, y - s}, {x + s*.8, y + s*.7}, {x, y + s*.35}, {x - s*.8, y + s*.7}}, hull)
	c.rect(x-2, y+s*.4, x+2, y+s*.4+4, light)
}

func (c *Canvas) gargoyle(x, y, s float64, col RGB, eye *RGB) {
	c.ellipse(x-s*.22, y-s*.25, x+s*.22, y+s*.45, col, nil)
	for _, side := range []float64{-1, 1} {
		c.polygon([][2]float64{{x + side*s*.15, y - s*.2}, {x + side*s*.3, y - s*.55}, {x + side*s*.02, y - s*.25}}, col)
		c.polygon([][2]float64{{x, y - s*.05}, {x + side*s*.7, y - s*.5}, {x + side*s*1.1, y - s*.1},
			{x + side*s*.8, y + s*.05}, {x + side*s*.6, y + s*.2}, {x + side*s*.35, y + s*.1}, {x, y + s*.2}}, col)
	}
	if eye != nil {
		c.rect(x-s*.1, y-s*.05, x-s*.1+3, y-s*.05+3, *eye)
		c.rect(x+s*.06, y-s*.05, x+s*.06+3, y-s*.05+3, *eye)
	}
}

func (c *Canvas) planet(cx, cy, r float64, body, shade RGB, ring *RGB) {
	box := []float64{cx - r, cy - r, cx + r, cy + r}
	c.ellipse(box[0], box[1], box[2], box[3], body, nil)
	c.ellipse(cx-r*.5, cy-r*1.1, cx+r*1.6, cy+r*1.0, shade, box)
	if ring != nil {
		c.ring(cx, cy, r*1.9, r*.38, 6, *ring)
		c.ellipse(box[0], box[1], box[2], cy, body, box) // the ring passes behind the upper half
		c.ellipse(cx-r*.5, cy-r*1.1, cx+r*1.6, cy, shade, box)
	}
}

func layoutVista(s Scene) *Canvas {
	r := newRng(s.Seed)
	c := newCanvas(LW, LH, RGB{})
	c.gradient([][2]any{{0.0, RGB{4, 6, 14}}, {.45, RGB{12, 16, 40}}, {.7, RGB{34, 26, 70}}, {.74, RGB{20, 16, 40}}, {1.0, RGB{6, 8, 16}}})
	c.glow(300, 180, 380, 120, RGB{16, 66, 80}, .8)
	c.glow(1250, 450, 420, 110, RGB{80, 22, 44}, .8)
	c.stars(r, 260, 440)
	ringCol := RGB{150, 132, 210}
	c.planet(960, 150, 74, RGB{92, 76, 160}, RGB{40, 32, 82}, &ringCol)
	c.ellipse(180, 70, 214, 104, RGB{150, 160, 196}, nil)
	c.fillBelow(ridge(r, LW, 470, 26, 7, 40), RGB{22, 18, 44})
	c.fillBelow(ridge(r, LW, 540, 40, 11, 70), RGB{9, 10, 22})
	for i, sh := range [][3]float64{{90, 250, 420}, {260, 330, 300}, {40, 380, 220}, {380, 200, 180}} {
		k := float64(i * 6)
		c.capitalShip(sh[0], sh[1], sh[2], RGB{40 + k, 50 + k, 78 + k}, RGB{112, 245, 213})
	}
	for i := 0; i < 14; i++ {
		c.fighter(r.between(120, 620), r.between(170, 420), r.between(10, 18), RGB{70, 82, 110}, RGB{112, 245, 213})
	}
	eye := RGB{244, 90, 100}
	for i := 0; i < 70; i++ {
		x := r.between(1000, 1520)
		y := 300 + math.Pow(r.Float64(), 1.5)*200
		sz := 10 + r.Float64()*26*(1-(y-300)/260)
		var e *RGB
		if r.Float64() < .4 {
			e = &eye
		}
		c.gargoyle(x, y, sz, RGB{24, 14, 30}, e)
	}
	return c
}

func layoutHall(s Scene) *Canvas {
	r := newRng(s.Seed)
	c := newCanvas(LW, LH, RGB{})
	c.gradient([][2]any{{0.0, RGB{6, 9, 20}}, {.78, RGB{16, 22, 44}}, {.8, RGB{10, 14, 28}}, {1.0, RGB{14, 18, 34}}})
	cx := float64(LW) / 2
	c.rect(cx-150, 40, cx+150, 300, RGB{5, 8, 20})
	c.ellipse(cx-150, -110, cx+150, 190, RGB{5, 8, 20}, nil)
	sky := newCanvas(300, 400, RGB{5, 8, 20})
	sky.stars(r, 30, 300)
	for y := 0; y < 300; y++ {
		for x := 0; x < 300; x++ {
			if p := sky.Px[y*300+x]; p != (RGB{5, 8, 20}) && (c.Px[(y)*LW+int(cx)-150+x] == RGB{5, 8, 20}) {
				c.Px[y*LW+int(cx)-150+x] = p
			}
		}
	}
	for x := 96; x < LW; x += 192 {
		fx := float64(x)
		c.rect(fx-44, 0, fx+44, 512, RGB{22, 30, 56})
		c.rect(fx-44, 0, fx-38, 512, RGB{40, 54, 92})
	}
	ribbons := []RGB{{112, 60, 160}, {40, 120, 150}, {150, 40, 60}}
	for x := 192; x < LW; x += 192 {
		if math.Abs(float64(x)-cx) < 180 {
			continue
		}
		fx := float64(x)
		for row, y := range []float64{120, 230, 340} {
			c.rect(fx-52, y-44, fx+52, y+50, RGB{10, 14, 30})
			c.rect(fx-52, y+44, fx+52, y+50, RGB{70, 200, 180})
			for k, dx := range []float64{-26, 26} {
				c.rect(fx+dx-7, y-30, fx+dx+7, y-8, ribbons[(row+k+x/192)%3])
				c.ellipse(fx+dx-14, y-10, fx+dx+14, y+18, RGB{200, 144, 42}, nil)
				c.ellipse(fx+dx-6, y-2, fx+dx+6, y+10, RGB{244, 202, 121}, nil)
			}
		}
	}
	for x := 96; x < LW; x += 192 {
		c.glow(float64(x), 560, 50, 80, RGB{40, 46, 70}, .6)
	}
	c.glow(cx, 520, 300, 60, RGB{60, 52, 30}, .5)
	return c
}

func layoutDefeat(s Scene) *Canvas {
	r := newRng(s.Seed)
	c := newCanvas(LW, LH, RGB{})
	c.gradient([][2]any{{0.0, RGB{10, 3, 8}}, {.5, RGB{40, 8, 18}}, {.72, RGB{96, 20, 28}}, {.76, RGB{30, 8, 14}}, {1.0, RGB{8, 3, 6}}})
	c.stars(r, 60, 300, RGB{150, 110, 120}, RGB{200, 80, 80})
	c.ellipse(1080, 60, 1240, 220, RGB{150, 30, 34}, nil)
	c.ellipse(1110, 70, 1260, 220, RGB{96, 18, 26}, []float64{1080, 60, 1240, 220})
	sky := ridge(r, LW, 480, 22, 5, 24)
	for i := 0; i < 26; i++ {
		x, w, h := r.IntN(LW), 10+r.IntN(26), r.between(40, 170)
		for k := x; k < min(LW, x+w); k++ {
			sky[k] = math.Min(sky[k], 470-h+r.between(-8, 8))
		}
	}
	c.fillBelow(sky, RGB{14, 4, 8})
	for i := 0; i < 40; i++ {
		x, y := float64(r.IntN(LW)), r.between(300, 600)
		c.rect(x, y, x+3, y+3, RGB{240, 120, 60})
	}
	eye := RGB{255, 90, 70}
	for i := 0; i < 46; i++ {
		x, y, sz := r.Float64()*LW, r.between(120, 420), r.between(14, 54)
		if x > 1030 && x < 1300 && y < 270 {
			continue // keep the moon's disc clean: a silhouette on it reads as an emblem
		}
		c.gargoyle(x, y, sz, RGB{20, 4, 10}, &eye)
	}
	return c
}

func layoutVictory(s Scene) *Canvas {
	r := newRng(s.Seed)
	c := newCanvas(LW, LH, RGB{})
	c.gradient([][2]any{{0.0, RGB{6, 8, 20}}, {.45, RGB{18, 22, 52}}, {.66, RGB{110, 76, 40}}, {.7, RGB{200, 144, 42}}, {.72, RGB{40, 30, 30}}, {1.0, RGB{8, 10, 18}}})
	cx := float64(LW) / 2
	c.glow(cx, 450, 380, 110, RGB{244, 202, 121}, .7)
	c.stars(r, 160, 380)
	c.ellipse(cx-70, 400, cx+70, 540, RGB{250, 220, 150}, nil)
	c.fillBelow(ridge(r, LW, 460, 18, 7, 60), RGB{16, 14, 26})
	fire := []RGB{{244, 202, 121}, {112, 245, 213}, {189, 167, 255}}
	for i := 0; i < 9; i++ {
		fx, fy := r.between(100, LW-100), r.between(60, 280)
		col := fire[r.IntN(3)]
		for k := 0; k < 14; k++ {
			a := float64(k) / 14 * 2 * math.Pi
			for _, rad := range []float64{18, 32, 44} {
				x, y := fx+math.Cos(a)*rad, fy+math.Sin(a)*rad
				c.rect(x, y, x+4, y+4, col)
			}
		}
	}
	for _, side := range []float64{-1, 1} {
		for row := 0; row < 5; row++ {
			for k := -row; k <= row; k += 2 {
				x := cx + side*(360+float64(row)*70) + float64(k)*26
				y := 240 + float64(row)*46
				c.line(x, y+14, x-side*40, y+70, 3, RGB{150, 110, 60})
				c.fighter(x, y, 16, RGB{60, 66, 96}, RGB{244, 202, 121})
			}
		}
	}
	return c
}

func layoutSector(s Scene) *Canvas {
	p := readPNG(filepath.Join(root, s.Painting))
	top := int(float64(p.H) * s.CropTop)
	crop := p.crop(0, top, p.W, p.H-top)
	w := int(math.Round(float64(crop.W) * LH / float64(crop.H)))
	crop = crop.resize(w, LH)
	strip := newCanvas(3*w, LH, RGB{})
	flip := crop.flipX()
	strip.paste(flip, 0, 0)
	strip.paste(crop, w, 0)
	strip.paste(flip, 2*w, 0)
	return strip.crop((strip.W-LW)/2, 0, LW, LH)
}

func layoutWall(s Scene) *Canvas {
	r := newRng(s.Seed)
	const n, step = 1024, 256
	c := newCanvas(n, n, RGB{14, 20, 36})
	lights := []RGB{{112, 245, 213}, {244, 202, 121}, {40, 70, 90}}
	for gy := 0.0; gy < n; gy += step {
		for gx := 0.0; gx < n; gx += step {
			c.rect(gx+8, gy+8, gx+step-8, gy+step-8, RGB{34, 46, 74})
			c.rect(gx+14, gy+14, gx+step-14, gy+step-14, RGB{20, 28, 48})
			for _, p := range [][2]float64{{24, 24}, {step - 32, 24}, {24, step - 32}, {step - 32, step - 32}} {
				c.rect(gx+p[0], gy+p[1], gx+p[0]+8, gy+p[1]+8, RGB{52, 66, 98})
			}
			if r.Float64() < .5 {
				for k := 0.0; k < 5; k++ {
					c.rect(gx+60, gy+70+k*24, gx+step-60, gy+78+k*24, RGB{8, 12, 24})
				}
			} else {
				c.rect(gx+60, gy+100, gx+step-60, gy+150, RGB{10, 16, 30})
				for k := 0.0; k < 4; k++ {
					c.rect(gx+80+k*26, gy+120, gx+88+k*26, gy+128, lights[r.IntN(3)])
				}
			}
		}
	}
	for _, x := range []float64{step - 20, 3*step - 20} {
		c.rect(x, 0, x+14, n, RGB{26, 34, 58})
	}
	return c
}

var layouts = map[string]func(Scene) *Canvas{
	"vista": layoutVista, "hall": layoutHall, "defeat": layoutDefeat,
	"victory": layoutVictory, "sector": layoutSector, "wall": layoutWall,
}

func cmdLayouts(s Spec) {
	for _, sc := range s.all() {
		c := layouts[sc.Layout](sc)
		if sc.Layout != "sector" {
			c.blur(2)
		}
		path := filepath.Join(work, "layouts", sc.ID+".png")
		writePNG(path, c.rgba())
		fmt.Println("layout", sc.ID, c.W, "x", c.H, "->", path)
	}
}

// ---------------------------------------------------------------- jobs / run / ingest

type Job struct {
	ID        string         `json:"id"`
	Workflow  string         `json:"workflow"`
	InitImage string         `json:"init_image"`
	Strength  float64        `json:"strength"`
	Overrides map[string]any `json:"overrides"`
}

func jobs(s Spec) []Job {
	var out []Job
	for _, sc := range s.all() {
		negative := s.Negative
		if sc.NegExtra != "" {
			negative += ", " + sc.NegExtra
		}
		out = append(out, Job{
			ID: sc.ID, Workflow: s.Workflow, Strength: sc.Strength,
			InitImage: filepath.Join(work, "layouts", sc.ID+".png"),
			Overrides: map[string]any{
				"prompt":          s.Style + ", " + sc.Prompt,
				"negative_prompt": negative,
				"seed":            sc.Seed,
				"$node:6.denoise": sc.Strength,
			},
		})
	}
	return out
}

func cmdJobs(s Spec) {
	data, _ := json.MarshalIndent(jobs(s), "", " ")
	path := filepath.Join(work, "jobs.json")
	must(os.MkdirAll(work, 0o755))
	must(os.WriteFile(path, data, 0o644))
	fmt.Println("jobs", len(jobs(s)), "->", path)
}

func httpJSON(method, u string, body any) map[string]any {
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, u, rd)
	must(err)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	must(err)
	defer resp.Body.Close()
	var out map[string]any
	must(json.NewDecoder(resp.Body).Decode(&out))
	return out
}

func upload(base, path string) string {
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	fw, err := mw.CreateFormFile("image", filepath.Base(path))
	must(err)
	data, err := os.ReadFile(path)
	must(err)
	fw.Write(data)
	mw.WriteField("overwrite", "true")
	mw.Close()
	resp, err := http.Post(base+"/upload/image", mw.FormDataContentType(), &buf)
	must(err)
	defer resp.Body.Close()
	var out map[string]any
	must(json.NewDecoder(resp.Body).Decode(&out))
	return out["name"].(string)
}

func cmdRun(s Spec, base string, only map[string]bool) {
	results := map[string]string{}
	for _, j := range jobs(s) {
		if len(only) > 0 && !only[j.ID] {
			continue
		}
		var wf map[string]map[string]any
		data, err := os.ReadFile(filepath.Join(root, j.Workflow))
		must(err)
		must(json.Unmarshal(data, &wf))
		name := upload(base, j.InitImage)
		for _, node := range wf {
			ins := node["inputs"].(map[string]any)
			title, _ := node["_meta"].(map[string]any)["title"].(string)
			switch title {
			case "$prompt":
				ins["text"] = j.Overrides["prompt"]
			case "$negative_prompt":
				ins["text"] = j.Overrides["negative_prompt"]
			case "$seed":
				ins["seed"] = j.Overrides["seed"]
				ins["denoise"] = j.Strength
			}
			if node["class_type"] == "LoadImage" {
				ins["image"] = name
			}
		}
		pid := httpJSON("POST", base+"/prompt", map[string]any{"prompt": wf})["prompt_id"].(string)
		var hist map[string]any
		for {
			hist = httpJSON("GET", base+"/history/"+pid, nil)
			if _, ok := hist[pid]; ok {
				break
			}
			time.Sleep(2 * time.Second)
		}
		for _, no := range hist[pid].(map[string]any)["outputs"].(map[string]any) {
			for _, im := range no.(map[string]any)["images"].([]any) {
				m := im.(map[string]any)
				q := url.Values{"filename": {m["filename"].(string)}, "subfolder": {m["subfolder"].(string)}, "type": {m["type"].(string)}}
				resp, err := http.Get(base + "/view?" + q.Encode())
				must(err)
				dest := filepath.Join(work, "http", j.ID+".png")
				must(os.MkdirAll(filepath.Dir(dest), 0o755))
				b, _ := io.ReadAll(resp.Body)
				resp.Body.Close()
				must(os.WriteFile(dest, b, 0o644))
				results[j.ID] = dest
			}
		}
		fmt.Println("run", j.ID, results[j.ID])
	}
	ingest(results)
}

func ingest(results map[string]string) {
	must(os.MkdirAll(rawDir, 0o755))
	ids := make([]string, 0, len(results))
	for id := range results {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	// Provenance of every ingested raw output: seed, strength, prompt, hash.
	runsPath := filepath.Join(root, "art/families/widescreen-runs.json")
	runs := map[string]map[string]any{}
	if data, err := os.ReadFile(runsPath); err == nil {
		must(json.Unmarshal(data, &runs))
	}
	byID := map[string]Job{}
	for _, j := range jobs(loadSpec()) {
		byID[j.ID] = j
	}
	for _, id := range ids {
		data, err := os.ReadFile(results[id])
		must(err)
		must(os.WriteFile(filepath.Join(rawDir, id+".png"), data, 0o644))
		j := byID[id]
		runs[id] = map[string]any{
			"workflow": j.Workflow, "seed": j.Overrides["seed"], "strength": j.Strength,
			"prompt": j.Overrides["prompt"], "negative_prompt": j.Overrides["negative_prompt"],
			"models":     []string{"sd_xl_base_1.0.safetensors", "pixel-art-xl.safetensors"},
			"raw_sha256": fmt.Sprintf("%x", sha256.Sum256(data)),
		}
		fmt.Println("ingest", id, "<-", results[id])
	}
	out, _ := json.MarshalIndent(runs, "", " ")
	must(os.WriteFile(runsPath, append(out, '\n'), 0o644))
}

// ---------------------------------------------------------------- pixel finish

func medianCut(px []RGB, n int) []RGB {
	boxes := [][]RGB{append([]RGB{}, px...)}
	for len(boxes) < n {
		best, bestRange, bestCh := -1, -1.0, 0
		for i, b := range boxes {
			if len(b) < 2 {
				continue
			}
			for ch := 0; ch < 3; ch++ {
				lo, hi := 255.0, 0.0
				for _, p := range b {
					lo, hi = math.Min(lo, p[ch]), math.Max(hi, p[ch])
				}
				if hi-lo > bestRange {
					best, bestRange, bestCh = i, hi-lo, ch
				}
			}
		}
		if best < 0 || bestRange <= 0 {
			break
		}
		b := boxes[best]
		sort.Slice(b, func(i, j int) bool { return b[i][bestCh] < b[j][bestCh] })
		boxes[best] = b[:len(b)/2]
		boxes = append(boxes, b[len(b)/2:])
	}
	var out []RGB
	for _, b := range boxes {
		var acc RGB
		for _, p := range b {
			acc[0], acc[1], acc[2] = acc[0]+p[0], acc[1]+p[1], acc[2]+p[2]
		}
		k := float64(len(b))
		out = append(out, RGB{math.Round(acc[0] / k), math.Round(acc[1] / k), math.Round(acc[2] / k)})
	}
	return out
}

func hexPalette(path string) []RGB {
	data, err := os.ReadFile(path)
	must(err)
	var p struct{ Colors []string }
	must(json.Unmarshal(data, &p))
	var out []RGB
	for _, h := range p.Colors {
		v, err := strconv.ParseUint(h[1:], 16, 32)
		must(err)
		out = append(out, RGB{float64(v >> 16 & 255), float64(v >> 8 & 255), float64(v & 255)})
	}
	return out
}

func finish(s Spec, sc Scene, raw *Canvas) *image.Paletted {
	lw, lh := s.Logical[0], s.Logical[1]
	if len(sc.Size) == 2 {
		lw, lh = sc.Size[0], sc.Size[1]
	}
	small := raw.resize(lw, lh)
	lums := make([]float64, len(small.Px))
	for i, p := range small.Px {
		lums[i] = luma(p)
	}
	sort.Float64s(lums)
	hi := lums[int(float64(len(lums)-1)*.995)]
	scale := math.Min(1.6, sc.Cap/math.Max(hi, 1e-3))
	for i := range small.Px {
		for ch := 0; ch < 3; ch++ {
			small.Px[i][ch] = math.Min(255, small.Px[i][ch]*scale)
		}
	}
	var pal []RGB
	if sc.Palette != "" {
		pal = hexPalette(filepath.Join(root, sc.Palette))
	} else {
		pal = append(medianCut(small.Px, sc.Colors), RGB{8, 13, 24})
	}
	var allowed []RGB
	seen := map[RGB]bool{}
	for _, p := range pal {
		if luma(p) <= sc.Cap+.03 && !seen[p] {
			seen[p] = true
			allowed = append(allowed, p)
		}
	}
	sort.Slice(allowed, func(i, j int) bool { return luma(allowed[i]) < luma(allowed[j]) })
	cp := make(color.Palette, len(allowed))
	for i, p := range allowed {
		cp[i] = color.RGBA{clamp8(p[0]), clamp8(p[1]), clamp8(p[2]), 255}
	}
	img := image.NewPaletted(image.Rect(0, 0, lw, lh), cp)
	w := [3]float64{.6, .89, .41}
	for i, p := range small.Px {
		best, bestD := 0, math.Inf(1)
		for k, q := range allowed {
			d := 0.0
			for ch := 0; ch < 3; ch++ {
				d += (p[ch] - q[ch]) * (p[ch] - q[ch]) * w[ch]
			}
			if d < bestD {
				best, bestD = k, d
			}
		}
		img.Pix[i] = uint8(best)
	}
	if sc.Layout == "wall" {
		img = tileable(img)
	}
	return img
}

// tileable rolls the tile by half so its seams meet in the middle, then
// covers that cross with a band copied from just beside it.
func tileable(src *image.Paletted) *image.Paletted {
	w, h := src.Rect.Dx(), src.Rect.Dy()
	out := image.NewPaletted(src.Rect, src.Palette)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			out.Pix[y*w+x] = src.Pix[((y+h/2)%h)*w+(x+w/2)%w]
		}
	}
	const b = 3
	for y := h/2 - b; y < h/2+b; y++ {
		copy(out.Pix[y*w:(y+1)*w], out.Pix[(y-2*b)*w:(y-2*b+1)*w])
	}
	for y := 0; y < h; y++ {
		for x := w/2 - b; x < w/2+b; x++ {
			out.Pix[y*w+x] = out.Pix[y*w+x-2*b]
		}
	}
	return out
}

func cmdProcess(s Spec) {
	total := 0
	for _, sc := range s.all() {
		src := filepath.Join(rawDir, sc.ID+".png")
		if _, err := os.Stat(src); err != nil {
			fmt.Println("missing raw", sc.ID, "(run the studio job, then ingest)")
			continue
		}
		img := finish(s, sc, readPNG(src))
		n := writePNG(filepath.Join(assets, sc.ID+".png"), img)
		total += n
		fmt.Printf("finish %-9s %dx%d %2d colours %6d bytes\n", sc.ID, img.Rect.Dx(), img.Rect.Dy(), len(img.Palette), n)
	}
	fmt.Println("total", total, "bytes")
}

func cmdContact(s Spec) {
	var tiles []*Canvas
	for _, sc := range s.all() {
		path := filepath.Join(assets, sc.ID+".png")
		if _, err := os.Stat(path); err != nil {
			continue
		}
		im := readPNG(path)
		if sc.Layout == "wall" {
			t := newCanvas(384, 160, RGB{})
			for y := 0; y < 160; y += im.H {
				for x := 0; x < 384; x += im.W {
					t.paste(im, x, y)
				}
			}
			im = t
		}
		tiles = append(tiles, im)
	}
	if len(tiles) == 0 {
		return
	}
	rows := (len(tiles) + 1) / 2
	sheet := newCanvas(2*388+4, rows*164+4, RGB{8, 13, 24})
	for i, t := range tiles {
		sheet.paste(t, (i%2)*388+4, (i/2)*164+4)
	}
	path := filepath.Join(root, "art/contact/widescreen-contact.png")
	writePNG(path, sheet.rgba())
	fmt.Println("contact", path)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: widescreen_assets layouts|jobs|run [--only a,b] [--url U]|ingest RESULTS.json|process|contact|all")
		os.Exit(2)
	}
	root = findRoot()
	home, _ := os.UserHomeDir()
	work = env("WIDESCREEN_WORK", "/work/tmp/imagegen/widescreen")
	rawDir = env("WIDESCREEN_RAW", filepath.Join(home, ".cache/demon-attack/widescreen-raw"))
	assets = filepath.Join(root, "assets/images/widescreen")
	s := loadSpec()
	switch os.Args[1] {
	case "layouts":
		cmdLayouts(s)
	case "jobs":
		cmdJobs(s)
	case "run":
		base, only := env("COMFY_URL", "http://studio:8188"), map[string]bool{}
		for i := 2; i+1 < len(os.Args); i += 2 {
			switch os.Args[i] {
			case "--url":
				base = os.Args[i+1]
			case "--only":
				for _, id := range bytes.Split([]byte(os.Args[i+1]), []byte(",")) {
					only[string(id)] = true
				}
			}
		}
		cmdRun(s, base, only)
	case "ingest":
		data, err := os.ReadFile(os.Args[2])
		must(err)
		var results map[string]string
		must(json.Unmarshal(data, &results))
		ingest(results)
	case "process":
		cmdProcess(s)
	case "contact":
		cmdContact(s)
	case "all":
		cmdLayouts(s)
		cmdJobs(s)
		cmdProcess(s)
		cmdContact(s)
	default:
		fmt.Fprintln(os.Stderr, "unknown stage", os.Args[1])
		os.Exit(2)
	}
}
