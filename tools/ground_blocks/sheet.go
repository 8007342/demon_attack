package main

import (
	"fmt"
	"image"
	"image/color"
	"strings"

	"demonattack/tools/pixelgrid"
)

// cmdSheet OUT CELL=RAW.png ...: a finish review sheet, one row per AI raw:
// the rig cell, the raw (scaled to the row), the finished cell, each at x6
// on a dark ground, labelled with the raw's file name.
func cmdSheet(args []string) {
	if len(args) < 2 {
		fail(fmt.Errorf("usage: sheet OUT.png <unit>.<cell>=RAW.png ..."))
	}
	p := loadProject()
	const k = 6
	type row struct {
		rig, raw, fin *image.NRGBA
		label         string
	}
	var rows []row
	maxW, maxH := 0, 0
	for _, a := range args[1:] {
		name, rawPath, ok := strings.Cut(a, "=")
		if !ok {
			fail(fmt.Errorf("want CELL=RAW.png, got %q", a))
		}
		u := p.unit(strings.SplitN(name, ".", 2)[0])
		cell := p.findCell(u, name)
		if cell == nil {
			fail(fmt.Errorf("no cell %s", name))
		}
		src, err := pixelgrid.ReadPNG(rawPath)
		must(err)
		key := pixelgrid.Hex(orStr(u.Fam.Sprite.Reference.Key, "#FF00FF"))
		pal := p.Pals[u.faction()]
		rig := image.NewNRGBA(image.Rect(0, 0, cell.F.W, cell.F.H))
		pal.paintCell(rig, cell, 0, 0, p.masterSector(u), p.builder(u).Rig.Seed)
		fin := p.finish(u, cell, src, key)
		// the raw, area-sampled to the cell's size x k
		rw, rh := cell.F.W*k, cell.F.H*k
		raw := image.NewNRGBA(image.Rect(0, 0, rw, rh))
		sb := src.Bounds()
		for y := 0; y < rh; y++ {
			for x := 0; x < rw; x++ {
				r, g, b, _ := src.At(sb.Min.X+x*sb.Dx()/rw, sb.Min.Y+y*sb.Dy()/rh).RGBA()
				raw.SetNRGBA(x, y, color.NRGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), 255})
			}
		}
		lab := rawPath[strings.LastIndex(rawPath, "/")+1:]
		rows = append(rows, row{rig, raw, fin, name + " " + lab})
		maxW, maxH = max(maxW, cell.F.W*k), max(maxH, cell.F.H*k)
	}
	pad, lab := 8, 14
	W := 3*maxW + 4*pad
	H := len(rows)*(maxH+lab+pad) + pad
	out := image.NewNRGBA(image.Rect(0, 0, W, H))
	fill(out, out.Bounds(), color.NRGBA{24, 26, 34, 255})
	for i, r := range rows {
		y := pad + i*(maxH+lab+pad)
		text(out, pad, y, 2, r.label, color.NRGBA{200, 200, 210, 255})
		y += lab
		for j := 0; j < 3; j++ {
			fill(out, image.Rect(pad+j*(maxW+pad), y, pad+j*(maxW+pad)+maxW, y+maxH), color.NRGBA{40, 44, 56, 255})
		}
		blit(out, r.rig, pad, y, k, false)
		blit(out, r.raw, pad+maxW+pad, y, 1, false)
		blit(out, r.fin, pad+2*(maxW+pad), y, k, false)
	}
	must(pixelgrid.WritePNG(args[0], out))
	fmt.Println("sheet", len(rows), "rows ->", args[0])
}

// findCell: a block cell or a reference cell (hull.ref.hNNN, art.ref.aNNN)
// of a unit by its full name.
func (p *Project) findCell(u unitRef, name string) *Cell {
	for _, cs := range [][]Cell{p.cellsOf(u), p.refCells(u)} {
		for i := range cs {
			if cs[i].Name == name {
				return &cs[i]
			}
		}
	}
	return nil
}
