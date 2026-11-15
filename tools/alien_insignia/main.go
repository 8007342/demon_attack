// Command alien_insignia lays out the alien-insignia review sheets
// (openspec/changes/alien-insignia, docs/styleguide/alien-troops.md).
//
// It composes the proposed rank insignia, force-shield segments and status
// rims onto the real flight cells of assets/images/combat.png, so the
// operator judges them on the shipped art at phone scale. Standard library
// only, CPU only, byte-identical output. Go, not Lua: Lua has no PNG codec
// in the forge and the sibling art tools (tools/ground_blocks,
// tools/sentinel_silhouettes) are Go.
//
//	go run . sheets -root ../..          # writes art/contact/alien-insignia-*.png
//	go run . atlas  -root ../..          # assets/images/insignia.png + lib/game/insignia_atlas.dart
//	go run . probe  -root ../.. -kind 1  # gridded 8x enlargement of one cell
//	go run . montage -out x.png -cols 3 -scale 1 a.png b.png ...
package main

import (
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: alien_insignia sheets|atlas|probe|montage [flags]")
		os.Exit(2)
	}
	verb, args := os.Args[1], os.Args[2:]
	fs := flag.NewFlagSet(verb, flag.ExitOnError)
	root := fs.String("root", ".", "repository root")
	kind := fs.Int("kind", 0, "species (probe)")
	out := fs.String("out", "", "output png (probe, montage)")
	cols := fs.Int("cols", 3, "montage columns")
	scale := fs.Int("scale", 1, "montage nearest scale")
	_ = fs.Parse(args)
	switch verb {
	case "sheets":
		atlas := mustLoad(filepath.Join(*root, "assets/images/combat.png"))
		dir := filepath.Join(*root, "art/contact")
		mustSave(filepath.Join(dir, "alien-insignia-ranks.png"), ranksSheet(atlas))
		mustSave(filepath.Join(dir, "alien-insignia-shields.png"), shieldsSheet(atlas))
		mustSave(filepath.Join(dir, "alien-insignia-phone.png"), phoneSheet(atlas))
		mustSave(filepath.Join(dir, "alien-insignia-glyphs.png"), glyphSheet())
	case "atlas":
		writeAtlas(*root)
	case "probe":
		atlas := mustLoad(filepath.Join(*root, "assets/images/combat.png"))
		c := cell(atlas, *kind, 0, glideCol)
		big := newCanvas(64*8, 64*8, color.NRGBA{30, 28, 44, 255})
		big.blit(c, 0, 0, 8)
		for i := 0; i < 64; i += 4 {
			for p := 0; p < 64*8; p++ {
				big.img.SetNRGBA(i*8, p, color.NRGBA{90, 90, 120, 255})
				big.img.SetNRGBA(p, i*8, color.NRGBA{90, 90, 120, 255})
			}
		}
		mustSave(*out, big.img)
	case "montage":
		var imgs []*image.NRGBA
		for _, p := range fs.Args() {
			imgs = append(imgs, mustLoad(p))
		}
		mustSave(*out, montage(imgs, *cols, *scale))
	default:
		fmt.Fprintln(os.Stderr, "unknown verb", verb)
		os.Exit(2)
	}
}

func mustLoad(path string) *image.NRGBA {
	f, err := os.Open(path)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	src, err := png.Decode(f)
	if err != nil {
		panic(fmt.Errorf("%s: %w", path, err))
	}
	b := src.Bounds()
	dst := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			dst.Set(x, y, src.At(b.Min.X+x, b.Min.Y+y))
		}
	}
	return dst
}

func mustSave(path string, img image.Image) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		panic(err)
	}
	f, err := os.Create(path)
	if err != nil {
		panic(err)
	}
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	if err := enc.Encode(f, img); err != nil {
		panic(err)
	}
	if err := f.Close(); err != nil {
		panic(err)
	}
	fmt.Println("wrote", path)
}

func montage(imgs []*image.NRGBA, cols, scale int) *image.NRGBA {
	w, h := 0, 0
	for _, m := range imgs {
		w = max(w, m.Bounds().Dx()*scale)
		h = max(h, m.Bounds().Dy()*scale)
	}
	rows := (len(imgs) + cols - 1) / cols
	c := newCanvas(cols*(w+8)+8, rows*(h+8)+8, bg)
	for i, m := range imgs {
		c.blit(m, 8+(i%cols)*(w+8), 8+(i/cols)*(h+8), scale)
	}
	return c.img
}
