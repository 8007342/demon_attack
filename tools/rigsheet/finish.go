package main

// Finish: AI raws and baked renders to the atlas grid (colour-preserving; the
// ground-forces A1 and boss B1 recipe, generalised):
//  1. a raw is resized to the rig frame (the AI keeps the control's framing);
//  2. alpha = the rig silhouette dilated by one finished texel, minus key pixels
//     (the rig owns the silhouette);
//  3. green despill, area downscale to the texel density of the layer's class;
//  4. quantise to the family palette (overlay-only ramps excluded), ink outline.

import (
	"image"
	"image/color"
	"math"
)

func resize(src *image.NRGBA, w, h int) *image.NRGBA {
	sw, sh := src.Bounds().Dx(), src.Bounds().Dy()
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		fy := (float64(y)+0.5)*float64(sh)/float64(h) - 0.5
		y0 := int(math.Floor(fy))
		ty := fy - float64(y0)
		for x := 0; x < w; x++ {
			fx := (float64(x)+0.5)*float64(sw)/float64(w) - 0.5
			x0 := int(math.Floor(fx))
			tx := fx - float64(x0)
			var acc [4]float64
			for _, s := range [][3]float64{{0, 0, (1 - tx) * (1 - ty)}, {1, 0, tx * (1 - ty)}, {0, 1, (1 - tx) * ty}, {1, 1, tx * ty}} {
				xx := min(max(x0+int(s[0]), 0), sw-1)
				yy := min(max(y0+int(s[1]), 0), sh-1)
				c := src.NRGBAAt(xx, yy)
				acc[0] += float64(c.R) * s[2]
				acc[1] += float64(c.G) * s[2]
				acc[2] += float64(c.B) * s[2]
				acc[3] += float64(c.A) * s[2]
			}
			out.SetNRGBA(x, y, color.NRGBA{uint8(acc[0] + .5), uint8(acc[1] + .5), uint8(acc[2] + .5), uint8(acc[3] + .5)})
		}
	}
	return out
}

func isKey(c color.NRGBA) bool {
	return int(c.G) > int(c.R)+60 && int(c.G) > int(c.B)+60
}

func dilate(m []bool, w, h, r int) []bool {
	out := make([]bool, len(m))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if !m[y*w+x] {
				continue
			}
			for dy := -r; dy <= r; dy++ {
				for dx := -r; dx <= r; dx++ {
					xx, yy := x+dx, y+dy
					if xx >= 0 && yy >= 0 && xx < w && yy < h {
						out[yy*w+xx] = true
					}
				}
			}
		}
	}
	return out
}

func nearest(pal []color.NRGBA, c color.NRGBA) color.NRGBA {
	best, bd := pal[0], math.MaxFloat64
	for _, p := range pal {
		dr, dg, db := float64(c.R)-float64(p.R), float64(c.G)-float64(p.G), float64(c.B)-float64(p.B)
		rm := (float64(c.R) + float64(p.R)) / 2
		d := (2+rm/256)*dr*dr + 4*dg*dg + (2+(255-rm)/256)*db*db
		if d < bd {
			bd, best = d, p
		}
	}
	return color.NRGBA{best.R, best.G, best.B, c.A}
}

// registerBBox maps a raw (already at the rig size) so the bounding box of its non-key
// pixels lands on the clay silhouette's box (independent x and y scale and offset). For
// edits that drift off the control's framing (a small subject the model re-centres or
// stretches); a raw that keeps the framing comes back nearly unchanged.
func registerBBox(fit, clay *image.NRGBA) *image.NRGBA {
	W, H := fit.Bounds().Dx(), fit.Bounds().Dy()
	box := func(in func(x, y int) bool) (float64, float64, float64, float64) {
		x0, y0, x1, y1 := W, H, -1, -1
		for y := 0; y < H; y++ {
			for x := 0; x < W; x++ {
				if in(x, y) {
					x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
				}
			}
		}
		return float64(x0), float64(y0), float64(x1 + 1), float64(y1 + 1)
	}
	// raw subject: neither key nor near-key, with a little margin against noise in the key
	rx0, ry0, rx1, ry1 := box(func(x, y int) bool {
		c := fit.NRGBAAt(x, y)
		return !(int(c.G) > int(c.R)+30 && int(c.G) > int(c.B)+30)
	})
	cx0, cy0, cx1, cy1 := box(func(x, y int) bool { return clay.Pix[(y*W+x)*4+3] >= 128 })
	if rx1 <= rx0 || cx1 <= cx0 {
		return fit
	}
	sx, sy := (rx1-rx0)/(cx1-cx0), (ry1-ry0)/(cy1-cy0)
	out := image.NewNRGBA(fit.Bounds())
	for y := 0; y < H; y++ {
		fy := ry0 + (float64(y)+0.5-cy0)*sy
		for x := 0; x < W; x++ {
			fx := rx0 + (float64(x)+0.5-cx0)*sx
			xx, yy := int(math.Floor(fx)), int(math.Floor(fy))
			if xx < 0 || yy < 0 || xx >= W || yy >= H {
				out.SetNRGBA(x, y, keyCol)
				continue
			}
			out.SetNRGBA(x, y, fit.NRGBAAt(xx, yy))
		}
	}
	return out
}

// fitRaw: the raw resized to the rig frame, masked to the stage's silhouette (+1 texel),
// key removed and despilled. Render resolution.
func fitRaw(raw *image.NRGBA, r *Rig, stage, t string) *image.NRGBA {
	return fitRawOpt(raw, r, stage, t, false)
}

// fitRawOpt: fitRaw, optionally registered to the clay silhouette box first (registerBBox).
func fitRawOpt(raw *image.NRGBA, r *Rig, stage, t string, register bool) *image.NRGBA {
	W, H := r.Size[0], r.Size[1]
	fit := resize(raw, W, H)
	clay := load(r.path(stage, "clay", t))
	if register {
		fit = registerBBox(fit, clay)
	}
	sil := make([]bool, W*H)
	for i := range sil {
		sil[i] = clay.Pix[i*4+3] >= 128
	}
	sil = dilate(sil, W, H, int(math.Ceil(r.RenderScale)))
	for i := 0; i < W*H; i++ {
		c := fit.NRGBAAt(i%W, i/W)
		if !sil[i] || isKey(c) {
			fit.Pix[i*4+3] = 0
			continue
		}
		if m := max(c.R, c.B); c.G > m {
			fit.Pix[i*4+1] = m + (c.G-m)/4
		}
		fit.Pix[i*4+3] = 255
	}
	return fit
}

// finishAt: a render-resolution image (alpha = coverage) downscaled to texel px per unit,
// quantised to the palette (nil = keep colours) and inked on its silhouette edge.
func finishAt(src *image.NRGBA, r *Rig, texel float64, pal []color.NRGBA, ink bool) *image.NRGBA {
	small := src
	if k := texel / r.PPU; k < 0.999 {
		small = areaScale(src, k)
	}
	sw, sh := small.Bounds().Dx(), small.Bounds().Dy()
	out := image.NewNRGBA(small.Bounds())
	for i := 0; i < len(small.Pix); i += 4 {
		c := color.NRGBA{small.Pix[i], small.Pix[i+1], small.Pix[i+2], small.Pix[i+3]}
		if c.A < 128 {
			continue
		}
		c.A = 255
		if pal != nil {
			c = nearest(pal, c)
		}
		out.Pix[i], out.Pix[i+1], out.Pix[i+2], out.Pix[i+3] = c.R, c.G, c.B, 255
	}
	if !ink {
		return out
	}
	inkC := hex("#07050C")
	edge := image.NewNRGBA(out.Bounds())
	copy(edge.Pix, out.Pix)
	for y := 0; y < sh; y++ {
		for x := 0; x < sw; x++ {
			if out.Pix[(y*sw+x)*4+3] == 0 {
				continue
			}
			for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
				xx, yy := x+d[0], y+d[1]
				if xx < 0 || yy < 0 || xx >= sw || yy >= sh || out.Pix[(yy*sw+xx)*4+3] == 0 {
					edge.SetNRGBA(x, y, inkC)
					break
				}
			}
		}
	}
	return edge
}

// symmetrise mirrors one half of an image in the rig frame about the hull's centre axis.
func symmetrise(fit *image.NRGBA, r *Rig, keepLeft bool) *image.NRGBA {
	ax := r.Origin[0]
	w, h := fit.Bounds().Dx(), fit.Bounds().Dy()
	out := image.NewNRGBA(fit.Bounds())
	copy(out.Pix, fit.Pix)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			fx := float64(x) + 0.5
			if (fx > ax) != keepLeft {
				continue
			}
			mx := int(math.Floor(2*ax - fx))
			if mx < 0 || mx >= w {
				out.SetNRGBA(x, y, color.NRGBA{})
				continue
			}
			out.SetNRGBA(x, y, fit.NRGBAAt(mx, y))
		}
	}
	return out
}

// maskDiff clears texels of a fitted image where the clay of stage b differs from stage a
// (geometry that left), so the bake fills them from the geometry instead of painting ghosts.
func maskDiff(fit *image.NRGBA, r *Rig, a, b, t string) (*image.NRGBA, int) {
	ca, cb := load(r.path(a, "clay", t)), load(r.path(b, "clay", t))
	n := 0
	for i := 0; i < len(fit.Pix); i += 4 {
		d := 0
		for k := 0; k < 4; k++ {
			d += abs(int(ca.Pix[i+k]) - int(cb.Pix[i+k]))
		}
		if d > 24 && fit.Pix[i+3] > 0 {
			fit.Pix[i+3] = 0
			n++
		}
	}
	return fit, n
}
