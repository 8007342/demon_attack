// Command ground_atmosphere builds the ground atmosphere atlas
// (openspec/changes/ground-forces-rework tasks 6.1/6.2, design
// plan/ground-atmosphere.md): horizon fog, low cloud, two mist banks and a
// dust veil per sector, plus shared cloud shadows and smoke sprites. Every
// layer is procedural (seeded periodic noise on the texel grid) with
// stepped alpha, so the build is deterministic and needs no GPU.
//
// Go standard library plus the shared tools/pixelgrid (hashing, PNG
// encoding, luma), the same toolchain as tools/ground_blocks and
// tools/ground_troops.
//
//	go run . pack      write assets/images/ground-atmosphere.png,
//	                   lib/game/ground_atmosphere_atlas.dart and
//	                   art/families/ground-atmosphere-runs.json
//	go run . check     regenerate in memory and compare with the committed
//	                   files (exit 1 on any difference)
//	go run . preview OUT  the atlas at x2 over each sector's ground colour
package main

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
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
	fmt.Fprintln(os.Stderr, "ground_atmosphere:", err)
	os.Exit(1)
}

func must(err error) {
	if err != nil {
		fail(err)
	}
}

func main() {
	root = findRoot()
	if len(os.Args) < 2 {
		fmt.Println("usage: go run . pack|check|preview OUT")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "pack":
		out := build(loadSpec())
		for _, f := range out.files() {
			must(os.MkdirAll(filepath.Dir(filepath.Join(root, f.path)), 0o755))
			must(os.WriteFile(filepath.Join(root, f.path), f.data, 0o644))
			fmt.Printf("%s (%d bytes)\n", f.path, len(f.data))
		}
		for s, t := range out.Tints {
			fmt.Printf("%-8s fog %s (sampled %s) smoke %s\n", out.Spec.Sectors[s].ID,
				hex(t.Fog), hex(t.Sample), hex(t.Smoke))
		}
	case "check":
		out := build(loadSpec())
		bad := false
		for _, f := range out.files() {
			old, err := os.ReadFile(filepath.Join(root, f.path))
			if err != nil || !bytes.Equal(old, f.data) {
				fmt.Println("stale:", f.path)
				bad = true
			}
		}
		if bad {
			os.Exit(1)
		}
		fmt.Println("ok: committed atlas, Dart metadata and runs match the generator")
	case "preview":
		if len(os.Args) < 3 {
			fail(errors.New("preview OUT"))
		}
		out := build(loadSpec())
		must(writePNG(os.Args[2], out.preview()))
		fmt.Println(os.Args[2])
	default:
		fail(fmt.Errorf("unknown verb %q", os.Args[1]))
	}
}
