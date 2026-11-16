package main

// Layer families (rigkit render.frame + a family "layers" block): every hull is rendered in one
// fixed frame, so the id pass cuts a hull's hero pick into whole, aligned cells, one per module
// (slot or slot.set), and a variant is drawn by stacking cells in layers.order. The first
// hull in layers.hulls that has a module supplies its cell (the shared base comes from a
// hull of its own). Commands:
//
//	rigsheet layeratlas FAMILY.json RIG COLS OUT.png [OUT.dart CLASS]
//	rigsheet layersheet FAMILY.json RIG OUT.png TITLE
//	rigsheet layercands FAMILY.json RIG OUT.png TITLE HULL=RAW[,RAW...]...

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"
	"strings"
)

type layerFamily struct {
	Layers struct {
		Order []string        `json:"order"`
		Hulls []string        `json:"hulls"`
		Ink   map[string]bool `json:"ink"`
		// Colours: "palette" (default) quantises to the family ramps, hard alpha and ink (pixel
		// art); "keep" keeps the area-averaged paint and its coverage, no ink (vector-like badges)
		Colours string `json:"colours"`
	} `json:"layers"`
	Selected map[string]json.RawMessage `json:"selected"`
}

type layerPick struct {
	S0       string `json:"S0"`
	Register string `json:"register"`
}

type layerCell struct {
	ID, Hull, Slot string
	Im             *image.NRGBA
}

func readLayerFamily(path string) (*layerFamily, string) {
	b, err := os.ReadFile(path)
	if err != nil {
		fail("%v", err)
	}
	var f layerFamily
	if err := json.Unmarshal(b, &f); err != nil {
		fail("%s: %v", path, err)
	}
	if len(f.Layers.Hulls) == 0 {
		fail("%s: no layers.hulls", path)
	}
	var root string
	if raw, ok := f.Selected["root"]; ok {
		json.Unmarshal(raw, &root)
	}
	return &f, root
}

func (f *layerFamily) pick(hull string) layerPick {
	var p layerPick
	if raw, ok := f.Selected[hull]; ok {
		json.Unmarshal(raw, &p)
	}
	return p
}

func (f *layerFamily) ink(slot string) bool {
	if v, ok := f.Layers.Ink[slot]; ok {
		return v
	}
	return true
}

func moduleID(in Inst) string {
	if in.Set != "" {
		return in.Slot + "." + in.Set
	}
	return in.Slot
}

// hullLayers cuts one raw of a hull into finished layer cells (module id -> image at the
// family's texel), in instance order. Inside a module's id mask the fitted paint is kept; where
// the paint is key (the edit shrank a shape) the flat hint colour fills in.
func hullLayers(f *layerFamily, r *Rig, raw string, register bool) ([]string, map[string]*image.NRGBA) {
	t := heroTag(r)
	fit := fitRawOpt(load(raw), r, "S0", t, register)
	ids := load(r.path("S0", "id", t))
	hint := load(r.path("S0", "hint", t))
	pal := readFamily(r.Family).palette()
	if f.Layers.Colours == "keep" {
		pal = nil
	}
	texel := r.maxTexel()
	var order []string
	out := map[string]*image.NRGBA{}
	for _, in := range r.Insts {
		want := hex(r.IDs[in.ID])
		lay := image.NewNRGBA(fit.Bounds())
		n := 0
		for i := 0; i < len(ids.Pix); i += 4 {
			if ids.Pix[i+3] < 128 || abs(int(ids.Pix[i])-int(want.R)) > 3 || abs(int(ids.Pix[i+1])-int(want.G)) > 3 ||
				abs(int(ids.Pix[i+2])-int(want.B)) > 3 {
				continue
			}
			src := fit.Pix[i : i+4]
			if src[3] == 0 {
				src = hint.Pix[i : i+4]
			}
			copy(lay.Pix[i:i+4], src)
			lay.Pix[i+3] = 255
			n++
		}
		if n == 0 {
			continue
		}
		id := moduleID(in)
		order = append(order, id)
		if pal == nil { // keep: area-averaged paint and coverage (smooth edges); cells stack cleanly
			// because every lower layer is whole under the one above it
			out[id] = areaScale(lay, texel/r.PPU)
		} else {
			out[id] = finishAt(lay, r, texel, pal, f.ink(in.Slot))
		}
	}
	return order, out
}

// layerCells: every module's cell, in layers.hulls order (first hull wins).
func layerCells(famPath, rigDir string) ([]layerCell, *Rig) {
	f, root := readLayerFamily(famPath)
	var cells []layerCell
	seen := map[string]bool{}
	var r0 *Rig
	for _, h := range f.Layers.Hulls {
		r := readRig(rigDir, h)
		if r0 == nil {
			r0 = r
		}
		if r.Size != r0.Size || r.Frame != r0.Frame {
			fail("%s: frame %v differs from %s %v (set render.frame)", h, r.Frame, r0.Hull, r0.Frame)
		}
		p := f.pick(h)
		if p.S0 == "" {
			fail("no pick for %s in %s", h, famPath)
		}
		order, ims := hullLayers(f, r, filepath.Join(root, p.S0), p.Register == "bbox")
		for _, id := range order {
			if seen[id] {
				continue
			}
			seen[id] = true
			cells = append(cells, layerCell{id, h, strings.SplitN(id, ".", 2)[0], ims[id]})
		}
	}
	return cells, r0
}

// paletted stores an image with at most 256 colours (alpha 0 = index 0) compactly.
func paletted(im *image.NRGBA) image.Image {
	idx := map[color.NRGBA]uint8{{}: 0}
	pal := color.Palette{color.NRGBA{}}
	p := image.NewPaletted(im.Bounds(), nil)
	for i := 0; i < len(im.Pix); i += 4 {
		c := color.NRGBA{im.Pix[i], im.Pix[i+1], im.Pix[i+2], im.Pix[i+3]}
		if c.A == 0 {
			c = color.NRGBA{}
		}
		k, ok := idx[c]
		if !ok {
			if len(pal) == 256 {
				return im
			}
			k = uint8(len(pal))
			idx[c] = k
			pal = append(pal, c)
		}
		p.Pix[i/4] = k
	}
	p.Palette = pal
	return p
}

func cmdLayerAtlas(a []string) {
	cells, r := layerCells(a[0], a[1])
	var cols int
	fmt.Sscan(a[2], &cols)
	out := a[3]
	cw, ch := cells[0].Im.Bounds().Dx(), cells[0].Im.Bounds().Dy()
	rows := (len(cells) + cols - 1) / cols
	page := image.NewNRGBA(image.Rect(0, 0, cols*cw, rows*ch))
	for i, c := range cells {
		x, y := (i%cols)*cw, (i/cols)*ch
		for yy := 0; yy < ch; yy++ {
			copy(page.Pix[(y+yy)*page.Stride+x*4:(y+yy)*page.Stride+(x+cw)*4], c.Im.Pix[yy*c.Im.Stride:(yy+1)*c.Im.Stride])
		}
	}
	save(out, paletted(page))
	if len(a) > 5 {
		f, _ := readLayerFamily(a[0])
		writeLayerDart(a[4], a[5], out, a[0], f.Layers.Order, r, cw, ch, cols, cells)
	}
	st, _ := os.Stat(out)
	fmt.Printf("layeratlas: %d cells, cell %dx%d, page %dx%d, %d bytes PNG, %d bytes resident\n",
		len(cells), cw, ch, page.Bounds().Dx(), page.Bounds().Dy(), st.Size(), page.Bounds().Dx()*page.Bounds().Dy()*4)
}

func writeLayerDart(path, class, png, fam string, order []string, r *Rig, cw, ch, cols int, cells []layerCell) {
	rel := func(p string) string {
		abs, _ := filepath.Abs(p)
		if q, err := filepath.Rel(repoRoot(), abs); err == nil && !strings.HasPrefix(q, "..") {
			return q
		}
		return p
	}
	var b strings.Builder
	fmt.Fprintf(&b, "// GENERATED by lua tools/rigkit/bake_layers.lua %s --cols %d --atlas %s --dart %s %s. Do not edit.\n",
		rel(fam), cols, rel(png), rel(path), class)
	fmt.Fprintf(&b, "// (rigkit rig.py, then tools/rigsheet layeratlas; no GPU: the hero picks are committed. See the\n")
	fmt.Fprintf(&b, "// family notes in %s and its render ledger under plan/render-runs/.)\n\n", rel(fam))
	fmt.Fprintf(&b, "/// Composable layer cells of %s: every cell shares one frame, so a variant\n", rel(png))
	fmt.Fprintf(&b, "/// is drawn by stacking whole cells.\n")
	fmt.Fprintf(&b, "abstract final class %s {\n", class)
	fmt.Fprintf(&b, "  static const asset = '%s';\n", rel(png))
	fmt.Fprintf(&b, "  static const cellWidth = %d, cellHeight = %d;\n\n", cw, ch)
	fmt.Fprintf(&b, "  /// Layer id -> (column, row) of its cell. Draw order: %s.\n", strings.Join(order, ", "))
	fmt.Fprintf(&b, "  static const cells = <String, (int, int)>{\n")
	for i, c := range cells {
		fmt.Fprintf(&b, "    '%s': (%d, %d),\n", c.ID, i%cols, i/cols)
	}
	fmt.Fprintf(&b, "  };\n}\n")
	if err := os.WriteFile(path, []byte(b.String()), 0o644); err != nil {
		fail("%v", err)
	}
}

// compose stacks the cells of one variant in layers.order (missing layers are skipped).
func compose(order []string, get func(slot string) *image.NRGBA, cw, ch int) *image.NRGBA {
	out := image.NewNRGBA(image.Rect(0, 0, cw, ch))
	for _, s := range order {
		if im := get(s); im != nil {
			blit(out, im, 0, 0, 1)
		}
	}
	return out
}

// shown draws im scaled to width w px (area average down, bilinear up), like a filtered drawImageRect.
func shown(im *image.NRGBA, w int) *image.NRGBA {
	k := float64(w) / float64(im.Bounds().Dx())
	if k < 1 {
		return areaScale(im, k)
	}
	return resize(im, w, round(float64(im.Bounds().Dy())*k))
}

var (
	cardBg  = hex("#101827")
	cardRow = hex("#0B1220")
	checkA  = hex("#2A2F3A")
	checkB  = hex("#20242E")
)

func checker(dst *image.NRGBA, x, y, w, h int) {
	for yy := 0; yy < h; yy++ {
		for xx := 0; xx < w; xx++ {
			c := checkA
			if (xx/6+yy/6)%2 == 1 {
				c = checkB
			}
			dst.SetNRGBA(x+xx, y+yy, c)
		}
	}
}

func layerVariants(cells []layerCell, order []string) ([]string, map[string]map[string]*image.NRGBA) {
	byID := map[string]*image.NRGBA{}
	var vs []string
	seen := map[string]bool{}
	for _, c := range cells {
		byID[c.ID] = c.Im
		if i := strings.Index(c.ID, "."); i > 0 && !seen[c.ID[i+1:]] {
			seen[c.ID[i+1:]] = true
			vs = append(vs, c.ID[i+1:])
		}
	}
	out := map[string]map[string]*image.NRGBA{}
	for _, v := range vs {
		m := map[string]*image.NRGBA{}
		for _, s := range order {
			if im, ok := byID[s+"."+v]; ok {
				m[s] = im
			} else if im, ok := byID[s]; ok {
				m[s] = im
			}
		}
		out[v] = m
	}
	return vs, out
}

func cmdLayerSheet(a []string) {
	cells, _ := layerCells(a[0], a[1])
	f, _ := readLayerFamily(a[0])
	order := f.Layers.Order
	cw, ch := cells[0].Im.Bounds().Dx(), cells[0].Im.Bounds().Dy()
	vs, vm := layerVariants(cells, order)
	sizes := []int{20, 40, 36, 72, 108}
	labels := []string{"20 PX", "20 X2", "36 PX", "36 X2", "36 X3"}
	rowH := 2*ch + 24
	colX := 2*cw + 40
	sw := 0
	for _, s := range sizes {
		sw += s + 14
	}
	W := colX + sw + len(order)*(cw+10) + 30
	H := 40 + len(vs)*rowH + 140
	page := newCanvas(W, H, cardRow)
	text(page, 12, 10, 3, a[3], ink)
	text(page, 12, 28, 1, fmt.Sprintf("CELL %dX%d - COMPOSITE X2 - DISPLAY SIZES (WIDTH, FILTERED) - LAYERS: %s", cw, ch, strings.ToUpper(strings.Join(order, ", "))), dim)
	for i, v := range vs {
		y := 40 + i*rowH
		comp := compose(order, func(s string) *image.NRGBA { return vm[v][s] }, cw, ch)
		fill(page, image.Rect(8, y, 8+2*cw+16, y+2*ch+16), cardBg)
		blit(page, comp, 16, y+8, 2)
		text(page, 16, y+2*ch+14, 1, strings.ToUpper(v), ink)
		x := colX
		for k, s := range sizes {
			im := shown(comp, s)
			fill(page, image.Rect(x-4, y+8, x+s+4, y+8+im.Bounds().Dy()+8), cardBg)
			blit(page, im, x, y+12, 1)
			text(page, x, y+8+im.Bounds().Dy()+12, 1, labels[k], dim)
			x += s + 14
		}
		x += 10
		for _, s := range order {
			checker(page, x, y+8, cw, ch)
			if im := vm[v][s]; im != nil {
				blit(page, im, x, y+8, 1)
				text(page, x, y+ch+12, 1, strings.ToUpper(s), dim)
			} else {
				text(page, x, y+ch+12, 1, "(NONE)", dim)
			}
			x += cw + 10
		}
	}
	// a scoreboard row: every variant at 20 px and at 36 px, side by side
	y := 40 + len(vs)*rowH + 8
	text(page, 12, y, 2, "IN A ROW: 20 PX, 36 PX (1X), 20 PX AT DPR 2", ink)
	y += 18
	fill(page, image.Rect(8, y, W-8, y+110), cardBg)
	for i, v := range vs {
		comp := compose(order, func(s string) *image.NRGBA { return vm[v][s] }, cw, ch)
		blit(page, shown(comp, 20), 16+i*26, y+8, 1)
		blit(page, shown(comp, 36), 200+i*42, y+8, 1)
		blit(page, shown(comp, 40), 500+i*46, y+8, 1)
	}
	save(a[2], page)
	fmt.Printf("layersheet: %d variants -> %s\n", len(vs), a[2])
}

// layercands: one row per hull, each candidate raw beside its cut stacked over the picked
// base, at x2 and at 20 / 36 px; the pick (family .selected) is outlined.
func cmdLayerCands(a []string) {
	f, root := readLayerFamily(a[0])
	order := f.Layers.Order
	var base *image.NRGBA
	h0 := f.Layers.Hulls[0]
	if bp := f.pick(h0); bp.S0 != "" {
		_, ims := hullLayers(f, readRig(a[1], h0), filepath.Join(root, bp.S0), bp.Register == "bbox")
		base = ims["base"]
	}
	type row struct {
		hull string
		raws []string
	}
	var rows []row
	most := 0
	for _, s := range a[4:] {
		h, list, ok := strings.Cut(s, "=")
		if !ok {
			fail("layercands: want HULL=RAW[,RAW...], got %s", s)
		}
		rows = append(rows, row{h, strings.Split(list, ",")})
		most = max(most, len(rows[len(rows)-1].raws))
	}
	r0 := readRig(a[1], h0)
	cw, ch := round(float64(r0.Size[0])*r0.maxTexel()/r0.PPU), round(float64(r0.Size[1])*r0.maxTexel()/r0.PPU)
	rw := 2 * cw
	rh := round(float64(rw) * float64(r0.Size[1]) / float64(r0.Size[0]))
	colW := rw + 2*cw + 30
	rowH := max(rh, 2*ch) + 90
	W := 24 + most*colW
	H := 40 + len(rows)*rowH
	page := newCanvas(W, H, cardRow)
	text(page, 12, 10, 3, a[3], ink)
	text(page, 12, 28, 1, "PER CANDIDATE: THE RAW, ITS ID-PASS CUT STACKED OVER THE PICKED BASE (X2), AT 20 AND 36 PX. OUTLINED: THE PICK.", dim)
	for j, rw0 := range rows {
		r := readRig(a[1], rw0.hull)
		pick := filepath.Base(f.pick(rw0.hull).S0)
		y := 44 + j*rowH
		for i, p := range rw0.raws {
			x := 12 + i*colW
			blit(page, shown(load(p), rw), x, y, 1)
			_, ims := hullLayers(f, r, p, true)
			if base != nil {
				ims["base"] = base
			}
			comp := compose(order, func(s string) *image.NRGBA {
				for id, im := range ims {
					if strings.SplitN(id, ".", 2)[0] == s {
						return im
					}
				}
				return nil
			}, cw, ch)
			cx := x + rw + 8
			fill(page, image.Rect(cx, y, cx+2*cw+8, y+2*ch+8), cardBg)
			blit(page, comp, cx+4, y+4, 2)
			ty := y + max(rh, 2*ch) + 6
			fill(page, image.Rect(x, ty, x+70, ty+52), cardBg)
			blit(page, shown(comp, 20), x+6, ty+6, 1)
			blit(page, shown(comp, 36), x+30, ty+6, 1)
			col := dim
			if filepath.Base(p) == pick {
				col = hex("#70F5D5")
				rectOutline(page, x-4, y-4, x+colW-22, ty+70, col)
			}
			text(page, x+80, ty+8, 2, strings.ToUpper(rw0.hull)+" "+strings.TrimSuffix(filepath.Base(p), filepath.Ext(p)), col)
		}
	}
	save(a[2], page)
	fmt.Printf("layercands: %d hulls -> %s\n", len(rows), a[2])
}
