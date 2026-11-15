// Command sentinel_silhouettes derives the far foreshadow silhouette sheet
// (openspec/changes/atmosphere-and-swarms design section 5, task 5.1) from
// the sentinels' own flight frames in assets/images/sentinel-effects.png.
//
// Go standard library only, no GPU, byte-identical on every run:
//
//	go run .   -> assets/images/sentinel-silhouettes.png,
//	              lib/game/sentinel_silhouette_atlas.dart and
//	              art/contact/sentinel-silhouettes.png
//
// Per species (0 shield warden, 1 armoured colossus): the level full-span
// glide pose (flight column 2) is banked through 8 frames from hard left
// to hard right (rotation about the body, the dipping wing foreshortened,
// the rising wing slightly long), reduced to its shape, and softened at two
// blur levels (near: the hand-off and the last wave out; far: the murk).
// Alpha is stepped to 8 levels so the edge keeps a pixel look. The body is
// one near-black colour; the runtime tints it with the fog (srcIn).
//
// Why CPU, not GPU: the sheet is a shape, not a texture. Deriving it from
// the sprite of record keeps every frame's outline exactly the sentinel's
// (the arrival cross-fades from silhouette to body), and no committed
// workflow renders a banked rig pose.
package main

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	srcW, srcH = 128, 64 // sentinel-effects cell
	srcCol     = 2       // STROKE[2]: level, full span
	cellW      = 160     // silhouette cell (room for bank and blur)
	cellH      = 96
	frames     = 8
	maxBankDeg = 22.0
	dipShrink  = .24 // dipping wing foreshortened at full bank
	riseGrow   = .05 // rising wing a touch longer
	alphaSteps = 8
)

var blurSigma = [2]float64{1.0, 2.1}

var body = color.NRGBA{0x08, 0x07, 0x0E, 255}

var root string

func fail(err error) {
	fmt.Fprintln(os.Stderr, "sentinel_silhouettes:", err)
	os.Exit(1)
}

func must(err error) {
	if err != nil {
		fail(err)
	}
}

func findRoot() string {
	d, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(d, "pubspec.yaml")); err == nil {
			return d
		}
		p := filepath.Dir(d)
		if p == d {
			fail(errors.New("run inside the demon_attack checkout"))
		}
		d = p
	}
}

func writePNG(p string, im image.Image) {
	must(os.MkdirAll(filepath.Dir(p), 0o755))
	var buf bytes.Buffer
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	must(enc.Encode(&buf, im))
	must(os.WriteFile(p, buf.Bytes(), 0o644))
}

// bankOf returns frame f's bank in -1..1 (f 0 hard left .. 7 hard right).
func bankOf(f int) float64 { return (float64(f) - 3.5) / 3.5 }

// mask is the source flight frame's shape (alpha >= 128).
func mask(src image.Image, species int) [srcH][srcW]bool {
	var m [srcH][srcW]bool
	for y := 0; y < srcH; y++ {
		for x := 0; x < srcW; x++ {
			_, _, _, a := src.At(srcCol*srcW+x, species*srcH+y).RGBA()
			m[y][x] = a>>8 >= 128
		}
	}
	return m
}

// banked coverage (0..1, 4x4 supersampled) of the shape at bank b, cell
// space; the source point (64, 32) lands on the cell centre, so the
// runtime's anchors (eyes) keep their offsets before the bank rotation.
func banked(m [srcH][srcW]bool, b float64) []float64 {
	// Pivot on the cell centre (the runtime anchors the sprite there).
	px, py := float64(srcW)/2, float64(srcH)/2
	th := b * maxBankDeg * math.Pi / 180
	sn, cs := math.Sin(th), math.Cos(th)
	ox, oy := 0.0, 0.0
	cov := make([]float64, cellW*cellH)
	const ss = 4
	for y := 0; y < cellH; y++ {
		for x := 0; x < cellW; x++ {
			hit := 0
			for j := 0; j < ss; j++ {
				for i := 0; i < ss; i++ {
					// Cell point relative to the pivot.
					qx := float64(x) + (float64(i)+.5)/ss - float64(cellW)/2 - ox
					qy := float64(y) + (float64(j)+.5)/ss - float64(cellH)/2 - oy
					// Un-rotate.
					dx, dy := qx*cs+qy*sn, -qx*sn+qy*cs
					// Positive bank rotates clockwise: the right wing dips.
					if dx*b > 0 {
						dx /= 1 - dipShrink*math.Abs(b)
					} else {
						dx /= 1 + riseGrow*math.Abs(b)
					}
					sx, sy := int(math.Floor(px+dx)), int(math.Floor(py+dy))
					if sx >= 0 && sy >= 0 && sx < srcW && sy < srcH && m[sy][sx] {
						hit++
					}
				}
			}
			cov[y*cellW+x] = float64(hit) / (ss * ss)
		}
	}
	return cov
}

func blur(a []float64, sigma float64) []float64 {
	r := int(math.Ceil(sigma * 3))
	k := make([]float64, 2*r+1)
	var s float64
	for i := -r; i <= r; i++ {
		k[i+r] = math.Exp(-float64(i*i) / (2 * sigma * sigma))
		s += k[i+r]
	}
	for i := range k {
		k[i] /= s
	}
	tmp := make([]float64, len(a))
	out := make([]float64, len(a))
	for y := 0; y < cellH; y++ {
		for x := 0; x < cellW; x++ {
			var v float64
			for i := -r; i <= r; i++ {
				if xx := x + i; xx >= 0 && xx < cellW {
					v += a[y*cellW+xx] * k[i+r]
				}
			}
			tmp[y*cellW+x] = v
		}
	}
	for y := 0; y < cellH; y++ {
		for x := 0; x < cellW; x++ {
			var v float64
			for i := -r; i <= r; i++ {
				if yy := y + i; yy >= 0 && yy < cellH {
					v += tmp[yy*cellW+x] * k[i+r]
				}
			}
			out[y*cellW+x] = v
		}
	}
	return out
}

func main() {
	root = findRoot()
	f, err := os.Open(filepath.Join(root, "assets/images/sentinel-effects.png"))
	must(err)
	src, err := png.Decode(f)
	f.Close()
	must(err)
	sheet := image.NewNRGBA(image.Rect(0, 0, frames*cellW, 4*cellH))
	for sp := 0; sp < 2; sp++ {
		m := mask(src, sp)
		for fr := 0; fr < frames; fr++ {
			cov := banked(m, bankOf(fr))
			for lv := 0; lv < 2; lv++ {
				a := blur(cov, blurSigma[lv])
				row := sp*2 + lv
				for y := 0; y < cellH; y++ {
					for x := 0; x < cellW; x++ {
						v := math.Round(math.Min(1, a[y*cellW+x]*1.08) * alphaSteps)
						if v <= 0 {
							continue
						}
						c := body
						c.A = uint8(math.Round(v / alphaSteps * 255))
						sheet.SetNRGBA(fr*cellW+x, row*cellH+y, c)
					}
				}
			}
		}
	}
	writePNG(filepath.Join(root, "assets/images/sentinel-silhouettes.png"), sheet)
	writeDart()
	contact(src, sheet)
	fmt.Println("packed assets/images/sentinel-silhouettes.png", sheet.Bounds().Dx(), sheet.Bounds().Dy())
}

func writeDart() {
	var b strings.Builder
	b.WriteString("// GENERATED by tools/sentinel_silhouettes — do not edit by hand.\n")
	b.WriteString("// Source: assets/images/sentinel-effects.png (flight column 2).\n\n")
	b.WriteString("import 'dart:ui' show Rect;\n\n")
	b.WriteString("/// The far foreshadow silhouette of a coming sentinel\n")
	b.WriteString("/// (atmosphere-and-swarms design section 5): per species 8 banking frames\n")
	b.WriteString("/// x 2 blur levels in assets/images/sentinel-silhouettes.png. One\n")
	b.WriteString("/// near-black body colour with stepped alpha: tint it (srcIn).\n")
	b.WriteString("abstract final class SentinelSilhouetteAtlas {\n")
	b.WriteString("  static const file = 'sentinel-silhouettes.png';\n")
	fmt.Fprintf(&b, "  static const cellW = %d, cellH = %d, frames = %d;\n", cellW, cellH, frames)
	b.WriteString("\n  /// Bank of each frame in degrees (clockwise positive), for anchors such\n")
	b.WriteString("  /// as the eyes, which rotate about the cell centre.\n")
	b.WriteString("  static const bankDeg = <double>[")
	for i := 0; i < frames; i++ {
		if i > 0 {
			b.WriteString(", ")
		}
		fmt.Fprintf(&b, "%.2f", bankOf(i)*maxBankDeg)
	}
	b.WriteString("];\n\n")
	b.WriteString("  /// Frame for a bank in -1..1 (hard left .. hard right).\n")
	b.WriteString("  static int frameFor(double bank) =>\n")
	b.WriteString("      ((bank.clamp(-1.0, 1.0) + 1) / 2 * (frames - 1)).round();\n\n")
	b.WriteString("  /// Cell of [species] (0 shield, 1 armoured) at [frame]; [blur] 0 near,\n")
	b.WriteString("  /// 1 far. The cell centre is the sentinel cell's centre.\n")
	b.WriteString("  static Rect cell(int species, int frame, int blur) => Rect.fromLTWH(\n")
	b.WriteString("      frame * cellW * 1.0, (species * 2 + blur) * cellH * 1.0,\n")
	b.WriteString("      cellW * 1.0, cellH * 1.0);\n")
	b.WriteString("}\n")
	must(os.WriteFile(filepath.Join(root, "lib/game/sentinel_silhouette_atlas.dart"), []byte(b.String()), 0o644))
	dartFormat(filepath.Join(root, "lib/game/sentinel_silhouette_atlas.dart"))
}

// contact: CP sheet. Per species and blur level, the 8 frames over a fog
// strip (sector fog tints in turn) with the source flight frame at left; a
// last row composes the far frames at 0.75x over a horizon gradient as the
// runtime shows them (body lerped toward the fog, warm rim, two eyes).
func contact(src image.Image, sheet *image.NRGBA) {
	fogs := []color.NRGBA{{0x3A, 0x44, 0x58, 255}, {0x3D, 0x35, 0x50, 255}, {0x46, 0x30, 0x2C, 255}, {0x2E, 0x3A, 0x35, 255}}
	W := 8 + srcW + 8 + frames*cellW + 8
	H := 8 + 4*(cellH+6) + 2*(cellH+6) + 8
	img := image.NewNRGBA(image.Rect(0, 0, W, H))
	for i := range img.Pix {
		img.Pix[i] = []uint8{0x0B, 0x0A, 0x12, 255}[i%4]
	}
	over := func(x, y int, c color.NRGBA, a float64) {
		d := img.NRGBAAt(x, y)
		m := func(s, t uint8) uint8 { return uint8(float64(s)*a + float64(t)*(1-a)) }
		img.SetNRGBA(x, y, color.NRGBA{m(c.R, d.R), m(c.G, d.G), m(c.B, d.B), 255})
	}
	for row := 0; row < 4; row++ {
		oy := 8 + row*(cellH+6)
		fog := fogs[row]
		for y := 0; y < cellH; y++ {
			for x := 4; x < W-4; x++ {
				img.SetNRGBA(x, oy+y, fog)
			}
		}
		sp := row / 2
		for y := 0; y < srcH; y++ {
			for x := 0; x < srcW; x++ {
				c := color.NRGBAModel.Convert(src.At(srcCol*srcW+x, sp*srcH+y)).(color.NRGBA)
				if c.A > 0 {
					over(8+x, oy+16+y, color.NRGBA{c.R, c.G, c.B, 255}, float64(c.A)/255)
				}
			}
		}
		for fr := 0; fr < frames; fr++ {
			for y := 0; y < cellH; y++ {
				for x := 0; x < cellW; x++ {
					c := sheet.NRGBAAt(fr*cellW+x, row*cellH+y)
					if c.A > 0 {
						over(16+srcW+fr*cellW+x, oy+y, c, float64(c.A)/255)
					}
				}
			}
		}
	}
	// In-game look: far blur, body 70 % toward black from the fog, at a
	// sky-to-horizon gradient, opacity .92; warm rim offset (-1.5, -1.5).
	for sp := 0; sp < 2; sp++ {
		oy := 8 + 4*(cellH+6) + sp*(cellH+6)
		fog := fogs[sp*2]
		for y := 0; y < cellH; y++ {
			t := float64(y) / cellH
			c := color.NRGBA{uint8(float64(fog.R) * (.55 + .45*t)), uint8(float64(fog.G) * (.55 + .45*t)), uint8(float64(fog.B) * (.55 + .45*t)), 255}
			for x := 4; x < W-4; x++ {
				img.SetNRGBA(x, oy+y, c)
			}
		}
		bodyC := color.NRGBA{uint8(float64(fog.R) * .3), uint8(float64(fog.G) * .3), uint8(float64(fog.B) * .3), 255}
		rim := color.NRGBA{0xE2, 0xA4, 0x6E, 255}
		for fr := 0; fr < frames; fr++ {
			ox := 16 + srcW + fr*cellW
			for pass := 0; pass < 2; pass++ {
				for y := 0; y < cellH; y++ {
					for x := 0; x < cellW; x++ {
						a := float64(sheet.NRGBAAt(fr*cellW+x, (sp*2+1)*cellH+y).A) / 255
						if a == 0 {
							continue
						}
						if pass == 0 {
							over(ox+x-1, oy+y-1, rim, .26*a)
						} else {
							over(ox+x, oy+y, bodyC, .92*a)
						}
					}
				}
			}
			th := bankOf(fr) * maxBankDeg * math.Pi / 180
			for _, s := range []float64{-1, 1} {
				ex, ey := s*5.5, -6.0
				rx, ry := ex*math.Cos(th)-ey*math.Sin(th), ex*math.Sin(th)+ey*math.Cos(th)
				cx, cy := ox+cellW/2+int(math.Round(rx)), oy+cellH/2+int(math.Round(ry))
				img.SetNRGBA(cx, cy, color.NRGBA{0xFF, 0xE7, 0xA8, 255})
				img.SetNRGBA(cx+1, cy, color.NRGBA{0xFF, 0x9A, 0x3C, 255})
			}
		}
	}
	writePNG(filepath.Join(root, "art/contact/sentinel-silhouettes.png"), img)
}

// dartFormat keeps the generated Dart in `dart format` shape (the analyzer
// and CI check it); best effort when dart is not on PATH.
func dartFormat(p string) {
	if _, err := exec.LookPath("dart"); err != nil {
		return
	}
	_ = exec.Command("dart", "format", p).Run()
}
