# boss-hero-assets task 4.1 (and the geometry half of 4.2): projection bake.
# Python only because bpy forces it.
#
#   $PY -I tools/boss_rig/project_bake.py RIG OUT HULL S0=hero_fit.png[,S2=...,S3=...]
#        [--views all|hero] [--layers 1] [--wrecks 1] [--threads 8]
#
# The picked hero (fitted to the rig frame by `boss_sheet finish`, *-fit.png) is
# camera-projected from the hero view (pitch 45, yaw 0) onto the hull mesh.
# Every other view, every module layer and every wreck is rendered with that
# texture, so materials are identical across the view set by construction.
# A surface point takes the hero texel at its hero-view position when the hero
# saw it: it faces the hero camera and its hero-view depth matches the hero z
# pass (rendered by build.py) within 1.5 units. Otherwise it takes a clay-tinted
# fill: the family colour of its material class under a fixed key light.
# Positions come from object coordinates (the rest pose), so a tumbling wreck
# keeps its texture. Stage S1 (scorch) uses the S0 geometry with its own image;
# S2 and S3 use their geometry (plates off, first module gone) and image (or
# the S0 image when no stage image is given).
#
# Outputs: OUT/<hull>/<stage>/beauty_<view>.png, layer_<inst>_<view>.png
# (other modules held out: the layers recompose the beauty exactly) and
# OUT/<hull>/wreck_<inst>_f<0|1>.png (module alone, hero view, tumbled).
import json, math, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Matrix, Vector
import build as B

FILL = {'hull': '#463C52', 'plate': '#5E526B', 'rib': '#683C88', 'bone': '#D8C69A', 'membrane': '#221D2A',
        'metal': '#322A3C', 'dark': '#0A0716', 'eye': '#FF8A2A', 'light': '#FFC85A'}


def lin(h):
    return tuple(B.srgb_to_lin(c) for c in B.hex_rgb(h))


def bake_material(tag, hero_img, z_img, rig, eps=1.5):
    """Emission: hero texel where the hero view saw the point, else the fill colour lit by a key light."""
    hv = rig['views']['p45_y+00']['camera']
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
    def math_node(op, a, b=None):
        n = N('ShaderNodeMath'); n.operation = op
        for i, x in enumerate((a, b)):
            if x is None: continue
            if isinstance(x, (int, float)): n.inputs[i].default_value = x
            else: L(x, n.inputs[i])
        return n.outputs[0]
    P = tc.outputs['Object']
    sx = dot(P, R); sy = math_node('MULTIPLY', dot(P, U), -1.0)
    u = math_node('DIVIDE', math_node('SUBTRACT', sx, x0), x1 - x0)
    v = math_node('SUBTRACT', 1.0, math_node('DIVIDE', math_node('SUBTRACT', sy, y0), y1 - y0))
    cv = N('ShaderNodeCombineXYZ'); L(u, cv.inputs[0]); L(v, cv.inputs[1])
    tex = N('ShaderNodeTexImage'); tex.image = hero_img; tex.interpolation = 'Closest'; tex.extension = 'CLIP'
    L(cv.outputs[0], tex.inputs['Vector'])
    zt = N('ShaderNodeTexImage'); zt.image = z_img; zt.interpolation = 'Closest'; zt.extension = 'CLIP'
    L(cv.outputs[0], zt.inputs['Vector'])
    # expected z value of this point in the hero view: 1 - (DIST - P.back - near) / (far - near)
    e = math_node('SUBTRACT', 1.0, math_node('DIVIDE', math_node('SUBTRACT', math_node('SUBTRACT', B.DIST, dot(P, Bk)), near), far - near))
    tol = eps / (far - near)
    seen_z = math_node('GREATER_THAN', e, math_node('SUBTRACT', zt.outputs['Color'], tol))
    facing = math_node('GREATER_THAN', dot(tc.outputs['Normal'], Bk), 0.08)
    has = math_node('GREATER_THAN', tex.outputs['Alpha'], 0.5)
    seen = math_node('MULTIPLY', math_node('MULTIPLY', seen_z, facing), has)
    # fill: family colour x (ambient + key light), key from the hero view's upper left
    key = (-R * 0.45 + U * 0.6 + Bk * 0.65).normalized()
    lam = math_node('MAXIMUM', dot(tc.outputs['Normal'], key), 0.0)
    shade = math_node('ADD', 0.45, math_node('MULTIPLY', lam, 0.75))
    fc = N('ShaderNodeRGB'); fc.outputs[0].default_value = (*lin(FILL[tag]), 1.0)
    fm = N('ShaderNodeMix'); fm.data_type = 'RGBA'; fm.blend_type = 'MULTIPLY'
    fm.inputs['Factor'].default_value = 1.0
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


def main(argv):
    args, opt, i = [], {}, 0
    while i < len(argv):
        if argv[i].startswith('--'):
            opt[argv[i][2:]] = argv[i + 1]; i += 2
        else:
            args.append(argv[i]); i += 1
    rig_dir, out, hull, heroes = args[0], args[1], args[2], dict(kv.split('=') for kv in args[3].split(','))
    g = B.load_grammar()
    rig = json.load(open(os.path.join(rig_dir, hull, 'rig.json')))
    threads = int(opt.get('threads', 8))
    t0 = time.time()
    sc, cam = B.setup_scene(threads)
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 9
    sc.cycles.pixel_filter_type = 'BLACKMAN_HARRIS'; sc.cycles.filter_width = 1.2
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = rig['size']; sc.render.resolution_percentage = 100
    frame = rig['frame']
    views = B.all_views(g, opt.get('views', 'all'))
    stages = [s for s in ('S0', 'S1', 'S2', 'S3') if s in heroes]
    n = 0
    for stage in stages:
        geo_stage = 'S0' if stage == 'S1' else stage
        B.clear_scene()
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        objs = B.build_hull(g, hull, geo_stage)
        hero = load_image(os.path.abspath(heroes[stage]))
        z = load_image(os.path.join(os.path.abspath(rig_dir), hull, geo_stage, 'z_p45_y+00.png'), non_color=True)
        mats = {tag: bake_material(tag, hero, z, rig) for tag in g['materials']}
        B.set_override(objs, lambda ob: mats[ob['tag']])
        d = os.path.join(out, hull, stage); os.makedirs(d, exist_ok=True)
        for (p, y) in views:
            basis = B.view_basis(p, y); B.place_camera(cam, basis, frame)
            tag = B.view_tag(p, y)
            for lst in objs.values():
                for ob in lst: ob.is_holdout = False
            sc.render.filepath = os.path.join(d, 'beauty_%s.png' % tag)
            bpy.ops.render.render(write_still=True); n += 1
            if opt.get('layers', '1') == '1':
                for iid in objs:
                    for jid, lst in objs.items():
                        for ob in lst: ob.is_holdout = jid != iid
                    sc.render.filepath = os.path.join(d, 'layer_%s_%s.png' % (iid, tag))
                    bpy.ops.render.render(write_still=True); n += 1
        for lst in objs.values():
            for ob in lst: ob.is_holdout = False
        # wrecks: each module alone at the hero view, rest pose and tumbled (S2 look: plates already blown)
        if opt.get('wrecks', '1') == '1' and stage == ('S2' if 'S2' in heroes else 'S0'):
            basis = B.view_basis(45, 0); B.place_camera(cam, basis, frame)
            for iid, lst in objs.items():
                if g['modules'][[i for i in B.hull_instances(g, hull) if i[0] == iid][0][1]].get('fixed') and iid != 'bow':
                    continue
                c = B.obj_centre(lst)
                for jid, l2 in objs.items():
                    for ob in l2: ob.hide_render = jid != iid
                for f, rot in enumerate(((0, 0, 0), (24, -10, 18))):
                    Rm = (Matrix.Translation(c) @ Matrix.Rotation(math.radians(rot[2]), 4, 'Z') @
                          Matrix.Rotation(math.radians(rot[1]), 4, 'Y') @ Matrix.Rotation(math.radians(rot[0]), 4, 'X') @
                          Matrix.Translation(-c))
                    for ob in lst: ob.matrix_world = Rm
                    sc.render.filepath = os.path.join(out, hull, 'wreck_%s_f%d.png' % (iid, f))
                    bpy.ops.render.render(write_still=True); n += 1
                for ob in lst: ob.matrix_world = Matrix.Identity(4)
            for l2 in objs.values():
                for ob in l2: ob.hide_render = False
        print('%s %s: %d renders so far, %.1f s' % (hull, stage, n, time.time() - t0), flush=True)
    print('bake: %d renders in %.1f s' % (n, time.time() - t0))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
