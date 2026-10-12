"""Give a character model an eye patch (black leather patch + a strap around the head), fitted to the surface.
~/.local/bin/blender -b -P tools/blender/eyepatch.py -- in.glb out.glb eye_x eye_z [radius]
eye_x / eye_z: where the eye is, in model meters (Blender frame: the model faces -Y). The patch is raycast onto the face.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[:2]
ex, ez = float(args[2]), float(args[3])
rad = float(args[4]) if len(args) > 4 else 0.03
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(body, dg)


def hit(x, z, d=Vector((0, 1, 0)), origin_y=-5.0):
    loc, nrm, _, _ = bvh.ray_cast(Vector((x, origin_y, z)), d)
    return loc, nrm


leather = bpy.data.materials.new("eyepatch")
leather.use_nodes = True
bsdf = leather.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.03, 0.025, 0.02, 1)
bsdf.inputs["Roughness"].default_value = 0.55
# the patch: a grid of points raycast onto the face inside an oval, pushed out a few mm
bm = bmesh.new()
rings, segs = 8, 32  # a smooth oval: rings of points raycast onto the face
center = hit(ex, ez)
cv = bm.verts.new(center[0] + center[1] * 0.005)
prev_ring = None
for r in range(1, rings + 1):
    ring = []
    for k in range(segs):
        a = k * 2 * math.pi / segs
        loc, nrm = hit(ex + math.cos(a) * rad * r / rings, ez + math.sin(a) * rad * 1.12 * r / rings)
        ring.append(bm.verts.new((loc + nrm * 0.005) if loc is not None else center[0]))
    for k in range(segs):
        k2 = (k + 1) % segs
        if prev_ring is None:
            bm.faces.new((cv, ring[k], ring[k2]))
        else:
            bm.faces.new((prev_ring[k], ring[k], ring[k2], prev_ring[k2]))
    prev_ring = ring
grid = prev_ring
# the strap: a thin band around the head, from the patch's outer edge up over the ear to the back
pts = []
for k in range(25):
    a = -math.pi / 2 + k * (2 * math.pi) / 24  # around the head at a tilt
    z = ez + 0.035 + 0.03 * math.sin(a + math.pi / 2)
    d = Vector((math.cos(a), math.sin(a), 0))
    c = Vector((ex * 0.2, 0.0, z))
    # cast inward from outside the head to find its surface at this angle
    loc, nrm, _, _ = bvh.ray_cast(c + d * 0.6 + Vector((0, hit(0, z)[0].y + 0.1 if hit(0, z)[0] else 0, 0)) * 0, -d)
    if loc is not None:
        pts.append((loc + nrm * 0.004, nrm))
prev = None
for p, nr in pts:
    up = Vector((0, 0, 0.007))
    v1, v2 = bm.verts.new(p - up), bm.verts.new(p + up)
    if prev:
        bm.faces.new((prev[0], prev[1], v2, v1))
    prev = (v1, v2)
me = bpy.data.meshes.new("eyepatch")
bm.to_mesh(me)
me.materials.append(leather)
patch = bpy.data.objects.new("eyepatch", me)
bpy.context.collection.objects.link(patch)
for f in me.polygons:
    f.use_smooth = True
print("EYEPATCH verts %d strap %d" % (len(grid), len(pts)))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
