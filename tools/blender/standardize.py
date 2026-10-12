"""Game-ready placement for a finished AI model (keeps its texture): stand it on the ground at a height, centered.
~/.local/bin/blender -b -P tools/blender/standardize.py -- in.glb out.glb height
Materials are renamed "aitex" so the game gives them its procedural animation (breathing, sway, flap, bob).
"""
import sys

import bpy
from mathutils import Matrix, Vector

src, dst, height = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
pts = [v.co for o in objs for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
k = float(height) / (hi.z - lo.z)
c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for o in objs:
    for v in o.data.vertices:
        v.co = (v.co - c) * k
    for p in o.data.polygons:  # smooth shading (AI meshes come in with flat, faceted normals)
        p.use_smooth = True
    bpy.context.view_layer.objects.active = o
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except RuntimeError:
        pass
    for m in o.data.materials:
        if m is not None:
            m.name = "aitex"
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
print("STANDARD", dst, round(k, 3))
