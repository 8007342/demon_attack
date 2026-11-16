package main

// carrier-v3 (openspec/changes/carrier-v3/design.md §2.5, §3.4, §4;
// plan/render-runs/carrier-v3.md §2.2–§2.3): a hull built for bending.
//
//   - underPaint: a layer's visible render plus the texels its neighbours cover
//     (its own silhouette within 12 units of the visible part), filled by
//     pullPush from the visible texels and darkened 15 %, so the bend's
//     height parallax never opens a sliver at an occlusion edge;
//   - pullPush: an edge-extending fill of the transparent texels of an image
//     from its opaque ones (a mip pyramid down, then back up);
//   - fielddata: the hull's field data texture (R the signed distance to the
//     S0 silhouette, closed by a 30-unit disc so the membrane rounds the
//     throat corners; G the Voronoi region of the family's 12 seeds; B the
//     baked height), at the family's field ppu over the envelope.

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
)

// underMargin: the under-paint reaches this far (units) beyond a layer's
// visible texels: at least the bend's largest height-parallax shift.
const underMargin = 12.0

// underPaint combines a layer's held-out render (visible) and its alone render
// (under: its whole silhouette) at render resolution: alpha = under ∩ dilate
// (visible, margin); colour = visible, else pull-push from it × 0.85.
func underPaint(vis, under *image.NRGBA, r *Rig) *image.NRGBA {
	W, H := vis.Bounds().Dx(), vis.Bounds().Dy()
	m := make([]bool, W*H)
	for i := range m {
		m[i] = vis.Pix[i*4+3] >= 128
	}
	near := dilateDisc(m, W, H, underMargin*r.PPU)
	fillIm := pullPush(vis)
	out := image.NewNRGBA(vis.Bounds())
	copy(out.Pix, vis.Pix)
	for i := 0; i < W*H; i++ {
		if m[i] || under.Pix[i*4+3] < 128 || !near[i] {
			continue
		}
		c := fillIm.Pix[i*4 : i*4+4]
		out.Pix[i*4] = uint8(float64(c[0]) * .85)
		out.Pix[i*4+1] = uint8(float64(c[1]) * .85)
		out.Pix[i*4+2] = uint8(float64(c[2]) * .85)
		out.Pix[i*4+3] = 255
	}
	return out
}

// dilateDisc: a binary dilation by a disc of radius r px (via the exact EDT).
func dilateDisc(m []bool, w, h int, r float64) []bool {
	d := edt(m, w, h)
	out := make([]bool, len(m))
	for i := range m {
		out[i] = d[i] <= r*r
	}
	return out
}

// edt: squared Euclidean distance (px²) from each pixel to the nearest true
// pixel (Felzenszwalb–Huttenlocher, separable).
func edt(m []bool, w, h int) []float64 {
	const inf = 1e20
	g := make([]float64, w*h)
	for i, b := range m {
		if b {
			g[i] = 0
		} else {
			g[i] = inf
		}
	}
	n := max(w, h)
	f, d := make([]float64, n), make([]float64, n)
	z, v := make([]float64, n+1), make([]int, n)
	pass := func(ln int) {
		k := 0
		v[0], z[0], z[1] = 0, -inf, inf
		for q := 1; q < ln; q++ {
			s := ((f[q] + float64(q*q)) - (f[v[k]] + float64(v[k]*v[k]))) / float64(2*q-2*v[k])
			for s <= z[k] {
				k--
				s = ((f[q] + float64(q*q)) - (f[v[k]] + float64(v[k]*v[k]))) / float64(2*q-2*v[k])
			}
			k++
			v[k], z[k], z[k+1] = q, s, inf
		}
		k = 0
		for q := 0; q < ln; q++ {
			for z[k+1] < float64(q) {
				k++
			}
			dq := float64(q - v[k])
			d[q] = dq*dq + f[v[k]]
		}
	}
	for x := 0; x < w; x++ {
		for y := 0; y < h; y++ {
			f[y] = g[y*w+x]
		}
		pass(h)
		for y := 0; y < h; y++ {
			g[y*w+x] = d[y]
		}
	}
	for y := 0; y < h; y++ {
		copy(f[:w], g[y*w:y*w+w])
		pass(w)
		copy(g[y*w:y*w+w], d[:w])
	}
	return g
}

// pullPush fills every transparent texel from the opaque ones: a pyramid of
// weight-averaged 2×2 colours (pull), then each level's partly known texels
// blended with the coarser level's colour (push).
func pullPush(src *image.NRGBA) *image.NRGBA {
	type lvl struct {
		w, h int
		c    [][3]float64 // colour (normalised)
		wt   []float64    // weight 0..1
	}
	W, H := src.Bounds().Dx(), src.Bounds().Dy()
	l0 := lvl{W, H, make([][3]float64, W*H), make([]float64, W*H)}
	for i := 0; i < W*H; i++ {
		if src.Pix[i*4+3] >= 128 {
			l0.c[i] = [3]float64{float64(src.Pix[i*4]), float64(src.Pix[i*4+1]), float64(src.Pix[i*4+2])}
			l0.wt[i] = 1
		}
	}
	levels := []lvl{l0}
	for {
		p := levels[len(levels)-1]
		if p.w <= 1 && p.h <= 1 {
			break
		}
		q := lvl{(p.w + 1) / 2, (p.h + 1) / 2, nil, nil}
		q.c, q.wt = make([][3]float64, q.w*q.h), make([]float64, q.w*q.h)
		sum := make([]float64, q.w*q.h)
		for y := 0; y < p.h; y++ {
			for x := 0; x < p.w; x++ {
				a, b := y*p.w+x, (y/2)*q.w+x/2
				for k := 0; k < 3; k++ {
					q.c[b][k] += p.c[a][k] * p.wt[a]
				}
				sum[b] += p.wt[a]
			}
		}
		for b := range sum {
			if sum[b] > 0 {
				for k := 0; k < 3; k++ {
					q.c[b][k] /= sum[b]
				}
			}
			q.wt[b] = math.Min(1, sum[b])
		}
		levels = append(levels, q)
	}
	for li := len(levels) - 2; li >= 0; li-- {
		p, q := levels[li], levels[li+1]
		for y := 0; y < p.h; y++ {
			for x := 0; x < p.w; x++ {
				a, b := y*p.w+x, (y/2)*q.w+x/2
				if p.wt[a] >= 1 {
					continue
				}
				for k := 0; k < 3; k++ {
					p.c[a][k] = p.wt[a]*p.c[a][k] + (1-p.wt[a])*q.c[b][k]
				}
				p.wt[a] = 1
			}
		}
	}
	out := image.NewNRGBA(src.Bounds())
	for i := 0; i < W*H; i++ {
		for k := 0; k < 3; k++ {
			out.Pix[i*4+k] = uint8(math.Min(255, math.Max(0, l0.c[i][k])))
		}
		out.Pix[i*4+3] = 255
	}
	return out
}

// padCrop: the alpha bounds of im grown by pad texels on every side (clipped):
// carrier-v3 §2.4, the mesh border lies inside each sprite's transparent margin.
func padCrop(im *image.NRGBA, pad int) image.Rectangle {
	cr := alphaBounds(im)
	if cr.Empty() {
		return cr
	}
	return image.Rect(cr.Min.X-pad, cr.Min.Y-pad, cr.Max.X+pad, cr.Max.Y+pad).Intersect(im.Bounds())
}

// Heights: rigkit bake.py's heights.json (ship-frame z per 20-unit node).
type Heights struct {
	Step   float64 `json:"step"`
	Layers map[string]struct {
		X0 float64 `json:"x0"`
		Y0 float64 `json:"y0"`
		W  int     `json:"w"`
		H  int     `json:"h"`
		Z  []int   `json:"z"`
	} `json:"layers"`
}

func readHeights(bake, hull string) *Heights {
	b, err := os.ReadFile(filepath.Join(bake, hull, "heights.json"))
	if err != nil {
		return nil
	}
	var h Heights
	if json.Unmarshal(b, &h) != nil {
		return nil
	}
	return &h
}

// heightAt: the baked height of instance id at hull-local (x, y) (bilinear on
// its grid; clamped at the grid's edge); ok false without a grid.
func (hs *Heights) heightAt(id string, x, y float64) (float64, bool) {
	if hs == nil {
		return 0, false
	}
	l, ok := hs.Layers[id]
	if !ok {
		return 0, false
	}
	fx := math.Max(0, math.Min(float64(l.W-1)-1e-6, (x-l.X0)/hs.Step))
	fy := math.Max(0, math.Min(float64(l.H-1)-1e-6, (y-l.Y0)/hs.Step))
	i, j := int(fx), int(fy)
	u, v := fx-float64(i), fy-float64(j)
	at := func(a, b int) float64 { return float64(l.Z[min(b, l.H-1)*l.W+min(a, l.W-1)]) }
	return (at(i, j)*(1-u)+at(i+1, j)*u)*(1-v) + (at(i, j+1)*(1-u)+at(i+1, j+1)*u)*v, true
}

// fielddata BAKE RIG HULL: BAKE/HULL/fin_field.png + fin_chunks.png/json
// via bakefinish). Pixel (i, j) is hull-local (left + (i+.5)/ppu, top + (j+.5)/ppu).
// R = 128 + d·(127/range) (d: signed distance in units, outside positive), G =
// region id × 20, B = fracture chunk id (chunkMap).
func cmdFieldData(a []string) {
	bake, rigDir, hull := a[0], a[1], a[2]
	r := readRig(rigDir, hull)
	var fam struct {
		Field struct {
			PPU     float64      `json:"ppu"`
			Range   float64      `json:"range"`
			Regions [][2]float64 `json:"regions"`
		} `json:"field"`
	}
	b, _ := os.ReadFile(filepath.Join(repoRoot(), r.Family))
	json.Unmarshal(b, &fam)
	ppu, rng := fam.Field.PPU, fam.Field.Range
	if ppu == 0 {
		ppu, rng = .5, 32
	}
	env := r.Envelope
	if len(env) < 4 {
		env = []float64{r.Frame[0], r.Frame[1], r.Frame[2], r.Frame[3]}
	}
	// pad by the field's range, so the membrane is defined past the envelope edge
	left, top := env[0]-rng, env[1]-rng
	w, h := int(math.Ceil((env[2]-env[0]+2*rng)*ppu)), int(math.Ceil((env[3]-env[1]+2*rng)*ppu))
	beauty := load(filepath.Join(bake, hull, "S0", "fin_beauty_"+tag(45, 0)+".png"))
	bt := r.maxTexel()
	in := make([]bool, w*h)
	lum := make([]float64, w*h)
	for j := 0; j < h; j++ {
		for i := 0; i < w; i++ { // the cell's centre luminance, for the fracture map
			xx, yy := int((left+(float64(i)+.5)/ppu-r.Frame[0])*bt), int((top+(float64(j)+.5)/ppu-r.Frame[1])*bt)
			if xx >= 0 && yy >= 0 && xx < beauty.Bounds().Dx() && yy < beauty.Bounds().Dy() {
				c := beauty.Pix[(yy*beauty.Bounds().Dx()+xx)*4:]
				lum[j*w+i] = .3*float64(c[0]) + .59*float64(c[1]) + .11*float64(c[2])
			}
		}
	}
	for j := 0; j < h; j++ {
		for i := 0; i < w; i++ {
			// the max alpha over the field cell (the beauty is at bt px per unit)
			x0, y0 := (left+float64(i)/ppu-r.Frame[0])*bt, (top+float64(j)/ppu-r.Frame[1])*bt
			for yy := int(y0); yy < int(y0+bt/ppu) && !in[j*w+i]; yy++ {
				for xx := int(x0); xx < int(x0+bt/ppu); xx++ {
					if xx >= 0 && yy >= 0 && xx < beauty.Bounds().Dx() && yy < beauty.Bounds().Dy() && beauty.Pix[(yy*beauty.Bounds().Dx()+xx)*4+3] >= 96 {
						in[j*w+i] = true
						break
					}
				}
			}
		}
	}
	// close the silhouette by a 30-unit disc: the membrane rounds the throat
	// corners instead of folding into a cusp where the lip meets the prongs
	cr := 30 * ppu
	dOut := edt(in, w, h)
	grown := make([]bool, w*h)
	for i := range grown {
		grown[i] = dOut[i] <= cr*cr
	}
	notG := make([]bool, w*h)
	for i := range notG {
		notG[i] = !grown[i]
	}
	dBack := edt(notG, w, h)
	closed := make([]bool, w*h)
	for i := range closed {
		closed[i] = dBack[i] > cr*cr
	}
	notC := make([]bool, w*h)
	for i := range notC {
		notC[i] = !closed[i]
	}
	o, inn := edt(closed, w, h), edt(notC, w, h)
	hs := readHeights(bake, hull)
	out := image.NewNRGBA(image.Rect(0, 0, w, h))
	for j := 0; j < h; j++ {
		for i := 0; i < w; i++ {
			k := j*w + i
			var d float64
			if closed[k] {
				d = -(math.Sqrt(inn[k]) - .5) / ppu
			} else {
				d = (math.Sqrt(o[k]) - .5) / ppu
			}
			x, y := left+(float64(i)+.5)/ppu, top+(float64(j)+.5)/ppu
			reg, best := 0, math.MaxFloat64
			for ri, s := range fam.Field.Regions {
				if dd := (x-s[0])*(x-s[0]) + (y-s[1])*(y-s[1]); dd < best {
					reg, best = ri, dd
				}
			}
			ht := 0.0
			if hs != nil {
				for _, id := range []string{"carapace"} {
					if v, ok := hs.heightAt(id, x, y); ok {
						ht = v
					}
				}
			}
			out.Pix[k*4] = uint8(math.Max(0, math.Min(255, math.Round(128+d*127/rng))))
			out.Pix[k*4+1] = uint8(reg * 20)
			out.Pix[k*4+2] = uint8(math.Max(0, math.Min(255, math.Round(128+ht/2))))
			out.Pix[k*4+3] = 255
		}
	}
	lab, cent := chunkMap(lum, in, w, h, ppu, 110, 0xC4A5)
	for k, l := range lab { // B: the fracture chunk (the per-instance height grids carry the heights)
		out.Pix[k*4+2] = l
	}
	save(filepath.Join(bake, hull, "fin_field.png"), out)
	cm := image.NewNRGBA(image.Rect(0, 0, w, h))
	var cs [][3]float64
	for k, l := range lab {
		cm.Pix[k*4], cm.Pix[k*4+3] = l, 255
	}
	for _, c := range cent {
		cs = append(cs, [3]float64{math.Round((left+(c[0]+.5)/ppu)*10) / 10, math.Round((top+(c[1]+.5)/ppu)*10) / 10, math.Round(c[2] / ppu / ppu)})
	}
	save(filepath.Join(bake, hull, "fin_chunks.png"), cm)
	cj, _ := json.Marshal(map[string]any{"encoding": "R = chunk id (1..n, 0 outside the S0 silhouette) at the field grid; chunks[i] = [x, y, area units^2] of chunk i+1 (hull-local)", "chunks": cs})
	os.WriteFile(filepath.Join(bake, hull, "fin_chunks.json"), cj, 0o644)
	fmt.Printf("%s: %d fracture chunks\n", hull, len(cs))
	meta, _ := json.MarshalIndent(map[string]any{"left": left, "top": top, "w": w, "h": h, "ppu": ppu, "range": rng,
		"encoding": "R = 128 + d*127/range (signed distance, units, outside +; silhouette closed by a 30-unit disc); G = region*20 (family field.regions order); B = fracture chunk id (1..n, 0 outside; fin_chunks.json)"}, "", " ")
	os.WriteFile(filepath.Join(bake, hull, "fin_field.json"), meta, 0o644)
	fmt.Printf("%s: field %d x %d px at %.2f px/unit (%.2f MB RGBA)\n", hull, w, h, ppu, float64(w*h*4)/(1<<20))
}

var _ = color.NRGBA{}

// chunkMap: the collapse's fracture map (operator round 3b C3: the hull must
// break up as one structure, along its own seams, not along module borders).
// Marker watershed at the field grid: the edge strength is the S0 beauty's
// luminance gradient (strakes, terraces, seams); markers sit on a jittered
// lattice of about spacing units inside the silhouette (deterministic); the
// flood runs lowest edge first, so the cracks land on the painted seams.
// Returns per texel the chunk id (1..n; 0 outside) and the chunk centroids.
func chunkMap(lum []float64, in []bool, w, h int, ppu, spacing float64, seed uint32) ([]uint8, [][3]float64) {
	E := make([]float64, w*h)
	at := func(x, y int) float64 { return lum[min(max(y, 0), h-1)*w+min(max(x, 0), w-1)] }
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			gx := at(x+1, y-1) + 2*at(x+1, y) + at(x+1, y+1) - at(x-1, y-1) - 2*at(x-1, y) - at(x-1, y+1)
			gy := at(x-1, y+1) + 2*at(x, y+1) + at(x+1, y+1) - at(x-1, y-1) - 2*at(x, y-1) - at(x+1, y-1)
			E[y*w+x] = math.Hypot(gx, gy)
		}
	}
	rnd := seed
	next := func() float64 { rnd ^= rnd << 13; rnd ^= rnd >> 17; rnd ^= rnd << 5; return float64(rnd%10000) / 10000 }
	lab := make([]uint8, w*h)
	step := spacing * ppu
	n := 0
	type px struct {
		e   float64
		i   int
		ord int
	}
	var heap []px
	push := func(p px) {
		heap = append(heap, p)
		for k := len(heap) - 1; k > 0; {
			q := (k - 1) / 2
			if heap[q].e < heap[k].e || (heap[q].e == heap[k].e && heap[q].ord < heap[k].ord) {
				break
			}
			heap[q], heap[k] = heap[k], heap[q]
			k = q
		}
	}
	pop := func() px {
		top := heap[0]
		last := len(heap) - 1
		heap[0] = heap[last]
		heap = heap[:last]
		for k := 0; ; {
			l, r, m := 2*k+1, 2*k+2, k
			if l < len(heap) && (heap[l].e < heap[m].e || (heap[l].e == heap[m].e && heap[l].ord < heap[m].ord)) {
				m = l
			}
			if r < len(heap) && (heap[r].e < heap[m].e || (heap[r].e == heap[m].e && heap[r].ord < heap[m].ord)) {
				m = r
			}
			if m == k {
				break
			}
			heap[m], heap[k] = heap[k], heap[m]
			k = m
		}
		return top
	}
	ord := 0
	// mirror-symmetric markers (the hull is symmetric; so are its cracks)
	cx := float64(w) / 2
	for gy := step / 2; gy < float64(h); gy += step {
		for gx := step / 2; gx < cx; gx += step {
			jx, jy := (next()-.5)*step*.6, (next()-.5)*step*.6
			for _, sx := range []float64{1, -1} {
				x := int(cx + sx*(cx-(gx+jx)))
				y := int(gy + jy)
				if x < 0 || y < 0 || x >= w || y >= h || !in[y*w+x] || lab[y*w+x] != 0 || n >= 254 {
					continue
				}
				n++
				lab[y*w+x] = uint8(n)
				push(px{0, y*w + x, ord})
				ord++
			}
		}
	}
	for len(heap) > 0 {
		p := pop()
		x, y := p.i%w, p.i/w
		for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
			xx, yy := x+d[0], y+d[1]
			if xx < 0 || yy < 0 || xx >= w || yy >= h {
				continue
			}
			k := yy*w + xx
			if !in[k] || lab[k] != 0 {
				continue
			}
			lab[k] = lab[p.i]
			push(px{E[k], k, ord})
			ord++
		}
	}
	cent := make([][3]float64, n)
	for i, l := range lab {
		if l > 0 {
			cent[l-1][0] += float64(i % w)
			cent[l-1][1] += float64(i / w)
			cent[l-1][2]++
		}
	}
	for k := range cent {
		if cent[k][2] > 0 {
			cent[k][0] /= cent[k][2]
			cent[k][1] /= cent[k][2]
		}
	}
	return lab, cent
}
