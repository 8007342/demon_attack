// gifstrip packs a directory of PNG frames (sorted by name) into one
// looping GIF for review clips (carrier-render-engine).
//
//	go run ./tools/gifstrip -scale 0.6 -delay 12 -crop 0,0,360,440 OUT.gif DIR
//
// The palette is the 255 most common colours of all frames (RGB at 5 bits
// per channel), dithered with Floyd–Steinberg; stdlib only.
package main

import (
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"image/png"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func main() {
	scale := flag.Float64("scale", 0.6, "output scale")
	delay := flag.Int("delay", 12, "frame delay (1/100 s)")
	crop := flag.String("crop", "", "x,y,w,h crop of each frame (source px)")
	flag.Parse()
	if flag.NArg() != 2 {
		fmt.Fprintln(os.Stderr, "usage: gifstrip [-scale s] [-delay cs] [-crop x,y,w,h] OUT.gif DIR")
		os.Exit(2)
	}
	out, dir := flag.Arg(0), flag.Arg(1)
	names, err := filepath.Glob(filepath.Join(dir, "*.png"))
	if err != nil || len(names) == 0 {
		fmt.Fprintln(os.Stderr, "no frames in", dir)
		os.Exit(1)
	}
	sort.Strings(names)
	var frames []*image.RGBA
	for _, n := range names {
		f, err := os.Open(n)
		if err != nil {
			panic(err)
		}
		img, err := png.Decode(f)
		f.Close()
		if err != nil {
			panic(err)
		}
		r := img.Bounds()
		if *crop != "" {
			p := strings.Split(*crop, ",")
			v := make([]int, 4)
			for i := range v {
				v[i], _ = strconv.Atoi(p[i])
			}
			r = image.Rect(v[0], v[1], v[0]+v[2], v[1]+v[3]).Intersect(r)
		}
		frames = append(frames, resize(img, r, *scale))
	}
	pal := palette(frames)
	g := &gif.GIF{LoopCount: 0}
	for _, f := range frames {
		p := image.NewPaletted(f.Bounds(), pal)
		draw.FloydSteinberg.Draw(p, f.Bounds(), f, image.Point{})
		g.Image = append(g.Image, p)
		g.Delay = append(g.Delay, *delay)
	}
	w, err := os.Create(out)
	if err != nil {
		panic(err)
	}
	defer w.Close()
	if err := gif.EncodeAll(w, g); err != nil {
		panic(err)
	}
	fmt.Printf("%s: %d frames %dx%d\n", out, len(frames), frames[0].Bounds().Dx(), frames[0].Bounds().Dy())
}

// resize box-filters region r of img by s.
func resize(img image.Image, r image.Rectangle, s float64) *image.RGBA {
	w, h := int(float64(r.Dx())*s), int(float64(r.Dy())*s)
	dst := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			x0, y0 := r.Min.X+int(float64(x)/s), r.Min.Y+int(float64(y)/s)
			x1, y1 := r.Min.X+int(float64(x+1)/s), r.Min.Y+int(float64(y+1)/s)
			if x1 <= x0 {
				x1 = x0 + 1
			}
			if y1 <= y0 {
				y1 = y0 + 1
			}
			var sr, sg, sb, n uint32
			for yy := y0; yy < y1; yy++ {
				for xx := x0; xx < x1; xx++ {
					cr, cg, cb, _ := img.At(xx, yy).RGBA()
					sr, sg, sb, n = sr+cr>>8, sg+cg>>8, sb+cb>>8, n+1
				}
			}
			dst.Set(x, y, color.RGBA{uint8(sr / n), uint8(sg / n), uint8(sb / n), 255})
		}
	}
	return dst
}

// palette: the 255 most common 5-bit RGB buckets (bucket means), plus black.
func palette(frames []*image.RGBA) color.Palette {
	type acc struct{ r, g, b, n uint64 }
	hist := map[uint32]*acc{}
	for _, f := range frames {
		p := f.Pix
		for i := 0; i < len(p); i += 4 {
			k := uint32(p[i]>>3)<<10 | uint32(p[i+1]>>3)<<5 | uint32(p[i+2]>>3)
			a := hist[k]
			if a == nil {
				a = &acc{}
				hist[k] = a
			}
			a.r += uint64(p[i])
			a.g += uint64(p[i+1])
			a.b += uint64(p[i+2])
			a.n++
		}
	}
	keys := make([]uint32, 0, len(hist))
	for k := range hist {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool { return hist[keys[i]].n > hist[keys[j]].n })
	pal := color.Palette{color.RGBA{0, 0, 0, 255}}
	for _, k := range keys {
		if len(pal) == 256 {
			break
		}
		a := hist[k]
		pal = append(pal, color.RGBA{uint8(a.r / a.n), uint8(a.g / a.n), uint8(a.b / a.n), 255})
	}
	return pal
}
