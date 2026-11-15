package main

// control: the rig control strips for the Wan2.2 VACE in-between jobs
// (art/workflows/sprites/inbetween-wan-vace*.json, input $control).
//
// A strip is N frames of 480 x 480 side by side. Each frame is one of the
// block's own grid key frames for the clip (rig shading on mid grey, the
// "generate here" value for VACE), scaled by one integer factor and placed
// at one anchor for the whole clip, so the generated motion stays on the
// rig's contact row and silhouette. Cycles (move, walk, run) loop with each
// key held for two frames; one-shot clips (arrive, fall, special, ...)
// stretch their keys evenly across the strip.
//
// Clip names are the families' "inbetweens" entries: "walk.h090" and
// "move.h135" name a heading; "arrive", "fall", "strideOver", "flourish",
// "aim" take the heading the block stores them at; "special.<what>" is the
// unit's special row.

import (
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"demonattack/tools/pixelgrid"
)

const controlSize = 480

var controlGrey = color.NRGBA{127, 127, 127, 255}

func cyclicClip(state string) bool {
	return state == "walk" || state == "move" || state == "run"
}

// clipCells returns the key cells of one clip in frame order.
func clipCells(cells []Cell, id, clip string) ([]Cell, string, error) {
	state, head := clip, ""
	if i := strings.Index(clip, ".h"); i > 0 {
		state, head = clip[:i], clip[i+2:]
	}
	if strings.HasPrefix(state, "special.") {
		state = "special"
	}
	hpat := `h\d{3}`
	if head != "" {
		hpat = "h" + regexp.QuoteMeta(head)
	}
	re := regexp.MustCompile(`^` + regexp.QuoteMeta(id) + `\.hull\.` + regexp.QuoteMeta(state) + `\.` + hpat + `\.f(\d+)$`)
	type kf struct {
		f int
		c Cell
	}
	var ks []kf
	for _, c := range cells {
		if c.Overlay {
			continue
		}
		if m := re.FindStringSubmatch(c.Name); m != nil {
			f, _ := strconv.Atoi(m[1])
			ks = append(ks, kf{f, c})
		}
	}
	if len(ks) == 0 {
		return nil, state, fmt.Errorf("%s: no key cells for clip %q", id, clip)
	}
	sort.Slice(ks, func(a, b int) bool { return ks[a].f < ks[b].f })
	out := make([]Cell, len(ks))
	for i := range ks {
		out[i] = ks[i].c
	}
	return out, state, nil
}

// controlSequence maps N output frames onto K keys.
func controlSequence(k, n int, cyclic bool) []int {
	seq := make([]int, n)
	for i := range seq {
		if cyclic {
			seq[i] = (i / 2) % k
		} else {
			seq[i] = min(k-1, i*k/n)
		}
	}
	return seq
}

func (p *Project) controlStrip(u unitRef, clip string, n int) (*image.NRGBA, error) {
	keys, state, err := clipCells(p.cellsOf(u), u.Spec.ID, clip)
	if err != nil {
		return nil, err
	}
	b := p.builder(u)
	pal := p.Pals[u.faction()]
	sector := p.masterSector(u)
	// Paint every key, then one bounding box and one scale for the clip.
	imgs := make([]*image.NRGBA, len(keys))
	x0, y0, x1, y1 := 1<<30, 1<<30, -1, -1
	for i := range keys {
		c := keys[i]
		w, h := c.F.W, c.F.H
		img := image.NewNRGBA(image.Rect(0, 0, w, h))
		pal.paintCell(img, &c, 0, 0, sector, b.Rig.Seed)
		imgs[i] = img
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				if img.NRGBAAt(x, y).A != 0 {
					x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
				}
			}
		}
	}
	if x1 < 0 {
		return nil, fmt.Errorf("%s %s: empty key frames", u.Spec.ID, clip)
	}
	bw, bh := x1-x0+1, y1-y0+1
	k := max(1, controlSize*4/5/max(bw, bh))
	ox := (controlSize - bw*k) / 2
	oy := (controlSize - bh*k) / 2
	out := image.NewNRGBA(image.Rect(0, 0, controlSize*n, controlSize))
	fill(out, out.Bounds(), controlGrey)
	for i, ki := range controlSequence(len(keys), n, cyclicClip(state)) {
		src := imgs[ki]
		for y := y0; y <= y1; y++ {
			for x := x0; x <= x1; x++ {
				col := src.NRGBAAt(x, y)
				if col.A == 0 {
					continue
				}
				col.A = 255
				for dy := 0; dy < k; dy++ {
					for dx := 0; dx < k; dx++ {
						out.SetNRGBA(i*controlSize+ox+(x-x0)*k+dx, oy+(y-y0)*k+dy, col)
					}
				}
			}
		}
	}
	return out, nil
}

// cmdControl [ids...]: every inbetween clip of the named units (all units
// when none are named), at 17 and 33 frames, into $BLOCKS_WORK/control.
func cmdControl(args []string) {
	p := loadProject()
	n := 0
	for _, u := range p.units() {
		if len(args) > 0 && !contains(args, u.Spec.ID) {
			continue
		}
		for _, clip := range u.Spec.Inbetweens {
			for _, frames := range []int{17, 33} {
				img, err := p.controlStrip(u, clip, frames)
				must(err)
				path := filepath.Join(workDir(), "control", u.Spec.ID, fmt.Sprintf("%s.%s.f%d.png", u.Spec.ID, clip, frames))
				must(os.MkdirAll(filepath.Dir(path), 0o755))
				must(pixelgrid.WritePNG(path, img))
				n++
			}
		}
	}
	fmt.Println(n, "control strips ->", filepath.Join(workDir(), "control"))
}
