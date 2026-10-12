"""Kami shrine-ranch props (VISION.md): torii, stone lantern, sacred tree, hokora shrine, machine stone, stepping
stone, bamboo fence. Same painted look as props.py (merged organic meshes, vertex paint, baked AO).
~/.local/bin/blender -b -P tools/blender/kami_props.py -- torii lantern ... [--render out.png]
Exports res://assets/props/kami/<name>.glb (Y up, base at origin, front +Z).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets/props/kami")
args = sys.argv[sys.argv.index("--") + 1:]
render_to = args[args.index("--render") + 1] if "--render" in args else ""
names = [a for a in args if not a.startswith("--") and a != render_to]


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def box(c, size, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return o


def cyl(c, r, depth, axis="Z", verts=24, r2=None):
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=c, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=c, rotation=rot)
    return bpy.context.active_object


def blob(loc, radius, rough=0.3, seed=0, squash=(1, 1, 1), detail=4):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1.0)
    o = bpy.context.active_object
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in o.data.vertices:
        n = v.co.normalized()
        v.co = Vector((n.x * squash[0], n.y * squash[1], n.z * squash[2])) * radius * (1 + noise.fractal(n * 1.6 + off, 0.6, 2.0, 4) * rough)
    o.location = loc
    return o


def tube(pts, radii, seg=10):
    return lib.tube("t", [Vector(p) for p in pts], radii, lib.material("tmp", (1, 1, 1)), seg=seg)


def stone_c(base=(0.46, 0.44, 0.40), moss=0.5):
    def f(co, n, t):
        g = noise.noise(co * 4) * 0.5 + 0.5
        c = mix(tuple(x * 0.65 for x in base), base, g * 0.7 + max(0.0, n.z) * 0.3)
        m = max(0.0, n.z - 0.25) * moss * 2 * (noise.noise(co * 2.2 + Vector((7, 7, 7))) * 0.5 + 0.6)
        return mix(c, (0.24, 0.40, 0.12), m)
    return f


def wood_c(base):
    def f(co, n, t):
        g = noise.noise(Vector((co.x * 2, co.y * 2, co.z * 10))) * 0.5 + 0.5
        return mix(tuple(x * 0.72 for x in base), base, g)
    return f


def export(name, objs):
    os.makedirs(OUT, exist_ok=True)
    lib.export(os.path.join(OUT, name + ".glb"), objs)
    print("KAMI", name)


# ---------------------------------------------------------------- props

def torii(rnd):
    pillars = [cyl((x, 0, 2.1), 0.22, 4.2, r2=0.19) for x in (-1.9, 1.9)]
    pillars += [cyl((x, 0, 0.15), 0.3, 0.3) for x in (-1.9, 1.9)]                       # base rings (painted black)
    nuki = [box((0, 0, 3.15), (4.6, 0.22, 0.28))]                                      # lower beam
    kasagi = [box((0, 0, 4.0), (5.4, 0.42, 0.26))]                                     # top beam, curved up at the ends
    me = kasagi[0].data
    for v in me.vertices:
        v.co.z += (abs(v.co.x) / 2.7) ** 2.2 * 0.38
    kasagi.append(box((0, 0, 3.78), (5.0, 0.36, 0.2)))
    gakuzuka = [box((0, 0, 3.47), (0.24, 0.2, 0.45))]
    red = lib.ps2_finish(pillars[:2] + nuki + gakuzuka + [kasagi[1]], "torii_red",
                         lambda co, n, t: mix((0.62, 0.10, 0.05), (0.86, 0.22, 0.08), noise.noise(co * 3) * 0.5 + 0.5 - (0.15 if co.z < 0.6 else 0)),
                         voxel=0.025, smooth=1, faces=6000, ao=0.5)
    black = lib.ps2_finish(pillars[2:] + [kasagi[0]], "torii_black", lambda co, n, t: mix((0.06, 0.05, 0.05), (0.16, 0.14, 0.13), noise.noise(co * 4) * 0.5 + 0.5),
                           voxel=0.025, smooth=1, faces=3000, ao=0.4)
    return [red, black]


def lantern(rnd):
    parts = [cyl((0, 0, 0.12), 0.38, 0.24, verts=6), cyl((0, 0, 0.6), 0.13, 0.8, verts=12),
             cyl((0, 0, 1.05), 0.32, 0.12, verts=6), box((0, 0, 1.3), (0.42, 0.42, 0.38)),
             cyl((0, 0, 1.62), 0.55, 0.3, verts=6, r2=0.08), blob((0, 0, 1.82), 0.09, 0.1, detail=2)]
    stone = lib.ps2_finish(parts, "lantern", stone_c(moss=0.6), voxel=0.02, smooth=1, faces=4000, ao=0.6)
    glow = [box((0, 0, 1.3), (0.44, 0.3, 0.26)), box((0, 0, 1.3), (0.3, 0.44, 0.26))]  # light windows
    m = lib.material("lantern_light", (1.0, 0.72, 0.35), emit=4.0, emit_color=(1.0, 0.7, 0.3))
    for o in glow:
        lib.assign(o, m)
    return [stone] + glow


def sacred_tree(rnd):
    trunk = [tube([(0, 0, -0.2), (0.2, 0.1, 2.5), (0.0, 0.3, 5.0), (-0.3, 0.0, 7.0)], [1.25, 0.95, 0.75, 0.5], seg=18)]
    for k in range(6):  # big roots
        a = k / 6 * 2 * math.pi + 0.3
        trunk.append(tube([(0, 0, 1.4), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.2), (math.cos(a) * 2.4, math.sin(a) * 2.4, -0.1)], [0.5, 0.32, 0.1]))
    for k in range(7):  # limbs into the crown
        a = k / 7 * 2 * math.pi + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(2.5, 4.0)
        trunk.append(tube([(0, 0, 5.0 + k * 0.25), (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, 7.0 + k * 0.1),
                           (math.cos(a) * r, math.sin(a) * r, 8.2 + rnd.uniform(0, 0.8))], [0.45, 0.28, 0.12]))
    crown = []
    for k in range(34):
        a = rnd.uniform(0, 2 * math.pi)
        el = rnd.uniform(-0.3, 1.1)
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * 0.6))
        crown.append(blob(Vector((0, 0, 9.0)) + d * Vector((4.3, 4.3, 3.0)), rnd.uniform(1.5, 2.2), 0.18, seed=k, squash=(1, 1, 0.75)))
    bark = lambda co, n, t: mix((0.20, 0.14, 0.10), (0.42, 0.33, 0.25), noise.noise(Vector((co.x, co.y, co.z * 0.3)) * 2.5) * 0.5 + 0.5)

    def leaves(co, n, t):
        light = max(0.0, n.z) * 0.45 + max(0.0, n.dot(Vector((0.5, -0.6, 0.6)).normalized())) * 0.3
        c = mix((0.06, 0.20, 0.07), (0.28, 0.50, 0.15), t * 0.5 + light)
        return mix(c, (0.65, 0.72, 0.25), max(0.0, noise.noise(co * 1.8) * 0.5 + 0.5 - 0.7) * 2.5 * light)
    out = [lib.ps2_finish(trunk, "sacred_trunk", bark, voxel=0.08, smooth=4, faces=9000, ao=0.6, rough=0.95),
           lib.ps2_finish(crown, "sacred_crown", leaves, voxel=0.14, smooth=2, faces=14000, ao=0.8, rough=0.95)]
    # shimenawa: a thick twisted straw rope around the trunk, with zigzag paper shide hanging from it
    rope = []
    for k in range(2):
        pts, radii = [], []
        for i in range(49):
            a = i / 48 * 2 * math.pi
            tw = a * 9 + k * math.pi
            pts.append((math.cos(a) * 1.18 + math.cos(tw) * 0.06, math.sin(a) * 1.18 + math.sin(tw) * 0.06, 2.6 + math.sin(tw) * 0.06))
            radii.append(0.14)
        rope.append(tube(pts, radii, seg=10))
    out.append(lib.ps2_finish(rope, "shimenawa", lambda co, n, t: mix((0.68, 0.58, 0.32), (0.86, 0.78, 0.5), noise.noise(co * 12) * 0.5 + 0.5),
                              voxel=0.02, smooth=1, faces=6000, ao=0.5))
    shide = []
    for k in range(6):
        a = k / 6 * 2 * math.pi + 0.25
        base = Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 2.5))
        for j in range(4):  # zigzag paper strip
            shide.append(box(base + Vector((math.cos(a) * 0.02 * (j % 2), math.sin(a) * 0.02 * (j % 2), -0.14 - j * 0.16)),
                             (0.16, 0.02, 0.16), rot=(0, 0, a + math.pi / 2)))
    paper = lib.material("shide_paper", (0.97, 0.96, 0.92), rough=0.7, emit=0.2)
    for o in shide:
        lib.assign(o, paper)
    return out + shide


def hokora(rnd):
    import bmesh as bm_
    base = [box((0, 0, 0.35), (2.0, 1.6, 0.7))]                                     # stone plinth
    body = [box((0, 0, 1.25), (1.3, 1.0, 1.1))]                                     # wooden shrine house
    doors = [box((0, -0.51, 1.2), (0.9, 0.04, 0.85))]
    b = bm_.new()                                                                   # sweeping roof
    v = [b.verts.new(p) for p in [(-1.05, -0.95, 1.8), (1.05, -0.95, 1.8), (1.05, 0.95, 1.8), (-1.05, 0.95, 1.8), (0, -0.95, 2.45), (0, 0.95, 2.45)]]
    for f in [(0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4)]:
        b.faces.new([v[i] for i in f])
    me = bpy.data.meshes.new("roof")
    b.to_mesh(me)
    roof = bpy.data.objects.new("roof", me)
    bpy.context.collection.objects.link(roof)
    sol = roof.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.12
    bpy.context.view_layer.objects.active = roof
    bpy.ops.object.modifier_apply(modifier="s")
    for vv in roof.data.vertices:  # eaves curve up at the corners
        vv.co.z += (max(0.0, abs(vv.co.x) - 0.6)) ** 2 * 0.5
    stone = lib.ps2_finish(base, "hokora_base", stone_c(moss=0.7), voxel=0.03, smooth=1, faces=2000, ao=0.6)
    wood = lib.ps2_finish(body, "hokora_body", wood_c((0.55, 0.36, 0.2)), voxel=0.025, smooth=1, faces=3000, ao=0.6)
    door = lib.ps2_finish(doors, "hokora_doors", lambda co, n, t: (0.72, 0.16, 0.08), voxel=0.02, smooth=0, faces=1000, ao=0.3)
    rf = lib.ps2_finish([roof], "hokora_roof", lambda co, n, t: mix((0.16, 0.18, 0.2), (0.3, 0.33, 0.36), noise.noise(co * 6) * 0.5 + 0.5),
                        voxel=0.03, smooth=1, faces=3000, ao=0.5)
    return [stone, wood, door, rf]


def machine_stone(rnd):
    """An old machine (server tower) standing like a shrine stone, mossed over, a rope around it."""
    tower = [box((0, 0, 1.0), (0.8, 0.9, 2.0))]
    for k in range(5):
        tower.append(box((0, -0.46, 0.35 + k * 0.32), (0.66, 0.04, 0.2)))           # drive bays
    t = lib.ps2_finish(tower, "machine", lambda co, n, tt: mix((0.18, 0.19, 0.2), (0.34, 0.35, 0.36), noise.noise(co * 5) * 0.5 + 0.5),
                       voxel=0.02, smooth=1, faces=3000, ao=0.6)
    moss = [blob((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.35, 0.35), 2.0 + rnd.uniform(-0.05, 0.05)), rnd.uniform(0.25, 0.4), 0.3, seed=k, squash=(1, 1, 0.45), detail=3) for k in range(5)]
    moss += [blob((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.45, 0.45), 0.1), rnd.uniform(0.25, 0.4), 0.3, seed=k + 9, squash=(1, 1, 0.5), detail=3) for k in range(6)]
    m = lib.ps2_finish(moss, "moss", lambda co, n, tt: mix((0.14, 0.3, 0.08), (0.36, 0.55, 0.16), noise.noise(co * 6) * 0.5 + 0.5),
                       voxel=0.03, smooth=2, faces=3000, ao=0.5)
    rope = tube([(math.cos(a) * 0.62, math.sin(a) * 0.68, 1.35) for a in [i / 24 * 2 * math.pi for i in range(25)]], [0.07] * 25)
    r = lib.ps2_finish([rope], "machine_rope", lambda co, n, tt: (0.8, 0.7, 0.42), voxel=0.015, smooth=1, faces=1500, ao=0.3)
    led = box((0.22, -0.48, 1.85), (0.08, 0.02, 0.08))
    lib.assign(led, lib.material("kami_led", (0.4, 1.0, 0.85), emit=6.0, emit_color=(0.4, 1.0, 0.85)))
    return [t, m, r, led]


def stepping_stone(rnd):
    return [lib.ps2_finish([blob((0, 0, 0.04), 0.5, 0.15, seed=2, squash=(1, 0.85, 0.16), detail=3)], "step", stone_c(moss=0.3),
                           voxel=0.02, smooth=1, faces=800, ao=0.4)]


def bamboo_fence(rnd):
    poles = [cyl((x, 0, 0.7), 0.06, 1.4, verts=10) for x in [-1.1 + i * 0.22 for i in range(11)]]
    rails = [cyl((0, -0.08, z), 0.05, 2.5, axis="X", verts=10) for z in (0.45, 1.05)]
    return [lib.ps2_finish(poles + rails, "bamboo", lambda co, n, t: mix((0.52, 0.56, 0.24), (0.78, 0.74, 0.42), noise.noise(Vector((co.x * 4, co.y * 4, co.z * 2))) * 0.5 + 0.5 - (0.3 if abs((co.z * 2.2) % 1 - 0.5) < 0.04 else 0)),
                           voxel=0.012, smooth=1, faces=3000, ao=0.5)]


BUILD = {"torii": torii, "lantern": lantern, "sacred_tree": sacred_tree, "hokora": hokora, "machine_stone": machine_stone,
         "stepping_stone": stepping_stone, "bamboo_fence": bamboo_fence}
WIDTH = {"torii": 6.5, "sacred_tree": 11, "hokora": 3.2, "lantern": 1.6, "machine_stone": 1.8, "stepping_stone": 1.4, "bamboo_fence": 3.0}

built = {}
for n in (names or list(BUILD)):
    lib.reset()
    export(n, BUILD[n](random.Random(5)))
    built[n] = os.path.join(OUT, n + ".glb")

if render_to:
    lib.reset()
    widths = [WIDTH[n] for n in built]
    x = -sum(widths) / 2
    for n, w in zip(built, widths):
        bpy.ops.import_scene.gltf(filepath=built[n])
        for o in bpy.context.selected_objects:
            o.location.x += x + w / 2
        x += w
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 96
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    w = bpy.data.worlds.new("sky")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.95, 0.7, 0.45, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.78, 0.55)
    sun.rotation_euler = (math.radians(62), 0, math.radians(-40))
    sc.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=80)
    lib.assign(bpy.context.active_object, lib.material("ground", (0.3, 0.42, 0.15), rough=1.0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.lens = 35
    span = sum(widths)
    cam.location = (0, -span * 0.95, span * 0.22)
    cam.rotation_euler = (math.radians(80), 0, 0)
    sc.camera = cam
    sc.render.filepath = render_to
    bpy.ops.render.render(write_still=True)
    print("RENDER", render_to)
