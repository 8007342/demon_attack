package main

// CP0 review sheet (task 2.7): art/contact/ground-rig-turntables.png.
// One band per unit: rig shading at every direction (authored and
// mirrored) at 2x, black fills at 1x and at the far scale 0.62x, and the
// hero heading at 3x; then a turret x hull seating grid per articulated
// unit (5 hull headings x 9 layer angles at 1x).

import (
	"fmt"
	"image"
	"image/color"
	"math"
	"path/filepath"
	"strings"

	"demonattack/tools/pixelgrid"
)

var font3x5 = map[rune]string{
	'A': "010101111101101", 'B': "110101110101110", 'C': "011100100100011", 'D': "110101101101110",
	'E': "111100110100111", 'F': "111100110100100", 'G': "011100101101011", 'H': "101101111101101",
	'I': "111010010010111", 'J': "001001001101010", 'K': "101101110101101", 'L': "100100100100111",
	'M': "101111111101101", 'N': "110101101101101", 'O': "010101101101010", 'P': "110101110100100",
	'Q': "010101101110011", 'R': "110101110101101", 'S': "011100010001110", 'T': "111010010010010",
	'U': "101101101101111", 'V': "101101101101010", 'W': "101101111111101", 'X': "101101010101101",
	'Y': "101101010010010", 'Z': "111001010100111", '0': "111101101101111", '1': "010110010010111",
	'2': "110001010100111", '3': "110001010001110", '4': "101101111001001", '5': "111100110001110",
	'6': "011100111101111", '7': "111001010010010", '8': "111101111101111", '9': "111101111001110",
	'-': "000000111000000", '.': "000000000000010", ':': "000010000010000", '/': "001001010100100",
	' ': "000000000000000", '(': "010100100100010", ')': "010001001001010", '+': "000010111010000",
}

func text(dst *image.NRGBA, x, y, scale int, s string, col color.NRGBA) {
	for _, ch := range strings.ToUpper(s) {
		g, ok := font3x5[ch]
		if !ok {
			g = font3x5[' ']
		}
		for i := 0; i < 15; i++ {
			if g[i] == '1' {
				for dy := 0; dy < scale; dy++ {
					for dx := 0; dx < scale; dx++ {
						dst.SetNRGBA(x+(i%3)*scale+dx, y+(i/3)*scale+dy, col)
					}
				}
			}
		}
		x += 4 * scale
	}
}

func fill(dst *image.NRGBA, r image.Rectangle, c color.NRGBA) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			dst.SetNRGBA(x, y, c)
		}
	}
}

// blit draws src scaled by k (nearest; k < 1 samples) at (x, y), mirrored
// horizontally if asked; transparent texels are skipped.
func blit(dst *image.NRGBA, src *image.NRGBA, x, y int, k float64, mirror bool) {
	w, h := src.Bounds().Dx(), src.Bounds().Dy()
	ow, oh := int(math.Round(float64(w)*k)), int(math.Round(float64(h)*k))
	for oy := 0; oy < oh; oy++ {
		for ox := 0; ox < ow; ox++ {
			sx, sy := int(float64(ox)/k), int(float64(oy)/k)
			if mirror {
				sx = w - 1 - sx
			}
			c := src.NRGBAAt(min(sx, w-1), min(sy, h-1))
			if c.A != 0 {
				dst.SetNRGBA(x+ox, y+oy, c)
			}
		}
	}
}

func toBlack(src *image.NRGBA) *image.NRGBA {
	out := image.NewNRGBA(src.Bounds())
	for i := 0; i < len(src.Pix); i += 4 {
		if src.Pix[i+3] != 0 {
			out.Pix[i+3] = 255
		}
	}
	return out
}

// unitView: the hull at authored heading h with its layer aimed at angle
// a (mirrored when a < 0), as an image.
func (p *Project) unitView(u unitRef, h, a float64, mirror bool) *image.NRGBA {
	b := p.builder(u)
	pal := p.Pals[u.faction()]
	sec := p.masterSector(u)
	img := image.NewNRGBA(image.Rect(0, 0, b.CW, b.CH))
	hull := &Cell{F: b.move(h, 0)}
	if b.Rig.Block == "I" {
		hull.F = b.move(h, 0)
	}
	pal.paintCell(img, hull, 0, 0, sec, b.Rig.Seed)
	if b.Rig.Art != nil {
		ao := defaultOpt("art")
		ao.Aim = math.Abs(a)
		art := image.NewNRGBA(image.Rect(0, 0, b.CW, b.CH))
		pal.paintCell(art, &Cell{F: b.art(ao)}, 0, 0, sec, b.Rig.Seed)
		dx, du := b.pivot(h)
		// a mirrored layer on an unmirrored hull: mirror the art cell about
		// its pivot (the pivot x is the cell centre)
		ox := int(math.Round(b.Ox + dx - b.AOx))
		oy := int(math.Round(b.Ou - du - b.AOu))
		blit(img, art, ox, oy, 1, a < 0)
	}
	if mirror {
		m := image.NewNRGBA(img.Bounds())
		blit(m, img, 0, 0, 1, true)
		return m
	}
	return img
}

func (p *Project) directions(u unitRef) []float64 {
	hs := p.builder(u).Headings
	var out []float64
	for i := len(hs) - 1; i >= 0; i-- {
		if hs[i] != 0 && hs[i] != 180 {
			out = append(out, -hs[i])
		}
	}
	for _, h := range hs {
		out = append(out, h)
	}
	if hs[len(hs)-1] == 180 { // Host: order -90 … -157.5, 180 … 90
		out = out[:0]
		for _, h := range hs {
			if h != 180 {
				out = append(out, -h)
			}
		}
		for i := len(hs) - 1; i >= 0; i-- {
			out = append(out, hs[i])
		}
	}
	return out
}

func cmdContact() {
	p := loadProject()
	p.buildAll()
	img := p.contactSheet()
	must(pixelgrid.WritePNG(filepath.Join(root, "art/contact/ground-rig-turntables.png"), img))
	fmt.Println("contact", img.Bounds().Dx(), "x", img.Bounds().Dy())
}

func (p *Project) contactSheet() *image.NRGBA {
	const W = 1720
	bgDark := color.NRGBA{40, 38, 46, 255}
	bgLight := color.NRGBA{196, 196, 192, 255}
	ink := color.NRGBA{230, 226, 214, 255}
	dim := color.NRGBA{140, 136, 128, 255}
	type band struct {
		u unitRef
		h int
	}
	var bands []band
	total := 40
	for _, u := range p.units() {
		b := p.builder(u)
		bh := 3*b.CH + 14
		if b.Rig.Block == "K" {
			bh = 2*b.CH + 14
		}
		bands = append(bands, band{u, bh})
		total += bh
	}
	var seat []unitRef
	for _, u := range p.units() {
		if p.builder(u).Rig.Art != nil {
			seat = append(seat, u)
		}
	}
	seatRows := (len(seat) + 2) / 3
	total += 30 + seatRows*(5*40+26)
	img := image.NewNRGBA(image.Rect(0, 0, W, total))
	fill(img, img.Bounds(), color.NRGBA{24, 22, 28, 255})
	text(img, 12, 10, 3, "CP0 GROUND RIG TURNTABLES - RIG SHADING X2 / BLACK FILL X1 AND X0.62 / HERO X3", ink)
	y := 40
	for _, bd := range bands {
		u, b := bd.u, p.builder(bd.u)
		fill(img, image.Rect(0, y, W, y+bd.h-4), color.NRGBA{30, 28, 34, 255})
		text(img, 8, y+6, 2, u.Spec.ID, ink)
		text(img, 8, y+22, 1, fmt.Sprintf("%s %s %s", u.faction(), b.Rig.Block, b.Rig.Class), dim)
		if b.Rig.Threat {
			text(img, 8, y+30, 1, "THREAT VEHICLE", color.NRGBA{230, 150, 90, 255})
		}
		dirs := p.directions(u)
		k := 2.0
		if b.Rig.Block == "K" {
			k = 1.5
		}
		x := 150
		cw, ch := int(float64(b.CW)*k), int(float64(b.CH)*k)
		views := make([]*image.NRGBA, len(dirs))
		for i, d := range dirs {
			views[i] = p.unitView(u, math.Abs(d), d, d < 0)
			fill(img, image.Rect(x+i*cw, y+4, x+(i+1)*cw-1, y+4+ch), bgDark)
			blit(img, views[i], x+i*cw, y+4, k, false)
			text(img, x+i*cw+2, y+6+ch, 1, f1(d), dim)
		}
		x += 9*cw + 12
		for i := range dirs {
			fill(img, image.Rect(x+i*b.CW, y+4, x+(i+1)*b.CW-1, y+4+b.CH), bgLight)
			blit(img, toBlack(views[i]), x+i*b.CW, y+4, 1, false)
			sw := int(math.Round(float64(b.CW) * .62))
			sh := int(math.Round(float64(b.CH) * .62))
			fill(img, image.Rect(x+i*b.CW, y+8+b.CH, x+i*b.CW+sw, y+8+b.CH+sh), bgLight)
			blit(img, toBlack(views[i]), x+i*b.CW, y+8+b.CH, .62, false)
		}
		x += 9*b.CW + 12
		hk := 3.0
		if b.Rig.Block == "K" {
			hk = 2
		}
		hero := p.unitView(u, u.Spec.Hero.Heading, u.Spec.Hero.Heading, false)
		fill(img, image.Rect(x, y+4, x+int(float64(b.CW)*hk), y+4+int(float64(b.CH)*hk)), bgDark)
		blit(img, hero, x, y+4, hk, false)
		y += bd.h
	}
	y += 6
	text(img, 12, y, 2, "TURRET X HULL SEATING: ROWS = HULL HEADINGS, COLUMNS = LAYER ANGLES (MIRRORED LEFT)", ink)
	y += 24
	for i, u := range seat {
		b := p.builder(u)
		col, row := i%3, i/3
		x0, y0 := 8+col*(9*48+138), y+row*(5*40+26)
		text(img, x0, y0, 1, u.Spec.ID, ink)
		var angs []float64
		for j := len(b.Angles) - 1; j >= 0; j-- {
			if b.Angles[j] != 0 && b.Angles[j] != 180 {
				angs = append(angs, -b.Angles[j])
			}
		}
		angs = append(angs, b.Angles...)
		for hi, h := range b.Headings {
			for ai, a := range angs {
				cx, cy := x0+ai*b.CW, y0+10+hi*b.CH
				shade := bgDark
				if (hi+ai)%2 == 1 {
					shade = color.NRGBA{48, 46, 54, 255}
				}
				fill(img, image.Rect(cx, cy, cx+b.CW, cy+b.CH), shade)
				blit(img, p.unitView(u, h, a, false), cx, cy, 1, false)
			}
		}
	}
	return img
}
