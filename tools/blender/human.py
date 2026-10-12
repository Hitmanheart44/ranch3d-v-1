"""Real human bodies from MPFB (the MakeHuman plugin for Blender) + the MakeHuman CC0 asset packs.

    body, J, extra = human.make(
        {"gender": 0.0, "age": 0.55, ...},                 # macro sliders 0..1
        {"hip-scale-horiz-incr": 0.4},                    # extra shape targets (MPFB data/targets)
        height=2.4,
        pose={"upperarm01.L": ("aim", (0.2, -1, 0))},    # bone -> euler degrees or ("aim", godot dir)
        assets=[("hair/long01/long01.mhclo", "Hair", "hair/long01/toigo_long_01_violet/long01_diffuse_violet.png")],
        skin=("skins/young_caucasian_female/young_lightskinned_female_diffuse.png", (0.8, 0.6, 1.0)))

- gender 0 = female. age 0.5 = 25 years: ALWAYS keep age >= 0.5 (adults only, enforced).
- Asset paths are relative to MPFB's user data dir (where the asset packs were installed).
- Returns the posed, baked body (helpers removed, scaled to `height`, feet on the ground); joint landmarks J in
  GODOT coords (x right, y up, z forward; "l-shoulder", "r-knee", "head", "neck", "l-eye", "upper-teeth"...);
  and extra = {asset name: object}. Materials are simple Principled BSDF with the texture, named by asset kind
  ("skin", "hair", "brows", "lashes"), so glTF export and the Godot material swap stay simple.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.locationservice import LocationService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService

MIN_AGE = 0.5
KIND = {"Hair": "hair", "Eyebrows": "brows", "Eyelashes": "lashes", "Clothes": "cloth"}


def data(rel):
    return os.path.join(LocationService.get_user_data(), rel)


def make(macros, targets=None, height=2.4, pose=None, assets=None, skin=None):
    macro = TargetService.get_default_macro_info_dict()
    for k, v in macros.items():
        macro[k] = v
    macro["age"] = max(MIN_AGE, macro["age"])
    h = HumanService.create_human(macro_detail_dict=macro)
    for name, w in (targets or {}).items():
        path = TargetService.target_full_path(name)
        if path is None:
            raise ValueError("unknown MPFB target: " + name)
        TargetService.load_target(h, path, weight=w)
    TargetService.bake_targets(h)
    for m in list(h.modifiers):
        h.modifiers.remove(m)

    rig = None
    if pose is not None or assets:
        HumanService.add_builtin_rig(h, "default")
        rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")

    extra = {}
    for rel, kind, tex in (assets or []):
        before = set(bpy.data.objects)
        HumanService.add_mhclo_asset(data(rel), h, asset_type=kind, subdiv_levels=0)
        new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        for o in new:
            name = KIND.get(kind, "cloth")
            o.name = name
            _textured(o, name, data(tex), alpha=kind != "Clothes")
            extra[name] = o

    if rig is not None:
        _pose(rig, pose or {})
        for o in [h] + list(extra.values()):
            bpy.context.view_layer.objects.active = o
            for m in list(o.modifiers):
                if m.type == "ARMATURE":
                    bpy.ops.object.modifier_apply(modifier=m.name)
                elif m.type != "MASK":
                    o.modifiers.remove(m)
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        bpy.data.objects.remove(rig)

    J = _joints(h)
    _keep_group(h, "body")
    if skin:
        _textured(h, "skin", data(skin[0]), alpha=False, tint=skin[1])

    k = height / h.dimensions.z
    for o in [h] + list(extra.values()):
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        o.scale = o.scale * k
        o.location = o.location * k
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for p in o.data.polygons:
            p.use_smooth = True
    for key in J:
        J[key] = J[key] * k
    h.name = "body"
    return h, J, extra


def _textured(obj, name, png, alpha=True, tint=None):
    """Replace obj's materials with one simple Principled BSDF using `png` (optionally tinted, baked into a copy)."""
    img = bpy.data.images.load(png, check_existing=True)
    if tint is not None:
        t = img.copy()
        t.name = name + "_tex"
        px = list(t.pixels)
        for i in range(0, len(px), 4):  # mostly desaturate, then tint: keeps skin detail, loses the warm cast
            lum = 0.3 * px[i] + 0.59 * px[i + 1] + 0.11 * px[i + 2]
            for c in range(3):
                px[i + c] = (px[i + c] * 0.3 + lum * 0.7) * tint[c] * 1.15
        t.pixels = px
        t.pack()
        img = t
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45 if alpha else 0.5
    if alpha:
        nt.links.new(tn.outputs["Alpha"], bsdf.inputs["Alpha"])
    obj.data.materials.clear()
    obj.data.materials.append(m)


def _pose(rig, pose):
    """pose = {bone: (x, y, z) euler degrees, or bone: ("aim", (x, y, z)) = point the bone along a Godot-coord
    direction}. List parents before children."""
    for name, rot in pose.items():
        pb = rig.pose.bones[name]
        if rot[0] == "aim":
            g = rot[1]
            want = Vector((g[0], -g[2], g[1])).normalized()
            cur = (pb.tail - pb.head).normalized()
            q = cur.rotation_difference(want).to_matrix().to_4x4()
            loc = pb.matrix.to_translation()
            pb.matrix = Matrix.Translation(loc) @ q @ Matrix.Translation(-loc) @ pb.matrix
        else:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = tuple(math.radians(r) for r in rot)
        bpy.context.view_layer.update()


def _joints(h):
    """Centroid of each joint-* (and teeth helper) vertex group, in Godot coords."""
    idx = {g.index: g.name for g in h.vertex_groups if g.name.startswith("joint-") or g.name in ("helper-upper-teeth", "helper-lower-teeth")}
    sums = {}
    for v in h.data.vertices:
        for g in v.groups:
            if g.group in idx and g.weight > 0.0:
                s = sums.setdefault(idx[g.group], [Vector(), 0])
                s[0] += v.co
                s[1] += 1
    out = {}
    for name, (s, n) in sums.items():
        c = s / n
        key = name[6:] if name.startswith("joint-") else name[7:]
        out[key] = Vector((c.x, c.z, -c.y))  # Blender -> Godot
    return out


def _keep_group(h, group):
    gi = h.vertex_groups[group].index
    inside = [any(g.group == gi and g.weight > 0.0 for g in v.groups) for v in h.data.vertices]
    bm = bmesh.new()
    bm.from_mesh(h.data)
    bm.verts.ensure_lookup_table()
    drop = [f for f in bm.faces if not all(inside[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(h.data)
    bm.free()
    for m in list(h.modifiers):
        h.modifiers.remove(m)


def bust_apex(body, side=0):
    """Godot-coord point of the most forward vertex on the chest (for fitting tops).
    side=+1 / -1 = only that breast (x > 0 / x < 0); 0 = either."""
    top = max(v.co.z for v in body.data.vertices)
    best = None
    for v in body.data.vertices:
        if side and v.co.x * side < 0.01:
            continue
        if 0.62 * top < v.co.z < 0.8 * top and abs(v.co.x) < 0.2:  # torso only, not the hands
            if best is None or v.co.y < best.y:
                best = v.co
    return Vector((best.x, best.z, -best.y))
