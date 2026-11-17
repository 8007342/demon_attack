package main

// pack, v2 bakes (boss-carrier-v2, openspec/changes/boss-hero-assets/design.md
// section 8.6): the finished sprites come from BAKE/<hull>/manifest.json
// (tools/rigsheet bakefinish), already at their stored density (texel classes,
// stage scale); nothing is rescaled here. A view the bake did not store (the
// v2 budget stores the swerve at the middle pitch only) aliases the pitch-45
// view of the same yaw: the same sprites, no extra texture.

import (
	"encoding/json"
	"fmt"
	"image"
	"image/draw"
	"os"
	"path/filepath"
)

type bakeEntry struct {
	File  string     `json:"file"`
	Kind  string     `json:"kind"`
	Inst  string     `json:"inst"`
	Stage string     `json:"stage"`
	View  string     `json:"view"`
	Texel float64    `json:"texel"`
	Crop  [4]int     `json:"crop"`
	DXY   [2]float64 `json:"dxy"`
}

type bakeManifest struct {
	Schema  string      `json:"schema"`
	Hull    string      `json:"hull"`
	Entries []bakeEntry `json:"entries"`
	dir     string
	cache   map[string]map[string][4]*packItem
}

func readBakeManifest(bake, hull string) *bakeManifest {
	b, err := os.ReadFile(filepath.Join(bake, hull, "manifest.json"))
	if err != nil {
		fail("%v (a v2 hull needs tools/rigsheet bakefinish)", err)
	}
	var m bakeManifest
	if err := json.Unmarshal(b, &m); err != nil {
		fail("%v", err)
	}
	m.dir = filepath.Join(bake, hull)
	return &m
}

func (m *bakeManifest) sprite(e bakeEntry) *image.NRGBA {
	im := load(filepath.Join(m.dir, e.File))
	out := image.NewNRGBA(image.Rect(0, 0, e.Crop[2], e.Crop[3]))
	draw.Draw(out, out.Bounds(), im, image.Point{e.Crop[0], e.Crop[1]}, draw.Src)
	return out
}

var stageIndex = map[string]int{"S0": 0, "S1": 1, "S2": 2, "S3": 3}

type addFn = func(key string, im *image.NRGBA, dx, dy float64, ppu float64) *packItem

func (m *bakeManifest) viewLayers(t string, add addFn) map[string][4]*packItem {
	if m.cache == nil {
		m.cache = map[string]map[string][4]*packItem{}
	}
	if c, ok := m.cache[t]; ok {
		return c // an aliased view reuses the same sprites
	}
	out := map[string][4]*packItem{}
	defer func() { m.cache[t] = out }()
	for _, e := range m.Entries {
		if e.Kind != "layer" || e.View != t {
			continue
		}
		st := out[e.Inst]
		st[stageIndex[e.Stage]] = add(t+"."+e.Inst+"."+e.Stage, m.sprite(e), e.DXY[0], e.DXY[1], e.Texel)
		out[e.Inst] = st
	}
	return out
}

func (m *bakeManifest) wrecks(add addFn) map[string][2]*packItem {
	out := map[string][2]*packItem{}
	for _, e := range m.Entries {
		if e.Kind != "wreck" {
			continue
		}
		f := 0
		if filepath.Ext(e.File) == ".png" && len(e.File) > 6 && e.File[len(e.File)-6:] == "f1.png" {
			f = 1
		}
		w := out[e.Inst]
		w[f] = add("wreck."+e.Inst, m.sprite(e), e.DXY[0], e.DXY[1], e.Texel)
		out[e.Inst] = w
	}
	return out
}

func packHullV2(bake, rigDir, root, hull, class, dartSrc string) string {
	return packHullAs(bake, rigDir, root, hull, hull, class, dartSrc, readBakeManifest(bake, hull))
}

// belly writes the manifest's belly sprite (kind "belly": the Overflight's
// underside, outside the resident budget) to assets/images/boss-KEY-belly.png
// and returns its Dart constant, or "" when the bake has none.
func (m *bakeManifest) belly(root, key string) string {
	for _, e := range m.Entries {
		if e.Kind != "belly" {
			continue
		}
		im := m.sprite(e)
		name := "boss-" + key + "-belly.png"
		save(filepath.Join(root, "assets/images", name), im)
		return fmt.Sprintf("BossHeroBelly('%s', %d, %d, %s)", name, e.Crop[2], e.Crop[3], num(e.Texel))
	}
	return ""
}

// skylinePack places the items (sorted tallest first) on pages of pageW x pageMaxH with a
// bottom-left skyline (each column's filled height; 4-px candidate steps), opening a page
// only when no page fits. Returns the used height of each page. Far less waste than shelves
// for the v2 bakes, whose sprites range from 20 px gun ports to 600 px hull layers.
func skylinePack(order []*packItem, pad, pageW int) []int {
	type sky struct {
		col []int
		h   int
	}
	var pages []*sky
	place := func(s *sky, w, h int) (int, int) {
		bx, by := -1, pageMaxH+1
		for x := 0; x+w <= pageW; x += 4 {
			top := 0
			for c := x; c < x+w; c++ {
				top = max(top, s.col[c])
			}
			if top+h <= pageMaxH && top < by {
				bx, by = x, top
			}
		}
		return bx, by
	}
	for _, it := range order {
		w, h := it.img.Bounds().Dx()+pad, it.img.Bounds().Dy()+pad
		done := false
		for pi, s := range pages {
			if x, y := place(s, w, h); x >= 0 {
				for c := x; c < x+w && c < pageW; c++ {
					s.col[c] = y + h
				}
				it.page, it.x, it.y = pi, x, y
				s.h = max(s.h, y+h-pad)
				done = true
				break
			}
		}
		if !done {
			s := &sky{col: make([]int, pageW)}
			pages = append(pages, s)
			x, y := place(s, w, h)
			if x < 0 {
				fail("sprite %s (%d x %d) does not fit a page", it.key, w, h)
			}
			for c := x; c < x+w && c < pageW; c++ {
				s.col[c] = y + h
			}
			it.page, it.x, it.y = len(pages)-1, x, y
			s.h = max(s.h, y+h-pad)
		}
	}
	out := make([]int, len(pages))
	for i, s := range pages {
		out[i] = s.h
	}
	return out
}
