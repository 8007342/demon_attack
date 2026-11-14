package main

// Rig format (schema demon-attack.ground-rig/v1), one JSON file per unit
// under art/families/rigs/. A rig is a hull and at most one articulated
// layer, each a list of convex primitives in texels, plus the marks the
// generators read: material, tags (pose groups, emissive lights, channel
// stages, debris pieces, soft edges) and the gait of legged units.

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Prim struct {
	Kind string `json:"kind"` // box | prism | bar | ball | leg
	At   V3     `json:"at"`   // box/prism: centre of the base; ball: centre
	Size V3     `json:"size"` // box: w (x), l (y), h (z); ball: radii
	// prism
	N      int     `json:"n"`
	R      float64 `json:"r"`
	R2     float64 `json:"r2"` // top radius (0 = same as r; use -1 for a point)
	H      float64 `json:"h"`
	Rot    float64 `json:"rot"`
	Axis   string  `json:"axis"` // z (default) | x | y
	Center bool    `json:"center"`
	// bar / leg
	A        V3         `json:"a"`
	B        V3         `json:"b"`
	T        float64    `json:"t"`
	TZ       float64    `json:"tz"`
	Hip      V3         `json:"hip"`
	Knee     V3         `json:"knee"`
	Foot     V3         `json:"foot"`
	FootSize [2]float64 `json:"foot_size"`
	Phase    float64    `json:"phase"` // gait phase 0..1
	// box chamfers (texels cut along each face)
	Chamfer map[string]float64 `json:"chamfer"` // top, front, back, sides, vert, bottom, bfront, bback
	Cuts    []struct {
		N V3 `json:"n"`
		P V3 `json:"p"`
	} `json:"cuts"`
	Yaw   float64 `json:"yaw"`
	Pitch float64 `json:"pitch"`
	Roll  float64 `json:"roll"`

	Mat  string   `json:"mat"`
	Tags []string `json:"tags"`
	// Channel stage 1..3 (Host): lit by fill1..fill3 overlays.
	Stage int    `json:"stage"`
	Soft  bool   `json:"soft"`
	Piece string `json:"piece"`
	Note  string `json:"note"`
}

type Pose struct {
	Tag   string  `json:"tag"`  // "" = the whole layer
	Axis  string  `json:"axis"` // x (pitch) | y (roll) | z (yaw)
	Deg   float64 `json:"deg"`
	Pivot V3      `json:"pivot"`
	Move  V3      `json:"move"`
	Lit   bool    `json:"lit"` // light the tag's emissive prims
	Hide  bool    `json:"hide"`
	Show  bool    `json:"show"` // show prims tagged "hidden" in this group
}

type Layer struct {
	Kind   string `json:"kind"`   // turret | pod | cab | cradle | jib | gunner | casemate | launcher
	Pivot  V3     `json:"pivot"`  // on the hull, unit-local
	Muzzle V3     `json:"muzzle"` // art-local (pivot at origin, aim 0 = +y)
	Angles string `json:"angles"` // "" = the faction's five; "tilt" = cradle tilts a0-a2
	Prims  []Prim `json:"prims"`
	// Elevations (Sextant): extra barrel pitch per elevation step.
	Elevations []float64 `json:"elevations"`
	// Seat: lowest art-local z of the layer; the hull's turret ring top.
	Seat float64 `json:"seat"`
}

type Gait struct {
	Frames int     `json:"frames"` // 4 infantry, 6 walkers
	Stride float64 `json:"stride"` // foot travel along y, texels (half amplitude)
	Lift   float64 `json:"lift"`
	Bob    float64 `json:"bob"` // body rise on the push frames
}

type Rig struct {
	Schema  string `json:"schema"`
	ID      string `json:"id"`
	Name    string `json:"name"`
	Faction string `json:"faction"` // fleet | host
	Class   string `json:"class"`   // infantry | light | heavy | walker | command
	Block   string `json:"block"`   // V | W | K | I
	Move    string `json:"move"`    // tracks | wheels | hover | stride
	Notes   string `json:"notes"`
	Hull    []Prim `json:"hull"`
	Art     *Layer `json:"art"`
	Gait    *Gait  `json:"gait"`
	// Poses by state name, one list of part transforms per frame.
	Poses map[string][][]Pose `json:"poses"`
	Seed  int                 `json:"seed"`
	// Debris: named pieces (by prim piece id) cut first; chips fill to 12.
	Pieces []string `json:"pieces"`
	Threat bool     `json:"threat"`
	Path   string   `json:"-"`
}

func loadRig(path string) (*Rig, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var r Rig
	dec := json.NewDecoder(strings.NewReader(string(b)))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&r); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	r.Path = path
	return &r, r.check()
}

var knownKinds = map[string]bool{"box": true, "prism": true, "bar": true, "ball": true, "leg": true}

func (r *Rig) check() error {
	if r.Schema != "demon-attack.ground-rig/v1" {
		return fmt.Errorf("%s: schema %q", r.ID, r.Schema)
	}
	if r.Faction != "fleet" && r.Faction != "host" {
		return fmt.Errorf("%s: faction %q", r.ID, r.Faction)
	}
	if !strings.Contains("VWKI", r.Block) || len(r.Block) != 1 {
		return fmt.Errorf("%s: block %q", r.ID, r.Block)
	}
	if _, ok := classTable[r.Class]; !ok {
		return fmt.Errorf("%s: class %q", r.ID, r.Class)
	}
	all := append([]Prim{}, r.Hull...)
	if r.Art != nil {
		all = append(all, r.Art.Prims...)
	}
	if len(r.Hull) == 0 {
		return fmt.Errorf("%s: empty hull", r.ID)
	}
	for i, p := range all {
		if !knownKinds[p.Kind] {
			return fmt.Errorf("%s: prim %d kind %q", r.ID, i, p.Kind)
		}
		if p.Mat == "" {
			return fmt.Errorf("%s: prim %d has no material", r.ID, i)
		}
	}
	if (r.Block == "W" || r.Block == "I" || r.Block == "K") && r.Gait == nil {
		return fmt.Errorf("%s: block %s needs a gait", r.ID, r.Block)
	}
	return nil
}

func (r *Rig) hasTag(t string) bool {
	for _, p := range r.allPrims() {
		if p.has(t) {
			return true
		}
	}
	return false
}

func (r *Rig) allPrims() []Prim {
	all := append([]Prim{}, r.Hull...)
	if r.Art != nil {
		all = append(all, r.Art.Prims...)
	}
	return all
}

func (p Prim) has(t string) bool {
	for _, x := range p.Tags {
		if x == t {
			return true
		}
	}
	return false
}

func loadRigs(dir string) (map[string]*Rig, error) {
	files, _ := filepath.Glob(filepath.Join(dir, "*.json"))
	sort.Strings(files)
	out := map[string]*Rig{}
	for _, f := range files {
		r, err := loadRig(f)
		if err != nil {
			return nil, err
		}
		if filepath.Base(f) != r.ID+".json" {
			return nil, fmt.Errorf("%s: id %q does not match the file name", f, r.ID)
		}
		out[r.ID] = r
	}
	return out, nil
}

// Solid is one primitive placed in a layer frame, with its attributes.
type Solid struct {
	Shape Shape
	Prim  *Prim
	Local Xf // prim frame -> layer frame (for pattern coordinates)
	Lit   bool
}

// expand turns a primitive into solids in its layer frame. A leg becomes a
// thigh, a shin and a foot; gait offsets the knee and foot.
func expand(p *Prim, footOff V3) []Solid {
	place := func(s Shape, x Xf) Solid { return Solid{Shape: s.xf(x), Prim: p, Local: x} }
	rot := ident()
	if p.Yaw != 0 {
		rot = yawCW(p.Yaw).mul(rot)
	}
	if p.Pitch != 0 {
		rot = pitchUp(p.Pitch).mul(rot)
	}
	if p.Roll != 0 {
		rot = rollRight(p.Roll).mul(rot)
	}
	switch p.Kind {
	case "box":
		pl := boxPlanes(p.Size[0], p.Size[1], p.Size[2])
		w, l, h := p.Size[0]/2, p.Size[1]/2, p.Size[2]
		X, Y, Z := V3{1, 0, 0}, V3{0, 1, 0}, V3{0, 0, 1}
		add := func(a V3, da float64, b V3, db float64, c float64) {
			if c > 0 {
				pl = append(pl, chamferPlane(a, da, b, db, c))
			}
		}
		c := p.Chamfer
		top, sides, bottom := c["top"], c["sides"], c["bottom"]
		front, back := math.Max(c["front"], top), math.Max(c["back"], top)
		sides = math.Max(sides, top)
		add(Z, h, Y, l, front)
		add(Z, h, Y.mul(-1), l, back)
		add(Z, h, X, w, sides)
		add(Z, h, X.mul(-1), w, sides)
		bf, bb := math.Max(c["bfront"], bottom), math.Max(c["bback"], bottom)
		add(Z.mul(-1), 0, Y, l, bf)
		add(Z.mul(-1), 0, Y.mul(-1), l, bb)
		add(Z.mul(-1), 0, X, w, bottom)
		add(Z.mul(-1), 0, X.mul(-1), w, bottom)
		v := c["vert"]
		vf := math.Max(v, c["vfront"])
		add(X, w, Y, l, vf)
		add(X.mul(-1), w, Y, l, vf)
		add(X, w, Y.mul(-1), l, v)
		add(X.mul(-1), w, Y.mul(-1), l, v)
		for _, ct := range p.Cuts {
			pl = append(pl, planeThrough(ct.N, ct.P.sub(p.At))) // cut points are unit-local
		}
		x := rotAbout(rot, V3{}).then(move(p.At))
		return []Solid{place(Shape{Planes: pl}, x)}
	case "prism":
		n := p.N
		if n == 0 {
			n = 12
		}
		r2 := p.R2
		if r2 == 0 {
			r2 = p.R
		} else if r2 < 0 {
			r2 = 0.01
		}
		pl := prismPlanes(n, p.R, r2, p.H, p.Rot)
		ax := ident()
		switch p.Axis {
		case "x":
			ax = M3{{0, 0, 1}, {0, 1, 0}, {-1, 0, 0}} // z -> x
		case "y":
			ax = M3{{1, 0, 0}, {0, 0, 1}, {0, -1, 0}} // z -> y
		}
		var x Xf
		if p.Center {
			x = move(V3{0, 0, -p.H / 2})
		} else {
			x = idXf()
		}
		x = x.then(Xf{R: ax}).then(rotAbout(rot, V3{})).then(move(p.At))
		return []Solid{place(Shape{Planes: pl}, x)}
	case "bar":
		t, tz := p.T, p.TZ
		if tz == 0 {
			tz = t
		}
		a, b := p.A, p.B.add(footOff)
		x := rotAbout(rot, a)
		return []Solid{place(Shape{Planes: barPlanes(a, b, t, tz)}, x)}
	case "ball":
		x := rotAbout(rot, V3{}).then(move(p.At))
		return []Solid{place(Shape{Ell: true, ER: p.Size, EX: idXf()}, x)}
	case "leg":
		t := p.T
		if t == 0 {
			t = 2
		}
		foot := p.Foot.add(footOff)
		knee := p.Knee.add(V3{footOff[0] / 2, footOff[1] / 2, footOff[2] * .6})
		out := []Solid{
			place(Shape{Planes: barPlanes(p.Hip, knee, t+.5, t+.5)}, idXf()),
			place(Shape{Planes: barPlanes(knee, foot, t, t)}, idXf()),
		}
		if p.FootSize[0] > 0 {
			fw, fl := p.FootSize[0], p.FootSize[1]
			out = append(out, place(Shape{Planes: boxPlanes(fw, fl, 1.2)}, move(V3{foot[0], foot[1] + fl/4, math.Max(0, foot[2]-.6)})))
		}
		return out
	}
	return nil
}
