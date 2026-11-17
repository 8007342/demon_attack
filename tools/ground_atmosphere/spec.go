package main

// The family spec (art/families/ground-atmosphere.json) and the sector
// tints sampled from each sector painting's horizon.

import (
	"encoding/json"
	"image"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strings"

	"demonattack/tools/pixelgrid"
	"golang.org/x/image/webp"
)

type Spec struct {
	Schema string `json:"schema"`
	Name   string `json:"name"`
	Atlas  struct {
		File  string `json:"file"`
		Dart  string `json:"dart"`
		Runs  string `json:"runs"`
		Width int    `json:"width"`
	} `json:"atlas"`
	AlphaSteps []float64 `json:"alpha_steps"`
	Tint       struct {
		SampleRows   [2]float64 `json:"sample_rows"`
		Darken       string     `json:"darken"`
		DarkenMix    float64    `json:"darken_mix"`
		SampleWeight float64    `json:"sample_weight"`
		Luma         [2]float64 `json:"luma"`
		ChromaMax    float64    `json:"chroma_max"`
		LitLumaMax   float64    `json:"lit_luma_max"`
		DarkScale    float64    `json:"dark_scale"`
	} `json:"tint"`
	SmokeRamp []string `json:"smoke_ramp"`
	Sectors   []struct {
		ID             string  `json:"id"`
		Painting       string  `json:"painting"`
		FogStart       string  `json:"fog_start"`
		Smoke          string  `json:"smoke"`
		SmokeMix       *string `json:"smoke_mix"`
		SmokeMixAmount float64 `json:"smoke_mix_amount"`
	} `json:"sectors"`
	Bands   []Band   `json:"bands"`
	Sprites []Sprite `json:"sprites"`
	Density struct {
		Near, Far, Max, Emissive, ThreatCap float64
	} `json:"-"`
	DensityRaw map[string]float64 `json:"density"`
	Lane       struct {
		Left, Right, Top float64
		AlphaCap         float64 `json:"alpha_cap"`
	} `json:"lane"`
	MistEmptyMin float64 `json:"mist_empty_min"`
}

type Band struct {
	ID             string     `json:"id"`
	H              int        `json:"h"`
	Seed           int        `json:"seed"`
	AlphaMax       float64    `json:"alpha_max"`
	TopY           float64    `json:"top_y"`
	Pass           string     `json:"pass"`
	SortZ          *float64   `json:"sort_z"`
	Parallax       float64    `json:"parallax"`
	Drift          float64    `json:"drift"`
	Opacity        [2]float64 `json:"opacity"`
	RuntimeOpacity float64    `json:"runtime_opacity"`
	Reduced        bool       `json:"reduced"`
}

type Sprite struct {
	ID             string     `json:"id"`
	W              int        `json:"w"`
	H              int        `json:"h"`
	Frames         int        `json:"frames"`
	Seed           int        `json:"seed"`
	AlphaMax       float64    `json:"alpha_max"`
	Color          string     `json:"color"`
	Pass           string     `json:"pass"`
	SortZ          *float64   `json:"sort_z"`
	Parallax       float64    `json:"parallax"`
	Drift          float64    `json:"drift"`
	Opacity        [2]float64 `json:"opacity"`
	RuntimeOpacity float64    `json:"runtime_opacity"`
	GroundSquash   float64    `json:"ground_squash"`
	Rows           []float64  `json:"rows"`
	Reduced        bool       `json:"reduced"`
	RampSteps      []int      `json:"ramp_steps"`
	LaneOpacityMax float64    `json:"lane_opacity_max"`
}

const specPath = "art/families/ground-atmosphere.json"

func loadSpec() *Spec {
	b, err := os.ReadFile(filepath.Join(root, specPath))
	must(err)
	var s Spec
	must(json.Unmarshal(b, &s))
	d := s.DensityRaw
	s.Density.Near, s.Density.Far, s.Density.Max = d["fog_mix_near_z"], d["fog_mix_far_z"], d["fog_mix_max"]
	s.Density.Emissive, s.Density.ThreatCap = d["emissive_rate"], d["threat_cap"]
	return &s
}

func (s *Spec) band(id string) Band {
	for _, b := range s.Bands {
		if b.ID == id {
			return b
		}
	}
	fail(errNamed("band", id))
	return Band{}
}

func (s *Spec) sprite(id string) Sprite {
	for _, b := range s.Sprites {
		if b.ID == id {
			return b
		}
	}
	fail(errNamed("sprite", id))
	return Sprite{}
}

type namedErr struct{ kind, id string }

func (e namedErr) Error() string  { return "spec has no " + e.kind + " " + e.id }
func errNamed(k, id string) error { return namedErr{k, id} }

// --- colour ---------------------------------------------------------------

type rgb struct{ R, G, B float64 } // 0..255

func fromHex(h string) rgb {
	c := pixelgrid.Hex(h)
	return rgb{float64(c.R), float64(c.G), float64(c.B)}
}

func (c rgb) nrgba(a uint8) color.NRGBA {
	q := func(v float64) uint8 { return uint8(math.Max(0, math.Min(255, math.Round(v)))) }
	return color.NRGBA{q(c.R), q(c.G), q(c.B), a}
}

func (c rgb) round() rgb { n := c.nrgba(255); return rgb{float64(n.R), float64(n.G), float64(n.B)} }

func hex(c rgb) string { return pixelgrid.HexString(c.nrgba(255)) }

func luma(c rgb) float64 { return (.2126*c.R + .7152*c.G + .0722*c.B) / 255 }

func chroma(c rgb) float64 {
	return (math.Max(c.R, math.Max(c.G, c.B)) - math.Min(c.R, math.Min(c.G, c.B))) / 255
}

func lerp(a, b rgb, t float64) rgb {
	return rgb{a.R + (b.R-a.R)*t, a.G + (b.G-a.G)*t, a.B + (b.B-a.B)*t}
}

func scale(c rgb, k float64) rgb { return rgb{c.R * k, c.G * k, c.B * k} }

// withLuma scales c so its luma is l (hue and saturation kept).
func withLuma(c rgb, l float64) rgb {
	if luma(c) <= 0 {
		v := l * 255
		return rgb{v, v, v}
	}
	return scale(c, l/luma(c))
}

// clampTint keeps luma in [lo, hi] and chroma at or under cmax; the result
// is rounded to 8 bits and still inside the caps.
func clampTint(c rgb, lo, hi, cmax float64) rgb {
	for i := 0; i < 64; i++ {
		l := luma(c)
		if l < lo {
			c = withLuma(c, lo+.002)
		} else if l > hi {
			c = withLuma(c, hi-.002)
		}
		if ch := chroma(c); ch > cmax {
			g := luma(c) * 255
			c = lerp(c, rgb{g, g, g}, 1-(cmax-.004)/ch)
		}
		r := c.round()
		if l := luma(r); l >= lo && l <= hi && chroma(r) <= cmax {
			return r
		}
	}
	return c.round()
}

// Tints of one sector.
type Tints struct {
	Sample, Fog, Lit, Dark, Smoke rgb
}

// readPainting decodes a sector painting: WebP since phone-performance
// (assets ship one format), PNG otherwise.
func readPainting(p string) (image.Image, error) {
	if !strings.HasSuffix(p, ".webp") {
		return pixelgrid.ReadPNG(p)
	}
	f, err := os.Open(p)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return webp.Decode(f)
}

// horizonSample averages the painting's horizon band (the rows the flyover
// sky bake lays on the horizon line) and darkens it as that bake does.
func horizonSample(s *Spec, painting string) rgb {
	im, err := readPainting(filepath.Join(root, painting))
	must(err)
	b := im.Bounds()
	y0 := b.Min.Y + int(float64(b.Dy())*s.Tint.SampleRows[0])
	y1 := b.Min.Y + int(float64(b.Dy())*s.Tint.SampleRows[1])
	var sum rgb
	n := 0.0
	for y := y0; y < y1; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			c := color.NRGBAModel.Convert(im.At(x, y)).(color.NRGBA)
			sum.R += float64(c.R)
			sum.G += float64(c.G)
			sum.B += float64(c.B)
			n++
		}
	}
	avg := scale(sum, 1/n)
	return lerp(avg, fromHex(s.Tint.Darken), s.Tint.DarkenMix)
}

func sectorTints(s *Spec) []Tints {
	var out []Tints
	t := s.Tint
	for _, sec := range s.Sectors {
		start := fromHex(sec.FogStart)
		sample := horizonSample(s, sec.Painting)
		// The horizon gives the hue; the starting tint gives the value.
		hue := withLuma(sample, luma(start))
		fog := clampTint(lerp(start, hue, t.SampleWeight), t.Luma[0], t.Luma[1], t.ChromaMax)
		fog = awayFromSignals(fog, t.Luma[0], t.Luma[1])
		g := luma(fog) * 255
		lit := lerp(withLuma(fog, math.Min(t.LitLumaMax, luma(fog)+.07)), rgb{g, g, g}, .25)
		lit = clampTint(lit, t.Luma[0], t.LitLumaMax, t.ChromaMax)
		dark := clampTint(scale(fog, t.DarkScale), 0, t.Luma[1], t.ChromaMax)
		smoke := fromHex(sec.Smoke)
		if sec.SmokeMix != nil {
			smoke = lerp(smoke, fromHex(*sec.SmokeMix), sec.SmokeMixAmount)
		}
		out = append(out, Tints{sample.round(), fog, lit, dark, smoke.round()})
	}
	return out
}

// Signal hues (plan §5.4): ally cyan #70F5D5 and demon warm #FF8A2A. A
// tint near one of them may keep only grey-level chroma.
var signalHues = []float64{hue(fromHex("#70F5D5")), hue(fromHex("#FF8A2A"))}

const signalHueGap, greyChroma = 30.0, .06

func hue(c rgb) float64 {
	mx := math.Max(c.R, math.Max(c.G, c.B))
	mn := math.Min(c.R, math.Min(c.G, c.B))
	d := mx - mn
	if d == 0 {
		return 0
	}
	var h float64
	switch mx {
	case c.R:
		h = math.Mod((c.G-c.B)/d, 6)
	case c.G:
		h = (c.B-c.R)/d + 2
	default:
		h = (c.R-c.G)/d + 4
	}
	h *= 60
	if h < 0 {
		h += 360
	}
	return h
}

func hueDist(a, b float64) float64 {
	d := math.Mod(math.Abs(a-b), 360)
	return math.Min(d, 360-d)
}

// nearSignal: a tint with more than grey-level chroma within the gap of a
// signal hue.
func nearSignal(c rgb) bool {
	if chroma(c) <= greyChroma {
		return false
	}
	for _, s := range signalHues {
		if hueDist(hue(c), s) < signalHueGap {
			return true
		}
	}
	return false
}

func awayFromSignals(c rgb, lo, hi float64) rgb {
	if !nearSignal(c) {
		return c
	}
	return clampTint(c, lo, hi, greyChroma-.004)
}
