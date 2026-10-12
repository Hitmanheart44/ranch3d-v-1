"""Tidy a textured model made on a cloud service (Hunyuan 3D site etc.) for the game, keeping its texture:
join parts, weld seams, drop loose specks, decimate to a face budget (old machines), export .glb.
~/.local/bin/blender -b -P tools/blender/cloud_clean.py -- in.glb out.glb [max_faces]
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[:2]
budget = int(args[2]) if len(args) > 2 else 40000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
before = len(o.data.polygons)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.mesh.delete_loose()
bpy.ops.object.mode_set(mode="OBJECT")
if len(o.data.polygons) > budget:
    d = o.modifiers.new("dec", "DECIMATE")
    d.ratio = budget / len(o.data.polygons)
    d.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
print("CLOUDCLEAN %s faces %d -> %d" % (dst, before, len(o.data.polygons)))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=92)
