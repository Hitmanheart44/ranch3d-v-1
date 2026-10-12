"""Auto-rig an AI-generated model and give it animations (CPU only).
~/.local/bin/blender -b -P tools/blender/autorig.py -- in.glb out.glb biped|mermaid [preview_prefix]

Joints come from standard proportions refined by slicing the mesh (where the arms, legs and torso actually are),
weights from Blender's bone-heat (falls back to envelopes), then procedural keyframed actions:
Idle, Walk, Run (loops), Attack, Hit (one-shots). Exported as glTF actions; Godot plays them via MonsterModel.
The model faces -Y (Blender) = +Z (Godot), as everywhere in the pipeline.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, PROFILE = args[:3]
PREVIEW = args[3] if len(args) > 3 else ""
FPS = 30

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
for o in list(bpy.context.scene.objects):  # drop import empties
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)
V = [body.matrix_world @ v.co for v in body.data.vertices]
z0 = min(v.z for v in V)
H = max(v.z for v in V) - z0
cx = sum(v.x for v in V) / len(V)
cy = sum(v.y for v in V) / len(V)


def band(lo, hi, side=0):
    """Vertices between heights lo..hi (fractions of H); side -1 = left (x<cx), +1 = right."""
    return [v for v in V if z0 + lo * H <= v.z <= z0 + hi * H and (side == 0 or (v.x - cx) * side > 0)]


def centroid(vs, fallback):
    if not vs:
        return fallback
    return sum(vs, Vector()) / len(vs)


def pct(vals, p):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, int(p * len(vals)))] if vals else 0.0


def at(fx, fz, fy=0.0):
    return Vector((cx + fx * H, cy + fy * H, z0 + fz * H))


# ---------------------------------------------------------------- joints
J = {}
J["root"] = at(0, 0.0)
J["hips"] = at(0, 0.52)
J["spine"] = at(0, 0.62)
J["chest"] = at(0, 0.72)
J["neck"] = at(0, 0.81)
J["head"] = at(0, 0.86)
J["head_end"] = at(0, 1.0)
for s, name in [(-1, "L"), (1, "R")]:
    torso_w = pct([abs(v.x - cx) for v in band(0.74, 0.79)], 0.7)  # shoulder width from the torso slice
    sh = at(0, 0.79) + Vector((s * max(torso_w * 0.8, 0.07 * H), 0, 0))
    arm = [v for v in band(0.42, 0.76, s) if abs(v.x - cx) > torso_w * 0.95]  # the arm hangs outside the torso
    hand = centroid([v for v in arm if v.z < z0 + 0.56 * H], sh + Vector((s * 0.06 * H, 0, -0.3 * H)))
    hand.y = cy
    J["shoulder." + name] = sh
    J["elbow." + name] = sh.lerp(hand, 0.5) + Vector((0, 0.02 * H, 0))
    J["hand." + name] = hand
    J["hand_end." + name] = hand + (hand - sh).normalized() * 0.07 * H
    if PROFILE == "biped":
        knee_vs = band(0.22, 0.32, s)
        hip = at(s * 0.06, 0.5)
        knee = centroid(knee_vs, at(s * 0.07, 0.27))
        hip.x = cx + (knee.x - cx) * 0.9
        knee.y = cy - 0.01 * H
        ankle = Vector((knee.x, cy, z0 + 0.06 * H))
        J["hip." + name] = hip
        J["knee." + name] = knee
        J["ankle." + name] = ankle
        J["toe." + name] = ankle + Vector((0, -0.08 * H, -0.04 * H))
if PROFILE == "mermaid":  # a tail of segments following the mesh down to the fin
    pts = []
    for i in range(6):
        f = 0.5 - i * 0.09
        pts.append(centroid(band(max(0, f - 0.04), f + 0.04), at(0, f)))
    pts.append(at(0, 0.0, 0.0) + Vector((0, (pts[-1].y - cy), 0)))
    for i, p in enumerate(pts):
        J["tail%d" % i] = p

# ---------------------------------------------------------------- armature
arm_data = bpy.data.armatures.new("rig")
rig = bpy.data.objects.new("rig", arm_data)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones


def bone(name, a, b, parent=None, connect=False):
    e = eb.new(name)
    e.head, e.tail = J[a], J[b]
    e.roll = 0.0
    if parent:
        e.parent = eb[parent]
        e.use_connect = connect
    return e


bone("root", "root", "hips").use_deform = False
eb["root"].tail = J["root"] + Vector((0, 0, 0.15 * H))
bone("hips", "hips", "spine", "root")
bone("spine", "spine", "chest", "hips", True)
bone("chest", "chest", "neck", "spine", True)
bone("neck", "neck", "head", "chest", True)
bone("head", "head", "head_end", "neck", True)
for n in "LR":
    bone("upperarm." + n, "shoulder." + n, "elbow." + n, "chest")
    bone("forearm." + n, "elbow." + n, "hand." + n, "upperarm." + n, True)
    bone("hand." + n, "hand." + n, "hand_end." + n, "forearm." + n, True)
    if PROFILE == "biped":
        bone("thigh." + n, "hip." + n, "knee." + n, "hips")
        bone("shin." + n, "knee." + n, "ankle." + n, "thigh." + n, True)
        bone("foot." + n, "ankle." + n, "toe." + n, "shin." + n, True)
if PROFILE == "mermaid":
    prev = "hips"
    for i in range(6):
        bone("tail%d" % i, "tail%d" % i, "tail%d" % (i + 1), prev, i > 0)
        prev = "tail%d" % i
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- skinning
# AI meshes are not watertight, so bone-heat fails on them directly. Solve it on a voxel-remeshed proxy instead
# and transfer the weights back to the real mesh by nearest surface.
proxy = body.copy()
proxy.data = body.data.copy()
bpy.context.collection.objects.link(proxy)
rm = proxy.modifiers.new("vox", "REMESH")
rm.mode = "VOXEL"
rm.voxel_size = H / 90.0
bpy.context.view_layer.objects.active = proxy
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
bpy.ops.object.modifier_apply(modifier="vox")
proxy.vertex_groups.clear()
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
pw = sum(1 for v in proxy.data.vertices if len(v.groups) > 0)
print("PROXY WEIGHTED %d / %d" % (pw, len(proxy.data.vertices)))
body.vertex_groups.clear()
for g in proxy.vertex_groups:
    body.vertex_groups.new(name=g.name)
dt = body.modifiers.new("dt", "DATA_TRANSFER")
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.context.view_layer.objects.active = body
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.ops.object.modifier_apply(modifier="dt")
bpy.data.objects.remove(proxy)
body.parent = rig
mod = body.modifiers.new("rig", "ARMATURE")
mod.object = rig
weighted = sum(1 for v in body.data.vertices if len(v.groups) > 0)
print("WEIGHTED %d / %d" % (weighted, len(body.data.vertices)))
if weighted < 0.9 * len(body.data.vertices):  # last resort: smooth inverse-distance-to-bone weights
    body.vertex_groups.clear()
    segs = [(b.name, rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local) for b in arm_data.bones if b.use_deform]
    groups = {n: body.vertex_groups.new(name=n) for n, _, _ in segs}

    def seg_d(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
        return (p - (a + ab * t)).length

    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        ds = sorted(((seg_d(p, a, b), n) for n, a, b in segs))[:3]
        ws = [(1.0 / (d / H + 0.02) ** 4, n) for d, n in ds]
        tot = sum(w for w, _ in ws)
        for w, n in ws:
            groups[n].add([v.index], w / tot, "REPLACE")
    print("DISTANCE weights")
# limit to 4 influences and normalize (what game engines expect)
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- animations
pb = rig.pose.bones
for p in pb:
    p.rotation_mode = "XYZ"
R = math.radians


def key(frame, poses, root_z=0.0, root_y=0.0):
    """poses: {bone: (x, y, z) degrees}. Bones not listed return to rest."""
    for p in pb:
        e = poses.get(p.name, (0, 0, 0))
        p.rotation_euler = (R(e[0]), R(e[1]), R(e[2]))
        p.keyframe_insert("rotation_euler", frame=frame)
    pb["root"].location = (0, root_z * H, -root_y * H)  # root bone points up: its local Y is world Z
    pb["root"].keyframe_insert("location", frame=frame)


def action(name, frames, fn, loop=True):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for f in range(0, frames + 1, 2 if frames > 20 else 1):
        poses, rz, ry = fn(f / frames)
        key(f + 1, poses, rz, ry)
    if loop:
        poses, rz, ry = fn(0.0)
        key(frames + 1, poses, rz, ry)
    act.frame_range = (1, frames + 1)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    rig.animation_data.action = None


def tail_wave(t, amp, speed=1.0):
    return {"tail%d" % i: (amp * (0.4 + i * 0.25) * math.sin(2 * math.pi * (t * speed) - i * 0.9), 0, 0) for i in range(6)}


def idle(t):
    b = math.sin(2 * math.pi * t)
    p = {"spine": (b * 2, 0, 0), "chest": (b * 2, 0, 0), "head": (-b * 2, b * 3, 0),
         "upperarm.L": (b * 3, 0, -4), "upperarm.R": (b * 3, 0, 4), "forearm.L": (-6, 0, 0), "forearm.R": (-6, 0, 0)}
    if PROFILE == "mermaid":
        p.update(tail_wave(t, 6))
    return p, abs(b) * 0.004, 0


def walk(t, big=1.0):
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    p = {"hips": (0, 0, s * 5 * big), "chest": (-3 * big, 0, -s * 6 * big), "head": (2, 0, s * 3),
         "upperarm.L": (s * 22 * big, 0, -5), "upperarm.R": (-s * 22 * big, 0, 5),
         "forearm.L": (-12 - max(0, s) * 15 * big, 0, 0), "forearm.R": (-12 - max(0, -s) * 15 * big, 0, 0)}
    if PROFILE == "biped":
        p.update({"thigh.L": (-s * 28 * big, 0, 0), "thigh.R": (s * 28 * big, 0, 0),
                  "shin.L": (max(0, -c) * 40 * big, 0, 0), "shin.R": (max(0, c) * 40 * big, 0, 0),
                  "foot.L": (s * 10, 0, 0), "foot.R": (-s * 10, 0, 0)})
    else:
        p.update(tail_wave(t, 14 * big, 1.0))
    return p, abs(math.sin(2 * math.pi * t)) * 0.025 * big, 0


def run(t):
    p, rz, ry = walk(t, 1.6)
    p["spine"] = (-8, 0, 0)
    return p, rz, ry


def attack(t):  # wind up, strike, recover
    w = min(1, t / 0.35)
    k = max(0, min(1, (t - 0.35) / 0.15))
    r = max(0, (t - 0.6) / 0.4)
    amt = (w - k * 1.8) * (1 - r)
    p = {"chest": (amt * 10, 0, amt * 25), "spine": (amt * 6, 0, amt * 10),
         "upperarm.R": (amt * 70, 0, 15 + amt * 10), "forearm.R": (-30 * (1 - k), 0, 0),
         "upperarm.L": (-amt * 25, 0, -10), "head": (-amt * 5, 0, -amt * 10)}
    if PROFILE == "biped":
        p.update({"thigh.L": (-amt * 15, 0, 0), "thigh.R": (amt * 10, 0, 0), "shin.R": (abs(amt) * 15, 0, 0)})
    else:
        p.update(tail_wave(t, 20, 1.0))
    return p, 0, -min(0, amt) * 0.05


def hit(t):  # recoil back, settle
    a = math.sin(math.pi * min(1, t / 0.6)) * (1 - max(0, t - 0.6) / 0.4)
    p = {"spine": (a * 14, 0, 0), "chest": (a * 12, 0, a * 6), "head": (a * 18, 0, -a * 8),
         "upperarm.L": (-a * 20, 0, -a * 25), "upperarm.R": (-a * 20, 0, a * 25), "forearm.L": (-a * 30, 0, 0), "forearm.R": (-a * 30, 0, 0)}
    if PROFILE == "biped":
        p.update({"thigh.L": (a * 10, 0, 0), "thigh.R": (a * 10, 0, 0), "shin.L": (a * 15, 0, 0), "shin.R": (a * 15, 0, 0)})
    else:
        p.update(tail_wave(t, 18 * a, 1.5))
    return p, -a * 0.02, a * 0.06


action("Idle", 60, idle)
action("Walk", 30, walk)
action("Run", 20, run)
action("Attack", 24, attack, loop=False)
action("Hit", 18, hit, loop=False)

# ---------------------------------------------------------------- preview: a contact sheet of poses
if PREVIEW:  # CPU Cycles, low samples: one 3/4 view per pose
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 12
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 360, 480
    w = bpy.data.worlds.new("w")
    w.color = (0.35, 0.35, 0.4)
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (R(50), 0, R(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    tgt = Vector((cx, cy, z0 + 0.5 * H))
    cam.location = tgt + Vector((1.6 * H, -2.4 * H, 0.35 * H))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    for tr in rig.animation_data.nla_tracks:
        tr.mute = True
    for name, act, frame in [("idle", "Idle", 1), ("walk_a", "Walk", 8), ("walk_b", "Walk", 23), ("attack", "Attack", 9),
                             ("attack2", "Attack", 14), ("hit", "Hit", 8)]:
        rig.animation_data.action = bpy.data.actions[act]
        sc.frame_set(frame)
        sc.render.filepath = PREVIEW + "_" + name + ".png"
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action = None
    for tr in rig.animation_data.nla_tracks:
        tr.mute = False

bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_yup=True, export_apply=False)
print("RIGGED", DST)
