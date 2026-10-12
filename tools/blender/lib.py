import os
"""Shared helpers for breed model scripts. Run a breed script headless:

    blender -b --python-exit-code 1 -P tools/blender/vexa.py -- --render /tmp/out --export assets/models/vexa.glb

Coordinates: helpers take GODOT-style coords (x right, y up, z forward toward the viewer),
so numbers match the rest of the project. They are converted to Blender (z up, -y forward).
The glTF exporter converts back, so the model faces +Z in Godot.

Technique: the body is metaballs (blobs that melt together = one smooth, sculpted-looking skin),
converted to a mesh, remeshed and smoothed. Clothing is cut from that body surface by region and
thickened outward, so it hugs the shape. Horns/tails/limbs-as-props are tapered tubes.
Material NAMES are keys (skin, hair, plate, bone, glow, eye) so Godot can swap in project shaders.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

# Field math: a lone metaball with stiffness 2 and threshold 0.6 has a surface at ~0.67 x its radius.
SURF = 0.67


def V(x, y, z):
    """Godot coords -> Blender coords."""
    return Vector((x, -z, y))


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"render": None, "export": None, "outfit": ""}
    for i, k in enumerate(a):
        if k in ("--render", "--export", "--outfit") and i + 1 < len(a):
            out[k[2:]] = a[i + 1]
    return out


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- materials

def material(name, color, rough=0.5, metal=0.0, emit=0.0, emit_color=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*(emit_color or color), 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ---------------------------------------------------------------- metaball sculpting

class Blob:
    """A metaball object. Sizes are SURFACE radii (what you see), compensated for the field falloff."""

    def __init__(self, name, resolution=0.012):
        mb = bpy.data.metaballs.new(name)
        mb.resolution = resolution
        mb.render_resolution = resolution
        mb.threshold = 0.6
        self.obj = bpy.data.objects.new(name, mb)
        bpy.context.collection.objects.link(self.obj)
        self.mb = mb

    def ball(self, p, r, stiff=2.0, carve=False):
        """carve=True subtracts instead of adds (eye sockets, dimples)."""
        e = self.mb.elements.new(type="BALL")
        e.co = p
        e.radius = r / SURF
        e.stiffness = stiff
        e.use_negative = carve
        return e

    def ellipsoid(self, p, rx, ry, rz, rot=(0, 0, 0), stiff=2.0):
        """rx/ry/rz in GODOT axes (x right, y up, z forward). rot = Godot-axis degrees."""
        e = self.mb.elements.new(type="ELLIPSOID")
        e.co = p
        r = max(rx, ry, rz)
        e.radius = r / SURF
        # Blender ellipsoid sizes are along its local x, y, z = Godot x, -z, y
        e.size_x, e.size_y, e.size_z = rx / r, rz / r, ry / r
        e.rotation = _rot(rot)
        e.stiffness = stiff
        return e

    def capsule(self, a, b, r, stiff=2.0):
        """A limb segment between Blender points a and b."""
        e = self.mb.elements.new(type="CAPSULE")
        d = b - a
        e.co = (a + b) * 0.5
        e.radius = r / SURF
        e.size_x = d.length * 0.5  # absolute half-length of the core segment
        e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        e.stiffness = stiff
        return e

    def to_mesh(self, voxel=0.008, smooth=6, target_tris=24000):
        """Bake to a clean mesh: convert, voxel remesh, smooth, decimate."""
        bpy.context.view_layer.objects.active = self.obj
        self.obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.view_layer.objects.active
        m = obj.modifiers.new("remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = voxel
        s = obj.modifiers.new("smooth", "CORRECTIVE_SMOOTH")
        s.iterations = smooth
        s.smooth_type = "LENGTH_WEIGHTED"
        s.use_only_smooth = True
        _apply_all(obj)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris > target_tris:
            d = obj.modifiers.new("decimate", "DECIMATE")
            d.ratio = target_tris / tris
            _apply_all(obj)
        bpy.ops.object.shade_smooth()
        return obj


def _rot(deg):
    rx, ry, rz = (math.radians(a) for a in deg)
    # Godot axes -> Blender axes: x->x, y->z, z->-y
    q = Quaternion((1, 0, 0), rx) @ Quaternion((0, 0, 1), ry) @ Quaternion((0, -1, 0), rz)
    return q


def _apply_all(obj):
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def seg_dist(p, a, b):
    """Distance from point p to segment a-b (any coords, as long as they match)."""
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


# ---------------------------------------------------------------- clothing cut from the body

def shell(body, name, mat, test, thick=0.012, offset=0.004):
    """Copy the body faces where test(godot_center) is True, push them out and thicken: tight clothing."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    keep = set()
    for f in bm.faces:
        c = f.calc_center_median()
        if test(c.x, c.z, -c.y):
            keep.add(f)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context="FACES")
    # straighten the stair-stepped edge left by cutting along quads
    edge = [v for v in bm.verts if v.is_boundary]
    for _ in range(8):
        bmesh.ops.smooth_vert(bm, verts=edge, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    _apply_all(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    assign(obj, mat)
    return obj


def paint(obj, mat, test):
    """Give faces where test(godot_center) is True a second material (makeup, markings, scales)."""
    if mat.name not in [m.name for m in obj.data.materials]:
        obj.data.materials.append(mat)
    idx = [m.name for m in obj.data.materials].index(mat.name)
    n = 0
    for p in obj.data.polygons:
        c = p.center
        if test(c.x, c.z, -c.y):
            p.material_index = idx
            n += 1
    print("PAINT", mat.name, n)
    return n


def hair_clumps(name, mat, center, radius, n=48, length=1.0, seed=3, part_x=0.0):
    """Stylized game hair: n tapered clumps rooted on the upper-back half of a scalp sphere
    (Blender center/radius), sweeping back over the head and falling down the back.
    `length` scales how far they fall; part_x shifts the parting sideways."""
    import random
    rnd = random.Random(seed)
    objs = []
    for i in range(n):
        # roots on a spiral over the crown, skipping the face
        t = (i + 0.5) / n
        theta = math.acos(1 - t * 1.15)          # 0 = top of the head
        phi = i * 2.399963 + rnd.uniform(-0.2, 0.2)
        d = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta)))
        if d.y < -0.35 and d.z < 0.5:             # front-low = the face: no roots here
            continue
        root = center + d * radius * 0.92 + Vector((part_x, 0, 0))
        out = Vector((d.x * 0.8, 0.6 + max(0.0, d.y) * 0.4, 0)).normalized()  # everything sweeps back
        fall = radius * (2.5 + 4.5 * length * rnd.uniform(0.75, 1.1))
        pts = [root,
               root + d * radius * 0.35 + out * radius * 0.25,
               root + out * radius * 0.75 + Vector((0, 0, -radius * 0.7)),
               root + out * radius * 0.95 + Vector((0, 0.15 * radius, -fall * 0.5)),
               root + out * radius * 0.8 + Vector((d.x * radius * 0.3, 0.25 * radius, -fall))]
        w0 = radius * rnd.uniform(0.85, 1.2)
        k = 14
        cp = curve_pts(pts, k)
        normals = []
        for q in cp:  # lie flat on the head, then flat against the back
            n_head = (q - center).normalized()
            n_body = Vector((q.x - center.x, q.y - center.y, 0)).normalized()
            normals.append(n_head.lerp(n_body, min(1.0, max(0.0, (center.z - q.z) / (radius * 1.5)))).normalized())
        objs.append(ribbon(f"{name}{i}", cp, [w0 * (1 - j / (k - 1)) ** 0.8 for j in range(k)], normals, mat))
    # a side-swept fringe: a few wide cards from the parting across the forehead to one temple
    for j in range(4):
        root = center + Vector((part_x + radius * (0.1 - 0.12 * j), -radius * 0.55, radius * 0.75))
        pts = [root, root + Vector((-radius * 0.35, -radius * 0.4, -radius * 0.05)),
               root + Vector((-radius * 0.8, -radius * 0.55, -radius * 0.45)), root + Vector((-radius * 1.05, -radius * 0.4, -radius * 0.95))]
        cp = curve_pts(pts, 10)
        objs.append(ribbon(f"{name}_fringe{j}", cp, [radius * 0.7 * (1 - k / 9) ** 0.8 for k in range(10)],
                           [(q - center).normalized() for q in cp], mat))
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    hair = bpy.context.view_layer.objects.active
    hair.name = name
    return hair


def spiky_hair(name, mat, center, radius, n=40, seed=5, length=1.0, face_dir=Vector((0, -1, 0))):
    """Chunky stylized anime hair: a cap plus n thick tapered spikes radiating out and back from the scalp
    (Blender center/radius). Spikes skip the face side; a few long ones frame the face."""
    import random
    rnd = random.Random(seed)
    cap = Blob(name + "_cap", resolution=radius * 0.08)
    cap.ellipsoid(center + Vector((0, radius * 0.08, radius * 0.05)), radius * 1.02, radius * 1.05, radius * 1.0)
    objs = [cap.to_mesh(voxel=radius * 0.05, smooth=3, target_tris=5000)]
    assign(objs[0], mat)
    for i in range(n):
        t = (i + 0.5) / n
        theta = math.acos(1 - t * 1.25)
        phi = i * 2.399963
        d = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), math.cos(theta)))
        if d.dot(face_dir) > 0.25 and d.z < 0.55:
            continue
        root = center + d * radius * 0.85
        out = (d + Vector((0, 0.9, -0.35))).normalized()        # sweep back and a little down
        L = radius * rnd.uniform(0.8, 1.35) * length
        bend = Vector((0, 0.2, -0.35)) * L
        pts = curve_pts([root, root + out * L * 0.5, root + out * L + bend], 8)
        r0 = radius * rnd.uniform(0.38, 0.48)
        objs.append(tube(f"{name}{i}", pts, [r0 * (1 - j / 7) ** 1.3 for j in range(8)], mat, seg=7))
    for sx in (-1, 1):  # long locks framing the face
        root = center + Vector((sx * radius * 0.85, -radius * 0.35, -radius * 0.1))
        pts = curve_pts([root, root + Vector((sx * radius * 0.15, -radius * 0.15, -radius * 0.8)), root + Vector((sx * radius * 0.05, -radius * 0.05, -radius * 1.7))], 8)
        objs.append(tube(f"{name}_lock{sx}", pts, [radius * 0.22 * (1 - j / 7) ** 1.2 for j in range(8)], mat, seg=7))
    for j in range(3):  # bangs
        root = center + Vector(((j - 1) * radius * 0.35, -radius * 0.75, radius * 0.55))
        pts = curve_pts([root, root + Vector(((j - 1) * radius * 0.1, -radius * 0.25, -radius * 0.25)), root + Vector(((j - 1) * radius * 0.2, -radius * 0.3, -radius * 0.6))], 8)
        objs.append(tube(f"{name}_bang{j}", pts, [radius * 0.2 * (1 - k / 7) ** 1.2 for k in range(8)], mat, seg=7))
    return join(objs, name)


def fur_ring(name, mat, center, axis, radius, n=14, seed=2):
    """A fluffy cuff: n soft spikes around a limb (Blender center, limb axis, limb radius)."""
    import random
    rnd = random.Random(seed)
    axis = axis.normalized()
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = axis.cross(Vector((1, 0, 0)))
    side.normalize()
    up = side.cross(axis)
    objs = []
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-0.2, 0.2)
        d = side * math.cos(a) + up * math.sin(a)
        root = center + d * radius * 0.85 + axis * rnd.uniform(-0.3, 0.3) * radius
        tip = root + d * radius * rnd.uniform(0.6, 1.0) + axis * radius * rnd.uniform(-0.6, -0.2)
        objs.append(tube(f"{name}{i}", curve_pts([root, root.lerp(tip, 0.5) + d * radius * 0.15, tip], 5), [radius * 0.45, radius * 0.38, radius * 0.25, radius * 0.1, 0.0], mat, seg=6))
    return join(objs, name)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o


def ribbon(name, pts, widths, normals, mat, thick=0.004):
    """A flat tapered strip (hair card) along Blender points, lying on the surface given by `normals`."""
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = d.cross(normals[i]).normalized() * widths[i] * 0.5
        rows.append((bm.verts.new(p - side), bm.verts.new(p + side)))
    for i in range(len(rows) - 1):
        bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = thick
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    _apply_all(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    assign(obj, mat)
    return obj


# ---------------------------------------------------------------- tubes (horns, tails, straps)

def tube(name, pts, radii, mat, seg=12, cap=True):
    """Smooth tapered tube through Blender points with a radius per point. Ends in a point if radius 0."""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            d = pts[1] - pts[0]
        elif i == len(pts) - 1:
            d = pts[-1] - pts[-2]
        else:
            d = pts[i + 1] - pts[i - 1]
        d.normalize()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 0.01:
            side = d.cross(Vector((0, 1, 0)))
        side.normalize()
        up = side.cross(d)
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * max(radii[i], 0.0005)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    _apply_all(obj)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    assign(obj, mat)
    return obj


def curve_pts(ctrl, n=12):
    """Catmull-Rom through Blender control points -> n smooth points."""
    out = []
    c = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    for i in range(n):
        t = i / (n - 1) * (len(ctrl) - 1)
        k = min(int(t), len(ctrl) - 2)
        u = t - k
        p0, p1, p2, p3 = c[k], c[k + 1], c[k + 2], c[k + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    return out


def membrane(name, pts, mat, thick=0.006, smooth=0):
    """A thin skin stretched over a fan of Blender points (wings, fins, blades). pts[0] is the root.
    smooth > 0 subdivides (rounds the outline off, so keep it 0 for sharp shapes)."""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for i in range(1, len(vs) - 1):
        bm.faces.new((vs[0], vs[i], vs[i + 1]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    if smooth > 0:
        sub = obj.modifiers.new("sub", "SUBSURF")
        sub.levels = smooth
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = thick
    _apply_all(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    assign(obj, mat)
    return obj


# ---------------------------------------------------------------- output

def render(path, height=2.5, accent=(0.6, 0.3, 1.0)):
    """Front 3/4, back 3/4 and a face close-up to path_front/back/face.png. Dark stage, colored rim lights."""
    sc = bpy.context.scene
    sc.render.engine = os.environ.get("PREVIEW_ENGINE", "BLENDER_EEVEE")
    if sc.render.engine == "CYCLES":  # CPU preview while the GPU is busy with an AI job
        sc.cycles.device = "CPU"
        sc.cycles.samples = 24
        sc.cycles.use_denoising = True
    sc.render.resolution_x = 720
    sc.render.resolution_y = 960
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.011, 0.015, 1)
    sc.world = w
    sc.view_settings.view_transform = "AgX"
    _light("key", (2.5, -3.0, 3.5), 400, (1.0, 0.95, 0.92))
    _light("rim_l", (-2.5, 2.5, 2.5), 500, accent)
    _light("rim_r", (2.5, 2.5, 1.5), 300, (0.7, 0.8, 1.0))
    _light("fill", (-3.0, -2.0, 1.0), 80, (0.6, 0.65, 0.8))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    shots = (("front", -25, height * 0.52, 5.2), ("back", 155, height * 0.52, 5.2), ("face", -15, height * 0.9, 1.1))
    for tag, ang, tz, dist in shots:
        target = Vector((0, 0, tz))
        a = math.radians(ang)
        cam.location = target + Vector((math.sin(a) * dist, -math.cos(a) * dist, 0.35 * dist / 5.2))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"{path}_{tag}.png"
        bpy.ops.render.render(write_still=True)


def _light(name, loc, power, color):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = power
    ld.color = color
    ld.size = 2.0
    o = bpy.data.objects.new(name, ld)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.2)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(o)


def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)


def concept_shot(prefix, center_z, dist=4.0, lens=85, size=(832, 1216)):
    """Straight-on front render (prefix_concept.png) after render() has set up the stage: the 2D concept image of a
    Blender-built monster."""
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam_concept", bpy.data.cameras.new("cam_concept"))
    sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.location = (0.0, -dist, center_z + dist * 0.07)
    cam.rotation_euler = (math.radians(86), 0, 0)
    sc.camera = cam
    sc.view_settings.view_transform = "Standard"  # punchy PS2-style color (AgX washes saturated colors out)
    sc.view_settings.exposure = -0.7  # the stage lights are set up for AgX; keep painted colors from blowing out
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = prefix + "_concept.png"
    bpy.ops.render.render(write_still=True)


class SurfacePainter:
    """Lays flat shapes onto a mesh like paint (faces, markings), seen from the front (-Y).
    Shapes are given as (x, z) outlines; every point is ray-cast onto the surface so they wrap over curves."""

    def __init__(self, obj):
        from mathutils.bvhtree import BVHTree
        dg = bpy.context.evaluated_depsgraph_get()
        self.tree = BVHTree.FromObject(obj, dg)
        self.mw = obj.matrix_world.copy()
        self.inv = self.mw.inverted()

    def hit(self, x, z):
        o = self.inv @ Vector((x, -5.0, z))
        d = (self.inv.to_3x3() @ Vector((0, 1, 0))).normalized()
        loc, n, _, _ = self.tree.ray_cast(o, d)
        if loc is None:
            return None, None
        return self.mw @ loc, (self.mw.to_3x3() @ n).normalized()

    def on_surface(self, x, z, lift):
        p, n = self.hit(x, z)
        return p + n * lift

    def decal(self, name, outline, mat, lift=0.004, rings=6, step=0.008):
        dense = []
        for i, (x0, z0) in enumerate(outline):
            x1, z1 = outline[(i + 1) % len(outline)]
            k = max(1, int(math.hypot(x1 - x0, z1 - z0) / step))
            dense += [(x0 + (x1 - x0) * t / k, z0 + (z1 - z0) * t / k) for t in range(k)]
        cx = sum(p[0] for p in dense) / len(dense)
        cz = sum(p[1] for p in dense) / len(dense)
        n = len(dense)
        verts, faces = [], []
        for r in range(rings):
            f = 1 - r / rings
            verts += [tuple(self.on_surface(cx + (x - cx) * f, cz + (z - cz) * f, lift)) for x, z in dense]
        for r in range(rings - 1):
            for i in range(n):
                a0, a1 = r * n + i, r * n + (i + 1) % n
                faces.append((a0, a1, a1 + n, a0 + n))
        verts.append(tuple(self.on_surface(cx, cz, lift)))
        c = len(verts) - 1
        last = (rings - 1) * n
        faces += [(last + i, last + (i + 1) % n, c) for i in range(n)]
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        assign(o, mat)
        return o


def ellipse_pts(cx, cz, rx, rz, a0=0.0, a1=2 * math.pi, n=28, rot=0.0):
    """Outline points of an ellipse (or an arc of one), optionally rotated (radians) around its center."""
    full = abs(a1 - a0) > 6.2
    pts = []
    for i in range(n if full else n + 1):
        a = a0 + (a1 - a0) * i / n
        x, z = rx * math.cos(a), rz * math.sin(a)
        pts.append((cx + x * math.cos(rot) - z * math.sin(rot), cz + x * math.sin(rot) + z * math.cos(rot)))
    return pts


def ps2_finish(objs, name, color_fn, voxel=0.012, smooth=6, faces=24000, ao=0.5, emit=0.0, rough=0.8):
    """MR4/PS2 look for primitive-built parts: merge them into ONE organic mesh (voxel remesh + smoothing), then
    paint it with vertex colors: color_fn(co, normal, t) -> (r, g, b) (t = 0 bottom .. 1 top of the merged mesh),
    multiplied by baked ambient occlusion so the shading is painted in. Matte material named "vcol" (the game shows
    its vertex colors). Returns the merged object."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    m = o.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier="remesh")
    sm = o.modifiers.new("smooth", "LAPLACIANSMOOTH")
    sm.lambda_factor = 0.5
    sm.iterations = smooth
    bpy.ops.object.modifier_apply(modifier="smooth")
    if len(o.data.polygons) > faces:
        d = o.modifiers.new("dec", "DECIMATE")
        d.ratio = faces / len(o.data.polygons)
        bpy.ops.object.modifier_apply(modifier="dec")
    for p in o.data.polygons:
        p.use_smooth = True
    me = o.data
    zs = [v.co.z for v in me.vertices]
    z0, z1 = min(zs), max(zs)
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    base = [color_fn(v.co, v.normal, (v.co.z - z0) / max(1e-6, z1 - z0)) for v in me.vertices]
    if ao > 0:  # bake AO into a temporary attribute (CPU Cycles), then multiply it in
        aoa = me.color_attributes.new("AO", "FLOAT_COLOR", "POINT")
        me.color_attributes.active_color = aoa
        tmp = material("ao_tmp", (1, 1, 1))
        assign(o, tmp)
        sc = bpy.context.scene
        prev = sc.render.engine
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = 64
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
        sc.render.engine = prev
        occ = [aoa.data[i].color[0] for i in range(len(me.vertices))]
        me.color_attributes.remove(aoa)
    else:
        occ = [1.0] * len(me.vertices)
    for i, c in enumerate(base):  # palettes are written as sRGB (like a paint program); vertex colors are linear
        k = 1 - ao + ao * occ[i]
        col.data[i].color = ((c[0] * k) ** 2.2, (c[1] * k) ** 2.2, (c[2] * k) ** 2.2, 1.0)
    me.color_attributes.active_color = col
    mat = bpy.data.materials.new("vcol")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = 0.15
    if emit > 0:
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    assign(o, mat)
    return o
