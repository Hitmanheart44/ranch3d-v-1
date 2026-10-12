class_name Overworld
extends Node3D
## The v2 world (VISION.md): one continuous map. The ranch sits in a flat valley; a dirt road winds out of the
## ranch gate and climbs a hill to the shrine plateau. PS2-style painted look: terrain painted by shader (grass
## patches, dirt road, rock on slopes), wind-swayed grass clumps, forests, painted sky with clouds, haze.

const STEP := 2.0
const RANCH := Vector3(0, 0, 0)
const SEA_Y := -26.0
const LIGHTHOUSE := Vector3(95, SEA_Y, -30)
const SHRINE_C := Vector3(18, 6, -52)        # shrine on the hill just outside the north gate (top height 6 m)
const TOWN_C := Vector3(16.5, -8, 92)         # the town square, halfway down the harbor street
const ROAD2_CTRL := [Vector3(0, 0, 16), Vector3(0, 0, 26), Vector3(0, 0, 33), Vector3(5, 0, 42), Vector3(7, 0, 52)]
# The harbor street: from the top of town (where the ranch road arrives) down a valley to the quay. y = ground.
const STREET := [Vector3(7, 0, 52), Vector3(10, -2, 66), Vector3(13, -6, 80), Vector3(16, -8, 87), Vector3(17, -8, 97),
	Vector3(20, -12, 108), Vector3(24, -17, 121), Vector3(29, -21, 132), Vector3(33, -23, 140)]
const COVE := Vector3(47, SEA_Y, 142)          # the harbor basin cut into the cliffs
# each zone builds only its own region (x, z, w, d): keeps what's on screen and in memory small
const REGIONS := {"ranch": Rect2(-70, -60, 140, 120), "shrine": Rect2(-30, -110, 110, 90), "town": Rect2(-40, 40, 120, 110),
	"intro": Rect2(-60, -100, 130, 160)}  # the intro's flyover: ranch + north road + shrine in one view

@export var zone := "ranch"
var region := Rect2(-70, -60, 140, 120)
var road2: PackedVector3Array = []
const ROAD_CTRL := [Vector3(0, 0, -16), Vector3(0, 0, -24), Vector3(0, 0, -31), Vector3(8, 0, -33), Vector3(14, 0, -33.5), Vector3(18, 0, -34)]   # runs straight through the ranch gate, then bends to the shrine

var road: PackedVector3Array = []            # dense road centerline (y = road height)
var road_t: PackedFloat32Array = []
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	region = REGIONS.get(zone, region)
	rng.seed = 7
	noise.seed = 3
	noise.frequency = 0.012
	noise2.seed = 11
	noise2.frequency = 0.05
	_build_road()
	Prof.mark("_build_road()")
	_environment()
	Prof.mark("_environment()")
	var ground := TerrainGround.build(self, self)
	Prof.mark("terrain total")
	GroundCover.grass(ground, self)
	Prof.mark("grass + flowers")
	ScatterDress.build(self, self)
	Prof.mark("ScatterDress.build(self, self)")
	_far_terrain()
	Prof.mark("_far_terrain()")
	_far_forest()
	if zone != "town":
		_road_fences()
	Prof.mark("_far_forest()")
	_forest()
	Prof.mark("_forest()")
	_mountains()
	Prof.mark("_mountains()")
	_sea()
	Prof.mark("_sea()")
	if zone == "ranch" or zone == "intro":
		_ranch()
	if zone == "shrine" or zone == "intro":
		_shrine()
	elif zone == "town":
		add_child(TownLayout.new())
	# the neighbouring zones, as look-only scenery, so you see the ranch from the shrine, the town from the road...
	if zone != "ranch" and zone != "intro":
		_scenery(RanchLayout.new())
	if zone != "shrine" and zone != "intro":
		var k := KamiLayout.new()
		k.position = SHRINE_C
		k.rotation.y = PI
		_scenery(k)
	if zone != "town":
		_scenery(TownLayout.new())


# ---------------------------------------------------------------- shape

func _build_road() -> void:
	var pts: Array = ROAD_CTRL
	for i in pts.size() - 1:  # Catmull-Rom through the control points
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		for k in 12:
			var t := k / 12.0
			road.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	road.append(pts[-1])
	var total := 0.0
	road_t.append(0.0)
	for i in range(1, road.size()):
		total += road[i].distance_to(road[i - 1])
		road_t.append(total)
	for i in road.size():  # road climbs from the valley to the plateau
		var t := road_t[i] / total
		road[i].y = SHRINE_C.y * smoothstep(0.12, 0.97, t)
	var p2: Array = ROAD2_CTRL
	for i in p2.size() - 1:
		for k in 8:
			road2.append((p2[i] as Vector3).lerp(p2[i + 1], k / 8.0))
	road2.append(p2[-1])


## Distance (xz) to the nearest road and the road height there.
func road_info(x: float, z: float) -> Vector2:
	var best := 1e9
	var h := 0.0
	var p := Vector2(x, z)
	for rd in [road, road2]:
		var r2 := _road_seg(rd, p)
		if r2.x < best:
			best = r2.x
			h = r2.y
	return Vector2(best, h)


func _road_seg(rd: PackedVector3Array, p: Vector2) -> Vector2:
	var best := 1e9
	var h := 0.0
	for i in rd.size() - 1:
		var a := Vector2(rd[i].x, rd[i].z)
		var b := Vector2(rd[i + 1].x, rd[i + 1].z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			h = lerpf(rd[i].y, rd[i + 1].y, t)
	return Vector2(best, h)


## Distance to the harbor street (x), its ground height there (y), how far along it 0..1 (z).
static func street_info(x: float, z: float) -> Vector3:
	if _street_lens.is_empty():   # segment lengths and the total, computed once (this runs for every height() sample)
		for i in STREET.size() - 1:
			var l := Vector2(STREET[i + 1].x - STREET[i].x, STREET[i + 1].z - STREET[i].z).length()
			_street_lens.append(l)
			_street_total += l
	var best := 1e9
	var out := Vector3(1e9, 0, 0)
	var run := 0.0
	var q := Vector2(x, z)
	for i in STREET.size() - 1:
		var a := Vector2(STREET[i].x, STREET[i].z)
		var b := Vector2(STREET[i + 1].x, STREET[i + 1].z)
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var d := q.distance_to(a.lerp(b, t))
		if d < best:
			best = d
			out = Vector3(d, lerpf(STREET[i].y, STREET[i + 1].y, smoothstep(0.0, 1.0, t)), (run + _street_lens[i] * t) / _street_total)
		run += _street_lens[i]
	return out


static var _street_lens: Array[float] = []
static var _street_total := 0.0


## Point on the harbor street at fraction s (0 top .. 1 quay), with its ground height, and the street's direction.
static func street_at(s: float) -> Array:
	var total := 0.0
	for i in STREET.size() - 1:
		total += Vector2(STREET[i + 1].x - STREET[i].x, STREET[i + 1].z - STREET[i].z).length()
	var want := s * total
	for i in STREET.size() - 1:
		var a: Vector3 = STREET[i]
		var b: Vector3 = STREET[i + 1]
		var l := Vector2(b.x - a.x, b.z - a.z).length()
		if want <= l or i == STREET.size() - 2:
			var t := clampf(want / l, 0.0, 1.0)
			var p := a.lerp(b, t)
			p.y = lerpf(a.y, b.y, smoothstep(0.0, 1.0, t))
			return [p, Vector3(b.x - a.x, 0, b.z - a.z).normalized()]
		want -= l
	return [STREET[-1], Vector3.BACK]


## x of the cliff edge at depth z: the sea is east (+x).
static func coast(z: float) -> float:
	return 44.0 + sin(z * 0.045) * 7.0 + sin(z * 0.13 + 1.0) * 2.5


func height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 6.0 + noise2.get_noise_2d(x, z) * 1.5
	var inland := clampf((coast(z) - 12.0 - x) / 30.0, 0.0, 1.0)            # 0 near the cliffs, 1 inland
	var r := Vector2(x * 0.8, z).length()
	h += pow(clampf((r - 58.0) / 45.0, 0.0, 1.0), 2.0) * 34.0 * inland      # mountains rise behind the ranch
	var ds := Vector2(x - SHRINE_C.x, z - SHRINE_C.z).length()
	h += SHRINE_C.y * smoothstep(40.0, 22.0, ds) * 0.85                   # the shrine hill
	h = lerpf(h, 0.0, smoothstep(36.0, 27.0, Vector2(x - RANCH.x, z - RANCH.z).length()))   # ranch valley floor
	h = lerpf(h, SHRINE_C.y, smoothstep(27.0, 23.0, ds))                 # plateau top
	var ri := road_info(x, z)
	h = lerpf(h, ri.y, smoothstep(8.0, 3.5, ri.x))                        # road bed
	var st := street_info(x, z)                                           # the town's valley, stepping down to the harbor
	h = lerpf(h, st.y + maxf(0.0, st.x - 9.0) * 0.3, smoothstep(36.0, 12.0, st.x))  # gentle valley sides
	h = lerpf(h, SEA_Y - 6.0, smoothstep(13.5, 10.0, Vector2(x - COVE.x, z - COVE.z).length()))  # harbor water, deep
	if st.x < 30.0:  # level pads under the town's buildings
		for b in TownLayout.buildings().values():
			var bp: Vector3 = b[0]
			var pad_r := Vector2(float(b[3]), float(b[4])).length() * 0.5 + 0.8   # the pad reaches past the footprint corners
			var dd := Vector2(x - bp.x, z - bp.z).length()
			if dd < pad_r + 4.0:
				h = lerpf(h, bp.y, smoothstep(pad_r + 4.0, pad_r + 0.5, dd))
	var dx := x - coast(z) + noise2.get_noise_2d(z * 2.0, x) * 2.5
	if dx > -3.0:                                                         # the cliffs, straight down to the sea
		h = lerpf(h, SEA_Y - 4.0, smoothstep(-3.0, 6.0, dx))
	return h


# ---------------------------------------------------------------- terrain

## Low-detail terrain over the whole map outside this zone's region: the horizon stays continuous (same hills,
## ridges and cliffs) while only the zone itself is built in full detail. No collision, no dressing.
## The low-detail horizon mesh. Cached per zone by tools/bake/bake_far.gd (building it samples height() ~13k times and
## pushes ~70k vertices through SurfaceTool); falls back to building it live when the cache is missing.
func _far_terrain() -> void:
	var path := "res://assets/terrain/far_%s.res" % zone
	var mesh: ArrayMesh = load(path) if ResourceLoader.exists(path) else build_far_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = TERRAIN
	for k in ["grass004", "grass001", "ground037", "rock030"]:
		sm.set_shader_parameter(k, load("res://assets/tex/%s_color.jpg" % k))
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func build_far_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := region.grow(-6.0)
	# 5 m cells across the play area (neighbour zones keep their roads, yards and the town's valley), 10 m beyond
	for g in [[-80.0, 2.5, 64, Rect2(), 0.25], [-160.0, 5.0, 64, Rect2(-75, -75, 150, 150), 0.6], [-320.0, 10.0, 64, Rect2(-150, -150, 300, 300), 1.2]]:
		var lo: float = g[0]
		var step: float = g[1]
		var n: int = g[2]
		var hole: Rect2 = g[3]
		var hs := {}
		var cs := {}
		var ns := {}
		for j in n + 1:
			for i in n + 1:
				var x := lo + i * step
				var z := lo + j * step
				hs[Vector2i(i, j)] = height(x, z) - float(g[4])
				var ri := road_info(x, z)
				cs[Vector2i(i, j)] = Color(smoothstep(3.6, 2.0, ri.x), maxf(RanchLayout.dirt(x, z), 1.0 if TownLayout.paved(x, z) else 0.0), 0.0, 1.0)
		for j in n + 1:   # smooth normals from the height field, so big far triangles do not shade as flat facets
			for i in n + 1:
				var hc: float = hs[Vector2i(i, j)]
				var hl: float = hs.get(Vector2i(i - 1, j), hc)
				var hr: float = hs.get(Vector2i(i + 1, j), hc)
				var hd: float = hs.get(Vector2i(i, j - 1), hc)
				var hu: float = hs.get(Vector2i(i, j + 1), hc)
				ns[Vector2i(i, j)] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
		for j in n:
			for i in n:
				var c2 := Vector2(lo + (i + 0.5) * step, lo + (j + 0.5) * step)
				if inner.has_point(c2) or hole.has_point(c2):
					continue
				for c in [[0, 0], [1, 0], [0, 1], [1, 0], [1, 1], [0, 1]]:
					var k := Vector2i(i + c[0], j + c[1])
					st.set_color(cs[k])
					st.set_normal(ns[k])
					st.add_vertex(Vector3(lo + k.x * step, hs[k], lo + k.y * step))
	return st.commit()


## Distant trees on the far terrain (no collision, instanced) so the hills around each zone aren't bare.
func _far_forest() -> void:
	var parts: Array = _card_tree(1)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var xf: Array[Transform3D] = []
	var inner := region.grow(-4.0)
	for i in int(2600 * clampf(Quality.density() * 1.5, 0.15, 1.0)):
		var p := Vector2(r.randf_range(-260, 160), r.randf_range(-260, 260))
		if inner.has_point(p) or p.x > coast(p.y) - 6.0 or road_info(p.x, p.y).x < 7.0 or p.length() < 30.0:
			continue
		if street_info(p.x, p.y).x < 20.0 or Vector2(p.x - SHRINE_C.x, p.y - SHRINE_C.z).length() < 26.0:
			continue
		if noise.get_noise_2d(p.x * 2.0, p.y * 2.0) < -0.1:  # clumps and clearings, not an even carpet
			continue
		var s := r.randf_range(0.9, 1.5)
		xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, height(p.x, p.y) - 0.3, p.y)))
		if xf.size() >= int(700 * clampf(Quality.density() * 1.5, 0.15, 1.0)):
			break
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = part[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ---------------------------------------------------------------- dressing

## The Sketchfab pine (CC-BY, see CREDITS) as MultiMesh parts: [mesh, material, local transform], 10 m tall.
static func _pine_parts() -> Array:
	var path := "res://assets/props/sf/tree_pine11.glb"
	if not ResourceLoader.exists(path):
		return []
	var root: Node3D = (load(path) as PackedScene).instantiate()
	var bb := MonsterModel.bounds(root)
	var k := 10.0 / maxf(bb.size.y, 0.01)
	var base := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(-bb.get_center().x * k, -bb.position.y * k, -bb.get_center().z * k))
	var out: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local := base * _rel(m, root)
		for i in m.mesh.get_surface_count():
			var single := ArrayMesh.new()
			single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.mesh.surface_get_arrays(i))
			var mat := m.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				mat = (mat as BaseMaterial3D).duplicate()
				(mat as BaseMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
			out.append([single, mat, local])
	root.free()
	return out


static func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _forest() -> void:
	var variants: Array = []
	var pine := _pine_parts()
	for k in 3:
		variants.append(pine if not pine.is_empty() else _card_tree(k))
	var colliders := Node3D.new()
	add_child(colliders)
	var xf: Array = [[], [], []]
	var tries := 0
	var count := 0
	while count < int(70 * clampf(Quality.density() * 2.0, 0.3, 1.0)) and tries < 8000:
		tries += 1
		var p := Vector2(rng.randf_range(region.position.x, region.end.x), rng.randf_range(region.position.y, region.end.y))
		if p.length() < 33.0 or Vector2(p.x - SHRINE_C.x, p.y - SHRINE_C.z).length() < 26.0 or street_info(p.x, p.y).x < 20.0:
			continue
		if road_info(p.x, p.y).x < 6.0 or p.x > coast(p.y) - 6.0:
			continue
		var s := rng.randf_range(0.8, 1.35)
		(xf[count % 3] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, height(p.x, p.y) - 0.2, p.y)))
		count += 1
	for v in 3:
		for part in variants[v]:  # [mesh, material, (local transform)]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = (xf[v] as Array).size()
			var local: Transform3D = part[2] if part.size() > 2 else Transform3D.IDENTITY
			for i in mm.instance_count:
				mm.set_instance_transform(i, (xf[v][i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = part[1]
			add_child(mmi)
		for t in xf[v]:
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.45 * (t as Transform3D).basis.get_scale().x
			cy.height = 4.0
			cs.shape = cy
			sb.position = (t as Transform3D).origin + Vector3(0, 2.0, 0)
			sb.add_child(cs)
			colliders.add_child(sb)


## A PS2-style broadleaf tree: bark-textured trunk and limbs, and a crown of leaf-cluster cards whose normals
## point out from the crown center (so the crown shades like one soft leafy ball).
static func _card_tree(variant: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = 100 + variant
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_top := Vector3(r.randf_range(-0.3, 0.3), 4.2, r.randf_range(-0.3, 0.3))
	_limb(bark, Vector3(0, -0.3, 0), trunk_top, 0.42, 0.26)
	var crown_c := trunk_top + Vector3(0, 1.8, 0)
	for k in 5:
		var a := k / 5.0 * TAU + r.randf_range(-0.3, 0.3)
		var tip := crown_c + Vector3(cos(a) * 2.2, r.randf_range(-0.6, 0.8), sin(a) * 2.2)
		_limb(bark, trunk_top - Vector3(0, 0.6, 0), tip, 0.2, 0.06)
	bark.generate_normals()
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_texture = load("res://assets/tex/bark007_color.jpg")
	bark_mat.normal_enabled = true
	bark_mat.normal_texture = load("res://assets/tex/bark007_normal.jpg")
	bark_mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	bark_mat.albedo_color = Color(0.45, 0.38, 0.32)
	bark_mat.roughness = 0.95
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := Vector3(3.2, 2.6, 3.2)
	for k in 110:
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(-0.7, 1), r.randf_range(-1, 1)).normalized()
		var depth := sqrt(r.randf()) * 0.85 + 0.15
		var c := crown_c + d * radii * depth
		var size := r.randf_range(2.0, 3.0)
		var nrm := (c - crown_c).normalized()
		var basis := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-1.2, 1.2)) * Basis(Vector3.FORWARD, r.randf() * TAU)
		var ax := basis.x * size * 0.5
		var ay := basis.y * size * 0.5
		var corners := [c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			leaves.set_normal(((corners[idx] as Vector3) - crown_c).normalized().lerp(Vector3.UP, 0.25).normalized())
			leaves.set_uv(uvs[idx])
			leaves.add_vertex(corners[idx])
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_texture = load("res://assets/tex/foliage_%s.png" % ["a", "b", "c"][variant])
	leaf_mat.albedo_color = [Color(0.26, 0.42, 0.2), Color(0.22, 0.36, 0.18), Color(0.3, 0.42, 0.18)][variant]
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_mat.alpha_scissor_threshold = 0.45
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.roughness = 0.9
	leaf_mat.backlight_enabled = true
	leaf_mat.backlight = Color(0.25, 0.35, 0.1)
	return [[bark.commit(), bark_mat], [leaves.commit(), leaf_mat]]


static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var seg := 8
	var rings := 4
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var up := side.cross(axis)
	var length := a.distance_to(b)
	for j in rings:
		for i in seg:
			var quad := []
			for corner in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var t := float(corner[1]) / rings
				var ang := float(corner[0]) / seg * TAU
				var rad := lerpf(r0, r1, t)
				var p := a.lerp(b, t) + (side * cos(ang) + up * sin(ang)) * rad
				quad.append([p, Vector2(float(corner[0]) / seg * 2.0, t * length / 2.0)])
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(quad[idx][1])
				st.add_vertex(quad[idx][0])


func _mountains() -> void:
	var path := "res://assets/props/mountain.glb"
	if not ResourceLoader.exists(path):
		return
	for k in 14:
		var a := lerpf(0.75, 2.4 * PI - 0.75, k / 13.0) + PI * 0.5   # an arc around the west side
		var r := rng.randf_range(210.0, 250.0)
		var mp := Vector3(cos(a) * r, -4.0, sin(a) * r)
		if mp.x > coast(mp.z) - 40.0:
			continue  # inland only, never out in the sea
		var m := (load(path) as PackedScene).instantiate() as Node3D
		m.position = mp
		m.scale = Vector3.ONE * rng.randf_range(0.7, 1.1)
		m.rotation.y = rng.randf() * TAU
		add_child(m)
		Props.fix(m)


func _sea() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	sea.mesh = pm
	sea.position = Vector3(470, SEA_Y, 0)  # only out past the cliffs
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = OCEAN
	sea.material_override = sm
	add_child(sea)
	# foam where the waves hit the cliffs: a strip along the coastline at sea level
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -120.0
	while z < 120.0:
		var z2 := z + 2.0
		var a0 := Vector3(coast(z) + 4.0, SEA_Y + 0.15, z)
		var a1 := Vector3(coast(z2) + 4.0, SEA_Y + 0.15, z2)
		var b0 := a0 + Vector3(9.0, 0, 0)
		var b1 := a1 + Vector3(9.0, 0, 0)
		for v in [[a0, 0.0], [b0, 1.0], [b1, 1.0], [a0, 0.0], [b1, 1.0], [a1, 0.0]]:
			st.set_uv(Vector2(v[1], (v[0] as Vector3).z * 0.1))
			st.add_vertex(v[0])
		z = z2
	var foam := MeshInstance3D.new()
	foam.mesh = st.commit()
	var fm := ShaderMaterial.new()
	fm.shader = Shader.new()
	fm.shader.code = FOAM
	foam.material_override = fm
	add_child(foam)
	_lighthouse(LIGHTHOUSE)


func _lighthouse(base: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 14.0
	sp.height = 16.0
	rock.mesh = sp
	rock.position = base + Vector3(0, 2.0, 0)
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load("res://assets/tex/rock030_color.jpg")
	rm.uv1_scale = Vector3(4, 4, 1)
	rock.material_override = rm
	if Props.model(self, "ph/boulder_01", base + Vector3(0, -6.0, 0), 15.0, 0.6, false) == null:  # scanned rock (CC0)
		add_child(rock)
	else:
		rock.free()
	var y := base.y + 8.0
	var tower := Props.model(self, "sf/lighthouse_9", Vector3(base.x, y - 0.5, base.z), 24.0, 0.0, false)  # Sketchfab CC-BY
	for k in (0 if tower != null else 6):  # white and red bands (fallback when the model is missing)
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 2.6 - (k + 1) * 0.2
		cm.bottom_radius = 2.6 - k * 0.2
		cm.height = 3.2
		seg.mesh = cm
		seg.position = Vector3(base.x, y + 1.6, base.z)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.9, 0.85) if k % 2 == 0 else Color(0.75, 0.12, 0.1)
		seg.material_override = m
		add_child(seg)
		y += 3.2
	if tower != null:
		y = base.y + 8.0 + 24.0 - 3.6  # the lantern room near the top of the model
	var top := Vector3(base.x, y + 1.0, base.z)
	var lamp := MeshInstance3D.new()   # the lantern itself: small and warm
	var lm := SphereMesh.new()
	lm.radius = 0.55
	lm.height = 1.1
	lamp.mesh = lm
	lamp.position = top
	lamp.material_override = HitFx.glow_mat(Color(1.0, 0.88, 0.55), 3.0)
	add_child(lamp)
	var glow := MeshInstance3D.new()   # soft halo, always facing the camera
	var gq := QuadMesh.new()
	gq.size = Vector2(7.0, 7.0)
	glow.mesh = gq
	glow.material_override = _soft_shader("""
		float d = length(UV - vec2(0.5)) * 2.0;
		float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.5) * 0.7;
		ALBEDO = vec3(1.0, 0.85, 0.5); ALPHA = a;""", true)
	glow.position = top
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var pivot := Node3D.new()   # two slow, feathered beams (flat ribbons that fade out along and across)
	pivot.position = top
	add_child(pivot)
	for sgn in [1.0, -1.0]:
		var beam := MeshInstance3D.new()
		var bq := QuadMesh.new()
		bq.size = Vector2(46.0, 7.0)
		beam.mesh = bq
		beam.material_override = _soft_shader("""
			float along = UV.x;
			float across = abs(UV.y - 0.5) * 2.0;
			float a = pow(1.0 - along, 1.6) * (1.0 - across * across) * smoothstep(0.0, 0.05, along) * 0.22;
			ALBEDO = vec3(1.0, 0.92, 0.68); ALPHA = a;""", false)
		beam.rotation_degrees = Vector3(-90, 0, 0)
		beam.position = Vector3(sgn * 23.0, 0, 0)
		beam.scale.x = sgn
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(beam)
	var tw := create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", TAU, 14.0).from(0.0)


## An unshaded additive material from a fragment snippet (sets ALBEDO / ALPHA); billboard = faces the camera.
func _soft_shader(frag: String, billboard: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never;\n" \
		+ ("void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); }\n" if billboard else "") \
		+ "void fragment() {" + frag + "}\n"
	return m


func _ranch() -> void:
	add_child(RanchLayout.new())
	# ranch gate where the road leaves the valley
	RanchLayout.gate_arch(self, Vector3(0, 0, -RanchLayout.WALL_R))


func _box(p: Vector3, size: Vector3, m: Material, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	add_child(mi)
	if solid:
		mi.create_convex_collision()


## A rustic post-and-rail fence (with collision) down the left-hand side of the shrine road, from the ranch gate arch to the
## torii's red pillar, so you cannot cut across the grass to the shrine. Skips the ranch itself and the shrine plateau.
## One fence span: a post at `p` and two rails back to `q`, with collision.
func _fence_span(sb: StaticBody3D, post_xf: Array[Transform3D], rail_xf: Array[Transform3D], q: Vector3, p: Vector3) -> void:
	var y := height(p.x, p.z)
	var yq := height(q.x, q.z)
	var span := p - q
	var len := span.length()
	var mid := (p + q) / 2.0
	var ym := (y + yq) / 2.0
	post_xf.append(Transform3D(Basis().scaled(Vector3(0.16, 1.2, 0.16)), Vector3(p.x, y + 0.6, p.z)))
	var rail := Basis.looking_at(Vector3(span.x, y - yq, span.z).normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.08, 0.1, len + 0.1))
	rail_xf.append(Transform3D(rail, Vector3(mid.x, ym + 0.95, mid.z)))
	rail_xf.append(Transform3D(rail, Vector3(mid.x, ym + 0.5, mid.z)))
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.3, 2.0, len)
	cs.shape = bx
	cs.transform = Transform3D(Basis.looking_at(Vector3(span.x, 0, span.z).normalized(), Vector3.UP), Vector3(mid.x, ym + 1.0, mid.z))
	sb.add_child(cs)


func _road_fences() -> void:
	var wood := Build.mat("planks012", Vector3(1, 2, 1), Color(0.55, 0.4, 0.28))
	var sb := StaticBody3D.new()
	add_child(sb)
	var post_xf: Array[Transform3D] = []
	var rail_xf: Array[Transform3D] = []
	# One line from the ranch gate to the torii's west pillar: the road's left-hand edge, easing in toward the pillar's own
	# side over the last stretch so it arrives along the road's direction, with no kink.
	var line: Array[Vector3] = []
	var pillar_w := Vector3(SHRINE_C.x - 1.86, 0, SHRINE_C.z + 16.0)
	var pts := PackedVector3Array()
	for i in road.size():
		pts.append(Vector3(road[i].x, 0, road[i].z))
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var seg: Vector3 = pts[i] - a
		var dir := seg.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var l := seg.length()
		var t := 0.0
		while t < l:
			var c := a + dir * t
			t += 2.5
			if Vector2(c.x, c.z).length() < RanchLayout.WALL_R + 0.5:
				continue
			if c.z > 58.0 or not region.grow(-3.0).has_point(Vector2(c.x, c.z)):
				continue
			var dist := Vector2(c.x - pillar_w.x, c.z - pillar_w.z).length()
			if dist < 14.0 and (c - pillar_w).dot(dir) >= 0.0:
				continue   # past the pillar along the road: the fence ends there
			var off := 4.3
			if dist < 14.0:
				var lat_p := -((pillar_w - c).dot(side))   # how far left of the road the pillar stands
				off = lerpf(4.3, lat_p, 1.0 - clampf((dist - 1.0) / 13.0, 0.0, 1.0))
			line.append(c - side * off)   # the left-hand side
	if line.size() >= 1:
		var pillar := pillar_w
		if line[-1].distance_to(pillar) < 0.4:
			line[-1] = pillar
		else:
			line.append(pillar)
		var length := 0.0
		for i in range(1, line.size()):
			length += line[i].distance_to(line[i - 1])
		var count := maxi(1, int(round(length / 2.5)))
		var step := length / count
		var posts: Array[Vector3] = [line[0]]   # evenly spaced posts along the whole line; the last one stands on the pillar
		var seg_i := 1
		var from: Vector3 = line[0]
		var left := step
		while posts.size() <= count and seg_i < line.size():
			var to: Vector3 = line[seg_i]
			var d := from.distance_to(to)
			if d >= left - 0.0001:
				from = from.lerp(to, left / maxf(d, 0.0001))
				posts.append(from)
				left = step
			else:
				left -= d
				from = to
				seg_i += 1
		posts[posts.size() - 1] = line[-1]
		var first: Vector3 = posts[0]
		post_xf.append(Transform3D(Basis().scaled(Vector3(0.16, 1.2, 0.16)), Vector3(first.x, height(first.x, first.z) + 0.6, first.z)))
		for i in range(1, posts.size()):
			_fence_span(sb, post_xf, rail_xf, posts[i - 1], posts[i])
	# the last stretch: from the torii's east pillar out to where the ground starts to drop away. The fence ends there; an invisible
	# collision strip then runs on to the cliff wall, so there is no gap and no way through.
	if region.grow(-3.0).has_point(Vector2(SHRINE_C.x + 1.86, SHRINE_C.z + 16.0)):
		var east := Vector3(SHRINE_C.x + 1.86, 0, SHRINE_C.z + 16.0)
		var wall_x := coast(east.z) - 2.5   # the cliff wall that keeps you off the edge
		var drop_x := wall_x
		var xx := east.x + 2.0
		while xx < wall_x + 3.0:   # the real brink can lie inside the invisible wall
			if height(xx, east.z) < height(xx - 1.0, east.z) - 0.7:   # the ground starts to fall away
				drop_x = xx - 1.0
				break
			xx += 0.5
		var edge := Vector3(drop_x - 0.6, 0, east.z)   # the last post stands just inside the brink
		var run := east.distance_to(edge)
		if run > 1.0:
			var n_spans := maxi(1, int(round(run / 2.5)))
			post_xf.append(Transform3D(Basis().scaled(Vector3(0.16, 1.2, 0.16)), Vector3(east.x, height(east.x, east.z) + 0.6, east.z)))
			for k in range(1, n_spans + 1):
				_fence_span(sb, post_xf, rail_xf, east.lerp(edge, float(k - 1) / n_spans), east.lerp(edge, float(k) / n_spans))
		if wall_x - edge.x > 0.05:   # the unseen seal from the last post to the cliff wall
			var seal := CollisionShape3D.new()
			var sbx := BoxShape3D.new()
			sbx.size = Vector3(wall_x - edge.x + 0.6, 3.0, 0.5)
			seal.shape = sbx
			seal.position = Vector3((edge.x + wall_x) / 2.0 + 0.3, height(edge.x, east.z) + 1.5, east.z)
			sb.add_child(seal)
	for set in [post_xf, rail_xf]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new()
		mm.instance_count = set.size()
		for i in set.size():
			mm.set_instance_transform(i, set[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = wood
		add_child(mi)


## Add a layout as distant scenery only: no collision, lights, particles or shadows (cheap on old machines).
func _scenery(n: Node3D) -> void:
	if Quality.level == 0:   # neighbouring zones as far scenery cost ~25k triangles per building: skipped on the weakest tier
		n.queue_free()
		return
	Props.lite = true
	add_child(n)
	Props.lite = false
	for c in n.find_children("*", "", true, false):
		if c is CollisionObject3D or c is Light3D or c is GPUParticles3D or c is CPUParticles3D:
			c.queue_free()
		elif c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _shrine() -> void:
	var k := KamiLayout.new()
	k.position = SHRINE_C
	k.rotation.y = PI  # its torii faces the road arriving from the ranch side
	add_child(k)


# ---------------------------------------------------------------- sky and light

func _environment() -> void:
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/tex/sky_morning.hdr")
	pano.energy_multiplier = 1.0
	sky.sky_material = pano
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = Quality.glow()
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.78, 0.66)
	env.fog_density = 0.0016
	env.fog_sun_scatter = 0.25
	env.fog_sky_affect = 0.35   # the horizon dissolves into the haze instead of cutting hard
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82  # muted, earthy PS2 palette (not candy-bright)
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 150, 0)
	sun.light_color = Color(1.0, 0.85, 0.66)
	sun.light_energy = 1.15
	sun.shadow_enabled = Quality.shadows()
	sun.directional_shadow_max_distance = Quality.shadow_distance()
	if Quality.level >= 2:   # two cascades: crisp contact shadows near the camera, soft ones further out
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = 0.22
		sun.shadow_blur = 1.4
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # cheapest; fine for a compact valley
	add_child(sun)
	Atmosphere.attach(self, sun, env, pano)   # time of day + season weather


const NOISE := """
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1, 0)), f.x), mix(hsh(i + vec2(0, 1)), hsh(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += vn(p) * a; p *= 2.03; a *= 0.5; } return s; }
"""

const TERRAIN := """
shader_type spatial;
uniform sampler2D grass004 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass001 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground037 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock030 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;
varying vec4 vc;
""" + NOISE + """
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; vc = COLOR; }
vec3 tex2(sampler2D t, vec2 uv) {  // two scales, blended, to hide tiling
	return mix(texture(t, uv).rgb, texture(t, uv * 0.27 + 0.37).rgb, 0.4);
}
void fragment() {
	vec3 nw = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float slope = 1.0 - clamp(nw.y, 0.0, 1.0);
	float macro = fbm(wp.xz * 0.03);
	vec3 g = mix(tex2(grass004, wp.xz / 3.0), tex2(grass001, wp.xz / 3.4), smoothstep(0.35, 0.65, macro));
	g *= mix(0.6, 0.95, fbm(wp.xz * 0.11)) * vec3(0.82, 1.08, 0.62);   // lusher green
	vec3 dirt = tex2(ground037, wp.xz / 2.6) * vec3(0.8, 0.68, 0.52);   // packed earth, not sand
	dirt *= mix(0.85, 1.05, vn(wp.xz * 0.7));
	float grain = (vn(wp.xz * 2.1) - 0.5) * 0.45 + (fbm(wp.xz * 0.35) - 0.5) * 0.35;  // grass tufts eat into the edges
	float road = smoothstep(0.35, 0.8, vc.r + grain);
	float yard = smoothstep(0.4, 0.85, vc.g + grain) * 0.9;
	vec3 c = mix(g, dirt, max(road, yard));
	c = mix(c, g * 0.75, smoothstep(0.0, 0.25, max(road, yard)) * (1.0 - smoothstep(0.25, 0.6, max(road, yard))) * 0.5);  // trodden rim
	vec3 bw = pow(abs(nw), vec3(4.0)); bw /= (bw.x + bw.y + bw.z);
	vec3 rock = (texture(rock030, wp.zy / 4.0).rgb * bw.x + texture(rock030, wp.xz / 4.0).rgb * bw.y + texture(rock030, wp.xy / 4.0).rgb * bw.z)
		* vec3(0.85, 0.83, 0.8);
	float crag = smoothstep(0.2, 0.42, slope + (fbm(wp.xz * 0.08) - 0.5) * 0.25);  // rock shows through on the hillsides
	c = mix(c, rock, crag);
	c *= mix(1.0, 0.82, smoothstep(0.15, 0.35, slope) * (1.0 - crag));  // slopes a little darker than the flats
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""

const OCEAN := """
shader_type spatial;
varying vec3 wp;
""" + NOISE + """
float wave(vec2 p, float t) { return sin(p.x * 0.08 + t * 0.9) * 0.35 + sin(p.y * 0.11 - t * 0.7) * 0.25 + vn(p * 0.15 + t * 0.2) * 0.4; }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; VERTEX.y += wave(wp.xz, TIME); }
void fragment() {
	float t = TIME;
	float e = 0.5;
	float w0 = wave(wp.xz, t);
	vec3 n = normalize(vec3(w0 - wave(wp.xz + vec2(e, 0), t), 0.6, w0 - wave(wp.xz + vec2(0, e), t)));
	n = normalize(n + vec3(vn(wp.xz * 0.6 + t * 0.3) - 0.5, 0.0, vn(wp.xz * 0.6 - t * 0.25) - 0.5) * 0.4);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	vec3 deep = vec3(0.02, 0.12, 0.28), shallow = vec3(0.05, 0.32, 0.45);
	vec3 c = mix(deep, shallow, smoothstep(0.2, 0.8, vn(wp.xz * 0.02)) * 0.6);
	float caps = smoothstep(0.78, 0.92, vn(wp.xz * 0.35 + vec2(t * 0.4, t * 0.1))) * 0.5;
	ALBEDO = mix(c, vec3(0.75, 0.85, 0.92), caps * 0.45 + fres * 0.2);
	ROUGHNESS = 0.25;
	SPECULAR = 0.4;
}
"""

const FOAM := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;
""" + NOISE + """
void fragment() {
	float edge = 1.0 - UV.x;
	float n = vn(vec2(UV.x * 6.0 - TIME * 0.8, UV.y * 3.0)) * 0.6 + vn(vec2(UV.x * 14.0 - TIME * 1.4, UV.y * 9.0)) * 0.4;
	float a = smoothstep(0.35, 0.7, n * edge + edge * 0.5) * edge;
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = a * 0.85;
}
"""
