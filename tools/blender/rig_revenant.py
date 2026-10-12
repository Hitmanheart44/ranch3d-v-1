"""The Revenant: a reaper spirit possessing a dead body. Its cloak, hood and scythe float; the corpse's legs hang limp
and drag behind it along the ground (toes trailing), further back the faster it moves. CPU only.
~/.local/bin/blender -b -P tools/blender/rig_revenant.py -- in.glb out.glb [preview_prefix]
Leg pieces are found by position (the corpse's legs hang under the hood); everything else rides on the body bone.
Actions: Idle, Walk, Run, Attack, Hit (same names as tools/blender/autorig.py, so the game plays them the same way).
"""
import math
import sys

import bmesh
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = args[:2]
PREVIEW = args[2] if len(args) > 2 else ""
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = body
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)

# ---------------------------------------------------------------- find the legs (islands inside the leg box)
bm = bmesh.new()
bm.from_mesh(body.data)
bm.verts.ensure_lookup_table()
seen, legs = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    stack, comp = [v], []
    seen.add(v.index)
    while stack:
        a = stack.pop()
        comp.append(a)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b.index not in seen:
                seen.add(b.index)
                stack.append(b)
    xs = [c.co.x for c in comp]
    ys = [c.co.y for c in comp]
    zs = [c.co.z for c in comp]
    if min(xs) > -0.32 and max(xs) < 0.03 and min(ys) > 1.58 and max(ys) < 2.1 and max(zs) < 1.36:
        legs.extend(c.index for c in comp)
leg_set = set(legs)
LV = [body.data.vertices[i].co for i in leg_set]
hip_z = max(v.z for v in LV) - 0.05
knee_z = hip_z * 0.5
cy = sum(v.y for v in LV) / len(LV)
split_x = sum(v.x for v in LV) / len(LV)
side = {i: ("L" if body.data.vertices[i].co.x < split_x else "R") for i in leg_set}
cx = {s: sum(body.data.vertices[i].co.x for i in leg_set if side[i] == s) / max(1, sum(1 for i in leg_set if side[i] == s)) for s in "LR"}
print("LEGS verts %d hip %.2f knee %.2f split %.3f" % (len(leg_set), hip_z, knee_z, split_x))

# ---------------------------------------------------------------- armature
arm = bpy.data.armatures.new("rig")
rig = bpy.data.objects.new("rig", arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.edit_bones
root = eb.new("root")
root.head, root.tail = Vector((split_x, cy, 0)), Vector((split_x, cy, 0.3))
root.use_deform = False
b = eb.new("body")
b.head, b.tail = Vector((split_x, cy, hip_z)), Vector((split_x, cy, hip_z + 0.8))
b.parent = root
for s in "LR":
    t = eb.new("thigh." + s)
    t.head, t.tail = Vector((cx[s], cy, hip_z)), Vector((cx[s], cy, knee_z))
    t.parent = b
    sh = eb.new("shin." + s)
    sh.head, sh.tail = Vector((cx[s], cy, knee_z)), Vector((cx[s], cy, 0.02))
    sh.parent = t
    sh.use_connect = True
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- weights (rigid body, legs blend at the knee)
groups = {n: body.vertex_groups.new(name=n) for n in ["body", "thigh.L", "shin.L", "thigh.R", "shin.R"]}
for v in body.data.vertices:
    if v.index not in leg_set:
        groups["body"].add([v.index], 1.0, "REPLACE")
        continue
    s = side[v.index]
    k = min(1.0, max(0.0, (v.co.z - (knee_z - 0.08)) / 0.16))  # 1 = thigh, 0 = shin
    if k > 0:
        groups["thigh." + s].add([v.index], k, "REPLACE")
    if k < 1:
        groups["shin." + s].add([v.index], 1 - k, "REPLACE")
body.parent = rig
mod = body.modifiers.new("rig", "ARMATURE")
mod.object = rig

# ---------------------------------------------------------------- actions
pb = rig.pose.bones
for p in pb:
    p.rotation_mode = "XYZ"
R = math.radians
L = hip_z  # leg length (hip to ground)


def key(frame, trail_l, trail_r, shin_l, shin_r, lean, lift, sway=0.0):
    """trail: degrees the legs swing back (feet toward +Y, behind the model, which faces -Y)."""
    for p in pb:
        p.rotation_euler = (0, 0, 0)
    pb["thigh.L"].rotation_euler = (R(trail_l), 0, R(sway))
    pb["thigh.R"].rotation_euler = (R(trail_r), 0, R(-sway))
    pb["shin.L"].rotation_euler = (R(shin_l), 0, 0)
    pb["shin.R"].rotation_euler = (R(shin_r), 0, 0)
    pb["body"].rotation_euler = (R(lean), 0, 0)  # leans forward into the move
    # lower the whole thing so the toes stay on the ground however far back the legs trail
    t = R((trail_l + trail_r) / 2.0)
    sh = R((shin_l + shin_r) / 2.0)
    foot = L * 0.5 * math.cos(t) + L * 0.5 * math.cos(t + sh)  # how far below the hip the toes hang
    drop = max(0.0, L - foot - 0.03)
    pb["root"].location = (0, lift - drop, 0)  # root points up: its local Y is world Z
    for p in pb:
        p.keyframe_insert("rotation_euler", frame=frame)
    pb["root"].keyframe_insert("location", frame=frame)


def action(name, frames, fn, loop=True):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    step = 2 if frames > 20 else 1
    for f in range(0, frames + 1, step):
        key(f + 1, *fn(f / frames))
    if loop:
        key(frames + 1, *fn(0.0))
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 1, act)
    rig.animation_data.action = None


def idle(t):  # hovering, legs hanging a little back, swaying like dead weight
    s = math.sin(2 * math.pi * t)
    return 18 + s * 4, 21 - s * 4, -10 + s * 3, -12 - s * 3, 4, 0.04 + s * 0.02, s * 2


def drag(t, back):  # moving: thighs dragged out behind, shins hanging so the toes scrape, knees knocking loosely
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    return back + s * 5, back + 3 - s * 5, -back * 0.75 + abs(c) * 8, -back * 0.7 + abs(s) * 8, 10 + back * 0.12, 0.0, s * 3


def attack(t):  # lunges with the scythe; the corpse's legs flop after it
    w = math.sin(math.pi * min(1, t / 0.5))
    return 30 + w * 25, 34 + w * 20, -15 + w * 30, -12 + w * 30, 8 + w * 22, 0.1 * w, 0


def hit(t):  # jolted back: legs swing forward under it, then fall back
    a = math.sin(math.pi * min(1, t / 0.6)) * (1 - max(0, t - 0.6) / 0.4)
    return 20 - a * 40, 22 - a * 36, -10 + a * 25, -12 + a * 30, 4 - a * 18, 0.08 * a, a * 6


action("Idle", 60, idle)
action("Walk", 30, lambda t: drag(t, 45))
action("Run", 20, lambda t: drag(t, 60))
action("Attack", 24, attack, loop=False)
action("Hit", 18, hit, loop=False)

if PREVIEW:  # side view of each pose (CPU Cycles)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 8
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 360, 420
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.75, 0.78, 1)
    sc.world = w
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    tgt = Vector((split_x, cy - 0.6, 1.0))
    cam.location = tgt + Vector((5.2, 0.3, 0.6))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    for tr in rig.animation_data.nla_tracks:
        tr.mute = True
    for name, act, fr in [("idle", "Idle", 1), ("walk", "Walk", 8), ("run", "Run", 6), ("attack", "Attack", 12), ("hit", "Hit", 8)]:
        rig.animation_data.action = bpy.data.actions[act]
        sc.frame_set(fr)
        sc.render.filepath = PREVIEW + "_" + name + ".png"
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action = None
    for tr in rig.animation_data.nla_tracks:
        tr.mute = False

bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_skins=True, export_yup=True, export_apply=False)
print("RIGGED", DST)
