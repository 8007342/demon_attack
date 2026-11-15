package main

// atlasframe: today's single-view boss frame of a hull (superstructure form 0
// behind the bow idle frame 0), composited from assets/images/boss-<hull>.png
// with the rects of lib/game/boss_atlas.dart, at the atlas's 2 px per unit.
// It is the identity reference (image 2) of the hero edits.

import (
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type sprite struct {
	x, y, w, h int
	dx, dy     float64
}

func parseSprite(s string) sprite {
	m := regexp.MustCompile(`BossSprite\(([^)]*)\)`).FindStringSubmatch(s)
	f := strings.Split(m[1], ",")
	n := func(i int) float64 { v, _ := strconv.ParseFloat(strings.TrimSpace(f[i]), 64); return v }
	return sprite{int(n(0)), int(n(1)), int(n(2)), int(n(3)), n(4), n(5)}
}

func cmdAtlasFrame(a []string) {
	hull, out := a[0], a[1]
	root := repoRoot()
	src, err := os.ReadFile(filepath.Join(root, "lib/game/boss_atlas.dart"))
	if err != nil {
		fail("%v", err)
	}
	s := string(src)
	i := strings.Index(s, "key: '"+hull+"'")
	if i < 0 {
		fail("no hull %s", hull)
	}
	s = s[i:]
	if j := strings.Index(s[1:], "BossHull("); j > 0 {
		s = s[:j]
	}
	line := func(key string) string {
		k := strings.Index(s, key)
		return s[k : k+strings.Index(s[k:], "\n")]
	}
	sup := parseSprite(line("superstructure:"))
	k := strings.Index(s, "hull: [")
	bow := parseSprite(s[k+8:])
	em := regexp.MustCompile(`extent: \(([^)]*)\)`).FindStringSubmatch(s)
	var ext [4]float64
	for n, v := range strings.Split(em[1], ",") {
		ext[n], _ = strconv.ParseFloat(strings.TrimSpace(v), 64)
	}
	atlas := load(filepath.Join(root, "assets/images/boss-"+hull+".png"))
	w := int(math.Round((ext[2] - ext[0]) * 2))
	h := int(math.Round((ext[3] - ext[1]) * 2))
	dst := image.NewNRGBA(image.Rect(0, 0, w, h))
	for _, sp := range []sprite{sup, bow} {
		sub := atlas.SubImage(image.Rect(sp.x, sp.y, sp.x+sp.w, sp.y+sp.h)).(*image.NRGBA)
		cp := image.NewNRGBA(image.Rect(0, 0, sp.w, sp.h))
		for y := 0; y < sp.h; y++ {
			copy(cp.Pix[y*cp.Stride:y*cp.Stride+sp.w*4], sub.Pix[y*sub.Stride:y*sub.Stride+sp.w*4])
		}
		blit(dst, cp, int(math.Round((sp.dx-ext[0])*2)), int(math.Round((sp.dy-ext[1])*2)), 1)
	}
	// the maw and bay windows are holes in the atlas (the scene draws them);
	// fill them with ink so a key colour never shows through the reference
	sim := readSim()
	inkC := hex("#0A0716")
	win := func(cx, cy, ww, hh float64) {
		for y := int((cy - hh/2 - ext[1]) * 2); y < int((cy+hh/2-ext[1])*2); y++ {
			for x := int((cx - ww/2 - ext[0]) * 2); x < int((cx+ww/2-ext[0])*2); x++ {
				if dst.NRGBAAt(x, y).A < 255 {
					over(dst, x, y, inkC)
				}
			}
		}
	}
	win(sim.coreX, sim.coreY, sim.coreW, sim.coreH)
	win(sim.bayX, sim.bayY, sim.bayW, sim.bayH)
	win(-sim.bayX, sim.bayY, sim.bayW, sim.bayH)
	save(out, dst)
	fmt.Printf("%s %dx%d (extent %v)\n", out, w, h, ext)
}
