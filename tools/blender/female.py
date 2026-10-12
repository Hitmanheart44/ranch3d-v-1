"""Shared adult female base for the humanoid breeds (Vexa, Sylvara, Valkra, Nysse).

Proportions: ~2.45 tall, small head (~1/8 height), long legs, narrow waist, wide hips, full bust.
Pose: pin-up contrapposto. Weight on her right leg (hip pushed out), left knee bent in on her toes,
right hand on her hip, left arm relaxed, shoulders counter-tilted, head tilted.
All numbers are Godot coords (x right, y up, z forward); G() builds them, lib.V() converts to Blender.

body() returns (mesh, J). J = joint positions in Godot coords, for clothing region tests:
    lib.seg_dist(G(x, y, z), J["elbow_r"], J["wrist_r"]) < 0.06
Head features go through head(): local coords around the head center, tilted with the head.
"""
import math

import bpy
from mathutils import Vector

import lib
from lib import V

HEAD_C = (0.0, 2.27, 0.0)
HEAD_ROLL = -7.0   # degrees, sideways tilt
HEAD_PITCH = 5.0   # degrees, chin slightly down
HEAD_SHIFT = (0.012, 0.0, 0.01)


def G(x, y, z):
    return Vector((x, y, z))


def B(g):
    """Godot-coord Vector -> Blender point."""
    return V(g.x, g.y, g.z)


def head(x, y, z):
    """Head-local point (relative to the head center, untilted) -> Blender point on the tilted head."""
    r, p = math.radians(HEAD_ROLL), math.radians(HEAD_PITCH)
    x1, y1 = x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
    y2, z2 = y1 * math.cos(p) - z * math.sin(p), y1 * math.sin(p) + z * math.cos(p)
    return V(HEAD_C[0] + HEAD_SHIFT[0] + x1, HEAD_C[1] + HEAD_SHIFT[1] + y2, HEAD_C[2] + HEAD_SHIFT[2] + z2)


def joints(legs=True):
    J = {
        "pelvis": G(0.03, 1.28, 0.0), "waist": G(0.012, 1.56, 0.0), "chest": G(-0.004, 1.8, -0.01),
        "shoulder_r": G(0.222, 1.935, -0.025), "elbow_r": G(0.41, 1.63, -0.11), "wrist_r": G(0.235, 1.37, 0.0),
        "shoulder_l": G(-0.228, 1.965, -0.025), "elbow_l": G(-0.315, 1.67, -0.03), "wrist_l": G(-0.33, 1.39, 0.075),
    }
    if legs:
        J.update({
            "hip_r": G(0.155, 1.16, 0.0), "knee_r": G(0.095, 0.67, 0.02), "ankle_r": G(0.06, 0.1, 0.0),
            "hip_l": G(-0.095, 1.15, 0.0), "knee_l": G(-0.04, 0.71, 0.13), "ankle_l": G(-0.12, 0.17, 0.03),
        })
    return J


def body(legs=True):
    J = joints(legs)
    b = lib.Blob("Body")
    _face(b)
    b.capsule(B(J["chest"] + G(0.004, 0.23, 0.005)), head(0, -0.13, -0.01), 0.05)        # neck
    # torso, counter-tilted: hips push to her right, shoulders drop to her right
    sl, sr = J["shoulder_l"], J["shoulder_r"]
    b.ellipsoid(B((sl + sr) * 0.5 + G(0, 0.035, 0)), 0.2, 0.05, 0.08, rot=(0, 0, -5))    # trapezius
    c = J["chest"]
    b.ellipsoid(B(c), 0.182, 0.19, 0.122, rot=(0, 0, -4))                                # ribcage
    for sx in (-1, 1):
        b.ellipsoid(B(c + G(sx * 0.095, 0.015, 0.098)), 0.112, 0.108, 0.1, rot=(-6, sx * 12, -4))  # bust
    b.ellipsoid(B(J["waist"]), 0.118, 0.17, 0.088, rot=(0, 0, 3))                         # waist
    b.ellipsoid(B(J["waist"] + G(0, -0.05, 0.035)), 0.08, 0.08, 0.05)                     # soft belly
    b.ellipsoid(B(J["pelvis"]), 0.255, 0.155, 0.15, rot=(0, 0, 6))                        # hips
    for sx in (-1, 1):
        b.ellipsoid(B(J["pelvis"] + G(sx * 0.095, -0.065, -0.07)), 0.105, 0.105, 0.095)     # glutes
    for side in ("r", "l"):
        sh, el, wr = J["shoulder_" + side], J["elbow_" + side], J["wrist_" + side]
        b.ball(B(sh), 0.066)
        b.capsule(B(sh), B(el), 0.051)
        b.capsule(B(el), B(wr), 0.039)
        _hand(b, wr, el, side)
    if legs:
        for side in ("r", "l"):
            hip, knee, ank = J["hip_" + side], J["knee_" + side], J["ankle_" + side]
            b.ellipsoid(B(hip.lerp(knee, 0.28)), 0.098, 0.17, 0.102)          # upper thigh
            b.capsule(B(hip), B(knee), 0.08)
            b.capsule(B(knee), B(ank), 0.046)
            b.ellipsoid(B(knee.lerp(ank, 0.32) + G(0, 0, -0.025)), 0.06, 0.13, 0.066)  # calf
            toes = side == "l"  # the bent leg stands on its toes, the weight foot is flat
            fp = ank + (G(0.0, -0.09, 0.07) if toes else G(0.0, -0.055, 0.06))
            b.ellipsoid(B(fp), 0.042, 0.035, 0.105, rot=(55 if toes else 0, 0, 0))
    return b.to_mesh(voxel=0.007), J


def _hand(b, wr, el, side):
    d = (wr - el).normalized()
    if side == "r":  # resting on the hip, palm flat, fingers pointing down and back
        b.ellipsoid(B(wr + d * 0.06 + G(0.015, 0, 0)), 0.03, 0.065, 0.045, rot=(20, 0, 25))
    else:
        b.ellipsoid(B(wr + d * 0.07), 0.032, 0.07, 0.028)
        b.capsule(B(wr + d * 0.1), B(wr + d * 0.16 + G(0, 0, 0.02)), 0.014)  # fingers together


def _face(b):
    """Sculpted head: cranium, V jaw, cheekbones, nose, brow, carved eye sockets."""
    b.ellipsoid(head(0, 0.01, -0.01), 0.112, 0.14, 0.126)
    b.ellipsoid(head(0, -0.08, 0.042), 0.072, 0.056, 0.068)
    b.ball(head(0, -0.118, 0.072), 0.024)                         # chin
    for sx in (-1, 1):
        b.ball(head(sx * 0.056, -0.012, 0.083), 0.034)             # cheekbones
        b.ball(head(sx * 0.045, 0.013, 0.118), 0.022, carve=True)  # eye sockets
    b.ellipsoid(head(0, -0.012, 0.112), 0.01, 0.022, 0.014)        # nose bridge
    b.ball(head(0, -0.034, 0.12), 0.0105)                          # nose tip
    b.ellipsoid(head(0, 0.045, 0.1), 0.075, 0.016, 0.024)          # brow


def neck_center():
    """Blender point at the middle of the neck (for chokers, collars)."""
    return B(joints()["chest"] + G(0.004, 0.23, 0.005)).lerp(head(0, -0.13, -0.01), 0.35)


def face_details(eye_mat, lips_mat, liner_mat):
    """Glowing almond eyes, winged liner, arched brows, full lips."""
    out = []
    for sx in (-1, 1):
        out.append(_ellipsoid_mesh(f"eye{sx}", head(sx * 0.044, 0.012, 0.106), (0.022, 0.009, 0.009), (0, sx * -0.3, sx * 0.14), eye_mat))
        lid = [head(sx * 0.018, 0.02, 0.11), head(sx * 0.045, 0.028, 0.116), head(sx * 0.07, 0.024, 0.104), head(sx * 0.088, 0.034, 0.092)]
        out.append(lib.tube(f"liner{sx}", lib.curve_pts(lid, 8), [0.0035, 0.004, 0.004, 0.0035, 0.003, 0.0025, 0.0015, 0.0005], liner_mat, seg=5))
        brow = [head(sx * 0.02, 0.05, 0.112), head(sx * 0.05, 0.062, 0.108), head(sx * 0.082, 0.052, 0.092)]
        out.append(lib.tube(f"brow{sx}", lib.curve_pts(brow, 6), [0.004, 0.0045, 0.004, 0.003, 0.002, 0.0008], liner_mat, seg=5))
    out.append(_ellipsoid_mesh("lip_upper", head(0, -0.062, 0.108), (0.021, 0.0055, 0.007), (0, 0, 0), lips_mat))
    out.append(_ellipsoid_mesh("lip_lower", head(0, -0.073, 0.106), (0.019, 0.0075, 0.0075), (0, 0, 0), lips_mat))
    return out


def _ellipsoid_mesh(name, loc, scale, rot, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    lib.assign(o, mat)
    return o


def hair_long(mat):
    """Long hair: a cap over the back of the head, one smooth fall down the back, side locks framing the face."""
    h = lib.Blob("Hair", resolution=0.013)
    h.ellipsoid(head(0, 0.035, -0.025), 0.132, 0.152, 0.138)
    h.ellipsoid(head(0.02, 0.095, 0.05), 0.105, 0.055, 0.075, rot=(0, 0, -12))  # swept fringe
    fall = [head(0, -0.05, -0.1)] + [V(*p) for p in ((0.01, 2.0, -0.15), (0.0, 1.78, -0.16), (-0.01, 1.58, -0.14), (-0.015, 1.44, -0.12))]
    widths = [0.11, 0.125, 0.115, 0.08, 0.04]
    for i in range(len(fall) - 1):
        h.capsule(fall[i], fall[i + 1], widths[i] * 0.6, stiff=1.2)
        for sx in (-1, 1):
            h.capsule(fall[i] + V(sx * widths[i] * 0.7, 0, 0.01), fall[i + 1] + V(sx * widths[i + 1] * 0.7, 0, 0.01), widths[i] * 0.4, stiff=1.2)
    for sx in (-1, 1):  # thin tapering locks framing the face
        h.capsule(head(sx * 0.105, 0.05, 0.04), head(sx * 0.112, -0.08, 0.05), 0.02, stiff=1.2)
        h.capsule(head(sx * 0.112, -0.08, 0.05), head(sx * 0.1, -0.2, 0.04), 0.011, stiff=1.2)
    obj = h.to_mesh(voxel=0.009, smooth=4, target_tris=9000)
    lib.assign(obj, mat)
    return [obj]
