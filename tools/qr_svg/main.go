// Command qr_svg writes the stylised QR code for the /qr page (web/qr/).
//
// Square pixel modules in the game's midnight (#100E2C) on a pale mint tile,
// finder eyes with violet cores, error correction H so the centre can carry
// the gold-ringed game emblem. Dark-on-light keeps it readable by every phone
// camera. It also writes a PNG of the same module layout (centre cleared, no
// emblem) so the code can be decoded independently.
//
// Run (from tools/qr_svg): go run . -url https://demonattack.tlatoani.net/ -out ../../web/qr
// Writes qr.svg and inlines the same SVG into ../../web/qr/index.html.
package main

import (
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"log"
	"os"
	"path/filepath"
	"strings"

	"rsc.io/qr"
)

const (
	quiet   = 3         // quiet-zone modules around the code (tile padding)
	ink     = "#100E2C" // midnight: modules
	eyeCore = "#3A1F7A" // dark violet: finder cores
	paper   = "#EAF7F2" // pale mint tile
)

func main() {
	url := flag.String("url", "https://demonattack.tlatoani.net/", "URL to encode")
	out := flag.String("out", "web/qr", "output directory")
	emblemMods := flag.Int("emblem", 9, "side of the cleared centre square, in modules (odd)")
	flag.Parse()

	code, err := qr.Encode(*url, qr.H)
	if err != nil {
		log.Fatal(err)
	}
	n := code.Size
	e := *emblemMods
	if e%2 == 0 {
		e++
	}
	// Keep the cleared centre under ~8% of the symbol (H tolerates ~30%).
	if float64(e*e) > 0.08*float64(n*n) {
		log.Fatalf("emblem %d×%d too large for a %d×%d symbol", e, e, n, n)
	}
	c0 := (n - e) / 2
	inCentre := func(x, y int) bool { return x >= c0 && x < c0+e && y >= c0 && y < c0+e }
	inEye := func(x, y int) bool {
		in := func(ox, oy int) bool { return x >= ox && x < ox+7 && y >= oy && y < oy+7 }
		return in(0, 0) || in(n-7, 0) || in(0, n-7)
	}
	dark := func(x, y int) bool { return code.Black(x, y) && !inCentre(x, y) }

	full := n + 2*quiet
	var b strings.Builder
	fmt.Fprintf(&b, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" shape-rendering="crispEdges" role="img" aria-label="QR code: %s">`, full, full, *url)
	fmt.Fprintf(&b, `<rect width="%d" height="%d" rx="2.2" fill="%s"/>`, full, full, paper)
	// Data modules as one path of horizontal runs (eyes drawn separately).
	b.WriteString(`<path fill="` + ink + `" d="`)
	for y := 0; y < n; y++ {
		for x := 0; x < n; {
			if !dark(x, y) || inEye(x, y) {
				x++
				continue
			}
			run := 1
			for x+run < n && dark(x+run, y) && !inEye(x+run, y) {
				run++
			}
			fmt.Fprintf(&b, "M%d %dh%dv1h-%dz", x+quiet, y+quiet, run, run)
			x += run
		}
	}
	b.WriteString(`"/>`)
	// Finder eyes: midnight ring, violet core.
	for _, o := range [][2]int{{0, 0}, {n - 7, 0}, {0, n - 7}} {
		x, y := o[0]+quiet, o[1]+quiet
		fmt.Fprintf(&b, `<path fill="%s" fill-rule="evenodd" d="M%d %dh7v7h-7zM%d %dv5h5v-5z"/>`, ink, x, y, x+1, y+1)
		fmt.Fprintf(&b, `<rect x="%d" y="%d" width="3" height="3" fill="%s"/>`, x+2, y+2, eyeCore)
	}
	// Centre: a midnight plate with a gold rim, then the game emblem.
	cx := c0 + quiet
	fmt.Fprintf(&b, `<rect x="%g" y="%g" width="%g" height="%g" rx="1.2" fill="#100E2C" stroke="#EFBD57" stroke-width=".45"/>`,
		float64(cx)+.5, float64(cx)+.5, float64(e)-1, float64(e)-1)
	fmt.Fprintf(&b, `<image href="/icons/Icon-192.png" x="%g" y="%g" width="%g" height="%g" style="image-rendering:pixelated"/>`,
		float64(cx)+1, float64(cx)+1, float64(e)-2, float64(e)-2)
	b.WriteString(`</svg>`)
	svg := b.String()
	if err := os.WriteFile(filepath.Join(*out, "qr.svg"), []byte(svg+"\n"), 0o644); err != nil {
		log.Fatal(err)
	}
	// Inline it into the page between <!--QR--> and <!--/QR--> (an SVG shown
	// through <img> may not load the emblem image it references).
	page := filepath.Join(*out, "index.html")
	html, err := os.ReadFile(page)
	if err != nil {
		log.Fatal(err)
	}
	start := strings.Index(string(html), "<!--QR-->")
	end := strings.Index(string(html), "<!--/QR-->")
	if start < 0 || end < start {
		log.Fatalf("%s: missing <!--QR--> markers", page)
	}
	updated := string(html[:start]) + "<!--QR-->" + svg + string(html[end:])
	if err := os.WriteFile(page, []byte(updated), 0o644); err != nil {
		log.Fatal(err)
	}

	// Verification raster: 10 px per module, quiet zone 4, centre cleared.
	const s, qz = 10, 4
	side := (n + 2*qz) * s
	img := image.NewGray(image.Rect(0, 0, side, side))
	for i := range img.Pix {
		img.Pix[i] = 0xF0
	}
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			if dark(x, y) {
				for dy := 0; dy < s; dy++ {
					for dx := 0; dx < s; dx++ {
						img.SetGray((x+qz)*s+dx, (y+qz)*s+dy, color.Gray{0x10})
					}
				}
			}
		}
	}
	f, err := os.Create(filepath.Join(os.TempDir(), "demon-attack-qr-check.png"))
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("%s: %d×%d modules (version %d, level H), centre %d×%d cleared; check PNG %s\n",
		filepath.Join(*out, "qr.svg"), n, n, (n-17)/4, e, e, f.Name())
}
