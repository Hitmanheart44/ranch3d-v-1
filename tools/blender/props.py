"""Ranch environment props (ART_SLOTS.md): stylized MR4/HD hand-painted look. Each prop is merged into organic
meshes, painted with vertex colors (light from above, darker undersides, leafy/bark/moss variation) and baked AO.
~/.local/bin/blender -b -P tools/blender/props.py -- tree_round tree_pine rock ... [--render out.png]
Exports res://assets/props/<slot>.glb (Y up, base at origin, front +Z after export).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import lib  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
args = sys.argv[sys.argv.index("--") + 1:]
render_to = args[args.index("--render") + 1] if "--render" in args else ""
slots = [a for a in args if not a.startswith("--") and a != render_to]


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def blob(loc, radius, rough=0.35, seed=0, squash=(1, 1, 1), detail=4):
    """A lumpy displaced sphere (foliage clump, rock)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1.0, location=(0, 0, 0))
    o = bpy.context.active_object
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in o.data.vertices:
        n = v.co.normalized()
        d = noise.fractal(n * 1.6 + off, 0.6, 2.0, 4) * rough
        v.co = Vector((n.x * squash[0], n.y * squash[1], n.z * squash[2])) * radius * (1 + d)
    o.location = loc
    return o


def tube(pts, radii, seg=10):
    return lib.tube("t", [Vector(p) for p in pts], radii, lib.material("tmp", (1, 1, 1)), seg=seg)


def export(slot, objs):
    path = os.path.join(ROOT, "assets/props", slot + ".glb")
    lib.export(path, objs)
    print("PROP", slot, path)


# ---------------------------------------------------------------- props

def tree_round(rnd):
    trunk = [tube([(0, 0, -0.1), (0.05, 0.02, 1.2), (0.0, 0.05, 2.6), (-0.1, 0.0, 3.4)], [0.42, 0.3, 0.24, 0.18], seg=14)]
    for k in range(4):  # root flares
        a = k / 4 * 2 * math.pi + 0.4
        trunk.append(tube([(0, 0, 0.5), (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.08), (math.cos(a) * 0.7, math.sin(a) * 0.7, -0.05)], [0.18, 0.12, 0.05]))
    for k in range(5):  # main branches into the crown
        a = k / 5 * 2 * math.pi + rnd.uniform(-0.3, 0.3)
        r = rnd.uniform(1.0, 1.6)
        trunk.append(tube([(0, 0, 2.3 + k * 0.15), (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, 3.1 + k * 0.1),
                           (math.cos(a) * r, math.sin(a) * r, 3.8 + rnd.uniform(0, 0.5))], [0.16, 0.1, 0.05]))
    crown = []
    for k in range(22):  # distinct foliage clumps on the surface of a rounded crown (gaps between them shade dark)
        a = rnd.uniform(0, 2 * math.pi)
        el = rnd.uniform(-0.35, 1.2)
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * 0.8))
        crown.append(blob(Vector((0, 0, 4.2)) + d * 1.65, rnd.uniform(0.7, 1.0), 0.18, seed=k, squash=(1, 1, 0.8)))
    crown.append(blob((0, 0, 4.2), 1.55, 0.15, seed=99, squash=(1.05, 1.05, 0.85)))

    def bark(co, n, t):
        s = noise.noise(Vector((co.x * 3, co.y * 3, co.z * 0.6))) * 0.5 + 0.5
        return mix((0.24, 0.15, 0.08), (0.42, 0.28, 0.15), s * 0.8 + t * 0.2)

    def leaves(co, n, t):
        fine = noise.noise(co * 3.2) * 0.5 + 0.5
        light = max(0.0, n.z) * 0.45 + max(0.0, n.dot(Vector((0.5, -0.6, 0.6)).normalized())) * 0.3  # sun from front-left-top
        c = mix((0.07, 0.22, 0.06), (0.26, 0.5, 0.12), t * 0.5 + light)
        return mix(c, (0.62, 0.7, 0.22), max(0.0, fine - 0.72) * 2.2 * (0.4 + light))  # sunlit leaf speckles
    a = lib.ps2_finish(trunk, "trunk", bark, voxel=0.045, smooth=4, faces=4000, ao=0.5, rough=0.9)
    b = lib.ps2_finish(crown, "crown", leaves, voxel=0.06, smooth=2, faces=10000, ao=0.8, rough=0.9)
    return [a, b]


def tree_pine(rnd):
    trunk = [tube([(0, 0, -0.1), (0, 0, 3.0), (0, 0, 6.2)], [0.28, 0.2, 0.05], seg=12)]
    tiers = []
    n = 6
    for k in range(n):
        z = 1.1 + k * 0.82
        r = 2.0 * (1 - k / n) + 0.35
        bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=r, radius2=0.05, depth=1.6, location=(0, 0, z + 0.6))
        o = bpy.context.active_object
        me = o.data
        for v in me.vertices:  # wavy drooping skirt edge
            if v.co.z < 0:
                a = math.atan2(v.co.y, v.co.x)
                v.co.z += math.sin(a * 9 + k) * 0.12 - 0.15
                v.co.x *= 1 + math.sin(a * 13 + k * 2) * 0.06
                v.co.y *= 1 + math.sin(a * 13 + k * 2) * 0.06
        tiers.append(o)

    def bark(co, n, t):
        return mix((0.22, 0.13, 0.07), (0.36, 0.22, 0.12), noise.noise(co * 4) * 0.5 + 0.5)

    def needles(co, n, t):
        fine = noise.noise(Vector((co.x * 6, co.y * 6, co.z * 6))) * 0.5 + 0.5
        light = max(0.0, n.z) * 0.4 + max(0.0, n.dot(Vector((0.5, -0.6, 0.6)).normalized())) * 0.3
        c = mix((0.04, 0.16, 0.10), (0.18, 0.38, 0.18), light + t * 0.25)
        return mix(c, (0.35, 0.55, 0.25), max(0.0, fine - 0.75) * 2 * light)
    a = lib.ps2_finish(trunk, "trunk", bark, voxel=0.04, smooth=3, faces=2000, ao=0.4, rough=0.9)
    b = lib.ps2_finish(tiers, "needles", needles, voxel=0.07, smooth=2, faces=8000, ao=0.6, rough=0.9)
    return [a, b]


def rock(rnd):
    parts = [blob((0, 0, 0.42), 0.68, 0.22, seed=3, squash=(1.0, 0.85, 0.72), detail=3),
             blob((0.42, 0.18, 0.25), 0.4, 0.2, seed=8, squash=(1, 0.9, 0.7), detail=3)]

    def stone(co, n, t):
        grain = noise.noise(co * 5) * 0.5 + 0.5
        c = mix((0.30, 0.28, 0.26), (0.52, 0.49, 0.44), grain * 0.7 + max(0.0, n.z) * 0.3)
        moss = max(0.0, n.z - 0.35) * 1.6 * (noise.noise(co * 2.5 + Vector((5, 5, 5))) * 0.5 + 0.7)
        return mix(c, (0.25, 0.42, 0.12), moss)
    o = lib.ps2_finish(parts, "rock", stone, voxel=0.03, smooth=1, faces=2500, ao=0.7, rough=0.95)
    for v in o.data.vertices:  # flat underside, sits at y=0
        v.co.z = max(v.co.z, 0.0)
    return [o]


def box(c, size):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return o


def cyl(c, r, depth, axis="Z", verts=24):
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=c, rotation=rot)
    return bpy.context.active_object


def wood(base=(0.48, 0.32, 0.18)):
    def f(co, n, t):
        g = noise.noise(Vector((co.x * 1.5, co.y * 1.5, co.z * 9))) * 0.5 + 0.5
        return mix(tuple(c * 0.7 for c in base), tuple(min(1, c * 1.2) for c in base), g * 0.8 + max(0.0, n.z) * 0.2)
    return f


def glow(name, objs, color):
    m = lib.material(name, color, rough=0.5, emit=3.0, emit_color=color)
    for o in objs:
        lib.assign(o, m)
    return objs


def fence_segment(rnd):
    parts = [box((-1.2, 0, 0.65), (0.16, 0.16, 1.3)), box((-1.2, 0, 1.33), (0.2, 0.2, 0.06))]
    parts += [box((0, 0, z), (2.4, 0.08, 0.14)) for z in (0.5, 1.0)]
    return [lib.ps2_finish(parts, "fence", wood(), voxel=0.012, smooth=1, faces=2500, ao=0.5)]


def barn(rnd):
    import bmesh
    walls = [box((0, 0, 2.0), (7, 6, 4))]
    bm = bmesh.new()  # gable roof, ridge front-to-back so the gable faces the door
    v = [bm.verts.new(p) for p in [(-3.8, -3.3, 3.9), (3.8, -3.3, 3.9), (0, -3.3, 6.5), (-3.8, 3.3, 3.9), (3.8, 3.3, 3.9), (0, 3.3, 6.5)]]
    for f in [(0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1)]:
        bm.faces.new([v[i] for i in f])
    me = bpy.data.meshes.new("roof")
    bm.to_mesh(me)
    roof = bpy.data.objects.new("roof", me)
    bpy.context.collection.objects.link(roof)
    sol = roof.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.25
    bpy.context.view_layer.objects.active = roof
    bpy.ops.object.modifier_apply(modifier="s")
    trim = [box((0, -3.02, 1.5), (2.6, 0.12, 3.0))]                      # door frame
    trim += [box((x, -3.06, 1.5), (0.14, 0.1, 3.0)) for x in (-1.3, 1.3)] + [box((0, -3.06, 3.0), (2.74, 0.1, 0.14))]
    trim += [box((x, -3.07, 1.5), (0.12, 0.08, 3.2)) for x in (-0.6, 0.6)]
    trim += [box((x, -3.03, 2.0), (0.18, 0.1, 4.0)) for x in (-3.45, 3.45)]  # corner boards

    def red(co, n, t):
        plank = 0.5 + 0.5 * math.sin(co.x * 9 + co.y * 9)
        g = noise.noise(co * 2) * 0.5 + 0.5
        return mix((0.42, 0.10, 0.07), (0.66, 0.18, 0.11), plank * 0.3 + g * 0.5)

    def roof_c(co, n, t):
        sh = 0.5 + 0.5 * math.sin(co.z * 14)
        return mix((0.22, 0.17, 0.15), (0.36, 0.28, 0.24), sh * 0.5 + (noise.noise(co * 3) * 0.5 + 0.5) * 0.5)

    def white(co, n, t):
        return mix((0.78, 0.74, 0.66), (0.95, 0.93, 0.86), noise.noise(co * 4) * 0.5 + 0.5)
    out = [lib.ps2_finish(walls, "barn_walls", red, voxel=0.03, smooth=1, faces=6000, ao=0.5),
           lib.ps2_finish([roof], "barn_roof", roof_c, voxel=0.04, smooth=1, faces=4000, ao=0.5),
           lib.ps2_finish(trim, "barn_trim", white, voxel=0.02, smooth=1, faces=4000, ao=0.5)]
    wins = [box((x, -3.06, 3.3), (0.7, 0.05, 0.6)) for x in (-2.3, 2.3)] + [box((0, -3.36, 4.7), (0.8, 0.05, 0.8))]
    lamps = []
    for x in (-1.7, 1.7):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, location=(x, -3.25, 2.6))
        lamps.append(bpy.context.active_object)
    out += glow("window_glow", wins, (1.0, 0.78, 0.38)) + glow("lantern", lamps, (1.0, 0.68, 0.3))
    return out


def pond(rnd):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=3.1, depth=0.04, location=(0, 0, 0.02))
    water = bpy.context.active_object
    wm = lib.material("water", (0.12, 0.34, 0.45), rough=0.05)
    lib.assign(water, wm)
    rocks = []
    for k in range(18):
        a = k / 18 * 2 * math.pi + rnd.uniform(-0.1, 0.1)
        r = 3.25 + rnd.uniform(-0.1, 0.15)
        rocks.append(blob((math.cos(a) * r, math.sin(a) * r, 0.12), rnd.uniform(0.32, 0.5), 0.2, seed=k, squash=(1, 1, 0.6), detail=3))
    pads = []
    for k in range(5):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.6, 2.4)
        pads.append(cyl((math.cos(a) * r, math.sin(a) * r, 0.05), rnd.uniform(0.18, 0.3), 0.02))
    stone = rock.__code__ and (lambda co, n, t: mix((0.34, 0.31, 0.28), (0.55, 0.52, 0.47), noise.noise(co * 4) * 0.5 + 0.5 + max(0.0, n.z) * 0.2))
    out = [water, lib.ps2_finish(rocks, "pond_rocks", stone, voxel=0.04, smooth=1, faces=6000, ao=0.6)]
    out.append(lib.ps2_finish(pads, "lily_pads", lambda co, n, t: (0.22, 0.5, 0.16), voxel=0.02, smooth=1, faces=1500, ao=0.2))
    return out


def log_pile(rnd):
    logs = []
    for row, n in enumerate((3, 2, 1)):
        for i in range(n):
            x = (i - (n - 1) / 2) * 0.62
            logs.append(cyl((0, x, 0.3 + row * 0.52), 0.3, 2.0, axis="X"))

    def logc(co, n, t):
        if abs(n.x) > 0.8:  # cut ends: light rings
            r = math.hypot(co.y % 0.62 - 0.31, co.z) * 30
            return mix((0.72, 0.56, 0.36), (0.58, 0.42, 0.24), 0.5 + 0.5 * math.sin(r))
        return wood((0.36, 0.24, 0.14))(co, n, t)
    return [lib.ps2_finish(logs, "log_pile", logc, voxel=0.02, smooth=1, faces=5000, ao=0.6)]


def trough(rnd):
    parts = [box((0, 0, 0.32), (2.2, 0.6, 0.08)), box((0, -0.27, 0.56), (2.2, 0.06, 0.48)), box((0, 0.27, 0.56), (2.2, 0.06, 0.48)),
             box((-1.07, 0, 0.56), (0.06, 0.6, 0.48)), box((1.07, 0, 0.56), (0.06, 0.6, 0.48))]
    parts += [box((x, y, 0.15), (0.1, 0.1, 0.3)) for x in (-0.95, 0.95) for y in (-0.22, 0.22)]
    t = lib.ps2_finish(parts, "trough", wood(), voxel=0.012, smooth=1, faces=4000, ao=0.6)
    w = box((0, 0, 0.7), (2.08, 0.48, 0.02))
    lib.assign(w, lib.material("water", (0.12, 0.34, 0.45), rough=0.05))
    return [t, w]


def sparring_post(rnd):
    post = [cyl((0, 0, 1.0), 0.12, 2.0), box((0, 0, 1.75), (1.2, 0.1, 0.1))]
    straw = [cyl((0, 0, 1.55), 0.32, 1.1), blob((0, 0, 2.3), 0.26, 0.1, seed=4, detail=3)]

    def strawc(co, n, t):
        band = abs(((co.z * 3.2) % 1.0) - 0.5) < 0.06
        return (0.42, 0.28, 0.14) if band else mix((0.72, 0.6, 0.3), (0.9, 0.8, 0.45), noise.noise(Vector((co.x * 20, co.y * 20, co.z * 3))) * 0.5 + 0.5)
    return [lib.ps2_finish(post, "post", wood(), voxel=0.015, smooth=1, faces=2000, ao=0.5),
            lib.ps2_finish(straw, "straw", strawc, voxel=0.015, smooth=2, faces=5000, ao=0.5)]


def target(rnd):
    post = [box((0, 0.15, 0.85), (0.14, 0.14, 1.7)), box((0, 0.3, 0.6), (0.1, 0.5, 0.1))]
    face = [cyl((0, 0, 1.6), 0.72, 0.16, axis="Y", verts=48)]

    def rings(co, n, t):
        if n.y > -0.7:
            return (0.72, 0.6, 0.38)
        r = math.hypot(co.x, co.z - 1.6) / 0.72
        cols = [(0.95, 0.8, 0.15), (0.85, 0.12, 0.1), (0.15, 0.35, 0.75), (0.1, 0.1, 0.1), (0.92, 0.9, 0.84)]
        return cols[min(4, int(r * 5))]
    return [lib.ps2_finish(post, "target_post", wood(), voxel=0.012, smooth=1, faces=1500, ao=0.5),
            lib.ps2_finish(face, "target_face", rings, voxel=0.01, smooth=0, faces=4000, ao=0.3)]


def mountain(rnd):
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=40, radius2=2, depth=45, location=(0, 0, 22.5))
    o = bpy.context.active_object
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 3
    sub.subdivision_type = "SIMPLE"
    bpy.ops.object.modifier_apply(modifier="sub")
    for v in o.data.vertices:
        h = v.co.z / 45 + 0.5
        d = noise.ridged_multi_fractal(v.co * 0.05, 1.0, 2.0, 4, 1.0, 2.0) * 6 * (1 - abs(h - 0.5))
        v.co += Vector((v.co.x, v.co.y, 0)).normalized() * d if (v.co.x or v.co.y) else Vector()

    def mc(co, n, t):
        rockc = mix((0.38, 0.34, 0.32), (0.55, 0.5, 0.46), noise.noise(co * 0.2) * 0.5 + 0.5)
        c = mix((0.25, 0.38, 0.16), rockc, (t - 0.15) * 3)
        return mix(c, (0.95, 0.96, 1.0), (t - 0.72) * 6 * max(0.3, n.z))
    o2 = lib.ps2_finish([o], "mountain", mc, voxel=0.6, smooth=1, faces=6000, ao=0.4)
    for v in o2.data.vertices:
        v.co.z -= min(v.co.z for v in o2.data.vertices) if False else 0
    return [o2]


BUILD = {"tree_round": tree_round, "tree_pine": tree_pine, "rock": rock, "fence_segment": fence_segment, "barn": barn,
         "pond": pond, "log_pile": log_pile, "trough": trough, "sparring_post": sparring_post, "target": target,
         "mountain": mountain}
WIDTH = {"barn": 9, "pond": 8.5, "tree_round": 5.5, "tree_pine": 5, "mountain": 0}

built = {}
for slot in slots:
    lib.reset()
    objs = BUILD[slot](random.Random(11))
    export(slot, objs)
    built[slot] = os.path.join(ROOT, "assets/props", slot + ".glb")

if render_to:  # golden-hour lineup of everything built, rendered on the CPU
    lib.reset()
    show = [s for s in built if s != "mountain"]
    widths = [WIDTH.get(s, 3.2) for s in show]
    x = -sum(widths) / 2
    for slot, w in zip(show, widths):
        bpy.ops.import_scene.gltf(filepath=built[slot])
        for o in bpy.context.selected_objects:
            o.location.x += x + w / 2
        x += w
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 96
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("sky")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.68, 0.9, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.82, 0.6)
    sun.data.angle = math.radians(4)
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    lib.assign(bpy.context.active_object, lib.material("ground", (0.32, 0.45, 0.16), rough=1.0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.lens = 40
    cam.location = (0, -19 * max(1.0, sum(WIDTH.get(s, 3.2) for s in built if s != "mountain") / 16), 5.0)
    cam.rotation_euler = (math.radians(84), 0, 0)
    sc.camera = cam
    sc.render.filepath = render_to
    bpy.ops.render.render(write_still=True)
    print("RENDER", render_to)
