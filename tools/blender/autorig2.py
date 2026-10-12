"""Auto-rig v2 for AI-generated characters (CPU only): region skinning + hand-tuned procedural animation.
~/.local/bin/blender -b -P tools/blender/autorig2.py -- in.glb out.glb biped|fairy|mermaid [preview_prefix]

Why v2: AI meshes come in thousands of fragments, so Blender's bone-heat weighting fails or smears limbs together.
Here each bone may only move its own body region (a leg only below the hip and on its side, an arm only out past the
shoulder, a wing only behind/beside the upper back), blended smoothly at the joints. Then:
  biped   walk cycle with swing-leg knee bend, hip bob/sway, counter-rotating shoulders, arm swing with elbow lag
  fairy   hovers; wing bones flap; legs dangle and trail behind when flying; leans into motion
  mermaid floats upright; travelling S-wave down the tail
Actions: Idle, Walk, Run (loops), Attack, Hit (one-shots) -- the names the game plays (monsters/monster_model.gd).
The model faces -Y in Blender (+Z in Godot).
"""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, PROFILE = args[:3]
PREVIEW = args[3] if len(args) > 3 else ""
LEG_AMP = float(args[4]) if len(args) > 4 else 24.0  # thigh swing; lower for long skirts / hakama

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)
VS = body.data.vertices
z0 = min(v.co.z for v in VS)
H = max(v.co.z for v in VS) - z0
cx = sum(v.co.x for v in VS) / len(VS)
cy = sum(v.co.y for v in VS) / len(VS)


def P(fx, fz, fy=0.0):
    return Vector((cx + fx * H, cy + fy * H, z0 + fz * H))


def band(lo, hi):
    return [v.co for v in VS if z0 + lo * H <= v.co.z <= z0 + hi * H]


def pct(vals, p):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, int(p * len(vals)))] if vals else 0.0


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))) if b != a else float(x >= b)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- proportions from the mesh
torso_w = max(0.06 * H, pct([abs(v.x - cx) for v in band(0.62, 0.72)], 0.6))  # half-width of the ribcage
hip_w = max(0.05 * H, pct([abs(v.x - cx) for v in band(0.44, 0.5)], 0.55))
SH_Z, HIP_Z, KNEE_Z, NECK_Z = 0.78, 0.5, 0.27, 0.83
if PROFILE == "fairy":  # fairies are drawn with long legs and a high waist
    HIP_Z, KNEE_Z = 0.53, 0.29

J = {
    "root": P(0, 0), "hips": P(0, HIP_Z), "spine": P(0, 0.6), "chest": P(0, 0.7), "neck": P(0, NECK_Z),
    "head": P(0, 0.87), "head_end": P(0, 1.0),
}
for s, sx in (("L", -1), ("R", 1)):
    sh = P(sx * (torso_w / H) * 0.85, SH_Z)
    arm_vs = [v for v in band(0.4, SH_Z) if (v.x - cx) * sx > torso_w * 1.05]
    hand = (sum(arm_vs, Vector()) / len(arm_vs)) if arm_vs else sh + Vector((sx * 0.08 * H, 0, -0.3 * H))
    if arm_vs:  # the hand is the far/low end of the arm
        far = sorted(arm_vs, key=lambda v: -((v - sh).length))[: max(1, len(arm_vs) // 12)]
        hand = sum(far, Vector()) / len(far)
    J["shoulder." + s] = sh
    J["elbow." + s] = sh.lerp(hand, 0.5) + Vector((0, 0.015 * H, 0))
    J["hand." + s] = hand
    J["hand_end." + s] = hand + (hand - sh).normalized() * 0.07 * H
    lx = sx * hip_w * 0.55
    J["hip." + s] = Vector((cx + lx, cy, z0 + HIP_Z * H))
    J["knee." + s] = Vector((cx + lx * 1.05, cy - 0.01 * H, z0 + KNEE_Z * H))
    J["ankle." + s] = Vector((cx + lx * 1.1, cy, z0 + 0.05 * H))
    J["toe." + s] = Vector((cx + lx * 1.1, cy - 0.07 * H, z0 + 0.0))
    if PROFILE == "fairy":  # wings: from the shoulder blades out to the far tip of the wing mass
        wing_vs = [v.co for v in VS if (v.co.x - cx) * sx > torso_w * 1.25 and v.co.z > z0 + 0.55 * H and v.co.y > cy - 0.03 * H]
        tip = max(wing_vs, key=lambda v: abs(v.x - cx)) if wing_vs else P(sx * 0.35, 0.85, 0.1)
        root = P(sx * 0.05, 0.74, 0.06)
        J["wing." + s] = root
        J["wing_mid." + s] = root.lerp(tip, 0.45)
        J["wing_tip." + s] = tip
if PROFILE == "mermaid":
    for i in range(7):
        J["tail%d" % i] = P(0, HIP_Z - i * (HIP_Z / 6.0) + (0.02 if i == 6 else 0.0))

# ---------------------------------------------------------------- armature
arm = bpy.data.armatures.new("rig")
rig = bpy.data.objects.new("rig", arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.edit_bones
REGION = {}  # bone -> region tag used by the skinning gates


def bone(name, a, b, parent=None, connect=False, region="torso"):
    e = eb.new(name)
    e.head, e.tail = J[a], J[b]
    e.roll = 0.0
    if parent:
        e.parent = eb[parent]
        e.use_connect = connect
    REGION[name] = region
    return e


r = eb.new("root")
r.head, r.tail = J["root"], J["root"] + Vector((0, 0, 0.15 * H))
r.use_deform = False
bone("hips", "hips", "spine", "root")
bone("spine", "spine", "chest", "hips", True)
bone("chest", "chest", "neck", "spine", True)
bone("neck", "neck", "head", "chest", True)
bone("head", "head", "head_end", "neck", True, "head")
for s in "LR":
    bone("upperarm." + s, "shoulder." + s, "elbow." + s, "chest", False, "arm" + s)
    bone("forearm." + s, "elbow." + s, "hand." + s, "upperarm." + s, True, "arm" + s)
    bone("hand." + s, "hand." + s, "hand_end." + s, "forearm." + s, True, "arm" + s)
    if PROFILE != "mermaid":
        bone("thigh." + s, "hip." + s, "knee." + s, "hips", False, "leg" + s)
        bone("shin." + s, "knee." + s, "ankle." + s, "thigh." + s, True, "leg" + s)
        bone("foot." + s, "ankle." + s, "toe." + s, "shin." + s, True, "leg" + s)
    if PROFILE == "fairy":
        bone("wing." + s, "wing." + s, "wing_mid." + s, "chest", False, "wing" + s)
        bone("wing_tip." + s, "wing_mid." + s, "wing_tip." + s, "wing." + s, True, "wing" + s)
if PROFILE == "mermaid":
    prev = "hips"
    for i in range(6):
        bone("tail%d" % i, "tail%d" % i, "tail%d" % (i + 1), prev, i > 0, "tail")
        prev = "tail%d" % i
SEG = {b.name: (b.head.copy(), b.tail.copy()) for b in eb if b.use_deform}
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- region skinning


def seg_d(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
    return (p - (a + ab * t)).length


def gates(p):
    """How much each region is allowed to own this vertex (0..1)."""
    dx = p.x - cx
    h = (p.z - z0) / H
    g = {"torso": 1.0, "head": smooth(NECK_Z - 0.02, NECK_Z + 0.03, h), "tail": 0.0}
    for s, sx in (("L", -1), ("R", 1)):
        side = smooth(-0.01 * H, 0.02 * H, dx * sx)
        out = abs(dx)
        g["arm" + s] = side * smooth(torso_w * 0.9, torso_w * 1.2, out) * smooth(0.25, 0.35, h) * (1.0 - smooth(SH_Z + 0.03, SH_Z + 0.08, h))
        g["leg" + s] = side * (1.0 - smooth(HIP_Z - 0.06, HIP_Z + 0.01, h)) * (1.0 - smooth(hip_w * 1.3, hip_w * 1.8, out))
        if PROFILE == "fairy":
            behind = smooth(cy - 0.05 * H, cy + 0.02 * H, p.y)
            g["wing" + s] = side * smooth(torso_w * 0.95, torso_w * 1.6, out) * smooth(0.52, 0.6, h) * max(behind, smooth(torso_w * 1.6, torso_w * 2.4, out))
            g["arm" + s] *= 1.0 - g["wing" + s]
    if PROFILE == "mermaid":
        g["tail"] = 1.0 - smooth(HIP_Z - 0.04, HIP_Z + 0.02, h)
    return g


groups = {n: body.vertex_groups.new(name=n) for n in SEG}
for v in VS:
    p = v.co
    g = gates(p)
    ws = []
    for n, (a, b) in SEG.items():
        gate = g[REGION[n]]
        if REGION[n] == "torso":  # torso bones give way to the limbs where those own the vertex
            limb = max([g[k] for k in g if k not in ("torso", "head")] + [0.0])
            gate = 1.0 - limb * 0.97
        if gate <= 0.001:
            continue
        ws.append((gate / (seg_d(p, a, b) / H + 0.015) ** 4, n))
    ws.sort(reverse=True)
    ws = ws[:4]
    tot = sum(w for w, _ in ws) or 1.0
    for w, n in ws:
        groups[n].add([v.index], w / tot, "REPLACE")
body.parent = rig
mod = body.modifiers.new("rig", "ARMATURE")
mod.object = rig
print("SKINNED", len(VS), "verts,", len(SEG), "bones, profile", PROFILE)

# ---------------------------------------------------------------- animation
pb = rig.pose.bones
for p in pb:
    p.rotation_mode = "XYZ"
R = math.radians
TAU = 2 * math.pi


def key(frame, poses, lift=0.0, fwd=0.0):
    for p in pb:
        e = poses.get(p.name, (0, 0, 0))
        p.rotation_euler = (R(e[0]), R(e[1]), R(e[2]))
        p.keyframe_insert("rotation_euler", frame=frame)
    pb["root"].location = (0, lift * H, -fwd * H)  # root points up: local Y = world up, local Z = world -forward
    pb["root"].keyframe_insert("location", frame=frame)


def action(name, frames, fn, loop=True):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for f in range(0, frames + 1):
        poses, lift, fwd = fn(f / frames)
        key(f + 1, poses, lift, fwd)
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 1, act)
    rig.animation_data.action = None


def legs_walk(ph, amp, run=False):
    """One leg pair. Angles: +X tips a down-pointing bone backward (foot goes behind)."""
    out = {}
    for s, off in (("L", 0.0), ("R", math.pi)):
        a = ph + off
        swing = math.cos(a)  # > 0 while the leg swings forward
        out["thigh." + s] = (-amp * math.sin(a), 0, 0)
        out["shin." + s] = ((70 if run else 55) * max(0.0, swing) ** 2 + 6, 0, 0)
        out["foot." + s] = (-12 * math.sin(a) - 8 * max(0.0, swing), 0, 0)
    return out


def arms_swing(ph, amp, bend=18):
    out = {}
    for s, off, sx in (("L", math.pi, -1), ("R", 0.0, 1)):
        a = ph + off
        out["upperarm." + s] = (-amp * math.sin(a), 0, sx * 6)
        out["forearm." + s] = (-(bend + 12 * max(0.0, -math.sin(a))), 0, 0)
        out["hand." + s] = (-5, 0, 0)
    return out


def biped_cycle(t, amp, run=False):
    ph = TAU * t
    p = legs_walk(ph, amp, run)
    p.update(arms_swing(ph, amp * 0.8, 30 if run else 15))
    lean = 10 if run else 3
    p["hips"] = (0, 5 * math.sin(ph), 2 * math.sin(ph))
    p["spine"] = (lean * 0.5, -4 * math.sin(ph), 0)
    p["chest"] = (lean * 0.5, -6 * math.sin(ph), -2 * math.sin(ph))
    p["head"] = (-lean * 0.6, 4 * math.sin(ph), 0)
    lift = (0.022 if run else 0.012) * math.cos(2 * ph) - (0.03 if run else 0.012)
    return p, lift, 0.0


def biped_idle(t):
    b = math.sin(TAU * t)
    p = {"spine": (1.5 * b, 0, 0), "chest": (1.5 * b, 0, 0), "head": (-b, 2 * math.sin(TAU * t * 2 + 1), 0)}
    for s, sx in (("L", -1), ("R", 1)):
        p["upperarm." + s] = (2 * b, 0, sx * 5)
        p["forearm." + s] = (-10, 0, 0)
        p["thigh." + s] = (0, 0, sx * 1.5)
        p["shin." + s] = (3, 0, 0)
    return p, 0.004 * b - 0.004, 0.0


def wings(t, rate, amp, base=0.0):
    a = math.sin(TAU * t * rate)
    lag = math.sin(TAU * t * rate - 0.9)
    p = {}
    for s, sx in (("L", -1), ("R", 1)):
        p["wing." + s] = (0, sx * (base + 8 * a), sx * amp * a)
        p["wing_tip." + s] = (0, 0, sx * amp * 0.6 * lag)
    return p


def fairy_hover(t, speed):
    """speed 0 = hovering, 1 = flying fast. Legs dangle with lag; body tilts into the flight."""
    ph = TAU * t
    lean = 6 + 22 * speed
    p = wings(t, 2 if speed < 0.5 else 3, 22 + 14 * speed, base=-6 * speed)
    p["hips"] = (lean * 0.4, 0, 3 * math.sin(ph))
    p["spine"] = (lean * 0.3, 0, 0)
    p["chest"] = (lean * 0.3, 0, -2 * math.sin(ph))
    p["head"] = (-lean * 0.7, 3 * math.sin(ph), 0)
    for s, sx, off in (("L", -1, 0.0), ("R", 1, 1.3)):
        d = math.sin(ph + off)
        p["thigh." + s] = (12 + 25 * speed + 5 * d, 0, sx * 2)        # legs trail back as she flies
        p["shin." + s] = (18 + 10 * speed + 8 * max(0.0, d), 0, 0)    # knees soft, a little kick
        p["foot." + s] = (35, 0, 0)                                   # toes pointed
        p["upperarm." + s] = (-8 + 6 * d - 10 * speed, 0, sx * (14 + 6 * speed))
        p["forearm." + s] = (-25, 0, 0)
    lift = 0.06 + 0.025 * math.sin(2 * ph)  # off the ground, bobbing with each wingbeat pair
    return p, lift, 0.0


def tail(t, amp, speed=1.0):
    return {"tail%d" % i: (amp * (0.35 + i * 0.22) * math.sin(TAU * t * speed - i * 0.85), 0,
                           amp * 0.35 * (0.3 + i * 0.15) * math.sin(TAU * t * speed - i * 0.85 + 1.2)) for i in range(6)}


def mermaid(t, amp, lean):
    ph = TAU * t
    p = tail(t, amp)
    p["hips"] = (lean, 0, 2 * math.sin(ph))
    p["chest"] = (lean * 0.4, -3 * math.sin(ph), 0)
    p["head"] = (-lean, 2 * math.sin(ph), 0)
    for s, sx in (("L", -1), ("R", 1)):
        p["upperarm." + s] = (4 * math.sin(ph + (0 if s == "L" else math.pi)) - lean * 0.5, 0, sx * 12)
        p["forearm." + s] = (-20, 0, 0)
    return p, 0.03 + 0.015 * math.sin(ph), 0.0


def attack(t):
    w = smooth(0.0, 0.35, t)
    k = smooth(0.35, 0.5, t)
    back = smooth(0.6, 1.0, t)
    amt = (w - 1.8 * k) * (1 - back)
    p = {"chest": (amt * 8, amt * 22, 0), "spine": (amt * 5, amt * 10, 0), "head": (-amt * 4, -amt * 10, 0),
         "upperarm.R": (amt * 75, 0, 20), "forearm.R": (-35 * (1 - k), 0, 0), "upperarm.L": (-amt * 20, 0, -12)}
    if PROFILE == "biped":
        p.update({"thigh.L": (-amt * 18, 0, 0), "shin.L": (8, 0, 0), "thigh.R": (amt * 12, 0, 0), "shin.R": (abs(amt) * 12, 0, 0)})
        return p, -0.01 * abs(amt), -min(0.0, amt) * 0.05
    if PROFILE == "fairy":
        p.update(wings(t, 4, 35, base=-15 * abs(amt)))
        p.update({"thigh.L": (25, 0, 0), "thigh.R": (35, 0, 0), "shin.L": (30, 0, 0), "shin.R": (20, 0, 0), "foot.L": (35, 0, 0), "foot.R": (35, 0, 0)})
        return p, 0.06, -min(0.0, amt) * 0.08
    p.update(tail(t, 22))
    return p, 0.03, -min(0.0, amt) * 0.05


def hit(t):
    a = math.sin(math.pi * smooth(0.0, 0.6, t)) * (1 - smooth(0.6, 1.0, t))
    p = {"spine": (-a * 12, 0, 0), "chest": (-a * 10, 0, a * 5), "head": (-a * 16, 0, -a * 6)}
    for s, sx in (("L", -1), ("R", 1)):
        p["upperarm." + s] = (-a * 18, 0, sx * (8 + a * 22))
        p["forearm." + s] = (-20 - a * 25, 0, 0)
    if PROFILE == "biped":
        p.update({"thigh.L": (a * 3, 0, 0), "thigh.R": (-a * 2, 0, 0), "shin.L": (a * 6, 0, 0), "shin.R": (a * 4, 0, 0)})
        return p, -a * 0.015, a * 0.05
    if PROFILE == "fairy":
        p.update(wings(t, 2, 15, base=10 * a))
        p.update({"thigh.L": (25 - a * 30, 0, 0), "thigh.R": (25 - a * 25, 0, 0), "shin.L": (20 + a * 20, 0, 0), "shin.R": (20 + a * 25, 0, 0)})
        return p, 0.06, a * 0.07
    p.update(tail(t, 25 * a, 1.5))
    return p, 0.03, a * 0.05


if PROFILE == "biped":
    action("Idle", 60, biped_idle)
    action("Walk", 32, lambda t: biped_cycle(t, LEG_AMP))
    action("Run", 20, lambda t: biped_cycle(t, LEG_AMP * 1.45, True))
elif PROFILE == "fairy":
    action("Idle", 60, lambda t: fairy_hover(t, 0.0))
    action("Walk", 30, lambda t: fairy_hover(t, 0.55))
    action("Run", 20, lambda t: fairy_hover(t, 1.0))
else:
    action("Idle", 60, lambda t: mermaid(t, 8, 2))
    action("Walk", 32, lambda t: mermaid(t, 16, 6))
    action("Run", 22, lambda t: mermaid(t, 24, 12))
action("Attack", 24, attack, loop=False)
action("Hit", 18, hit, loop=False)

# ---------------------------------------------------------------- preview: side and front of each pose (CPU Cycles)
if PREVIEW:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 8
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 300, 400
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.72, 0.72, 0.75, 1)
    sc.world = w
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    tgt = Vector((cx, cy, z0 + 0.5 * H))
    for tr in rig.animation_data.nla_tracks:
        tr.mute = True
    for name, act, fr in [("idle", "Idle", 15), ("walk1", "Walk", 1), ("walk2", "Walk", 9), ("walk3", "Walk", 17), ("run", "Run", 6),
                          ("attack", "Attack", 11), ("hit", "Hit", 8)]:
        rig.animation_data.action = bpy.data.actions[act]
        sc.frame_set(fr)
        for view, off in (("side", Vector((2.6 * H, 0, 0.15 * H))), ("front", Vector((0.9 * H, -2.4 * H, 0.2 * H)))):
            cam.location = tgt + off
            cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = "%s_%s_%s.png" % (PREVIEW, name, view)
            bpy.ops.render.render(write_still=True)
    rig.animation_data.action = None
    for tr in rig.animation_data.nla_tracks:
        tr.mute = False

bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_yup=True, export_apply=False)
print("RIGGED", DST)
