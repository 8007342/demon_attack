package main

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strings"
)

// insignia-ranks (openspec/changes/insignia-ranks): the mark is rarer than
// the rank. Most of a wave wears nothing; elite grunts wear a small bone
// mark simplified from the officers' wings or crown (no fang, no ember);
// the fang is kept for the higher ranks: "Fang and Wings!" (the winged
// fang) on hunters, the winged crown on sentinels, and the fang and twin
// fangs only on the carrier's sigil. Picks and reasons:
// plan/render-runs/insignia-ranks.md.

func init() {
	// Elite grunt of the brood: the hunter's bat wings without the fang and
	// the ember, spread wide: tips swept up, trailing feathers swept down at
	// the outer edges, a small two-point tail at the root. The envelope is
	// an outstretched "X" of wings, never a V (a smile: the swept-V
	// candidate scored 0.67) and never a row of rising points (a crown: the
	// bat candidate read as one). 11 x 5: 2.2 times wider than tall.
	glyphs["winglet"] = []string{
		"oo.......oo",
		".ooo...ooo.",
		"..ooo.ooo..",
		".ooooooooo.",
		"oo..o.o..oo",
	}
	// Elite grunt of a sentinel's escort, and the spear-bearers: the
	// sentinel's crown without its wings and ember. Three points rise from
	// a flat band, the centre one tallest; the band is flat at the bottom
	// so no point hangs (rules 3, 5). 7 x 5: exactly 1.4 times wider than
	// tall (rule 2).
	glyphs["crownlet"] = []string{
		"...o...",
		"o..o..o",
		"oo.o.oo",
		"ooooooo",
		"ooooooo",
	}
}

// markLadder: the shipped marks in rank order, with the atlas key and who
// wears them. The two elite-grunt marks share one notch.
var markLadder = []struct{ key, name, who string }{
	{"winglet", "WINGLET", "ELITE GRUNT"},
	{"crownlet", "CROWNLET", "ESCORT ELITE / SPEAR"},
	{"wingfang", "FANG AND WINGS", "R3 HUNTER (ELITE)"},
	{"wingcrown", "WINGED CROWN", "R4 SENTINEL"},
}

// carrierLadder: the brood sigil on the carrier's four forms (2x).
var carrierLadder = []string{"fang", "fang2", "wingfang", "wingcrown"}

func markKeys() []string {
	var k []string
	for _, g := range markLadder {
		k = append(k, g.key)
	}
	return k
}

func markShapes() map[string][]string {
	m := map[string][]string{}
	for _, g := range markLadder {
		m[g.key] = glyphs[g.key]
	}
	return m
}

// rankCandidates: the shapes tried for the two elite-grunt marks (`go run
// . candidates -set ranks`); the shipped picks are in glyphs.
var rankCandidates = []struct {
	rank, name string
	shape      []string
}{
	{"WING", "A BAT", []string{".....o.....", "o...ooo...o", "oo.ooooo.oo", ".ooooooooo.", "..oo...oo.."}},
	{"WING", "B SWEPT V", []string{"oo.......oo", "ooo.....ooo", ".oooo.oooo.", "..ooooooo..", ".o.o...o.o."}},
	{"WING", "C PILOT BAR", []string{"o.........o", "oo.......oo", "ooo.ooo.ooo", ".ooooooooo.", "..o.....o.."}},
	{"WING", "D GULL", []string{"o.........o", "oo...o...oo", ".ooo.o.ooo.", "..ooooooo..", "...o...o..."}},
	{"WING", "E HEADED", []string{"o.........o", "oo...o...oo", "ooo.ooo.ooo", ".ooooooooo.", "..oo...oo.."}},
	{"WING", "F CUP", []string{"o.........o", "oo.......oo", "ooo.....ooo", ".ooooooooo.", "..oo...oo.."}},
	{"WING", "G SPREAD", []string{"oo.......oo", ".ooo...ooo.", "..ooo.ooo..", ".ooooooooo.", "oo..o.o..oo"}},
	{"WING", "H SPLIT", []string{"o.........o", "oo.......oo", ".ooo...ooo.", "..oooo.oooo", "...oo...oo."}},
	{"WING", "G2 SPREAD OUTER", []string{"oo.......oo", ".ooo...ooo.", "..ooo.ooo..", ".ooooooooo.", "oo..ooo..oo"}},
	{"WING", "G3 SPREAD BODY", []string{"oo.......oo", ".ooo.o.ooo.", "..ooooooo..", ".ooooooooo.", "oo...o...oo"}},
	{"WING", "I BAR TIPS", []string{"o.........o", "oo.......oo", "ooooooooooo", ".ooo.o.ooo.", "..o.....o.."}},
	{"CROWN", "A THREE POINT", []string{"...o...", "o..o..o", "oo.o.oo", "ooooooo", "ooooooo"}},
	{"CROWN", "B WIDE", []string{"....o....", "o...o...o", "oo.ooo.oo", "ooooooooo", ".ooooooo."}},
	{"CROWN", "C FIVE POINT", []string{"o.o.o.o.o", "o.o.o.o.o", "ooooooooo", "ooooooooo", ".ooooooo."}},
}

// --- the review sheet (`go run . ranks -root ../.. -waves <dir>`) ----------

// sampleWave is one mid-wave frame from tools/insignia_share.dart
// (sample-waves.json): every creature in the fight, its old rank (0-4,
// lightningRank) and its new mark.
type sampleWave struct {
	Label  string
	Width  float64
	Height float64
	Demons []struct {
		X, Y  float64
		Kind  int
		Large bool
		Old   int
		Mark  string
	}
}

func loadWaves(dir string) []sampleWave {
	b, err := os.ReadFile(filepath.Join(dir, "sample-waves.json"))
	if err != nil {
		return nil
	}
	var w []sampleWave
	if err := json.Unmarshal(b, &w); err != nil {
		panic(err)
	}
	return w
}

// shareRows: the per-tour lines of insignia-share.md, as sheet text.
func shareRows(dir string) []string {
	b, err := os.ReadFile(filepath.Join(dir, "insignia-share.md"))
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(b), "\n") {
		f := strings.Split(l, "|")
		if len(f) < 8 || (strings.TrimSpace(f[1]) != "normal" && strings.TrimSpace(f[1]) != "hard") {
			continue
		}
		first := func(s string) string { return strings.TrimSpace(strings.Split(s, "/")[0]) }
		second := func(s string) string { return strings.TrimSpace(strings.Split(s, "/")[1]) }
		out = append(out, fmt.Sprintf("%-6s TOUR %s   OLD MARKED %7s (WORST %7s)   NEW MARKED %7s (WORST %7s)   NEW FANG %6s (WORST %6s)",
			strings.ToUpper(strings.TrimSpace(f[1])), strings.TrimSpace(f[2]),
			first(f[4]), second(f[4]), first(f[5]), second(f[5]), first(f[6]), second(f[6])))
	}
	return out
}

var oldKeys = []string{"", "fang", "fang2", "wingfang", "wingcrown"}

// waveFrame draws one sample frame at [k] device px per arena unit: each
// creature's neutral glide cell at 40 units (sentinels at 1.8x, a stand-in
// for their own sheet), and its mark seated one art px above the skull,
// sized as the painter sizes it (1.35 units per glyph px), nearest.
func waveFrame(atlas *image.NRGBA, w sampleWave, old bool, k float64) *image.NRGBA {
	c := newCanvas(int(w.Width*k), int(w.Height*k), color.NRGBA{30, 28, 46, 255})
	type seat struct {
		key        string
		x, bottomY float64
	}
	var seats []seat
	for _, d := range w.Demons {
		scale := 1.0
		if d.Large {
			scale = 1.8
		}
		size := int(40 * scale * k)
		body := downscale(cell(atlas, d.Kind, 0, glideCol), size, size)
		c.blit(body, int(d.X*k)-size/2, int(d.Y*k)-size/2, 1)
		key := d.Mark
		if old {
			key = oldKeys[d.Old]
		}
		if key == "" || key == "none" {
			continue
		}
		if !old {
			key = map[string]string{"winglet": "winglet", "crownlet": "crownlet", "fangWings": "wingfang", "wingCrown": "wingcrown"}[key]
		}
		head := (float64(headTop[d.Kind]) - 32 - 1) / artPerUnit * scale
		seats = append(seats, seat{key, d.X, d.Y + head})
	}
	for _, s := range seats {
		img := glyphImage(glyphs[s.key], 1, bone, ember)
		u := 1.35 * k
		gw, gh := float64(img.Bounds().Dx())*u, float64(img.Bounds().Dy())*u
		x0, y0 := s.x*k-gw/2, s.bottomY*k-gh
		for py := int(math.Floor(y0)); py < int(math.Ceil(y0+gh)); py++ {
			for px := int(math.Floor(x0)); px < int(math.Ceil(x0+gw)); px++ {
				sx := int(math.Floor((float64(px) + .5 - x0) / u))
				sy := int(math.Floor((float64(py) + .5 - y0) / u))
				if sx < 0 || sy < 0 || sx >= img.Bounds().Dx() || sy >= img.Bounds().Dy() {
					continue
				}
				c.over(px, py, img.NRGBAAt(sx, sy))
			}
		}
	}
	return c.img
}

// ranksSheet2: art/contact/insignia-ranks.png.
//  1. The ladder, grunt to sentinel, at 8x, 2x (the atlas, bone / angry /
//     tell) and 1x, with the carrier's sigil ladder.
//  2. Each mark on each species at phone size (40 CSS px creature, DPR 2
//     and DPR 1).
//  3. Two sample waves, old against new, at phone DPR 1 (1:1) and DPR 2.
//  4. The measured shares and the lookalike scores.
func ranksSheet2(atlas *image.NRGBA, waves []sampleWave, shares []string) *image.NRGBA {
	keys := append([]string{""}, markKeys()...)
	names := []string{"NONE", "WINGLET", "CROWNLET", "FANG AND WINGS", "WINGED CROWN"}
	who := []string{"GRUNTS (MOST)", "ELITE GRUNT", "ESCORT, SPEAR", "HUNTER (ELITE)", "SENTINEL"}
	const W = 1560
	H := 90 + 190 + 60 + 4*100 + 40
	H += len(waves)*(1040+60) + 40 + 16*len(shares) + 120
	c := newCanvas(W, H, bg)
	header(c, "INSIGNIA RANKS - FANG AND WINGS, RARE AND MEANINGFUL",
		"OPERATOR: TOO MANY FANGS.  GRUNTS WEAR NOTHING; ELITE GRUNTS A WINGLET (CROWNLET IN AN ESCORT); FANGS ONLY ON HUNTERS (FANG AND WINGS) AND SENTINELS.")
	y := 84
	// 1. The ladder.
	x := 16
	for i, k := range keys {
		c.text(x, y, 2, names[i], label)
		c.text(x, y+14, 2, who[i], dim)
		if k != "" {
			c.blit(glyphImage(glyphs[k], 8, bone, ember), x, y+32, 1)
			bx := x + (len(glyphs[k][0])+2)*8 + 10
			for t, tone := range []struct{ f, e color.NRGBA }{{bone, ember}, {gold, white}, {white, white}} {
				c.blit(glyphImage(glyphs[k], 2, tone.f, tone.e), bx, y+32+t*30, 1)
			}
			c.blit(glyphImage(glyphs[k], 1, bone, ember), bx+40, y+32, 1)
			x = bx + 40 + 30 + 20
		} else {
			c.text(x, y+60, 3, "-", dim)
			x += 150
		}
	}
	y += 32 + 9*8 + 16 + 20
	c.text(16, y, 2, "EACH: 8X  |  2X BONE / ANGRY / TELL (THE ATLAS)  |  1X.    CARRIER SIGIL, FORMS 1-4 AT 2X:", dim)
	cx := 860
	for _, k := range carrierLadder {
		g := glyphImage(glyphs[k], 4, bone, ember)
		c.blit(g, cx, y-10, 1)
		cx += g.Bounds().Dx() + 16
	}
	y += 60
	// 2. On the demons, phone size.
	c.text(16, y, 3, "ON THE DEMONS AT PHONE SIZE: 40 CSS PX CREATURE AT DPR 2, THEN DPR 1", label)
	y += 28
	for kind := 0; kind < 4; kind++ {
		x := 16
		for _, k := range keys {
			var shape []string
			if k != "" {
				shape = glyphs[k]
			}
			img := onCreature(atlas, kind, shape, bone, ember)
			c.blit(downscale(img, 120, 120).SubImage(image.Rect(14, 4, 106, 94)).(*image.NRGBA), x, y, 1)
			c.blit(downscale(img, 60, 60).SubImage(image.Rect(7, 2, 53, 47)).(*image.NRGBA), x+94, y+22, 1)
			x += 94 + 48 + 40
		}
		y += 100
	}
	y += 20
	// 3. Sample waves.
	for _, w := range waves {
		var oldN, newN, fangOld, fangNew int
		for _, d := range w.Demons {
			if d.Old > 0 {
				oldN++
				fangOld++
			}
			if d.Mark != "none" {
				newN++
			}
			if d.Mark == "fangWings" || d.Mark == "wingCrown" {
				fangNew++
			}
		}
		n := len(w.Demons)
		c.text(16, y, 3, "SAMPLE WAVE: "+w.Label, label)
		c.text(16, y+24, 2, fmt.Sprintf("%d IN THE FIGHT.  OLD: %d MARKED, %d FANGS.  NEW: %d MARKED, %d FANGS.  LEFT: PHONE DPR 1 (1:1), RIGHT: DPR 2.", n, oldN, fangOld, newN, fangNew), dim)
		y += 44
		o1, n1 := waveFrame(atlas, w, true, 1), waveFrame(atlas, w, false, 1)
		c.blit(o1, 16, y, 1)
		c.blit(n1, 16, y+520+12, 1)
		c.text(24, y+8, 3, "BEFORE", label)
		c.text(24, y+520+12+8, 3, "AFTER", label)
		o2, n2 := waveFrame(atlas, w, true, 2), waveFrame(atlas, w, false, 2)
		// The DPR 2 frames, cropped to the formation band (top 260 units).
		c.blit(o2.SubImage(image.Rect(0, 0, 720, 516)).(*image.NRGBA), 16+360+16, y, 1)
		c.blit(n2.SubImage(image.Rect(0, 0, 720, 516)).(*image.NRGBA), 16+360+16, y+520+12, 1)
		c.text(16+360+24, y+8, 3, "BEFORE 2X", label)
		c.text(16+360+24, y+520+12+8, 3, "AFTER 2X", label)
		y += 1040 + 40
	}
	// 4. Shares and scores.
	c.text(16, y, 3, "MEASURED SHARE OF THE CREATURES IN THE FIGHT (TOOLS/INSIGNIA_SHARE.DART, 212 WAVES)", label)
	y += 26
	for _, r := range shares {
		c.text(16, y, 2, r, dim)
		y += 16
	}
	y += 14
	c.text(16, y, 3, "LOOKALIKE SCORES (SOFT IOU AGAINST A PIXEL HEART, SMILE, FACE; CEILING 0.5)", label)
	y += 26
	for i, r := range ladderMetrics(markShapes(), markKeys()) {
		c.text(16+(i%2)*760, y+(i/2)*16, 2, fmt.Sprintf("%-10s HEART %.2f  SMILE %.2f  FACE %.2f  MIRROR %.2f", strings.ToUpper(r.key), r.heart, r.smile, r.face, r.mirr), dim)
	}
	return c.img
}
