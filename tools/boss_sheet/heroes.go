package main

// heroes: the B1 sheet. Header row: the rig control (clay with hints), the
// depth control and today's atlas frame (the identity reference). Then one row
// per candidate: raw (at the render density), finished at the atlas density
// (x1, a DPR-2 phone), finished at 1 px per unit (CSS size on the phone) over
// a dark sky with the simulation windows, and a verdict line.
//
//	boss_sheet heroes RIG HULL OUT.png TODAY.png "label|raw.png|verdict" ...

import (
	"fmt"
	"image"
	"path/filepath"
	"strings"
)

func cmdHeroes(a []string) {
	rigDir, hull, out, today := a[0], a[1], a[2], a[3]
	rig := readRig(rigDir, hull)
	sim := readSim()
	t := tag(45, 0)
	W, H := rig.Size[0], rig.Size[1]
	nw, nh := W/2, H/2
	pad := 12
	rowH := max(H/2, nh) + 40
	cols := []int{W / 2, nw, nw/2 + 40}
	sheetW := pad
	for _, c := range cols {
		sheetW += c + pad
	}
	sheetW = max(sheetW, 3*(W/2+pad)+pad)
	entries := a[4:]
	sheet := newCanvas(sheetW, 50+(rowH+pad)*(len(entries)+1), bgDark)
	text(sheet, pad, 12, 3, strings.ToUpper(fmt.Sprintf("%s - %s, HERO VIEW PITCH 45 YAW 0", sheetHead(hull, "HEROES", "B1"), rig.Title)), ink)
	y := 50
	head := []struct {
		l  string
		im *image.NRGBA
	}{
		{"RIG CONTROL: CLAY + HINTS (IMAGE 1)", keyIn(clayHint(rigDir, hull, "S0", t), hex("#00FF00"))},
		{"RIG DEPTH (SDXL-CN CONTROL)", load(filepath.Join(rigDir, hull, "S0", "depth_"+t+".png"))},
		{"TODAY'S ATLAS FRAME (IDENTITY REFERENCE) X1", load(today)},
	}
	for i, h := range head {
		x := pad + i*(W/2+pad)
		fill(sheet, image.Rect(x, y, x+W/2, y+H/2), bgPanel)
		k := 0.5
		if i == 2 {
			k = 1
		}
		blit(sheet, h.im, x, y, k)
		text(sheet, x, y+H/2+6, 2, h.l, dim)
	}
	y += rowH + pad
	for _, e := range entries {
		p := strings.SplitN(e, "|", 3)
		raw := load(p[1])
		fin, _ := finishHero(raw, rig, rigDir, "S0", t, true)
		x := pad
		fill(sheet, image.Rect(x, y, x+W/2, y+H/2), bgPanel)
		blit(sheet, resize(raw, W/2, H/2), x, y, 1)
		text(sheet, x, y+H/2+6, 2, strings.ToUpper(p[0])+" RAW", ink)
		x += W/2 + pad
		fill(sheet, image.Rect(x, y, x+nw, y+nh), bgPanel)
		blit(sheet, fin, x, y, 1)
		text(sheet, x, y+nh+6, 2, "FINISHED X1 (ATLAS, DPR-2 PHONE)", dim)
		x += nw + pad
		// CSS-size phone strip: 180 units of a 360-wide arena at 1 px/unit
		css := 2 / rig.PPU // finished texels -> 1 px per unit (0.5 for the frigate)
		cw, ch := int(float64(nw)*css), int(float64(nh)*css)
		sky := image.Rect(x, y, x+cw+40, y+ch+60)
		fill(sheet, sky, hex("#0B0F1E"))
		bx := x + 20
		blit(sheet, fin, bx, y+30, css)
		simOverlay(sheet, rig, sim, bx, y+30, 1)
		text(sheet, x, y+ch+66, 2, "CSS SIZE + SIM WINDOWS", dim)
		if len(p) > 2 {
			text(sheet, pad, y+H/2+22, 2, strings.ToUpper(p[2]), dim)
		}
		y += rowH + pad
	}
	save(out, sheet)
	fmt.Println(out)
}
