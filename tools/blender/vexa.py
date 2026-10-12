"""Vexa: dusk demoness (ghost, duelist). Stylized monster girl in the spirit of the PS2 Monster Rancher
monster girls, in HD: MPFB adult body pushed toward anime proportions, flat bold colors (no photo skin),
chunky spiky hair, a plunging high-cut one-piece, fur cuffs, clawed feet, horns, bat wings, spade tail.
Original design (not a copy of any MR monster).

~/.local/bin/blender -b --python-exit-code 1 -P tools/blender/vexa.py -- --render /tmp/vexa --export assets/models/vexa.glb
Hard line: nipples and groin always covered. No nudity.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import human  # noqa: E402
import lib  # noqa: E402
from lib import V, seg_dist  # noqa: E402
from mathutils import Vector  # noqa: E402

lib.reset()
a = lib.args()


def B(g):
    return V(g.x, g.y, g.z)


def G(x, y, z):
    return Vector((x, y, z))


SIDES = ("l", "r")
POSE = {
    "upperleg01.L": ("aim", (-0.07, -1.0, 0.0)),
    "upperleg01.R": ("aim", (0.06, -1.0, 0.28)),
    "lowerleg01.R": ("aim", (-0.08, -1.0, -0.2)),
    "foot.R": ("aim", (0.0, -0.75, 0.66)),
    "upperarm01.L": ("aim", (0.45, 0.85, -0.12)),
    "lowerarm01.L": ("aim", (-0.75, 0.25, -0.3)),
    "upperarm01.R": ("aim", (-0.55, -0.8, -0.22)),
    "lowerarm01.R": ("aim", (0.78, -0.52, 0.12)),
}
targets = {
    # figure
    "measure-bust-circ-incr": 0.8, "measure-underbust-circ-decr": 0.4, "breast-volume-vert-up": 0.5,
    "breast-dist-decr": 0.35, "measure-waist-circ-decr": 1.0, "stomach-pregnant-decr": 0.5,
    "hip-scale-horiz-incr": 0.5, "measure-hips-circ-incr": 0.5, "buttocks-volume-incr": 0.9,
    "upperlegs-height-incr": 0.6, "lowerlegs-height-incr": 0.5, "torso-vshape-decr": 0.4,
    # anime face: V jaw, small nose and mouth, full lower lip
    "head-invertedtriangular": 0.7, "chin-triangle": 0.6, "chin-width-decr": 0.4,
    "nose-scale-horiz-decr": 0.6, "nose-scale-vert-decr": 0.5, "nose-volume-decr": 0.6, "nose-point-up": 0.4,
    "mouth-scale-horiz-decr": 0.4, "mouth-lowerlip-volume-incr": 0.5, "mouth-angles-up": 0.3,
}
for s in SIDES:
    targets.update({f"{s}-ear-shape-pointed": 1.0, f"{s}-ear-scale-incr": 1.0, f"{s}-ear-rot-backward": 0.6,
                    f"{s}-eye-scale-incr": 1.0, f"{s}-eye-corner2-up": 0.6})
body, J, extra = human.make(
    {"gender": 0.0, "age": 0.55, "muscle": 0.4, "weight": 0.42, "proportions": 1.0, "height": 0.9,
     "cupsize": 1.0, "firmness": 1.0}, targets, height=2.4, pose=POSE,
    assets=[("eyebrows/eyebrow010/eyebrow010.mhclo", "Eyebrows", "eyebrows/eyebrow010/eyebrow010.png"),
            ("eyelashes/eyelashes03/eyelashes03.mhclo", "Eyelashes", "eyelashes/eyelashes03/eyelashes03.png")])
parts = [body] + list(extra.values())

# Flat, bold palette (materials AFTER the body: MPFB cleans up unused materials while building it)
skin = lib.material("skin", (0.62, 0.55, 0.72), rough=0.45)
suit = lib.material("plate", (0.015, 0.012, 0.02), rough=0.22, metal=0.1)
hair = lib.material("hair", (0.45, 0.06, 0.42), rough=0.35)
fur = lib.material("fur", (0.75, 0.12, 0.55), rough=0.8)
bone = lib.material("bone", (0.12, 0.1, 0.12), rough=0.35)
wing = lib.material("wing", (0.22, 0.04, 0.26), rough=0.55)
glow = lib.material("glow", (0.9, 0.25, 0.8), emit=6.0)
eye = lib.material("eye", (1.0, 0.55, 0.95), emit=10.0)
lib.assign(body, skin)

eye_mid = (J["l-eye"] + J["r-eye"]) * 0.5
e = (J["l-eye"] - J["r-eye"]).length
cups = [human.bust_apex(body, 1), human.bust_apex(body, -1)]
crotch = (J["l-upper-leg"].y + J["r-upper-leg"].y) * 0.5 - 0.09
navel = crotch + 0.3


def on_arm(p):
    return any(min(seg_dist(p, J[f"{s}-shoulder"], J[f"{s}-elbow"]), seg_dist(p, J[f"{s}-elbow"], J[f"{s}-hand"])) < 0.075 for s in SIDES)


def leotard(x, y, z):
    """Plunging, high-cut, open-back one-piece. The plunge stays narrower than the bust, so the chest is covered."""
    p = G(x, y, z)
    if on_arm(p):
        return False
    top = max(c.y for c in cups) + 0.075
    low = crotch - 0.07 + max(0.0, abs(x) - 0.05) * 1.25          # high-cut leg openings
    if not (low < y < top):
        return False
    if z < -0.02 and y > crotch + 0.22:                             # open back
        return False
    if z > 0.0 and y > navel:                                       # plunge: a narrow V down to the navel
        if abs(x) < 0.012 + (y - navel) * 0.12:
            return False
    if y > min(c.y for c in cups) + 0.02 and abs(x) > 0.17:         # cut away under the arms
        return False
    return True


parts.append(lib.shell(body, "leotard", suit, leotard, thick=0.006, offset=0.002))
for c in cups:  # halter straps up to the neck
    parts.append(lib.tube("halter", lib.curve_pts([B(c + G(0.02 if c.x > 0 else -0.02, 0.07, -0.01)), B(J["neck"] + G(0.04 if c.x > 0 else -0.04, -0.01, 0.025))], 8), [0.006] * 8, suit, seg=6))
parts.append(lib.tube("neck_ring", [B(J["neck"] + G(0.055 * math.cos(t / 12 * 6.283), -0.01, 0.05 * math.sin(t / 12 * 6.283))) for t in range(13)], [0.008] * 13, glow, seg=6, cap=False))

# big glowing anime eyes in the sockets
for s in SIDES:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=e * 0.23, location=B(J[f"{s}-eye"] + G(0, 0, -0.004)))
    o = bpy.context.active_object
    o.name = f"eyeball_{s}"
    bpy.ops.object.shade_smooth()
    lib.assign(o, eye)
    parts.append(o)

# chunky spiky hair
scalp = B(eye_mid + G(0, 0.85 * e, -1.05 * e))
parts.append(lib.spiky_hair("hair", hair, scalp, 1.55 * e, n=26, length=1.1))

# fur cuffs at wrists and ankles, claws on the feet
for s in SIDES:
    wr, el = J[f"{s}-hand"], J[f"{s}-elbow"]
    parts.append(lib.fur_ring(f"cuff_w{s}", fur, B(el.lerp(wr, 0.85)), B(wr) - B(el), 0.045))
    ank, kn = J[f"{s}-ankle"], J[f"{s}-knee"]
    parts.append(lib.fur_ring(f"cuff_a{s}", fur, B(ank + G(0, 0.07, 0)), B(ank) - B(kn), 0.055, n=18))
    for k in range(1, 6):
        tip_keys = [kk for kk in J if kk.startswith(f"{s}-toe-{k}-")]
        if not tip_keys:
            continue
        tip = J[max(tip_keys)]
        parts.append(lib.tube(f"claw{s}{k}", lib.curve_pts([B(tip + G(0, 0.005, -0.01)), B(tip + G(0, 0.0, 0.035)), B(tip + G(0, -0.025, 0.06))], 6), [0.011, 0.01, 0.008, 0.005, 0.002, 0.0], bone, seg=6))

# swept horns
for sx in (-1, 1):
    root = eye_mid + G(sx * 0.65 * e, 1.3 * e, -0.2 * e)
    ctrl = [root, root + G(sx * 0.55 * e, 1.1 * e, -0.5 * e), root + G(sx * 0.95 * e, 1.6 * e, -1.6 * e), root + G(sx * 0.85 * e, 1.4 * e, -2.7 * e)]
    parts.append(lib.tube(f"horn{sx}", lib.curve_pts([B(c) for c in ctrl], 12), [0.33 * e * (1 - i / 11) ** 0.8 for i in range(12)], bone))

# bat wings: dark membrane, glowing finger bones
sc = (J["l-scapula"] + J["r-scapula"]) * 0.5
for sx in (-1, 1):
    root = B(sc + G(sx * 0.06, 0.02, -0.1))
    tips = [B(sc + G(sx * 0.42, 0.5, -0.24)), B(sc + G(sx * 0.78, 0.38, -0.3)), B(sc + G(sx * 0.82, 0.02, -0.28)), B(sc + G(sx * 0.58, -0.3, -0.22))]
    outline = [root, tips[0]]
    for i in range(len(tips) - 1):
        outline.append(tips[i].lerp(tips[i + 1], 0.5).lerp(root, 0.25))
        outline.append(tips[i + 1])
    outline.append(B(sc + G(sx * 0.2, -0.25, -0.14)))
    parts.append(lib.membrane(f"wing{sx}", outline, wing))
    for t in tips:
        parts.append(lib.tube(f"wbone{sx}", lib.curve_pts([root, root.lerp(t, 0.5) + V(0, 0.05, -0.02), t], 6), [0.016, 0.014, 0.012, 0.009, 0.005, 0.002], glow, seg=6))

# tail with a glowing spade
pv = J["pelvis"]
tail = lib.curve_pts([B(pv + G(0, 0.0, -0.13)), B(pv + G(0, -0.2, -0.38)), B(pv + G(0.1, -0.6, -0.55)), B(pv + G(0.27, -0.88, -0.5)), B(pv + G(0.42, -0.82, -0.34))], 16)
parts.append(lib.tube("tail", tail, [0.03 - 0.0015 * i for i in range(16)], skin, seg=8))
end = tail[-1]
d = (tail[-1] - tail[-2]).normalized()
side = d.cross(V(0, 0, 1)).normalized()
parts.append(lib.membrane("spade", [end, end + side * 0.07 - d * 0.03, end + d * 0.16, end - side * 0.07 - d * 0.03], glow, thick=0.012))

if a["render"]:
    lib.render(a["render"], accent=(0.9, 0.3, 0.8))
if a["export"]:
    lib.export(a["export"], parts)
