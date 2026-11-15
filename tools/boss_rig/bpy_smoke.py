# Smoke test for the boss-hero-assets route (openspec/changes/boss-hero-assets):
# headless Blender as the `bpy` wheel (no blender binary in the forge) renders a
# primitive boss blockout at 3 pitches x 3 yaws, clay (Workbench) and depth
# (EEVEE emission of camera distance, Raw view: macron.dev's trick).
#
#   uv python install 3.13
#   uv venv --python 3.13 ~/.cache/tillandsias-project/bpy-venv
#   VIRTUAL_ENV=~/.cache/tillandsias-project/bpy-venv uv pip install bpy==5.3.0
#   ~/.cache/tillandsias-project/bpy-venv/bin/python -I tools/boss_rig/bpy_smoke.py OUT_DIR [SIZE]
#
# 2026-11-15: 18 renders at 384 px in 47 s on 20 CPU cores; sheet
# art/contact/boss-hero-bpy-smoke.png (rows: pitch 38/45/52; clay then depth
# at yaw -14/0/+14). Python only because bpy forces it.
import bpy, math, sys, os
out = sys.argv[1]; size = int(sys.argv[2]) if len(sys.argv) > 2 else 384
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
def add(kind, loc, scale, rot=(0,0,0), name=None):
    getattr(bpy.ops.mesh, 'primitive_%s_add' % kind)(location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = scale
    if name: o.name = name
    return o
# hull: a long wedge body, a dorsal tower, two wing pylons, engine pods, mandibles
add('cube', (0,0,0), (1.0,3.0,0.35), name='hull')
add('cone', (0,3.4,0), (0.9,0.9,1.0), rot=(math.radians(-90),0,0), name='bow')
add('cube', (0,-0.8,0.6), (0.45,1.0,0.35), name='tower')
add('cube', (0,-0.9,1.05), (0.2,0.5,0.2), name='bridge')
for s in (-1,1):
    add('cube', (s*2.0,-0.6,0), (1.2,0.9,0.12), rot=(0,s*math.radians(-12),0), name='pylon')
    add('cylinder', (s*1.1,-3.2,0), (0.35,0.35,0.6), rot=(math.radians(90),0,0), name='engine')
    add('cone', (s*0.5,4.1,-0.1), (0.12,0.12,0.9), rot=(math.radians(-80),0,s*math.radians(12)), name='mandible')
    add('uv_sphere', (s*0.7,0.8,-0.45), (0.3,0.3,0.3), name='turret')
cam_data = bpy.data.cameras.new('cam'); cam_data.lens = 70
cam = bpy.data.objects.new('cam', cam_data); sc.collection.objects.link(cam); sc.camera = cam
sc.render.resolution_x = sc.render.resolution_y = size
sc.render.film_transparent = True
def aim(yaw, pitch, dist=16):
    # camera above and in front of the ship (the player looks up the screen
    # at a ship flying toward the bottom): pitch = elevation above the hull plane
    y, p = math.radians(yaw), math.radians(pitch)
    cam.location = (dist*math.cos(p)*math.sin(y), dist*math.cos(p)*math.cos(y)*-1+0, dist*math.sin(p))
    d = -cam.location.normalized() if hasattr(cam.location,'normalized') else None
    from mathutils import Vector
    cam.rotation_euler = (Vector((0,0,0)) - cam.location).to_track_quat('-Z','Y').to_euler()
# depth material (macron.dev's trick: emission of camera distance, Raw view)
mat = bpy.data.materials.new('depth'); mat.use_nodes = True
nt = mat.node_tree; nt.nodes.clear()
cd = nt.nodes.new('ShaderNodeCameraData'); mr = nt.nodes.new('ShaderNodeMapRange')
mr.inputs['From Min'].default_value = 11; mr.inputs['From Max'].default_value = 21
mr.inputs['To Min'].default_value = 1; mr.inputs['To Max'].default_value = 0
em = nt.nodes.new('ShaderNodeEmission'); oo = nt.nodes.new('ShaderNodeOutputMaterial')
nt.links.new(cd.outputs['View Distance'], mr.inputs['Value'])
nt.links.new(mr.outputs['Result'], em.inputs['Color'])
nt.links.new(em.outputs['Emission'], oo.inputs['Surface'])
meshes = [o for o in sc.objects if o.type == 'MESH']
os.makedirs(out, exist_ok=True)
for pitch in (38, 45, 52):
    for yaw in (-14, 0, 14):
        aim(yaw, pitch)
        tag = 'p%02d_y%+03d' % (pitch, yaw)
        sc.render.engine = 'BLENDER_WORKBENCH'
        sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'SINGLE'
        sc.display.shading.show_cavity = True
        sc.view_settings.view_transform = 'Standard'
        for o in meshes: o.data.materials.clear()
        sc.render.filepath = os.path.join(out, 'clay_' + tag + '.png'); bpy.ops.render.render(write_still=True)
        sc.render.engine = 'BLENDER_EEVEE'
        sc.view_settings.view_transform = 'Raw'
        for o in meshes: o.data.materials.append(mat)
        sc.render.filepath = os.path.join(out, 'depth_' + tag + '.png'); bpy.ops.render.render(write_still=True)
print('ok')
