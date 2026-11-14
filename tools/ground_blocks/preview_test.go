package main

import (
	"image"
	"image/color"
	"math"
	"os"
	"testing"

	"demonattack/tools/pixelgrid"
)

// GB_DBG=unit[,unit] writes a x4 strip of the unit's directions to GB_OUT.
func TestDbgStrip(t *testing.T) {
	ids := os.Getenv("GB_DBG")
	if ids == "" {
		t.Skip()
	}
	root = findRoot()
	p := loadProject()
	var us []unitRef
	for _, id := range splitComma(ids) {
		us = append(us, p.unit(id))
	}
	w := 0
	for _, u := range us {
		w = max(w, len(p.directions(u))*p.builder(u).CW)
	}
	h := 0
	for _, u := range us {
		h += p.builder(u).CH
	}
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	fill(img, img.Bounds(), color.NRGBA{58, 56, 62, 255})
	y := 0
	for _, u := range us {
		b := p.builder(u)
		for i, d := range p.directions(u) {
			blit(img, p.unitView(u, math.Abs(d), d, d < 0), i*b.CW, y, 1, false)
		}
		y += b.CH
	}
	out := image.NewNRGBA(image.Rect(0, 0, w*4, h*4))
	blit(out, img, 0, 0, 4, false)
	must(pixelgrid.WritePNG(os.Getenv("GB_OUT"), out))
}

func splitComma(s string) []string {
	var out []string
	cur := ""
	for _, c := range s {
		if c == ',' {
			out = append(out, cur)
			cur = ""
		} else {
			cur += string(c)
		}
	}
	return append(out, cur)
}
