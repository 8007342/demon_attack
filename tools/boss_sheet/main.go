// boss_sheet: review sheets, control images and budget measurements for the
// boss-hero-assets pipeline (openspec/changes/boss-hero-assets). Go, standard
// library only; reads the rig output of tools/boss_rig/build.py.
//
//	go run ./tools/boss_sheet stack OUT.png IMG...              quick side-by-side preview
//	go run ./tools/boss_sheet clayhint RIG HULL STAGE TAG        clay with the hint pass drawn in
//	go run ./tools/boss_sheet keyin IN.png OUT.png #00FF00       flatten a transparent render onto a key colour
//	go run ./tools/boss_sheet turntables RIG OUT.png HULL...     the B0 sheet
//	go run ./tools/boss_sheet budget RIG HULL...                 measured RGBA budget from the id masks
//	go run ./tools/boss_sheet atlasframe HULL OUT.png            today's atlas frame (superstructure + bow) of a hull
//	go run ./tools/boss_sheet lineup BAKE RIG OUT.png HULL...     the B3 tour-progression sheet
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

type Rig struct {
	Hull   string            `json:"hull"`
	Title  string            `json:"title"`
	Extent float64           `json:"extent"`
	PPU    float64           `json:"ppu"`
	Frame  [4]float64        `json:"frame"`
	Size   [2]int            `json:"size"`
	Origin [2]float64        `json:"origin_px"`
	IDs    map[string]string `json:"module_ids"`
	Insts  []struct {
		ID     string `json:"id"`
		Module string `json:"module"`
		Mirror int    `json:"mirror"`
		Detach *int   `json:"detach"`
	} `json:"instances"`
	Views map[string]struct {
		Pitch  int `json:"pitch"`
		Yaw    int `json:"yaw"`
		Stages map[string]struct {
			Anchors map[string]json.RawMessage `json:"anchors"`
			Fail    []string                   `json:"gate_fail"`
		} `json:"stages"`
	} `json:"views"`
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
	return &r
}

func tag(p, y int) string { return fmt.Sprintf("p%02d_y%+03d", p, y) }

var pitches = []int{38, 45, 52}
var yaws = []int{-12, 0, 12}

// atlas constants from lib/game/boss_atlas.dart
type simGeom struct{ coreX, coreY, coreW, coreH, bayX, bayY, bayW, bayH, turX, turY, bodyHW, bodyTop, bodyBot float64 }

func readSim() simGeom {
	src, err := os.ReadFile(filepath.Join(repoRoot(), "lib/game/boss_atlas.dart"))
	if err != nil {
		fail("%v", err)
	}
	get := func(name string) map[string]float64 {
		m := regexp.MustCompile(`static const ` + name + ` = \(([^)]*)\)`).FindSubmatch(src)
		out := map[string]float64{}
		for _, kv := range strings.Split(string(m[1]), ",") {
			p := strings.Split(kv, ":")
			v, _ := strconv.ParseFloat(strings.TrimSpace(p[1]), 64)
			out[strings.TrimSpace(p[0])] = v
		}
		return out
	}
	c, b, t, s := get("coreWindow"), get("bayWindow"), get("turretPivot"), get("solidBody")
	return simGeom{c["x"], c["y"], c["w"], c["h"], b["x"], b["y"], b["w"], b["h"], t["x"], t["y"], s["halfWidth"], s["top"], s["bottom"]}
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

// clayHint: clay with hint features forced (white eyes and lights, black maw and bays).
func clayHint(rig, hull, stage, t string) *image.NRGBA {
	clay := load(filepath.Join(rig, hull, stage, "clay_"+t+".png"))
	hp := filepath.Join(rig, hull, stage, "hint_"+t+".png")
	if _, err := os.Stat(hp); err != nil {
		return clay
	}
	hint := load(hp)
	for i := 0; i < len(clay.Pix); i += 4 {
		if hint.Pix[i+3] < 128 {
			continue
		}
		v := hint.Pix[i]
		if v > 200 {
			clay.Pix[i], clay.Pix[i+1], clay.Pix[i+2], clay.Pix[i+3] = 255, 255, 255, 255
		} else if v < 50 {
			clay.Pix[i], clay.Pix[i+1], clay.Pix[i+2], clay.Pix[i+3] = 0, 0, 0, 255
		}
	}
	return clay
}

func keyIn(src *image.NRGBA, key color.NRGBA) *image.NRGBA {
	out := newCanvas(src.Bounds().Dx(), src.Bounds().Dy(), key)
	blit(out, src, 0, 0, 1)
	return out
}

// simOverlay draws the simulation windows over a view drawn at (x, y) with px per unit k.
func simOverlay(dst *image.NRGBA, r *Rig, sim simGeom, x, y int, k float64) {
	ox := float64(x) + r.Origin[0]*k/r.PPU
	oy := float64(y) + r.Origin[1]*k/r.PPU
	P := func(ax, ay float64) (int, int) { return int(math.Round(ox + ax*k)), int(math.Round(oy + ay*k)) }
	box := func(cx, cy, w, h float64, c color.NRGBA) {
		x0, y0 := P(cx-w/2, cy-h/2)
		x1, y1 := P(cx+w/2, cy+h/2)
		rectOutline(dst, x0, y0, x1, y1, c)
	}
	box(sim.coreX, sim.coreY, sim.coreW, sim.coreH, simCol)
	box(sim.bayX, sim.bayY, sim.bayW, sim.bayH, simCol)
	box(-sim.bayX, sim.bayY, sim.bayW, sim.bayH, simCol)
	for _, s := range []float64{-1, 1} {
		cx, cy := P(s*sim.turX, sim.turY)
		cross(dst, cx, cy, 3, simCol)
	}
	x0, y0 := P(-sim.bodyHW, sim.bodyTop)
	x1, y1 := P(sim.bodyHW, sim.bodyBot)
	rectOutline(dst, x0, y0, x1, y1, bodyCol)
}

func cmdTurntables(args []string) {
	rig, out, hulls := args[0], args[1], args[2:]
	sim := readSim()
	type band struct {
		r *Rig
		w int
	}
	pad := 10
	// layout: per hull a band: label row, then 3x3 grid at x1 (native), then a column of hero S2, S3, id, depth at x1
	var bands []*Rig
	W, H := 0, 40
	for _, h := range hulls {
		r := readRig(rig, h)
		bands = append(bands, r)
		cw := int(math.Round((r.Frame[2] - r.Frame[0]) * r.PPU / 2))
		ch := int(math.Round((r.Frame[3] - r.Frame[1]) * r.PPU / 2))
		W = max(W, pad+3*(cw+pad)+20+4*(cw+pad))
		H += 30 + 3*(ch+pad+14) + pad
	}
	H += 40
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 10, 3, "BOSS RIG TURNTABLES (B0) - CLAY WITH HINTS AT X1 (ATLAS TEXEL DENSITY); CYAN = SIM WINDOWS, GOLD = SOLID BODY", ink)
	y := 40
	for _, r := range bands {
		cw := int(math.Round((r.Frame[2] - r.Frame[0]) * r.PPU / 2))
		ch := int(math.Round((r.Frame[3] - r.Frame[1]) * r.PPU / 2))
		k := r.PPU / 2 // px per unit at x1
		fails := 0
		for _, v := range r.Views {
			for _, s := range v.Stages {
				fails += len(s.Fail)
			}
		}
		text(sheet, pad, y+4, 3, fmt.Sprintf("%s  (%s, extent x%.2f, %d modules, %.2f px/unit)  anchor gate: %s",
			strings.ToUpper(r.Hull), r.Title, r.Extent, len(r.Insts), k, map[bool]string{true: "OK", false: fmt.Sprintf("%d FAILS", fails)}[fails == 0]), ink)
		y += 30
		for i, p := range pitches {
			for j, yw := range yaws {
				x := pad + j*(cw+pad)
				yy := y + i*(ch+pad+14)
				fill(sheet, image.Rect(x, yy, x+cw, yy+ch), bgPanel)
				im := clayHint(rig, r.Hull, "S0", tag(p, yw))
				blit(sheet, im, x, yy, 0.5)
				simOverlay(sheet, r, sim, x, yy, k)
				text(sheet, x, yy+ch+3, 2, fmt.Sprintf("PITCH %d YAW %+d", p, yw), dim)
			}
		}
		// right column block: hero S2, S3 (rows 0,1), id and depth (row 2)
		hx := pad + 3*(cw+pad) + 20
		hero := tag(45, 0)
		items := []struct {
			label, path string
			hint        bool
			stage       string
		}{
			{"S0 MODULE IDS", "id", false, "S0"}, {"S0 DEPTH (CONTROL)", "depth", false, "S0"},
			{"S2 PLATES OFF", "clay", true, "S2"}, {"S3 FIRST MODULE GONE", "clay", true, "S3"},
			{"S0 NORMAL", "normal", false, "S0"},
		}
		for n, it := range items {
			col, row := n%2, n/2
			x := hx + col*(cw+pad)
			yy := y + row*(ch+pad+14)
			fill(sheet, image.Rect(x, yy, x+cw, yy+ch), bgPanel)
			var im *image.NRGBA
			if it.hint {
				im = clayHint(rig, r.Hull, it.stage, hero)
			} else {
				p := filepath.Join(rig, r.Hull, it.stage, it.path+"_"+hero+".png")
				if _, err := os.Stat(p); err != nil {
					continue
				}
				im = load(p)
			}
			blit(sheet, im, x, yy, 0.5)
			text(sheet, x, yy+ch+3, 2, it.label+" (HERO VIEW)", dim)
		}
		y += 3*(ch+pad+14) + pad
	}
	save(out, sheet)
	fmt.Println(out)
}

// budget: resident RGBA per hull measured on the id masks of S0, S2 and S3.
// Stored views: pitch x yaw {0, +12} (yaw -12 draws +12 mirrored); at yaw 0 a
// mirrored module pair is stored once. Per module and view: the S0 layer is its
// id bbox; stage patches S2 and S3 are the bboxes of its pixels whose clay
// changes S0->S2 and S2->S3, and S1 (scorch) reuses the S2 patch rect.
// Rects are scaled from the render density to the atlas density (1/ppu-scale).
func cmdBudget(args []string) {
	rig, hulls := args[0], args[1:]
	for _, h := range hulls {
		r := readRig(rig, h)
		col := map[[3]uint8]string{}
		for id, hx := range r.IDs {
			c := hex(hx)
			col[[3]uint8{c.R, c.G, c.B}] = id
		}
		pairs := map[string]bool{}
		for _, in := range r.Insts {
			if strings.HasSuffix(in.ID, "L") && r.IDs[strings.TrimSuffix(in.ID, "L")+"R"] != "" {
				pairs[in.ID] = true
			}
		}
		total := 0.0
		perView := map[string]float64{}
		for _, p := range pitches {
			for _, yw := range []int{0, 12} {
				t := tag(p, yw)
				id0 := load(filepath.Join(rig, h, "S0", "id_"+t+".png"))
				c0 := load(filepath.Join(rig, h, "S0", "clay_"+t+".png"))
				c2 := load(filepath.Join(rig, h, "S2", "clay_"+t+".png"))
				c3 := load(filepath.Join(rig, h, "S3", "clay_"+t+".png"))
				type bb struct{ x0, y0, x1, y1 int }
				grow := func(m map[string]*bb, id string, x, y int) {
					b := m[id]
					if b == nil {
						m[id] = &bb{x, y, x, y}
						return
					}
					b.x0, b.y0, b.x1, b.y1 = min(b.x0, x), min(b.y0, y), max(b.x1, x), max(b.y1, y)
				}
				s0, s2, s3 := map[string]*bb{}, map[string]*bb{}, map[string]*bb{}
				w, hh := id0.Bounds().Dx(), id0.Bounds().Dy()
				diff := func(a, b *image.NRGBA, i int) bool {
					d := 0
					for k := 0; k < 4; k++ {
						d += int(math.Abs(float64(a.Pix[i+k]) - float64(b.Pix[i+k])))
					}
					return d > 24
				}
				for y := 0; y < hh; y++ {
					for x := 0; x < w; x++ {
						i := y*id0.Stride + x*4
						if id0.Pix[i+3] < 128 {
							continue
						}
						id := col[[3]uint8{id0.Pix[i], id0.Pix[i+1], id0.Pix[i+2]}]
						if id == "" {
							continue
						}
						grow(s0, id, x, y)
						if diff(c0, c2, i) {
							grow(s2, id, x, y)
						}
						if diff(c2, c3, i) {
							grow(s3, id, x, y)
						}
					}
				}
				k := 0.5 // render at ppu-scale 2: atlas rects are half per axis
				area := func(b *bb) float64 {
					if b == nil {
						return 0
					}
					return math.Ceil(float64(b.x1-b.x0+1)*k+2) * math.Ceil(float64(b.y1-b.y0+1)*k+2)
				}
				v := 0.0
				for id := range s0 {
					if yw == 0 && pairs[id] {
						continue
					}
					v += 4 * (area(s0[id]) + 2*area(s2[id]) + area(s3[id]))
				}
				perView[t] = v / (1 << 20)
				total += v
			}
		}
		keys := make([]string, 0, len(perView))
		for k := range perView {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		fmt.Printf("%-14s %.2f MB RGBA resident (6 stored views; S0 layers + S1/S2/S3 patches)", h, total/(1<<20))
		for _, k := range keys {
			fmt.Printf("  %s %.2f", k, perView[k])
		}
		fmt.Println()
	}
}

func cmdStack(args []string) {
	var ims []*image.NRGBA
	w, h := 0, 0
	for _, p := range args[1:] {
		im := load(p)
		ims = append(ims, im)
		w += im.Bounds().Dx() + 8
		h = max(h, im.Bounds().Dy())
	}
	out := newCanvas(w, h, color.NRGBA{60, 60, 70, 255})
	x := 0
	for _, im := range ims {
		blit(out, im, x, 0, 1)
		x += im.Bounds().Dx() + 8
	}
	save(args[0], out)
}

func main() {
	if len(os.Args) < 2 {
		fail("usage: see the header of tools/boss_sheet/main.go")
	}
	a := os.Args[2:]
	switch os.Args[1] {
	case "stack":
		cmdStack(a)
	case "clayhint":
		save(filepath.Join(a[0], a[1], a[2], "clayhint_"+a[3]+".png"), clayHint(a[0], a[1], a[2], a[3]))
	case "keyin":
		save(a[1], keyIn(load(a[0]), hex(a[2])))
	case "turntables":
		cmdTurntables(a)
	case "budget":
		cmdBudget(a)
	case "heroes":
		cmdHeroes(a)
	case "sym":
		cmdSym(a)
	case "bakefinish":
		cmdBakeFinish(a)
	case "views":
		cmdViews(a)
	case "stages":
		cmdStages(a)
	case "maskdiff":
		cmdMaskDiff(a)
	case "bakebudget":
		cmdBakeBudget(a)
	case "view":
		cmdView(a)
	case "finish":
		cmdFinish(a)
	case "lineup":
		cmdLineup(a)
	case "atlasframe":
		cmdAtlasFrame(a)
	default:
		fail("unknown command %s", os.Args[1])
	}
}
