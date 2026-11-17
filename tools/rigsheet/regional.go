package main

// carrier-v3 regional edits (plan/render-runs/carrier-v3.md §1): the tour-1
// heroes are kept; only the regions whose clay changed (gates, the thorn
// deck's pores, the keel tip, the gun thorns) are re-painted and composited
// onto the old pick, in the rig frame.
//
//	rigsheet regional OLDRAW OLDCTL NEWCTL INPUT.png MASK.png [GROW]
//	    MASK: where the two controls differ, grown by GROW units (default 6);
//	    INPUT: the old raw at the rig size with the new control inside MASK
//	    (the edit's input: the model repaints the clay to match its surroundings)
//	rigsheet regionmerge OLDRAW EDIT MASK OUT.png
//	    OUT: the old raw at the rig size with EDIT (resized to it) inside MASK,
//	    feathered over 2 units at the mask's edge; everything else byte for byte
//	    the old pick's pixels (resampled to the rig size).

import (
	"fmt"
	"image"
	"image/color"
	"math"
	"strings"
)

func cmdRegional(a []string) {
	oldRaw, oldCtl, newCtl := load(a[0]), load(a[1]), load(a[2])
	W, H := newCtl.Bounds().Dx(), newCtl.Bounds().Dy()
	if oldCtl.Bounds().Dx() != W || oldCtl.Bounds().Dy() != H {
		fail("controls differ in size: %v %v", oldCtl.Bounds(), newCtl.Bounds())
	}
	grow := 6.0
	if len(a) > 5 {
		fmt.Sscan(a[5], &grow)
	}
	ppu := 3.0 // the tour-1 rig density (render.scale x core texel)
	m := make([]bool, W*H)
	n := 0
	for i := 0; i < W*H; i++ {
		d := 0
		for k := 0; k < 3; k++ {
			d += abs(int(oldCtl.Pix[i*4+k]) - int(newCtl.Pix[i*4+k]))
		}
		if d > 30 {
			m[i] = true
			n++
		}
	}
	m = dilateDisc(m, W, H, grow*ppu)
	base := resize(oldRaw, W, H)
	in := image.NewNRGBA(base.Bounds())
	copy(in.Pix, base.Pix)
	mask := image.NewNRGBA(base.Bounds())
	area := 0
	for i := 0; i < W*H; i++ {
		v := uint8(0)
		if m[i] {
			copy(in.Pix[i*4:i*4+4], newCtl.Pix[i*4:i*4+4])
			v = 255
			area++
		}
		mask.Pix[i*4], mask.Pix[i*4+1], mask.Pix[i*4+2], mask.Pix[i*4+3] = v, v, v, 255
	}
	save(a[3], in)
	save(a[4], mask)
	fmt.Printf("regional: %d changed px, mask %.1f %% of the frame\n", n, 100*float64(area)/float64(W*H))
}

func cmdRegionMerge(a []string) {
	mask := load(a[2])
	W, H := mask.Bounds().Dx(), mask.Bounds().Dy()
	base, edit := resize(load(a[0]), W, H), resize(load(a[1]), W, H)
	m := make([]bool, W*H)
	for i := range m {
		m[i] = mask.Pix[i*4] >= 128
	}
	// feather: weight 1 inside, falling to 0 over f px outside the mask
	notM := make([]bool, W*H)
	for i := range notM {
		notM[i] = !m[i]
	}
	dIn := edt(m, W, H) // squared px to the mask
	f := 6.0
	out := image.NewNRGBA(base.Bounds())
	for i := 0; i < W*H; i++ {
		wt := 0.0
		if m[i] {
			wt = 1
		} else if d := math.Sqrt(dIn[i]); d < f {
			wt = 1 - d/f
		}
		b, e := base.Pix[i*4:i*4+4], edit.Pix[i*4:i*4+4]
		c := color.NRGBA{}
		c.R = uint8(float64(b[0])*(1-wt) + float64(e[0])*wt + .5)
		c.G = uint8(float64(b[1])*(1-wt) + float64(e[1])*wt + .5)
		c.B = uint8(float64(b[2])*(1-wt) + float64(e[2])*wt + .5)
		c.A = 255
		out.SetNRGBA(i%W, i/W, c)
	}
	_ = notM
	save(a[3], out)
}

// deckshade RAW RIG HULL OUT.png: a raw at the rig size with the highlights of the
// prow and the deck-bay leaves compressed (above luminance 56, × 0.35): the AI's
// gloss on the deck dome quantised to pale bone as two symmetric blobs (eyes) on the
// tour-1 thorn, and the bay leaves as two pale squares on the lattice. The runtime
// dome shade stays as the guard; this fixes it in the art.
func cmdDeckShade(a []string) {
	r := readRig(a[1], a[2])
	raw := placeRaw(load(a[0]), r)
	ids := load(r.path("S0", "id", tag(45, 0)))
	var want []color.NRGBA
	for id, h := range r.IDs {
		if id == "prow" || strings.HasPrefix(id, "gate_bay") {
			want = append(want, hex(h))
		}
	}
	W, H := raw.Bounds().Dx(), raw.Bounds().Dy()
	n := 0
	for i := 0; i < W*H; i++ {
		c := ids.Pix[i*4 : i*4+4]
		hit := false
		for _, w := range want {
			if abs(int(c[0])-int(w.R)) < 6 && abs(int(c[1])-int(w.G)) < 6 && abs(int(c[2])-int(w.B)) < 6 {
				hit = true
				break
			}
		}
		if !hit {
			continue
		}
		p := raw.Pix[i*4 : i*4+3]
		l := .3*float64(p[0]) + .59*float64(p[1]) + .11*float64(p[2])
		if l <= 56 {
			continue
		}
		f := (56 + (l-56)*.35) / l
		for k := 0; k < 3; k++ {
			p[k] = uint8(float64(p[k]) * f)
		}
		n++
	}
	save(a[3], raw)
	fmt.Printf("deckshade: %d texels compressed\n", n)
}
