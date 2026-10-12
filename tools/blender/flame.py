"""Flame (fire / fire main breed) and Embergeist (fire / dark): a floating ball of living fire with a face.
Round fire body, curling flame tongues off the top and sides, angry glowing eyes under dark brows, a wide jagged
grin full of teeth, and two fireballs floating beside it as hands.
~/.local/bin/blender -b -P tools/blender/flame.py -- out.glb [render_prefix] [flame|embergeist]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
prefix = args[1] if len(args) > 1 and args[1] != "-" else ""
kind = args[2] if len(args) > 2 else "flame"
lib.reset()
rnd = random.Random(7)

PAL = {  # body, outer tongues, inner tongues, brows/sockets, eye glow, fireballs
    "flame": [(0.80, 0.14, 0.02), (0.92, 0.22, 0.02), (1.0, 0.50, 0.04), (0.25, 0.02, 0.0), (1.0, 0.95, 0.6), (1.0, 0.6, 0.08)],
    "embergeist": [(0.22, 0.04, 0.30), (0.55, 0.05, 0.85), (0.85, 0.25, 1.0), (0.05, 0.0, 0.08), (0.95, 0.75, 1.0), (1.0, 0.5, 0.08)],
}[kind]
body_m = lib.material("fire_body", PAL[0], rough=0.4, emit=0.6, emit_color=PAL[0])
outer_m = lib.material("fire_outer", PAL[1], rough=0.4, emit=0.5, emit_color=PAL[1])
inner_m = lib.material("fire_inner", PAL[2], rough=0.4, emit=0.7, emit_color=PAL[2])
socket_m = lib.material("socket", PAL[3], rough=0.5)
eye_m = lib.material("eye_glow", PAL[4], rough=0.2, emit=4.0, emit_color=PAL[4])
mouth_m = lib.material("mouth", (0.08, 0.0, 0.0), rough=0.5)
teeth_m = lib.material("teeth", (1.0, 0.97, 0.9), rough=0.25, emit=0.4)
ball_m = lib.material("fireball", PAL[5], rough=0.3, emit=3.0, emit_color=PAL[5])
parts = []

C = Vector((0, 0, 0.7))  # body center (it floats)
R = 0.3


def sphere(name, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=18, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    lib.assign(o, mat)
    for p in o.data.polygons:
        p.use_smooth = True
    parts.append(o)
    return o


def tongue(base, direction, length, radius, mat, curl=0.25, seed_side=None):
    """A flame tongue: a tapering tube that rises along `direction` with an S-curl, ending in a sharp tip."""
    d = Vector(direction).normalized()
    side = seed_side or d.orthogonal().normalized()
    pts, radii = [], []
    for i in range(7):
        t = i / 6
        pts.append(Vector(base) + d * t * length + side * math.sin(t * math.pi * 1.3) * curl * length * t)
        radii.append(radius * (1 - t) ** 0.7)
    parts.append(lib.tube("tongue", pts, radii, mat, seg=10))


def lick(name, base, height, radius, lean, mat, curl=0.0, flat=1.0):
    """A flame lick: round at the bottom, swelling, then sweeping up to a sharp tip that leans along `lean`
    (and curls back toward the end). The Bomb-style silhouette is one big lick on top of the body."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24)
    o = bpy.context.active_object
    o.name = name
    L = Vector(lean)
    for v in o.data.vertices:
        t = (v.co.z + 1) / 2                                  # 0 bottom .. 1 tip
        prof = math.sin(math.pi * min(1.0, t * 1.25 + 0.05)) ** 0.55 * (1 - t) ** 0.85 * 1.35
        ang = math.atan2(v.co.y, v.co.x)
        prof *= 1 + 0.16 * max(0.0, t - 0.3) * math.sin(5 * ang + t * 7)   # wavy fire edges higher up
        sway = L * (t ** 2) * height + Vector((0, curl, 0)) * (max(0.0, t - 0.6) ** 2) * height * 4
        v.co = Vector((v.co.x * prof * radius, v.co.y * prof * radius * flat, 0)) + Vector((0, 0, t * height)) + sway
    o.location = base
    for p in o.data.polygons:
        p.use_smooth = True
    lib.assign(o, mat)
    parts.append(o)
    return o


body = sphere("body", C, (R, R * 0.92, R * 0.95), body_m)
# Bomb-style silhouette: the body flows up into one big swept-back plume, with a few big licks around it
lick("plume", C + Vector((0, 0.09, -0.2)), 1.02, 0.3, (0, 0.16, 0), outer_m, curl=0.22)
lick("plume_core", C + Vector((0, 0.06, -0.05)), 0.78, 0.19, (0, 0.12, 0), inner_m, curl=0.15)
for s, h, ang in ((-1, 0.62, 0.55), (1, 0.62, 0.55), (-1, 0.48, 1.0), (1, 0.48, 1.0)):
    lick("side_lick", C + Vector((s * 0.17, 0.06, 0.0 if ang < 0.8 else -0.08)), h, 0.13,
         (s * 0.35 * ang, 0.12, 0), inner_m if ang < 0.8 else outer_m, curl=0.12)
# PS2 finish: body + plume + licks become one organic, painted mesh (deep red base -> orange -> yellow -> gold tip,
# streaky flame variation, baked AO). The face is then painted onto it.
from mathutils import noise  # noqa: E402
RAMPS = {"flame": [(0.50, 0.04, 0.02), (0.95, 0.22, 0.03), (1.0, 0.55, 0.06), (1.0, 0.82, 0.25), (1.0, 0.95, 0.6)],
         "embergeist": [(0.10, 0.01, 0.14), (0.30, 0.04, 0.45), (0.58, 0.08, 0.85), (0.85, 0.35, 1.0), (0.97, 0.75, 1.0)]}[kind]


def fire_color(co, n, t):
    streak = noise.noise(Vector((co.x * 9, co.y * 9, co.z * 1.6))) * 0.2
    u = min(0.999, max(0.0, t ** 1.7 * 1.1 + streak + 0.12))
    x = u * (len(RAMPS) - 1)
    i = int(x)
    f = x - i
    a, b = RAMPS[i], RAMPS[min(i + 1, len(RAMPS) - 1)]
    return tuple(a[j] * (1 - f) + b[j] * f for j in range(3))


fire_parts = [o for o in parts if o.name.startswith(("body", "plume", "side_lick"))]
parts = [o for o in parts if o not in fire_parts]
body = lib.ps2_finish(fire_parts, "flame_body", fire_color, voxel=0.011, ao=0.5, emit=0.15)
parts.append(body)
paint = lib.SurfacePainter(body)
EZ = C.z + 0.05
for s in (-1, 1):
    # angry eye: flat top edge sloping down toward the middle, rounded bottom; dark socket behind it
    eye = [(s * 0.2, EZ + 0.035), (s * 0.05, EZ - 0.01)] + [(s * (0.05 + 0.15 * (1 - math.cos(a)) / 2), EZ - 0.01 - 0.045 * math.sin(a) + 0.045 * a / math.pi * 0.0) for a in [i / 10 * math.pi for i in range(1, 10)]]
    sock = [(x * 1.18 - s * 0.005, z + 0.012) for x, z in eye]
    parts.append(paint.decal("socket", sock, socket_m, 0.004))
    parts.append(paint.decal("eye", eye, eye_m, 0.008))
MZ = C.z - 0.12
W = 0.2
upper = [(x, MZ + 0.05 - 1.3 * x * x) for x in [i / 12 * 2 * W - W for i in range(13)]]
lower = [(x, MZ - 0.1 + 1.6 * x * x) for x in [W - i / 12 * 2 * W for i in range(13)]]
parts.append(paint.decal("mouth", upper + lower, mouth_m, 0.004, rings=8))
mid = lambda x: MZ - 0.025 + 0.15 * x * x  # where upper and lower teeth meet
nt = 7
for k in range(nt):  # upper teeth point down, lower teeth point up, interleaved: a zigzag
    for sign in (-1, 1):
        x0 = -W * 0.92 + (k + (0.5 if sign > 0 else 0.0)) * (2 * W * 0.92) / nt
        x1 = x0 + (2 * W * 0.92) / nt
        xm = (x0 + x1) / 2
        if sign < 0:
            lip = lambda x: MZ + 0.05 - 1.3 * x * x
            tri = [(x0, lip(x0) + 0.01), (x1, lip(x1) + 0.01), (xm, mid(xm) - 0.012)]
        else:
            if x1 > W * 0.95:
                continue
            lip = lambda x: MZ - 0.1 + 1.6 * x * x
            tri = [(x1, lip(x1) - 0.01), (x0, lip(x0) - 0.01), (xm, mid(xm) + 0.012)]
        parts.append(paint.decal("tooth", tri, teeth_m, 0.007, rings=3, step=0.006))
# fireball hands
for s in (-1, 1):
    fb = C + Vector((s * 0.46, -0.06, -0.1))
    sphere("fireball", fb, (0.09, 0.09, 0.09), ball_m)
    for k in range(5):
        a = k / 5 * 2 * math.pi
        tongue(fb + Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.03)), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1),
               0.16, 0.045, outer_m if k % 2 else inner_m, curl=0.2)

# PS2 finish for each fireball hand: one blob, white-hot core fading to orange flame tips
for s in (-1, 1):
    grp = [o for o in parts if o.name.startswith(("fireball", "tongue")) and (o.matrix_world @ o.data.vertices[0].co).x * s > 0.25]
    if grp:
        parts = [o for o in parts if o not in grp]
        parts.append(lib.ps2_finish(grp, "fireball", lambda co, n, t: fire_color(co, n, 0.45 + 0.55 * t), voxel=0.008, ao=0.3, emit=0.6))

lib.export(out, parts)
print("FLAME", kind, out)
if prefix:
    lib.render(prefix, height=1.4, accent=(1.0, 0.5, 0.1))
    lib.concept_shot(prefix, 0.72, dist=4.4)
