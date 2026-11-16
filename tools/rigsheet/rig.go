package main

// rigsheet: the shared finishing and review-sheet tool of the rigkit pipeline
// (R10). Go, standard library only. Everything family-specific comes from the
// rig.json that tools/rigkit/rig.py writes (schema demon-attack.rig/v2) and the
// family JSON it names: render density, texel classes per instance, overlay,
// palettes, materials. No boss constants live here.

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Inst struct {
	ID         string    `json:"id"`
	Module     string    `json:"module"`
	Slot       string    `json:"slot"`
	Set        string    `json:"set"`
	Mirror     int       `json:"mirror"`
	Offset     []float64 `json:"offset"`
	Detach     *int      `json:"detach"`
	TexelClass string    `json:"texel_class"`
	Texel      float64   `json:"texel"`
	Wreck      any       `json:"wreck"`
}

type Overlay struct {
	Rect  []float64 `json:"rect"`  // cx, cy, w, h (arena units)
	Cross []float64 `json:"cross"` // x, y
	Color string    `json:"color"` // sim | body
}

type Point struct {
	Module  string  `json:"module"`
	X       float64 `json:"x"`
	Y       float64 `json:"y"`
	Visible bool    `json:"visible"`
}

type StageRec struct {
	Anchors map[string]json.RawMessage `json:"anchors"`
	Lights  []Point                    `json:"lights"`
	Fires   []Point                    `json:"fires"`
	Fail    []string                   `json:"gate_fail"`
}

type Rig struct {
	Family      string             `json:"family"`
	Hull        string             `json:"hull"`
	Title       string             `json:"title"`
	Tour        int                `json:"tour"`
	Extent      float64            `json:"extent"`
	PPU         float64            `json:"ppu"`
	RenderScale float64            `json:"render_scale"`
	Texel       map[string]float64 `json:"texel"`
	Frame       [4]float64         `json:"frame"`
	Size        [2]int             `json:"size"`
	Origin      [2]float64         `json:"origin_px"`
	Envelope    []float64          `json:"envelope"`
	Overlay     []Overlay          `json:"overlay"`
	IDs         map[string]string  `json:"module_ids"`
	Insts       []Inst             `json:"instances"`
	Views       map[string]struct {
		Pitch  int                 `json:"pitch"`
		Yaw    int                 `json:"yaw"`
		Stages map[string]StageRec `json:"stages"`
	} `json:"views"`
	Stages map[string]struct {
		Shed    []string `json:"shed"`
		Removed []string `json:"removed"`
	} `json:"stages"`
	dir string
}

func readRig(dir, hull string) *Rig {
	b, err := os.ReadFile(filepath.Join(dir, hull, "rig.json"))
	if err != nil {
		fail("%v", err)
	}
	var r Rig
	if err := json.Unmarshal(b, &r); err != nil {
		fail("%v", err)
	}
	r.dir = dir
	return &r
}

func (r *Rig) path(stage, kind, t string) string {
	return filepath.Join(r.dir, r.Hull, stage, kind+"_"+t+".png")
}

// maxTexel: the finest finished density (px per unit); the hero sheets use it.
func (r *Rig) maxTexel() float64 {
	m := 0.0
	for _, v := range r.Texel {
		m = math.Max(m, v)
	}
	return m
}

func (r *Rig) inst(id string) *Inst {
	for i := range r.Insts {
		if r.Insts[i].ID == id {
			return &r.Insts[i]
		}
	}
	return nil
}

// pairStored: false for the left of a mirrored pair at yaw 0 (drawn as the right one, flipped).
func (r *Rig) pairStored(id string, yaw int) bool {
	if yaw == 0 && strings.HasSuffix(id, "L") && r.inst(strings.TrimSuffix(id, "L")+"R") != nil {
		return false
	}
	return true
}

type Family struct {
	Palettes struct {
		OverlayOnly []string            `json:"overlay_only"`
		Ramps       map[string][]string `json:"ramps"`
	} `json:"palettes"`
	Materials map[string]struct {
		Hint string `json:"hint"`
	} `json:"materials"`
	Prompts  map[string]string          `json:"prompts"`
	Selected map[string]json.RawMessage `json:"selected"`
	Hulls    map[string]struct {
		Tour  int               `json:"tour"`
		Title string            `json:"title"`
		Set   string            `json:"set"`
		Sets  map[string]string `json:"sets"`
	} `json:"hulls"`
	Views struct {
		Pitch     []int `json:"pitch"`
		Yaw       []int `json:"yaw"`
		Hero      []int `json:"hero"`
		StoredYaw []int `json:"stored_yaw"`
	} `json:"views"`
}

func readFamily(rel string) *Family {
	b, err := os.ReadFile(filepath.Join(repoRoot(), rel))
	if err != nil {
		fail("%v", err)
	}
	var f Family
	if err := json.Unmarshal(b, &f); err != nil {
		fail("%s: %v", rel, err)
	}
	return &f
}

// palette: every ramp colour except the overlay-only ramps (the shield cyan).
func (f *Family) palette() []color.NRGBA {
	skip := map[string]bool{}
	for _, s := range f.Palettes.OverlayOnly {
		skip[s] = true
	}
	names := make([]string, 0, len(f.Palettes.Ramps))
	for n := range f.Palettes.Ramps {
		names = append(names, n)
	}
	sort.Strings(names)
	var pal []color.NRGBA
	for _, n := range names {
		if skip[n] {
			continue
		}
		for _, h := range f.Palettes.Ramps[n] {
			pal = append(pal, hex(h))
		}
	}
	return pal
}

func repoRoot() string {
	d, _ := os.Getwd()
	for d != "/" {
		if _, err := os.Stat(filepath.Join(d, "pubspec.yaml")); err == nil {
			return d
		}
		d = filepath.Dir(d)
	}
	fail("run inside the repository")
	return ""
}

func tag(p, y int) string { return fmt.Sprintf("p%02d_y%+03d", p, y) }

var (
	simCol  = color.NRGBA{60, 230, 255, 220}
	bodyCol = color.NRGBA{255, 210, 60, 170}
	keyCol  = color.NRGBA{0, 255, 0, 255}
)

// overlay draws the family overlay over an image of this rig's frame drawn at (x, y)
// with k px per arena unit.
func overlay(dst *image.NRGBA, r *Rig, x, y int, k float64) {
	ox := float64(x) - r.Frame[0]*k
	oy := float64(y) - r.Frame[1]*k
	P := func(ax, ay float64) (int, int) { return int(math.Round(ox + ax*k)), int(math.Round(oy + ay*k)) }
	for _, o := range r.Overlay {
		c := simCol
		if o.Color == "body" {
			c = bodyCol
		}
		if len(o.Rect) == 4 {
			x0, y0 := P(o.Rect[0]-o.Rect[2]/2, o.Rect[1]-o.Rect[3]/2)
			x1, y1 := P(o.Rect[0]+o.Rect[2]/2, o.Rect[1]+o.Rect[3]/2)
			rectOutline(dst, x0, y0, x1, y1, c)
		}
		if len(o.Cross) == 2 {
			cx, cy := P(o.Cross[0], o.Cross[1])
			cross(dst, cx, cy, max(2, int(3*k)), c)
		}
	}
}

// clayHint: the clay pass with the hint pass drawn in (hint colour where the
// hint pass is not the neutral grey).
func clayHint(r *Rig, stage, t string) *image.NRGBA {
	clay := load(r.path(stage, "clay", t))
	hp := r.path(stage, "hint", t)
	if _, err := os.Stat(hp); err != nil {
		return clay
	}
	hint := load(hp)
	for i := 0; i < len(clay.Pix); i += 4 {
		if hint.Pix[i+3] < 128 {
			continue
		}
		hr, hg, hb := int(hint.Pix[i]), int(hint.Pix[i+1]), int(hint.Pix[i+2])
		if abs(hr-128) < 6 && abs(hg-128) < 6 && abs(hb-128) < 6 {
			continue
		}
		// keep a little of the clay's shading on bright hints so facets still read
		sh := float64(clay.Pix[i]) / 255
		f := 0.75 + 0.25*sh
		if hr+hg+hb < 30 {
			f = 1
		}
		clay.Pix[i] = uint8(math.Min(255, float64(hr)*f))
		clay.Pix[i+1] = uint8(math.Min(255, float64(hg)*f))
		clay.Pix[i+2] = uint8(math.Min(255, float64(hb)*f))
		clay.Pix[i+3] = 255
	}
	return clay
}

func keyIn(src *image.NRGBA, key color.NRGBA) *image.NRGBA {
	out := newCanvas(src.Bounds().Dx(), src.Bounds().Dy(), key)
	blit(out, src, 0, 0, 1)
	return out
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func alphaBounds(im *image.NRGBA) image.Rectangle {
	r := image.Rectangle{}
	w := im.Bounds().Dx()
	for i := 3; i < len(im.Pix); i += 4 {
		if im.Pix[i] > 0 {
			x, y := (i/4)%w, (i/4)/w
			r = r.Union(image.Rect(x, y, x+1, y+1))
		}
	}
	return r
}
