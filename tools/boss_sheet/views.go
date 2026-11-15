package main

// B2 tools.
//
//	boss_sheet sym FIT.png RIG HULL OUT.png left|right
//	    mirror one half of a hero fitted to the rig frame onto the other, about the
//	    hull's centre axis (exact at yaw 0): the atlas stores yaw +12 and draws -12
//	    mirrored, so the hero must be symmetric or details swap sides in a swerve.
//	boss_sheet bakefinish BAKE RIG HULL STAGE      finish every baked view (beauty and layers) to fin_*.png
//	boss_sheet views BAKE RIG HULL OUT.png         the B2 view sheet (+ OUT.gif: swerve and glide)
//	boss_sheet stages BAKE RIG HULL OUT.png        the B2 stage sheet S0-S4

import (
	"fmt"
	"image"
	"image/color"
	"image/color/palette"
	"image/draw"
	"image/gif"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func cmdSym(a []string) {
	fit := load(a[0])
	rig := readRig(a[1], a[2])
	ax := rig.Origin[0] // x of the hull's centre axis in render px
	w, h := fit.Bounds().Dx(), fit.Bounds().Dy()
	out := image.NewNRGBA(fit.Bounds())
	copy(out.Pix, fit.Pix)
	left := a[4] == "left"
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			fx := float64(x) + 0.5
			onRight := fx > ax
			if onRight != left { // this pixel is on the kept side
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
	save(a[3], out)
}

func cmdBakeFinish(a []string) {
	bake, rigDir, hull, stage := a[0], a[1], a[2], a[3]
	rig := readRig(rigDir, hull)
	d := filepath.Join(bake, hull, stage)
	if stage == "wrecks" {
		d = filepath.Join(bake, hull)
		ents, _ := os.ReadDir(d)
		for _, e := range ents {
			if strings.HasPrefix(e.Name(), "wreck_") {
				fin, _ := finishLayer(load(filepath.Join(d, e.Name())), rig, rigDir, "S2", "", false)
				save(filepath.Join(d, "fin_"+e.Name()), fin)
			}
		}
		return
	}
	ents, _ := os.ReadDir(d)
	geo := stage
	if stage == "S1" {
		geo = "S0"
	}
	n := 0
	for _, e := range ents {
		nm := e.Name()
		if !(strings.HasPrefix(nm, "beauty_") || strings.HasPrefix(nm, "layer_")) {
			continue
		}
		t := nm[strings.LastIndex(nm, "_p")+1 : len(nm)-4]
		fin, _ := finishLayer(load(filepath.Join(d, nm)), rig, rigDir, geo, t, strings.HasPrefix(nm, "beauty_"))
		save(filepath.Join(d, "fin_"+nm), fin)
		n++
	}
	fmt.Printf("%s %s: %d finished\n", hull, stage, n)
}

// finishLayer: a baked render is already in the rig frame; the beauty is
// masked to its view's clay silhouette (+1 texel), a layer to its own alpha.
func finishLayer(src *image.NRGBA, rig *Rig, rigDir, geo, t string, beauty bool) (*image.NRGBA, *image.NRGBA) {
	if beauty {
		return finishHero(src, rig, rigDir, geo, t, true)
	}
	small := areaScale(src, 0.5)
	pal := familyPalette()
	out := image.NewNRGBA(small.Bounds())
	for i := 0; i < len(small.Pix); i += 4 {
		c := color.NRGBA{small.Pix[i], small.Pix[i+1], small.Pix[i+2], small.Pix[i+3]}
		if c.A < 128 {
			continue
		}
		c.A = 255
		c = nearest(pal, c)
		out.Pix[i], out.Pix[i+1], out.Pix[i+2], out.Pix[i+3] = c.R, c.G, c.B, 255
	}
	return out, nil
}

func finPath(bake, hull, stage, t string) string {
	return filepath.Join(bake, hull, stage, "fin_beauty_"+t+".png")
}

func cmdViews(a []string) {
	bake, rigDir, hull, out := a[0], a[1], a[2], a[3]
	rig := readRig(rigDir, hull)
	sim := readSim()
	nw, nh := rig.Size[0]/2, rig.Size[1]/2
	pad := 12
	cols := 3
	W := pad + cols*(nw+pad) + 20 + 2*(nw+pad)
	H := 50 + 3*(nh+pad+20) + 20
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 12, 3, strings.ToUpper(fmt.Sprintf("%s - %s: HERO %s PROJECTED ONTO THE RIG, FINISHED X1; CYAN = SIM WINDOWS", sheetHead(hull, "VIEWS", "B2"), rig.Title, heroSeed(hull))), ink)
	y0 := 50
	for i, p := range pitches {
		for j, yw := range yaws {
			x := pad + j*(nw+pad)
			y := y0 + i*(nh+pad+20)
			fill(sheet, image.Rect(x, y, x+nw, y+nh), bgPanel)
			blit(sheet, load(finPath(bake, hull, "S0", tag(p, yw))), x, y, 1)
			simOverlay(sheet, rig, sim, x, y, rig.PPU/2)
			text(sheet, x, y+nh+4, 2, fmt.Sprintf("PITCH %d YAW %+d", p, yw), dim)
		}
	}
	// right block: mirror check and layer recomposition at the hero view
	x := pad + cols*(nw+pad) + 20
	y := y0
	m := load(finPath(bake, hull, "S0", tag(45, 12)))
	mir := image.NewNRGBA(m.Bounds())
	for yy := 0; yy < m.Bounds().Dy(); yy++ {
		for xx := 0; xx < m.Bounds().Dx(); xx++ {
			// mirror about the centre axis at atlas density
			ax := rig.Origin[0] / 2
			mx := int(math.Floor(2*ax - (float64(xx) + 0.5)))
			if mx >= 0 && mx < m.Bounds().Dx() {
				mir.SetNRGBA(xx, yy, m.NRGBAAt(mx, yy))
			}
		}
	}
	fill(sheet, image.Rect(x, y, x+nw, y+nh), bgPanel)
	blit(sheet, mir, x, y, 1)
	text(sheet, x, y+nh+4, 2, "YAW +12 MIRRORED (= HOW YAW -12 IS DRAWN)", dim)
	diff := diffPct(mir, load(finPath(bake, hull, "S0", tag(45, -12))))
	text(sheet, x, y+nh+14, 2, fmt.Sprintf("VS RENDERED -12: %.1f%% TEXELS DIFFER", diff), dim)
	// layers recomposed
	t := tag(45, 0)
	comp := image.NewNRGBA(image.Rect(0, 0, nw, nh))
	ents, _ := os.ReadDir(filepath.Join(bake, hull, "S0"))
	var layers []string
	for _, e := range ents {
		if strings.HasPrefix(e.Name(), "fin_layer_") && strings.HasSuffix(e.Name(), t+".png") {
			layers = append(layers, e.Name())
		}
	}
	sort.Strings(layers)
	for _, l := range layers {
		blit(comp, load(filepath.Join(bake, hull, "S0", l)), 0, 0, 1)
	}
	xx := x + nw + pad
	fill(sheet, image.Rect(xx, y, xx+nw, y+nh), bgPanel)
	blit(sheet, comp, xx, y, 1)
	text(sheet, xx, y+nh+4, 2, fmt.Sprintf("%d MODULE LAYERS RECOMPOSED (HERO VIEW)", len(layers)), dim)
	// layers spread out
	y += nh + pad + 20
	lx := x
	for _, l := range layers {
		im := load(filepath.Join(bake, hull, "S0", l))
		b := alphaBounds(im)
		if b.Empty() {
			continue
		}
		sub := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
		draw.Draw(sub, sub.Bounds(), im, b.Min, draw.Src)
		k := math.Min(1, float64(nw)/2/float64(b.Dx()))
		if lx+int(float64(b.Dx())*k) > W-pad {
			lx = x
			y += nh/2 + 24
		}
		fill(sheet, image.Rect(lx, y, lx+int(float64(b.Dx())*k), y+int(float64(b.Dy())*k)), bgPanel)
		blit(sheet, sub, lx, y, k)
		name := strings.TrimSuffix(strings.TrimPrefix(l, "fin_layer_"), "_"+t+".png")
		text(sheet, lx, y+int(float64(b.Dy())*k)+4, 2, strings.ToUpper(name), dim)
		lx += int(float64(b.Dx())*k) + pad
	}
	save(out, sheet)
	writeSwerveGIF(bake, rig, hull, strings.TrimSuffix(out, ".png")+".gif")
	fmt.Println(out)
}

func alphaBounds(im *image.NRGBA) image.Rectangle {
	r := image.Rectangle{}
	b := im.Bounds()
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			if im.NRGBAAt(x, y).A > 0 {
				r = r.Union(image.Rect(x, y, x+1, y+1))
			}
		}
	}
	return r
}

func diffPct(a, b *image.NRGBA) float64 {
	n, d := 0, 0
	for i := 0; i < len(a.Pix) && i < len(b.Pix); i += 4 {
		if a.Pix[i+3] == 0 && b.Pix[i+3] == 0 {
			continue
		}
		n++
		dd := 0
		for k := 0; k < 4; k++ {
			dd += int(math.Abs(float64(a.Pix[i+k]) - float64(b.Pix[i+k])))
		}
		if dd > 48 {
			d++
		}
	}
	return 100 * float64(d) / float64(max(n, 1))
}

// writeSwerveGIF: the boss strafing on a 360 x 300 arena strip at CSS size x2
// (atlas density): x follows a slow sine, yaw from the horizontal velocity
// (+-12 above 40 % of max speed), pitch from the vertical glide (y +-16:
// 38 above, 52 below), as boss-grandeur design 5 selects them. Views only; no
// crossfade.
func writeSwerveGIF(bake string, rig *Rig, hull, out string) {
	views := map[string]*image.NRGBA{}
	get := func(p, yw int) *image.NRGBA {
		t := tag(p, yw)
		if v, ok := views[t]; ok {
			return v
		}
		v := load(finPath(bake, hull, "S0", t))
		views[t] = v
		return v
	}
	k := rig.PPU / 2 // px per unit in the fin images
	W, H := int(360*k), int(300*k)
	g := &gif.GIF{}
	frames := 72
	for f := 0; f < frames; f++ {
		ph := 2 * math.Pi * float64(f) / float64(frames)
		bx := 180 + 70*math.Sin(ph)
		vx := math.Cos(ph)
		gy := 16 * math.Sin(2*ph+0.8)
		by := 150 + gy
		yw := 0
		if vx > 0.4 {
			yw = 12
		} else if vx < -0.4 {
			yw = -12
		}
		p := 45
		if gy < -8 {
			p = 38
		} else if gy > 8 {
			p = 52
		}
		frame := newCanvas(W, H, hex("#0B0F1E"))
		for s := 0; s < 40; s++ { // static star field
			sx := int(math.Mod(float64(s)*97.3, float64(W)))
			sy := int(math.Mod(float64(s)*53.9+float64(f*2), float64(H)))
			over(frame, sx, sy, color.NRGBA{120, 120, 160, 255})
		}
		v := get(p, abs(yw))
		if yw < 0 {
			v = mirrorAbout(v, rig.Origin[0]/2)
		}
		ox := int(math.Round(bx*k - rig.Origin[0]/2))
		oy := int(math.Round(by*k - rig.Origin[1]/2))
		blit(frame, v, ox, oy, 1)
		text(frame, 6, 6, 2, fmt.Sprintf("PITCH %d YAW %+d", p, yw), dim)
		pm := image.NewPaletted(frame.Bounds(), palette.Plan9)
		draw.Draw(pm, pm.Bounds(), frame, image.Point{}, draw.Src)
		g.Image = append(g.Image, pm)
		g.Delay = append(g.Delay, 8)
	}
	f, err := os.Create(out)
	if err != nil {
		fail("%v", err)
	}
	gif.EncodeAll(f, g)
	f.Close()
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func mirrorAbout(m *image.NRGBA, ax float64) *image.NRGBA {
	out := image.NewNRGBA(m.Bounds())
	w := m.Bounds().Dx()
	for y := 0; y < m.Bounds().Dy(); y++ {
		for x := 0; x < w; x++ {
			mx := int(math.Floor(2*ax - (float64(x) + 0.5)))
			if mx >= 0 && mx < w {
				out.SetNRGBA(x, y, m.NRGBAAt(mx, y))
			}
		}
	}
	return out
}

func cmdStages(a []string) {
	bake, rigDir, hull, out := a[0], a[1], a[2], a[3]
	rig := readRig(rigDir, hull)
	nw, nh := rig.Size[0]/2, rig.Size[1]/2
	pad := 12
	W := pad + 3*(nw+pad)
	stages := []string{"S0", "S1", "S2", "S3"}
	H := 50 + (len(stages)+1)*(nh+pad+22) + nh/2
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 12, 3, strings.ToUpper(fmt.Sprintf("%s - %s: S0-S3 PROJECTED, FINISHED X1; S4 = MODULE WRECKS", sheetHead(hull, "STAGES", "B2"), rig.Title)), ink)
	label := map[string]string{"S0": "S0 INTACT (SHIELD CELLS ARE AN OVERLAY)", "S1": "S1 SCORCHED", "S2": "S2 EXPOSED: PLATES OFF, RIBS",
		"S3": "S3 BREAKING: FIRST MODULE (TOWER) GONE"}
	y := 50
	for _, s := range stages {
		for j, yw := range yaws {
			x := pad + j*(nw+pad)
			fill(sheet, image.Rect(x, y, x+nw, y+nh), bgPanel)
			pth := finPath(bake, hull, s, tag(45, yw))
			if _, err := os.Stat(pth); err == nil {
				blit(sheet, load(pth), x, y, 1)
			}
			text(sheet, x, y+nh+4, 2, fmt.Sprintf("%s  PITCH 45 YAW %+d", label[s], yw), dim)
		}
		y += nh + pad + 22
	}
	// S4: wrecks, two tumble frames each
	ents, _ := os.ReadDir(filepath.Join(bake, hull))
	x := pad
	text(sheet, pad, y-14, 2, "S4 COLLAPSE: MODULE WRECKS, REST AND TUMBLED (FROM THE S2 LOOK)", ink)
	y += 6
	for _, e := range ents {
		if !strings.HasPrefix(e.Name(), "fin_wreck_") {
			continue
		}
		im := load(filepath.Join(bake, hull, e.Name()))
		b := alphaBounds(im)
		if b.Empty() {
			continue
		}
		sub := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
		draw.Draw(sub, sub.Bounds(), im, b.Min, draw.Src)
		k := math.Min(1, 0.42*float64(nh)/float64(b.Dy()))
		if x+int(float64(b.Dx())*k) > W-pad {
			x = pad
			y += int(0.42*float64(nh)) + 24
		}
		blit(sheet, sub, x, y, k)
		text(sheet, x, y+int(float64(b.Dy())*k)+4, 2, strings.ToUpper(strings.TrimSuffix(strings.TrimPrefix(e.Name(), "fin_wreck_"), ".png")), dim)
		x += int(float64(b.Dx())*k) + pad
	}
	save(out, sheet)
	fmt.Println(out)
}

// cmdMaskDiff: FIT RIG HULL A B OUT: clear the fit's alpha where the hero-view
// clay of stage A and stage B differ (geometry that left the hull: those
// texels must not project onto what is now visible behind them).
func cmdMaskDiff(a []string) {
	fit := load(a[0])
	t := tag(45, 0)
	ca := load(filepath.Join(a[1], a[2], a[3], "clay_"+t+".png"))
	cb := load(filepath.Join(a[1], a[2], a[4], "clay_"+t+".png"))
	m := make([]bool, len(fit.Pix)/4)
	w, h := fit.Bounds().Dx(), fit.Bounds().Dy()
	for i := range m {
		d := 0
		for k := 0; k < 4; k++ {
			d += int(math.Abs(float64(ca.Pix[i*4+k]) - float64(cb.Pix[i*4+k])))
		}
		m[i] = d > 24
	}
	m = dilate(m, w, h, 2)
	n := 0
	for i, v := range m {
		if v && fit.Pix[i*4+3] > 0 {
			fit.Pix[i*4+3] = 0
			n++
		}
	}
	save(a[5], fit)
	fmt.Printf("%s: %d texels cleared\n", a[5], n)
}

// cmdBakeBudget: RGBA resident of the finished atlas content of one hull,
// measured on the baked layers: per stored view (pitch x yaw {0, +12}; a
// mirrored pair once at yaw 0) each module layer's S0 alpha rect, plus stage
// patches S1, S2, S3: the rect of the module's texels that differ from the
// previous stage's layer (S1 vs S0, S2 vs S0, S3 vs S2), plus the wrecks.
func cmdBakeBudget(a []string) {
	bake, rigDir, hull := a[0], a[1], a[2]
	rig := readRig(rigDir, hull)
	ids := map[string]bool{}
	for _, in := range rig.Insts {
		ids[in.ID] = true
	}
	total, s0Area, patchArea, tileArea, wreckArea := 0.0, 0.0, 0.0, 0.0, 0.0
	rectArea := func(r image.Rectangle) float64 { return float64(r.Dx()+2) * float64(r.Dy()+2) }
	// tiles: 16 x 16 cells of a module rect that differ from the previous stage
	tiles := func(a, b *image.NRGBA) float64 {
		w, h := a.Bounds().Dx(), a.Bounds().Dy()
		n := 0
		for ty := 0; ty < h; ty += 16 {
			for tx := 0; tx < w; tx += 16 {
				hit := false
				for y := ty; y < min(ty+16, h) && !hit; y++ {
					for x := tx; x < min(tx+16, w) && !hit; x++ {
						i := y*a.Stride + x*4
						d := 0
						for k := 0; k < 4; k++ {
							d += int(math.Abs(float64(a.Pix[i+k]) - float64(b.Pix[i+k])))
						}
						hit = d > 48
					}
				}
				if hit {
					n++
				}
			}
		}
		return float64(n * 18 * 18)
	}
	diffRect := func(a, b *image.NRGBA) image.Rectangle {
		r := image.Rectangle{}
		w := a.Bounds().Dx()
		for i := 0; i < len(a.Pix); i += 4 {
			if a.Pix[i+3] == 0 && b.Pix[i+3] == 0 {
				continue
			}
			d := 0
			for k := 0; k < 4; k++ {
				d += int(math.Abs(float64(a.Pix[i+k]) - float64(b.Pix[i+k])))
			}
			if d > 48 {
				x, y := (i/4)%w, (i/4)/w
				r = r.Union(image.Rect(x, y, x+1, y+1))
			}
		}
		return r
	}
	ld := func(stage, id, t string) *image.NRGBA {
		p := filepath.Join(bake, hull, stage, "fin_layer_"+id+"_"+t+".png")
		if _, err := os.Stat(p); err != nil {
			return nil
		}
		return load(p)
	}
	for _, p := range pitches {
		for _, yw := range []int{0, 12} {
			t := tag(p, yw)
			for id := range ids {
				if yw == 0 && strings.HasSuffix(id, "L") && ids[strings.TrimSuffix(id, "L")+"R"] {
					continue
				}
				s0, s1, s2, s3 := ld("S0", id, t), ld("S1", id, t), ld("S2", id, t), ld("S3", id, t)
				if s0 == nil {
					continue
				}
				s0Area += rectArea(alphaBounds(s0))
				if s1 != nil {
					patchArea += rectArea(diffRect(s1, s0))
					tileArea += tiles(s1, s0)
				}
				if s2 != nil {
					patchArea += rectArea(diffRect(s2, s0))
					tileArea += tiles(s2, s0)
				}
				if s3 != nil && s2 != nil {
					patchArea += rectArea(diffRect(s3, s2))
					tileArea += tiles(s3, s2)
				}
			}
		}
	}
	ents, _ := os.ReadDir(filepath.Join(bake, hull))
	for _, e := range ents {
		if strings.HasPrefix(e.Name(), "fin_wreck_") {
			wreckArea += rectArea(alphaBounds(load(filepath.Join(bake, hull, e.Name()))))
		}
	}
	mb := func(a float64) float64 { return a * 4 / (1 << 20) }
	total = s0Area + patchArea + wreckArea
	fmt.Printf("%s: %.2f MB RGBA resident (finished layers, 6 stored views): S0 layers %.2f, stage patch rects %.2f (as 16-px tiles %.2f, at half density %.2f), wrecks %.2f; DECIDED (stage patches at half density) %.2f MB\n",
		hull, mb(total), mb(s0Area), mb(patchArea), mb(tileArea), mb(patchArea/4), mb(wreckArea), mb(s0Area+patchArea/4+wreckArea))
}
