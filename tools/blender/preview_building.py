"""Building preview: whole model in frame, neutral daylight, front 3/4 and back 3/4 (Cycles on the CPU).
~/.local/bin/blender -b -P tools/blender/preview_building.py -- model.glb /out/prefix   -> prefix_front.png, prefix_back.png
"""
import math
import sys

import bpy
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (lo + hi) / 2
size = (hi - lo).length
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 900
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.world = w
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.data.color = (1.0, 0.95, 0.88)
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
sc.collection.objects.link(sun)
ground = bpy.data.meshes.new("g")
ground.from_pydata([(-500, -500, lo.z), (500, -500, lo.z), (500, 500, lo.z), (-500, 500, lo.z)], [], [(0, 1, 2, 3)])
g = bpy.data.objects.new("g", ground)
gm = bpy.data.materials.new("gm")
gm.diffuse_color = (0.35, 0.33, 0.3, 1)
g.data.materials.append(gm)
sc.collection.objects.link(g)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.lens = 35
sc.collection.objects.link(cam)
sc.camera = cam
for name, a in [("front", -0.6), ("back", math.pi - 0.6)]:
    cam.location = c + Vector((math.sin(a) * size * 1.05, -math.cos(a) * size * 1.05, size * 0.38))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out + "_" + name + ".png"
    bpy.ops.render.render(write_still=True)
