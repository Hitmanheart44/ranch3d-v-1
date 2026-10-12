"""Give a building model's untextured back wall (a flat dark panel from the cloud generator) proper plank siding.
~/.local/bin/blender -b -P tools/blender/fill_back.py -- in.glb out.glb planks_tinted.png
The model faces -Y (Blender). Faces on the back (+Y) side that point backward get a plank material tinted r,g,b,
UV-projected so the planks run vertically like the side walls.
"""
import sys

import bmesh
import bpy

a = sys.argv[sys.argv.index("--") + 1:]
src, dst, tex = a[:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [x for x in bpy.context.scene.objects if x.type == "MESH"][0]
me = o.data
ys = [v.co.y for v in me.vertices]
zs = [v.co.z for v in me.vertices]
ymax, zmin, zmax = max(ys), min(zs), max(zs)
mat = bpy.data.materials.new("backwall")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
img = nt.nodes.new("ShaderNodeTexImage")
img.image = bpy.data.images.load(tex)
nt.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])  # (pre-tint the image: glTF keeps only image -> color)
bsdf.inputs["Roughness"].default_value = 0.9
me.materials.append(mat)
mi = len(me.materials) - 1
bm = bmesh.new()
bm.from_mesh(me)
uv = bm.loops.layers.uv.active
n = 0
for f in bm.faces:
    c = f.calc_center_median()
    if f.normal.y > 0.55 and c.y > ymax - 0.6 and zmin + 0.25 < c.z < zmax - 0.15:
        f.material_index = mi
        for l in f.loops:
            l[uv].uv = (l.vert.co.z / 1.4, l.vert.co.x / 0.9)  # boards run vertically, like the side walls
        n += 1
bm.to_mesh(me)
print("BACKWALL faces", n)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
