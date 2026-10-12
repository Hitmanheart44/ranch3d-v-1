"""Clean an AI sculpt before texturing: weld, light smoothing of the lumpy AI surface, decimate.
~/.local/bin/blender -b -P tools/blender/clean_mesh.py -- in.glb out.glb [faces=40000]
Keeps the glTF frame (Y up, facing +Z) so the painter and detail pass line up with the concept.
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[:2]
faces = int(args[2]) if len(args) > 2 else 40000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.context.view_layer.objects.active = objs[0]
for o in objs:
    o.select_set(True)
if len(objs) > 1:
    bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.object.mode_set(mode="OBJECT")
m = o.modifiers.new("smooth", "LAPLACIANSMOOTH")  # irons out AI noise, keeps volume and silhouette
m.lambda_factor = 0.4
m.iterations = 3
m.use_volume_preserve = True
bpy.ops.object.modifier_apply(modifier="smooth")
n = len(o.data.polygons)
if n > faces:
    d = o.modifiers.new("dec", "DECIMATE")
    d.ratio = faces / n
    bpy.ops.object.modifier_apply(modifier="dec")
for p in o.data.polygons:
    p.use_smooth = True
o.data.materials.clear()
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=False)
print("CLEAN", dst, len(o.data.polygons))
