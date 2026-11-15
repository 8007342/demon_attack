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
	cell := p.findCell(u, args[1])
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

// finish (decision A1, plan/render-runs/ground-forces-rework.md §10): keep
// the AI image's colour, quantised to the faction palette of the unit's
// master sector, inside the rig silhouette dilated by one texel (8-way).
// Each texel takes the mean non-key colour of its region of the AI frame
// (the edit workflows keep the reference's framing; an image of another
// aspect is fitted subject box to rig box instead). Inside the rig the
// nearest palette colour wins; in the one-texel ring the texel is kept only
// where the AI covered most of it and its colour is not nearer the ink
// than the palette (the AI's own outline stays outline). Hard rig texels
// the AI left empty keep the rig's shading; soft ones may vanish at the
// edge. Binary alpha, ink around the result.
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
	at := func(x, y int) color.NRGBA {
		r, g, bb, a := src.At(x, y).RGBA()
		return color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(bb >> 8), uint8(a >> 8)}
	}
	W, H := c.F.W, c.F.H
	out := image.NewNRGBA(image.Rect(0, 0, W, H))
	cx0, cy0, cx1, cy1 := c.F.bbox()
	if cx1 < 0 {
		return out
	}
	// texel (x, y) of the cell reads source rect [fx0+x*fw/W', ...) where
	// the frame is the whole image (same aspect) or the subject box fitted
	// to the rig box (other aspect).
	fx0, fy0, fw, fh := float64(sb.Min.X), float64(sb.Min.Y), float64(sb.Dx()), float64(sb.Dy())
	gx0, gy0, gw, gh := 0.0, 0.0, float64(W), float64(H)
	if a := fw / fh / (float64(W) / float64(H)); a < .97 || a > 1.03 {
		x0, y0, x1, y1 := sb.Max.X, sb.Max.Y, -1, -1
		for y := sb.Min.Y; y < sb.Max.Y; y++ {
			for x := sb.Min.X; x < sb.Max.X; x++ {
				if !isBg(at(x, y)) {
					x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
				}
			}
		}
		if x1 < 0 {
			return out
		}
		fx0, fy0, fw, fh = float64(x0), float64(y0), float64(x1-x0+1), float64(y1-y0+1)
		gx0, gy0, gw, gh = float64(cx0), float64(cy0), float64(cx1-cx0+1), float64(cy1-cy0+1)
	}
	mean := make([]color.NRGBA, W*H)
	cov := make([]float64, W*H)
	for y := 0; y < H; y++ {
		for x := 0; x < W; x++ {
			ax0 := int(fx0 + (float64(x)-gx0)*fw/gw)
			ax1 := max(int(fx0+(float64(x+1)-gx0)*fw/gw), ax0+1)
			ay0 := int(fy0 + (float64(y)-gy0)*fh/gh)
			ay1 := max(int(fy0+(float64(y+1)-gy0)*fh/gh), ay0+1)
			var r, g, bl, n, k float64
			for yy := max(ay0, sb.Min.Y); yy < min(ay1, sb.Max.Y); yy++ {
				for xx := max(ax0, sb.Min.X); xx < min(ax1, sb.Max.X); xx++ {
					col := at(xx, yy)
					n++
					if !isBg(col) {
						r, g, bl = r+float64(col.R), g+float64(col.G), bl+float64(col.B)
						k++
					}
				}
			}
			if k > 0 {
				mean[y*W+x] = color.NRGBA{uint8(r/k + .5), uint8(g/k + .5), uint8(bl/k + .5), 255}
				cov[y*W+x] = k / n
			}
		}
	}
	colours := pal.finishColours(master)
	keep := make([]bool, W*H)
	for y := 0; y < H; y++ {
		for x := 0; x < W; x++ {
			i := y*W + x
			px := c.F.at(x, y)
			if px.Mat != 0 {
				soft := false
				if pr := b.prim(px.Prim); pr != nil && pr.Soft {
					soft = true
				}
				interior := c.F.filled(x-1, y) && c.F.filled(x+1, y) && c.F.filled(x, y-1) && c.F.filled(x, y+1)
				switch {
				case cov[i] >= .2:
					out.SetNRGBA(x, y, nearest(colours, mean[i]))
				case soft && !interior:
					continue
				default:
					out.SetNRGBA(x, y, pal.colour(*px, master, b.Rig.Seed))
				}
				keep[i] = true
				continue
			}
			ring := false
			for dy := -1; dy <= 1 && !ring; dy++ {
				for dx := -1; dx <= 1; dx++ {
					if c.F.filled(x+dx, y+dy) {
						ring = true
						break
					}
				}
			}
			if !ring || cov[i] < .5 {
				continue
			}
			q := nearest(colours, mean[i])
			if colDist(mean[i], pal.Ink) <= colDist(mean[i], q) {
				continue
			}
			out.SetNRGBA(x, y, q)
			keep[i] = true
		}
	}
	if !c.Overlay {
		for y := 0; y < H; y++ {
			for x := 0; x < W; x++ {
				if keep[y*W+x] {
					continue
				}
				for _, d := range [4][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}} {
					if xx, yy := x+d[0], y+d[1]; xx >= 0 && yy >= 0 && xx < W && yy < H && keep[yy*W+xx] {
						out.SetNRGBA(x, y, pal.Ink)
						break
					}
				}
			}
		}
	}
	return out
}

// finishNames: the ramps a finished cell may use, in a fixed order (the
// first ramp holding a colour owns it when the pack remaps sectors).
func (pal *Palette) finishNames() []string {
	names := make([]string, 0, len(pal.Ramps)+2)
	for k := range pal.Ramps {
		names = append(names, k)
	}
	if pal.Faction == "host" {
		names = append(names, "stone", "membrane")
	}
	sort.Strings(names)
	return names
}

// finishColours: every distinct colour of the faction's ramps in a sector.
func (pal *Palette) finishColours(sector string) []color.NRGBA {
	seen := map[color.NRGBA]bool{}
	var out []color.NRGBA
	for _, n := range pal.finishNames() {
		for _, col := range pal.ramp(n, sector) {
			if !seen[col] {
				seen[col] = true
				out = append(out, col)
			}
		}
	}
	return out
}

// colDist: squared "redmean" RGB distance, a cheap perceptual weighting.
func colDist(a, b color.NRGBA) float64 {
	rm := (float64(a.R) + float64(b.R)) / 2
	dr, dg, db := float64(a.R)-float64(b.R), float64(a.G)-float64(b.G), float64(a.B)-float64(b.B)
	return (2+rm/256)*dr*dr + 4*dg*dg + (2+(255-rm)/256)*db*db
}

func nearest(pal []color.NRGBA, c color.NRGBA) color.NRGBA {
	best, bd := pal[0], math.Inf(1)
	for _, p := range pal {
		if d := colDist(p, c); d < bd {
			best, bd = p, d
		}
	}
	return best
}
