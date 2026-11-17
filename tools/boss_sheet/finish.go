package main

// finish: a raw hero (AI output on the key colour) to the atlas grid, the
// boss analogue of ground_blocks finish (option A1, colour-preserving):
//  1. resize the raw to the rig frame (the AI keeps the input's framing);
//  2. alpha = the rig silhouette dilated by 1 atlas texel, minus key pixels
//     (the rig owns the silhouette; AI may move an edge by at most 1 texel);
//  3. despill the key, area-downscale to the hull's texel density;
//  4. quantise to the hull-family ramps (art/families/boss-hulls.json), ink outline.
//
//	boss_sheet finish RAW RIG HULL STAGE TAG OUT.png [--no-quant]

import (
	"encoding/json"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strings"
)

type grammar struct {
	Palettes struct {
		Ramps map[string][]string `json:"ramps"`
	} `json:"palettes"`
}

func familyPalette() []color.NRGBA {
	b, err := os.ReadFile(filepath.Join(repoRoot(), "art/families/boss-hulls.json"))
	if err != nil {
		fail("%v", err)
	}
	var g grammar
	if err := json.Unmarshal(b, &g); err != nil {
		fail("%v", err)
	}
	var pal []color.NRGBA
	for name, r := range g.Palettes.Ramps {
		if name == "shield" { // the cyan force-shield language is overlay-only
			continue
		}
		for _, h := range r {
			pal = append(pal, hex(h))
		}
	}
	return pal
}

// resize: bilinear to w x h.
func resize(src *image.NRGBA, w, h int) *image.NRGBA {
	sw, sh := src.Bounds().Dx(), src.Bounds().Dy()
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		fy := (float64(y)+0.5)*float64(sh)/float64(h) - 0.5
		y0 := int(math.Floor(fy))
		ty := fy - float64(y0)
		for x := 0; x < w; x++ {
			fx := (float64(x)+0.5)*float64(sw)/float64(w) - 0.5
			x0 := int(math.Floor(fx))
			tx := fx - float64(x0)
			var acc [4]float64
			for _, s := range [][3]float64{{0, 0, (1 - tx) * (1 - ty)}, {1, 0, tx * (1 - ty)}, {0, 1, (1 - tx) * ty}, {1, 1, tx * ty}} {
				xx := min(max(x0+int(s[0]), 0), sw-1)
				yy := min(max(y0+int(s[1]), 0), sh-1)
				c := src.NRGBAAt(xx, yy)
				acc[0] += float64(c.R) * s[2]
				acc[1] += float64(c.G) * s[2]
				acc[2] += float64(c.B) * s[2]
				acc[3] += float64(c.A) * s[2]
			}
			out.SetNRGBA(x, y, color.NRGBA{uint8(acc[0] + .5), uint8(acc[1] + .5), uint8(acc[2] + .5), uint8(acc[3] + .5)})
		}
	}
	return out
}

func isKey(c color.NRGBA) bool {
	return int(c.G) > int(c.R)+60 && int(c.G) > int(c.B)+60
}

// dilate grows a boolean mask by r pixels (square).
func dilate(m []bool, w, h, r int) []bool {
	out := make([]bool, len(m))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if !m[y*w+x] {
				continue
			}
			for dy := -r; dy <= r; dy++ {
				for dx := -r; dx <= r; dx++ {
					xx, yy := x+dx, y+dy
					if xx >= 0 && yy >= 0 && xx < w && yy < h {
						out[yy*w+xx] = true
					}
				}
			}
		}
	}
	return out
}

func nearest(pal []color.NRGBA, c color.NRGBA) color.NRGBA {
	best, bd := pal[0], math.MaxFloat64
	for _, p := range pal {
		dr, dg, db := float64(c.R)-float64(p.R), float64(c.G)-float64(p.G), float64(c.B)-float64(p.B)
		rm := (float64(c.R) + float64(p.R)) / 2
		d := (2+rm/256)*dr*dr + 4*dg*dg + (2+(255-rm)/256)*db*db
		if d < bd {
			bd, best = d, p
		}
	}
	return color.NRGBA{best.R, best.G, best.B, c.A}
}

// finishHero returns the finished sprite at atlas density, and the raw fitted
// to the render frame (for the projection bake).
func finishHero(raw *image.NRGBA, rig *Rig, rigDir, stage, t string, quant bool) (*image.NRGBA, *image.NRGBA) {
	W, H := rig.Size[0], rig.Size[1]
	fit := resize(raw, W, H)
	clay := load(filepath.Join(rigDir, rig.Hull, stage, "clay_"+t+".png"))
	sil := make([]bool, W*H)
	for i := range sil {
		sil[i] = clay.Pix[i*4+3] >= 128
	}
	sil = dilate(sil, W, H, 2) // 1 atlas texel at ppu-scale 2
	for i := 0; i < W*H; i++ {
		c := fit.NRGBAAt(i%W, i/W)
		if !sil[i] || isKey(c) {
			fit.Pix[i*4+3] = 0
			continue
		}
		// despill: clamp green to the max of red and blue where it dominates
		if m := max(c.R, c.B); c.G > m {
			fit.Pix[i*4+1] = m + (c.G-m)/4
		}
		fit.Pix[i*4+3] = 255
	}
	small := areaScale(fit, 0.5)
	sw, sh := small.Bounds().Dx(), small.Bounds().Dy()
	pal := familyPalette()
	inkC := hex("#0A0716")
	out := image.NewNRGBA(small.Bounds())
	for y := 0; y < sh; y++ {
		for x := 0; x < sw; x++ {
			c := small.NRGBAAt(x, y)
			if c.A < 128 {
				continue
			}
			c.A = 255
			if quant {
				c = nearest(pal, c)
			}
			out.SetNRGBA(x, y, c)
		}
	}
	// outline ink on the silhouette edge (inside)
	edge := image.NewNRGBA(out.Bounds())
	copy(edge.Pix, out.Pix)
	for y := 0; y < sh; y++ {
		for x := 0; x < sw; x++ {
			if out.NRGBAAt(x, y).A == 0 {
				continue
			}
			for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
				xx, yy := x+d[0], y+d[1]
				if xx < 0 || yy < 0 || xx >= sw || yy >= sh || out.NRGBAAt(xx, yy).A == 0 {
					edge.SetNRGBA(x, y, inkC)
					break
				}
			}
		}
	}
	return edge, fit
}

func cmdFinish(a []string) {
	raw, rigDir, hull, stage, t, out := a[0], a[1], a[2], a[3], a[4], a[5]
	quant := !(len(a) > 6 && a[6] == "--no-quant")
	rig := readRig(rigDir, hull)
	fin, fit := finishHero(load(raw), rig, rigDir, stage, t, quant)
	save(out, fin)
	save(out[:len(out)-4]+"-fit.png", fit)
}

// sheetHead: the frigate keeps its pilot (B1/B2) titles; later hulls are B3.
// The hero seed comes from selected.<hull>.S0 in the family spec.
func sheetHead(hull, kind, pilotCP string) string {
	if hull == "frigate" {
		return "BOSS PILOT " + kind + " (" + pilotCP + ")"
	}
	return "BOSS HULL " + kind + " (B3)"
}

func heroSeed(hull string) string {
	b, err := os.ReadFile(filepath.Join(repoRoot(), "art/families/boss-hulls.json"))
	if err != nil {
		fail("%v", err)
	}
	var g struct {
		Selected map[string]json.RawMessage `json:"selected"`
	}
	if err := json.Unmarshal(b, &g); err != nil {
		fail("%v", err)
	}
	var s struct{ S0 string }
	_ = json.Unmarshal(g.Selected[hull], &s)
	base := filepath.Base(s.S0)
	return strings.TrimSuffix(base, filepath.Ext(base))
}
