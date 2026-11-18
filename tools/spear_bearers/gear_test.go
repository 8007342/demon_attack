package main

import (
	"image/color"
	"math"
	"testing"
)

// The levelled spear's head ends at the model's release point
// (SpearTuning.releaseDx, releaseDy = 7, 16 units; 1.6 art px a unit).
func TestReleasePointMatchesModel(t *testing.T) {
	x, y := 32+7*artPerUnit, 32+16*artPerUnit
	if math.Hypot(levelTip.x-x, levelTip.y-y) > 2 {
		t.Fatalf("levelled tip %v, model release (%.1f, %.1f)", levelTip, x, y)
	}
}

// No cyan (force shields) and no blackbody heat colours (dive shields) in
// any gear pixel (alien-troops §3, §9).
func TestPaletteKeepsItsChannels(t *testing.T) {
	img := renderAtlas(pickHead, pickEmblem)
	b := img.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			p := img.NRGBAAt(x, y)
			if p.A == 0 {
				continue
			}
			if isCyan(p) || isHeat(p) {
				t.Fatalf("pixel %d,%d %v uses a reserved channel", x, y, p)
			}
		}
	}
}

func isCyan(p color.NRGBA) bool {
	return int(p.B) > int(p.R)+60 && int(p.G) > int(p.R)+60
}

func isHeat(p color.NRGBA) bool {
	return int(p.R) > 200 && int(p.R) > int(p.B)+90 && p.G < 200
}

// The emblem is not mirror-symmetric (a face or heart magnet, §4.1 rule
// 2): most of its rows are lopsided about the emblem's own centre line.
func TestEmblemIsAsymmetric(t *testing.T) {
	l := newLayer(32, 32)
	l.emblem(pt{16, 16}, 9, pickEmblem)
	minX, maxX := 32, -1
	for y := 0; y < 32; y++ {
		for x := 0; x < 32; x++ {
			if l.at(x, y).A != 0 {
				minX, maxX = min(minX, x), max(maxX, x)
			}
		}
	}
	rows, lopsided := 0, 0
	for y := 0; y < 32; y++ {
		any, sym := false, true
		for x := minX; x <= maxX; x++ {
			on := l.at(x, y).A != 0
			any = any || on
			if on != (l.at(minX+maxX-x, y).A != 0) {
				sym = false
			}
		}
		if any {
			rows++
			if !sym {
				lopsided++
			}
		}
	}
	if rows == 0 || lopsided*2 <= rows {
		t.Fatalf("emblem: %d of %d rows lopsided", lopsided, rows)
	}
}

// Every head ends in a point: one pixel wide within 2 px of the tip.
func TestHeadsArePointed(t *testing.T) {
	for h := range headNames {
		l := projectileLayer(0, Head(h))
		w := 0
		for x := 0; x < projW; x++ {
			if c := l.at(x, projTipY-1); c.A != 0 && c != ink {
				w++
			}
		}
		if w > 2 {
			t.Fatalf("head %s is %d px wide at its tip", headNames[h], w)
		}
	}
}
