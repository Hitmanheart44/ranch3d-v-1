"""Plant main breed (plant type). MR-plant silhouette (a bulb body with a face, standing on roots, leaf fronds,
flowers on stalks) crossed with Roselia's flower hands. Own details: star-lily flowers (magenta, yellow centers)
on two arm stalks + one top stalk, a leaf calyx on the bulb, cartoon face like Prismoid's.
~/.local/bin/blender -b -P tools/blender/plant.py -- out.glb [render_prefix]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
prefix = args[1] if len(args) > 1 else ""
lib.reset()

bulb_m = lib.material("bulb", (0.86, 0.88, 0.55), rough=0.35)
stem = lib.material("stem", (0.25, 0.62, 0.18), rough=0.35)
leaf = lib.material("leaf", (0.12, 0.48, 0.12), rough=0.35)
root = lib.material("root", (0.62, 0.45, 0.22), rough=0.5)
petal = lib.material("petal", (0.85, 0.04, 0.07), rough=0.3)
center_m = lib.material("flower_center", (1.0, 0.8, 0.1), rough=0.3)
ink = lib.material("face", (0.0, 0.0, 0.0), rough=0.15)
shine = lib.material("eye_shine", (1, 1, 1), rough=0.1, emit=1.5)
cheek = lib.material("cheek", (1.0, 0.45, 0.5), rough=0.4)
parts = []


def ball(name, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    lib.assign(o, mat)
    for p in o.data.polygons:
        p.use_smooth = True
    parts.append(o)
    return o


def blade(name, base, direction, length, width, mat, up=(0, 0, 1)):
    """A flat pointed blade (leaf / petal) from base along direction; its flat side faces `up` as far as possible."""
    d = Vector(direction).normalized()
    o = ball(name, Vector(base) + d * length * 0.5, (width, length * 0.5, width * 0.22), mat)
    # local Y = length axis, local Z = flat-side normal
    z = Vector(up)
    z = (z - d * z.dot(d)).normalized() if (z - d * z.dot(d)).length > 1e-4 else d.orthogonal().normalized()
    x = d.cross(z)
    from mathutils import Matrix
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Matrix((x, d, z)).transposed().to_quaternion()
    # taper to a point: pinch the far end
    for v in o.data.vertices:
        t = max(0.0, v.co.y)  # 0..1 toward the tip
        v.co.x *= 1.0 - 0.75 * t
    return o


def flower(center, facing, size=1.0):
    """Star lily: 6 pointed petals cupped toward `facing`, yellow center with stamens."""
    f = Vector(facing).normalized()
    a = f.orthogonal().normalized()
    b = f.cross(a)
    for k in range(6):
        ang = k / 6 * 2 * math.pi
        radial = a * math.cos(ang) + b * math.sin(ang)
        d = (radial + f * 0.55).normalized()
        blade("petal", center + radial * 0.02 * size, d, 0.17 * size, 0.06 * size, petal, up=f)
    ball("flower_center", center + f * 0.02 * size, (0.035 * size,) * 3, center_m)
    for k in range(3):
        ang = k / 3 * 2 * math.pi + 0.5
        tip = center + f * 0.09 * size + (a * math.cos(ang) + b * math.sin(ang)) * 0.03 * size
        parts.append(lib.tube("stamen", [center + f * 0.02 * size, tip], [0.006 * size, 0.004 * size], center_m, seg=6))
        ball("anther", tip, (0.012 * size,) * 3, center_m)


def lathe(name, profile, mat, seg=32):
    """Solid of revolution around Z from (z, r) points, bottom to top (closed at both ends)."""
    import bmesh
    bm = bmesh.new()
    rings = [[bm.verts.new((r * math.cos(k / seg * 2 * math.pi), r * math.sin(k / seg * 2 * math.pi), z)) for k in range(seg)]
             for z, r in profile]
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(seg):
            bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="sub")
    for p in o.data.polygons:
        p.use_smooth = True
    lib.assign(o, mat)
    parts.append(o)
    return o


# turnip body: wide round bottom, narrowing to a neck on top, tapering to a taproot below. No legs: it floats.
lathe("bulb", [(0.06, 0.004), (0.10, 0.03), (0.15, 0.10), (0.21, 0.19), (0.29, 0.27), (0.38, 0.31), (0.47, 0.30),
               (0.55, 0.25), (0.61, 0.18), (0.66, 0.11), (0.70, 0.07), (0.73, 0.05)], bulb_m)
parts.append(lib.tube("taproot", [Vector((0, 0, 0.09)), Vector((0.01, 0, 0.03)), Vector((0.03, 0, -0.04))], [0.025, 0.012, 0.0], root, seg=8))
parts.append(lib.tube("bulb_neck", [Vector((0, 0, 0.7)), Vector((0, 0, 0.76))], [0.06, 0.05], stem))
for k in range(8):
    ang = k / 8 * 2 * math.pi
    radial = Vector((math.cos(ang), math.sin(ang), 0))
    blade("calyx", Vector((0, 0, 0.68)) + radial * 0.07, (radial * 1.0 + Vector((0, 0, -0.9))), 0.2, 0.07, leaf, up=radial + Vector((0, 0, 0.6)))
# big leaf fronds out to the sides (lower than the arms)
for s in (-1, 1):
    blade("frond", (s * 0.08, 0.02, 0.7), (s * 1.0, 0.15, 0.25), 0.42, 0.13, leaf, up=(0, 0, 1))
# arm stalks ending in flower hands, and a top stalk with a flower crown
for s in (-1, 1):
    pts = [Vector((s * 0.05, 0, 0.72)), Vector((s * 0.2, -0.02, 0.86)), Vector((s * 0.38, -0.06, 0.88))]
    parts.append(lib.tube("arm", pts, [0.035, 0.03, 0.026], stem))
    flower(pts[-1] + Vector((s * 0.02, -0.01, 0.0)), (s * 1.0, -0.6, 0.35), size=1.05)
top = [Vector((0, 0, 0.72)), Vector((0.012, 0, 0.9)), Vector((0.0, 0, 1.08))]
parts.append(lib.tube("top_stem", top, [0.035, 0.03, 0.026], stem))
flower(top[-1], (0, -0.5, 1.0), size=1.15)
# face on the bulb front (cartoon, like Prismoid's)
FY = -0.297
FZ = 0.42
for s in (-1, 1):
    ball("eye", (s * 0.075, FY, FZ + 0.03), (0.034, 0.014, 0.05), ink)
    ball("shine", (s * 0.075 - 0.011, FY - 0.01, FZ + 0.052), (0.011, 0.006, 0.013), shine)
    ball("cheek", (s * 0.14, FY + 0.035, FZ - 0.035), (0.032, 0.012, 0.02), cheek)
smile = [Vector((x, FY + 0.004 + 6 * x * x, FZ - 0.055 - 6.0 * (0.003 - x * x))) for x in (-0.055, -0.03, 0.0, 0.03, 0.055)]
parts.append(lib.tube("smile", smile, [0.006, 0.009, 0.01, 0.009, 0.006], ink, seg=8))

lib.export(out, parts)
print("PLANT", out)
if prefix:
    lib.render(prefix, height=1.3, accent=(0.6, 1.0, 0.4))
    lib.concept_shot(prefix, 0.55, dist=4.4)
