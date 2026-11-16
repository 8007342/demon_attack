# rigkit bake: camera-project one picked hero image per stage onto a hull's mesh and render
# the stored views, every instance layer and the wrecks with that texture (the boss B2 bake,
# generalised: family-driven fills, stored views only, border-cropped layer renders).
# Python only because bpy forces it.
#
#   $PY -I tools/rigkit/bake.py FAMILY.json RIG OUT HULL S0=fit.png[,S1=...,S2=...,S3=...]
#        [--views stored|all|hero] [--layers 1] [--wrecks 1] [--samples 6] [--threads 8] [--poses 1]
#
# A surface point takes the hero texel at its hero-view position when the hero camera saw it
# (it faces the camera and its depth matches the rig's 16-bit z pass within eps units);
# otherwise the family fill colour of its material under a fixed key light. Positions come
# from object (rest) coordinates, so a tumbling wreck keeps its texture. S1 uses the S0
# geometry; S2 and S3 their own (scales shed, first detach group gone).
#
# Outputs: OUT/<hull>/<stage>/beauty_<view>.png, layer_<inst>_<view>.png (other instances held
# out: the layers recompose the beauty), OUT/<hull>/wreck_<inst>_f<0|1>.png, and with --views
# stored also beauty_<mirror view>.png at the hero pitch for the mirror check. With --poses 1 (an
# articulated family, rigkit.poses) also beauty_<hero view>_<pose>.png for every pose of the S0 stage:
# the parts move with their projected texture, so every pose frame carries the same paint.
import json, math, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Matrix, Vector
import rigkit as K
from rig import opts


def lin(h):
    return tuple(K.srgb_to_lin(c) for c in K.hex_rgb(h))


def bake_material(tag, fill, hero_img, z_img, rig, hero_tag, eps=1.5):
    hv = rig['views'][hero_tag]['camera']
    R, U, Bk = Vector(hv['right']), Vector(hv['up']), Vector(hv['back'])
    x0, y0, x1, y1 = rig['frame']; near, far = rig['depth']['near'], rig['depth']['far']
    mat = bpy.data.materials.new('bake_' + tag)
    if not mat.node_tree:
        mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear(); N = nt.nodes.new; L = nt.links.new
    tc = N('ShaderNodeTexCoord')

    def dot(vec_out, v):
        n = N('ShaderNodeVectorMath'); n.operation = 'DOT_PRODUCT'
        L(vec_out, n.inputs[0]); n.inputs[1].default_value = tuple(v)
        return n.outputs['Value']

    def mnode(op, a, b=None):
        n = N('ShaderNodeMath'); n.operation = op
        for i, x in enumerate((a, b)):
            if x is None: continue
            if isinstance(x, (int, float)): n.inputs[i].default_value = x
            else: L(x, n.inputs[i])
        return n.outputs[0]
    P = tc.outputs['Object']
    sx = dot(P, R); sy = mnode('MULTIPLY', dot(P, U), -1.0)
    u = mnode('DIVIDE', mnode('SUBTRACT', sx, x0), x1 - x0)
    v = mnode('SUBTRACT', 1.0, mnode('DIVIDE', mnode('SUBTRACT', sy, y0), y1 - y0))
    cv = N('ShaderNodeCombineXYZ'); L(u, cv.inputs[0]); L(v, cv.inputs[1])
    tex = N('ShaderNodeTexImage'); tex.image = hero_img; tex.interpolation = 'Closest'; tex.extension = 'CLIP'
    L(cv.outputs[0], tex.inputs['Vector'])
    zt = N('ShaderNodeTexImage'); zt.image = z_img; zt.interpolation = 'Closest'; zt.extension = 'CLIP'
    L(cv.outputs[0], zt.inputs['Vector'])
    e = mnode('SUBTRACT', 1.0, mnode('DIVIDE', mnode('SUBTRACT', mnode('SUBTRACT', K.DIST, dot(P, Bk)), near), far - near))
    tol = eps / (far - near)
    seen_z = mnode('GREATER_THAN', e, mnode('SUBTRACT', zt.outputs['Color'], tol))
    facing = mnode('GREATER_THAN', dot(tc.outputs['Normal'], Bk), 0.08)
    has = mnode('GREATER_THAN', tex.outputs['Alpha'], 0.5)
    seen = mnode('MULTIPLY', mnode('MULTIPLY', seen_z, facing), has)
    key = (-R * 0.45 + U * 0.6 + Bk * 0.65).normalized()
    lam = mnode('MAXIMUM', dot(tc.outputs['Normal'], key), 0.0)
    shade = mnode('ADD', 0.45, mnode('MULTIPLY', lam, 0.75))
    fc = N('ShaderNodeRGB'); fc.outputs[0].default_value = (*lin(fill), 1.0)
    fm = N('ShaderNodeMix'); fm.data_type = 'RGBA'; fm.blend_type = 'MULTIPLY'; fm.inputs['Factor'].default_value = 1.0
    sh = N('ShaderNodeCombineColor'); L(shade, sh.inputs[0]); L(shade, sh.inputs[1]); L(shade, sh.inputs[2])
    L(fc.outputs[0], fm.inputs['A']); L(sh.outputs[0], fm.inputs['B'])
    mix = N('ShaderNodeMix'); mix.data_type = 'RGBA'
    L(seen, mix.inputs['Factor']); L(fm.outputs['Result'], mix.inputs['A']); L(tex.outputs['Color'], mix.inputs['B'])
    em = N('ShaderNodeEmission'); out = N('ShaderNodeOutputMaterial')
    L(mix.outputs['Result'], em.inputs['Color']); L(em.outputs[0], out.inputs['Surface'])
    return mat


def load_image(path, non_color=False):
    img = bpy.data.images.load(path, check_existing=False)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'
    return img


def set_border(sc, rect, size):
    if rect is None:
        sc.render.use_border = False; return
    W, H = size
    x0, y0, x1, y1 = rect
    sc.render.use_border = True; sc.render.use_crop_to_border = False
    sc.render.border_min_x = max(0.0, x0 / W); sc.render.border_max_x = min(1.0, x1 / W)
    sc.render.border_min_y = max(0.0, 1 - y1 / H); sc.render.border_max_y = min(1.0, 1 - y0 / H)


def render_layers(sc, objs, ids, basis, frame, ppu, size, d, prefix, tag, under):
    """Per instance: PREFIX_<id>_<tag>.png with every other instance held out (the visible part),
    and with under, under_PREFIX_<id>_<tag>.png: the instance alone (its whole silhouette, one
    sample), so rigsheet can under-paint the texels its neighbours cover (carrier-v3 §2.5)."""
    n = 0; W, H = size; samples = sc.cycles.samples
    for iid in ids:
        rect = K.module_rect_px(objs[iid], basis, frame, ppu)
        if rect is None or rect[0] >= W - 2 or rect[1] >= H - 2 or rect[2] <= 2 or rect[3] <= 2:
            continue  # the module is outside the visible envelope in this view
        set_border(sc, rect, size)
        for jid, lst in objs.items():
            for ob in lst: ob.is_holdout = jid != iid
        sc.render.filepath = os.path.join(d, '%s_%s_%s.png' % (prefix, iid, tag))
        bpy.ops.render.render(write_still=True); n += 1
        if under:
            for jid, lst in objs.items():
                for ob in lst: ob.is_holdout = False; ob.hide_render = jid != iid
            sc.cycles.samples = 1
            sc.render.filepath = os.path.join(d, 'under_%s_%s_%s.png' % (prefix, iid, tag))
            bpy.ops.render.render(write_still=True); n += 1
            sc.cycles.samples = samples
            for lst in objs.values():
                for ob in lst: ob.hide_render = False
    for lst in objs.values():
        for ob in lst: ob.is_holdout = False
    set_border(sc, None, size)
    return n


def heights(g, objs, basis, path, frame, step=20.0):
    """carrier-v3 §2.2: each instance's height grid at the hero view: the ship-frame z (height above
    the hull's reference plane, units) of its own first surface along the view ray, at the nodes of
    the hull-local STEP lattice over its projected rect (+ 12 units of under-paint); misses take
    the nearest hit (rings), so the bend never tears inside the sprite."""
    from mathutils.bvhtree import BVHTree
    right, up, back = basis; out = {'step': step, 'layers': {}}
    for iid, lst in objs.items():
        vs, fs = [], []
        for ob in lst:
            b = len(vs); vs += [ob.matrix_world @ v.co for v in ob.data.vertices]
            fs += [tuple(b + k for k in pl.vertices) for pl in ob.data.polygons]
        if not vs:
            continue
        bvh = BVHTree.FromPolygons([tuple(v) for v in vs], fs)
        xs = [v.dot(right) for v in vs]; ys = [-v.dot(up) for v in vs]
        x0 = math.floor((max(min(xs), frame[0]) - 12) / step) * step; x1 = math.ceil((min(max(xs), frame[2]) + 12) / step) * step
        y0 = math.floor((max(min(ys), frame[1]) - 12) / step) * step; y1 = math.ceil((min(max(ys), frame[3]) + 12) / step) * step
        nx, ny = int(round((x1 - x0) / step)) + 1, int(round((y1 - y0) / step)) + 1
        grid = [None] * (nx * ny)
        for j in range(ny):
            for i in range(nx):
                sx, sy = x0 + i * step, y0 + j * step
                o = right * sx - up * sy + back * K.DIST
                hit = bvh.ray_cast(o, -back, K.DIST * 3)
                if hit[0] is not None:
                    grid[j * nx + i] = hit[0].z
        known = [k for k, v in enumerate(grid) if v is not None]
        if not known:
            continue
        while any(v is None for v in grid):
            nxt = list(grid)
            for k, v in enumerate(grid):
                if v is not None:
                    continue
                i, j = k % nx, k // nx
                nb = [grid[jj * nx + ii] for ii, jj in ((i - 1, j), (i + 1, j), (i, j - 1), (i, j + 1))
                      if 0 <= ii < nx and 0 <= jj < ny and grid[jj * nx + ii] is not None]
                if nb:
                    nxt[k] = sum(nb) / len(nb)
            grid = nxt
        out['layers'][iid] = {'x0': x0, 'y0': y0, 'w': nx, 'h': ny, 'z': [int(round(v)) for v in grid]}
    with open(path, 'w') as fh:
        json.dump(out, fh)


def main(argv):
    args, opt = opts(argv)
    g = K.load_family(args[0])
    rig_dir, out, hull = args[1], args[2], args[3]
    heroes = dict(kv.split('=') for kv in args[4].split(','))
    rig = json.load(open(os.path.join(rig_dir, hull, 'rig.json')))
    threads = int(opt.get('threads', 8))
    t0 = time.time()
    sc, cam = K.setup_scene(threads)
    sc.render.engine = 'CYCLES'; sc.cycles.samples = int(opt.get('samples', 6))
    sc.cycles.pixel_filter_type = 'BLACKMAN_HARRIS'; sc.cycles.filter_width = 1.2
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = rig['size']; sc.render.resolution_percentage = 100
    frame, ppu = rig['frame'], rig['ppu']
    hero = tuple(g['views']['hero']); hero_tag = K.view_tag(*hero)
    which = opt.get('views', 'stored')
    views = K.all_views(g, which)
    extra = [(hero[0], -y) for y in g['views'].get('stored_yaw', []) if y > 0] if which == 'stored' else []
    stages = [s for s in ('S0', 'S1', 'S2', 'S3') if s in heroes]
    wreck_stage = 'S2' if 'S2' in heroes else 'S0'
    insts = {i['id']: i for i in K.instances(g, hull)}
    under = opt.get('under', '1') == '1'
    n = 0
    for stage in stages:
        geo = 'S0' if stage == 'S1' else stage
        K.clear_scene()
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        objs = K.build_hull(g, hull, geo)
        himg = load_image(os.path.abspath(heroes[stage]))
        z = load_image(os.path.join(os.path.abspath(rig_dir), hull, geo, 'z_%s.png' % hero_tag), non_color=True)
        mats = {tag: bake_material(tag, m.get('fill', '#808080'), himg, z, rig, hero_tag) for tag, m in g['materials'].items()}
        K.set_override(objs, lambda ob: mats[ob['tag']])
        d = os.path.join(out, hull, stage); os.makedirs(d, exist_ok=True)
        for (p, y) in views + (extra if stage == 'S0' else []):
            basis = K.view_basis(g, p, y); K.place_camera(cam, basis, frame)
            tag = K.view_tag(p, y)
            for lst in objs.values():
                for ob in lst: ob.is_holdout = False
            set_border(sc, None, rig['size'])
            sc.render.filepath = os.path.join(d, 'beauty_%s.png' % tag)
            bpy.ops.render.render(write_still=True); n += 1
            if opt.get('layers', '1') == '1' and (p, y) not in extra:
                ids = [iid for iid in objs if not (y == 0 and iid.endswith('L') and iid[:-1] + 'R' in objs)]
                n += render_layers(sc, objs, ids, basis, frame, ppu, rig['size'], d, 'layer', tag, under)
            if stage != 'S1' and (p, y) == hero and K.door_insts(objs):
                # carrier-v3 gates: the open state of every door instance (the runtime blends the two)
                K.set_doors(objs, 'open')
                ids = [iid for iid in K.door_insts(objs) if not (iid.endswith('L') and iid[:-1] + 'R' in objs)]
                n += render_layers(sc, objs, ids, basis, frame, ppu, rig['size'], d, 'door', tag, under)
                K.set_doors(objs, 'closed')
            if stage == 'S0' and (p, y) == hero:
                heights(g, objs, basis, os.path.join(out, hull, 'heights.json'), frame)
        for lst in objs.values():
            for ob in lst: ob.is_holdout = False
        if opt.get('poses') == '1' and stage == 'S0' and g.get('articulation'):
            basis = K.view_basis(g, *hero); K.place_camera(cam, basis, frame); set_border(sc, None, rig['size'])
            for pose in K.poses(g):
                K.apply_pose(g, objs, hull, pose)
                sc.render.filepath = os.path.join(d, 'beauty_%s_%s.png' % (hero_tag, pose[0]))
                bpy.ops.render.render(write_still=True); n += 1
            K.apply_pose(g, objs, hull, K.poses(g)[0])
        if opt.get('wrecks', '1') == '1' and stage == wreck_stage:
            basis = K.view_basis(g, *hero); K.place_camera(cam, basis, frame)
            for iid, lst in objs.items():
                w = insts[iid]['def'].get('wreck', True)
                if w is not True:
                    continue  # 'layer': the runtime sinks the module's own S3 layer
                if iid.endswith('R') and iid[:-1] + 'L' in objs:
                    continue  # a mirrored pair stores the L wreck; R draws it flipped
                c = K.obj_centre(lst)
                for jid, l2 in objs.items():
                    for ob in l2: ob.hide_render = jid != iid
                for f, rot in enumerate(((0, 0, 0), (24, -10, 18))):
                    Rm = (Matrix.Translation(c) @ Matrix.Rotation(math.radians(rot[2]), 4, 'Z') @
                          Matrix.Rotation(math.radians(rot[1]), 4, 'Y') @ Matrix.Rotation(math.radians(rot[0]), 4, 'X') @
                          Matrix.Translation(-c))
                    for ob in lst: ob.matrix_world = Rm
                    bpy.context.view_layer.update()
                    # its own frame, never clipped by the envelope (the wreck tumbles into view)
                    xs = [(ob.matrix_world @ v.co).dot(basis[0]) for ob in lst for v in ob.data.vertices]
                    ys = [-(ob.matrix_world @ v.co).dot(basis[1]) for ob in lst for v in ob.data.vertices]
                    m = g.get('render', {}).get('margin', 6)
                    wf = (math.floor(min(xs) - m), math.floor(min(ys) - m), math.ceil(max(xs) + m), math.ceil(max(ys) + m))
                    sc.render.resolution_x = round((wf[2] - wf[0]) * ppu); sc.render.resolution_y = round((wf[3] - wf[1]) * ppu)
                    wf = (wf[0], wf[1], wf[0] + sc.render.resolution_x / ppu, wf[1] + sc.render.resolution_y / ppu)
                    K.place_camera(cam, basis, wf); set_border(sc, None, rig['size'])
                    sc.render.filepath = os.path.join(out, hull, 'wreck_%s_f%d.png' % (iid, f))
                    bpy.ops.render.render(write_still=True); n += 1
                    with open(os.path.join(out, hull, 'wreck_%s_f%d.json' % (iid, f)), 'w') as fh:
                        json.dump({'frame': wf}, fh)
                    sc.render.resolution_x, sc.render.resolution_y = rig['size']; K.place_camera(cam, basis, frame)
                for ob in lst: ob.matrix_world = Matrix.Identity(4)
            for l2 in objs.values():
                for ob in l2: ob.hide_render = False
            set_border(sc, None, rig['size'])
        print('%s %s: %d renders so far, %.1f s' % (hull, stage, n, time.time() - t0), flush=True)
    print('bake: %d renders in %.1f s' % (n, time.time() - t0))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
