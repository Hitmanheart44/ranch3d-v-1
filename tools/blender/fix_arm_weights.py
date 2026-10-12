"""Repaint arm skin weights on a rigged GLB so baggy trousers / skirts stop following the arms.
  blender -b -P tools/blender/fix_arm_weights.py -- in.glb out.glb [radius_m]
For every vertex weighted to an arm bone (upperarm/forearm/hand .L/.R): if the vertex is farther than `radius` from that
arm's bone chain (distance to the nearest bone segment), the arm influence is removed and the rest renormalised
(falling back to the nearest torso bone). Skinning near the arm is untouched, so walk/attack clips still look the same.
"""
import sys
import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
RADIUS = float(a[2]) if len(a) > 2 else 0.11

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
ARM = ["upperarm", "forearm", "hand"]


def seg_dist(p, h, t):
    d = t - h
    k = max(0.0, min(1.0, (p - h).dot(d) / max(d.length_squared, 1e-9)))
    return (p - (h + d * k)).length


for side in ("L", "R"):
    chain = [rig.data.bones.get(f"{n}.{side}") for n in ARM]
    chain = [b for b in chain if b is not None]
    if not chain:
        continue
    segs = [(rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local) for b in chain]
    names = {f"{n}.{side}" for n in ARM}
    for ob in meshes:
        gi = {g.index: g.name for g in ob.vertex_groups}
        arm_idx = [i for i, n in gi.items() if n in names]
        if not arm_idx:
            continue
        removed = 0
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            near = min(seg_dist(p, h, t) for h, t in segs)
            if near <= RADIUS:
                continue
            for i in arm_idx:
                try:
                    ob.vertex_groups[i].remove([v.index])
                    removed += 1
                except RuntimeError:
                    pass
        print(side, ob.name, "arm weights removed:", removed)
    # vertices left with no weight at all -> give them to the chest/spine
    for ob in meshes:
        for v in ob.data.vertices:
            if not v.groups:
                for fallback in ("chest", "spine", "hips"):
                    if fallback in ob.vertex_groups:
                        ob.vertex_groups[fallback].add([v.index], 1.0, "REPLACE")
                        break

bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_animations=True, export_skins=True, export_yup=True, export_apply=False)
print("WROTE", DST)
