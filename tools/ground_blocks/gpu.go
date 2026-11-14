package main

// GPU-side verbs. Nothing here talks to the studio: rig writes reference
// images, jobs writes the queue (run it with the studio tools, one job at a
// time, per plan/render-runs/rerender-all.md), ingest records provenance,
// finish puts one AI image back on the grid.

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"demonattack/tools/pixelgrid"
)

// refImage: a hull (with its layer) or layer cell at x scale on the key.
func (p *Project) refImage(u unitRef, c *Cell, scale int, key color.NRGBA) *image.NRGBA {
	b := p.builder(u)
	pal := p.Pals[u.faction()]
	cell := image.NewNRGBA(image.Rect(0, 0, b.CW, b.CH))
	pal.paintCell(cell, c, 0, 0, p.masterSector(u), b.Rig.Seed)
	out := image.NewNRGBA(image.Rect(0, 0, b.CW*scale, b.CH*scale))
	for y := 0; y < b.CH*scale; y++ {
		for x := 0; x < b.CW*scale; x++ {
			col := cell.NRGBAAt(x/scale, y/scale)
			if col.A == 0 {
				col = key
			}
			out.SetNRGBA(x, y, col)
		}
	}
	return out
}

func (p *Project) refCells(u unitRef) []Cell {
	b := p.builder(u)
	var out []Cell
	for _, h := range b.Headings {
		var fr *Frame
		if b.Rig.Block == "I" {
			fr = b.move(h, 0)
		} else {
			fr = b.composed(h, b.opt(h))
		}
		out = append(out, Cell{Name: u.Spec.ID + ".hull.ref.h" + hcode(h), F: fr})
	}
	for _, a := range b.Angles {
		ao := defaultOpt("art")
		ao.Aim = a
		out = append(out, Cell{Name: u.Spec.ID + ".art.ref.a" + hcode(a), F: b.art(ao)})
	}
	return out
}

func cmdRig(args []string) {
	p := loadProject()
	n := 0
	for _, u := range p.units() {
		if len(args) > 0 && !contains(args, u.Spec.ID) {
			continue
		}
		key := pixelgrid.Hex(orStr(u.Fam.Sprite.Reference.Key, "#FF00FF"))
		sc := max(1, u.Fam.Sprite.Reference.Scale)
		for _, c := range p.refCells(u) {
			c := c
			path := filepath.Join(workDir(), "rig", u.Spec.ID, c.Name+".png")
			must(pixelgrid.WritePNG(path, p.refImage(u, &c, sc, key)))
			n++
		}
	}
	fmt.Println(n, "rig references ->", filepath.Join(workDir(), "rig"))
}

func orStr(s, d string) string {
	if s == "" {
		return d
	}
	return s
}

type Job struct {
	ID        string         `json:"id"`
	Unit      string         `json:"unit"`
	Family    string         `json:"family"`
	Kind      string         `json:"kind"` // hero | heading | layer
	Workflow  string         `json:"workflow"`
	Inputs    map[string]any `json:"inputs"`
	Overrides map[string]any `json:"overrides"`
	Missing   bool           `json:"workflow_missing,omitempty"`
}

func (p *Project) jobs() []Job {
	var jobs []Job
	for _, u := range p.units() {
		fam, s := u.Fam, u.Spec
		master := p.masterSector(u)
		phrase := func(h float64) string { return fam.HeadingPhrases[hcode(h)] }
		prompt := func(h float64) string {
			parts := []string{fam.StylePrompt}
			if ph := phrase(h); ph != "" {
				parts = append(parts, ph)
			}
			parts = append(parts, s.Subject)
			if m := s.Sectors[master]; m != "" {
				parts = append(parts, m)
			}
			return strings.Join(parts, ", ")
		}
		ref := func(name string) string { return filepath.Join("rig", s.ID, s.ID+"."+name+".png") }
		wf := func(k string) (string, bool) {
			w := fam.Sprite.Workflows[k]
			_, err := os.Stat(filepath.Join(root, w))
			return w, err != nil
		}
		hw, hm := wf("hero")
		for c := 0; c < s.Hero.Candidates; c++ {
			seed := s.Seed + c
			jobs = append(jobs, Job{ID: fmt.Sprintf("%s/hero/%d", s.ID, seed), Unit: s.ID, Family: fam.Name, Kind: "hero", Workflow: hw, Missing: hm,
				Inputs:    map[string]any{"input": ref("hull.ref.h" + hcode(s.Hero.Heading))},
				Overrides: map[string]any{"prompt": prompt(s.Hero.Heading), "negative_prompt": fam.NegativePrompt, "seed": seed}})
		}
		heroSel := "<hero selection pending>"
		if s.Hero.Selected != nil {
			heroSel = fmt.Sprintf("selected/%s/hero/%d.png", s.ID, *s.Hero.Selected)
		}
		dw, dm := wf("heading")
		for i, h := range s.Headings {
			if h == s.Hero.Heading {
				continue
			}
			for c := 0; c < max(1, s.HeadingCandidates); c++ {
				seed := s.Seed + 10 + i*4 + c
				jobs = append(jobs, Job{ID: fmt.Sprintf("%s/heading/h%s/%d", s.ID, hcode(h), seed), Unit: s.ID, Family: fam.Name, Kind: "heading", Workflow: dw, Missing: dm,
					Inputs:    map[string]any{"input": ref("hull.ref.h" + hcode(h)), "hero": heroSel},
					Overrides: map[string]any{"prompt": "Redraw image 1 with exactly the materials, colours and detail of image 2. Keep the outline, pose and viewing angle of image 1. " + prompt(h), "negative_prompt": fam.NegativePrompt, "seed": seed}})
			}
		}
		if s.Art != nil {
			b := p.builder(u)
			for i, a := range b.Angles {
				for c := 0; c < max(1, s.HeadingCandidates); c++ {
					seed := s.Seed + 40 + i*4 + c
					jobs = append(jobs, Job{ID: fmt.Sprintf("%s/layer/a%s/%d", s.ID, hcode(a), seed), Unit: s.ID, Family: fam.Name, Kind: "layer", Workflow: dw, Missing: dm,
						Inputs:    map[string]any{"input": ref("art.ref.a" + hcode(a)), "hero": heroSel},
						Overrides: map[string]any{"prompt": "Redraw image 1 with exactly the materials, colours and detail of image 2. Keep the outline and angle of image 1. " + fam.StylePrompt + ", the " + s.Art.Kind + " of " + s.Subject, "negative_prompt": fam.NegativePrompt, "seed": seed}})
				}
			}
		}
	}
	return jobs
}

func cmdJobs() {
	p := loadProject()
	jobs := p.jobs()
	must(os.MkdirAll(workDir(), 0o755))
	b, _ := json.MarshalIndent(jobs, "", " ")
	must(os.WriteFile(filepath.Join(workDir(), "jobs.json"), b, 0o644))
	kinds := map[string]int{}
	missing := 0
	for _, j := range jobs {
		kinds[j.Kind]++
		if j.Missing {
			missing++
		}
	}
	fmt.Printf("%d jobs %v -> %s (%d reference a workflow not committed yet)\n", len(jobs), kinds, filepath.Join(workDir(), "jobs.json"), missing)
}

// cmdIngest copies $BLOCKS_WORK/http/<job id with / as __> to $BLOCKS_RAW
// and records workflow, prompt, seed and output hashes per family.
func cmdIngest() {
	p := loadProject()
	jobs := map[string]Job{}
	for _, j := range p.jobs() {
		jobs[j.ID] = j
	}
	runs := map[string]map[string]any{}
	for _, f := range familyFiles {
		fam := p.Fams[f]
		m := map[string]any{}
		if b, err := os.ReadFile(filepath.Join(root, fam.Runs)); err == nil {
			must(json.Unmarshal(b, &m))
		}
		runs[fam.Name] = m
	}
	entries, _ := os.ReadDir(filepath.Join(workDir(), "http"))
	n := 0
	for _, d := range entries {
		jid := strings.ReplaceAll(d.Name(), "__", "/")
		j, ok := jobs[jid]
		if !ok || !d.IsDir() {
			continue
		}
		dest := filepath.Join(rawDir(), jid)
		must(os.MkdirAll(dest, 0o755))
		var outputs []map[string]string
		pngs, _ := filepath.Glob(filepath.Join(workDir(), "http", d.Name(), "*.png"))
		sort.Strings(pngs)
		for _, f := range pngs {
			b, err := os.ReadFile(f)
			must(err)
			must(os.WriteFile(filepath.Join(dest, filepath.Base(f)), b, 0o644))
			h := sha256.Sum256(b)
			outputs = append(outputs, map[string]string{"file": filepath.Base(f), "sha256": hex.EncodeToString(h[:])})
		}
		runs[j.Family]["runs/"+jid] = map[string]any{"workflow": j.Workflow, "kind": j.Kind, "inputs": j.Inputs,
			"prompt": j.Overrides["prompt"], "negative_prompt": j.Overrides["negative_prompt"], "seed": j.Overrides["seed"], "outputs": outputs}
		n++
	}
	for _, f := range familyFiles {
		fam := p.Fams[f]
		b, _ := json.MarshalIndent(runs[fam.Name], "", " ")
		must(os.WriteFile(filepath.Join(root, fam.Runs), append(b, '\n'), 0o644))
	}
	fmt.Println("ingested", n)
}

// cmdFinish IN CELL [OUT]: finishing for one AI image.
func cmdFinish(args []string) {
	if len(args) < 2 {
		fail(fmt.Errorf("usage: finish IN.png <unit>.<cell name> [OUT.png]"))
	}
	p := loadProject()
	id := strings.SplitN(args[1], ".", 2)[0]
	u := p.unit(id)
	var cell *Cell
	cs := p.cellsOf(u)
	for i := range cs {
		if cs[i].Name == args[1] {
			cell = &cs[i]
		}
	}
	if cell == nil {
		fail(fmt.Errorf("no cell %s", args[1]))
	}
	src, err := pixelgrid.ReadPNG(args[0])
	must(err)
	key := pixelgrid.Hex(orStr(u.Fam.Sprite.Reference.Key, "#FF00FF"))
	out := p.finish(u, cell, src, key)
	dst := finishedPath(id, args[1])
	if len(args) > 2 {
		dst = args[2]
	}
	must(pixelgrid.WritePNG(dst, out))
	fmt.Println("finished", args[1], "->", dst)
}

// finish: crop the AI image to its subject, area-downscale onto the rig
// cell's content box, quantise each texel to the ramp of the rig's
// material there (nearest luma within the material's steps), keep the rig
// silhouette (soft prims may grow or shrink by one texel), binary alpha,
// ink outline.
func (p *Project) finish(u unitRef, c *Cell, src image.Image, key color.NRGBA) *image.NRGBA {
	b := p.builder(u)
	pal := p.Pals[u.faction()]
	master := p.masterSector(u)
	isBg := func(col color.NRGBA) bool {
		if col.A < 128 {
			return true
		}
		d := math.Abs(float64(col.R)-float64(key.R)) + math.Abs(float64(col.G)-float64(key.G)) + math.Abs(float64(col.B)-float64(key.B))
		return d < 90
	}
	sb := src.Bounds()
	x0, y0, x1, y1 := sb.Max.X, sb.Max.Y, -1, -1
	at := func(x, y int) color.NRGBA {
		r, g, bb, a := src.At(x, y).RGBA()
		return color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(bb >> 8), uint8(a >> 8)}
	}
	for y := sb.Min.Y; y < sb.Max.Y; y++ {
		for x := sb.Min.X; x < sb.Max.X; x++ {
			if !isBg(at(x, y)) {
				x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
			}
		}
	}
	cx0, cy0, cx1, cy1 := c.F.bbox()
	out := image.NewNRGBA(image.Rect(0, 0, c.F.W, c.F.H))
	if x1 < 0 || cx1 < 0 {
		return out
	}
	cw, ch := cx1-cx0+1, cy1-cy0+1
	sw, sh := x1-x0+1, y1-y0+1
	lum := make([]float64, cw*ch)
	cov := make([]float64, cw*ch)
	for y := 0; y < ch; y++ {
		for x := 0; x < cw; x++ {
			ax0, ax1 := x0+x*sw/cw, x0+max((x+1)*sw/cw, x*sw/cw+1)
			ay0, ay1 := y0+y*sh/ch, y0+max((y+1)*sh/ch, y*sh/ch+1)
			var s, n, k float64
			for yy := ay0; yy < ay1; yy++ {
				for xx := ax0; xx < ax1; xx++ {
					col := at(xx, yy)
					n++
					if !isBg(col) {
						s += pixelgrid.Luma(col)
						k++
					}
				}
			}
			if k > 0 {
				lum[y*cw+x] = s / k
			}
			cov[y*cw+x] = k / math.Max(1, n)
		}
	}
	grid := c.F.clone()
	for y := 0; y < c.F.H; y++ {
		for x := 0; x < c.F.W; x++ {
			px := c.F.at(x, y)
			lx, ly := x-cx0, y-cy0
			inBox := lx >= 0 && ly >= 0 && lx < cw && ly < ch
			soft := false
			if pr := b.prim(px.Prim); pr != nil && pr.Soft {
				soft = true
			}
			if px.Mat == 0 {
				// a soft neighbour may grow by one texel where the AI drew
				for _, d := range [4][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}} {
					if q := c.F.at(x+d[0], y+d[1]); q != nil && q.Mat != 0 {
						if pr := b.prim(q.Prim); pr != nil && pr.Soft && inBox && cov[ly*cw+lx] > .6 {
							*grid.at(x, y) = *q
						}
					}
				}
				continue
			}
			if !inBox {
				continue
			}
			if soft && cov[ly*cw+lx] < .2 && !(c.F.filled(x-1, y) && c.F.filled(x+1, y) && c.F.filled(x, y-1) && c.F.filled(x, y+1)) {
				*grid.at(x, y) = Px{}
				continue
			}
			m := pal.Mats.List[px.Mat]
			if m.Emissive || m.Flat || cov[ly*cw+lx] == 0 {
				continue
			}
			ramp := pal.ramp(m.Ramp, master)
			best, bs := 9.0, int(px.Step)
			for s := m.Lo; s <= m.Hi; s++ {
				if d := math.Abs(pixelgrid.Luma(ramp[s]) - lum[ly*cw+lx]); d < best {
					best, bs = d, s
				}
			}
			grid.at(x, y).Step = int8(bs)
		}
	}
	fc := &Cell{Name: c.Name, F: grid, Overlay: c.Overlay}
	pal.paintCell(out, fc, 0, 0, master, b.Rig.Seed)
	return out
}
