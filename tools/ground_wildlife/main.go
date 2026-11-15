// Command ground_wildlife is the reproducible pipeline for the ground war
// easter-egg wildlife atlas (plan/ground-easter-eggs.md sections 4-5): flock
// flyers that burst from falling trees and leap frames for the flyover
// critters that flee the troops.
//
// Go standard library only. Driven by art/families/ground-wildlife.json.
//
//	go run . ingest    raws in $WILDLIFE_RAW (copied there from the studio's
//	                   /work/tmp/imagegen/studio/<job>/ outputs, one
//	                   <species>/<seed>/ folder each) -> provenance in
//	                   art/families/ground-wildlife-runs.json, then sources
//	go run . sources   selected raw -> art/sprites/sources/ground-wildlife/
//	                   <id>-raw.png (full-resolution alpha crop, the pick of
//	                   record) and <id>.png (box-downscaled to source_px)
//	go run . review OUT  candidate sheet: every raw over a dark checker with
//	                   its finished flap A at x6 beside it
//	go run . offline   committed sources -> assets/images/ground-wildlife.png,
//	                   lib/game/ground_wildlife_atlas.dart and
//	                   art/contact/ground-wildlife.png (no GPU, byte-identical
//	                   on every run)
//
// The GPU jobs themselves run through the studio's MCP tool
// (studio.run_workflow, art/workflows/backgrounds/sprite-transparent.json,
// count = candidates, seed = the species seed); see the runs file.
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
	"sort"
	"strconv"
	"strings"
)

type Species struct {
	ID       string `json:"id"`
	Row      int    `json:"row"`
	Sector   string `json:"sector"`
	Seed     int    `json:"seed"`
	Selected int    `json:"selected"`
	Hint     string `json:"hint"`
	Prompt   string `json:"prompt"`
}

type Squash struct {
	KY   float64 `json:"ky"`
	KX   float64 `json:"kx"`
	Lift int     `json:"lift"`
}

type Spec struct {
	Atlas struct {
		File        string `json:"file"`
		Width       int    `json:"width"`
		FlockCell   [2]int `json:"flock_cell"`
		CritterCell [2]int `json:"critter_cell"`
	} `json:"atlas"`
	StylePrompt    string `json:"style_prompt"`
	NegativePrompt string `json:"negative_prompt"`
	Sprite         struct {
		Workflow   string `json:"workflow"`
		Candidates int    `json:"candidates"`
		SourcePx   int    `json:"source_px"`
	} `json:"sprite"`
	Caps struct {
		BodyLuma   []float64 `json:"body_luma"`
		MaxLuma    float64   `json:"max_luma"`
		Chroma     float64   `json:"chroma"`
		HintWeight float64   `json:"hint_weight"`
	} `json:"caps"`
	Flock struct {
		HeadingDeg float64 `json:"heading_deg"`
		FlapFold   float64 `json:"flap_fold"`
		FlapLift   float64 `json:"flap_lift"`
		BodyFrac   float64 `json:"body_frac"`
	} `json:"flock"`
	Species  []Species `json:"species"`
	Critters struct {
		Source   string   `json:"source"`
		Crouch   Squash   `json:"crouch"`
		Leap     Squash   `json:"leap"`
		WarmLuma float64  `json:"warm_luma"`
		IDs      []string `json:"ids"`
	} `json:"critters"`
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
	fmt.Fprintln(os.Stderr, "ground_wildlife:", err)
	os.Exit(1)
}

func must(err error) {
	if err != nil {
		fail(err)
	}
}

func loadSpec() Spec {
	b, err := os.ReadFile(filepath.Join(root, "art/families/ground-wildlife.json"))
	must(err)
	var s Spec
	must(json.Unmarshal(b, &s))
	return s
}

func rawDir() string {
	if v := os.Getenv("WILDLIFE_RAW"); v != "" {
		return v
	}
	h, _ := os.UserHomeDir()
	return filepath.Join(h, ".cache/demon-attack/ground-wildlife/raw")
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

func prompt(s Spec, e Species) string {
	return fmt.Sprintf("%s, %s, transparent background", s.StylePrompt, e.Prompt)
}

// ---------------------------------------------------------------------------
// Ingest and sources
// ---------------------------------------------------------------------------

func cmdIngest() {
	s := loadSpec()
	runsPath := filepath.Join(root, "art/families/ground-wildlife-runs.json")
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
			job, _ := os.ReadFile(filepath.Join(dir, "job"))
			runs[fmt.Sprintf("%s/%d", e.ID, seed)] = map[string]any{
				"workflow":        s.Sprite.Workflow,
				"tool":            "studio.run_workflow",
				"job":             strings.TrimSpace(string(job)),
				"prompt":          prompt(s, e),
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
		raw, err := loadRaw(e.ID, e.Selected)
		if err != nil {
			fmt.Println("missing raw", e.ID, e.Selected)
			continue
		}
		c := crop(raw)
		dir := filepath.Join(root, "art/sprites/sources/ground-wildlife")
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

var _ = sort.Strings

// dartFormat keeps the generated Dart in `dart format` shape (the analyzer
// and CI check it); best effort when dart is not on PATH.
func dartFormat(p string) {
	if _, err := exec.LookPath("dart"); err != nil {
		return
	}
	_ = exec.Command("dart", "format", p).Run()
}
