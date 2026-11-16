package main

// bakefinish and budget: the finished outputs and the documented layout the
// atlas pack reads (openspec/changes/boss-hero-assets/design.md section 8.6):
//
//	BAKE/<hull>/<stage>/fin_layer_<inst>_<view>.png   instance layer, full frame at its stored density
//	BAKE/<hull>/<stage>/fin_beauty_<view>.png          review composite at the finest class density
//	BAKE/<hull>/fin_wreck_<inst>_f<0|1>.png            S4 wreck frames (left of a mirrored pair only)
//	BAKE/<hull>/manifest.json                          every stored sprite: file, kind, inst, stage,
//	                                                   view, texel (px per unit), crop rect in px and
//	                                                   its top-left in arena units from the carrier centre
//
// Stored density: S0 layers and wrecks at the instance's texel class density
// (rig.json instances[].texel); S1-S3 layers at that density x stage_scale
// (the family budget.stage_scale, the B2 half-density decision).

import (
	"encoding/json"
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Entry struct {
	File  string     `json:"file"`
	Kind  string     `json:"kind"`
	Inst  string     `json:"inst"`
	Stage string     `json:"stage,omitempty"`
	View  string     `json:"view,omitempty"`
	Texel float64    `json:"texel"`
	Crop  [4]int     `json:"crop"`
	DXY   [2]float64 `json:"dxy"`
	Bytes int        `json:"bytes"`
}

type Manifest struct {
	Schema     string             `json:"schema"`
	Hull       string             `json:"hull"`
	Family     string             `json:"family"`
	Replaces   string             `json:"replaces,omitempty"`
	Frame      [4]float64         `json:"frame"`
	Texel      map[string]float64 `json:"texel"`
	StageScale float64            `json:"stage_scale"`
	StoredYaw  []int              `json:"stored_yaw"`
	Mirror     string             `json:"mirror"`
	Entries    []Entry            `json:"entries"`
	Resident   int                `json:"resident_bytes"`
	Notes      string             `json:"notes"`
}

func stageScale(fam string) float64 {
	b, _ := os.ReadFile(filepath.Join(repoRoot(), fam))
	var g struct {
		Budget struct {
			StageScale float64 `json:"stage_scale"`
		} `json:"budget"`
		Hulls map[string]struct {
			Replaces string `json:"replaces"`
		} `json:"hulls"`
	}
	_ = json.Unmarshal(b, &g)
	if g.Budget.StageScale == 0 {
		return 0.5
	}
	return g.Budget.StageScale
}

func viewOf(name string) string {
	i := strings.LastIndex(name, "_p")
	return name[i+1 : len(name)-4]
}

func cmdBakeFinish(a []string) {
	bake, rigDir, hull := a[0], a[1], a[2]
	r := readRig(rigDir, hull)
	fam := readFamily(r.Family)
	pal := fam.palette()
	ss := stageScale(r.Family)
	m := Manifest{Schema: "demon-attack.boss-bake/v2", Hull: hull, Family: r.Family, Frame: r.Frame, Texel: r.Texel,
		StageScale: ss, StoredYaw: fam.Views.StoredYaw, Mirror: "yaw -t draws +t mirrored about x = 0; at yaw 0 and in wrecks a mirrored pair stores its L or R once (see inst)",
		Notes: "dxy = top-left of the cropped sprite in arena units from the carrier centre at the view; draw at w/texel x h/texel units"}
	addAt := func(frame [4]float64, dir, name, kind, inst, stage, view string, texel float64, im *image.NRGBA) {
		out := filepath.Join(dir, "fin_"+name)
		save(out, im)
		// carrier-v3 §2.4: 4 transparent texels around every sprite (the mesh's edge lies in them)
		cr := padCrop(im, 4)
		if cr.Empty() {
			return
		}
		rel, _ := filepath.Rel(filepath.Join(bake, hull), out)
		e := Entry{File: rel, Kind: kind, Inst: inst, Stage: stage, View: view, Texel: texel,
			Crop:  [4]int{cr.Min.X, cr.Min.Y, cr.Dx(), cr.Dy()},
			DXY:   [2]float64{frame[0] + float64(cr.Min.X)/texel, frame[1] + float64(cr.Min.Y)/texel},
			Bytes: (cr.Dx() + 2) * (cr.Dy() + 2) * 4}
		if kind != "beauty" {
			m.Resident += e.Bytes
		}
		m.Entries = append(m.Entries, e)
	}
	add := func(dir, name, kind, inst, stage, view string, texel float64, im *image.NRGBA) {
		addAt(r.Frame, dir, name, kind, inst, stage, view, texel, im)
	}
	// a layer's render with its under-paint when bake.py rendered one (carrier-v3)
	withUnder := func(d, nm string, src *image.NRGBA) *image.NRGBA {
		if u := filepath.Join(d, "under_"+nm); mustStat(u) {
			return underPaint(src, load(u), r)
		}
		return src
	}
	for _, stage := range []string{"S0", "S1", "S2", "S3"} {
		d := filepath.Join(bake, hull, stage)
		ents, err := os.ReadDir(d)
		if err != nil {
			continue
		}
		n := 0
		for _, e := range ents {
			nm := e.Name()
			if strings.HasPrefix(nm, "fin_") || strings.HasPrefix(nm, "under_") || !strings.HasSuffix(nm, ".png") {
				continue
			}
			src := load(filepath.Join(d, nm))
			v := viewOf(nm)
			switch {
			case strings.HasPrefix(nm, "beauty_"):
				add(d, nm, "beauty", "", stage, v, r.maxTexel(), finishAt(src, r, r.maxTexel(), pal, true))
			case strings.HasPrefix(nm, "layer_"), strings.HasPrefix(nm, "door_"):
				kind := strings.SplitN(nm, "_", 2)[0] // layer, or door: a gate's open state
				id := strings.TrimSuffix(strings.TrimPrefix(nm, kind+"_"), "_"+v+".png")
				in := r.inst(id)
				if in == nil {
					continue
				}
				tx := in.Texel
				if stage != "S0" {
					tx *= ss
				}
				add(d, nm, kind, id, stage, v, tx, finishAt(withUnder(d, nm, src), r, tx, pal, false))
			}
			n++
		}
		fmt.Printf("%s %s: %d finished\n", hull, stage, n)
	}
	d := filepath.Join(bake, hull)
	ents, _ := os.ReadDir(d)
	for _, e := range ents {
		nm := e.Name()
		if !strings.HasPrefix(nm, "wreck_") {
			continue
		}
		id := strings.SplitN(strings.TrimPrefix(nm, "wreck_"), "_f", 2)[0]
		in := r.inst(id)
		if in == nil {
			continue
		}
		if !strings.HasSuffix(nm, ".png") {
			continue
		}
		fr := r.Frame // carrier-v3: a wreck rendered in its own frame carries it in a sidecar
		if b, err := os.ReadFile(filepath.Join(d, strings.TrimSuffix(nm, ".png")+".json")); err == nil {
			var wf struct{ Frame [4]float64 }
			if json.Unmarshal(b, &wf) == nil {
				fr = wf.Frame
			}
		}
		addAt(fr, d, nm, "wreck", id, "S4", tag(45, 0), in.Texel, finishAt(load(filepath.Join(d, nm)), r, in.Texel, pal, true))
	}
	if b := filepath.Join(d, "fin_belly.png"); mustStat(b) { // the Overflight underside: its own asset, not resident with the hull
		im := load(b)
		cr := alphaBounds(im)
		m.Entries = append(m.Entries, Entry{File: "fin_belly.png", Kind: "belly", Stage: "overflight", Texel: 0.5,
			Crop: [4]int{cr.Min.X, cr.Min.Y, cr.Dx(), cr.Dy()}, Bytes: (cr.Dx() + 2) * (cr.Dy() + 2) * 4})
	}
	sort.Slice(m.Entries, func(i, j int) bool { return m.Entries[i].File < m.Entries[j].File })
	b, _ := json.MarshalIndent(m, "", " ")
	os.WriteFile(filepath.Join(d, "manifest.json"), b, 0o644)
	fmt.Printf("%s: %d entries, %.2f MB RGBA resident (stored layers + wrecks)\n", hull, len(m.Entries), float64(m.Resident)/(1<<20))
}

// budget: the resident RGBA of the stored sprites, by stage, kind and texel class, from the manifest.
func cmdBudget(a []string) {
	bake, rigDir, hulls := a[0], a[1], a[2:]
	for _, hull := range hulls {
		r := readRig(rigDir, hull)
		b, err := os.ReadFile(filepath.Join(bake, hull, "manifest.json"))
		if err != nil {
			fail("%v (run bakefinish first)", err)
		}
		var m Manifest
		json.Unmarshal(b, &m)
		by := map[string]int{}
		total := 0
		for _, e := range m.Entries {
			if e.Kind == "beauty" || e.Kind == "belly" {
				continue
			}
			in := r.inst(e.Inst)
			cls := "?"
			if in != nil {
				cls = in.TexelClass
			}
			k := e.Kind + " " + e.Stage + " " + cls
			if e.Kind == "wreck" {
				k = "wreck " + cls
			}
			by[k] += e.Bytes
			total += e.Bytes
		}
		if im, err := os.Stat(filepath.Join(bake, hull, "fin_field.png")); err == nil && im.Size() > 0 {
			f := load(filepath.Join(bake, hull, "fin_field.png"))
			by["field data"] = f.Bounds().Dx() * f.Bounds().Dy() * 4
			total += by["field data"]
		}
		keys := make([]string, 0, len(by))
		for k := range by {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		fmt.Printf("%s: %.2f MB RGBA resident (budget 16)\n", hull, float64(total)/(1<<20))
		for _, k := range keys {
			fmt.Printf("  %-22s %6.2f MB\n", k, float64(by[k])/(1<<20))
		}
		_ = math.Abs
	}
}
