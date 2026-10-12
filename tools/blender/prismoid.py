"""Prismoid: a 90s-platformer collectible gem with a face, modeled directly (low poly, flat-shaded facets).
~/.local/bin/blender -b -P tools/blender/prismoid.py -- out.glb [render_prefix]
Shape: flat table on top, sloped crown, an 8-sided upright band that carries the face, pointed pavilion below.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
prefix = args[1] if len(args) > 1 else ""
lib.reset()

N = 8
LIFT = 0.35  # floats this high off the ground
# round brilliant cut (low poly): table, crown (star + kite + upper girdle facets), thin girdle, pavilion, culet
Z_TABLE, Z_MID, Z_GT, Z_GB, Z_CULET = 1.0, 0.89, 0.80, 0.77, 0.30
R_TABLE, R_MID, R_G = 0.30, 0.43, 0.5
off = -math.pi / 2  # a table vertex points straight at the front (-Y)


def ring(n, z, r, o):
    return [bm.verts.new((r * math.cos(o + i * 2 * math.pi / n), r * math.sin(o + i * 2 * math.pi / n), z + LIFT)) for i in range(n)]


bm = bmesh.new()
table = ring(N, Z_TABLE, R_TABLE, off)
mid = ring(N, Z_MID, R_MID, off + math.pi / N)
gt = ring(2 * N, Z_GT, R_G, off)
gb = ring(2 * N, Z_GB, R_G, off)
culet = bm.verts.new((0, 0, Z_CULET + LIFT))
bm.faces.new(table)
for i in range(N):
    j, h = (i + 1) % N, (i - 1) % N
    bm.faces.new((table[i], table[j], mid[i]))                      # star facets
    bm.faces.new((table[i], mid[h], gt[2 * i]))                     # kite facets (as two triangles)
    bm.faces.new((table[i], gt[2 * i], mid[i]))
    bm.faces.new((mid[i], gt[2 * i], gt[2 * i + 1]))                # upper girdle facets
    bm.faces.new((mid[i], gt[2 * i + 1], gt[(2 * i + 2) % (2 * N)]))
    bm.faces.new((gb[2 * i], gb[2 * i + 1], culet))                 # pavilion: straight facets to the point
    bm.faces.new((gb[2 * i + 1], gb[(2 * i + 2) % (2 * N)], culet))
for k in range(2 * N):                                              # thin girdle band
    k2 = (k + 1) % (2 * N)
    bm.faces.new((gt[k], gt[k2], gb[k2], gb[k]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
from mathutils.bvhtree import BVHTree  # noqa: E402
tree = BVHTree.FromBMesh(bm)
me = bpy.data.meshes.new("gem")
bm.to_mesh(me)
gem = bpy.data.objects.new("gem", me)
bpy.context.collection.objects.link(gem)
for p in me.polygons:
    p.use_smooth = False  # flat facets = the PS1 look
lib.assign(gem, lib.material("gem", (0.80, 0.01, 0.30), rough=0.08, emit=0.12, emit_color=(1.0, 0.1, 0.45)))


def decal(name, x, z, w, h, depth, mat, lift=0.0):
    """A flat oval lying on whatever facet is at (x, z) seen from the front."""
    loc, n, _, _ = tree.ray_cast(Vector((x, -3.0, z + LIFT)), Vector((0, 1, 0)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10)
    o = bpy.context.active_object
    o.name = name
    o.scale = (w, depth, h)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, -1, 0)).rotation_difference(n)
    o.location = loc + n * (depth * 0.4 + lift)
    lib.assign(o, mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def on_surface(x, z, lift):
    loc, n, _, _ = tree.ray_cast(Vector((x, -3.0, z + LIFT)), Vector((0, 1, 0)))
    return loc + n * lift


def flat_decal(name, outline, mat, lift, rings=6, step=0.008):
    """A flat shape (outline = (x, z) points, seen from the front) laid onto the facets like paint: the outline is
    densified and filled with rings shrinking to the center, and every point is projected onto the gem, so the
    shape bends over facet edges instead of cutting under them."""
    dense = []
    for i, (x0, z0) in enumerate(outline):
        x1, z1 = outline[(i + 1) % len(outline)]
        k = max(1, int(math.hypot(x1 - x0, z1 - z0) / step))
        dense += [(x0 + (x1 - x0) * t / k, z0 + (z1 - z0) * t / k) for t in range(k)]
    cx = sum(p[0] for p in dense) / len(dense)
    cz = sum(p[1] for p in dense) / len(dense)
    n = len(dense)
    verts, faces = [], []
    for r in range(rings):  # ring 0 = outline, then shrinking toward the center
        f = 1 - r / rings
        verts += [tuple(on_surface(cx + (x - cx) * f, cz + (z - cz) * f, lift)) for x, z in dense]
    for r in range(rings - 1):
        for i in range(n):
            a0, a1 = r * n + i, r * n + (i + 1) % n
            faces.append((a0, a1, a1 + n, a0 + n))
    verts.append(tuple(on_surface(cx, cz, lift)))
    c = len(verts) - 1
    last = (rings - 1) * n
    faces += [(last + i, last + (i + 1) % n, c) for i in range(n)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    lib.assign(o, mat)
    return o


def ellipse(cx, cz, rx, rz, a0=0.0, a1=2 * math.pi, n=28):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cz + rz * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1 if a1 - a0 < 6.2 else n)]


# Dragon Quest-style happy face, in our glossy PS2 look: big black oval eyes with a shine, a wide open D grin
ink = lib.material("face", (0.0, 0.0, 0.0), rough=0.15)
shine = lib.material("eye_shine", (1, 1, 1), rough=0.1, emit=1.5)
mouth = lib.material("mouth", (0.30, 0.0, 0.03), rough=0.3, emit=0.3, emit_color=(0.35, 0.0, 0.04))
tongue = lib.material("tongue", (0.85, 0.08, 0.22), rough=0.35, emit=0.15, emit_color=(0.9, 0.1, 0.25))
parts = [gem]
EZ, MZ = 0.865, 0.735
for s in (-1, 1):
    parts.append(flat_decal("eye", ellipse(s * 0.1, EZ, 0.045, 0.066), ink, 0.004))
    parts.append(flat_decal("shine", ellipse(s * 0.1 - 0.014, EZ + 0.024, 0.013, 0.016), shine, 0.007))
parts.append(flat_decal("mouth", [(-0.12, MZ)] + ellipse(0.0, MZ, 0.12, 0.10, math.pi, 2 * math.pi)[1:-1] + [(0.12, MZ)], mouth, 0.004))
parts.append(flat_decal("tongue", ellipse(0.0, MZ - 0.075, 0.06, 0.028), tongue, 0.007))
lib.export(out, parts)
print("PRISMOID", out)
if prefix:
    lib.render(prefix, height=1.6, accent=(1.0, 0.4, 0.8))
    # straight-on front shot = his 2D concept (the stock cameras are framed for tall humanoids)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam_front", bpy.data.cameras.new("cam_front"))
    sc.collection.objects.link(cam)
    cam.data.lens = 85
    cam.location = (0.0, -4.0, LIFT + 0.75)
    cam.rotation_euler = (math.radians(86), 0, 0)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = 832, 1216
    sc.render.filepath = prefix + "_concept.png"
    bpy.ops.render.render(write_still=True)
