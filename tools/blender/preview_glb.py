"""Render any .glb from the front, back and face (same stage/lights as the breed scripts).
~/.local/bin/blender -b -P tools/blender/preview_glb.py -- model.glb /tmp/out_prefix
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import lib  # noqa: E402

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
lib.reset()
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# stand it on the ground, 2.4 tall, centered
zmin = min((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
zmax = max((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
for o in objs:
    s = 2.4 / (zmax - zmin)
    o.scale = o.scale * s
    o.location.z -= zmin * s
    if not o.data.materials:
        o.data.materials.append(lib.material("clay", (0.55, 0.5, 0.6), rough=0.5))
lib.render(out, accent=(0.9, 0.3, 0.8))
