package main

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

// insignia-ranks: the elite-grunt marks keep the gargoyle-insignia rules
// (design §1 there) and sit a clear notch below the officers.
func TestRankMarks(t *testing.T) {
	checkGlyphs()
	set, keys := markShapes(), markKeys()
	for _, r := range ladderMetrics(set, keys) {
		if r.heart > .5 || r.smile > .5 || r.face > .5 {
			t.Errorf("%s: heart %.2f smile %.2f face %.2f > 0.5", r.key, r.heart, r.smile, r.face)
		}
		if r.mirr > .85 && float64(r.w) < 1.4*float64(r.h) {
			t.Errorf("%s: symmetric (%.2f) but %dx%d", r.key, r.mirr, r.w, r.h)
		}
		// The 9 x 6 CSS px minimum fill: 7 x 5 glyph px.
		if r.w < 7 || r.h < 5 {
			t.Errorf("%s: %dx%d under the 7x5 minimum", r.key, r.w, r.h)
		}
	}
	officer := len(set["wingfang"][0])
	for _, k := range []string{"winglet", "crownlet"} {
		g := strings.Join(set[k], "")
		if strings.Contains(g, "e") {
			t.Errorf("%s: an elite grunt carries no ember", k)
		}
		if len(set[k][0]) >= officer || len(set[k]) >= len(set["wingfang"]) {
			t.Errorf("%s: not smaller than Fang and Wings", k)
		}
		// Rule 3 / no hanging fang: nothing in the bottom row's centre
		// column hangs alone below the band.
		bottom := set[k][len(set[k])-1]
		mid := len(bottom) / 2
		if bottom[mid] != '.' && bottom[mid-1] == '.' && bottom[mid+1] == '.' {
			t.Errorf("%s: a single point hangs at the centre (a heart's tip)", k)
		}
	}
	// The two elite-grunt marks read apart (wings are not a crown).
	for _, r := range ladderMetrics(set, keys) {
		if (r.key == "winglet" && r.nearestKey == "crownlet") || (r.key == "crownlet" && r.nearestKey == "winglet") {
			if r.nearest > .6 {
				t.Errorf("%s too close to %s: %.2f", r.key, r.nearestKey, r.nearest)
			}
		}
	}
	if len(set["wingcrown"][0]) <= officer {
		t.Error("the winged crown is not wider than Fang and Wings")
	}
}

// The committed atlas is exactly what `go run . atlas` writes.
func TestAtlasByteIdentical(t *testing.T) {
	img, dart := atlasFiles()
	png, err := os.ReadFile("../../assets/images/insignia.png")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(png, encodePNG(img)) {
		t.Error("assets/images/insignia.png differs from a rebuild: go run . atlas -root ../..")
	}
	src, err := os.ReadFile("../../lib/game/insignia_atlas.dart")
	if err != nil {
		t.Fatal(err)
	}
	if string(src) != dart {
		t.Error("lib/game/insignia_atlas.dart differs from a rebuild: go run . atlas -root ../..")
	}
	img2, dart2 := atlasFiles()
	if !bytes.Equal(encodePNG(img2), encodePNG(img)) || dart2 != dart {
		t.Error("two rebuilds differ")
	}
}
