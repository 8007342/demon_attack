// Command ground_troops is the reproducible pipeline for the ground war v4
// troops atlas: demon infantry and rocket troopers, a demon heavy tank and
// allied rifle and rocket troopers.
//
// Go standard library only. Driven by art/families/ground-troops.json.
//
//	go run . jobs      write the ComfyUI queue (LayerDiffuse keyframes,
//	                   3 candidate seeds per unit) to $TROOPS_WORK/jobs.json
//	go run . run       execute it against COMFY_URL (default http://studio:8188),
//	                   one job in flight; outputs in $TROOPS_WORK/http
//	go run . ingest    copy raws to $TROOPS_RAW (never the checkout), record
//	                   provenance in art/families/ground-troops-runs.json and
//	                   refresh the selected sources of record under
//	                   art/sprites/sources/ground-troops/
//	go run . pack      refresh sources from raws if present, then offline
//	go run . offline   committed sources -> assets/images/ground-troops.png,
//	                   lib/game/ground_troops_atlas.dart and
//	                   art/contact/ground-troops-contact.png (no GPU,
//	                   byte-identical on every run)
//
// Silhouettes and every frame are authored on the texel grid; the AI
// keyframe contributes only a -1/0/+1 shading texture on the body ramp.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Spec
// ---------------------------------------------------------------------------

type Unit struct {
	ID       string `json:"id"`
	Row      int    `json:"row"`
	Side     string `json:"side"`
	Kind     string `json:"kind"`
	Seed     int    `json:"seed"`
	Selected int    `json:"selected"`
	Prompt   string `json:"prompt"`
}

type Spec struct {
	StylePrompt    string `json:"style_prompt"`
	NegativePrompt string `json:"negative_prompt"`
	Sprite         struct {
		Workflow   string `json:"workflow"`
		Candidates int    `json:"candidates"`
		SourcePx   int    `json:"source_px"`
	} `json:"sprite"`
	Units []Unit `json:"units"`
}

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
	fmt.Fprintln(os.Stderr, "ground_troops:", err)
	os.Exit(1)
}

func must(err error) {
	if err != nil {
		fail(err)
	}
}

func loadSpec() Spec {
	b, err := os.ReadFile(filepath.Join(root, "art/families/ground-troops.json"))
	must(err)
	var s Spec
	must(json.Unmarshal(b, &s))
	return s
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func workDir() string {
	h, _ := os.UserHomeDir()
	return envOr("TROOPS_WORK", filepath.Join(h, ".cache/demon-attack/ground-troops/work"))
}

func rawDir() string {
	h, _ := os.UserHomeDir()
	return envOr("TROOPS_RAW", filepath.Join(h, ".cache/demon-attack/ground-troops/raw"))
}

// ---------------------------------------------------------------------------
// GPU stages
// ---------------------------------------------------------------------------

type Job struct {
	ID        string         `json:"id"`
	Unit      string         `json:"unit"`
	Workflow  string         `json:"workflow"`
	Inputs    map[string]any `json:"inputs"`
	Overrides map[string]any `json:"overrides"`
}

func jobList(s Spec) []Job {
	var jobs []Job
	for _, e := range s.Units {
		for c := 0; c < s.Sprite.Candidates; c++ {
			jobs = append(jobs, Job{
				ID:       fmt.Sprintf("%s/%d", e.ID, e.Seed+c),
				Unit:     e.ID,
				Workflow: s.Sprite.Workflow,
				Inputs:   map[string]any{},
				Overrides: map[string]any{
					"prompt":                   fmt.Sprintf("%s, %s, transparent background", s.StylePrompt, e.Prompt),
					"negative_prompt":          s.NegativePrompt,
					"seed":                     e.Seed + c,
					"$node:10.filename_prefix": "ground-troops/sprite-rgb",
					"$node:12.filename_prefix": "ground-troops/sprite-alpha",
				},
			})
		}
	}
	return jobs
}

func cmdJobs() {
	jobs := jobList(loadSpec())
	must(os.MkdirAll(workDir(), 0o755))
	b, _ := json.MarshalIndent(jobs, "", " ")
	must(os.WriteFile(filepath.Join(workDir(), "jobs.json"), b, 0o644))
	fmt.Printf("%d jobs -> %s\n", len(jobs), filepath.Join(workDir(), "jobs.json"))
}

// bindWorkflow fills the workflow placeholders by node title, as the studio
// tool and tools/flyover_assets.py do.
func bindWorkflow(j Job) map[string]map[string]any {
	b, err := os.ReadFile(filepath.Join(root, j.Workflow))
	must(err)
	var wf map[string]map[string]any
	must(json.Unmarshal(b, &wf))
	for _, node := range wf {
		meta, _ := node["_meta"].(map[string]any)
		title, _ := meta["title"].(string)
		ins := node["inputs"].(map[string]any)
		switch title {
		case "$prompt":
			ins["text"] = j.Overrides["prompt"]
		case "$negative_prompt":
			ins["text"] = j.Overrides["negative_prompt"]
		case "$seed":
			ins["seed"] = j.Overrides["seed"]
		}
	}
	for k, v := range j.Overrides {
		if strings.HasPrefix(k, "$node:") {
			parts := strings.SplitN(k[6:], ".", 2)
			wf[parts[0]]["inputs"].(map[string]any)[parts[1]] = v
		}
	}
	return wf
}

func httpJSON(u string, body any) map[string]any {
	var resp *http.Response
	var err error
	if body != nil {
		b, _ := json.Marshal(body)
		resp, err = http.Post(u, "application/json", bytes.NewReader(b))
	} else {
		resp, err = http.Get(u)
	}
	must(err)
	defer resp.Body.Close()
	var out map[string]any
	must(json.NewDecoder(resp.Body).Decode(&out))
	return out
}

func cmdRun(only string, force bool) {
	base := strings.TrimRight(envOr("COMFY_URL", "http://studio:8188"), "/")
	for _, j := range jobList(loadSpec()) {
		if only != "" && !hasAnyPrefix(j.ID, strings.Split(only, ",")) {
			continue
		}
		dest := filepath.Join(workDir(), "http", strings.ReplaceAll(j.ID, "/", "__"))
		if pngs, _ := filepath.Glob(filepath.Join(dest, "*.png")); len(pngs) >= 2 && !force {
			continue
		}
		pid := httpJSON(base+"/prompt", map[string]any{"prompt": bindWorkflow(j)})["prompt_id"].(string)
		var hist map[string]any
		for {
			hist = httpJSON(base+"/history/"+pid, nil)
			if _, ok := hist[pid]; ok {
				break
			}
			time.Sleep(3 * time.Second)
		}
		os.RemoveAll(dest)
		must(os.MkdirAll(dest, 0o755))
		outs := hist[pid].(map[string]any)["outputs"].(map[string]any)
		for _, no := range outs {
			ims, _ := no.(map[string]any)["images"].([]any)
			for _, im := range ims {
				m := im.(map[string]any)
				q := url.Values{"filename": {m["filename"].(string)}, "subfolder": {m["subfolder"].(string)}, "type": {m["type"].(string)}}
				r, err := http.Get(base + "/view?" + q.Encode())
				must(err)
				b, _ := io.ReadAll(r.Body)
				r.Body.Close()
				must(os.WriteFile(filepath.Join(dest, m["filename"].(string)), b, 0o644))
			}
		}
		jb, _ := json.MarshalIndent(j, "", " ")
		must(os.WriteFile(filepath.Join(dest, "job.json"), jb, 0o644))
		fmt.Println(j.ID, "ok")
	}
}

func hasAnyPrefix(s string, ps []string) bool {
	for _, p := range ps {
		if strings.HasPrefix(s, p) {
			return true
		}
	}
	return false
}

func cmdIngest() {
	s := loadSpec()
	jobs := map[string]Job{}
	for _, j := range jobList(s) {
		jobs[j.ID] = j
	}
	runsPath := filepath.Join(root, "art/families/ground-troops-runs.json")
	runs := map[string]any{}
	if b, err := os.ReadFile(runsPath); err == nil {
		must(json.Unmarshal(b, &runs))
	}
	entries, _ := os.ReadDir(filepath.Join(workDir(), "http"))
	n := 0
	for _, d := range entries {
		jid := strings.ReplaceAll(d.Name(), "__", "/")
		j, ok := jobs[jid]
		if !ok || !d.IsDir() {
			continue
		}
		dest := filepath.Join(rawDir(), jid)
		os.RemoveAll(dest)
		must(os.MkdirAll(dest, 0o755))
		var outputs []map[string]string
		pngs, _ := filepath.Glob(filepath.Join(workDir(), "http", d.Name(), "*.png"))
		sort.Strings(pngs)
		for _, p := range pngs {
			b, err := os.ReadFile(p)
			must(err)
			must(os.WriteFile(filepath.Join(dest, filepath.Base(p)), b, 0o644))
			h := sha256.Sum256(b)
			outputs = append(outputs, map[string]string{"file": filepath.Base(p), "sha256": hex.EncodeToString(h[:])})
		}
		runs[jid] = map[string]any{
			"workflow":        j.Workflow,
			"prompt":          j.Overrides["prompt"],
			"negative_prompt": j.Overrides["negative_prompt"],
			"seed":            j.Overrides["seed"],
			"models": []string{"layer_xl_transparent_conv.safetensors", "pixel-art-xl.safetensors",
				"sdxl-full/sd_xl_base_1.0.safetensors", "vae_transparent_decoder.safetensors"},
			"outputs": outputs,
		}
		n++
	}
	b, _ := json.MarshalIndent(runs, "", " ") // map keys are sorted
	must(os.WriteFile(runsPath, append(b, '\n'), 0o644))
	fmt.Println("ingested", n)
	writeSources(s)
}

func readPNG(p string) (image.Image, error) {
	f, err := os.Open(p)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return png.Decode(f)
}

func writePNG(p string, im image.Image) {
	must(os.MkdirAll(filepath.Dir(p), 0o755))
	var buf bytes.Buffer
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	must(enc.Encode(&buf, im))
	must(os.WriteFile(p, buf.Bytes(), 0o644))
}

// writeSources crops each selected keyframe to its LayerDiffuse alpha and
// box-downscales it to at most source_px: the inputs of record for offline.
func writeSources(s Spec) {
	for _, e := range s.Units {
		dir := filepath.Join(rawDir(), e.ID, fmt.Sprint(e.Selected))
		rgbs, _ := filepath.Glob(filepath.Join(dir, "sprite-rgb*.png"))
		als, _ := filepath.Glob(filepath.Join(dir, "sprite-alpha*.png"))
		if len(rgbs) == 0 || len(als) == 0 {
			fmt.Println("missing raw", e.ID, e.Selected)
			continue
		}
		sort.Strings(rgbs)
		sort.Strings(als)
		rgb, err := readPNG(rgbs[0])
		must(err)
		al, err := readPNG(als[0])
		must(err)
		b := al.Bounds()
		x0, y0, x1, y1 := b.Max.X, b.Max.Y, -1, -1
		for y := b.Min.Y; y < b.Max.Y; y++ {
			for x := b.Min.X; x < b.Max.X; x++ {
				r, _, _, _ := al.At(x, y).RGBA()
				if r>>8 >= 140 {
					x0, y0 = min(x0, x), min(y0, y)
					x1, y1 = max(x1, x), max(y1, y)
				}
			}
		}
		if x1 < 0 {
			continue
		}
		w, h := x1-x0+1, y1-y0+1
		k := math.Min(1, float64(s.Sprite.SourcePx)/float64(max(w, h)))
		ow, oh := max(1, int(math.Round(float64(w)*k))), max(1, int(math.Round(float64(h)*k)))
		out := image.NewNRGBA(image.Rect(0, 0, ow, oh))
		for oy := 0; oy < oh; oy++ {
			for ox := 0; ox < ow; ox++ {
				sx0, sx1 := x0+ox*w/ow, x0+(ox+1)*w/ow
				sy0, sy1 := y0+oy*h/oh, y0+(oy+1)*h/oh
				var rs, gs, bs, as, n float64
				for y := sy0; y < max(sy1, sy0+1); y++ {
					for x := sx0; x < max(sx1, sx0+1); x++ {
						r, g, bb, _ := rgb.At(x, y).RGBA()
						a, _, _, _ := al.At(x, y).RGBA()
						rs += float64(r >> 8)
						gs += float64(g >> 8)
						bs += float64(bb >> 8)
						as += float64(a >> 8)
						n++
					}
				}
				out.SetNRGBA(ox, oy, color.NRGBA{uint8(rs / n), uint8(gs / n), uint8(bs / n), uint8(as / n)})
			}
		}
		writePNG(filepath.Join(root, "art/sprites/sources/ground-troops", e.ID+".png"), out)
		fmt.Println("source", e.ID, ow, oh)
	}
}

func main() {
	root = findRoot()
	if len(os.Args) < 2 {
		fmt.Println("usage: go run . jobs|run [--only a,b] [--force]|ingest|pack|offline")
		os.Exit(2)
	}
	only, force := "", false
	for i := 2; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "--only":
			if i+1 < len(os.Args) {
				only = os.Args[i+1]
				i++
			}
		case "--force":
			force = true
		}
	}
	switch os.Args[1] {
	case "jobs":
		cmdJobs()
	case "run":
		cmdRun(only, force)
	case "ingest":
		cmdIngest()
	case "pack":
		writeSources(loadSpec())
		cmdOffline()
	case "offline":
		cmdOffline()
	default:
		fail(fmt.Errorf("unknown stage %q", os.Args[1]))
	}
}
