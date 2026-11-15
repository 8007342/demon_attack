# rigkit bake: camera-project one picked hero image per stage onto a hull's mesh and render
# the stored views, every instance layer and the wrecks with that texture (the boss B2 bake,
# generalised: family-driven fills, stored views only, border-cropped layer renders).
# Python only because bpy forces it.
#
#   $PY -I tools/rigkit/bake.py FAMILY.json RIG OUT HULL S0=fit.png[,S1=...,S2=...,S3=...]
#        [--views stored|all|hero] [--layers 1] [--wrecks 1] [--samples 6] [--threads 8]
#
# A surface point takes the hero texel at its hero-view position when the hero camera saw it
# (it faces the camera and its depth matches the rig's 16-bit z pass within eps units);
# otherwise the family fill colour of its material under a fixed key light. Positions come
# from object (rest) coordinates, so a tumbling wreck keeps its texture. S1 uses the S0
# geometry; S2 and S3 their own (scales shed, first detach group gone).
#
# Outputs: OUT/<hull>/<stage>/beauty_<view>.png, layer_<inst>_<view>.png (other instances held
# out: the layers recompose the beauty), OUT/<hull>/wreck_<inst>_f<0|1>.png, and with --views
# stored also beauty_<mirror view>.png at the hero pitch for the mirror check.
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
                for iid in objs:
                    if y == 0 and iid.endswith('L') and iid[:-1] + 'R' in objs:
                        continue  # a mirrored pair is stored once at yaw 0
                    for jid, lst in objs.items():
                        for ob in lst: ob.is_holdout = jid != iid
                    set_border(sc, K.module_rect_px(objs[iid], basis, frame, ppu), rig['size'])
                    sc.render.filepath = os.path.join(d, 'layer_%s_%s.png' % (iid, tag))
                    bpy.ops.render.render(write_still=True); n += 1
        for lst in objs.values():
            for ob in lst: ob.is_holdout = False
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
                    set_border(sc, K.module_rect_px(lst, basis, frame, ppu, pad=8), rig['size'])
                    sc.render.filepath = os.path.join(out, hull, 'wreck_%s_f%d.png' % (iid, f))
                    bpy.ops.render.render(write_still=True); n += 1
                for ob in lst: ob.matrix_world = Matrix.Identity(4)
            for l2 in objs.values():
                for ob in l2: ob.hide_render = False
            set_border(sc, None, rig['size'])
        print('%s %s: %d renders so far, %.1f s' % (hull, stage, n, time.time() - t0), flush=True)
    print('bake: %d renders in %.1f s' % (n, time.time() - t0))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
