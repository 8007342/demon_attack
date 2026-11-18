package main

// The spear-bearer's gear, authored as geometry at the combat atlas's art
// pixel (64 per creature cell, 40 arena units): strokes are 2 art px (the
// insignia's coarse pixel, alien-troops §2.3), every piece gets a 1 art px
// ink outline, and the palette is the brood's iron and bone (alien-troops
// §5.4: the lightning rods' iron, the insignia's bone). No cyan (force
// shields), no blackbody heat colours (dive shields), no heart, face or
// mouth in the buckler's emblem (§4.1).

import (
	"image"
	"image/color"
	"math"
)

// Palette.
var (
	ink      = color.NRGBA{0x0B, 0x0A, 0x14, 255} // insignia.ink
	iron     = color.NRGBA{0x2E, 0x2A, 0x33, 255} // brood iron (rods)
	ironEdge = color.NRGBA{0x5A, 0x52, 0x62, 255} // its edge
	bone     = color.NRGBA{0xE9, 0xDF, 0xC8, 255} // rod tips
	boneHi   = color.NRGBA{0xF6, 0xEB, 0xC8, 255} // insignia.bone
	boneLo   = color.NRGBA{0xB8, 0xAC, 0x90, 255} // bone in shade
	talon    = color.NRGBA{0x8E, 0x82, 0x6C, 255} // a claw on the shaft
	white    = color.NRGBA{0xFF, 0xFF, 0xFF, 255} // tell.white (glint, hit)
)

// Head is a spearhead variant (the candidates sheet; [pickHead] ships).
type Head int

const (
	headLeaf Head = iota
	headTusk
	headBarb
)

var headNames = []string{"leaf", "tusk", "barb"}

// Emblem is a buckler emblem variant ([pickEmblem] ships).
type Emblem int

const (
	emblemFang Emblem = iota
	emblemBoss
	emblemWhorl
)

var emblemNames = []string{"fang", "boss", "whorl"}

// The picks (plan/render-runs/spear-bearers.md has the reasons).
const (
	pickHead   = headTusk
	pickEmblem = emblemFang
)

type pt struct{ x, y float64 }

// layer is one transparent 64 px (or smaller) frame being drawn.
type layer struct{ img *image.NRGBA }

func newLayer(w, h int) *layer { return &layer{image.NewNRGBA(image.Rect(0, 0, w, h))} }

func (l *layer) set(x, y int, p color.NRGBA) {
	if x < 0 || y < 0 || x >= l.img.Bounds().Dx() || y >= l.img.Bounds().Dy() {
		return
	}
	l.img.SetNRGBA(x, y, p)
}

func (l *layer) at(x, y int) color.NRGBA {
	if x < 0 || y < 0 || x >= l.img.Bounds().Dx() || y >= l.img.Bounds().Dy() {
		return color.NRGBA{}
	}
	return l.img.NRGBAAt(x, y)
}

// outline adds a 1 px ink ring (8-neighbourhood) around every opaque
// pixel, so the gear sits on any hide or sky.
func (l *layer) outline() {
	b := l.img.Bounds()
	var ring []image.Point
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if l.at(x, y).A != 0 {
				continue
			}
			hit := false
			for dy := -1; dy <= 1 && !hit; dy++ {
				for dx := -1; dx <= 1; dx++ {
					if q := l.at(x+dx, y+dy); q.A != 0 && q != ink {
						hit = true
						break
					}
				}
			}
			if hit {
				ring = append(ring, image.Pt(x, y))
			}
		}
	}
	for _, p := range ring {
		l.set(p.X, p.Y, ink)
	}
}

// over copies src's opaque pixels onto l (src drawn on top).
func (l *layer) over(src *layer) {
	b := src.img.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			if p := src.at(x, y); p.A != 0 {
				l.set(x, y, p)
			}
		}
	}
}

// spear draws a spear from its butt to its tip: a 2 px iron shaft lit on
// one side, a bone collar and ferrule, and the head.
func (l *layer) spear(butt, tip pt, head Head) {
	dx, dy := tip.x-butt.x, tip.y-butt.y
	length := math.Hypot(dx, dy)
	ux, uy := dx/length, dy/length
	nx, ny := -uy, ux // the shaft's left
	headLen := 11.0
	shaftEnd := length - headLen
	b := l.img.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			px, py := float64(x)+.5-butt.x, float64(y)+.5-butt.y
			u := px*ux + py*uy
			v := px*nx + py*ny
			switch {
			case u >= 0 && u <= shaftEnd && math.Abs(v) <= 1.0:
				c := iron
				if v < 0 {
					c = ironEdge
				}
				if u < 2.5 || (u > shaftEnd-3 && u <= shaftEnd-1) {
					c = boneLo // ferrule and collar
				}
				l.set(x, y, c)
			case u > shaftEnd && u <= length+.5:
				if c, ok := headPixel(head, (u-shaftEnd)/headLen, v); ok {
					l.set(x, y, c)
				}
			}
		}
	}
}

// headPixel is the head's colour at [t] (0 base .. 1 tip) and lateral
// offset [v] (px; negative is the shaft's left, the lit side).
func headPixel(h Head, t, v float64) (color.NRGBA, bool) {
	if t < 0 || t > 1 {
		return color.NRGBA{}, false
	}
	var half, mid float64
	switch h {
	case headLeaf: // a symmetric leaf: widest a third of the way up
		half = 3.2 * math.Sin(math.Pi*math.Min(1, t*1.25+.12))
		if t > .75 {
			half = 3.2 * (1 - t) / .25 * .6
		}
	case headTusk: // a long tapering tusk, its tip hooked to one side
		half = 2.6 * math.Pow(1-t, .75)
		mid = 1.8 * t * t
	case headBarb: // a narrow blade with one barb hooked back
		half = 1.8 * (1 - t)
		if t < .3 && v > 0 {
			half = 1.8 + 5*(.3-t)
		}
	}
	d := v - mid
	if math.Abs(d) > half+.15 || t > 1.02 {
		return color.NRGBA{}, false
	}
	switch {
	case d < -.4:
		return boneHi, true
	case d > .9:
		return boneLo, true
	}
	return bone, true
}

// talons draws a claw gripping at [p] across the shaft direction [u].
func (l *layer) talons(p pt, ux, uy float64) {
	nx, ny := -uy, ux
	for _, s := range []float64{-2.5, -1.5, 1.5, 2.5} {
		x := p.x + nx*s
		y := p.y + ny*s
		l.set(int(x), int(y), talon)
		l.set(int(x+ux), int(y+uy), talon)
	}
}

// buckler draws the round shield centred at c, radii rx × ry (an ellipse
// is the shield seen at an angle), with [emblem], [hit] flashes the rim
// white and cracks the face.
func (l *layer) buckler(c pt, rx, ry float64, emblem Emblem, hit bool) {
	b := l.img.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			px, py := (float64(x)+.5-c.x)/rx, (float64(y)+.5-c.y)/ry
			r := math.Hypot(px, py)
			if r > 1 {
				continue
			}
			// The rim is 2 px wide whatever the radius.
			rimW := 2.0 / math.Min(rx, ry)
			switch {
			case r > 1-rimW:
				if hit {
					l.set(x, y, white)
				} else if py < 0 {
					l.set(x, y, boneHi)
				} else {
					l.set(x, y, boneLo)
				}
			case r > 1-rimW-1.2/math.Min(rx, ry) && px+py < -.3:
				l.set(x, y, ironEdge) // the face's lit edge
			default:
				l.set(x, y, iron)
			}
		}
	}
	if rx >= 6 && ry >= 6 {
		l.emblem(c, math.Min(rx, ry), emblem)
	}
	if hit {
		// A crack across the face, from the rim toward the boss.
		for i, d := range []pt{{-5, -4}, {-4, -3}, {-3, -3}, {-2, -2}, {-1, -1}, {-1, 0}, {0, 1}} {
			if i%3 == 2 {
				l.set(int(c.x+d.x+1), int(c.y+d.y), white)
			}
			l.set(int(c.x+d.x), int(c.y+d.y), white)
		}
	}
}

// emblem draws the buckler's bone emblem at c (face radius r).
func (l *layer) emblem(c pt, r float64, e Emblem) {
	switch e {
	case emblemFang:
		// One fang leaning right, tapering to a single point: asymmetric,
		// no lobes, no zigzag (a zigzag read as a lightning bolt in the
		// first pass; alien-troops §4.1 rules 2-4).
		cells := []struct{ x, y, w int }{
			{-2, -4, 4}, {-2, -3, 4}, {-1, -2, 3}, {-1, -1, 3}, {0, 0, 2}, {0, 1, 2}, {1, 2, 1}, {1, 3, 1},
		}
		for _, s := range cells {
			for i := 0; i < s.w; i++ {
				col := bone
				if i == 0 {
					col = boneHi
				}
				l.set(int(c.x)+s.x+i, int(c.y)+s.y, col)
			}
		}
	case emblemBoss:
		for y := -2; y < 2; y++ {
			for x := -2; x < 2; x++ {
				l.set(int(c.x)+x, int(c.y)+y, bone)
			}
		}
	case emblemWhorl:
		for k := 0; k < 3; k++ {
			a := float64(k) * 2 * math.Pi / 3
			for s := 1.0; s < r-3; s += .5 {
				x := c.x + math.Cos(a+s*.25)*s
				y := c.y + math.Sin(a+s*.25)*s
				l.set(int(x), int(y), bone)
			}
		}
	}
}

// glint draws the wind-up's 4-point star centred in a 15 px frame.
func glintFrame() *layer {
	l := newLayer(15, 15)
	for i := -7; i <= 7; i++ {
		a := uint8(255 - 26*absInt(i))
		l.set(7+i, 7, color.NRGBA{255, 255, 255, a})
		l.set(7, 7+i, color.NRGBA{255, 255, 255, a})
	}
	for _, d := range [][2]int{{-1, -1}, {1, -1}, {-1, 1}, {1, 1}} {
		l.set(7+d[0], 7+d[1], color.NRGBA{255, 255, 255, 200})
	}
	return l
}

func absInt(i int) int {
	if i < 0 {
		return -i
	}
	return i
}

// The gear poses, in the 64 px creature cell (centre 32, 32; the body's
// centre is about 32, 34; the levelled head ends at the model's release
// point, (32 + 7, 32 + 16) units × 1.6 art px per unit).
var (
	idleButt, idleTip    = pt{45, 54}, pt{45, 12}
	levelButt, levelTip  = pt{46, 24}, pt{43, 59}
	windButt, windTip    = pt{55, 1}, pt{45, 27}
	releaseClaw          = pt{43, 53}
	carriedAt            = pt{18, 39}
	raisedAt             = pt{30, 43}
	propAt               = pt{32, 32}
	carriedRx, carriedRy = 5.0, 8.5
	raisedR              = 9.5
	propRx, propRy       = 9.5, 3.5
)

// Spear-layer frames (row 0) and buckler-layer frames (row 1).
const (
	spearIdle = iota
	spearLevel
	spearWind
	spearRelease
	spearFrames
)

const (
	bucklerCarried = iota
	bucklerRaised
	bucklerHit
	bucklerProp
	bucklerFrames
)

// spearLayer renders spear frame [f].
func spearLayer(f int, head Head) *layer {
	l := newLayer(cellPx, cellPx)
	switch f {
	case spearIdle:
		l.spear(idleButt, idleTip, head)
		l.talons(pt{45, 38}, 0, -1)
	case spearLevel:
		l.spear(levelButt, levelTip, head)
		l.talons(pt{45.3, 33}, -.085, 1)
	case spearWind:
		l.spear(windButt, windTip, head)
		l.talons(pt{51.5, 11}, -.39, .92)
	case spearRelease:
		// The empty claw, flung forward and open, two speed lines behind.
		for _, d := range []pt{{-3, 0}, {-3, 1}, {-1, 1}, {-1, 2}, {1, 1}, {1, 2}, {3, 0}, {3, 1}} {
			l.set(int(releaseClaw.x+d.x), int(releaseClaw.y+d.y), talon)
		}
		for y := -12; y <= -3; y++ {
			l.set(int(releaseClaw.x)-2, int(releaseClaw.y)+y, color.NRGBA{0xE9, 0xDF, 0xC8, uint8(40 + 12*(y+12))})
			l.set(int(releaseClaw.x)+2, int(releaseClaw.y)+y-2, color.NRGBA{0xE9, 0xDF, 0xC8, uint8(30 + 10*(y+12))})
		}
		return l // the speed lines stay soft: no outline
	}
	l.outline()
	return l
}

// bucklerLayer renders buckler frame [f].
func bucklerLayer(f int, emblem Emblem) *layer {
	l := newLayer(cellPx, cellPx)
	switch f {
	case bucklerCarried:
		l.buckler(carriedAt, carriedRx, carriedRy, emblem, false)
	case bucklerRaised:
		l.buckler(raisedAt, raisedR, raisedR, emblem, false)
	case bucklerHit:
		l.buckler(raisedAt, raisedR, raisedR, emblem, true)
	case bucklerProp:
		l.buckler(propAt, propRx, propRy, emblem, false)
	}
	l.outline()
	return l
}

// Projectile frames: the thrown spear, tip down, at these leans (degrees,
// + leans its tip right), in [projW] × [projH] cells with the tip at
// ([projW]/2, [projTipY]).
var projAngles = []float64{-24, -12, 0, 12, 24}

const projW, projH, projTipY = 24, 48, 44

func projectileLayer(deg float64, head Head) *layer {
	l := newLayer(projW, projH)
	a := deg * math.Pi / 180
	tip := pt{float64(projW) / 2, projTipY}
	const length = 40.0
	butt := pt{tip.x - math.Sin(a)*length, tip.y - math.Cos(a)*length}
	l.spear(butt, tip, head)
	l.outline()
	return l
}
