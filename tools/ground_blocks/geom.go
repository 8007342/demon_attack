package main

// 3-D rig geometry: convex primitives as half-space sets (and ellipsoids),
// rigid transforms, and an orthographic ray caster onto the texel grid.
// Unit-local frame: x to the unit's right, y forward (the nose), z up, in
// texels, origin on the ground at the footprint centre.

import "math"

type V3 [3]float64

func (a V3) add(b V3) V3      { return V3{a[0] + b[0], a[1] + b[1], a[2] + b[2]} }
func (a V3) sub(b V3) V3      { return V3{a[0] - b[0], a[1] - b[1], a[2] - b[2]} }
func (a V3) mul(k float64) V3 { return V3{a[0] * k, a[1] * k, a[2] * k} }
func (a V3) dot(b V3) float64 { return a[0]*b[0] + a[1]*b[1] + a[2]*b[2] }
func (a V3) cross(b V3) V3 {
	return V3{a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]}
}
func (a V3) len() float64 { return math.Sqrt(a.dot(a)) }
func (a V3) norm() V3 {
	l := a.len()
	if l == 0 {
		return a
	}
	return a.mul(1 / l)
}

// M3 is a row-major rotation matrix.
type M3 [3][3]float64

func ident() M3 { return M3{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}} }

func (m M3) apply(v V3) V3 {
	return V3{m[0][0]*v[0] + m[0][1]*v[1] + m[0][2]*v[2],
		m[1][0]*v[0] + m[1][1]*v[1] + m[1][2]*v[2],
		m[2][0]*v[0] + m[2][1]*v[1] + m[2][2]*v[2]}
}

func (m M3) mul(n M3) M3 {
	var o M3
	for i := 0; i < 3; i++ {
		for j := 0; j < 3; j++ {
			o[i][j] = m[i][0]*n[0][j] + m[i][1]*n[1][j] + m[i][2]*n[2][j]
		}
	}
	return o
}

func (m M3) t() M3 {
	var o M3
	for i := 0; i < 3; i++ {
		for j := 0; j < 3; j++ {
			o[i][j] = m[j][i]
		}
	}
	return o
}

func rad(d float64) float64 { return d * math.Pi / 180 }

// yawCW turns by deg clockwise seen from above: the nose (+y) goes to +x at
// 90°. This is the screen-angle convention of the heading tables.
func yawCW(deg float64) M3 {
	c, s := math.Cos(rad(deg)), math.Sin(rad(deg))
	return M3{{c, s, 0}, {-s, c, 0}, {0, 0, 1}}
}

// pitchUp raises the nose (+y toward +z) by deg.
func pitchUp(deg float64) M3 {
	c, s := math.Cos(rad(deg)), math.Sin(rad(deg))
	return M3{{1, 0, 0}, {0, c, -s}, {0, s, c}}
}

// rollRight lowers the right side (+x toward -z) by deg.
func rollRight(deg float64) M3 {
	c, s := math.Cos(rad(deg)), math.Sin(rad(deg))
	return M3{{c, 0, s}, {0, 1, 0}, {-s, 0, c}}
}

// Xf is a rigid transform p -> R p + T.
type Xf struct {
	R M3
	T V3
}

func idXf() Xf                   { return Xf{R: ident()} }
func (x Xf) apply(p V3) V3       { return x.R.apply(p).add(x.T) }
func (x Xf) applyDir(d V3) V3    { return x.R.apply(d) }
func (x Xf) then(y Xf) Xf        { return Xf{R: y.R.mul(x.R), T: y.R.apply(x.T).add(y.T)} } // y after x
func (x Xf) inv() Xf             { rt := x.R.t(); return Xf{R: rt, T: rt.apply(x.T).mul(-1)} }
func rotAbout(r M3, pivot V3) Xf { return Xf{R: r, T: pivot.sub(r.apply(pivot))} }
func move(d V3) Xf               { return Xf{R: ident(), T: d} }

// Plane: inside where n·p <= d.
type Plane struct {
	N V3
	D float64
}

func (p Plane) xf(x Xf) Plane {
	n := x.R.apply(p.N)
	return Plane{N: n, D: p.D + n.dot(x.T)}
}

// Shape is one convex solid in some frame: planes, or an ellipsoid.
type Shape struct {
	Planes []Plane
	Ell    bool
	EC     V3 // ellipsoid centre and radii in its own frame (EX maps it out)
	ER     V3
	EX     Xf
}

func (s Shape) xf(x Xf) Shape {
	o := s
	if s.Ell {
		o.EX = s.EX.then(x)
		return o
	}
	o.Planes = make([]Plane, len(s.Planes))
	for i, p := range s.Planes {
		o.Planes[i] = p.xf(x)
	}
	return o
}

// hit returns the entry distance and outward normal of the ray o + t·d.
func (s Shape) hit(o, d V3) (float64, V3, bool) {
	if s.Ell {
		inv := s.EX.inv()
		lo := inv.apply(o).sub(s.EC)
		ld := inv.applyDir(d)
		q := V3{lo[0] / s.ER[0], lo[1] / s.ER[1], lo[2] / s.ER[2]}
		qd := V3{ld[0] / s.ER[0], ld[1] / s.ER[1], ld[2] / s.ER[2]}
		a, b, c := qd.dot(qd), 2*q.dot(qd), q.dot(q)-1
		disc := b*b - 4*a*c
		if disc < 0 {
			return 0, V3{}, false
		}
		t := (-b - math.Sqrt(disc)) / (2 * a)
		p := lo.add(ld.mul(t))
		n := V3{p[0] / (s.ER[0] * s.ER[0]), p[1] / (s.ER[1] * s.ER[1]), p[2] / (s.ER[2] * s.ER[2])}
		return t, s.EX.applyDir(n).norm(), true
	}
	tIn, tOut := math.Inf(-1), math.Inf(1)
	var nIn V3
	for _, p := range s.Planes {
		den := p.N.dot(d)
		num := p.D - p.N.dot(o)
		if math.Abs(den) < 1e-12 {
			if num < 0 {
				return 0, V3{}, false
			}
			continue
		}
		t := num / den
		if den < 0 {
			if t > tIn {
				tIn, nIn = t, p.N
			}
		} else if t < tOut {
			tOut = t
		}
		if tIn > tOut {
			return 0, V3{}, false
		}
	}
	return tIn, nIn.norm(), true
}

// contains reports whether p is inside (used by tests and seating checks).
func (s Shape) contains(p V3) bool {
	if s.Ell {
		q := s.EX.inv().apply(p).sub(s.EC)
		return (q[0]*q[0])/(s.ER[0]*s.ER[0])+(q[1]*q[1])/(s.ER[1]*s.ER[1])+(q[2]*q[2])/(s.ER[2]*s.ER[2]) <= 1
	}
	for _, pl := range s.Planes {
		if pl.N.dot(p) > pl.D+1e-9 {
			return false
		}
	}
	return true
}

// boxPlanes: an axis box with its bottom face centred on the origin.
func boxPlanes(w, l, h float64) []Plane {
	return []Plane{
		{V3{1, 0, 0}, w / 2}, {V3{-1, 0, 0}, w / 2},
		{V3{0, 1, 0}, l / 2}, {V3{0, -1, 0}, l / 2},
		{V3{0, 0, 1}, h}, {V3{0, 0, -1}, 0},
	}
}

// chamferPlane cuts the edge between two faces (outward normals a and b at
// offsets da and db) by c texels along each face.
func chamferPlane(a V3, da float64, b V3, db float64, c float64) Plane {
	n := a.add(b).norm()
	e := a.mul(da).add(b.mul(db)) // a point on the edge (a ⟂ b)
	return Plane{N: n, D: n.dot(e) - c/math.Sqrt2}
}

// planeThrough: outward normal n, passing through p.
func planeThrough(n V3, p V3) Plane {
	n = n.norm()
	return Plane{N: n, D: n.dot(p)}
}

// prismPlanes: an n-sided frustum along +z from 0 to h, circumradius r at
// the bottom and r2 at the top, first face normal at rot degrees from +y
// (clockwise).
func prismPlanes(n int, r, r2, h, rot float64) []Plane {
	ps := []Plane{{V3{0, 0, 1}, h}, {V3{0, 0, -1}, 0}}
	k := math.Cos(math.Pi / float64(n))
	a0, a1 := r*k, r2*k
	for i := 0; i < n; i++ {
		phi := rad(rot + 360*float64(i)/float64(n))
		dx, dy := math.Sin(phi), math.Cos(phi)
		nn := V3{h * dx, h * dy, a0 - a1}.norm()
		ps = append(ps, Plane{N: nn, D: nn.dot(V3{a0 * dx, a0 * dy, 0})})
	}
	return ps
}

// barPlanes: a square-section beam from a to b, t wide and tz tall.
func barPlanes(a, b V3, t, tz float64) []Plane {
	u := b.sub(a).norm()
	v := u.cross(V3{0, 0, 1})
	if v.len() < 1e-6 {
		v = V3{1, 0, 0}
	}
	v = v.norm()
	w := v.cross(u).norm()
	return []Plane{
		{u, u.dot(b)}, {u.mul(-1), -u.dot(a)},
		{v, v.dot(a) + t/2}, {v.mul(-1), -v.dot(a) + t/2},
		{w, w.dot(a) + tz/2}, {w.mul(-1), -w.dot(a) + tz/2},
	}
}

// Camera: orthographic, looking up the plane (+y) and down by Elev degrees.
type Camera struct {
	Elev           float64
	Right, Up, Fwd V3
	Light          V3
	LMin, LMax     float64
}

func newCamera(elev float64, light V3, lmin, lmax float64) Camera {
	e := rad(elev)
	c := Camera{Elev: elev, Right: V3{1, 0, 0}, Up: V3{0, math.Sin(e), math.Cos(e)}, Fwd: V3{0, math.Cos(e), -math.Sin(e)}, LMin: lmin, LMax: lmax}
	// light is given in screen terms: x right, y up the screen, z toward
	// the viewer.
	c.Light = c.Right.mul(light[0]).add(c.Up.mul(light[1])).add(c.Fwd.mul(-light[2])).norm()
	return c
}

// project returns screen x (right) and u (up) of a world point.
func (c Camera) project(p V3) (float64, float64) { return p.dot(c.Right), p.dot(c.Up) }
