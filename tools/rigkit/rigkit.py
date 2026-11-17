# rigkit: the shared, data-driven bpy module kit for art families that go
# through the rig -> clay/depth/normal -> hero -> projection -> finish -> bake
# flow (R10, plan/operator-feedback-2026-11-15b.md). Python only because bpy
# forces it (forge order: Lua > Rust > Go). Nothing in here knows about bosses:
# a family JSON (schema demon-attack.rig-family/v1, documented in
# openspec/changes/boss-hero-assets/design.md §8.5) declares the prims, slots,
# sets, hulls, views, stages, anchor gate, materials and palettes.
#
# Library layers (each usable on its own):
#   geometry  prim_geometry / build_prim: primitives, generators (array along a
#             path, an arc or a grid, optionally dropped onto another module's
#             surface), modifiers (Catmull-Clark subsurf, mirror-safe noise
#             displacement). Pure mesh data; no scene needed except for subsurf.
#   family    load_family / instances / stage_plan: slots x sets -> instances.
#   scene     setup_scene / view_basis / place_camera / render_pass.
#   gate      gate_view: data-driven anchor and coverage gate.
#   pose      poses / pose_matrix / apply_pose: optional articulation (a family "articulation"
#             block tilts slots rigidly about a pivot, e.g. a control stick's tilt grid).
import bpy, bmesh, json, math, os, random, re
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
S2 = math.sqrt(0.5)
DIST = 3000.0
# the hero-plane ("face") frame: columns X, screen-down D, toward-camera N at pitch 45
PLANE = Matrix(((1, 0, 0), (0, -S2, -S2), (0, -S2, S2)))


# ================================================================ geometry
def octagon(w, d, c):
    a, b = w * (1 - c), d * (1 - c)
    return [(w, -b), (w, b), (a, d), (-a, d), (-w, b), (-w, -b), (-a, -d), (a, -d)]


def superellipse(w, d, e, n):
    """n points of |x/w|^e + |y/d|^e = 1, starting at +x (mirror-symmetric about x = 0)."""
    out = []
    for k in range(n):
        a = 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        out.append((w * math.copysign(abs(c) ** (2 / e), c), d * math.copysign(abs(s) ** (2 / e), s)))
    return out


def _ring_faces(rings, n, cap=True):
    f = []
    for i in range(rings - 1):
        for k in range(n):
            a, b = i * n + k, i * n + (k + 1) % n
            f.append((a, b, b + n, a + n))
    if cap:
        f.append(tuple(range(n))[::-1]); f.append(tuple(range((rings - 1) * n, rings * n)))
    return f


def prim_geometry(p):
    """Local verts and faces of one primitive (before rot / at / frame)."""
    t = p['type']
    if t == 'box':
        sx, sy, sz = [s / 2 for s in p['size']]
        tx, ty = p.get('taper', [1, 1]); dx, dy = p.get('skew', [0, 0])
        v = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
             (-sx * tx + dx, -sy * ty + dy, sz), (sx * tx + dx, -sy * ty + dy, sz),
             (sx * tx + dx, sy * ty + dy, sz), (-sx * tx + dx, sy * ty + dy, sz)]
        return v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    if t in ('loft', 'shell'):
        # loft: octagon sections [at, w, d, chamfer, ox, o2]; shell: superellipse sections
        # [at, w, d, exponent, ox, o2] with seg points per ring (organic hulls, with subsurf)
        secs = p['sections']; ax = p['axis']; v = []
        n = 8 if t == 'loft' else p.get('seg', 24)
        for s in secs:
            at, w, d, c, o1, o2 = s
            ring = octagon(w, d, c) if t == 'loft' else superellipse(w, d, c, n)
            for (a, b) in ring:
                v.append((a + o1, at, b + o2) if ax == 'y' else (a + o1, b + o2, at))
        return v, _ring_faces(len(secs), n)
    if t == 'cyl':
        r1, r2, ln, seg = p['r'], p.get('r2', p['r']), p['len'], p.get('seg', 12)
        v = [(r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z)
             for z, r in ((-ln / 2, r1), (ln / 2, r2)) for k in range(seg)]
        return v, _ring_faces(2, seg)
    if t == 'lathe':
        # profile [[r, z], ...] revolved about local z; r = 0 ends close to a point
        prof = p['profile']; seg = p.get('seg', 16)
        v = [(max(r, 1e-3) * math.cos(2 * math.pi * k / seg), max(r, 1e-3) * math.sin(2 * math.pi * k / seg), z)
             for r, z in prof for k in range(seg)]
        return v, _ring_faces(len(prof), seg)
    if t == 'ell':
        rx, ry, rz = p['radii']; seg = p.get('seg', 12); rings = max(4, seg // 2)
        v = [(0, 0, -rz)]
        for i in range(1, rings):
            th = math.pi * i / rings - math.pi / 2
            for k in range(seg):
                a = 2 * math.pi * k / seg
                v.append((rx * math.cos(th) * math.cos(a), ry * math.cos(th) * math.sin(a), rz * math.sin(th)))
        v.append((0, 0, rz)); top = len(v) - 1; f = []
        for k in range(seg):
            f.append((0, 1 + (k + 1) % seg, 1 + k))
        for i in range(rings - 2):
            for k in range(seg):
                a = 1 + i * seg + k; b = 1 + i * seg + (k + 1) % seg
                f.append((a, b, b + seg, a + seg))
        base = 1 + (rings - 2) * seg
        for k in range(seg):
            f.append((base + k, base + (k + 1) % seg, top))
        return v, f
    if t == 'horn':
        # a tube along pts with radii; aspect [a, b] flattens the section (blades, ribs)
        pts = [Vector(q) for q in p['pts']]; radii = p['radii']; seg = p.get('seg', 8)
        asp = p.get('aspect', [1, 1]); v = []
        for i, (c, r) in enumerate(zip(pts, radii)):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            ref = Vector(p.get('up', (1, 0, 0) if abs(d.x) < 0.9 else (0, 0, 1)))
            u = d.cross(ref).normalized(); w = d.cross(u).normalized()
            for k in range(seg):
                a = 2 * math.pi * k / seg
                v.append(tuple(c + r * (asp[0] * math.cos(a) * u + asp[1] * math.sin(a) * w)))
        return v, _ring_faces(len(pts), seg)
    if t == 'shard':
        # crystal: an n-sided bipyramid, r wide, tip h above and foot below (local z up)
        n, r, h, foot = p.get('sides', 6), p['r'], p['h'], p.get('foot', p['r'])
        tw = p.get('twist', 0.0)
        v = [(r * math.cos(2 * math.pi * k / n + tw), r * math.sin(2 * math.pi * k / n + tw), 0) for k in range(n)]
        v += [(0, 0, h), (0, 0, -foot)]
        f = [(k, (k + 1) % n, n) for k in range(n)] + [((k + 1) % n, k, n + 1) for k in range(n)]
        return v, f
    if t == 'prism':
        poly = p['poly']; n0, n1 = p['n0'], p['n1']; m = len(poly)
        v = [(a, b, n0) for a, b in poly] + [(a, b, n1) for a, b in poly]
        f = [tuple(range(m))[::-1], tuple(range(m, 2 * m))]
        f += [(k, (k + 1) % m, m + (k + 1) % m, m + k) for k in range(m)]
        return v, f
    if t == 'star':
        # a flat badge outline extruded along local z: n points alternating r and r2 (r2 = r or
        # omitted: a regular n-gon), first point at a0 degrees (90 = +y); hole > 0 makes it a ring
        n, r, ln = p['n'], p['r'], p['len']; r2 = p.get('r2', r); a0 = math.radians(p.get('a0', 90))
        hole = p.get('hole', 0)
        pts = [(r if k % 2 == 0 else r2) for k in range(2 * n)] if r2 != r else [r] * n
        m = len(pts)
        ring = [(q * math.cos(a0 + 2 * math.pi * k / m), q * math.sin(a0 + 2 * math.pi * k / m)) for k, q in enumerate(pts)]
        if not hole:
            v = [(x, y, z) for z in (-ln / 2, ln / 2) for x, y in ring]
            return v, _ring_faces(2, m)
        inner = [(hole * math.cos(a0 + 2 * math.pi * k / m), hole * math.sin(a0 + 2 * math.pi * k / m)) for k in range(m)]
        v = [(x, y, z) for z in (-ln / 2, ln / 2) for x, y in ring] + [(x, y, z) for z in (-ln / 2, ln / 2) for x, y in inner]
        o0, o1, i0, i1 = 0, m, 2 * m, 3 * m
        f = []
        for k in range(m):
            k2 = (k + 1) % m
            f += [(o1 + k, o1 + k2, i1 + k2, i1 + k), (o0 + k2, o0 + k, i0 + k, i0 + k2),
                  (o0 + k, o0 + k2, o1 + k2, o1 + k), (i0 + k2, i0 + k, i1 + k, i1 + k2)]
        return v, f
    if t == 'web':
        pts = p['pts']; v = [tuple(q) for q in pts]
        c = Vector((0, 0, 0))
        for q in pts: c += Vector(q)
        c /= len(pts); v.append(tuple(c)); ci = len(v) - 1
        return v, [(i, (i + 1) % len(pts), ci) for i in range(len(pts))]
    raise ValueError('unknown prim type ' + t)


def rot_matrix(rot):
    return (Matrix.Rotation(math.radians(rot[2]), 3, 'Z') @ Matrix.Rotation(math.radians(rot[1]), 3, 'Y')
            @ Matrix.Rotation(math.radians(rot[0]), 3, 'X'))


def place(p, frame):
    """Local geometry -> rot -> at -> module frame (ship coordinates)."""
    v, f = prim_geometry(p)
    R = rot_matrix(p.get('rot', [0, 0, 0])); at = Vector(p.get('at', [0, 0, 0]))
    sc = p.get('scale', 1.0)
    out = []
    for q in v:
        q = Vector(q)
        if p['type'] == 'prism' and frame == 'ship':
            q = Vector((q.z, q.x, q.y))  # poly (y, z), extrusion along x
        q = R @ (q * sc) + at
        if frame in ('face', 'plane'):
            q = PLANE @ q
        out.append(q)
    return out, f


# ---------------------------------------------------------------- generators
def _lerp(a, b, t):
    if isinstance(a, (list, tuple)):
        return [x + (y - x) * t for x, y in zip(a, b)]
    return a + (b - a) * t


def path_points(spec, count):
    """count points (and parameters t) along a polyline, an arc or a grid."""
    if 'grid' in spec:
        gx, gy = spec['grid']['x'], spec['grid']['y']; z = spec['grid'].get('z', 0)
        pts = [Vector((x, y, z)) for y in gy for x in gx]
        n = len(pts)
        return [(q, i / max(1, n - 1)) for i, q in enumerate(pts)]
    if 'arc' in spec:
        a = spec['arc']; c = Vector(a['c']); r = a['r']; pl = a.get('plane', 'xy')
        out = []
        for i in range(count):
            t = i / max(1, count - 1)
            ang = math.radians(_lerp(a['a0'], a['a1'], t))
            u, w = math.cos(ang) * r, math.sin(ang) * r
            d = {'xy': (u, w, 0), 'xz': (u, 0, w), 'yz': (0, u, w)}[pl]
            out.append((c + Vector(d), t))
        return out
    pts = [Vector(q) for q in spec['path']]
    if len(pts) == 1:
        return [(pts[0], i / max(1, count - 1)) for i in range(count)]
    seg =[(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(seg) or 1.0; out = []
    for i in range(count):
        t = i / max(1, count - 1) if count > 1 else 0.5
        s = t * total; k = 0
        while k < len(seg) - 1 and s > seg[k]:
            s -= seg[k]; k += 1
        u = s / seg[k] if seg[k] else 0
        out.append((pts[k].lerp(pts[k + 1], min(1.0, u)), t))
    return out


def align_to(n):
    """Rotation taking local +z to the unit vector n (x kept as close to world x as possible)."""
    n = n.normalized(); x = Vector((1, 0, 0))
    if abs(n.dot(x)) > 0.95:
        x = Vector((0, 1, 0))
    y = n.cross(x).normalized(); x = y.cross(n).normalized()
    return Matrix((x, y, n)).transposed()


def cleared(surfaces, w):
    """Whether an array element at unscaled module point w falls in a gate clearing (hero-view
    arena units; surfaces['_clear'] = [(x, y, r)], set per hull; gate modules are never cleared)."""
    cl = surfaces.get('_clear')
    if not cl or surfaces.get('_noclear'):
        return False
    e = surfaces.get('_ext', {}).get('_self', 1.0)
    sx, sy = w.x * e, -(w.y + w.z) * S2 * e
    return any(math.hypot(sx - x, sy - y) < r for x, y, r in cl)


def array_geometry(p, frame, surfaces, off=Vector((0, 0, 0))):
    """An array generator: copies of a child prim at points along a path / arc / grid,
    with ramps (scale, rot), seeded jitter, and optional drop onto a module surface."""
    count = p.get('count', 1)
    pts = path_points(p, count)
    child = p['child']
    s0, s1 = p.get('scale', [1, 1]) if isinstance(p.get('scale', 1), list) else (p.get('scale', 1),) * 2
    r0, r1 = p.get('rot', [[0, 0, 0], [0, 0, 0]])
    jit = p.get('jitter', {}); seed = p.get('seed', 1)
    drop = p.get('drop')
    V, F = [], []
    for i, (q, t) in enumerate(pts):
        # mirror-safe jitter: an element and its x-mirror twin draw the same numbers, mirrored;
        # an element on the centre line gets no asymmetric jitter
        rng = random.Random(hash((seed, round(abs(q.x), 1), round(q.y, 1), round(q.z, 1))))
        sg = 0.0 if abs(q.x) < 0.5 else math.copysign(1.0, q.x)
        j = lambda k: (rng.random() * 2 - 1) * jit.get(k, 0)
        sc = _lerp(s0, s1, t) * (1 + j('scale'))
        jr = j('rot'); rot = [a + d for a, d in zip(_lerp(r0, r1, t), (jr, sg * jr, sg * jr))]
        q = q + Vector((sg * j('pos'), j('pos'), 0))
        cv, cf = prim_geometry(child)
        cR = rot_matrix(child.get('rot', [0, 0, 0])); cat = Vector(child.get('at', [0, 0, 0]))
        M = rot_matrix(rot)
        if frame in ('face', 'plane'):  # the child is authored in the plane frame too
            q = PLANE @ q; M = PLANE @ M
        if drop:
            bvh = surfaces.get(drop['onto'])
            if bvh is None:
                raise ValueError('drop onto unknown surface %s' % drop['onto'])
            # surfaces are stored unscaled; a module with another extent (a fixed gate on a
            # scaled hull) casts in the target's unscaled space: k = own extent / target extent
            ext = surfaces.get('_ext', {})
            k = ext.get('_self', 1.0) / ext.get(drop['onto'], ext.get('_self', 1.0))
            d = Vector(drop.get('dir', (0, 0, -1))).normalized()
            # mirror-safe: a left element casts at its right twin and mirrors the hit (the BVH
            # triangulates quads along one diagonal, so hit normals are not mirror-exact)
            o = (q + off) * k; fl = o.x < 0
            m = Vector((-1, 1, 1))
            oc = o * m if fl else o; dc = d * m if fl else d
            hit = bvh.ray_cast(oc - dc * 4000, dc)
            if hit[0] is None:
                continue  # off the surface: no copy
            hp, hn = Vector(hit[0]) / k, Vector(hit[1])
            if hn.dot(dc) > 0:
                hn = -hn
            if abs(o.x) < 0.5:
                hn.x = 0.0; hn.normalize(); hp.x = o.x
            if fl:
                hp = hp * m; hn = hn * m
            nrm = hn
            q = hp - off - d * drop.get('offset', 0)
            if drop.get('align', True):
                tilt = drop.get('tilt', 1.0)  # 1 = follow the normal, 0 = keep the drop direction
                M = align_to((-d).lerp(nrm, tilt)) @ M
        if cleared(surfaces, q + off):
            continue  # carrier-v3: decor never covers a gate
        base = len(V)
        for c in cv:
            V.append(M @ (cR @ (Vector(c) * sc) + cat * sc) + q)
        F += [tuple(base + k for k in face) for face in cf]
    return V, F


# ---------------------------------------------------------------- modifiers
def subdivide(verts, faces, levels):
    me = bpy.data.meshes.new('_sub'); me.from_pydata([tuple(v) for v in verts], [], faces); me.validate()
    ob = bpy.data.objects.new('_sub', me); bpy.context.scene.collection.objects.link(ob)
    m = ob.modifiers.new('sub', 'SUBSURF'); m.levels = levels; m.render_levels = levels
    dg = bpy.context.evaluated_depsgraph_get()
    em = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    v = [Vector(x.co) for x in em.vertices]; f = [tuple(pl.vertices) for pl in em.polygons]
    bpy.data.objects.remove(ob, do_unlink=True); bpy.data.meshes.remove(me); bpy.data.meshes.remove(em)
    return v, f


def vertex_normals(verts, faces):
    acc = [Vector((0, 0, 0)) for _ in verts]
    for f in faces:
        if len(f) < 3:
            continue
        n = Vector((0, 0, 0))  # Newell normal: independent of the face's start vertex (mirror-safe)
        for a, b in zip(f, f[1:] + f[:1]):
            p, q = verts[a], verts[b]
            n += Vector(((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x), (p.x - q.x) * (p.y + q.y)))
        for k in f:
            acc[k] += n
    return [a.normalized() if a.length > 1e-9 else Vector((0, 0, 1)) for a in acc]


def displace(verts, faces, spec):
    """Mirror-safe organic displacement: noise of (|x|, y, z) along the vertex normal."""
    amp, freq = spec.get('amp', 2.0), spec.get('freq', 0.05)
    noise.seed_set(spec.get('seed', 7))
    oct_ = spec.get('octaves', 3); ridged = spec.get('ridged', False)
    ns = vertex_normals(verts, faces); out = []
    for v, n in zip(verts, ns):
        q = Vector((abs(v.x), v.y, v.z)) * freq
        if ridged:
            h = 1 - abs(noise.noise(q, noise_basis='PERLIN_ORIGINAL'))
            h = h * h - 0.5
        else:
            h = noise.fractal(q, 0.6, 2.0, oct_, noise_basis='PERLIN_ORIGINAL')
        out.append(v + n * amp * h)
    return out


def build_prim(p, frame, surfaces, off=Vector((0, 0, 0))):
    """World verts and faces of a prim (module frame), with generators and modifiers."""
    if p['type'] == 'array':
        v, f = array_geometry(p, frame, surfaces, off)
    else:
        v, f = place(p, frame)
    if not v:
        return v, f
    if p.get('subsurf'):
        v, f = subdivide(v, f, p['subsurf'])
    if p.get('displace'):
        v = displace(v, f, p['displace'])
    return v, f


def mirror_x(verts):
    return [Vector((-q.x, q.y, q.z)) for q in verts]


def mesh_from(verts, faces, name, smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    if smooth:
        for pl in me.polygons:
            pl.use_smooth = True
    return me


# ================================================================ family
def load_family(path):
    with open(path) as fh:
        g = json.load(fh)
    g['_path'] = os.path.relpath(os.path.abspath(path), ROOT)
    return g


def module_def(g, slot, set_name):
    """A module = a slot's shared fields + common prims + one set's prims and points."""
    s = g['slots'][slot]
    sets = s.get('sets', {})
    if set_name not in sets:
        set_name = s.get('default_set', next(iter(sets)) if sets else None)
    sd = sets.get(set_name, {}) if set_name else {}
    m = {k: v for k, v in s.items() if k not in ('sets', 'common')}
    m.update({k: v for k, v in sd.items() if k != 'prims'})
    m['prims'] = list(s.get('common', [])) + list(sd.get('prims', []))
    m['set'] = set_name
    for k in ('lights', 'fires', 'nozzles', 'vortex'):
        m[k] = list(s.get('common_' + k, [])) + list(sd.get(k, []))
    if 'hinge' in sd:
        m['hinge'] = sd['hinge']
    return m


def instances(g, hull):
    """Instances of a hull: dicts {id, slot, set, module, sign, offset, def}."""
    h = g['hulls'][hull]; out = []
    for e in h['slots']:
        if isinstance(e, str):
            e = {'slot': e}
        slot = e['slot']; sname = e.get('set', h.get('sets', {}).get(slot, h.get('set')))
        mod = module_def(g, slot, sname)
        for k in ('detach', 'texel', 'gameplay', 'wreck'):
            if k in e:
                mod[k] = e[k]
        base = slot + ('_' + e['suffix'] if e.get('suffix') else '')
        rec = {'slot': slot, 'set': mod['set'], 'module': '%s.%s' % (slot, mod['set']) if mod['set'] else slot,
               'offset': e.get('offset', [0, 0, 0]), 'scale': e.get('scale', 1.0), 'def': mod}
        if mod.get('mirror') or e.get('mirror'):
            out.append(dict(rec, id=base + 'L', sign=-1)); out.append(dict(rec, id=base + 'R', sign=1))
        else:
            out.append(dict(rec, id=base, sign=1))
    return out


def stage_plan(g, hull, stage):
    """(shed tags, removed instance ids) for a stage, from g['stages'][stage]."""
    st = g['stages'][stage]; insts = instances(g, hull)
    shed = set(st.get('shed', []))
    removed = set()
    n = st.get('detach', 0)
    if n:
        ranks = sorted({i['def'].get('detach') for i in insts if i['def'].get('detach') is not None})
        for r in ranks[:n]:
            removed |= {i['id'] for i in insts if i['def'].get('detach') == r}
    return shed, removed


def module_geometry(g, hull, inst, surfaces, shed=()):
    """[(prim name, tag, smooth, verts, faces)] of one instance in hull coordinates (sign applied,
    extent applied). Also registers the instance's own unscaled surface (BVH) for later drops."""
    mod = inst['def']; frame = mod.get('frame', 'ship')
    ext = 1.0 if mod.get('fixed') else g['hulls'][hull].get('extent', 1.0) * inst.get('scale', 1.0)
    off = Vector(inst['offset']); parts = []; surf_v, surf_f = [], []
    surfaces.setdefault('_ext', {})['_self'] = ext
    surfaces['_noclear'] = mod.get('gameplay') == 'gate' or inst['slot'] == 'prow'
    tmap = g['hulls'][hull].get('tag_map', {})  # carrier-v3: a hull may repaint a material (carrier4-shroud plate -> scale)
    for p in mod['prims']:
        tag = tmap.get(p['tag'], p['tag'])
        if p.get('drop', {}).get('onto') == 'self':  # drop onto this module's earlier prims
            surfaces['self'] = BVHTree.FromPolygons([tuple(q) for q in surf_v], surf_f)
        v, f = build_prim(p, frame, surfaces, off)
        if not v:
            continue
        v = [q + off for q in v]
        copies = [(v, f)]
        if p.get('mirror'):
            copies.append((mirror_x(v), [tuple(reversed(x)) for x in f]))
        for ci, (cv, cf) in enumerate(copies):
            if p.get('surface', True):
                b = len(surf_v); surf_v += cv; surf_f += [tuple(b + k for k in x) for x in cf]
            if tag in shed:
                continue
            wv = mirror_x(cv) if inst['sign'] < 0 else cv
            wv = [q * ext for q in wv]
            door = door_matrix(p.get('open'), frame, wv, inst['sign'] if ci == 0 else -inst['sign']) if p.get('open') else None
            parts.append((p['name'] + ('' if ci == 0 else '.m'), tag, bool(p.get('subsurf') or p.get('smooth')), wv, cf, door))
    if surf_v:
        surfaces[inst['slot']] = BVHTree.FromPolygons([tuple(q) for q in surf_v], surf_f)
        surfaces['_ext'][inst['slot']] = ext
    return parts


def door_matrix(spec, frame, verts, sign):
    """carrier-v3 gates: the world matrix of a door part in its open state. spec (module frame):
    {pivot: [x, y, n] from the part's centroid, rot: [rx, ry, rz] degrees about the pivot,
    move: [x, y, n], scale: s}. Only matrix_world moves, so the bake's object coordinates carry
    the closed state's projected texture with the part (as the articulation poses do)."""
    F = PLANE if frame in ('face', 'plane') else Matrix.Identity(3)
    M = Matrix(((-1, 0, 0), (0, 1, 0), (0, 0, 1)))
    R = F @ rot_matrix(spec.get('rot', [0, 0, 0])) @ F.transposed()
    piv = F @ Vector(spec.get('pivot', [0, 0, 0])); mv = F @ Vector(spec.get('move', [0, 0, 0]))
    if sign < 0:
        R = M @ R @ M; piv = M @ piv; mv = M @ mv
    c = Vector((0, 0, 0))
    for v in verts: c += v
    P = c / max(1, len(verts)) + piv
    S = Matrix.Diagonal(Vector((spec.get('scale', 1.0),) * 3)).to_4x4()
    return Matrix.Translation(P + mv) @ R.to_4x4() @ S @ Matrix.Translation(-P)


def build_hull(g, hull, stage='S0', mats=None, doors='closed'):
    """Create the hull's objects in the scene; returns {instance id: [objects]}.
    Instances build in hull order, so a later slot can drop onto an earlier one.
    doors='open' sets every door part (a prim with an 'open' spec) to its open matrix."""
    shed, removed = stage_plan(g, hull, stage)
    ids = {i['id'] for i in instances(g, hull)}
    surfaces = {'_clear': [(p['at'][0], p['at'][1], p['clear']) for p in g.get('anchors', {}).get('points', [])
                           if p.get('clear') and p['module'] in ids]}
    objs = {}
    for inst in instances(g, hull):
        parts = module_geometry(g, hull, inst, surfaces, shed)
        if inst['id'] in removed:
            continue
        objs[inst['id']] = []
        for name, tag, smooth, v, f, door in parts:
            nm = '%s.%s' % (inst['id'], name)
            ob = bpy.data.objects.new(nm, mesh_from(v, f, nm, smooth))
            ob['tag'] = tag; ob['inst'] = inst['id']; ob['prim'] = name
            if door is not None:
                ob['door'] = [c for r in door for c in r]
            bpy.context.scene.collection.objects.link(ob)
            if mats:
                ob.data.materials.append(mats[tag])
            objs[inst['id']].append(ob)
    set_doors(objs, doors)
    return objs


def set_doors(objs, state):
    """Door parts to their closed (rest) or open matrix."""
    for lst in objs.values():
        for ob in lst:
            if 'door' in ob:
                d = list(ob['door'])
                ob.matrix_world = Matrix([d[0:4], d[4:8], d[8:12], d[12:16]]) if state == 'open' else Matrix.Identity(4)
    bpy.context.view_layer.update()


def door_insts(objs):
    """Instance ids with door parts."""
    return [iid for iid, lst in objs.items() if any('door' in ob for ob in lst)]


def module_point(g, hull, inst, q):
    """A module-local point (lights, fires, nozzles) in hull coordinates."""
    mod = inst['def']; v = Vector(q[:3])
    if mod.get('frame', 'ship') in ('face', 'plane'):
        v = PLANE @ v
    v = v + Vector(inst['offset'])
    if inst['sign'] < 0:
        v.x = -v.x
    if not mod.get('fixed'):
        v = v * g['hulls'][hull].get('extent', 1.0) * inst.get('scale', 1.0)
    return v


# ================================================================ views
def swerve_axis(g):
    return Vector(g['views'].get('swerve_axis', (0.0, S2, S2)))


def view_basis(g, pitch, yaw):
    """Camera right, up and back vectors (world) for a view: pitch = elevation above the hull
    plane from the bow side; yaw orbits about the family's swerve axis (a banked turn)."""
    p = math.radians(pitch)
    right = Vector((1, 0, 0)); up = Vector((0, math.sin(p), math.cos(p))); back = Vector((0, -math.cos(p), math.sin(p)))
    Rinv = Matrix.Rotation(math.radians(-yaw), 3, swerve_axis(g))
    return Rinv @ right, Rinv @ up, Rinv @ back


def project(v, basis):
    right, up, _ = basis
    return (v.dot(right), -v.dot(up))  # arena units: x right, y down


def view_tag(pitch, yaw):
    return 'p%02d_y%+03d' % (pitch, yaw)


def all_views(g, which='all'):
    if which in ('hero', 'belly'):
        return [tuple(g['views'][which])]
    vs = [(p, y) for p in g['views']['pitch'] for y in g['views']['yaw']]
    if which == 'stored':
        if 'stored' in g['views']:
            return [tuple(v) for v in g['views']['stored']]
        st = g['views'].get('stored_yaw', g['views']['yaw'])
        vs = [(p, y) for (p, y) in vs if y in st]
    return vs


def place_camera(cam, basis, frame):
    right, up, back = basis
    M = Matrix((right, up, back)).transposed().to_4x4()
    M.translation = back * DIST
    cam.matrix_world = M
    x0, y0, x1, y1 = frame
    w, h = x1 - x0, y1 - y0; sc = max(w, h)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = sc
    cam.data.shift_x = ((x0 + x1) / 2) / sc
    cam.data.shift_y = -((y0 + y1) / 2) / sc
    cam.data.clip_start = 1.0; cam.data.clip_end = DIST * 2


def all_verts(objs):
    for lst in objs.values():
        for ob in lst:
            for v in ob.data.vertices:
                yield ob.matrix_world @ v.co


def hull_frame(g, objs, views, ppu, hull=None):
    """One frame (arena units) for every view: the projected bounds + margin, clipped to the
    family's visible envelope (render.envelope; parts outside it never reach the screen).
    With an articulated family and its hull, the frame holds every pose too."""
    verts = list(all_verts(objs))
    if hull is not None and g.get('articulation'):
        for pose in poses(g):
            apply_pose(g, objs, hull, pose); verts += list(all_verts(objs))
        apply_pose(g, objs, hull, poses(g)[0])
    x0 = y0 = 1e9; x1 = y1 = -1e9
    for (p, y) in views:
        b = view_basis(g, p, y)
        for v in verts:
            sx, sy = project(v, b)
            x0, x1, y0, y1 = min(x0, sx), max(x1, sx), min(y0, sy), max(y1, sy)
    m = g.get('render', {}).get('margin', 6)
    x0, y0 = math.floor(x0 - m), math.floor(y0 - m); x1, y1 = math.ceil(x1 + m), math.ceil(y1 + m)
    fixed = g.get('render', {}).get('frame')
    if fixed:  # one frame for every hull (layer families: cells stack when the frames agree)
        x0, y0, x1, y1 = fixed
        return (x0, y0, x1, y1), max(max(v.length for v in verts), math.hypot(x1 - x0, y1 - y0))
    env = envelope(g, hull)
    if env:
        x0, y0, x1, y1 = max(x0, env[0]), max(y0, env[1]), min(x1, env[2]), min(y1, env[3])
    w = math.ceil((x1 - x0) * ppu / 2) * 2 / ppu; h = math.ceil((y1 - y0) * ppu / 2) * 2 / ppu
    return (x0, y0, x0 + w, y0 + h), max(v.length for v in verts)


def envelope(g, hull=None):
    """The visible envelope (carrier-v3 §6.2: per hull, render.envelope as the fallback); None
    with --envelope off."""
    if g.get('_envelope_off'):
        return None
    if hull is not None and 'envelope' in g['hulls'].get(hull, {}):
        return g['hulls'][hull]['envelope']
    return g.get('render', {}).get('envelope')


def module_rect_px(objs_list, basis, frame, ppu, pad=3):
    """Pixel rect (x0, y0, x1, y1) of a module's projection in a frame, for render borders."""
    xs, ys = [], []
    for ob in objs_list:
        for v in ob.data.vertices:
            sx, sy = project(ob.matrix_world @ v.co, basis); xs.append(sx); ys.append(sy)
    if not xs:
        return None
    fx0, fy0 = frame[0], frame[1]
    return (max(0, int((min(xs) - fx0) * ppu) - pad), max(0, int((min(ys) - fy0) * ppu) - pad),
            int((max(xs) - fx0) * ppu) + pad, int((max(ys) - fy0) * ppu) + pad)


# ================================================================ gate
def ray_hit(scene, origin, direction):
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, nrm, idx, ob, mat = scene.ray_cast(dg, origin, direction, distance=DIST * 4)
    return (ob.name if hit else None), (Vector(loc) if hit else None)


def obj_centre(objs_list):
    vs = [ob.matrix_world @ v.co for ob in objs_list for v in ob.data.vertices]
    c = Vector((0, 0, 0))
    for v in vs: c += v
    return c / len(vs)


def gate_view(g, objs, basis, scene):
    """The data-driven anchor gate of one view: each anchor prim projects within the tolerance of
    its target and is the first thing the camera sees there; the coverage rect is all hull."""
    a = g.get('anchors', {}); tol = a.get('tolerance', 3.0); res = {}; fails = []
    right, up, back = basis
    for pt in a.get('points', []):
        inst, prim = pt['module'], pt['prim']
        obs = [ob for ob in objs.get(inst, []) if ob['prim'] == prim]
        if not obs and pt.get('optional') and inst not in objs:
            continue  # a gate of a later tour
        if not obs:
            fails.append('%s: prim %s.%s missing' % (pt['name'], inst, prim)); continue
        c = obj_centre(obs); sx, sy = project(c, basis)
        err = math.hypot(sx - pt['at'][0], sy - pt['at'][1])
        hit, _ = ray_hit(scene, c + back * DIST, -back)
        # a closed gate door over a window is part of the window (carrier-v3 §4)
        clear = hit is not None and (hit.startswith(inst + '.') or hit.startswith('gate_'))
        res[pt['name']] = {'x': round(sx, 2), 'y': round(sy, 2), 'err': round(err, 2), 'unobstructed': clear, 'hit': hit}
        if err > tol:
            fails.append('%s off by %.2f' % (pt['name'], err))
        if not clear:
            fails.append('%s obstructed by %s' % (pt['name'], hit))
    cov = a.get('coverage')
    if cov:
        x0, y0, x1, y1 = cov['rect']; ins = cov.get('inset', 0); nx, ny = cov.get('grid', [9, 5])
        x0, y0, x1, y1 = x0 + ins, y0 + ins, x1 - ins, y1 - ins
        miss = []
        for i in range(nx):
            for j in range(ny):
                ax = x0 + (x1 - x0) * i / (nx - 1); ay = y0 + (y1 - y0) * j / (ny - 1)
                hit, _ = ray_hit(scene, right * ax - up * ay + back * DIST, -back)
                if hit is None:
                    miss.append((round(ax, 1), round(ay, 1)))
        res['coverage'] = {'samples': nx * ny, 'missed': miss}
        if miss:
            fails.append('coverage rect not all hull at %s' % miss[:4])
    return res, fails


def project_points(g, hull, objs, basis, scene):
    """Lights, fires and nozzles of the present instances, projected, with visibility."""
    out = {'lights': [], 'fires': [], 'nozzles': [], 'vortex': []}
    insts = {i['id']: i for i in instances(g, hull)}
    _, _, back = basis
    for iid in objs:
        inst = insts[iid]
        for kind in out:
            for q in inst['def'].get(kind, []):
                v = module_point(g, hull, inst, q)
                sx, sy = project(v, basis)
                hit, loc = ray_hit(scene, v + back * DIST, -back)
                rec = {'module': iid, 'x': round(sx, 2), 'y': round(sy, 2),
                       'visible': loc is not None and (loc - v).length < 3.0}
                if kind == 'lights': rec['kind'] = q[3]
                if kind == 'nozzles': rec['size'] = q[3]
                out[kind].append(rec)
    return out


# ================================================================ scene and passes
def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def clear_scene():
    for ob in list(bpy.data.objects):
        if ob.type == 'MESH':
            bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def setup_scene(threads):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.threads_mode = 'FIXED'; sc.render.threads = threads
    sc.render.film_transparent = True
    # emission passes on Cycles CPU: ~0.4 GB against EEVEE's ~1.5 GB software-GL baseline
    sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False; sc.cycles.use_adaptive_sampling = False
    sc.cycles.pixel_filter_type = 'BOX'; sc.cycles.filter_width = 0.01
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam


def emission_material(name, build):
    mat = bpy.data.materials.new(name)
    if hasattr(mat, 'use_nodes') and not mat.node_tree: mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    em = nt.nodes.new('ShaderNodeEmission'); out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    build(nt, em)
    return mat


def depth_material(near, far, name='depth'):
    def b(nt, em):
        cd = nt.nodes.new('ShaderNodeCameraData'); mr = nt.nodes.new('ShaderNodeMapRange')
        mr.inputs['From Min'].default_value = near; mr.inputs['From Max'].default_value = far
        mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.0
        nt.links.new(cd.outputs['View Z Depth'], mr.inputs['Value'])
        nt.links.new(mr.outputs['Result'], em.inputs['Color'])
    return emission_material(name, b)


def const_material(name, val):
    def b(nt, em):
        em.inputs['Color'].default_value = (val, val, val, 1.0)
    return emission_material(name, b)


def normal_material():
    def b(nt, em):
        geo = nt.nodes.new('ShaderNodeNewGeometry')
        vt = nt.nodes.new('ShaderNodeVectorTransform')
        vt.vector_type = 'NORMAL'; vt.convert_from = 'WORLD'; vt.convert_to = 'CAMERA'
        ma = nt.nodes.new('ShaderNodeVectorMath'); ma.operation = 'MULTIPLY_ADD'
        ma.inputs[1].default_value = (0.5, 0.5, -0.5); ma.inputs[2].default_value = (0.5, 0.5, 0.5)
        nt.links.new(geo.outputs['Normal'], vt.inputs['Vector'])
        nt.links.new(vt.outputs['Vector'], ma.inputs[0])
        nt.links.new(ma.outputs['Vector'], em.inputs['Color'])
    return emission_material('normal', b)


def clay_materials(g):
    mats = {}
    for tag, m in g['materials'].items():
        mat = bpy.data.materials.new('clay_' + tag)
        c = m['clay']; mat.diffuse_color = (c, c, c, 1.0)
        mats[tag] = mat
    return mats


def hint_rgb(m):
    """Hint colour of a material: '#RRGGBB', or legacy 'bright' / 'dark'; None = plain clay."""
    h = m.get('hint')
    if h is None:
        return None
    if h == 'bright':
        return (1.0, 1.0, 1.0)
    if h == 'dark':
        return (0.0, 0.0, 0.0)
    return hex_rgb(h)


def set_override(objs, pick):
    for lst in objs.values():
        for ob in lst:
            ob.data.materials.clear(); ob.data.materials.append(pick(ob))


def render_pass(sc, path, kind, objs, ctx):
    """clay (Workbench studio + cavity), hint (flat hint colours, alpha 0 = plain clay),
    id (flat module colours), depth / z (Cycles emission of view depth), normal (camera space)."""
    rs = sc.render
    rs.image_settings.color_depth = '8'; rs.image_settings.color_mode = 'RGBA'
    g = ctx['g']
    if kind in ('clay', 'id', 'hint'):
        rs.engine = 'BLENDER_WORKBENCH'
        sh = sc.display.shading
        if kind == 'clay':
            sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_cavity = True
            sh.cavity_type = 'BOTH'; sh.show_shadows = g.get('render', {}).get('clay_shadows', False)
            sh.cavity_ridge_factor = 1.0; sh.cavity_valley_factor = 1.0
            sc.display.render_aa = '8'; sc.view_settings.view_transform = 'Standard'
            for lst in objs.values():
                for ob in lst: ob.hide_render = False
            set_override(objs, lambda ob: ctx['mats'][ob['tag']])
        else:
            sh.light = 'FLAT'; sh.color_type = 'OBJECT'; sh.show_cavity = False; sh.show_shadows = False
            sc.display.render_aa = 'OFF'; sc.view_settings.view_transform = 'Raw'
            for lst in objs.values():
                for ob in lst:
                    if kind == 'id':
                        r, gg, b = ctx['ids'][ob['inst']]; a = 1.0
                    else:
                        hc = hint_rgb(g['materials'][ob['tag']])
                        (r, gg, b), a = (hc, 1.0) if hc else ((0.5, 0.5, 0.5), 1.0)
                        if not hc:
                            r = gg = b = 0.5
                    ob.color = (r, gg, b, a)
    else:
        rs.engine = 'CYCLES'
        sc.cycles.samples = 1
        sc.view_settings.view_transform = 'Raw'
        if kind == 'depth':
            set_override(objs, lambda ob: ctx['depth'])
        elif kind == 'z':
            rs.image_settings.color_depth = '16'
            set_override(objs, lambda ob: ctx['zmat'])
        elif kind == 'normal':
            set_override(objs, lambda ob: ctx['normal'])
    rs.filepath = path
    bpy.ops.render.render(write_still=True)


# ================================================================ articulation
# A family may declare
#   "articulation": {"pivot": [x, y, z], "dirs": 8, "tilts": [8, 16, 24],
#                    "follow": {slot: k | {"k": k, "pivot": [x, y, z]}}}
# A pose tilts every instance of a following slot rigidly by k x tilt degrees about its pivot,
# toward the direction a (degrees, 0 = +x, 90 = +y; the family's own frame). Slots not listed
# stay put. Objects keep their rest mesh (only matrix_world moves), so the projection bake's
# object coordinates carry the hero texture with the part: every pose shows the same paint.
def poses(g):
    """[(id, direction degrees, tilt degrees)]: the rest pose first, then dirs x tilts."""
    a = g.get('articulation')
    if not a:
        return [('rest', 0.0, 0.0)]
    n = a.get('dirs', 8); out = [('c', 0.0, 0.0)]
    for t in a['tilts']:
        for k in range(n):
            ang = 360.0 * k / n
            out.append(('a%03d_t%02d' % (round(ang), round(t)), ang, float(t)))
    return out


def pose_matrix(g, slot, pose):
    a = g.get('articulation') or {}
    _, ang, tilt = pose
    f = a.get('follow', {}).get(slot, 0); pv = a.get('pivot', [0, 0, 0])
    if isinstance(f, dict):
        pv = f.get('pivot', pv); f = f.get('k', 1.0)
    if not f or not tilt:
        return Matrix.Identity(4)
    r = math.radians(ang)
    axis = Vector((-math.sin(r), math.cos(r), 0.0))  # rotating +z about it leans toward (cos, sin, 0)
    pv = Vector(pv)
    return Matrix.Translation(pv) @ Matrix.Rotation(math.radians(tilt * f), 4, axis) @ Matrix.Translation(-pv)


def apply_pose(g, objs, hull, pose):
    """Set every object's matrix_world for a pose (instances keep their rest meshes)."""
    slots = {i['id']: i['slot'] for i in instances(g, hull)}
    for iid, lst in objs.items():
        M = pose_matrix(g, slots[iid], pose)
        for ob in lst:
            ob.matrix_world = M
    bpy.context.view_layer.update()
