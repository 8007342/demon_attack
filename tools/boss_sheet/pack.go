package main

// pack: boss-hero-assets task 4.4. Packs the finished projection bake of each
// hull (bakefinish output) into atlas pages and regenerates the hero section
// of lib/game/boss_atlas.dart, which BossPainter reads.
//
//	boss_sheet pack BAKE RIG HULL...
//
// Per hull and per stored view (pitch 38/45/52 x yaw 0/+12; yaw -12 is drawn
// as +12 mirrored; at yaw 0 a mirrored pair's left module is drawn as its
// right one flipped):
//   - S0 module layers at the atlas density (2 px per unit), cropped to alpha;
//   - S1-S3 module layers at half density (1 px per unit, drawn x2: the B2
//     budget decision), each a whole-module replacement of the S0 layer;
//   - per module two wreck frames (rest, tumbled) at 2 px per unit;
//   - the small functional parts of the hull's frontal atlas (jaw leaves, bay
//     vents, engine plumes, breaches, debris), so one hull needs no second
//     atlas resident.
// Pages are shelf-packed at <= 2048 x 2048 (the contract allows 4096 x 2048)
// and trimmed to their used height; the resident RGBA of all pages must stay
// <= 16 MB or the pack fails. The frontal section of boss_atlas.dart (from
// tools/generate_boss_sprites.py) is kept verbatim; only the text after the
// hero marker is rewritten, with every hull that has a bake.

import (
	"encoding/json"
	"fmt"
	"image"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const heroMarker = "// ---- BEGIN boss hero atlases (tools/boss_sheet pack) ----"
const budgetBytes = 16 << 20
const pageW, pageMaxH = 2048, 2048

type packItem struct {
	key  string // stable name (for the Dart tables)
	img  *image.NRGBA
	dx   float64 // top-left in arena units from the anchor
	dy   float64
	ppu  float64 // px per unit (2 and 1 in the v1 frigate bake; any density in a v2 manifest)
	page int
	x, y int
}

type rigPoint struct {
	Module  string  `json:"module"`
	X       float64 `json:"x"`
	Y       float64 `json:"y"`
	Visible bool    `json:"visible"`
	Kind    *int    `json:"kind"`
	Size    *int    `json:"size"`
}

type rigStage struct {
	Anchors map[string]json.RawMessage `json:"anchors"`
	Lights  []rigPoint                 `json:"lights"`
	Fires   []rigPoint                 `json:"fires"`
	Nozzles []rigPoint                 `json:"nozzles"`
}

func crop(im *image.NRGBA) (*image.NRGBA, image.Rectangle, bool) {
	r := alphaBounds(im)
	if r.Empty() {
		return nil, r, false
	}
	out := image.NewNRGBA(image.Rect(0, 0, r.Dx(), r.Dy()))
	for y := 0; y < r.Dy(); y++ {
		copy(out.Pix[y*out.Stride:y*out.Stride+r.Dx()*4], im.Pix[(r.Min.Y+y)*im.Stride+r.Min.X*4:(r.Min.Y+y)*im.Stride+r.Max.X*4])
	}
	return out, r, true
}

func subImage(atlas *image.NRGBA, s sprite) *image.NRGBA {
	out := image.NewNRGBA(image.Rect(0, 0, s.w, s.h))
	for y := 0; y < s.h; y++ {
		copy(out.Pix[y*out.Stride:y*out.Stride+s.w*4], atlas.Pix[(s.y+y)*atlas.Stride+s.x*4:(s.y+y)*atlas.Stride+(s.x+s.w)*4])
	}
	return out
}

// frontalParts: the functional part sprites of a hull's frontal atlas.
func frontalParts(dartSrc, hull string) (map[string][]sprite, map[string][]int) {
	s := dartSrc
	if i := strings.Index(s, heroMarker); i >= 0 {
		s = s[:i]
	}
	i := strings.Index(s, "key: '"+hull+"'")
	if i < 0 {
		fail("no frontal hull %s", hull)
	}
	s = s[i:]
	if j := strings.Index(s[1:], "BossHull("); j > 0 {
		s = s[:j]
	}
	re := regexp.MustCompile(`BossSprite\([^)]*\)`)
	field := func(name string) string {
		k := strings.Index(s, "\n      "+name+": ")
		if k < 0 {
			fail("no field %s", name)
		}
		rest := s[k+1:]
		// up to the next top-level field of the hull
		m := regexp.MustCompile(`\n      [a-zA-Z]+: `).FindStringIndex(rest[1:])
		if m != nil {
			rest = rest[:m[0]+1]
		}
		return rest
	}
	out := map[string][]sprite{}
	shape := map[string][]int{}
	for _, f := range []string{"jaws", "vents", "breach", "debris"} {
		for _, m := range re.FindAllString(field(f), -1) {
			out[f] = append(out[f], parseSprite(m))
		}
	}
	// plumes: [size][level 0-2][flicker 0-1]
	for _, m := range re.FindAllString(field("plumes"), -1) {
		out["plumes"] = append(out["plumes"], parseSprite(m))
	}
	shape["plumes"] = []int{len(out["plumes"]) / 6, 3, 2}
	return out, shape
}

func cmdPack(a []string) {
	if len(a) < 3 {
		fail("usage: pack BAKE RIG HULL...")
	}
	bake, rigDir, hulls := a[0], a[1], a[2:]
	root := repoRoot()
	dartPath := filepath.Join(root, "lib/game/boss_atlas.dart")
	srcB, err := os.ReadFile(dartPath)
	if err != nil {
		fail("%v", err)
	}
	dartSrc := string(srcB)
	frontal := dartSrc
	if i := strings.Index(frontal, heroMarker); i >= 0 {
		frontal = strings.TrimRight(frontal[:i], "\n") + "\n"
	}
	var dart strings.Builder
	dart.WriteString(heroTypes)
	dart.WriteString(heroTypesV3)
	dart.WriteString("abstract final class BossHeroAtlas {\n  /// Packed hulls by key; a hull missing here is drawn from its frontal\n  /// atlas ([BossAtlas.classes]) until its view set is packed.\n  static const hulls = <String, BossHeroHull>{\n")
	for _, hull := range hulls {
		// HULL=CLASS packs a v2 bake (boss-carrier-v2: BAKE/HULL/manifest.json) under
		// its own key HULL, as one set combination of the tour class CLASS it
		// replaces (e.g. carrier1-thorn=frigate); the runtime picks one per run
		if i := strings.Index(hull, "="); i > 0 {
			dart.WriteString(packHullV2(bake, rigDir, root, hull[:i], hull[i+1:], dartSrc))
			continue
		}
		dart.WriteString(packHull(bake, rigDir, root, hull, dartSrc))
	}
	dart.WriteString("  };\n}\n")
	out := frontal + "\n" + heroMarker + "\n" + dart.String()
	if err := os.WriteFile(dartPath, []byte(out), 0o644); err != nil {
		fail("%v", err)
	}
}

func packHull(bake, rigDir, root, hull, dartSrc string) string {
	return packHullAs(bake, rigDir, root, hull, hull, hull, dartSrc, nil)
}

// packHullAs packs HULL's bake as runtime key KEY, one set combination of the tour
// class CLASS (whose frontal atlas lends the small functional parts).
func packHullAs(bake, rigDir, root, hull, key, class, dartSrc string, v2 *bakeManifest) string {
	rig := readRig(rigDir, hull)
	raw, _ := os.ReadFile(filepath.Join(rigDir, hull, "rig.json"))
	var rv struct {
		Views map[string]struct {
			Stages map[string]rigStage `json:"stages"`
		} `json:"views"`
	}
	if err := json.Unmarshal(raw, &rv); err != nil {
		fail("%v", err)
	}
	ox, oy := rig.Origin[0]/2, rig.Origin[1]/2 // finished images are half the rig size
	ids := []string{}
	isID := map[string]bool{}
	for _, in := range rig.Insts {
		ids = append(ids, in.ID)
		isID[in.ID] = true
	}
	var items []*packItem
	add := func(key string, im *image.NRGBA, dx, dy float64, ppu float64) *packItem {
		it := &packItem{key: key, img: im, dx: dx, dy: dy, ppu: ppu}
		items = append(items, it)
		return it
	}
	type viewRec struct {
		tag    string
		pitch  int
		yaw    int
		layers map[string][4]*packItem
		doors  map[string][4]*packItem
	}
	var views []viewRec
	v3 := v2 != nil && v3Rig(rigDir, hull)
	for _, p := range pitches {
		for _, yw := range []int{0, 12} {
			t := tag(p, yw)
			v := viewRec{tag: t, pitch: p, yaw: yw, layers: map[string][4]*packItem{}}
			if v3 { // carrier-v3: one stored view (45, 0), bent at runtime; doors in their open state
				if p != 45 || yw != 0 {
					continue
				}
				v.layers = v2.viewLayers(t, add)
				v.doors = v2.viewDoors(t, add)
				views = append(views, v)
				continue
			}
			if v2 != nil {
				v.layers = v2.viewLayers(t, add)
				if len(v.layers) == 0 { // not stored (a v2 budget decision): alias the middle pitch
					for _, o := range views {
						if o.pitch == 45 && o.yaw == yw {
							v.layers = o.layers
						}
					}
					if len(v.layers) == 0 {
						v.layers = v2.viewLayers(tag(45, yw), add)
					}
				}
				views = append(views, v)
				continue
			}
			for _, id := range ids {
				if yw == 0 && strings.HasSuffix(id, "L") && isID[strings.TrimSuffix(id, "L")+"R"] {
					continue // drawn as the right one, flipped
				}
				var st [4]*packItem
				for si, stage := range []string{"S0", "S1", "S2", "S3"} {
					path := filepath.Join(bake, hull, stage, "fin_layer_"+id+"_"+t+".png")
					if _, err := os.Stat(path); err != nil {
						continue
					}
					im := load(path)
					k, cx, cy := 2.0, ox, oy
					if si > 0 {
						im = areaScale(im, .5)
						k, cx, cy = 1.0, ox/2, oy/2
					}
					c, r, ok := crop(im)
					if !ok {
						continue
					}
					st[si] = add(fmt.Sprintf("%s.%s.%s", t, id, stage), c,
						(float64(r.Min.X)-cx)/float64(k), (float64(r.Min.Y)-cy)/float64(k), k)
				}
				v.layers[id] = st
			}
			views = append(views, v)
		}
	}
	wrecks := map[string][2]*packItem{}
	if v2 != nil {
		wrecks = v2.wrecks(add)
	}
	wids := ids
	if v2 != nil {
		wids = nil
	}
	for _, id := range wids {
		// A mirrored pair's wreck is stored once (the left one); the right
		// one draws it flipped (ledger §4: the B3 budget rule).
		if strings.HasSuffix(id, "R") && isID[strings.TrimSuffix(id, "R")+"L"] {
			continue
		}
		var w [2]*packItem
		for f := 0; f < 2; f++ {
			path := filepath.Join(bake, hull, fmt.Sprintf("fin_wreck_%s_f%d.png", id, f))
			if _, err := os.Stat(path); err != nil {
				continue
			}
			c, r, ok := crop(load(path))
			if !ok {
				continue
			}
			w[f] = add("wreck."+id, c, (float64(r.Min.X)-ox)/2, (float64(r.Min.Y)-oy)/2, 2)
		}
		if w[0] != nil {
			wrecks[id] = w
		}
	}
	parts, shape := frontalParts(dartSrc, class)
	atlas := load(filepath.Join(root, "assets/images/boss-"+class+".png"))
	partItems := map[string][]*packItem{}
	for _, name := range []string{"jaws", "vents", "plumes", "breach", "debris"} {
		for i, s := range parts[name] {
			partItems[name] = append(partItems[name], add(fmt.Sprintf("%s.%d", name, i), subImage(atlas, s), s.dx, s.dy, 2))
		}
	}

	// shelf pack, tallest first
	order := make([]*packItem, len(items))
	copy(order, items)
	sort.SliceStable(order, func(i, j int) bool {
		hi, hj := order[i].img.Bounds().Dy(), order[j].img.Bounds().Dy()
		if hi != hj {
			return hi > hj
		}
		return order[i].img.Bounds().Dx() > order[j].img.Bounds().Dx()
	})
	const pad = 1
	pw := pageW
	type page struct{ h int }
	pages := []page{{}}
	if v2 != nil {
		area := map[string]int{}
		for _, it := range order {
			k := strings.SplitN(it.key, ".", 2)[0]
			if strings.HasPrefix(k, "p") {
				k = "layer"
			}
			area[k] += it.img.Bounds().Dx() * it.img.Bounds().Dy() * 4
		}
		fmt.Printf("%s sprite RGBA by kind: %v\n", key, area)
		pages = nil
		pw = 4096 // the contract allows 4096 x 2048; one wide page wastes less than two narrow ones
		for _, ph := range skylinePack(order, pad, pw) {
			pages = append(pages, page{ph})
		}
		order = nil // placed
	}
	x, y, shelf := 0, 0, 0
	for _, it := range order {
		w, h := it.img.Bounds().Dx(), it.img.Bounds().Dy()
		if x+w > pageW {
			x, y, shelf = 0, y+shelf+pad, 0
		}
		if y+h > pageMaxH {
			pages = append(pages, page{})
			x, y, shelf = 0, 0, 0
		}
		it.page, it.x, it.y = len(pages)-1, x, y
		x += w + pad
		shelf = max(shelf, h)
		pages[len(pages)-1].h = max(pages[len(pages)-1].h, y+h)
	}
	resident := 0
	var x3 v3Extras
	if v3 {
		x3 = v3Data(bake, rigDir, root, hull, key)
		resident += x3.dataBytes
	}
	var names []string
	var sizes []string
	for i := range pages {
		h := (pages[i].h + 1) &^ 1
		im := image.NewNRGBA(image.Rect(0, 0, pw, h))
		for _, it := range items {
			if it.page == i {
				blit(im, it.img, it.x, it.y, 1)
			}
		}
		name := fmt.Sprintf("boss-%s-hero-%d.png", key, i)
		save(filepath.Join(root, "assets/images", name), im)
		resident += pw * h * 4
		names = append(names, "'"+name+"'")
		sizes = append(sizes, fmt.Sprintf("(%d, %d)", pw, h))
	}
	mb := float64(resident) / (1 << 20)
	fmt.Printf("%s: %d sprites on %d pages, %.2f MB RGBA resident\n", key, len(items), len(pages), mb)
	if resident > budgetBytes {
		fail("%s: %.2f MB over the 16 MB budget", key, mb)
	}

	spr := func(it *packItem) string {
		if it == nil {
			return "null"
		}
		return fmt.Sprintf("BossHeroSprite(%d, %d, %d, %d, %d, %s, %s%s)", it.page, it.x, it.y,
			it.img.Bounds().Dx(), it.img.Bounds().Dy(), num(it.dx), num(it.dy), map[bool]string{true: "", false: ", " + num(it.ppu)}[it.ppu == 2])
	}
	pts := func(ps []rigPoint, kind func(rigPoint) int, all bool) string {
		var b []string
		for _, p := range ps {
			if !p.Visible && !all {
				continue
			}
			b = append(b, fmt.Sprintf("BossHeroPoint(%s, %s, %d, '%s')", num(p.X), num(p.Y), kind(p), p.Module))
		}
		return "[" + strings.Join(b, ", ") + "]"
	}
	lightKind := func(p rigPoint) int {
		if p.Kind != nil {
			return *p.Kind
		}
		return 0
	}
	nozzleSize := func(p rigPoint) int {
		if p.Size != nil {
			return *p.Size
		}
		return 0
	}
	fireKind := func(rigPoint) int { return 0 }

	var o strings.Builder
	w := func(f string, args ...any) { fmt.Fprintf(&o, f, args...) }
	w("    '%s': BossHeroHull(\n", key)
	w("      key: '%s',\n", key)
	w("      replaces: '%s',\n", class)
	if set := strings.TrimPrefix(key, strings.SplitN(key, "-", 2)[0]+"-"); set != key {
		w("      set: '%s',\n", set)
	}
	if v2 != nil {
		if b := v2.belly(root, key); b != "" {
			w("      belly: %s,\n", b)
		}
	}
	w("      pages: [%s],\n", strings.Join(names, ", "))
	w("      pageSizes: [%s],\n", strings.Join(sizes, ", "))
	w("      residentBytes: %d,\n", resident)
	w("      frame: (%s, %s, %s, %s),\n", num(rig.Frame[0]), num(rig.Frame[1]), num(rig.Frame[2]), num(rig.Frame[3]))
	w("      modules: [\n")
	for _, in := range rig.Insts {
		d := "null"
		if in.Detach != nil {
			d = fmt.Sprint(*in.Detach)
		}
		w("        BossHeroModule('%s', '%s', %d, %s),\n", in.ID, in.Module, in.Mirror, d)
	}
	w("      ],\n      views: {\n")
	for _, v := range views {
		w("        '%s': BossHeroView(\n          pitch: %d,\n          yaw: %d,\n          layers: {\n", v.tag, v.pitch, v.yaw)
		for _, id := range ids {
			st, ok := v.layers[id]
			if !ok {
				continue
			}
			w("            '%s': [%s, %s, %s, %s],\n", id, spr(st[0]), spr(st[1]), spr(st[2]), spr(st[3]))
		}
		w("          },\n")
		if len(v.doors) > 0 {
			w("          doors: {\n")
			for _, id := range ids {
				if st, ok := v.doors[id]; ok {
					w("            '%s': [%s, %s, %s, %s],\n", id, spr(st[0]), spr(st[1]), spr(st[2]), spr(st[3]))
				}
			}
			w("          },\n")
		}
		if v3 {
			w("          vortex: %s,\n", pts(x3.vortex, func(rigPoint) int { return 0 }, true))
		}
		rs := rv.Views[v.tag].Stages
		for si, stage := range []string{"S0", "S3"} {
			s := rs[stage]
			suffix := []string{"", "Broken"}[si]
			w("          lights%s: %s,\n", suffix, pts(s.Lights, lightKind, false))
			w("          fires%s: %s,\n", suffix, pts(s.Fires, fireKind, false))
			w("          nozzles%s: %s,\n", suffix, pts(s.Nozzles, nozzleSize, true))
		}
		var an []string
		keys := make([]string, 0, len(rs["S0"].Anchors))
		for k := range rs["S0"].Anchors {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			var p struct {
				X, Y *float64
			}
			if json.Unmarshal(rs["S0"].Anchors[k], &p) == nil && p.X != nil && p.Y != nil {
				an = append(an, fmt.Sprintf("'%s': (%s, %s)", k, num(*p.X), num(*p.Y)))
			}
		}
		w("          anchors: {%s},\n        ),\n", strings.Join(an, ", "))
	}
	w("      },\n")
	if v3 {
		x3.dart(func(f string, a ...any) { w(f, a...) })
	}
	w("      wrecks: {\n")
	for _, id := range ids {
		if wr, ok := wrecks[id]; ok {
			w("        '%s': [%s, %s],\n", id, spr(wr[0]), spr(wr[1]))
		}
	}
	w("      },\n")
	list := func(name string) {
		var b []string
		for _, it := range partItems[name] {
			b = append(b, spr(it))
		}
		w("      %s: [%s],\n", name, strings.Join(b, ", "))
	}
	list("jaws")
	list("vents")
	list("breach")
	list("debris")
	// plumes regrouped as [size][level][flicker]
	n := shape["plumes"][0]
	w("      plumes: [\n")
	for s := 0; s < n; s++ {
		var lv []string
		for l := 0; l < 3; l++ {
			i := s*6 + l*2
			lv = append(lv, "["+spr(partItems["plumes"][i])+", "+spr(partItems["plumes"][i+1])+"]")
		}
		w("        [%s],\n", strings.Join(lv, ", "))
	}
	w("      ],\n    ),\n")
	return o.String()
}

func num(v float64) string {
	s := fmt.Sprintf("%.2f", v)
	s = strings.TrimRight(strings.TrimRight(s, "0"), ".")
	if s == "-0" {
		s = "0"
	}
	if !strings.Contains(s, ".") {
		s += ".0"
	}
	return s
}

const heroTypes = `// Generated by tools/boss_sheet pack from the projection bake of
// boss-hero-assets (plan/render-runs/boss-hero-assets.md); do not edit.

/// One sprite of a hero atlas page: page index, source rect (px) and the
/// top-left of its destination in arena units from its anchor (the carrier
/// centre). It is drawn at w / ppu x h / ppu units: 2 px per unit for S0
/// layers, wrecks and parts; 1 px per unit for the S1-S3 stage layers.
class BossHeroSprite {
  const BossHeroSprite(this.page, this.x, this.y, this.w, this.h, this.dx,
      this.dy, [this.ppu = 2]);
  final int page, x, y, w, h;
  final double dx, dy, ppu;
}

/// One module instance of a hull: id, catalogue module, mirror (-1 for the
/// left of a pair) and detach order (null: never detaches; the spine).
class BossHeroModule {
  const BossHeroModule(this.id, this.module, this.mirror, this.detach);
  final String id, module;
  final int mirror;
  final int? detach;
}

/// A projected rig point, arena units from the carrier centre: a running
/// light (kind 0 red, 1 green, 2 strobe, 3 amber), a fire point, or an
/// engine nozzle (kind = plume size). Only points visible in the view.
class BossHeroPoint {
  const BossHeroPoint(this.x, this.y, this.kind, this.module);
  final double x, y;
  final int kind;
  final String module;
}

/// One stored view (pitch 38/45/52 x yaw 0/+12; yaw -12 is +12 mirrored).
/// [layers]: module id to its S0-S3 layers (null: the module is gone in
/// that stage). At yaw 0 the left module of a mirrored pair is absent: draw
/// the right one flipped about the carrier centre. Points for S0-S2 and for
/// S3 ("Broken": the first module of the detach order gone). [anchors]: the
/// projected functional anchors (gate: within 3 units of [BossAtlas]).
class BossHeroView {
  const BossHeroView({
    required this.pitch,
    required this.yaw,
    required this.layers,
    required this.lights,
    required this.fires,
    required this.nozzles,
    required this.lightsBroken,
    required this.firesBroken,
    required this.nozzlesBroken,
    required this.anchors,
    this.doors = const {},
    this.vortex = const [],
  });
  final int pitch, yaw;

  /// carrier-v3 gates: a door instance's open state per stage (the closed
  /// state is its layer); the runtime blends the two.
  final Map<String, List<BossHeroSprite?>> doors;

  /// carrier-v3 §7: the vortex-trail anchors (prong, wing and tendril tips).
  final List<BossHeroPoint> vortex;
  final Map<String, List<BossHeroSprite?>> layers;
  final List<BossHeroPoint> lights, fires, nozzles;
  final List<BossHeroPoint> lightsBroken, firesBroken, nozzlesBroken;
  final Map<String, (double, double)> anchors;
}

/// A hull's packed view set: pages, modules, views, wrecks (rest and
/// tumbled, at the hero view) and the functional parts carried over from
/// its frontal atlas (jaw leaves, bay vents, plumes, breaches, debris).
/// The Overflight's underside (boss-carrier-v2 fin_belly.png): its own page,
/// outside the resident budget, drawn centred on the overflight position at
/// w / ppu x h / ppu units.
class BossHeroBelly {
  const BossHeroBelly(this.asset, this.w, this.h, this.ppu);
  final String asset;
  final int w, h;
  final double ppu;
}

class BossHeroHull {
  const BossHeroHull({
    required this.key,
    required this.replaces,
    this.set = '',
    this.belly,
    required this.pages,
    required this.pageSizes,
    required this.residentBytes,
    required this.frame,
    required this.modules,
    required this.views,
    required this.wrecks,
    required this.jaws,
    required this.vents,
    required this.breach,
    required this.debris,
    required this.plumes,
    this.gates = const {},
    this.hinges = const {},
    this.data,
  });
  final String key;

  /// carrier-v3: CarrierGate id to the art instance that draws it.
  final Map<String, String> gates;

  /// carrier-v3 §2.2: per lagging instance its hinge root and tip (x0, y0,
  /// x1, y1, hull-local units at the stored view).
  final Map<String, (double, double, double, double)> hinges;

  /// carrier-v3: the hull's data page (field texture and height grids).
  final BossHeroData? data;

  /// The tour class ([BossAtlas.classes] key) this hull is drawn for, and
  /// its set combination (empty for a v1 hull): a class with several packed
  /// hulls picks one per run.
  final String replaces, set;
  final BossHeroBelly? belly;
  final List<String> pages;
  final List<(int, int)> pageSizes;
  final int residentBytes;
  final (double, double, double, double) frame;
  final List<BossHeroModule> modules;
  final Map<String, BossHeroView> views;
  final Map<String, List<BossHeroSprite?>> wrecks;
  final List<BossHeroSprite> jaws, vents, breach, debris;
  final List<List<List<BossHeroSprite>>> plumes;
}

`
