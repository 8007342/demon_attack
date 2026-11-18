// Command wind_kites is the reproducible pipeline for the Crosswind bonus
// level's kites (openspec/changes/crosswind design §6 and §Pipelines).
//
// Go standard library only. Driven by art/families/wind-kites.json.
//
//	go run . ingest      raws in $KITES_RAW (copied there from the studio's
//	                     /work/tmp/imagegen/studio/<job>/<n>/ outputs as
//	                     <species>/<seed>/sprite-rgb.png + sprite-alpha.png)
//	                     -> provenance in art/families/wind-kites-runs.json,
//	                     then sources
//	go run . sources     selected raw -> art/sprites/sources/wind-kites/
//	                     <id>-raw.png (the full-resolution alpha crop, the pick
//	                     of record) and <id>.png (box-downscaled to source_px)
//	go run . review OUT  candidate sheet: every raw over a checker, its
//	                     finished frames at x5 beside it
//	go run . offline     committed sources -> assets/images/wind-kites.png,
//	                     lib/game/bonus/levels/wind_kites_atlas.dart and
//	                     art/contact/wind-kites.png (no GPU, byte-identical)
//
// The GPU jobs run through the studio's MCP tool (studio.run_workflow,
// art/workflows/backgrounds/sprite-transparent.json, count = candidates,
// seed = the species seed, prompt = style_prompt + species prompt).
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
)

type Species struct {
	ID       string `json:"id"`
	Row      int    `json:"row"`
	Seed     int    `json:"seed"`
	Selected int    `json:"selected"`
	Hint     string `json:"hint"`
	Job      string `json:"job"`
	Prompt   string `json:"prompt"`
}

type Spec struct {
	Atlas struct {
		File  string    `json:"file"`
		Cell  [2]int    `json:"cell"`
		Banks []float64 `json:"banks_deg"`
	} `json:"atlas"`
	StylePrompt    string `json:"style_prompt"`
	NegativePrompt string `json:"negative_prompt"`
	Sprite         struct {
		Workflow   string `json:"workflow"`
		Candidates int    `json:"candidates"`
		SourcePx   int    `json:"source_px"`
	} `json:"sprite"`
	Species []Species `json:"species"`
}

var root string

func findRoot() string {
	d, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(d, "pubspec.yaml")); err == nil {
			return d
		}
		p := filepath.Dir(d)
		if p == d {
			fail(errors.New("run inside the demon_attack checkout"))
		}
		d = p
	}
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "wind_kites:", err)
	os.Exit(1)
}

func must(err error) {
	if err != nil {
		fail(err)
	}
}

func loadSpec() Spec {
	b, err := os.ReadFile(filepath.Join(root, "art/families/wind-kites.json"))
	must(err)
	var s Spec
	must(json.Unmarshal(b, &s))
	return s
}

func rawDir() string {
	if v := os.Getenv("KITES_RAW"); v != "" {
		return v
	}
	h, _ := os.UserHomeDir()
	return filepath.Join(h, ".cache/tillandsias-project/wind-kites-raw")
}

func readPNG(p string) (image.Image, error) {
	f, err := os.Open(p)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return png.Decode(f)
}

func writePNG(p string, im image.Image) {
	must(os.MkdirAll(filepath.Dir(p), 0o755))
	var buf bytes.Buffer
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	must(enc.Encode(&buf, im))
	must(os.WriteFile(p, buf.Bytes(), 0o644))
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

func cmdIngest() {
	s := loadSpec()
	runsPath := filepath.Join(root, "art/families/wind-kites-runs.json")
	runs := map[string]any{}
	if b, err := os.ReadFile(runsPath); err == nil {
		must(json.Unmarshal(b, &runs))
	}
	n := 0
	for _, e := range s.Species {
		for c := 0; c < s.Sprite.Candidates; c++ {
			seed := e.Seed + c
			dir := filepath.Join(rawDir(), e.ID, strconv.Itoa(seed))
			var outputs []map[string]string
			for _, f := range []string{"sprite-alpha.png", "sprite-rgb.png"} {
				b, err := os.ReadFile(filepath.Join(dir, f))
				if err != nil {
					continue
				}
				h := sha256.Sum256(b)
				outputs = append(outputs, map[string]string{"file": f, "sha256": hex.EncodeToString(h[:])})
			}
			if len(outputs) < 2 {
				continue
			}
			runs[fmt.Sprintf("%s/%d", e.ID, seed)] = map[string]any{
				"workflow":        s.Sprite.Workflow,
				"tool":            "studio.run_workflow",
				"job":             e.Job,
				"prompt":          fmt.Sprintf("%s, %s, transparent background", s.StylePrompt, e.Prompt),
				"negative_prompt": s.NegativePrompt,
				"seed":            seed,
				"selected":        seed == e.Selected,
				"models": []string{"layer_xl_transparent_conv.safetensors", "pixel-art-xl.safetensors",
					"sdxl-full/sd_xl_base_1.0.safetensors", "vae_transparent_decoder.safetensors"},
				"outputs": outputs,
			}
			n++
		}
	}
	b, _ := json.MarshalIndent(runs, "", " ")
	must(os.WriteFile(runsPath, append(b, '\n'), 0o644))
	fmt.Println("ingested", n)
	writeSources(s)
}

// loadRaw merges a candidate's RGB and LayerDiffuse alpha into one image.
func loadRaw(id string, seed int) (*image.NRGBA, error) {
	dir := filepath.Join(rawDir(), id, strconv.Itoa(seed))
	rgb, err := readPNG(filepath.Join(dir, "sprite-rgb.png"))
	if err != nil {
		return nil, err
	}
	al, err := readPNG(filepath.Join(dir, "sprite-alpha.png"))
	if err != nil {
		return nil, err
	}
	b := rgb.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			r, g, bb, _ := rgb.At(b.Min.X+x, b.Min.Y+y).RGBA()
			a, _, _, _ := al.At(b.Min.X+x, b.Min.Y+y).RGBA()
			out.SetNRGBA(x, y, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(bb >> 8), uint8(a >> 8)})
		}
	}
	return out, nil
}

// crop returns the bounding box of alpha >= 140 (the vegetation rule).
func crop(im *image.NRGBA) *image.NRGBA {
	b := im.Bounds()
	x0, y0, x1, y1 := b.Max.X, b.Max.Y, -1, -1
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if im.NRGBAAt(x, y).A >= 140 {
				x0, y0 = min(x0, x), min(y0, y)
				x1, y1 = max(x1, x), max(y1, y)
			}
		}
	}
	if x1 < 0 {
		return im
	}
	out := image.NewNRGBA(image.Rect(0, 0, x1-x0+1, y1-y0+1))
	for y := y0; y <= y1; y++ {
		for x := x0; x <= x1; x++ {
			out.SetNRGBA(x-x0, y-y0, im.NRGBAAt(x, y))
		}
	}
	return out
}

// downscale box-filters [im] so its longer side is [px] (alpha-weighted).
func downscale(im *image.NRGBA, px int) *image.NRGBA {
	w, h := im.Bounds().Dx(), im.Bounds().Dy()
	k := math.Min(1, float64(px)/float64(max(w, h)))
	ow, oh := max(1, int(math.Round(float64(w)*k))), max(1, int(math.Round(float64(h)*k)))
	out := image.NewNRGBA(image.Rect(0, 0, ow, oh))
	for oy := 0; oy < oh; oy++ {
		for ox := 0; ox < ow; ox++ {
			sx0, sx1 := ox*w/ow, (ox+1)*w/ow
			sy0, sy1 := oy*h/oh, (oy+1)*h/oh
			var rs, gs, bs, as, n float64
			for y := sy0; y < max(sy1, sy0+1); y++ {
				for x := sx0; x < max(sx1, sx0+1); x++ {
					c := im.NRGBAAt(x, y)
					a := float64(c.A)
					rs += float64(c.R) * a
					gs += float64(c.G) * a
					bs += float64(c.B) * a
					as += a
					n++
				}
			}
			if as == 0 {
				continue
			}
			out.SetNRGBA(ox, oy, color.NRGBA{uint8(rs / as), uint8(gs / as), uint8(bs / as), uint8(as / n)})
		}
	}
	return out
}

func writeSources(s Spec) {
	for _, e := range s.Species {
		if e.Selected < 0 {
			fmt.Println("no pick yet", e.ID)
			continue
		}
		raw, err := loadRaw(e.ID, e.Selected)
		if err != nil {
			fmt.Println("missing raw", e.ID, e.Selected)
			continue
		}
		c := bodyCrop(raw)
		dir := filepath.Join(root, "art/sprites/sources/wind-kites")
		writePNG(filepath.Join(dir, e.ID+"-raw.png"), c)
		src := downscale(c, s.Sprite.SourcePx)
		writePNG(filepath.Join(dir, e.ID+".png"), src)
		fmt.Println("source", e.ID, e.Selected, src.Bounds().Dx(), src.Bounds().Dy())
	}
}

func main() {
	root = findRoot()
	if len(os.Args) < 2 {
		fmt.Println("usage: go run . ingest|sources|review OUT|offline")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "ingest":
		cmdIngest()
	case "sources":
		writeSources(loadSpec())
	case "review":
		if len(os.Args) < 3 {
			fail(errors.New("review OUT.png"))
		}
		cmdReview(os.Args[2])
	case "offline":
		cmdOffline()
	default:
		fail(fmt.Errorf("unknown stage %q", os.Args[1]))
	}
}

// dartFormat keeps the generated Dart in `dart format` shape; best effort
// when dart is not on PATH.
func dartFormat(p string) {
	if _, err := exec.LookPath("dart"); err != nil {
		return
	}
	_ = exec.Command("dart", "format", p).Run()
}

// bodyCrop is crop without the kite's string: rows and columns whose solid
// run is under 15 % of the widest one (the thin tail line the model draws
// below most kites) are dropped before the bounding box. The painter draws
// its own tail, which streams with the wind.
func bodyCrop(im *image.NRGBA) *image.NRGBA {
	c := crop(im)
	b := c.Bounds()
	rows := make([]int, b.Dy())
	cols := make([]int, b.Dx())
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if c.NRGBAAt(x, y).A >= 140 {
				rows[y]++
				cols[x]++
			}
		}
	}
	span := func(v []int) (int, int) {
		m := 0
		for _, n := range v {
			m = max(m, n)
		}
		lo, hi := -1, -1
		for i, n := range v {
			if float64(n) >= .15*float64(m) {
				if lo < 0 {
					lo = i
				}
				hi = i
			}
		}
		return lo, hi
	}
	y0, y1 := span(rows)
	x0, x1 := span(cols)
	out := image.NewNRGBA(image.Rect(0, 0, x1-x0+1, y1-y0+1))
	for y := y0; y <= y1; y++ {
		for x := x0; x <= x1; x++ {
			out.SetNRGBA(x-x0, y-y0, c.NRGBAAt(x, y))
		}
	}
	return out
}
