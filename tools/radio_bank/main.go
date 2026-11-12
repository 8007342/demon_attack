// radio-bank validates model candidates and assembles the modern PWA bank.
// Only required model inference remains in Python; validation/copying is Go.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type Line struct {
	Speaker string `json:"speaker"`
	Text    string `json:"text"`
	Gloss   string `json:"gloss"`
}
type Part struct {
	Lines []Line `json:"lines"`
	Demon *Part  `json:"demon"`
}
type Source struct {
	Triggers map[string]Part `json:"triggers"`
}
type Expected struct{ ID, Trigger, Kind, Speaker, Text string }
type Master struct {
	SHA string `json:"sha256"`
}
type Metadata struct {
	Schema   string            `json:"schema"`
	ID       string            `json:"id"`
	Speaker  string            `json:"speaker"`
	Kind     string            `json:"kind"`
	Trigger  string            `json:"trigger"`
	Text     string            `json:"text"`
	Engine   string            `json:"engine"`
	Emotion  string            `json:"emotion"`
	Samples  int               `json:"samples"`
	Mouth    string            `json:"mouth"`
	Open     string            `json:"open"`
	Vis      string            `json:"vis"`
	LUFS     float64           `json:"lufs"`
	Fallback string            `json:"fallback"`
	Inputs   map[string]string `json:"input_hashes"`
	Masters  map[string]Master `json:"masters"`
	Codec    struct {
		Name    string `json:"name"`
		SHA     string `json:"sha256"`
		Bitrate int    `json:"bitrate_kbps"`
	} `json:"codec"`
}
type Clip struct {
	Speaker        string            `json:"speaker"`
	Kind           string            `json:"kind"`
	Trigger        string            `json:"trigger"`
	Engine         string            `json:"engine"`
	Emotion        string            `json:"emotion,omitempty"`
	Fallback       string            `json:"fallback,omitempty"`
	Duration       float64           `json:"duration"`
	Mouth          string            `json:"mouth"`
	Open           string            `json:"open"`
	Vis            string            `json:"vis"`
	LUFS           float64           `json:"lufs"`
	OggBytes       int64             `json:"ogg_bytes"`
	SHA            map[string]string `json:"sha256"`
	DecodedSamples int               `json:"decoded_samples"`
	DecodedPeak    float64           `json:"decoded_peak_dbfs"`
	DecodedLUFS    float64           `json:"decoded_lufs"`
}

type Biquad struct{ b0, b1, b2, a1, a2, x1, x2, y1, y2 float64 }

func (b *Biquad) sample(x float64) float64 {
	y := b.b0*x + b.b1*b.x1 + b.b2*b.x2 - b.a1*b.y1 - b.a2*b.y2
	b.x2 = b.x1
	b.x1 = x
	b.y2 = b.y1
	b.y1 = y
	return y
}
func kFilters() (Biquad, Biquad) {
	const sr = 24000.0
	a := math.Pow(10, 3.99984/40)
	w := 2 * math.Pi * 1681.97 / sr
	alpha := math.Sin(w) / (2 * .7071752)
	cw := math.Cos(w)
	d := (a + 1) - (a-1)*cw + 2*math.Sqrt(a)*alpha
	shelf := Biquad{b0: a * ((a + 1) + (a-1)*cw + 2*math.Sqrt(a)*alpha) / d,
		b1: -2 * a * ((a - 1) + (a+1)*cw) / d, b2: a * ((a + 1) + (a-1)*cw - 2*math.Sqrt(a)*alpha) / d,
		a1: 2 * ((a - 1) - (a+1)*cw) / d, a2: ((a + 1) - (a-1)*cw - 2*math.Sqrt(a)*alpha) / d}
	k := math.Tan(math.Pi * 38.13 / sr)
	norm := 1 / (1 + math.Sqrt2*k + k*k)
	hp := Biquad{b0: norm, b1: -2 * norm, b2: norm, a1: 2 * (k*k - 1) * norm, a2: (1 - math.Sqrt2*k + k*k) * norm}
	return shelf, hp
}
func loudness(samples []float64) float64 {
	shelf, hp := kFilters()
	n := len(samples)
	if n < 9600 {
		n = 9600
	}
	prefix := make([]float64, n+1)
	for i, x := range samples {
		y := hp.sample(shelf.sample(x))
		prefix[i+1] = prefix[i] + y*y
	}
	for i := len(samples); i < n; i++ {
		prefix[i+1] = prefix[i]
	}
	var power []float64
	for i := 0; i+9600 <= n; i += 2400 {
		z := (prefix[i+9600] - prefix[i]) / 9600
		if -.691+10*math.Log10(z+1e-12) > -70 {
			power = append(power, z)
		}
	}
	if len(power) == 0 {
		return -70
	}
	var total float64
	for _, z := range power {
		total += z
	}
	threshold := -.691 + 10*math.Log10(total/float64(len(power))+1e-12) - 10
	total = 0
	kept := 0
	for _, z := range power {
		if -.691+10*math.Log10(z+1e-12) > threshold {
			total += z
			kept++
		}
	}
	if kept == 0 {
		return -70
	}
	return -.691 + 10*math.Log10(total/float64(kept)+1e-12)
}
func digest(path string) (string, error) {
	f, e := os.Open(path)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	if _, e = io.Copy(h, f); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
func copyFile(from, to string) error {
	f, e := os.Open(from)
	if e != nil {
		return e
	}
	defer f.Close()
	g, e := os.Create(to + ".tmp")
	if e != nil {
		return e
	}
	_, e = io.Copy(g, f)
	if c := g.Close(); e == nil {
		e = c
	}
	if e != nil {
		return e
	}
	return os.Rename(to+".tmp", to)
}
func loadJSON(path string, to any) error {
	b, e := os.ReadFile(path)
	if e != nil {
		return e
	}
	return json.Unmarshal(b, to)
}
func writeJSON(path string, v any) error {
	b, e := json.MarshalIndent(v, "", " ")
	if e != nil {
		return e
	}
	if e = os.WriteFile(path+".tmp", append(b, '\n'), 0644); e != nil {
		return e
	}
	return os.Rename(path+".tmp", path)
}
func expected(source Source) []Expected {
	var keys []string
	for key := range source.Triggers {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	var all []Expected
	for _, t := range keys {
		p := source.Triggers[t]
		for i, l := range p.Lines {
			all = append(all, Expected{fmt.Sprintf("%s.h%d", t, i), t, "human", l.Speaker, l.Text})
		}
		if p.Demon != nil {
			for i, l := range p.Demon.Lines {
				all = append(all, Expected{fmt.Sprintf("%s.d%d", t, i), t, "demon", l.Speaker, l.Gloss})
			}
		}
	}
	return all
}
func validateTiming(m Metadata) error {
	if m.Samples < 7200 || m.Samples > 24000*30 {
		return fmt.Errorf("implausible duration: %d samples", m.Samples)
	}
	if len(m.Mouth) != len(m.Open) || len(m.Mouth) != len(m.Vis) || math.Abs(float64(len(m.Mouth))-float64(m.Samples)/1600) > 1.01 {
		return fmt.Errorf("mouth track duration mismatch")
	}
	if strings.Trim(m.Open, "0") == "" {
		return fmt.Errorf("voice has no mouth movement")
	}
	for start := 0; start < len(m.Mouth); {
		end := start + 1
		for end < len(m.Mouth) && m.Mouth[end] == m.Mouth[start] {
			end++
		}
		if end-start < 2 {
			return fmt.Errorf("single-frame mouth flicker")
		}
		start = end
	}
	for i, c := range m.Mouth {
		if !strings.ContainsRune("0123456789<=>", c) {
			return fmt.Errorf("unknown mouth shape %q", c)
		}
		if m.Open[i] < '0' || m.Open[i] > '9' {
			return fmt.Errorf("invalid openness")
		}
		if !strings.ContainsRune("-oe", rune(m.Vis[i])) {
			return fmt.Errorf("invalid viseme")
		}
	}
	return nil
}
func decode(ffmpeg, path string) ([]float64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, ffmpeg, "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", "24000", "-")
	raw, e := cmd.Output()
	if e != nil {
		return nil, fmt.Errorf("decode: %w", e)
	}
	if len(raw)%4 != 0 || len(raw) > 4*24000*30 {
		return nil, fmt.Errorf("invalid decoded audio length")
	}
	samples := make([]float64, len(raw)/4)
	for i := range samples {
		samples[i] = float64(math.Float32frombits(binary.LittleEndian.Uint32(raw[i*4:])))
		if math.IsNaN(samples[i]) || math.IsInf(samples[i], 0) {
			return nil, fmt.Errorf("non-finite decoded audio")
		}
	}
	return samples, nil
}
func validateCandidate(root string, want Expected, inputs map[string]string, ffmpeg string) (Clip, error) {
	var m Metadata
	dir := filepath.Join(root, want.ID)
	if e := loadJSON(filepath.Join(dir, "metadata.json"), &m); e != nil {
		return Clip{}, e
	}
	if m.Schema != "demon-attack.voice-candidate/v1" || m.ID != want.ID || m.Kind != want.Kind || m.Trigger != want.Trigger || m.Speaker != want.Speaker || m.Text != want.Text {
		return Clip{}, fmt.Errorf("candidate identity/text differs from source")
	}
	for p, hash := range inputs {
		if m.Inputs[p] != hash {
			return Clip{}, fmt.Errorf("stale input %s", p)
		}
	}
	if e := validateTiming(m); e != nil {
		return Clip{}, e
	}
	for _, name := range []string{"baseline", "expressive", "voice"} {
		d, e := digest(filepath.Join(dir, name+".flac"))
		if e != nil {
			return Clip{}, e
		}
		if d != m.Masters[name].SHA {
			return Clip{}, fmt.Errorf("%s master hash mismatch", name)
		}
	}
	if m.Codec.Name != "opus" || m.Codec.Bitrate < 32 {
		return Clip{}, fmt.Errorf("not the high-quality Opus candidate bank")
	}
	path := filepath.Join(dir, "radio.ogg")
	d, e := digest(path)
	if e != nil {
		return Clip{}, e
	}
	if d != m.Codec.SHA {
		return Clip{}, fmt.Errorf("Opus hash mismatch")
	}
	samples, e := decode(ffmpeg, path)
	if e != nil {
		return Clip{}, e
	}
	if math.Abs(float64(len(samples)-m.Samples)) > 2 {
		return Clip{}, fmt.Errorf("decoded sample count %d vs %d", len(samples), m.Samples)
	}
	peak := 0.0
	for _, x := range samples {
		peak = math.Max(peak, math.Abs(x))
	}
	db := 20 * math.Log10(peak+1e-12)
	lk := loudness(samples)
	target := -18.
	if want.Kind == "demon" {
		target = -18.5
	}
	if db > 0 || lk < -65 || math.Abs(lk-target) > 1.5 {
		return Clip{}, fmt.Errorf("decoded peak %.2f dBFS, loudness %.2f LUFS (target %.1f)", db, lk, target)
	}
	stat, e := os.Stat(path)
	if e != nil {
		return Clip{}, e
	}
	return Clip{Speaker: m.Speaker, Kind: m.Kind, Trigger: m.Trigger, Engine: m.Engine, Emotion: m.Emotion, Fallback: m.Fallback,
		Duration: math.Round(float64(m.Samples)/24) / 1000, Mouth: m.Mouth, Open: m.Open, Vis: m.Vis, LUFS: m.LUFS, OggBytes: stat.Size(), SHA: map[string]string{"ogg": d},
		DecodedSamples: len(samples), DecodedPeak: db, DecodedLUFS: lk}, nil
}
func run() error {
	sourceDir := flag.String("source", "assets/research/battle-metal-radio/batch-2026-11-12/voices", "candidate directory")
	out := flag.String("out", "", "staging directory (required; never infers promotion)")
	partial := flag.Bool("allow-partial", false, "development audit: write an explicitly incomplete staging bank")
	ffmpeg := flag.String("ffmpeg", "/home/linuxbrew/.linuxbrew/bin/ffmpeg", "decoder executable")
	flag.Parse()
	if *out == "" {
		return fmt.Errorf("--out is required")
	}
	absoluteOut, e := filepath.Abs(*out)
	if e != nil {
		return e
	}
	runtimeBank, e := filepath.Abs("web/audio/comms")
	if e != nil {
		return e
	}
	if absoluteOut == runtimeBank {
		return fmt.Errorf("assemble into a staging directory; the runtime bank must be promoted separately")
	}
	var source Source
	if e := loadJSON("art/comms/lines.json", &source); e != nil {
		return e
	}
	inputs := map[string]string{}
	for _, p := range []string{"art/comms/cast.json", "art/comms/lines.json", "art/comms/audio.json", "art/comms/demon-delivery.json"} {
		d, e := digest(p)
		if e != nil {
			return e
		}
		inputs[p] = d
	}
	all := expected(source)
	clips := map[string]Clip{}
	problems := map[string]string{}
	humans, demons := 0, 0
	seconds := 0.0
	var bytes int64
	if e := os.MkdirAll(*out, 0755); e != nil {
		return e
	}
	for _, want := range all {
		clip, e := validateCandidate(*sourceDir, want, inputs, *ffmpeg)
		if e != nil {
			problems[want.ID] = e.Error()
			continue
		}
		if e = copyFile(filepath.Join(*sourceDir, want.ID, "radio.ogg"), filepath.Join(*out, want.ID+".ogg")); e != nil {
			return e
		}
		clips[want.ID] = clip
		if want.Kind == "human" {
			humans++
		} else {
			demons++
		}
		seconds += clip.Duration
		bytes += clip.OggBytes
	}
	complete := len(clips) == len(all)
	report := map[string]any{"schema": "demon-attack.radio-bank-audit/v1", "complete": complete, "expected": len(all), "validated": len(clips), "problems": problems, "input_hashes": inputs, "listening_acceptance": "pending; numeric verification is not an audition"}
	if e := writeJSON(filepath.Join(*out, "audit.json"), report); e != nil {
		return e
	}
	if !complete && !*partial {
		// A previous development manifest must not look like a fresh complete build.
		if e := os.Remove(filepath.Join(*out, "manifest.json")); e != nil && !os.IsNotExist(e) {
			return e
		}
		return fmt.Errorf("%d/%d candidates valid; see %s/audit.json; no manifest written", len(clips), len(all), *out)
	}
	manifest := map[string]any{"schema": "demon-attack.comms-bank/v2", "generator": "tools/radio_bank", "complete": complete,
		"formats": []string{"ogg"}, "codec": map[string]any{"name": "opus", "opus_kbps": 48, "sample_rate": 24000}, "mouth_fps": 15,
		"review": "pending listening and synchronized mobile review", "source_hashes": inputs,
		"totals": map[string]any{"clips": len(clips), "human": humans, "demon": demons, "seconds": math.Round(seconds*100) / 100, "ogg_bytes": bytes}, "clips": clips}
	if e := writeJSON(filepath.Join(*out, "manifest.json"), manifest); e != nil {
		return e
	}
	fmt.Printf("radio-bank: %d/%d validated (%d human, %d demon), %.2f MB Opus; complete=%v\n", len(clips), len(all), humans, demons, float64(bytes)/1e6, complete)
	return nil
}
func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
