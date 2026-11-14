package main

// Family specs (schema demon-attack.ground-blocks/v1): ground-fleet.json,
// ground-host.json and ground-infantry.json under art/families/. They hold
// the atlas grid, camera, palettes and materials, per-sector rosters and
// kits, prompts, seeds and the GPU plan per unit. validate checks them
// against the rigs and the palette rules of both style guides.

import (
	"encoding/json"
	"fmt"
	"image/color"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"demonattack/tools/pixelgrid"
)

var sectorOrder = []string{"krybor", "ringfall", "ember", "hollow", "carrier"}

type Hero struct {
	Heading    float64 `json:"heading"`
	Candidates int     `json:"candidates"`
	Selected   *int    `json:"selected"`
}

type UnitSpec struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Faction string `json:"faction"`
	Block   string `json:"block"`
	Role    string `json:"role"`
	Slot    *struct {
		Sector  string `json:"sector"`
		Variant int    `json:"variant"`
	} `json:"slot"`
	Rig      string    `json:"rig"`
	Headings []float64 `json:"headings"`
	Art      *struct {
		Kind   string    `json:"kind"`
		Angles []float64 `json:"angles"`
	} `json:"art"`
	Subject           string            `json:"subject"`
	Sectors           map[string]string `json:"sectors"` // sector -> prompt modifier
	Seed              int               `json:"seed"`
	Hero              Hero              `json:"hero"`
	HeadingCandidates int               `json:"headings_candidates"`
	Inbetweens        []string          `json:"inbetweens"`
	Threat            bool              `json:"threat"`
	Phase             int               `json:"phase"`
	Notes             string            `json:"notes"`
}

type SectorSpec struct {
	Units []string `json:"units"`
	Kit   string   `json:"kit"`
	Stone []string `json:"stone"` // Host: the sector stone ramp
	Note  string   `json:"note"`
}

type Family struct {
	Schema  string `json:"schema"`
	Name    string `json:"name"`
	Faction string `json:"faction"` // fleet | host | mixed
	Notes   string `json:"notes"`
	Atlas   struct {
		File    string `json:"file"` // with {sector}
		Cell    [2]int `json:"cell"`
		Columns int    `json:"columns"`
	} `json:"atlas"`
	Camera struct {
		Elevation float64 `json:"elevation_deg"`
		Light     V3      `json:"light"`
		LMin      float64 `json:"lmin"`
		LMax      float64 `json:"lmax"`
	} `json:"camera"`
	Headings  []float64           `json:"headings"`
	ArtAngles []float64           `json:"art_angles"`
	Ramps     map[string][]string `json:"ramps"`
	Materials map[string]Material `json:"materials"`
	Ink       string              `json:"ink"`
	// Infantry family: the vehicle families whose palettes it uses.
	Palettes       map[string]string     `json:"palettes"`
	Forbidden      []string              `json:"forbidden_ramps"`
	Sectors        map[string]SectorSpec `json:"sectors"`
	StylePrompt    string                `json:"style_prompt"`
	NegativePrompt string                `json:"negative_prompt"`
	HeadingPhrases map[string]string     `json:"heading_phrases"`
	Sprite         struct {
		Workflows map[string]string `json:"workflows"`
		Reference struct {
			Scale int    `json:"scale"`
			Key   string `json:"key"`
		} `json:"reference"`
		Candidates int `json:"candidates"`
	} `json:"sprite"`
	SeedRange [2]int     `json:"seed_range"`
	Units     []UnitSpec `json:"units"`
	Runs      string     `json:"runs"`

	Path string                `json:"-"`
	mats map[string]*Materials // by faction
}

func loadFamily(path string) (*Family, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var f Family
	dec := json.NewDecoder(strings.NewReader(string(b)))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&f); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	f.Path = path
	return &f, nil
}

// Palette of one faction: ramps (Host stone per sector) and materials.
type Palette struct {
	Faction string
	Ramps   map[string][]color.NRGBA
	Stone   map[string][]color.NRGBA // Host: sector -> stone ramp
	Kit     map[string]string
	Ink     color.NRGBA
	Mats    *Materials
}

func hexes(hs []string) []color.NRGBA {
	out := make([]color.NRGBA, len(hs))
	for i, h := range hs {
		out[i] = pixelgrid.Hex(h)
	}
	return out
}

func (f *Family) palette() *Palette {
	p := &Palette{Faction: f.Faction, Ramps: map[string][]color.NRGBA{}, Stone: map[string][]color.NRGBA{}, Kit: map[string]string{}, Ink: pixelgrid.Hex(f.Ink)}
	for k, v := range f.Ramps {
		p.Ramps[k] = hexes(v)
	}
	for s, sp := range f.Sectors {
		if len(sp.Stone) > 0 {
			p.Stone[s] = hexes(sp.Stone)
		}
		p.Kit[s] = sp.Kit
	}
	names := make([]string, 0, len(f.Materials))
	for k := range f.Materials {
		names = append(names, k)
	}
	sort.Strings(names)
	m := &Materials{List: []Material{{Name: ""}}, Index: map[string]int8{}}
	for _, n := range names {
		mm := f.Materials[n]
		mm.Name = n
		m.Index[n] = int8(len(m.List))
		m.List = append(m.List, mm)
	}
	p.Mats = m
	return p
}

// ramp returns the colours of a ramp for a sector (Host "stone" and
// "membrane" follow the sector).
func (p *Palette) ramp(name, sector string) []color.NRGBA {
	if p.Faction == "host" {
		st := p.Stone[sector]
		if st == nil {
			st = p.Stone["hollow"]
		}
		switch name {
		case "stone":
			return st
		case "membrane":
			return membrane(st)
		}
	}
	return p.Ramps[name]
}

// membrane: the stone ramp shifted 15° warm (gargoyle guide, Section 6).
func membrane(st []color.NRGBA) []color.NRGBA {
	out := make([]color.NRGBA, len(st))
	for i, c := range st {
		h, s, l := rgbToHsl(c)
		h -= 15
		if h < 0 {
			h += 360
		}
		out[i] = hslToRgb(h, s*1.1, l*.95)
	}
	return out
}

var hexRe = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

// validate checks a family against its rigs: the family-spec conventions
// of art/families (schema, name, atlas, prompts, workflows, seeds), every
// unit's rig, block and headings, materials and ramps, sector rosters,
// and the faction palette rules.
func (f *Family) validate(rigs map[string]*Rig, others map[string]*Family) []string {
	var errs []string
	bad := func(format string, a ...any) {
		errs = append(errs, fmt.Sprintf("%s: ", filepath.Base(f.Path))+fmt.Sprintf(format, a...))
	}
	if f.Schema != "demon-attack.ground-blocks/v1" {
		bad("schema %q", f.Schema)
	}
	if f.Name == "" || f.Name+".json" != filepath.Base(f.Path) {
		bad("name %q does not match the file", f.Name)
	}
	if !strings.Contains(f.Atlas.File, "{sector}") || !strings.HasSuffix(f.Atlas.File, ".png") {
		bad("atlas.file %q needs {sector} and .png", f.Atlas.File)
	}
	if f.Atlas.Columns != 20 {
		bad("atlas.columns %d, the block layout has 20", f.Atlas.Columns)
	}
	if f.StylePrompt == "" || f.NegativePrompt == "" {
		bad("style_prompt and negative_prompt are required")
	}
	for _, w := range []string{"franchise", "studio", "starcraft", "warhammer", "battletech", "gundam", "lego"} {
		low := strings.ToLower(f.StylePrompt + " " + f.NegativePrompt)
		for _, u := range f.Units {
			low += " " + strings.ToLower(u.Subject)
			for _, m := range u.Sectors {
				low += " " + strings.ToLower(m)
			}
		}
		if strings.Contains(low, w) {
			bad("a prompt names %q", w)
		}
	}
	for k, wf := range f.Sprite.Workflows {
		if wf == "" || !strings.HasPrefix(wf, "art/workflows/") {
			bad("workflow %s %q", k, wf)
		}
	}
	if f.Runs == "" || !strings.HasSuffix(f.Runs, "-runs.json") {
		bad("runs %q", f.Runs)
	}
	pal := map[string]*Family{}
	if f.Faction == "mixed" {
		for fac, file := range f.Palettes {
			o := others[file]
			if o == nil {
				bad("palette family %s missing", file)
				continue
			}
			pal[fac] = o
		}
	} else {
		pal[f.Faction] = f
		if f.Camera.Elevation <= 0 || f.Camera.Elevation >= 90 {
			bad("camera elevation %v", f.Camera.Elevation)
		}
		if len(f.Headings) != 5 {
			bad("%d headings, the decision is five", len(f.Headings))
		}
		for i := 1; i < len(f.Headings); i++ {
			if f.Headings[i]-f.Headings[i-1] != 22.5 {
				bad("headings not in 22.5° steps")
			}
		}
		if !hexRe.MatchString(f.Ink) {
			bad("ink %q", f.Ink)
		}
		for k, r := range f.Ramps {
			for _, h := range r {
				if !hexRe.MatchString(h) {
					bad("ramp %s colour %q", k, h)
				}
			}
		}
		for n, m := range f.Materials {
			r := f.Ramps[m.Ramp]
			if (m.Ramp == "stone" || m.Ramp == "membrane") && f.Faction == "host" {
				r = make([]string, 5)
			}
			if r == nil {
				bad("material %s: ramp %q missing", n, m.Ramp)
				continue
			}
			if m.Lo < 0 || m.Hi >= len(r) || m.Lo > m.Hi || (m.Emissive && (m.LitStep < 0 || m.LitStep >= len(r))) {
				bad("material %s: steps %d..%d (lit %d) outside %s[0..%d]", n, m.Lo, m.Hi, m.LitStep, m.Ramp, len(r)-1)
			}
		}
		// Palette rules: no forbidden reserved colours in this faction.
		forbidden := map[string]bool{}
		for _, fr := range f.Forbidden {
			for _, h := range reservedRamps[fr] {
				forbidden[strings.ToUpper(h)] = true
			}
		}
		for k, r := range f.Ramps {
			for _, h := range r {
				if forbidden[strings.ToUpper(h)] {
					bad("ramp %s uses forbidden colour %s", k, h)
				}
			}
		}
		for s, sp := range f.Sectors {
			for _, h := range sp.Stone {
				if !hexRe.MatchString(h) {
					bad("sector %s stone %q", s, h)
				}
				if forbidden[strings.ToUpper(h)] {
					bad("sector %s stone uses forbidden %s", s, h)
				}
			}
			if f.Faction == "host" && len(sp.Stone) != 5 {
				bad("sector %s needs a 5-step stone ramp", s)
			}
		}
	}
	ids := map[string]bool{}
	for _, u := range f.Units {
		if ids[u.ID] {
			bad("unit %s twice", u.ID)
		}
		ids[u.ID] = true
		r := rigs[u.ID]
		if r == nil {
			bad("unit %s: no rig art/families/rigs/%s.json", u.ID, u.ID)
			continue
		}
		if u.Rig != "rigs/"+u.ID+".json" {
			bad("unit %s: rig path %q", u.ID, u.Rig)
		}
		if r.Block != u.Block {
			bad("unit %s: block %s but rig says %s", u.ID, u.Block, r.Block)
		}
		fac := u.Faction
		if fac == "" {
			fac = f.Faction
		}
		if r.Faction != fac {
			bad("unit %s: faction %s but rig says %s", u.ID, fac, r.Faction)
		}
		if f.Faction != "mixed" && u.Block == "I" {
			bad("unit %s: infantry belongs in ground-infantry.json", u.ID)
		}
		if f.Faction == "mixed" && u.Block != "I" {
			bad("unit %s: only infantry in the infantry family", u.ID)
		}
		if u.Seed < f.SeedRange[0] || u.Seed > f.SeedRange[1] {
			bad("unit %s: seed %d outside %v", u.ID, u.Seed, f.SeedRange)
		}
		if u.Subject == "" {
			bad("unit %s: no subject line", u.ID)
		}
		if u.Hero.Candidates < 1 {
			bad("unit %s: hero.candidates", u.ID)
		}
		want := headingsFor(r, pal[fac])
		if len(u.Headings) != len(want) {
			bad("unit %s: %d headings, block %s wants %d", u.ID, len(u.Headings), u.Block, len(want))
		} else {
			for i := range want {
				if u.Headings[i] != want[i] {
					bad("unit %s: heading %d is %v, want %v", u.ID, i, u.Headings[i], want[i])
				}
			}
		}
		okHero := false
		for _, h := range u.Headings {
			okHero = okHero || h == u.Hero.Heading
		}
		if !okHero {
			bad("unit %s: hero heading %v is not authored", u.ID, u.Hero.Heading)
		}
		if (u.Art != nil) != (r.Art != nil) {
			bad("unit %s: art layer in spec %v, in rig %v", u.ID, u.Art != nil, r.Art != nil)
		}
		if pf := pal[fac]; pf != nil {
			for _, p := range r.allPrims() {
				if _, ok := pf.Materials[p.Mat]; !ok {
					bad("unit %s: material %q not in %s", u.ID, p.Mat, pf.Name)
				}
			}
		}
		for s := range u.Sectors {
			if !contains(sectorOrder, s) {
				bad("unit %s: sector %q", u.ID, s)
			}
		}
	}
	for s, sp := range f.Sectors {
		if !contains(sectorOrder, s) {
			bad("sector %q", s)
		}
		for _, id := range sp.Units {
			if !ids[id] {
				bad("sector %s lists unknown unit %s", s, id)
			}
		}
	}
	for _, s := range sectorOrder {
		if _, ok := f.Sectors[s]; !ok {
			bad("sector %s missing", s)
		}
	}
	return errs
}

// reservedRamps: the reserved sets of art/families/ground-forces.json plus
// demon_gilt (gargoyle guide), for the forbidden-colour checks.
var reservedRamps = map[string][]string{
	"demon_warm": {"#3A0A0C", "#7A1410", "#B8260F", "#E8501A", "#FF8A2A", "#FFC85A", "#FFF0B8"},
	"demon_gilt": {"#1B1406", "#36280D", "#644B18", "#9A7324"},
	"ally_cyan":  {"#0C3A40", "#16626A", "#2AA59A", "#70F5D5", "#D2FFF4"},
}

func contains(xs []string, s string) bool {
	for _, x := range xs {
		if x == s {
			return true
		}
	}
	return false
}

// headingsFor: the authored headings of a rig's block for its faction.
func headingsFor(r *Rig, f *Family) []float64 {
	switch r.Block {
	case "I":
		if r.Faction == "fleet" {
			return []float64{0, 45, 90}
		}
		return []float64{45, 90, 135}
	case "K":
		return []float64{90, 135, 180}
	}
	if f == nil {
		return nil
	}
	return f.Headings
}
