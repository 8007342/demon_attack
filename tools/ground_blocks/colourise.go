package main

// Colourising a master cell for one sector: material ramps (the Host's
// stone follows the sector), the sector kit baked in (Fleet camouflage,
// Host stone kit), then the outline ink on base cells. Binary alpha.

import (
	"image"
	"image/color"
	"math"

	"demonattack/tools/pixelgrid"
)

// kitStep returns the ramp and step of a texel after the sector kit.
func (pal *Palette) kitted(px Px, rampName, sector string, seed int) (string, int) {
	step := int(px.Step)
	m := pal.Mats.List[px.Mat]
	if px.Emis || m.Flat || px.Prim < 0 {
		return rampName, step
	}
	kit := pal.Kit[sector]
	P := px.P
	switch pal.Faction {
	case "fleet":
		if rampName != "ally_hull" {
			return rampName, step
		}
		switch kit {
		case "snow":
			if px.N[2] > .85 {
				step = min(m.Hi, step+1)
			}
		case "patch":
			if pixelgrid.Hash01(seed, int(px.Prim), int(math.Round(px.N[0]*2)), int(math.Round(px.N[1]*2))) < .45 {
				step = max(m.Lo, step-1)
			}
		case "heat":
			if !px.Art && P[2] < 3.2 {
				step = min(step, 1)
			}
		case "teal":
			if math.Abs(P[1]+1) < 1.1 && px.N[2] > .3 {
				if step >= 3 {
					return "ally_cyan", 1
				}
				return "ally_cyan", 0
			}
		}
	case "host":
		if rampName != "stone" {
			return rampName, step
		}
		switch kit {
		case "frost":
			if px.N[2] > .7 && pixelgrid.Hash01(seed, int(P[0]*2), int(P[1]*2), int(P[2]*2)) < .22 {
				step = min(4, step+1)
			}
		case "mortar", "kiln":
			frac := .12
			if kit == "kiln" {
				frac = .07
			}
			d1, d2, h := voronoi3(seed+11, P, 4.2)
			if d2-d1 < .24 && h < frac && px.N[2] < .8 {
				return "demon_warm", 1
			}
		case "damp":
			if P[2] < 2 {
				step = max(0, step-1)
			}
		case "obsidian":
			if step == m.Hi && pixelgrid.Hash01(seed, int(P[0]*3), int(P[1]*3), int(P[2]*3)) < .12 {
				step = 4
			}
		}
	}
	return rampName, step
}

func (pal *Palette) colour(px Px, sector string, seed int) color.NRGBA {
	m := pal.Mats.List[px.Mat]
	rn, step := pal.kitted(px, m.Ramp, sector, seed)
	r := pal.ramp(rn, sector)
	if len(r) == 0 {
		fail(errf("ramp %q missing for %s", rn, pal.Faction))
	}
	return r[max(0, min(len(r)-1, step))]
}

// paintCell draws a cell at (ox, oy) of dst: overlays as they are, base
// cells with the outline ink around the silhouette.
func (pal *Palette) paintCell(dst *image.NRGBA, c *Cell, ox, oy int, sector string, seed int) {
	f := c.F
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			p := f.at(x, y)
			if p.Mat != 0 {
				dst.SetNRGBA(ox+x, oy+y, pal.colour(*p, sector, seed))
				continue
			}
			if c.Overlay {
				continue
			}
			if f.filled(x-1, y) || f.filled(x+1, y) || f.filled(x, y-1) || f.filled(x, y+1) {
				dst.SetNRGBA(ox+x, oy+y, pal.Ink)
			}
		}
	}
}

// blackFill: the silhouette (outline included) in solid black.
func blackFill(dst *image.NRGBA, c *Cell, ox, oy int) {
	f := c.F
	k := color.NRGBA{0, 0, 0, 255}
	for y := 0; y < f.H; y++ {
		for x := 0; x < f.W; x++ {
			if f.filled(x, y) || (!c.Overlay && (f.filled(x-1, y) || f.filled(x+1, y) || f.filled(x, y-1) || f.filled(x, y+1))) {
				dst.SetNRGBA(ox+x, oy+y, k)
			}
		}
	}
}
