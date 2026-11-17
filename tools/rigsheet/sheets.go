package main

// Review sheets of finished bakes: views (+ swerve GIF), stages, sets, the
// phone-scale in-context mock and the tour lineup.

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/color/palette"
	"image/draw"
	"image/gif"
	"math"
	"os"
	"path/filepath"
	"strings"
)

func finBeauty(bake string, r *Rig, stage, t string) *image.NRGBA {
	p := filepath.Join(bake, r.Hull, stage, "fin_beauty_"+t+".png")
	if !mustStat(p) {
		return nil
	}
	return load(p)
}

// beautyAt returns the finished beauty of a view, yaw < 0 drawn as the mirror of +yaw
// about the hull's centre axis (what the runtime does), and its density.
func beautyAt(bake string, r *Rig, stage string, p, yw int) *image.NRGBA {
	ay := yw
	if ay < 0 {
		ay = -ay
	}
	if p != 45 && !mustStat(filepath.Join(bake, r.Hull, stage, "fin_beauty_"+tag(p, ay)+".png")) {
		p = 45 // not stored (the v2 budget): the runtime draws the middle pitch
	}
	if yw < 0 {
		im := finBeauty(bake, r, stage, tag(p, -yw))
		if im == nil {
			return nil
		}
		return mirrorAbout(im, -r.Frame[0]*r.maxTexel())
	}
	return finBeauty(bake, r, stage, tag(p, yw))
}

func mirrorAbout(m *image.NRGBA, ax float64) *image.NRGBA {
	w, h := m.Bounds().Dx(), m.Bounds().Dy()
	out := image.NewNRGBA(m.Bounds())
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			mx := int(math.Floor(2*ax - (float64(x) + 0.5)))
			if mx >= 0 && mx < w {
				out.SetNRGBA(x, y, m.NRGBAAt(mx, y))
			}
		}
	}
	return out
}

func cmdViews(a []string) {
	bake, rigDir, hull, out := a[0], a[1], a[2], a[3]
	r := readRig(rigDir, hull)
	k := 0.62
	fw, fh := r.Frame[2]-r.Frame[0], r.Frame[3]-r.Frame[1]
	cw, ch := int(fw*k), int(fh*k)
	pad := 12
	W := pad + 3*(cw+pad)
	H := 50 + 3*(ch+pad+18) + 20
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 14, 3, fmt.Sprintf("%s - FINISHED VIEW SET S0 (YAW -12 = MIRRORED +12), %.2f PX PER UNIT, CYAN = SIM WINDOWS", strings.ToUpper(r.Title), k), ink)
	for i, p := range []int{38, 45, 52} {
		for j, yw := range []int{-12, 0, 12} {
			x := pad + j*(cw+pad)
			y := 50 + i*(ch+pad+18)
			fill(sheet, image.Rect(x, y, x+cw, y+ch), hex("#2B3A55"))
			im := beautyAt(bake, r, "S0", p, yw)
			if im != nil {
				blit(sheet, im, x, y, k/r.maxTexel())
			}
			overlay(sheet, r, x, y, k)
			lbl := fmt.Sprintf("PITCH %d YAW %+d", p, yw)
			if p != 45 && yw != 0 && !mustStat(filepath.Join(bake, r.Hull, "S0", "fin_beauty_"+tag(p, 12)+".png")) {
				lbl += "  (NOT STORED: DRAWS PITCH 45)"
			}
			text(sheet, x, y+ch+4, 2, lbl, dim)
		}
	}
	save(out, sheet)
	// mirror check: rendered -12 at the hero pitch vs the mirrored +12
	if rend := finBeauty(bake, r, "S0", tag(45, -12)); rend != nil {
		mir := beautyAt(bake, r, "S0", 45, -12)
		diff, n := 0, 0
		for i := 3; i < len(rend.Pix); i += 4 {
			if rend.Pix[i] == 0 && mir.Pix[i] == 0 {
				continue
			}
			n++
			d := abs(int(rend.Pix[i-3])-int(mir.Pix[i-3])) + abs(int(rend.Pix[i-2])-int(mir.Pix[i-2])) + abs(int(rend.Pix[i-1])-int(mir.Pix[i-1])) + abs(int(rend.Pix[i])-int(mir.Pix[i]))
			if d > 60 {
				diff++
			}
		}
		fmt.Printf("mirror check: %.1f %% of texels differ (rendered -12 vs mirrored +12)\n", 100*float64(diff)/float64(max(1, n)))
	}
	swerveGIF(bake, r, strings.TrimSuffix(out, ".png")+".gif")
	fmt.Println(out)
}

// swerveGIF: 48 frames of the strafe, yaw from the horizontal velocity and pitch from the glide.
func swerveGIF(bake string, r *Rig, out string) {
	k := 0.5
	fw, fh := r.Frame[2]-r.Frame[0], r.Frame[3]-r.Frame[1]
	w, h := int(fw*k)+40, int(fh*k)+20
	cache := map[string]*image.NRGBA{}
	get := func(p, yw int) *image.NRGBA {
		key := tag(p, yw)
		if im, ok := cache[key]; ok {
			return im
		}
		im := beautyAt(bake, r, "S0", p, yw)
		if im != nil {
			im = areaScale(im, k/r.maxTexel())
		}
		cache[key] = im
		return im
	}
	g := &gif.GIF{}
	for f := 0; f < 48; f++ {
		ph := 2 * math.Pi * float64(f) / 48
		vx := math.Cos(ph)
		gl := math.Sin(2 * ph)
		yw := 0
		if vx > 0.4 {
			yw = 12
		} else if vx < -0.4 {
			yw = -12
		}
		p := 45
		if gl > 0.5 {
			p = 38
		} else if gl < -0.5 {
			p = 52
		}
		fr := newCanvas(w, h, hex("#2B3A55"))
		if im := get(p, yw); im != nil {
			blit(fr, im, 20+int(10*math.Sin(ph)), 10+int(6*gl), 1)
		}
		text(fr, 6, h-14, 2, fmt.Sprintf("P%d Y%+d", p, yw), ink)
		pm := image.NewPaletted(fr.Bounds(), palette.Plan9)
		draw.FloydSteinberg.Draw(pm, fr.Bounds(), fr, image.Point{})
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

func cmdStages(a []string) {
	bake, rigDir, hull, out := a[0], a[1], a[2], a[3]
	r := readRig(rigDir, hull)
	k := 0.62
	fw, fh := r.Frame[2]-r.Frame[0], r.Frame[3]-r.Frame[1]
	cw, ch := int(fw*k), int(fh*k)
	pad := 12
	names := map[string]string{"S0": "S0 SHIELDED (INTACT)", "S1": "S1 SHIELD FAILING", "S2": "S2 ARMOUR SHED", "S3": "S3 MODULE LOSS"}
	W := pad + 3*(cw+pad)
	H := 50 + 4*(ch+pad+18) + 420
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 14, 3, strings.ToUpper(r.Title)+" - DAMAGE AND DECAY STAGES AT PITCH 45, YAW -12 / 0 / +12; S4 WRECKS", ink)
	for i, s := range []string{"S0", "S1", "S2", "S3"} {
		for j, yw := range []int{-12, 0, 12} {
			x := pad + j*(cw+pad)
			y := 50 + i*(ch+pad+18)
			fill(sheet, image.Rect(x, y, x+cw, y+ch), hex("#2B3A55"))
			im := beautyAt(bake, r, s, 45, yw)
			lbl := fmt.Sprintf("%s YAW %+d", names[s], yw)
			if im == nil && s == "S1" { // not baked: the runtime scorch overlay on S0, approximated
				if im = beautyAt(bake, r, "S0", 45, yw); im != nil {
					im = scorch(im)
					lbl += "  (RUNTIME OVERLAY, APPROX.)"
				}
			}
			if im != nil {
				blit(sheet, im, x, y, k/r.maxTexel())
			}
			text(sheet, x, y+ch+4, 2, lbl, dim)
		}
	}
	// wrecks
	y := 50 + 4*(ch+pad+18)
	text(sheet, pad, y, 2, "S4 COLLAPSE WRECKS (REST, TUMBLED), MIRRORED PAIRS STORED ONCE; THE CARAPACE SINKS AS ITS OWN S3 LAYER", dim)
	y += 18
	x := pad
	ents, _ := os.ReadDir(filepath.Join(bake, hull))
	for _, e := range ents {
		if !strings.HasPrefix(e.Name(), "fin_wreck_") {
			continue
		}
		im := load(filepath.Join(bake, hull, e.Name()))
		cr := alphaBounds(im)
		if cr.Empty() {
			continue
		}
		sub := image.NewNRGBA(image.Rect(0, 0, cr.Dx(), cr.Dy()))
		draw.Draw(sub, sub.Bounds(), im, cr.Min, draw.Src)
		in := r.inst(strings.SplitN(strings.TrimPrefix(e.Name(), "fin_wreck_"), "_f", 2)[0])
		kk := 0.62 / in.Texel
		sw := int(float64(cr.Dx()) * kk)
		if x+sw > W-pad {
			x = pad
			y += 200
		}
		fill(sheet, image.Rect(x, y, x+sw, y+int(float64(cr.Dy())*kk)), hex("#2B3A55"))
		blit(sheet, sub, x, y, kk)
		text(sheet, x, y+int(float64(cr.Dy())*kk)+3, 2, strings.TrimSuffix(strings.TrimPrefix(e.Name(), "fin_wreck_"), ".png"), dim)
		x += sw + pad
	}
	save(out, sheet)
	fmt.Println(out)
}

// sets: the same tour built from different module sets, S0 and S3 at the hero view.
func cmdSets(a []string) {
	bake, rigDir, out, hulls := a[0], a[1], a[2], a[3:]
	k := 0.62
	pad := 14
	var rs []*Rig
	W, ch := pad, 0
	for _, h := range hulls {
		r := readRig(rigDir, h)
		rs = append(rs, r)
		W += int((r.Frame[2]-r.Frame[0])*k) + pad
		ch = max(ch, int((r.Frame[3]-r.Frame[1])*k))
	}
	H := 50 + 2*(ch+60) + 10
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 14, 3, "COMPOSABLE MODULE SETS - ONE TOUR, ONE SET COMBINATION PER RUN (VISUAL ONLY); TOP S0, BOTTOM S3", ink)
	x := pad
	for _, r := range rs {
		cw := int((r.Frame[2] - r.Frame[0]) * k)
		for row, s := range []string{"S0", "S3"} {
			y := 50 + row*(ch+60)
			fill(sheet, image.Rect(x, y, x+cw, y+ch), hex("#2B3A55"))
			if im := finBeauty(bake, r, s, tag(45, 0)); im != nil {
				blit(sheet, im, x, y, k/r.maxTexel())
			} else {
				blit(sheet, clayHint(r, s, tag(45, 0)), x, y, k/r.PPU)
			}
			overlay(sheet, r, x, y, k)
		}
		seen := map[string]bool{}
		var sets []string
		for _, in := range r.Insts {
			if !seen[in.Slot] {
				seen[in.Slot] = true
				sets = append(sets, in.Slot+":"+in.Set)
			}
		}
		text(sheet, x, 50+ch+6, 2, strings.ToUpper(r.Hull), ink)
		for i := 0; i*3 < len(sets); i++ {
			text(sheet, x, 50+ch+22+i*12, 2, strings.ToUpper(strings.Join(sets[i*3:min(len(sets), i*3+3)], "  ")), dim)
		}
		x += cw + pad
	}
	save(out, sheet)
	fmt.Println(out)
}

// mock: three phone frames (360 x 520 arena, DPR 2) with the carrier at the boss row,
// under the zoom-out camera (screen = pivot + Z (arena - pivot), pivot (180, 477)).
func cmdMock(a []string) {
	bake, rigDir, out, hull := a[0], a[1], a[2], a[3]
	r := readRig(rigDir, hull)
	root := repoRoot()
	bg := load(filepath.Join(root, "assets/images/sector-1.webp"))
	parts := load(filepath.Join(root, "assets/images/ship-parts.png"))
	ship := image.NewNRGBA(image.Rect(0, 0, 96, 96))
	draw.Draw(ship, ship.Bounds(), parts, image.Point{}, draw.Src)
	type panel struct {
		z      float64
		bx     float64
		by     float64
		pitch  int
		yaw    int
		stage  string
		label  string
		shield bool
	}
	panels := []panel{
		{0.86, 180, 205, 45, 0, "S0", "ENGAGE: Z 0.86, CENTRED, SHIELDED", true},
		{0.70, 100, 197, 38, -12, "S0", "CLIMB: Z 0.70, SWERVING LEFT, PITCH 38", true},
		{0.76, 250, 213, 52, 12, "S2", "ARMOUR SHED (S2): Z 0.76, PITCH 52", false},
	}
	if mustStat(filepath.Join(bake, hull, "S3")) {
		panels = append(panels, panel{0.72, 180, 205, 45, 0, "S3", "MODULE LOSS (S3): Z 0.72", false})
	}
	const dpr = 2.0
	PW, PH := int(360*dpr), int(520*dpr)
	pad := 16
	sheet := newCanvas(pad+len(panels)*(PW+pad), PH+90, bgDark)
	text(sheet, pad, 14, 3, strings.ToUpper(r.Title)+" - PHONE-SCALE MOCK (360 X 520 CSS ARENA AT DPR 2), THE HULL SPILLS OFF-SCREEN BY DESIGN", ink)
	for i, p := range panels {
		ph := newCanvas(PW, PH, hex("#0B0A14"))
		// far ground below the climb: the sector backdrop, darkened and fogged
		bgk := float64(PW) / float64(bg.Bounds().Dx()) * 1.1
		blit(ph, bg, -int(float64(PW)*0.05), -int(float64(PH)*0.1), bgk)
		for y := 0; y < PH; y++ {
			fog := 0.55 + 0.25*float64(PH-y)/float64(PH)
			for x := 0; x < PW; x++ {
				over(ph, x, y, color.NRGBA{70, 60, 96, uint8(255 * fog)})
			}
		}
		S := func(ax, ay float64) (float64, float64) {
			return (180 + p.z*(ax-180)) * dpr, (477 + p.z*(ay-477)) * dpr
		}
		// the stored layers at their stored densities, upscaled the way the runtime draws them
		im := composeLayers(bake, r, p.stage, p.pitch, p.yaw, r.maxTexel())
		if im == nil {
			im = beautyAt(bake, r, p.stage, p.pitch, p.yaw)
		}
		if im == nil {
			im = clayHint(r, p.stage, tag(p.pitch, p.yaw))
			im = areaScale(im, r.maxTexel()/r.PPU)
		}
		k := p.z * dpr / r.maxTexel()
		x0, y0 := S(p.bx+r.Frame[0], p.by+r.Frame[1])
		// drop shadow onto the fog layer below (offset down-right, soft)
		sh := areaScale(im, k*0.25)
		for y := 0; y < sh.Bounds().Dy(); y++ {
			for x := 0; x < sh.Bounds().Dx(); x++ {
				if a := sh.Pix[(y*sh.Bounds().Dx()+x)*4+3]; a > 0 {
					for dy := 0; dy < 4; dy++ {
						for dx := 0; dx < 4; dx++ {
							over(ph, int(x0)+40+x*4+dx, int(y0)+70+y*4+dy, color.NRGBA{10, 6, 18, uint8(float64(a) * 0.45)})
						}
					}
				}
			}
		}
		blit(ph, im, int(x0), int(y0), k)
		if p.shield {
			// the runtime's force-field rim: an elliptic cyan arc over the prow (overlay, not art)
			cx, cy := S(p.bx, p.by+12)
			for t := 0.0; t < math.Pi; t += 0.002 {
				x := cx + math.Cos(t)*110*p.z*dpr
				y := cy + math.Sin(t)*63*p.z*dpr
				for d := 0; d < 3; d++ {
					over(ph, int(x), int(y)+d, color.NRGBA{98, 240, 255, 150})
				}
			}
		}
		// the player ship at the ship row (48 units, drawn at Z)
		sx, sy := S(180+float64(i-1)*40, 477)
		blit(ph, ship, int(sx-24*p.z*dpr), int(sy-24*p.z*dpr), p.z*dpr/2)
		// creature size markers (34 CSS px floor) along the swarm band
		for c := 0; c < 5; c++ {
			cx, cy := S(70+float64(c)*55, 330+float64(c%2)*30)
			for t := 0.0; t < 2*math.Pi; t += 0.05 {
				over(ph, int(cx+math.Cos(t)*17*dpr*p.z), int(cy+math.Sin(t)*17*dpr*p.z), color.NRGBA{255, 255, 255, 90})
			}
		}
		x := pad + i*(PW+pad)
		blit(sheet, ph, x, 50, 1)
		rectOutline(sheet, x-1, 49, x+PW, 50+PH, dim)
		text(sheet, x, 50+PH+8, 2, p.label, dim)
		text(sheet, x, 50+PH+22, 2, "WHITE RINGS = 34 CSS PX CREATURE FLOOR; CYAN ARC = FORCE FIELD OVERLAY", dim)
	}
	save(out, sheet)
	fmt.Println(out)
}

// lineup: tour escalation, every hull's hero view at one scale (0.42 px per unit), bottom
// aligned on the carrier centre row, with the visible phone screen at Z 0.70 outlined.
func cmdLineup(a []string) {
	rigDir, out := a[0], a[1]
	bake := ""
	hulls := a[2:]
	if len(hulls) > 0 && strings.HasPrefix(hulls[0], "bake=") {
		bake = strings.TrimPrefix(hulls[0], "bake=")
		hulls = hulls[1:]
	}
	k := 0.42
	pad := 16
	var rs []*Rig
	W, top, bot := pad, 0.0, 0.0
	for _, h := range hulls {
		r := readRig(rigDir, h)
		rs = append(rs, r)
		W += int((r.Frame[2]-r.Frame[0])*k) + pad
		top = math.Min(top, r.Frame[1])
		bot = math.Max(bot, r.Frame[3])
	}
	H := 60 + int((bot-top)*k) + 60
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 14, 3, "TOUR ESCALATION LINEUP - HERO VIEW AT ONE SCALE; DASHED = PHONE SCREEN AT ZOOM 0.70 WITH THE CARRIER CENTRED", ink)
	x := pad
	for _, r := range rs {
		cw := int((r.Frame[2] - r.Frame[0]) * k)
		y := 60 + int((r.Frame[1]-top)*k)
		var im *image.NRGBA
		kk := k / r.PPU
		if bake != "" {
			if b := finBeauty(bake, r, "S0", tag(45, 0)); b != nil {
				im, kk = b, k/r.maxTexel()
			}
		}
		if im == nil {
			im = clayHint(r, "S0", tag(45, 0))
		}
		blit(sheet, im, x, y, kk)
		overlay(sheet, r, x, y, k)
		// visible screen at Z 0.70 with the carrier centred (180, 205): arena x [-77, 437], y [-204, 538]
		cx := float64(x) - r.Frame[0]*k
		cy := 60 - top*k
		vx0, vx1 := cx+(-77-180)*k, cx+(437-180)*k
		vy0 := cy + (-204-205)*k
		for xx := int(vx0); xx < int(vx1); xx += 6 {
			fill(sheet, image.Rect(xx, int(vy0), xx+3, int(vy0)+2), simCol)
		}
		for yy := int(vy0); yy < H-50; yy += 6 {
			fill(sheet, image.Rect(int(vx0), yy, int(vx0)+2, yy+3), simCol)
			fill(sheet, image.Rect(int(vx1), yy, int(vx1)+2, yy+3), simCol)
		}
		text(sheet, x, H-44, 2, fmt.Sprintf("TOUR %d  %s", r.Tour, strings.ToUpper(r.Hull)), ink)
		text(sheet, x, H-30, 2, fmt.Sprintf("%d INSTANCES  EXTENT X%.2f", len(r.Insts), r.Extent), dim)
		x += cw + pad
	}
	save(out, sheet)
	fmt.Println(out)
}

// scorch approximates the S1 runtime overlay for review: crystals dimmed toward slate, the hull
// darkened and warmed, a sparse speckle of ember hairline glints (deterministic).
func scorch(src *image.NRGBA) *image.NRGBA {
	out := image.NewNRGBA(src.Bounds())
	copy(out.Pix, src.Pix)
	w := src.Bounds().Dx()
	for i := 0; i < len(out.Pix); i += 4 {
		if out.Pix[i+3] == 0 {
			continue
		}
		r, g, b := float64(out.Pix[i]), float64(out.Pix[i+1]), float64(out.Pix[i+2])
		if b > r*1.3 && b > 120 { // violet crystal: flicker dim
			r, g, b = r*0.55, g*0.5, b*0.55
		}
		r, g, b = r*0.78+6, g*0.7, b*0.68
		p := i / 4
		x, y := p%w, p/w
		if (x*7919+y*104729)%97 == 0 {
			r, g, b = 255, 120, 40
		}
		out.Pix[i], out.Pix[i+1], out.Pix[i+2] = uint8(math.Min(255, r)), uint8(math.Min(255, g)), uint8(math.Min(255, b))
	}
	return out
}

// composeLayers rebuilds a view from the stored sprites of the manifest, as the runtime does:
// per instance (rig order) its stage layer, falling back to lower stages, at its stored texel
// density scaled (nearest) to out px per unit; an unstored view draws pitch 45; yaw -12 mirrors +12;
// the left of a mirrored pair at yaw 0 draws the right one flipped; detached groups (S3) are gone.
func composeLayers(bake string, r *Rig, stage string, p, yw int, out float64) *image.NRGBA {
	b, err := os.ReadFile(filepath.Join(bake, r.Hull, "manifest.json"))
	if err != nil {
		return nil
	}
	var m Manifest
	if json.Unmarshal(b, &m) != nil {
		return nil
	}
	ay := yw
	if ay < 0 {
		ay = -ay
	}
	t := tag(p, ay)
	has := func(t string) bool {
		for _, e := range m.Entries {
			if e.Kind == "layer" && e.View == t {
				return true
			}
		}
		return false
	}
	if !has(t) {
		t = tag(45, ay)
	}
	find := func(inst, st string) *Entry {
		for i := range m.Entries {
			e := &m.Entries[i]
			if e.Kind == "layer" && e.View == t && e.Inst == inst && e.Stage == st {
				return e
			}
		}
		return nil
	}
	removed := map[string]bool{}
	if s, ok := r.Stages[stage]; ok {
		for _, id := range s.Removed {
			removed[id] = true
		}
	}
	W := int(math.Round((r.Frame[2] - r.Frame[0]) * out))
	H := int(math.Round((r.Frame[3] - r.Frame[1]) * out))
	canvas := image.NewNRGBA(image.Rect(0, 0, W, H))
	order := []string{"S3", "S2", "S1", "S0"}
	for _, in := range r.Insts {
		if removed[in.ID] {
			continue
		}
		id, flip := in.ID, false
		if ay == 0 && strings.HasSuffix(id, "L") && r.inst(strings.TrimSuffix(id, "L")+"R") != nil {
			id, flip = strings.TrimSuffix(id, "L")+"R", true
		}
		var e *Entry
		started := false
		for _, st := range order {
			if st == stage {
				started = true
			}
			if started {
				if e = find(id, st); e != nil {
					break
				}
			}
		}
		if e == nil {
			continue
		}
		src := load(filepath.Join(bake, r.Hull, e.File))
		k := out / e.Texel
		for y := 0; y < int(float64(e.Crop[3])*k); y++ {
			for x := 0; x < int(float64(e.Crop[2])*k); x++ {
				c := src.NRGBAAt(e.Crop[0]+int(float64(x)/k), e.Crop[1]+int(float64(y)/k))
				if c.A == 0 {
					continue
				}
				dx := int(math.Round((e.DXY[0]-r.Frame[0])*out)) + x
				if flip { // mirror about the hull's centre axis
					dx = int(math.Round(-r.Frame[0]*out*2)) - dx - 1
				}
				over(canvas, dx, int(math.Round((e.DXY[1]-r.Frame[1])*out))+y, c)
			}
		}
	}
	if yw < 0 {
		canvas = mirrorAbout(canvas, -r.Frame[0]*out)
	}
	return canvas
}
