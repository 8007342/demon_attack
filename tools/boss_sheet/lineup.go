package main

// lineup: the B3 tour-progression sheet. One column per hull, in tour order:
// the hero view S0 finished at x1 (atlas density, a DPR-2 phone), then S0 and
// S3 at CSS size (1 px per unit) over the arena sky with the simulation windows,
// all bottom-aligned so the growth from tour to tour reads at a glance.
//
//	boss_sheet lineup BAKE RIG OUT.png HULL...

import (
	"fmt"
	"image"
	"math"
	"strings"
)

func cmdLineup(a []string) {
	bake, rigDir, out, hulls := a[0], a[1], a[2], a[3:]
	sim := readSim()
	t := tag(45, 0)
	pad := 16
	type col struct {
		r           *Rig
		w, h        int // x1 size
		cw, ch      int // CSS size
		s0, s3, s0c *image.NRGBA
	}
	var cols []col
	W, H1, H2 := pad, 0, 0
	for _, h := range hulls {
		r := readRig(rigDir, h)
		s0 := load(finPath(bake, h, "S0", t))
		s3 := load(finPath(bake, h, "S3", t))
		css := 2 / r.PPU
		c := col{r: r, w: s0.Bounds().Dx(), h: s0.Bounds().Dy(), s0: s0, s3: s3}
		c.cw, c.ch = int(math.Round(float64(c.w)*css)), int(math.Round(float64(c.h)*css))
		cols = append(cols, c)
		W += c.w + pad
		H1 = max(H1, c.h)
		H2 = max(H2, c.ch)
	}
	H := 50 + 30 + H1 + 40 + 2*(H2+40) + pad
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 12, 3, "BOSS HULLS (B3) - TOUR PROGRESSION: HERO VIEW S0 AT X1 (ATLAS), THEN S0 AND S3 AT CSS SIZE WITH THE SIM WINDOWS", ink)
	x := pad
	for _, c := range cols {
		y := 50
		text(sheet, x, y, 2, strings.ToUpper(fmt.Sprintf("%s (%d MODULES, X%.2f)", c.r.Title, len(c.r.Insts), c.r.Extent)), ink)
		y += 30
		fill(sheet, image.Rect(x, y, x+c.w, y+H1), bgPanel)
		blit(sheet, c.s0, x, y+H1-c.h, 1)
		y += H1 + 40
		for i, im := range []*image.NRGBA{c.s0, c.s3} {
			sky := image.Rect(x, y, x+c.w, y+H2)
			fill(sheet, sky, hex("#0B0F1E"))
			bx, by := x+(c.w-c.cw)/2, y+H2-c.ch
			blit(sheet, im, bx, by, 2/c.r.PPU)
			simOverlay(sheet, c.r, sim, bx, by, 1)
			text(sheet, x, y+H2+6, 2, []string{"S0 CSS SIZE", "S3 CSS SIZE"}[i], dim)
			y += H2 + 40
		}
		x += c.w + pad
	}
	save(out, sheet)
	fmt.Println(out)
}
