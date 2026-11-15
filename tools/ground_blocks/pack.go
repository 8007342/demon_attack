package main

// Per-sector packing (task 2.5): each sector atlas holds only the blocks
// its roster uses, with the sector kit baked in, then one fx row. The
// metadata maps cell names to (atlas, row, column).

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"

	"demonattack/tools/pixelgrid"
)

type Placement struct {
	Unit string
	Row0 int
}

type AtlasOut struct {
	Family   *Family
	Sector   string
	File     string
	Img      *image.NRGBA
	Units    []Placement
	FxRow    int
	PNGBytes int
	CellW    int
	CellH    int
}

func (p *Project) fxCells(fam *Family) []Cell {
	pal := p.Pals[fam.Faction]
	cw, ch := fam.Atlas.Cell[0], fam.Atlas.Cell[1]
	mk := func() *Frame { return newFrame(cw, ch, float64(cw)/2, float64(ch)-1) }
	m := func(n string) int8 {
		i, ok := pal.Mats.Index[n]
		if !ok {
			fail(errf("%s: fx material %s", fam.Name, n))
		}
		return i
	}
	smoke, glow := m("smoke"), m("glow")
	var out []Cell
	add := func(col int, name string, f *Frame) {
		out = append(out, Cell{Name: fam.Faction + "." + name, Row: 0, Col: col, F: f, Overlay: true})
	}
	cx, cy := float64(cw)/2, float64(ch)-4
	for f := 0; f < 4; f++ {
		fr := mk()
		r := pixelgrid.NewRng(9100 + f)
		for k := 0; k < 5; k++ {
			x := cx - 6 - float64(f)*1.5 - r.F()*4
			y := cy - float64(f)*1.2 - r.F()*2
			pixelgrid.Disc(matCanvas{fr, smoke, int8(3 - f/2)}, x, y, 1.6-float64(f)*.25, 1.1, 0)
		}
		add(f, fmt.Sprintf("fx.skid.f%d", f), fr)
	}
	for f := 0; f < 4; f++ {
		fr := mk()
		rx := 5 + float64(f)*4
		for a := 0.0; a < 360; a += 3 {
			x := cx + rx*cosd(a)
			y := cy - 2 + rx*.5*sind(a)
			if int(a/3)%3 != f%3 {
				matCanvas{fr, smoke, int8(3 - f/2)}.Set(int(x), int(y), 0)
			}
		}
		add(4+f, fmt.Sprintf("fx.ring.f%d", f), fr)
	}
	for f := 0; f < 3; f++ {
		fr := mk()
		pixelgrid.Disc(matCanvas{fr, glow, 3}, cx, float64(ch)/2, 3.2-float64(f), 3.2-float64(f), 0)
		pixelgrid.Disc(matCanvas{fr, glow, 4}, cx, float64(ch)/2, 1.6-float64(f)*.5, 1.6-float64(f)*.5, 0)
		add(8+f, fmt.Sprintf("fx.muzzle.f%d", f), fr)
	}
	shard := "plate"
	if fam.Faction == "host" {
		shard = "stone"
	}
	for f := 0; f < 3; f++ {
		fr := mk()
		r := pixelgrid.NewRng(9200 + f)
		for k := 0; k < 6; k++ {
			x := cx + (r.F()-.5)*(6+float64(f)*6)
			y := float64(ch)/2 - 2 + (r.F()-.5)*6 + float64(f)*2
			matCanvas{fr, m(shard), int8(2 + k%2)}.Set(int(x), int(y), 0)
			matCanvas{fr, m(shard), int8(1 + k%2)}.Set(int(x)+1, int(y), 0)
		}
		add(11+f, fmt.Sprintf("fx.shards.f%d", f), fr)
	}
	return out
}

func (p *Project) packFamily(fam *Family, sector string, finished bool) *AtlasOut {
	cw, ch := fam.Atlas.Cell[0], fam.Atlas.Cell[1]
	rows := 0
	var pl []Placement
	for _, id := range fam.Sectors[sector].Units {
		u := p.unit(id)
		pl = append(pl, Placement{id, rows})
		rows += blockRows(u.Spec.Block)
	}
	fxRow := -1
	if fam.Faction != "mixed" {
		fxRow = rows
		rows++
	}
	img := image.NewNRGBA(image.Rect(0, 0, fam.Atlas.Columns*cw, max(1, rows)*ch))
	for _, q := range pl {
		u := p.unit(q.Unit)
		pal := p.Pals[u.faction()]
		seed := p.Rigs[q.Unit].Seed
		for i := range p.cellsOf(u) {
			c := &p.cellsOf(u)[i]
			ox, oy := c.Col*cw, (q.Row0+c.Row)*ch
			if finished {
				if fin := finishedCell(q.Unit, c.Name); fin != nil {
					paintFinished(img, c, fin, pal, ox, oy, sector, p.masterSector(u))
					continue
				}
			}
			pal.paintCell(img, c, ox, oy, sector, seed)
		}
	}
	if fxRow >= 0 {
		pal := p.Pals[fam.Faction]
		for _, c := range p.fxCells(fam) {
			pal.paintCell(img, &c, c.Col*cw, fxRow*ch, sector, 0)
		}
	}
	b, err := pixelgrid.EncodePNG(img)
	must(err)
	return &AtlasOut{Family: fam, Sector: sector, File: atlasPath(fam, sector), Img: img, Units: pl, FxRow: fxRow, PNGBytes: len(b), CellW: cw, CellH: ch}
}

// masterSector: the sector a unit's finished cells are quantised in (its
// first sector).
func (p *Project) masterSector(u unitRef) string {
	for _, s := range sectorOrder {
		for _, f := range p.Fams {
			if contains(f.Sectors[s].Units, u.Spec.ID) {
				return s
			}
		}
	}
	return "hollow"
}

func finishedPath(unit, name string) string {
	return filepath.Join(root, "art/sprites/sources/ground-blocks", unit, name+".png")
}

func finishedCell(unit, name string) image.Image {
	im, err := pixelgrid.ReadPNG(finishedPath(unit, name))
	if err != nil {
		return nil
	}
	return im
}

// paintFinished: a finished (AI-refined) cell, its colours from the master
// sector's ramps remapped ramp-for-ramp to the target sector. The finished
// image owns the silhouette within the rig's one-texel ring (A1); texels
// it does not cover fall back to the rig colour, and the ink goes around
// the result.
func paintFinished(dst *image.NRGBA, c *Cell, fin image.Image, pal *Palette, ox, oy int, sector, master string) {
	type rs struct {
		ramp string
		step int
	}
	rev := map[color.NRGBA]rs{}
	for _, n := range pal.finishNames() {
		for i, col := range pal.ramp(n, master) {
			if _, ok := rev[col]; !ok {
				rev[col] = rs{n, i}
			}
		}
	}
	f := c.F
	b := fin.Bounds()
	keep := make([]bool, f.W*f.H)
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			inFin := x < b.Dx() && y < b.Dy()
			if inFin {
				r, g, bb, a := fin.At(b.Min.X+x, b.Min.Y+y).RGBA()
				k := color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(bb >> 8), 255}
				if q, ok := rev[k]; ok && a >= 0x8000 {
					rr := pal.ramp(q.ramp, sector)
					dst.SetNRGBA(ox+x, oy+y, rr[min(q.step, len(rr)-1)])
					keep[y*f.W+x] = true
					continue
				}
			}
			if f.filled(x, y) && !inFin {
				dst.SetNRGBA(ox+x, oy+y, pal.colour(*f.at(x, y), sector, 0))
				keep[y*f.W+x] = true
			}
		}
	}
	if c.Overlay {
		return
	}
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			if keep[y*f.W+x] {
				continue
			}
			for _, d := range [4][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}} {
				if xx, yy := x+d[0], y+d[1]; xx >= 0 && yy >= 0 && xx < f.W && yy < f.H && keep[yy*f.W+xx] {
					dst.SetNRGBA(ox+x, oy+y, pal.Ink)
					break
				}
			}
		}
	}
}

type packReport struct {
	Sector    string           `json:"sector"`
	Atlases   []map[string]any `json:"atlases"`
	RGBABytes int              `json:"rgba_bytes"`
	PNGBytes  int              `json:"png_bytes"`
	DrawCalls map[string]int   `json:"draw_calls_busy_frame"`
}

func cmdPack(finished bool) {
	p := loadProject()
	if errs := p.validate(); len(errs) > 0 {
		for _, e := range errs {
			fmt.Println(e)
		}
		os.Exit(1)
	}
	p.buildAll()
	var outs []*AtlasOut
	var reports []packReport
	for _, s := range sectorOrder {
		rep := packReport{Sector: s, DrawCalls: map[string]int{}}
		for _, f := range familyFiles {
			a := p.packFamily(p.Fams[f], s, finished)
			outs = append(outs, a)
			must(pixelgrid.WritePNG(filepath.Join(root, a.File), a.Img))
			w, h := a.Img.Bounds().Dx(), a.Img.Bounds().Dy()
			rep.Atlases = append(rep.Atlases, map[string]any{"file": a.File, "w": w, "h": h, "rgba_bytes": w * h * 4, "png_bytes": a.PNGBytes, "blocks": len(a.Units)})
			rep.RGBABytes += w * h * 4
			rep.PNGBytes += a.PNGBytes
		}
		rep.DrawCalls = p.drawCalls(s)
		reports = append(reports, rep)
	}
	writeDart(p, outs)
	b, _ := json.MarshalIndent(map[string]any{
		"note":    "Generated by tools/ground_blocks pack/offline. RGBA bytes are the uncompressed GPU footprint of each sector's three atlases; draw calls are drawImageRect calls for the ground units in a busy frame at the skirmish caps (see plan/render-runs/ground-forces-rework.md, Section 7).",
		"sectors": reports,
	}, "", " ")
	must(os.WriteFile(filepath.Join(root, "art/families/ground-blocks-pack.json"), append(b, '\n'), 0o644))
	for _, r := range reports {
		fmt.Printf("%-8s rgba %5.2f MB  png %4d KB  draws %v\n", r.Sector, float64(r.RGBABytes)/(1<<20), r.PNGBytes/1024, r.DrawCalls)
	}
}

// drawCalls estimates drawImageRect calls in a busy frame of a sector: the
// skirmish caps of plan/ground-war-v4 (Host 5/5/5/6/3 by sector, one threat
// vehicle), three allied vehicles and two squads of four. A vehicle draws
// hull + articulated layer + up to two overlays at near LOD; infantry one.
func (p *Project) drawCalls(sector string) map[string]int {
	caps := map[string]int{"krybor": 5, "ringfall": 5, "ember": 5, "hollow": 6, "carrier": 3}
	host := caps[sector] * 4
	threat := 4
	allies := 3 * 4
	inf := 2 * 4
	return map[string]int{"host": host, "threat": threat, "fleet": allies, "infantry": inf, "total": host + threat + allies + inf, "textures": 3}
}

func cosd(a float64) float64 { return cosf(rad(a)) }
func sind(a float64) float64 { return sinf(rad(a)) }
