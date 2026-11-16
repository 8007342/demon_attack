# rigkit rig: build a family's hulls in headless Blender and render the control passes.
#
#   PY=$(lua tools/boss_rig/setup_bpy.lua)
#   $PY -I tools/rigkit/rig.py FAMILY.json --check [--hulls a,b]      grammar gate, no renders
#   $PY -I tools/rigkit/rig.py FAMILY.json OUT [--hulls a,b] [--stages S0,S2,S3] [--views all|stored|hero]
#                                   [--passes clay,hint,depth,normal,id,z] [--threads 8] [--envelope off]
#                                   [--pose-passes clay,hint]
#
# Per hull, view and stage: clay (Workbench, studio light + cavity), hint (flat hint colours:
# family materials with a "hint"), depth (near = white), normal (camera space), id (flat
# instance colours, no AA), z (16-bit depth at the hero view, for the projection bake).
# OUT/<hull>/rig.json: the frame, render density, cameras, instances (slot, set, texel class,
# detach), the poses of an articulated family (rigkit.poses; --pose-passes renders those passes per
# pose at the hero view as <kind>_<view>_<pose>.png in S0), the projected anchors, lights, fires and nozzles per view and stage, the overlay
# the sheets draw (family anchors.overlay), and the gate results. Exit 2 when the gate fails.
import json, math, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import rigkit as K


def opts(argv):
    args, opt, i = [], {}, 0
    while i < len(argv):
        if argv[i].startswith('--'):
            if i + 1 < len(argv) and not argv[i + 1].startswith('--'):
                opt[argv[i][2:]] = argv[i + 1]; i += 2
            else:
                opt[argv[i][2:]] = '1'; i += 1
        else:
            args.append(argv[i]); i += 1
    return args, opt


def instance_ids(g, hull):
    """Flat id colours: the slot colour, darker for the left of a mirrored pair, shifted by suffix."""
    ids = {}
    for n, inst in enumerate(K.instances(g, hull)):
        r, gg, b = K.hex_rgb(inst['def']['id'])
        if inst['sign'] < 0:
            r, gg, b = r * 0.6, gg * 0.6, b * 0.6
        if '_' in inst['id']:
            r, gg, b = 1 - r * 0.8, gg * 0.8, b * 0.8 + 0.1
        ids[inst['id']] = (round(r, 4), round(gg, 4), round(b, 4))
    return ids


def verify_dart(g):
    """Optional: the family's anchor targets must equal constants in a Dart source."""
    vd = g.get('anchors', {}).get('verify_dart')
    if not vd:
        return []
    src = open(os.path.join(K.ROOT, vd['file'])).read(); errs = []
    for name, (const, kx, ky, sx) in vd['points'].items():
        m = re.search(r'static const %s = \(([^)]*)\)' % const, src)
        if not m:
            errs.append('verify_dart: %s missing' % const); continue
        d = {k.strip(): float(v) for k, v in (kv.split(':') for kv in m.group(1).split(','))}
        pt = next((p for p in g['anchors']['points'] if p['name'] == name), None)
        want = (sx * d[kx], d[ky])
        if pt is None or abs(pt['at'][0] - want[0]) > 1e-6 or abs(pt['at'][1] - want[1]) > 1e-6:
            errs.append('verify_dart: anchor %s != %s %s' % (name, const, want))
    return errs


def run_check(g, hulls):
    errs = verify_dart(g)
    words = [w.lower() for w in g.get('originality', {}).get('forbidden_words', [])]
    texts = [h['title'] for h in g['hulls'].values()] + list(g['slots'].keys()) + \
            [s for sl in g['slots'].values() for s in sl.get('sets', {}).keys()] + \
            [sl.get('notes', '') for sl in g['slots'].values()] + \
            [v for k, v in g.get('prompts', {}).items() if not k.startswith('negative') and isinstance(v, str)]
    for t in texts:
        for w in words:
            if re.search(r'\b%s\b' % re.escape(w), t.lower()):
                errs.append('forbidden word %r in %r' % (w, t[:60]))
    sc, cam = K.setup_scene(8)
    for hull in hulls:
        h = g['hulls'][hull]; t0 = time.time()
        insts = K.instances(g, hull)
        want = h.get('module_count')
        if want is not None and len(insts) != want:
            errs.append('%s: %d instances, want %d' % (hull, len(insts), want))
        K.clear_scene()
        objs = K.build_hull(g, hull, 'S0'); bpy.context.view_layer.update()
        nv = sum(len(ob.data.vertices) for l in objs.values() for ob in l)
        if g.get('symmetric', True):
            from mathutils.kdtree import KDTree
            vs = list(K.all_verts(objs)); kd = KDTree(len(vs))
            for n, v in enumerate(vs): kd.insert(v, n)
            kd.balance()
            bad = sum(1 for v in vs if kd.find(v * 1 - 2 * v.x * K.Vector((1, 0, 0)))[2] > 0.5)
            if bad:
                errs.append('%s: %d of %d vertices break the mirror symmetry' % (hull, bad, len(vs)))
        for (p, y) in K.all_views(g):
            _, fails = K.gate_view(g, objs, K.view_basis(g, p, y), sc)
            errs += ['%s %s: %s' % (hull, K.view_tag(p, y), f) for f in fails]
        print('%-22s instances %2d  verts %7d  %.1f s' % (hull, len(insts), nv, time.time() - t0), flush=True)
    return errs


def run_render(g, out, hulls, stages, which, passes, threads, pose_passes=()):
    all_fail = []
    rcfg = g.get('render', {})
    for hull in hulls:
        t0 = time.time()
        sc, cam = K.setup_scene(threads)
        h = g['hulls'][hull]
        tex = h['texel']  # {class: px per unit} of the finished atlas
        ppu = max(tex.values()) * rcfg.get('scale', 2)
        K.clear_scene()
        objs0 = K.build_hull(g, hull, 'S0'); bpy.context.view_layer.update()
        frame, radius = K.hull_frame(g, objs0, K.all_views(g, 'belly' if which == 'belly' else 'all'), ppu, hull)
        sc.render.resolution_x = round((frame[2] - frame[0]) * ppu)
        sc.render.resolution_y = round((frame[3] - frame[1]) * ppu)
        sc.render.resolution_percentage = 100
        near, far = K.DIST - radius, K.DIST + radius
        ids = instance_ids(g, hull)
        ctx = {'g': g, 'mats': K.clay_materials(g), 'ids': ids, 'depth': K.depth_material(near, far),
               'zmat': K.depth_material(near, far, 'z'), 'normal': K.normal_material()}
        insts = K.instances(g, hull)
        rig = {'schema': 'demon-attack.rig/v2', 'family': g['_path'], 'hull': hull, 'title': h['title'],
               'tour': h.get('tour'), 'extent': h.get('extent', 1.0), 'ppu': ppu, 'render_scale': rcfg.get('scale', 2),
               'texel': tex, 'frame': frame, 'size': [sc.render.resolution_x, sc.render.resolution_y],
               'origin_px': [round(-frame[0] * ppu, 3), round(-frame[1] * ppu, 3)],
               'envelope': rcfg.get('envelope'),
               'depth': {'near': near, 'far': far, 'map': 'value = 1 - (viewZ - near) / (far - near)'},
               'swerve_axis': list(K.swerve_axis(g)), 'views': {}, 'overlay': g.get('anchors', {}).get('overlay', []),
               'module_ids': {k: '#%02X%02X%02X' % tuple(round(c * 255) for c in v) for k, v in ids.items()},
               'instances': [{'id': i['id'], 'module': i['module'], 'slot': i['slot'], 'set': i['set'],
                              'mirror': i['sign'], 'offset': i['offset'], 'detach': i['def'].get('detach'),
                              'mount': i['def'].get('mount'), 'gameplay': i['def'].get('gameplay', 'none'),
                              'texel_class': i['def'].get('texel', 'mass'),
                              'texel': tex[i['def'].get('texel', 'mass')], 'wreck': i['def'].get('wreck', True)}
                             for i in insts],
               'poses': [{'id': p[0], 'dir': p[1], 'tilt': p[2]} for p in K.poses(g)] if g.get('articulation') else [],
               'stages': {s: {'shed': sorted(K.stage_plan(g, hull, s)[0]), 'removed': sorted(K.stage_plan(g, hull, s)[1])}
                          for s in g['stages']}}
        for stage in stages:
            K.clear_scene()
            objs = K.build_hull(g, hull, stage)
            bpy.context.view_layer.update()
            for (p, y) in K.all_views(g, which):
                basis = K.view_basis(g, p, y); K.place_camera(cam, basis, frame)
                bpy.context.view_layer.update()
                tag = K.view_tag(p, y); d = os.path.join(out, hull, stage)
                os.makedirs(d, exist_ok=True)
                for kind in passes:
                    if kind == 'z' and (p, y) != tuple(g['views']['hero']):
                        continue
                    K.render_pass(sc, os.path.join(d, '%s_%s.png' % (kind, tag)), kind, objs, ctx)
                gate, fails = K.gate_view(g, objs, basis, sc) if which != 'belly' else ({}, [])
                pts = K.project_points(g, hull, objs, basis, sc)
                v = rig['views'].setdefault(tag, {'pitch': p, 'yaw': y, 'camera': {
                    'right': [round(c, 6) for c in basis[0]], 'up': [round(c, 6) for c in basis[1]],
                    'back': [round(c, 6) for c in basis[2]]}, 'stages': {}})
                v['stages'][stage] = {'anchors': gate, **pts, 'gate_fail': fails}
                all_fail += ['%s %s %s: %s' % (hull, stage, tag, f) for f in fails]
            if stage == 'S0' and pose_passes and g.get('articulation'):
                hv = tuple(g['views']['hero']); basis = K.view_basis(g, *hv); K.place_camera(cam, basis, frame)
                d = os.path.join(out, hull, stage)
                for pose in K.poses(g):
                    K.apply_pose(g, objs, hull, pose)
                    for kind in pose_passes:
                        K.render_pass(sc, os.path.join(d, '%s_%s_%s.png' % (kind, K.view_tag(*hv), pose[0])), kind, objs, ctx)
                K.apply_pose(g, objs, hull, K.poses(g)[0])
            print('%s %s: %.1f s' % (hull, stage, time.time() - t0), flush=True)
        with open(os.path.join(out, hull, 'rig.json'), 'w') as fh:
            json.dump(rig, fh, indent=1)
        print('%s: %d stages in %.1f s, %dx%d px' % (hull, len(stages), time.time() - t0, *rig['size']), flush=True)
    return all_fail


def main(argv):
    args, opt = opts(argv)
    g = K.load_family(args[0])
    hulls = opt['hulls'].split(',') if 'hulls' in opt else list(g['hulls'].keys())
    if 'check' in opt:
        errs = run_check(g, hulls)
        for e in errs: print('FAIL', e)
        print('check: %s' % ('ok' if not errs else '%d failures' % len(errs)))
        return 1 if errs else 0
    if opt.get('envelope') == 'off':  # full plan renders (lineups), never for the atlas
        g.setdefault('render', {}).pop('envelope', None)
    stages = opt.get('stages', 'S0,S2,S3').split(',')
    passes = opt.get('passes', 'clay,hint,depth,normal,id,z').split(',')
    pp = [p for p in opt.get('pose-passes', '').split(',') if p]
    fails = run_render(g, args[1], hulls, stages, opt.get('views', 'all'), passes, int(opt.get('threads', 8)), pp)
    for f in fails: print('GATE', f)
    print('anchor gate: %s' % ('ok' if not fails else '%d failures' % len(fails)))
    return 2 if fails else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
