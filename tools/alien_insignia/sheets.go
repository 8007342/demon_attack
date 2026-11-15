package main

import (
	"image"
	"image/color"
	"math"
	"strings"
)

// Insignia palette (docs/styleguide/alien-troops.md §3).
var (
	ink    = color.NRGBA{11, 10, 20, 255}    // outline, 1 coarse px
	bone   = color.NRGBA{246, 235, 200, 255} // rank marks
	ember  = color.NRGBA{255, 90, 54, 255}   // ocellus core, angry rim
	gold   = color.NRGBA{255, 194, 74, 255}  // angry marks
	cyan   = color.NRGBA{98, 240, 255, 255}  // force-shield cells
	cyanLo = color.NRGBA{28, 111, 134, 255}  // spent shield slot
	white  = color.NRGBA{255, 255, 255, 255}
	violet = color.NRGBA{168, 136, 255, 255} // today's elite dot ring
)

// Glyphs on the coarse grid: one glyph pixel is 2 art px (the old 32-grid
// pixel, ~1.35 CSS px at the creature's 40-unit draw). 'o' fill, 'e' core;
// the ink outline is added around every glyph (1 coarse px, 8-connected).
var glyphs = map[string][]string{
	// Talon: the alien chevron, a downward claw hook, 2-px strokes.
	"talon": {
		"oo...oo",
		"ooo.ooo",
		".ooooo.",
		"..ooo..",
		"...o...",
	},
	// Ocellus: the alien star, a four-rayed eye with an ember core.
	"ocellus": {
		"....o....",
		"....o....",
		"...ooo...",
		"..ooeoo..",
		"oooeeeooo",
		"..ooeoo..",
		"...ooo...",
		"....o....",
		"....o....",
	},
	// Crown: five tines on a band, for sentinels and brood officers.
	"crown": {
		"o.o.o.o.o",
		"o.o.o.o.o",
		"ooooooooo",
		"ooeooeooo",
	},
	// Force-shield cell: a hex plate.
	"cell": {
		".oo.",
		"oooo",
		"oooo",
		".oo.",
	},
}

// stamp draws a glyph with its bottom-centre at art (x, y) on [c], with an
// art-to-canvas [scale]. Pass 0 inks the outline, pass 1 fills, so stacked
// stamps merge into one outlined shape.
func stamp(c *canvas, name string, x, y, scale int, fill, core color.NRGBA, pass int) {
	g := glyphs[name]
	h, w := len(g), len(g[0])
	on := func(i, j int) bool {
		return i >= 0 && j >= 0 && i < w && j < h && g[j][i] != '.'
	}
	ox, oy := x-w, y-2*h // coarse px are 2 art px
	for j := -1; j <= h; j++ {
		for i := -1; i <= w; i++ {
			var p color.NRGBA
			switch {
			case on(i, j) && pass == 1 && g[j][i] == 'e':
				p = core
			case on(i, j) && pass == 1:
				p = fill
			case !on(i, j) && pass == 0:
				near := false
				for dj := -1; dj <= 1; dj++ {
					for di := -1; di <= 1; di++ {
						near = near || on(i+di, j+dj)
					}
				}
				if !near {
					continue
				}
				p = ink
			default:
				continue
			}
			c.rect((ox+2*i)*scale, (oy+2*j)*scale, 2*scale, 2*scale, p)
		}
	}
}

func stampBoth(c *canvas, name string, x, y, scale int, fill, core color.NRGBA) {
	stamp(c, name, x, y, scale, fill, core, 0)
	stamp(c, name, x, y, scale, fill, core, 1)
}

// headTop is the art y of the top of each species' skull in the neutral
// glide cell (measured with the probe verb); marks sit just above it.
var headTop = [4]int{22, 21, 22, 20}

const pad = 16 // a creature sits at (pad, pad) on a 96 art px canvas

type rank int

const (
	drone rank = iota
	skirmisher
	veteran
	hunter
	todayElite
)

var rankNames = []string{"R0 DRONE", "R1 SKIRMISHER", "R2 VETERAN", "R3 HUNTER", "TODAY ELITE"}

type look struct {
	kind, row, col int
	rank           rank
	shield, slots  int // force-shield cells left / total (0 = none)
	breaking       bool
	angry, tell    bool
	wound          int // 0-3: proposed hide warm-up
}

// creature renders one look on a 96 x 96 art px canvas.
func creature(atlas *image.NRGBA, l look) *image.NRGBA {
	c := newCanvas(96, 96, color.NRGBA{})
	body := copyOf(cell(atlas, l.kind, l.row, l.col))
	if l.wound > 0 {
		warm(body, .12*float64(l.wound))
	}
	if l.shield > 0 || l.breaking {
		rim(c, body, cyan, 150)
	}
	if l.angry {
		rim(c, body, ember, 230)
	}
	if l.tell {
		rim(c, body, white, 230)
	}
	c.blit(body, pad, pad, 1)
	if l.rank == todayElite {
		// Today: the baked elite overlay (level 0) and the 12-dot ring.
		c.blit(cell(atlas, l.kind, eliteRowOff, 4), pad, pad, 1)
		for i := 0; i < 12; i++ {
			a := 2 * math.Pi * float64(i) / 12
			x := 48 + 24*artPerUnit*math.Cos(a)
			y := 48 + 24*artPerUnit*math.Sin(a)
			c.rect(int(x-1.6), int(y-1.6), 3, 3, violet)
		}
	}
	fill, core := bone, ember
	if l.angry {
		fill, core = gold, white
	}
	if l.tell {
		fill, core = white, white
	}
	x, y := pad+32, pad+headTop[l.kind]-1
	switch l.rank {
	case skirmisher:
		stampBoth(c, "talon", x, y, 1, fill, core)
	case veteran:
		stamp(c, "talon", x, y, 1, fill, core, 0)
		stamp(c, "talon", x, y-8, 1, fill, core, 0)
		stamp(c, "talon", x, y, 1, fill, core, 1)
		stamp(c, "talon", x, y-8, 1, fill, core, 1)
	case hunter:
		stampBoth(c, "ocellus", x, y+1, 1, fill, core)
	}
	if l.slots > 0 {
		shieldArc(c, l)
	}
	return c.img
}

// shieldArc: force-shield cells on an arc in front of the body (toward
// the player, screen down), one per shield point; spent slots stay as dark
// sockets so "how much is left of how much" reads at a glance.
func shieldArc(c *canvas, l look) {
	n := l.slots
	for i := 0; i < n; i++ {
		t := 0.0
		if n > 1 {
			t = float64(i)/float64(n-1) - .5
		}
		a := math.Pi/2 + t*float64(n-1)*.44
		x := 48 + int(math.Round(30*math.Cos(a)))
		y := 50 + int(math.Round(22*math.Sin(a)))
		fill := cyanLo
		if i < l.shield || (l.breaking && i == l.shield) {
			fill = cyan
		}
		if l.breaking && i == l.shield {
			fill = white
			// shards
			c.rect(x-6, y+4, 2, 2, cyan)
			c.rect(x+5, y+6, 2, 2, cyan)
			c.rect(x-2, y+9, 2, 2, white)
		}
		// centre the 4 x 4 coarse cell at (x, y)
		stampBoth(c, "cell", x+4, y+4, 1, fill, fill)
	}
}

// warm lerps every lit hide pixel toward ember (the old whole-body molt
// shift, restored as a tint on the painted art).
func warm(img *image.NRGBA, k float64) {
	b := img.Bounds()
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			p := img.NRGBAAt(x, y)
			if p.A == 0 || int(p.R)+int(p.G)+int(p.B) < 90 {
				continue // keep the dark outline
			}
			img.SetNRGBA(x, y, color.NRGBA{
				uint8(float64(p.R) + (255-float64(p.R))*k),
				uint8(float64(p.G) + (110-float64(p.G))*k),
				uint8(float64(p.B) + (60-float64(p.B))*k),
				p.A,
			})
		}
	}
}

// rim paints a 1 art px outline of [body]'s silhouette (dilated, outside
// only) onto [c] at the creature position.
func rim(c *canvas, body *image.NRGBA, p color.NRGBA, alpha uint8) {
	b := body.Bounds()
	solid := func(x, y int) bool {
		if x < 0 || y < 0 || x >= b.Dx() || y >= b.Dy() {
			return false
		}
		return body.NRGBAAt(b.Min.X+x, b.Min.Y+y).A > 128
	}
	q := p
	q.A = alpha
	for y := -2; y < b.Dy()+2; y++ {
		for x := -2; x < b.Dx()+2; x++ {
			if solid(x, y) {
				continue
			}
			near := false
			for dy := -2; dy <= 2 && !near; dy++ {
				for dx := -2; dx <= 2; dx++ {
					if dx*dx+dy*dy <= 4 && solid(x+dx, y+dy) {
						near = true
						break
					}
				}
			}
			if near {
				c.over(pad+x, pad+y, q)
			}
		}
	}
}

// --- sheets -----------------------------------------------------------------

func header(c *canvas, title, sub string) {
	c.text(16, 14, 4, title, label)
	c.text(16, 46, 2, sub, dim)
}

// ranksSheet: species x rank at 3x art, then the same at true phone size
// (40 CSS px creature: 96 art px canvas -> 60 px, DPR 1, the worst case).
func ranksSheet(atlas *image.NRGBA) *image.NRGBA {
	ranks := []rank{todayElite, drone, skirmisher, veteran, hunter}
	const z, cw = 3, 96 * 3
	phone := 60
	w := 16 + len(ranks)*(cw+8) + 24 + len(ranks)*(phone+8) + 16
	c := newCanvas(w, 80+4*(cw+24)+16, bg)
	header(c, "ALIEN INSIGNIA - RANKS", "LEFT: ART X3.  RIGHT: TRUE PHONE SIZE (40 CSS PX CREATURE, DPR 1).  TALON = CHEVRON, OCELLUS = STAR.")
	species := []string{"TEAL IMP", "VIOLET BRUTE", "CORAL HUNTER", "GOLD ELDER"}
	for k := 0; k < 4; k++ {
		y := 80 + k*(cw+24)
		c.text(16, y, 2, species[k], dim)
		for i, r := range ranks {
			img := creature(atlas, look{kind: k, col: glideCol, rank: r})
			x := 16 + i*(cw+8)
			c.rect(x, y+14, cw, cw, color.NRGBA{30, 28, 46, 255})
			c.blit(img, x, y+14, z)
			if k == 0 {
				c.text(x+4, 66, 2, rankNames[r], label)
			}
			px := 16 + len(ranks)*(cw+8) + 24 + i*(phone+8)
			c.blit(downscale(img, phone, phone), px, y+14+cw/2-phone/2, 1)
		}
	}
	return c.img
}

// shieldsSheet: force-shield cells, break, wound tint, angry rim, dive tell.
func shieldsSheet(atlas *image.NRGBA) *image.NRGBA {
	looks := []struct {
		name string
		l    look
	}{
		{"SHIELD 5/5", look{rank: veteran, shield: 5, slots: 5}},
		{"SHIELD 3/5", look{rank: veteran, shield: 3, slots: 5}},
		{"SHIELD 1/3", look{rank: veteran, shield: 1, slots: 3}},
		{"BREAK 2>1", look{rank: veteran, shield: 1, slots: 3, breaking: true}},
		{"WOUND 1 (MOLT)", look{rank: veteran, row: 1, wound: 1}},
		{"WOUND 3 (MOLT)", look{rank: veteran, row: 3, wound: 3}},
		{"ANGRY (1 HP)", look{rank: veteran, row: 4, angry: true}},
		{"DIVE TELL", look{rank: hunter, tell: true}},
	}
	const z, cw, phone = 2, 96 * 2, 60
	w := 16 + len(looks)*(cw+8) + 16
	kinds := []int{1, 3, 0}
	c := newCanvas(w, 80+len(kinds)*(cw+phone+40)+16, bg)
	header(c, "ALIEN INSIGNIA - SHIELDS AND STATUS", "ART X2, TRUE PHONE SIZE UNDER EACH.  FORCE SHIELD = CYAN HEX CELLS FACING THE PLAYER, ONE PER POINT; SPENT = DARK SOCKET.")
	for r, k := range kinds {
		y := 80 + r*(cw+phone+40)
		for i, e := range looks {
			l := e.l
			l.kind = k
			l.col = glideCol
			if l.tell {
				l.row, l.col = 7, 1 // anticipation cell
			}
			img := creature(atlas, l)
			x := 16 + i*(cw+8)
			if r == 0 {
				c.text(x+2, 66, 2, e.name, label)
			}
			c.rect(x, y, cw, cw, color.NRGBA{30, 28, 46, 255})
			c.blit(img, x, y, z)
			c.blit(downscale(img, phone, phone), x+cw/2-phone/2, y+cw+8, 1)
		}
	}
	return c.img
}

// phoneSheet: the same formation today and proposed, in a 360 x 640 CSS
// play area at DPR 2 (creatures 80 device px), over a dark sector ground.
func phoneSheet(atlas *image.NRGBA) *image.NRGBA {
	const pw, ph = 720, 1280
	c := newCanvas(16+2*(pw+24)+16, 80+ph+16, bg)
	header(c, "ALIEN INSIGNIA - PHONE FORMATION", "360 X 640 CSS AT DPR 2, CREATURES AT 40 CSS PX.  LEFT: TODAY (DOT RING).  RIGHT: PROPOSED.")
	type slot struct {
		kind, x, y int
		r          rank
		shield     int
		angry      bool
	}
	form := []slot{
		{0, 60, 120, drone, 0, false}, {0, 160, 100, drone, 0, false}, {1, 260, 130, skirmisher, 0, false},
		{2, 90, 230, veteran, 0, false}, {3, 200, 210, hunter, 3, false}, {1, 300, 250, skirmisher, 0, true},
		{0, 50, 340, drone, 0, false}, {2, 150, 330, skirmisher, 0, false}, {3, 250, 350, veteran, 0, false},
		{1, 110, 450, hunter, 0, false}, {0, 220, 470, drone, 0, false}, {2, 310, 430, veteran, 2, false},
	}
	for p := 0; p < 2; p++ {
		ox := 16 + p*(pw+24)
		// ground: a dark vertical ramp with faint ridges
		for y := 0; y < ph; y++ {
			t := float64(y) / ph
			base := color.NRGBA{uint8(26 + 18*t), uint8(22 + 14*t), uint8(40 + 6*t), 255}
			for x := 0; x < pw; x++ {
				v := base
				if (x/3+y/7+int(9*math.Sin(float64(x)/40+float64(y)/90)))%23 == 0 {
					v = color.NRGBA{v.R + 10, v.G + 8, v.B + 8, 255}
				}
				c.img.SetNRGBA(ox+x, 80+y, v)
			}
		}
		c.text(ox+12, 80+12, 3, map[int]string{0: "TODAY", 1: "PROPOSED"}[p], label)
		for _, s := range form {
			l := look{kind: s.kind, col: glideCol, rank: s.r, angry: s.angry}
			if s.angry {
				l.row = 4
			}
			if p == 0 {
				if s.r == hunter {
					l.rank = todayElite
				} else {
					l.rank = drone
				}
				l.angry = false
			} else if s.shield > 0 {
				l.shield, l.slots = s.shield, 3
			}
			img := downscale(creature(atlas, l), 120, 120) // 96 art -> 60 CSS -> 120 dev
			c.blit(img, ox+2*s.x-60, 80+2*s.y-60, 1)
		}
		// the ship row for scale
		c.rect(ox+pw/2-40, 80+ph-180, 80, 40, color.NRGBA{120, 200, 230, 255})
		c.text(ox+pw/2-30, 80+ph-130, 2, "SHIP 40 CSS", dim)
	}
	return c.img
}

// glyphSheet: the glyph set at 8x with its palette.
func glyphSheet() *image.NRGBA {
	names := []string{"talon", "ocellus", "crown", "cell"}
	c := newCanvas(16+len(names)*200+16, 80+200+60, bg)
	header(c, "ALIEN INSIGNIA - GLYPHS", "1 GLYPH PX = 2 ART PX. BONE F6EBC8 / EMBER FF5A36 / ANGRY GOLD FFC24A / SHIELD CYAN 62F0FF, SPENT 1C6F86 / INK 0B0A14")
	for i, n := range names {
		x := 16 + i*200
		fill := bone
		if n == "cell" {
			fill = cyan
		}
		stampBoth(c, n, (x+100)/4, 60, 4, fill, ember)
		c.text(x+60, 80+180, 3, strings.ToUpper(n), label)
	}
	return c.img
}
