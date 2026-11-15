// Command ground_blocks is the reproducible pipeline for the reworked
// ground war atlases (openspec/changes/ground-forces-rework): per-unit
// blocks of headings, articulated layers, overlays and states, rendered
// from rigs on the texel grid, packed per sector with the sector kit baked
// in, plus the generated Dart metadata and review sheets.
//
// Go standard library plus the shared rasteriser tools/pixelgrid.
//
//	go run . validate   check the three family specs against the rigs
//	go run . rig [id]   render rig references (x8 on the key colour) for the
//	                    GPU jobs into $BLOCKS_WORK/rig/
//	go run . jobs       write the ComfyUI queue ($BLOCKS_WORK/jobs.json):
//	                    hero, heading and layer edits per unit
//	go run . ingest     copy raws to $BLOCKS_RAW, record provenance in the
//	                    families' -runs.json files
//	go run . finish IN CELL OUT   put one AI image on the grid: area
//	                    downscale, palette quantise, mask to the rig
//	                    silhouette (soft edges +-1), binary alpha, ink
//	go run . bake UNIT [CELL=IMG ..]  carry the AI colour of the unit's
//	                    keyframes (hull.ref.hNNN / art.ref.aNNN raws; by default
//	                    the committed ones in art/sprites/sources/
//	                    ground-blocks-selected/UNIT/) onto every base cell of
//	                    its block, by rig surface point; writes finished cells
//	go run . bakesheet OUT UNIT [substr ..]  rig | baked review pairs
//	go run . pack       pack every sector atlas from finished cells where
//	                    they exist, else from the rig; write the metadata
//	go run . offline    pack from the rig alone (no GPU, byte-identical)
//	go run . contact    the CP0 sheet art/contact/ground-rig-turntables.png
package main

import (
	"errors"
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"

	"demonattack/tools/pixelgrid"
)

var root string

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

func fail(err error) {
	fmt.Fprintln(os.Stderr, "ground_blocks:", err)
	os.Exit(1)
}

func must(err error) {
	if err != nil {
		fail(err)
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func workDir() string {
	h, _ := os.UserHomeDir()
	return envOr("BLOCKS_WORK", filepath.Join(h, ".cache/demon-attack/ground-blocks/work"))
}

func rawDir() string {
	h, _ := os.UserHomeDir()
	return envOr("BLOCKS_RAW", filepath.Join(h, ".cache/demon-attack/ground-blocks/raw"))
}

func main() {
	root = findRoot()
	if len(os.Args) < 2 {
		fmt.Println("usage: go run . validate|rig [id]|control [id]|sheet OUT CELL=RAW..|bake UNIT|bakesheet OUT UNIT|jobs|ingest|finish IN CELL OUT|pack|offline|contact")
		os.Exit(2)
	}
	args := os.Args[2:]
	switch os.Args[1] {
	case "validate":
		cmdValidate()
	case "rig":
		cmdRig(args)
	case "jobs":
		cmdJobs()
	case "ingest":
		cmdIngest()
	case "finish":
		cmdFinish(args)
	case "pack":
		cmdPack(true)
	case "offline":
		cmdPack(false)
	case "contact":
		cmdContact()
	case "block":
		cmdBlock(args)
	case "bakesheet":
		cmdBakeSheet(args)
	case "bake":
		cmdBake(args)
	case "sheet":
		cmdSheet(args)
	case "control":
		cmdControl(args)
	default:
		fail(fmt.Errorf("unknown verb %q", os.Args[1]))
	}
}

// cmdBlock: a review render of one unit's block at x4 (debug aid).
func cmdBlock(args []string) {
	p := loadProject()
	u := p.unit(args[0])
	b := p.builder(u)
	cs := p.cellsOf(u)
	rows := blockRows(u.Spec.Block)
	cw, ch := b.CW, u.Fam.Atlas.Cell[1]
	img := image.NewNRGBA(image.Rect(0, 0, 20*cw, rows*ch))
	fill(img, img.Bounds(), color.NRGBA{58, 56, 62, 255})
	pal := p.Pals[u.faction()]
	for i := range cs {
		pal.paintCell(img, &cs[i], cs[i].Col*cw, cs[i].Row*ch, p.masterSector(u), b.Rig.Seed)
	}
	out := image.NewNRGBA(image.Rect(0, 0, 20*cw*4, rows*ch*4))
	blit(out, img, 0, 0, 4, false)
	must(pixelgrid.WritePNG(args[1], out))
	fmt.Println(len(cs), "cells ->", args[1])
}
