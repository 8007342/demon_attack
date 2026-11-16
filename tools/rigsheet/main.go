package main

// rigsheet commands (run from the repository; RIG = tools/rigkit/rig.py output,
// BAKE = tools/rigkit/bake.py output):
//
//	rigsheet ctl RIG HULL STAGE TAG OUT.png          clay + hint colours on the green key (the hero control)
//	rigsheet fit RAW RIG HULL STAGE TAG OUT.png [left|right|none] [bbox]
//	                                                 raw -> rig frame, silhouette mask, despill (+ symmetrise);
//	                                                 bbox first registers the raw's subject box to the clay's
//	rigsheet maskdiff FIT RIG HULL A B OUT.png       drop texels whose geometry left between stages A and B
//	rigsheet finish RAW RIG HULL STAGE TAG TEXEL OUT.png  one finished image at TEXEL px per unit (the belly)
//	rigsheet kit RIG OUT.png HULL...                 kit turntables: 3x3 clay views + passes per hull
//	rigsheet heroes RIG HULL OUT.png TITLE RAW...    hero candidate sheet (raw, finished, phone scale)
//	rigsheet bakefinish BAKE RIG HULL                finish every baked layer at its class density + manifest.json
//	rigsheet budget BAKE RIG HULL...                 measured resident RGBA of the finished outputs (+ the field page)
//	rigsheet regional OLDRAW OLDCTL NEWCTL INPUT.png MASK.png [GROW] / regionmerge OLDRAW EDIT MASK OUT.png (tour-1 regional edits)
//	rigsheet v3sheet BAKE RIG OUT.png HULL...         carrier-v3 review: S0/S2/S3 at the stored view, gates closed/open
//	rigsheet fielddata BAKE RIG HULL                 carrier-v3 field data texture: R distance, G region, B height
//	                                                 (bakefinish also under-paints layers, finishes door_ states and wreck frames)
//	rigsheet views BAKE RIG HULL OUT.png             finished views x stages with the overlay (+ OUT.gif swerve)
//	rigsheet stages BAKE RIG HULL OUT.png            S0-S3 at three yaws, S4 wrecks
//	rigsheet sets BAKE RIG OUT.png HULL...           the same tour with different module sets, side by side
//	rigsheet mock BAKE RIG OUT.png HULL [zoom] [x]   phone-scale in-context mock (360 x 520 arena, zoomed out, spill)
//	rigsheet lineup RIG OUT.png [BAKE] HULL...       tour escalation lineup (clay, or finished when baked)
//	rigsheet poseatlas BAKE RIG HULL TEXEL COLS OUT.png [OUT.dart CLASS]
//	                                                 articulated family: every pose finished, one cell, one page
//	rigsheet posesheet BAKE RIG HULL TEXEL OUT.png TITLE   clay and finished poses by tilt and direction
//	rigsheet posecands RIG HULL TEXEL OUT.png TITLE PICK RAW...  hero candidates: raw + finished rest pose

import (
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		fail("usage: see the header of tools/rigsheet/main.go")
	}
	a := os.Args[2:]
	switch os.Args[1] {
	case "ctl":
		r := readRig(a[0], a[1])
		save(a[4], keyIn(clayHint(r, a[2], a[3]), keyCol))
	case "fit":
		r := readRig(a[1], a[2])
		fit := fitRawOpt(load(a[0]), r, a[3], a[4], len(a) > 7 && a[7] == "bbox")
		if len(a) > 6 && a[6] != "none" {
			fit = symmetrise(fit, r, a[6] == "left")
		}
		save(a[5], fit)
	case "finish": // RAW RIG HULL STAGE TAG TEXEL OUT.png: one finished image (e.g. the belly) at TEXEL px per unit
		r := readRig(a[1], a[2])
		var tx float64
		fmt.Sscan(a[5], &tx)
		fit := fitRaw(load(a[0]), r, a[3], a[4])
		save(a[6], finishAt(fit, r, tx, readFamily(r.Family).palette(), true))
	case "maskdiff":
		r := readRig(a[1], a[2])
		out, n := maskDiff(load(a[0]), r, a[3], a[4], tag(45, 0))
		save(a[5], out)
		fmt.Printf("maskdiff: %d texels dropped\n", n)
	case "kit":
		cmdKit(a)
	case "heroes":
		cmdHeroes(a)
	case "bakefinish":
		cmdBakeFinish(a)
	case "regional":
		cmdRegional(a)
	case "regionmerge":
		cmdRegionMerge(a)
	case "v3sheet":
		cmdV3Sheet(a)
	case "fielddata":
		cmdFieldData(a)
	case "budget":
		cmdBudget(a)
	case "views":
		cmdViews(a)
	case "stages":
		cmdStages(a)
	case "sets":
		cmdSets(a)
	case "mock":
		cmdMock(a)
	case "lineup":
		cmdLineup(a)
	case "grid":
		cmdGrid(a)
	case "poseatlas":
		cmdPoseAtlas(a)
	case "posesheet":
		cmdPoseSheet(a)
	case "posecands":
		cmdPoseCands(a)
	default:
		fail("unknown command %s", os.Args[1])
	}
}

var (
	bgDark  = hex("#120F1A")
	bgPanel = hex("#1E1B28")
	ink     = hex("#E6E2F0")
	dim     = hex("#968AAA")
)

// kit: per hull, the 3x3 clay views (hints drawn in) with the overlay, then the
// hero view's id, depth, normal and the S2 / S3 clay.
func cmdKit(a []string) {
	rigDir, out, hulls := a[0], a[1], a[2:]
	k := 0.42
	pad := 12
	var rigs []*Rig
	W, H := 0, 50
	for _, h := range hulls {
		r := readRig(rigDir, h)
		rigs = append(rigs, r)
		cw, ch := int((r.Frame[2]-r.Frame[0])*k), int((r.Frame[3]-r.Frame[1])*k)
		W = max(W, pad+5*(cw+pad)+20)
		H += 34 + 3*(ch+pad+16) + pad
	}
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 14, 3, "ALIEN CARRIER KIT TURNTABLES - CLAY WITH HINTS (VIOLET CRYSTAL, ORANGE EMBER, BLACK OPENINGS); CYAN = SIM WINDOWS, GOLD = SOLID BODY", ink)
	y := 50
	for _, r := range rigs {
		cw, ch := int((r.Frame[2]-r.Frame[0])*k), int((r.Frame[3]-r.Frame[1])*k)
		fails := 0
		for _, v := range r.Views {
			for _, s := range v.Stages {
				fails += len(s.Fail)
			}
		}
		gate := "OK"
		if fails > 0 {
			gate = fmt.Sprintf("%d FAILS", fails)
		}
		text(sheet, pad, y+4, 3, fmt.Sprintf("%s  %s  %d INSTANCES  FRAME %.0f X %.0f UNITS  ANCHOR GATE %s", strings.ToUpper(r.Hull), r.Title, len(r.Insts),
			r.Frame[2]-r.Frame[0], r.Frame[3]-r.Frame[1], gate), ink)
		y += 34
		for i, p := range []int{38, 45, 52} {
			for j, yw := range []int{-12, 0, 12} {
				x := pad + j*(cw+pad)
				yy := y + i*(ch+pad+16)
				fill(sheet, image.Rect(x, yy, x+cw, yy+ch), bgPanel)
				if _, err := os.Stat(r.path("S0", "clay", tag(p, yw))); err != nil {
					continue
				}
				blit(sheet, clayHint(r, "S0", tag(p, yw)), x, yy, k/r.PPU)
				overlay(sheet, r, x, yy, k)
				text(sheet, x, yy+ch+4, 2, fmt.Sprintf("PITCH %d YAW %+d", p, yw), dim)
			}
		}
		hero := tag(45, 0)
		items := []struct{ label, stage, kind string }{
			{"MODULE IDS", "S0", "id"}, {"DEPTH", "S0", "depth"},
			{"S2 ARMOUR SHED", "S2", "clay"}, {"S3 FIRST MODULE GONE", "S3", "clay"},
			{"NORMAL", "S0", "normal"}, {"HINTS", "S0", "hint"},
		}
		for n, it := range items {
			x := pad + 3*(cw+pad) + 20 + (n%2)*(cw+pad)
			yy := y + (n/2)*(ch+pad+16)
			if x+cw > W {
				continue
			}
			fill(sheet, image.Rect(x, yy, x+cw, yy+ch), bgPanel)
			p := r.path(it.stage, it.kind, hero)
			if _, err := os.Stat(p); err != nil {
				continue
			}
			var im *image.NRGBA
			if it.kind == "clay" {
				im = clayHint(r, it.stage, hero)
			} else {
				im = load(p)
			}
			blit(sheet, im, x, yy, k/r.PPU)
			text(sheet, x, yy+ch+4, 2, it.label+" (HERO VIEW)", dim)
		}
		y += 3*(ch+pad+16) + pad
	}
	save(out, sheet)
	fmt.Println(out)
}

// heroes: one row per candidate raw: the raw, the finished hero at the finest texel
// density with the overlay, and the phone-scale view (zoom 0.7 at DPR 2 -> 1.4 px/unit).
func cmdHeroes(a []string) {
	rigDir, hull, out, title, raws := a[0], a[1], a[2], a[3], a[4:]
	r := readRig(rigDir, hull)
	fam := readFamily(r.Family)
	pal := fam.palette()
	kr := 0.55 // raw shown at 0.55 px per unit
	kp := 1.4  // phone: zoom 0.70 x DPR 2
	fw, fh := r.Frame[2]-r.Frame[0], r.Frame[3]-r.Frame[1]
	cw0, ch := int(fw*kr), int(fh*kr)
	cw1 := int(fw * kp)
	ch1 := int(fh * kp)
	rowH := max(ch, ch1) + 30
	pad := 12
	W := pad + cw0 + pad + cw1 + pad
	ctl := keyIn(clayHint(r, "S0", tag(45, 0)), keyCol)
	H := 50 + (len(raws)+1)*rowH
	sheet := newCanvas(W, H, bgDark)
	text(sheet, pad, 14, 3, title, ink)
	y := 50
	blit(sheet, ctl, pad, y, float64(cw0)/float64(ctl.Bounds().Dx()))
	text(sheet, pad, y+ch+4, 2, "CONTROL: CLAY + HINTS ON KEY", dim)
	y += rowH
	for _, raw := range raws {
		im := load(raw)
		blit(sheet, im, pad, y, float64(cw0)/float64(im.Bounds().Dx()))
		fit := fitRaw(im, r, "S0", tag(45, 0))
		fin := finishAt(fit, r, kp, pal, true)
		x1 := pad + cw0 + pad
		fill(sheet, image.Rect(x1, y, x1+cw1, y+ch1), hex("#2B3A55"))
		blit(sheet, fin, x1, y, 1)
		overlay(sheet, r, x1, y, kp)
		text(sheet, pad, y+max(ch, ch1)+6, 2, strings.ToUpper(filepath.Base(raw))+"   RAW | FINISHED AT PHONE DENSITY (ZOOM 0.70, DPR 2 = 1.4 PX PER UNIT) WITH SIM WINDOWS", dim)
		y += rowH
	}
	save(out, sheet)
	fmt.Println(out)
}

func mustStat(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func round(x float64) int { return int(math.Round(x)) }

// grid: a quick contact grid of images (cols per row, each scaled to width w), labelled by file name.
//
//	rigsheet grid OUT.png COLS W IMG...
func cmdGrid(a []string) {
	var cols, w int
	fmt.Sscan(a[1], &cols)
	fmt.Sscan(a[2], &w)
	ims := a[3:]
	var cells []*image.NRGBA
	h := 0
	for _, p := range ims {
		im := load(p)
		if k := float64(w) / float64(im.Bounds().Dx()); k < 1 {
			im = areaScale(im, k)
		} else {
			up := image.NewNRGBA(image.Rect(0, 0, w, int(float64(im.Bounds().Dy())*k)))
			blit(up, im, 0, 0, k)
			im = up
		}
		cells = append(cells, im)
		h = max(h, im.Bounds().Dy())
	}
	rows := (len(cells) + cols - 1) / cols
	sheet := newCanvas(cols*(w+8)+8, rows*(h+24)+8, bgDark)
	for i, im := range cells {
		x, y := 8+(i%cols)*(w+8), 8+(i/cols)*(h+24)
		blit(sheet, im, x, y, 1)
		text(sheet, x, y+h+5, 2, strings.ToUpper(filepath.Base(filepath.Dir(ims[i]))+"/"+filepath.Base(ims[i])), dim)
	}
	save(a[0], sheet)
}
