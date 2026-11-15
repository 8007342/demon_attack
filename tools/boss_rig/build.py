# boss-hero-assets tasks 1.3, 2.1, 2.2: the boss rig in headless Blender (bpy).
# Python only because bpy forces it (forge order: Lua > Rust > Go).
#
#   PY=$(lua tools/boss_rig/setup_bpy.lua)
#   $PY -I tools/boss_rig/build.py --check                    # grammar gate, no renders
#   $PY -I tools/boss_rig/build.py OUT [--hulls a,b] [--stages S0,S2,S3] [--views all|hero]
#                                     [--passes clay,hint,depth,normal,id,z] [--ppu-scale 2] [--threads 8]
#
# Builds each hull from art/families/boss-hulls.json (procedural modules on a
# spine), renders per view and stage: clay (Workbench, hints drawn in), depth
# (Cycles emission of view depth, near = white, hints: eyes and lights white,
# maw and bays black), normal (camera space, Cycles), id (flat module colours,
# no AA), z (16-bit linear depth, for the projection bake), and writes
# OUT/<hull>/rig.json: frame, ppu, view cameras, module ids, and the projected
# anchors (functional windows, lights, fires, nozzles) per view and stage.
# The anchor gate (task 2.2) fails the build (exit 2) if the core maw, bays or
# turret pivots project more than the tolerance away from BossAtlas, or the
# solid body is not covered by hull, in any view.
#
# Camera: orthographic, 1 world unit = 1 arena unit. Pitch p = the camera's
# elevation above the hull plane, from the bow side. A swerve of yaw t turns
# the hull about the hero view's screen-up axis A = (0, .7071, .7071): a banked
# turn (heading and roll ~t/sqrt2 each), which keeps the functional face on the
# simulation windows. Positive t turns the bow toward screen right.
import bpy, bmesh, json, math, os, re, sys, time
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GRAMMAR = os.path.join(ROOT, 'art/families/boss-hulls.json')
ATLAS_DART = os.path.join(ROOT, 'lib/game/boss_atlas.dart')
S2 = math.sqrt(0.5)
DIST = 2000.0
AXIS_A = Vector((0.0, S2, S2))
FACE = Matrix(((1, 0, 0), (0, -S2, -S2), (0, -S2, S2)))  # columns: X, screen-down D, toward-camera N


# ---------------------------------------------------------------- geometry
def octagon(w, d, c):
    a, b = w * (1 - c), d * (1 - c)
    return [(w, -b), (w, b), (a, d), (-a, d), (-w, b), (-w, -b), (-a, -d), (a, -d)]


def mesh_from(verts, faces, name):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    return me


def prim_geometry(p):
    """Local verts and faces of one prim (before at/rot/frame)."""
    t = p['type']
    if t == 'box':
        sx, sy, sz = [s / 2 for s in p['size']]
        tx, ty = p.get('taper', [1, 1]); dx, dy = p.get('skew', [0, 0])
        v = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
             (-sx * tx + dx, -sy * ty + dy, sz), (sx * tx + dx, -sy * ty + dy, sz),
             (sx * tx + dx, sy * ty + dy, sz), (-sx * tx + dx, sy * ty + dy, sz)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        return v, f
    if t == 'loft':
        secs = p['sections']; ax = p['axis']; v = []; f = []
        for s in secs:
            at, w, d, c, o1, o2 = s
            for (a, b) in octagon(w, d, c):
                v.append((a + o1, at, b + o2) if ax == 'y' else (a + o1, b + o2, at))
        n = 8
        for i in range(len(secs) - 1):
            for k in range(n):
                a, b = i * n + k, i * n + (k + 1) % n
                f.append((a, b, b + n, a + n))
        f.append(tuple(range(n))[::-1]); f.append(tuple(range((len(secs) - 1) * n, len(secs) * n)))
        return v, f
    if t == 'cyl':
        r1, r2, ln, seg = p['r'], p.get('r2', p['r']), p['len'], p.get('seg', 12)
        v = []
        for z, r in ((-ln / 2, r1), (ln / 2, r2)):
            for k in range(seg):
                a = 2 * math.pi * k / seg
                v.append((r * math.cos(a), r * math.sin(a), z))
        f = [(k, (k + 1) % seg, seg + (k + 1) % seg, seg + k) for k in range(seg)]
        f.append(tuple(range(seg))[::-1]); f.append(tuple(range(seg, 2 * seg)))
        return v, f
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
        pts = [Vector(q) for q in p['pts']]; radii = p['radii']; seg = p.get('seg', 8)
        v = []; f = []
        for i, (c, r) in enumerate(zip(pts, radii)):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            # ring frame from the x axis, so centreline horns stay mirror-symmetric
            ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 0, 1))
            u = d.cross(ref).normalized(); w = d.cross(u).normalized()
            for k in range(seg):
                a = 2 * math.pi * k / seg
                v.append(tuple(c + r * (math.cos(a) * u + math.sin(a) * w)))
        for i in range(len(pts) - 1):
            for k in range(seg):
                a, b = i * seg + k, i * seg + (k + 1) % seg
                f.append((a, b, b + seg, a + seg))
        f.append(tuple(range(seg))[::-1]); f.append(tuple(range((len(pts) - 1) * seg, len(pts) * seg)))
        return v, f
    if t == 'prism':
        poly = p['poly']; n0, n1 = p['n0'], p['n1']; m = len(poly)
        # face frame: poly (ax, ay), extruded along n; ship frame: poly (y, z), extruded along x
        v = [(a, b, n0) for a, b in poly] + [(a, b, n1) for a, b in poly]
        f = [tuple(range(m))[::-1], tuple(range(m, 2 * m))]
        f += [(k, (k + 1) % m, m + (k + 1) % m, m + k) for k in range(m)]
        return v, f
    if t == 'web':
        pts = p['pts']; v = [tuple(q) for q in pts]
        c = Vector((0, 0, 0))
        for q in pts: c += Vector(q)
        c /= len(pts); v.append(tuple(c)); ci = len(v) - 1
        f = [(i, (i + 1) % len(pts), ci) for i in range(len(pts))]
        return v, f
    raise ValueError('unknown prim type ' + t)


def prim_world(p, frame):
    """World verts of a prim: local -> rot -> at, in the module frame."""
    v, f = prim_geometry(p)
    t = p['type']
    rot = p.get('rot', [0, 0, 0])
    R = (Matrix.Rotation(math.radians(rot[2]), 3, 'Z') @ Matrix.Rotation(math.radians(rot[1]), 3, 'Y')
         @ Matrix.Rotation(math.radians(rot[0]), 3, 'X'))
    at = Vector(p.get('at', [0, 0, 0]))
    out = []
    for q in v:
        q = Vector(q)
        if t == 'prism' and frame == 'ship':
            q = Vector((q.z, q.x, q.y))  # poly (y, z), extrusion along x
        q = R @ q + at
        if frame == 'face':
            q = FACE @ q
        out.append(q)
    return out, f


def mirror_x(verts):
    return [Vector((-q.x, q.y, q.z)) for q in verts]


# ---------------------------------------------------------------- grammar
def load_grammar():
    with open(GRAMMAR) as fh:
        return json.load(fh)


def hull_instances(g, hull):
    """Module instances of a hull: (instance id, module name, mirror sign, offset)."""
    out = []
    for m in g['hulls'][hull]['modules']:
        if isinstance(m, str):
            m = {'module': m}
        name = m['module']; mod = g['modules'][name]
        suffix = m.get('suffix'); off = m.get('offset', [0, 0, 0])
        base = name + ('_' + suffix if suffix else '')
        if mod.get('mirror') or m.get('mirror'):
            out.append((base + 'L', name, -1, off)); out.append((base + 'R', name, 1, off))
        else:
            out.append((base, name, 1, off))
    return out


def detach_rank(g, inst):
    return g['modules'][inst[1]].get('detach')


def stage_geometry(g, hull, stage):
    """(plates_on, removed instance ids) for a stage."""
    insts = hull_instances(g, hull)
    if stage in ('S0', 'S1'):
        return True, set()
    if stage == 'S2':
        return False, set()
    ranks = sorted({detach_rank(g, i) for i in insts if detach_rank(g, i) is not None})
    first = ranks[0] if ranks else None
    return False, {i[0] for i in insts if detach_rank(g, i) == first}


def module_point(g, hull, inst, q, frame):
    """A module-local point (lights, fires, nozzles) in world space."""
    _, name, sign, off = inst
    mod = g['modules'][name]
    v = Vector(q[:3])
    if frame == 'face':
        v = FACE @ v
    v = v + Vector(off)
    if sign < 0:
        v.x = -v.x
    if not mod.get('fixed'):
        v = v * g['hulls'][hull]['extent']
    return v


def build_hull(g, hull, stage='S0', mats=None):
    """Create the hull's objects in the current scene; returns {instance: [objects]}."""
    plates_on, removed = stage_geometry(g, hull, stage)
    s = g['hulls'][hull]['extent']
    objs = {}
    for inst in hull_instances(g, hull):
        iid, name, sign, off = inst
        if iid in removed:
            continue
        mod = g['modules'][name]; frame = mod.get('frame', 'ship')
        objs[iid] = []
        for p in mod['prims']:
            if p['tag'] == 'plate' and not plates_on:
                continue
            copies = [1, -1] if p.get('mirror') else [1]
            for cs in copies:
                v, f = prim_world(p, frame)
                if cs < 0:
                    v = mirror_x(v)
                v = [q + Vector(off) for q in v]
                if sign < 0:
                    v = mirror_x(v)
                if not mod.get('fixed'):
                    v = [q * s for q in v]
                nm = '%s.%s%s' % (iid, p['name'], '' if cs > 0 else '.m')
                ob = bpy.data.objects.new(nm, mesh_from(v, f, nm))
                ob['tag'] = p['tag']; ob['inst'] = iid; ob['prim'] = p['name']
                bpy.context.scene.collection.objects.link(ob)
                if mats:
                    ob.data.materials.append(mats[p['tag']])
                objs[iid].append(ob)
    return objs


# ---------------------------------------------------------------- views
def view_basis(pitch, yaw):
    """Camera right, up and back (toward camera) vectors in world space."""
    p = math.radians(pitch)
    right = Vector((1, 0, 0)); up = Vector((0, math.sin(p), math.cos(p))); back = Vector((0, -math.cos(p), math.sin(p)))
    Rinv = Matrix.Rotation(math.radians(-yaw), 3, AXIS_A)  # orbit the camera = turn the hull by +yaw
    return Rinv @ right, Rinv @ up, Rinv @ back


def project(v, basis):
    right, up, _ = basis
    return (v.dot(right), -v.dot(up))  # arena units: x right, y down


def view_tag(pitch, yaw):
    return 'p%02d_y%+03d' % (pitch, yaw)


def all_views(g, which='all'):
    if which == 'hero':
        return [tuple(g['views']['hero'])]
    return [(p, y) for p in g['views']['pitch'] for y in g['views']['yaw']]


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


# ---------------------------------------------------------------- atlas constants
def atlas_constants():
    src = open(ATLAS_DART).read()
    def tup(name):
        m = re.search(r'static const %s = \(([^)]*)\)' % name, src)
        return {k.strip(): float(v) for k, v in (kv.split(':') for kv in m.group(1).split(','))}
    return {'core': tup('coreWindow'), 'bay': tup('bayWindow'), 'turret': tup('turretPivot'), 'body': tup('solidBody')}


# ---------------------------------------------------------------- materials
def make_materials(g):
    mats = {}
    for tag, m in g['materials'].items():
        mat = bpy.data.materials.new('clay_' + tag)
        c = m['clay']; mat.diffuse_color = (c, c, c, 1.0)
        mats[tag] = mat
    return mats


def emission_material(name, build):
    mat = bpy.data.materials.new(name)
    if hasattr(mat, "use_nodes") and not mat.node_tree: mat.use_nodes = True
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


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


# ---------------------------------------------------------------- framing and anchors
def all_verts(objs):
    for lst in objs.values():
        for ob in lst:
            for v in ob.data.vertices:
                yield ob.matrix_world @ v.co


def hull_frame(g, hull, views, ppu):
    """One frame (arena units) for every view and stage: the S0 hull's projected bounds + margin."""
    clear_scene()
    objs = build_hull(g, hull, 'S0')
    verts = list(all_verts(objs))
    x0 = y0 = 1e9; x1 = y1 = -1e9
    for (p, y) in views:
        b = view_basis(p, y)
        for v in verts:
            sx, sy = project(v, b)
            x0, x1, y0, y1 = min(x0, sx), max(x1, sx), min(y0, sy), max(y1, sy)
    m = 6
    x0, y0 = math.floor(x0 - m), math.floor(y0 - m); x1, y1 = math.ceil(x1 + m), math.ceil(y1 + m)
    # whole pixels, even sizes
    w = math.ceil((x1 - x0) * ppu / 2) * 2 / ppu; h = math.ceil((y1 - y0) * ppu / 2) * 2 / ppu
    return (x0, y0, x0 + w, y0 + h), max(v.length for v in verts)


def ray_hit(scene, origin, direction):
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, nrm, idx, ob, mat = scene.ray_cast(dg, origin, direction, distance=DIST * 4)
    return (ob.name if hit else None), (Vector(loc) if hit else None)


def obj_centre(objs_list):
    vs = [ob.matrix_world @ v.co for ob in objs_list for v in ob.data.vertices]
    c = Vector((0, 0, 0))
    for v in vs: c += v
    return c / len(vs)


def gate_view(g, hull, objs, basis, atlas, scene):
    """Functional anchors of one view: projected centres of the maw, bays and turrets, and solid-body coverage."""
    tol = g['anchors']['tolerance']; res = {}; fails = []
    bow = {ob['prim']: ob for ob in objs['bow']}
    want = {'core': (atlas['core']['x'], atlas['core']['y']),
            'bayL': (-atlas['bay']['x'], atlas['bay']['y']), 'bayR': (atlas['bay']['x'], atlas['bay']['y']),
            'turretL': (-atlas['turret']['x'], atlas['turret']['y']), 'turretR': (atlas['turret']['x'], atlas['turret']['y'])}
    prim_of = g['modules']['bow']['anchors']
    right, up, back = basis
    for key, (wx, wy) in want.items():
        ob = bow[prim_of[key]]
        c = obj_centre([ob])
        sx, sy = project(c, basis)
        err = math.hypot(sx - wx, sy - wy)
        # unobstructed: the camera ray through the anchor hits the anchor's own prim (or the bow)
        hit, _ = ray_hit(scene, c + back * DIST, -back)
        clear = hit is not None and hit.startswith('bow.')
        res[key] = {'x': round(sx, 2), 'y': round(sy, 2), 'err': round(err, 2), 'unobstructed': clear, 'hit': hit}
        if err > tol:
            fails.append('%s off by %.2f' % (key, err))
        if not clear:
            fails.append('%s obstructed by %s' % (key, hit))
    # solid body: every inset sample point hits hull geometry
    sb = g['anchors']['solid_body']; ins = sb['inset']
    hw, top, bot = atlas['body']['halfWidth'] - ins, atlas['body']['top'] + ins, atlas['body']['bottom'] - ins
    miss = []
    for i in range(9):
        for j in range(5):
            ax = -hw + 2 * hw * i / 8; ay = top + (bot - top) * j / 4
            o = right * ax - up * ay + back * DIST
            hit, _ = ray_hit(scene, o, -back)
            if hit is None:
                miss.append((round(ax, 1), round(ay, 1)))
    res['solid_body'] = {'samples': 45, 'missed': miss}
    if miss:
        fails.append('solid body not covered at %s' % miss[:4])
    return res, fails


def project_points(g, hull, objs, basis, scene):
    """Lights, fires and nozzles of the present modules, projected, with visibility."""
    out = {'lights': [], 'fires': [], 'nozzles': []}
    insts = {i[0]: i for i in hull_instances(g, hull)}
    _, _, back = basis
    for iid in objs:
        inst = insts[iid]; mod = g['modules'][inst[1]]; frame = mod.get('frame', 'ship')
        for kind in out:
            for q in mod.get(kind, []):
                v = module_point(g, hull, inst, q, frame)
                sx, sy = project(v, basis)
                hit, loc = ray_hit(scene, v + back * DIST, -back)
                vis = loc is not None and (loc - v).length < 3.0
                rec = {'module': iid, 'x': round(sx, 2), 'y': round(sy, 2), 'visible': vis}
                if kind == 'lights': rec['kind'] = q[3]
                if kind == 'nozzles': rec['size'] = q[3]
                out[kind].append(rec)
    return out


# ---------------------------------------------------------------- render
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
    # emission passes run on Cycles (CPU): ~0.4 GB resident against EEVEE's ~1.5 GB
    # software-GL baseline, which kept a hull over the forge's 2 GB budget
    sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False; sc.cycles.use_adaptive_sampling = False
    sc.cycles.pixel_filter_type = 'BOX'; sc.cycles.filter_width = 0.01
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam


def set_override(objs, pick):
    for lst in objs.values():
        for ob in lst:
            ob.data.materials.clear(); ob.data.materials.append(pick(ob))


def render_pass(sc, path, kind, objs, ctx):
    rs = sc.render
    rs.image_settings.color_depth = '8'; rs.image_settings.color_mode = 'RGBA'
    if kind in ('clay', 'id', 'hint'):
        rs.engine = 'BLENDER_WORKBENCH'
        sh = sc.display.shading
        if kind == 'clay':
            sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_cavity = True
            sh.cavity_type = 'BOTH'; sh.show_shadows = False
            sc.display.render_aa = '8'; sc.view_settings.view_transform = 'Standard'
            set_override(objs, lambda ob: ctx['mats'][ob['tag']])
        else:
            sh.light = 'FLAT'; sh.color_type = 'OBJECT'; sh.show_cavity = False; sh.show_shadows = False
            sc.display.render_aa = 'OFF'; sc.view_settings.view_transform = 'Raw'
            for lst in objs.values():
                for ob in lst:
                    if kind == 'id':
                        r, gg, b = ctx['ids'][ob['inst']]
                    else:  # hint mask: white = bright hint, black = dark hint, grey = plain clay
                        hv = ctx['g']['materials'][ob['tag']].get('hint')
                        r = gg = b = {'bright': 1.0, 'dark': 0.0}.get(hv, 0.5)
                    ob.color = (r, gg, b, 1.0)
    else:
        rs.engine = 'CYCLES'
        sc.cycles.samples = 1  # one centre sample per pixel: exact depth / normal values
        sc.view_settings.view_transform = 'Raw'
        if kind == 'depth':
            hint = {'bright': ctx['white'], 'dark': ctx['black']}
            set_override(objs, lambda ob: hint.get(ctx['g']['materials'][ob['tag']].get('hint'), ctx['depth']))
        elif kind == 'z':
            rs.image_settings.color_depth = '16'; rs.image_settings.color_mode = 'RGBA'
            set_override(objs, lambda ob: ctx['zmat'])
        elif kind == 'normal':
            set_override(objs, lambda ob: ctx['normal'])
    rs.filepath = path
    bpy.ops.render.render(write_still=True)


def run_render(g, out, hulls, stages, which, passes, ppu_scale, threads):
    atlas = atlas_constants(); all_fail = []
    for hull in hulls:
        t0 = time.time()
        sc, cam = setup_scene(threads)
        views = all_views(g, which)
        ppu = g['hulls'][hull]['texel'] * ppu_scale
        frame, radius = hull_frame(g, hull, all_views(g, 'all'), ppu)
        sc.render.resolution_x = round((frame[2] - frame[0]) * ppu)
        sc.render.resolution_y = round((frame[3] - frame[1]) * ppu)
        sc.render.resolution_percentage = 100
        near, far = DIST - radius, DIST + radius
        ids = {}
        for inst in hull_instances(g, hull):
            col = g['modules'][inst[1]]['id']
            r, gg, b = hex_rgb(col)
            if inst[2] < 0:  # left of a mirrored pair: darker
                r, gg, b = r * 0.6, gg * 0.6, b * 0.6
            ids[inst[0]] = (round(r, 4), round(gg, 4), round(b, 4))
        ctx = {'g': g, 'mats': make_materials(g), 'ids': ids, 'depth': depth_material(near, far),
               'zmat': depth_material(near, far, 'z'), 'normal': normal_material(),
               'white': const_material('hint_white', 1.0), 'black': const_material('hint_black', 0.0)}
        rig = {'hull': hull, 'title': g['hulls'][hull]['title'], 'extent': g['hulls'][hull]['extent'],
               'ppu': ppu, 'frame': frame, 'size': [sc.render.resolution_x, sc.render.resolution_y],
               'origin_px': [round(-frame[0] * ppu, 3), round(-frame[1] * ppu, 3)],
               'depth': {'near': near, 'far': far, 'map': 'value = 1 - (viewZ - near) / (far - near)'},
               'swerve_axis': list(AXIS_A), 'views': {}, 'modules': {},
               'module_ids': {k: '#%02X%02X%02X' % tuple(round(c * 255) for c in v) for k, v in ids.items()},
               'instances': [{'id': i[0], 'module': i[1], 'mirror': i[2], 'offset': i[3],
                              'detach': g['modules'][i[1]].get('detach'), 'slot': g['modules'][i[1]]['slot'],
                              'mount': g['modules'][i[1]]['mount'], 'gameplay': g['modules'][i[1]]['gameplay']}
                             for i in hull_instances(g, hull)]}
        for stage in stages:
            clear_scene()
            objs = build_hull(g, hull, stage)
            bpy.context.view_layer.update()
            for (p, y) in views:
                basis = view_basis(p, y); place_camera(cam, basis, frame)
                bpy.context.view_layer.update()
                tag = view_tag(p, y); d = os.path.join(out, hull, stage)
                os.makedirs(d, exist_ok=True)
                for kind in passes:
                    if kind == 'z' and (p, y) != tuple(g['views']['hero']):
                        continue
                    render_pass(sc, os.path.join(d, '%s_%s.png' % (kind, tag)), kind, objs, ctx)
                gate, fails = gate_view(g, hull, objs, basis, atlas, sc)
                pts = project_points(g, hull, objs, basis, sc)
                v = rig['views'].setdefault(tag, {'pitch': p, 'yaw': y, 'camera': {
                    'right': [round(c, 6) for c in basis[0]], 'up': [round(c, 6) for c in basis[1]],
                    'back': [round(c, 6) for c in basis[2]]}, 'stages': {}})
                v['stages'][stage] = {'anchors': gate, **pts, 'gate_fail': fails}
                for f in fails:
                    all_fail.append('%s %s %s: %s' % (hull, stage, tag, f))
        with open(os.path.join(out, hull, 'rig.json'), 'w') as fh:
            json.dump(rig, fh, indent=1)
        print('%s: %d stages x %d views in %.1f s' % (hull, len(stages), len(views), time.time() - t0), flush=True)
    return all_fail


# ---------------------------------------------------------------- --check
def run_check(g):
    errs = []; atlas = atlas_constants()
    a = g['anchors']
    if (a['core'][0], a['core'][1]) != (atlas['core']['x'], atlas['core']['y']) or a['bay'][:2] != [atlas['bay']['x'], atlas['bay']['y']]:
        errs.append('grammar anchors disagree with BossAtlas')
    words = [w.lower() for w in g['originality']['forbidden_words']]
    texts = [h['title'] for h in g['hulls'].values()] + list(g['modules'].keys()) + \
            [m.get('notes', '') for m in g['modules'].values()] + \
            [v for k, v in g['prompts'].items() if k != 'negative']
    for t in texts:
        for w in words:
            if re.search(r'\b%s\b' % re.escape(w), t.lower()):
                errs.append('forbidden word %r in %r' % (w, t[:60]))
    sc, cam = setup_scene(8)
    for hull, h in g['hulls'].items():
        insts = hull_instances(g, hull)
        if len(insts) != g['module_counts'][hull]:
            errs.append('%s: %d modules, want %d' % (hull, len(insts), g['module_counts'][hull]))
        if h['extent'] > g['seeded_assembly']['max_extent']:
            errs.append('%s: extent over the limit' % hull)
        clear_scene()
        objs = build_hull(g, hull, 'S0'); bpy.context.view_layer.update()
        # symmetry: the vertex cloud mirrors onto itself
        vs = sorted((round(v.x, 2), round(v.y, 2), round(v.z, 2)) for v in all_verts(objs))
        ms = sorted((round(-v[0], 2), v[1], v[2]) for v in vs)
        bad = sum(1 for p, q in zip(vs, ms) if max(abs(p[i] - q[i]) for i in range(3)) > 0.05)
        if bad:
            errs.append('%s: %d vertices break the mirror symmetry' % (hull, bad))
        # budget: stored views only (yaw -t is the mirror of +t; at yaw 0 a mirrored
        # pair is stored once), every module's bbox at the hull's texel density, RGBA
        ppu = h['texel']; total = 0
        for (p, y) in all_views(g):
            if y < 0:
                continue
            b = view_basis(p, y)
            for iid, lst in objs.items():
                if y == 0 and iid.endswith('L') and iid[:-1] + 'R' in objs:
                    continue
                pts = [project(ob.matrix_world @ v.co, b) for ob in lst for v in ob.data.vertices]
                xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
                area = (max(xs) - min(xs) + 2) * (max(ys) - min(ys) + 2) * ppu * ppu
                stages = 1 + 3 * 0.35  # S0 layer + S1-S3 patches (~35 % of the module each)
                total += area * 4 * stages
        mb = total / (1 << 20)
        h['_budget_mb'] = round(mb, 2)
        # bbox upper bound (no occlusion trim): warn over the budget, fail over 1.4x;
        # the measured gate runs on the rendered id masks (tools/boss_sheet budget)
        if mb > 1.4 * g['seeded_assembly']['budget_mb']:
            errs.append('%s: bbox upper bound %.1f MB RGBA over 1.4 x budget' % (hull, mb))
        elif mb > g['seeded_assembly']['budget_mb']:
            print('WARN %s: bbox upper bound %.1f MB > %.0f MB; measure on the id masks' % (hull, mb, g['seeded_assembly']['budget_mb']))
        # anchors and solid body in every view
        for (p, y) in all_views(g):
            b = view_basis(p, y)
            _, fails = gate_view(g, hull, objs, b, atlas, sc)
            errs += ['%s %s: %s' % (hull, view_tag(p, y), f) for f in fails]
        print('%-14s modules %2d  extent %.2f  bbox bound %.1f MB RGBA (6 stored views, S0 + stage patches)' %
              (hull, len(insts), h['extent'], mb), flush=True)
    return errs


def main(argv):
    g = load_grammar()
    if '--check' in argv:
        errs = run_check(g)
        for e in errs: print('FAIL', e)
        print('check: %s' % ('ok' if not errs else '%d failures' % len(errs)))
        return 1 if errs else 0
    args, opt, i = [], {}, 0
    while i < len(argv):
        if argv[i].startswith('--'):
            opt[argv[i][2:]] = argv[i + 1]; i += 2
        else:
            args.append(argv[i]); i += 1
    out = args[0]
    hulls = opt.get('hulls', ','.join(g['hulls'].keys())).split(',')
    stages = opt.get('stages', 'S0,S2,S3').split(',')
    passes = opt.get('passes', 'clay,hint,depth,normal,id,z').split(',')
    fails = run_render(g, out, hulls, stages, opt.get('views', 'all'), passes,
                       float(opt.get('ppu-scale', 2)), int(opt.get('threads', 8)))
    for f in fails: print('GATE', f)
    print('anchor gate: %s' % ('ok' if not fails else '%d failures' % len(fails)))
    return 2 if fails else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
