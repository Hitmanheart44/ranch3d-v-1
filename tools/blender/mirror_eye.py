"""Fix a botched eye on a textured model by mirroring the good eye's texture onto it (CPU, no repainting).
~/.local/bin/blender -b -P tools/blender/mirror_eye.py -- in.glb out.glb good_x bad_x eye_z [rad_x rad_z]
Each point of the bad eye's area (raycast onto the face from the front, the model faces -Y) takes the color
of the mirror point on the good eye; the edge is feathered so there's no seam.
"""
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = a[:2]
gx, bx, ez = float(a[2]), float(a[3]), float(a[4])
rx = float(a[5]) if len(a) > 5 else 0.034
rz = float(a[6]) if len(a) > 6 else 0.026
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = [x for x in bpy.context.scene.objects if x.type == "MESH"][0]
me = o.data
me.calc_loop_triangles()
img = None
for m in me.materials:
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None and n.outputs[0].links and \
                any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
            img = n.image
W, H = img.size
px = np.empty(W * H * 4, np.float32)
img.pixels.foreach_get(px)
px = px.reshape(H, W, 4)
src_px = px.copy()
uvl = me.uv_layers.active.data
bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
tri_of_poly = {}
for t in me.loop_triangles:
    tri_of_poly.setdefault(t.polygon_index, []).append(t)


def uv_at(x, z):
    loc, _, fi, _ = bvh.ray_cast(Vector((x, -5.0, z)), Vector((0, 1, 0)))
    if loc is None:
        return None
    for t in tri_of_poly.get(fi, []):
        vs = [me.vertices[i].co for i in t.vertices]
        v0, v1, v2 = vs[1] - vs[0], vs[2] - vs[0], loc - vs[0]
        d00, d01, d11, d20, d21 = v0.dot(v0), v0.dot(v1), v1.dot(v1), v2.dot(v0), v2.dot(v1)
        den = d00 * d11 - d01 * d01
        if den == 0:
            continue
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        u = 1 - v - w
        if min(u, v, w) < -0.01:
            continue
        uv = uvl[t.loops[0]].uv * u + uvl[t.loops[1]].uv * v + uvl[t.loops[2]].uv * w
        return int(uv.x * (W - 1)), int(uv.y * (H - 1))
    return None


n = 160
done = 0
for j in range(n):
    for i in range(n):
        du, dv = i / (n - 1) * 2 - 1, j / (n - 1) * 2 - 1
        r = du * du + dv * dv
        if r > 1:
            continue
        tb = uv_at(bx + du * rx, ez + dv * rz)
        tg = uv_at(gx - du * rx, ez + dv * rz)  # eyelids: mirrored across the face
        ti = uv_at(gx + du * rx, ez + dv * rz)  # iris and pupil: NOT mirrored, so both eyes look the same way
        if tb is None or tg is None or ti is None:
            continue
        k = min(1.0, (1 - r) / 0.35)  # feather the outer rim
        mi = 1.0 - min(1.0, max(0.0, (r - 0.2) / 0.25))  # how much of the iris copy to use (centre of the eye)
        for oy in (0, 1):
            for ox in (0, 1):
                yb, xb = min(H - 1, tb[1] + oy), min(W - 1, tb[0] + ox)
                yg, xg = min(H - 1, tg[1] + oy), min(W - 1, tg[0] + ox)
                yi, xi = min(H - 1, ti[1] + oy), min(W - 1, ti[0] + ox)
                col = src_px[yg, xg, :3] * (1 - mi) + src_px[yi, xi, :3] * mi
                px[yb, xb, :3] = px[yb, xb, :3] * (1 - k) + col * k
        done += 1
img.pixels.foreach_set(px.ravel())
img.update()
img.pack()
print("MIRROREYE samples", done, "texture", W, H)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
