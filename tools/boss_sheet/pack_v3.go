package main

// pack, carrier-v3 bakes (openspec/changes/carrier-v3/design.md §2, §3.4, §4;
// plan/render-runs/carrier-v3.md §2): one stored view (45, 0); the gates' open
// door states (manifest kind "door"); the rig's vortex points and hinges; the
// gate map (CarrierGate id -> art instance, from the family's gate anchors);
// and one data page per hull: the field data texture (R distance, G region,
// B height) on top, every instance's height grid below it (16-bit: z + 32768
// in R (high byte) and G (low byte)).

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// v3 is a carrier-v3 rig: one stored view.
func v3Rig(rigDir, hull string) bool {
	raw, _ := os.ReadFile(filepath.Join(rigDir, hull, "rig.json"))
	var rv struct {
		Views map[string]json.RawMessage `json:"views"`
	}
	json.Unmarshal(raw, &rv)
	return len(rv.Views) == 1
}

func (m *bakeManifest) viewDoors(t string, add addFn) map[string][4]*packItem {
	out := map[string][4]*packItem{}
	for _, e := range m.Entries {
		if e.Kind != "door" || e.View != t {
			continue
		}
		st := out[e.Inst]
		st[stageIndex[e.Stage]] = add(t+".door."+e.Inst+"."+e.Stage, m.sprite(e), e.DXY[0], e.DXY[1], e.Texel)
		out[e.Inst] = st
	}
	return out
}

type v3Extras struct {
	vortex    []rigPoint
	hinges    map[string][4]float64
	gates     map[string]string
	dataDart  string
	dataBytes int
}

// v3Data reads the rig's vortex points, hinges and the family's gate map, and
// writes the hull's data page (assets/images/boss-KEY-data.png).
func v3Data(bake, rigDir, root, hull, key string) v3Extras {
	var x v3Extras
	raw, _ := os.ReadFile(filepath.Join(rigDir, hull, "rig.json"))
	var rv struct {
		Family string `json:"family"`
		Views  map[string]struct {
			Stages map[string]struct {
				Vortex []rigPoint `json:"vortex"`
			} `json:"stages"`
		} `json:"views"`
		Hinges map[string]struct {
			Root [2]float64 `json:"root"`
			Tip  [2]float64 `json:"tip"`
		} `json:"hinges"`
		Insts []struct {
			ID string `json:"id"`
		} `json:"instances"`
	}
	json.Unmarshal(raw, &rv)
	if v, ok := rv.Views[tag(45, 0)]; ok {
		x.vortex = v.Stages["S0"].Vortex
	}
	x.hinges = map[string][4]float64{}
	for id, h := range rv.Hinges {
		x.hinges[id] = [4]float64{h.Root[0], h.Root[1], h.Tip[0], h.Tip[1]}
	}
	have := map[string]bool{}
	for _, in := range rv.Insts {
		have[in.ID] = true
	}
	fb, _ := os.ReadFile(filepath.Join(root, rv.Family))
	var fam struct {
		Anchors struct {
			Points []struct {
				Name   string `json:"name"`
				Module string `json:"module"`
			} `json:"points"`
		} `json:"anchors"`
	}
	json.Unmarshal(fb, &fam)
	x.gates = map[string]string{}
	for _, p := range fam.Anchors.Points {
		if !strings.HasPrefix(p.Name, "gate_") {
			continue
		}
		id := strings.TrimPrefix(p.Name, "gate_")
		inst := p.Module
		if inst == "prow" { // the deck bays: their gate module is gate_bayL / gate_bayR
			inst = "gate_" + id
		}
		if have[inst] {
			x.gates[id] = inst
		}
	}
	// the data page
	fieldPath := filepath.Join(bake, hull, "fin_field.png")
	if _, err := os.Stat(fieldPath); err != nil {
		return x
	}
	field := load(fieldPath)
	var fm struct {
		Left, Top, PPU, Range float64
	}
	if b, err := os.ReadFile(filepath.Join(bake, hull, "fin_field.json")); err == nil {
		json.Unmarshal(b, &fm)
	}
	var hs struct {
		Step   float64 `json:"step"`
		Layers map[string]struct {
			X0 float64 `json:"x0"`
			Y0 float64 `json:"y0"`
			W  int     `json:"w"`
			H  int     `json:"h"`
			Z  []int   `json:"z"`
		} `json:"layers"`
	}
	if b, err := os.ReadFile(filepath.Join(bake, hull, "heights.json")); err == nil {
		json.Unmarshal(b, &hs)
	}
	fw, fh := field.Bounds().Dx(), field.Bounds().Dy()
	W := fw
	// the fracture map (operator round 3b C3) sits beside the field, same grid
	var chunks *image.NRGBA
	var cj struct {
		Chunks [][3]float64 `json:"chunks"`
	}
	if _, err := os.Stat(filepath.Join(bake, hull, "fin_chunks.png")); err == nil {
		chunks = load(filepath.Join(bake, hull, "fin_chunks.png"))
		if b, err := os.ReadFile(filepath.Join(bake, hull, "fin_chunks.json")); err == nil {
			json.Unmarshal(b, &cj)
		}
	}
	ids := make([]string, 0, len(hs.Layers))
	for id := range hs.Layers {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	// shelf-pack the grids under the field
	type place struct{ x, y int }
	pl := map[string]place{}
	x0, y0, shelf := 0, fh+1, 0
	for _, id := range ids {
		l := hs.Layers[id]
		if x0+l.W > W {
			x0, y0, shelf = 0, y0+shelf+1, 0
		}
		pl[id] = place{x0, y0}
		x0 += l.W + 1
		shelf = max(shelf, l.H)
	}
	H := y0 + shelf
	page := image.NewNRGBA(image.Rect(0, 0, W, H))
	blit(page, field, 0, 0, 1)
	chunkDart := "null"
	if chunks != nil {
		var cs []string
		for _, c := range cj.Chunks {
			cs = append(cs, fmt.Sprintf("(%s, %s, %s)", num(c[0]), num(c[1]), num(c[2])))
		}
		chunkDart = fmt.Sprintf("BossHeroGrid(0, 0, %d, %d, %s, %s), chunkCentres: [%s]", fw, fh, num(fm.Left), num(fm.Top), strings.Join(cs, ", "))
	}
	var grids []string
	for _, id := range ids {
		l, p := hs.Layers[id], pl[id]
		for j := 0; j < l.H; j++ {
			for i := 0; i < l.W; i++ {
				z := l.Z[j*l.W+i] + 32768
				page.SetNRGBA(p.x+i, p.y+j, color.NRGBA{uint8(z >> 8), uint8(z & 255), 0, 255})
			}
		}
		grids = append(grids, fmt.Sprintf("'%s': BossHeroGrid(%d, %d, %d, %d, %s, %s)", id, p.x, p.y, l.W, l.H, num(l.X0), num(l.Y0)))
	}
	name := "boss-" + key + "-data.png"
	save(filepath.Join(root, "assets/images", name), page)
	x.dataBytes = W * H * 4
	x.dataDart = fmt.Sprintf("BossHeroData('%s', %d, %d, field: BossHeroGrid(0, 0, %d, %d, %s, %s), fieldPpu: %s, fieldRange: %s, step: %s, heights: {%s}, chunks: %s)",
		name, W, H, fw, fh, num(fm.Left), num(fm.Top), num(fm.PPU), num(fm.Range), num(hs.Step), strings.Join(grids, ", "), chunkDart)
	return x
}

func (x v3Extras) dart(w func(string, ...any)) {
	if len(x.gates) > 0 {
		keys := make([]string, 0, len(x.gates))
		for k := range x.gates {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		var b []string
		for _, k := range keys {
			b = append(b, fmt.Sprintf("'%s': '%s'", k, x.gates[k]))
		}
		w("      gates: {%s},\n", strings.Join(b, ", "))
	}
	if len(x.hinges) > 0 {
		keys := make([]string, 0, len(x.hinges))
		for k := range x.hinges {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		var b []string
		for _, k := range keys {
			h := x.hinges[k]
			b = append(b, fmt.Sprintf("'%s': (%s, %s, %s, %s)", k, num(h[0]), num(h[1]), num(h[2]), num(h[3])))
		}
		w("      hinges: {%s},\n", strings.Join(b, ", "))
	}
	if x.dataDart != "" {
		w("      data: %s,\n", x.dataDart)
	}
}

const heroTypesV3 = `/// carrier-v3: a grid on a hull's data page: its px rect on the page and the
/// hull-local (arena units) position of its first node / texel.
class BossHeroGrid {
  const BossHeroGrid(this.x, this.y, this.w, this.h, this.left, this.top);
  final int x, y, w, h;
  final double left, top;
}

/// carrier-v3: a hull's data page (its own small PNG): the field data
/// texture at [field] (R 128 + distance × 127 / [fieldRange], outside
/// positive; G region × 20; B the fracture chunk id, see [chunks]; [fieldPpu] px per unit, texel
/// centres at left + (i + .5) / ppu) and every instance's height grid
/// (z + 32768, R high byte, G low byte; nodes every [step] units from the
/// grid's left/top).
class BossHeroData {
  const BossHeroData(this.asset, this.w, this.h,
      {required this.field,
      required this.fieldPpu,
      required this.fieldRange,
      required this.step,
      required this.heights,
      this.chunks,
      this.chunkCentres = const []});
  final String asset;
  final int w, h;
  final BossHeroGrid field;
  final double fieldPpu, fieldRange, step;
  final Map<String, BossHeroGrid> heights;

  /// The collapse's fracture map (operator round 3b C3): the field
  /// texture's B channel, chunk id (1..n, 0 outside the S0 silhouette); cracks follow
  /// the painted seams (a marker watershed on the beauty's luminance edges).
  /// [chunkCentres] (x, y, area in units²) of chunk i + 1.
  final BossHeroGrid? chunks;
  final List<(double, double, double)> chunkCentres;
}

`
