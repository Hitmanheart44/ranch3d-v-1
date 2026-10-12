"""Downscale every texture in a .glb to at most N px (faster loading, lighter on old GPUs). Keeps animations.
~/.local/bin/blender -b -P tools/blender/shrink_tex.py -- in.glb out.glb [max_px]
"""
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = a[:2]
mx = int(a[2]) if len(a) > 2 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
n = 0
for img in bpy.data.images:
    w, h = img.size
    if max(w, h) > mx:
        k = mx / max(w, h)
        img.scale(max(1, int(w * k)), max(1, int(h * k)))
        n += 1
anim = bool(bpy.data.actions)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=88,
                          export_animations=anim, export_animation_mode="NLA_TRACKS" if anim else "ACTIONS", export_skins=True)
print("SHRUNK", dst, n, "images", "anim" if anim else "")
