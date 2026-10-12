"""Poly Haven glTF -> light game .glb: join, decimate to a face budget, keep its textures, stand it on the ground.
~/.local/bin/blender -b -P tools/blender/ph_prep.py -- in.gltf out.glb max_faces
"""
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
src, dst, budget = a[0], a[1], int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
tot = sum(len(o.data.polygons) for o in meshes)
if tot > budget:
    for o in meshes:  # decimate each part by the same ratio (keeps separate materials intact)
        d = o.modifiers.new("dec", "DECIMATE")
        d.ratio = max(0.0005, budget / tot)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="dec")
after = sum(len(o.data.polygons) for o in meshes)
zmin = min((o.matrix_world @ v.co).z for o in meshes for v in o.data.vertices)
for o in bpy.context.scene.objects:
    if o.parent is None:
        o.location.z -= zmin
print("PREP %s faces %d -> %d" % (dst, tot, after))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=88)
