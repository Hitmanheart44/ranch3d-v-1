"""Make an AI-generated mesh game-ready: stand it on the ground at a height, center it, one tinted material.
~/.local/bin/blender -b -P tools/blender/import_ai.py -- in.glb out.glb 2.4 0.62,0.55,0.72 [turn_deg] [concept_nobg.png]
turn_deg spins it so it faces the game's front (Hunyuan3D output needs 90).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import lib  # noqa: E402
import math  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, height, col = args[:4]
turn = float(args[4]) if len(args) > 4 else 0.0
concept = args[5] if len(args) > 5 else ""
lib.reset()
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    o.data.transform(Matrix.Rotation(math.radians(turn), 4, "Z") @ o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
k = float(height) / (hi.z - lo.z)
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
mat = lib.material("skin", tuple(float(c) for c in col.split(",")), rough=0.4)
for o in objs:
    o.data.transform(o.matrix_world)
    o.matrix_world = o.matrix_world.Identity(4)
    for v in o.data.vertices:
        v.co = (v.co - center) * k
    for p in o.data.polygons:
        p.use_smooth = True
    lib.assign(o, mat)
lib.export(dst, objs)
print("OK", dst)


def paint_from_concept(objs, png):
    """Color every vertex from the concept art, projected straight on from the front (the model faces -Y here).
    Sides and back take the color of the matching front spot, which suits a mostly symmetric character.
    Transparent pixels (outside the cutout) are filled from their nearest opaque neighbor first."""
    import numpy as np
    img = bpy.data.images.load(png)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]  # top row first
    solid = px[:, :, 3] > 0.5
    rows, cols = np.where(solid)
    r0, r1, c0, c1 = rows.min(), rows.max(), cols.min(), cols.max()
    px = _flatten(px, solid)
    filled = px.copy()
    have = solid.copy()
    for _ in range(60):  # grow colors outward into the transparent area
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            src_have = np.roll(have, (dy, dx), axis=(0, 1))
            src = np.roll(filled, (dy, dx), axis=(0, 1))
            take = src_have & ~have
            filled[take] = src[take]
            have = have | take
    pts = [v.co for o in objs for v in o.data.vertices]
    xmin, xmax = min(p.x for p in pts), max(p.x for p in pts)
    zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
    for o in objs:
        me = o.data
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for v in me.vertices:
            u = (v.co.x - xmin) / (xmax - xmin)
            t = (zmax - v.co.z) / (zmax - zmin)
            c = int(c0 + u * (c1 - c0))
            r = int(r0 + t * (r1 - r0))
            col = filled[min(max(r, 0), h - 1), min(max(c, 0), w - 1)]
            attr.data[v.index].color = (float(col[0]), float(col[1]), float(col[2]), 1.0)
        m = bpy.data.materials.new("vcol")
        m.use_nodes = True
        nt = m.node_tree
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Col"
        nt.links.new(ca.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.75
        lib.assign(o, m)


def _flatten(px, solid, k=8, win=31):
    """PS2-style flat paint: cluster the concept's colors into k flat colors (drops gloss and shading), then a
    majority vote in a win x win window removes thin highlight streaks and speckles."""
    import numpy as np
    rgb = px[:, :, :3]
    pts = rgb[solid]
    rng = np.random.default_rng(0)
    sample = pts[rng.choice(len(pts), min(20000, len(pts)), replace=False)]
    cent = sample[rng.choice(len(sample), k, replace=False)]
    for _ in range(25):
        lab = ((sample[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            if (lab == i).any():
                cent[i] = sample[lab == i].mean(0)
    h, w = solid.shape
    label = np.full((h, w), -1)
    label[solid] = ((pts[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
    votes = np.zeros((k, h, w), np.float32)
    r = win // 2
    for i in range(k):  # box-filtered count of each label = majority vote
        m = np.pad((label == i).astype(np.float32), ((r + 1, r), (r + 1, r)))
        c = m.cumsum(0).cumsum(1)
        votes[i] = c[win:, win:] - c[:-win, win:] - c[win:, :-win] + c[:-win, :-win]
    # gloss is always lighter than the material under it: where a darker color holds 30%+ of the window, it wins
    lum = cent @ np.array([0.3, 0.59, 0.11], np.float32)
    strong = votes >= 0.3 * votes.max(0, keepdims=True)
    best = np.where(strong, lum[:, None, None], 9.0).argmin(0)
    out = px.copy()
    out[:, :, :3] = np.where(solid[:, :, None], cent[best], rgb)
    return out


if concept:
    paint_from_concept(objs, concept)
    lib.export(dst, objs)
    print("PAINTED", dst)
