class_name RanchLayout
extends Node3D
## The ranch, laid out MR4-style and built to expand. Everything is data: buildings, the training yard, plots and
## the dirt paths between them. Add a building = add an entry to SITES (and a builder func if it's a new kind).
## The terrain paints dirt under DIRT (paths + yards) via RanchLayout.dirt(x, z).

# name: [kind, position, yaw degrees]
# Sites not in Game.ranch_upgrades show as an empty staked plot until they're built (an addition to the ranch).
const SITES := {
	"house": ["house", Vector3(-13, 0, 5), -90.0],
	"pen": ["pen", Vector3(13, 0, -1), 90.0],
	"stable": ["stable", Vector3(14, 0, 10), 90.0],
	"training": ["training_yard", Vector3(0, 0, 13), 0.0],
	"storage": ["storage", Vector3(9, 0, -6), 0.0],
	"pond": ["pond", Vector3(-15, 0, -9), 0.0],
}
const ALWAYS := ["pond"]  # nature, not a building
const HUB := Vector3(0, 0, 0)          # the yard in the middle everything connects to
const GATE := Vector3(0, 0, -20)       # where the road leaves the ranch
# dirt paths (segments) and dirt areas (circles: center, radius)
const PATHS := [[Vector3(0, 0, -20), Vector3(0, 0, 0)], [Vector3(0, 0, 0), Vector3(0, 0, 24)], [Vector3(0, 0, 0), Vector3(-6, 0, 5)],
	[Vector3(0, 0, 0), Vector3(9, 0, -1)], [Vector3(0, 0, 0), Vector3(-27, 0, 0)]]
const AREAS := [[Vector3(0, 0, 0), 3.8]]
# path + yard per addition, painted only once it's built
const EXTRA_DIRT := {"stable": [[Vector3(0, 0, 0), Vector3(10, 0, 9)], [Vector3(14, 0, 10), 3.5]],
	"training": [[Vector3(0, 0, 0), Vector3(0, 0, 8)], [Vector3(0, 0, 13), 4.5]], "storage": [[Vector3(0, 0, 0), Vector3(8, 0, -5)], [Vector3(9, 0, -6), 3.0]]}
const ADDITIONS := {"stable": [2500, "Stable", "Room for four more kami."],
	"training": [1200, "Training yard", "A fenced yard with gadget pads for harder drills."],
	"storage": [600, "Storage", "Crates and a trough: keep more food on hand."]}
const WALL_R := 27.0  # the ranch's dry-stone border; openings only at the north and south gates
const GATE_CLEAR := 4.5  # the wall stops this far from a gate's centre: just outside the arch posts (3.4 m) so no stone crowds the road


## How many kami the ranch can house: the starting pen holds one, a stable adds four.
static func capacity() -> int:
	return 1 + (4 if "stable" in Game.ranch_upgrades else 0)


## World position for the nth kami's home spot (in front of the pen / stable).
static func home(i: int) -> Vector3:
	if i == 0:
		return SITES["pen"][1] + Vector3(-3.0, 0, 0)
	return SITES["stable"][1] + Vector3(-4.0, 0, -6.0 + (i - 1) * 3.0)


## 0..1 how much bare dirt is at (x, z): paths, the hub, the training yard, plots.
static var _dirt_key := -1
static var _dirt_paths: Array = []
static var _dirt_areas: Array = []


static func dirt(x: float, z: float) -> float:
	var key := Game.ranch_upgrades.size()   # the path / yard lists only change when a building is added
	if key != _dirt_key:
		_dirt_key = key
		_dirt_paths = PATHS.duplicate()
		_dirt_areas = AREAS.duplicate()
		for k in EXTRA_DIRT:
			if k in Game.ranch_upgrades:
				_dirt_paths.append(EXTRA_DIRT[k][0])
				_dirt_areas.append(EXTRA_DIRT[k][1])
	var p := Vector2(x, z)
	var d := 0.0
	for seg in _dirt_paths:
		var a := Vector2(seg[0].x, seg[0].z)
		var b := Vector2(seg[1].x, seg[1].z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		d = maxf(d, smoothstep(1.7, 0.7, p.distance_to(a + ab * t)))
	for ar in _dirt_areas:
		d = maxf(d, smoothstep(float(ar[1]) + 1.0, float(ar[1]) - 1.5, p.distance_to(Vector2(ar[0].x, ar[0].z))))
	return d


func _ready() -> void:
	_wall()
	_dressing()
	for key in SITES:
		var site: Array = SITES[key]
		var n := Node3D.new()
		n.position = site[1]
		n.rotation_degrees.y = site[2]
		add_child(n)
		if key in ALWAYS or key in Game.ranch_upgrades:
			call("_" + str(site[0]), n)  # not built yet = nothing there (a fresh ranch is bare)


## A point on the terrain (the parent Overworld knows the height); flat 0 when there is none (previews).
func _on_ground(x: float, z: float) -> Vector3:
	var ow := get_parent()
	return Vector3(x, ow.height(x, z) if ow != null and ow.has_method("height") else 0.0, z)


## Ranch clutter (free props): barrels and a bucket by the house, a signpost at each gate.
func _dressing() -> void:
	var h: Vector3 = SITES["house"][1]
	Props.model(self, "ph/wooden_barrels_01", h + Vector3(5.5, 0, -6.5), 1.1, 0.4)
	Props.model(self, "ph/wooden_bucket_01", h + Vector3(4.6, 0, -8.6), 0.4, 0.0, false)
	Props.model(self, "ph/tree_stump_01", h + Vector3(2.0, 0, 7.0), 0.7, 0.0)
	Props.model(self, "ph/hatchet", h + Vector3(2.0, 0.65, 7.0), 0.5, 0.6, false)
	Props.model(self, "sf/signpost_4", _on_ground(4.0, -21.5), 2.3, 0.3, false)   # beside the road, standing on the real ground height
	Props.model(self, "sf/signpost_4", _on_ground(-4.0, 21.5), 2.3, PI + 0.3, false)


## A timber gate arch over a road: tall posts on stone footings, a capped top beam and a tie beam (4.8 m clear).
static func gate_arch(parent: Node3D, at: Vector3, yaw := 0.0) -> void:
	var g := Node3D.new()  # built around its own origin so the arch can face any way
	g.position = at
	g.rotation.y = yaw
	parent.add_child(g)
	parent = g
	var pos := Vector3.ZERO
	var wood := Build.mat("planks012", Vector3(1, 3, 1), Color(0.62, 0.46, 0.32))
	var dark := Build.mat("planks012", Vector3(3, 1, 1), Color(0.4, 0.28, 0.2))
	var stone := Build.mat("rock030", Vector3.ONE, Color(0.7, 0.68, 0.64))
	for x in [-3.4, 3.4]:
		Build.box(parent, pos + Vector3(x, 0.25, 0), Vector3(0.8, 0.5, 0.8), stone, true)
		Build.cyl(parent, pos + Vector3(x, 2.65, 0), 0.22, 0.26, 4.8, wood, true, 10)
	Build.box(parent, pos + Vector3(0, 4.25, 0), Vector3(7.6, 0.3, 0.32), wood)  # tie beam
	Build.box(parent, pos + Vector3(0, 5.15, 0), Vector3(8.8, 0.4, 0.55), dark)  # top beam, overhanging
	Build.box(parent, pos + Vector3(0, 5.42, 0), Vector3(9.2, 0.14, 0.8), dark)  # cap
	Build.box(parent, pos + Vector3(0, 4.7, 0), Vector3(0.25, 0.75, 0.3), wood)  # centre strut


func _rock_wall(rocks: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2701
	var lists: Array = []
	for r in rocks:
		lists.append([])
	var n := 120
	for i in n:
		var a := TAU * (i + 0.5) / n
		var p := Vector3(cos(a), 0, sin(a)) * WALL_R
		if (absf(p.x) < GATE_CLEAR and absf(p.z) > 15.0) or (absf(p.z) < GATE_CLEAR and p.x < -15.0):  # gate openings: north, south and the west trail
			continue
		var tang := Vector3(-sin(a), 0, cos(a))   # along the wall: a stone rests on the lowest ground under its length, so it never floats on a slope
		var gy := minf(_on_ground(p.x, p.z).y, minf(_on_ground(p.x + tang.x * 0.8, p.z + tang.z * 0.8).y, _on_ground(p.x - tang.x * 0.8, p.z - tang.z * 0.8).y)) - 0.03
		for course in 2:
			var v := rng.randi() % rocks.size()
			var bb: AABB = rocks[v][2]
			var want := Vector3(1.6, 0.62 if course == 0 else 0.5, 0.95)  # each stone about this big
			var sc := Vector3(want.x / maxf(bb.size.x, 0.01), want.y / maxf(bb.size.y, 0.01), want.z / maxf(bb.size.z, 0.01))
			var basis := Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.2, 0.2)).scaled(sc * rng.randf_range(0.9, 1.15))
			var origin := p + Vector3(cos(a), 0, sin(a)) * rng.randf_range(-0.1, 0.1) + Vector3(0, gy + [0.0, 0.40][course], 0)
			var t := Transform3D(basis, origin) * Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
			(lists[v] as Array).append(t)
	for v in rocks.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = rocks[v][0]
		mm.instance_count = (lists[v] as Array).size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, lists[v][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if rocks[v][1] != null:
			mmi.material_override = rocks[v][1]
		add_child(mmi)
	var sb := StaticBody3D.new()  # collision: plain segments along the ring
	add_child(sb)
	for i in 128:
		var a := TAU * (i + 0.5) / 128
		var p := Vector3(cos(a), 0, sin(a)) * WALL_R
		if (absf(p.x) < GATE_CLEAR and absf(p.z) > 15.0) or (absf(p.z) < GATE_CLEAR and p.x < -15.0):
			continue
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(TAU * WALL_R / 128 + 0.3, 1.2, 1.0)
		cs.shape = bx
		cs.position = Vector3(p.x, _on_ground(p.x, p.z).y + 0.6, p.z)
		cs.rotation.y = -a + PI * 0.5
		sb.add_child(cs)


## A low dry-stone wall around the ranch with openings at the two gates (you leave only by the roads).
func _wall() -> void:
	var rocks := Props.parts("ph/wall_rocks") if Quality.level > 0 else []   # 240 scanned stones = 260k triangles: boxes on the weakest tier  # scanned mossy stones (Poly Haven CC0), stacked into a dry-stone wall
	if not rocks.is_empty():
		_rock_wall(rocks)
		return
	# visible stones: two courses of irregular blocks and flat capstones, drawn as one MultiMesh (cheap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2701
	var xf: Array[Transform3D] = []
	var n := 150
	for i in n:
		var a := TAU * (i + 0.5) / n
		var p := Vector3(cos(a), 0, sin(a)) * WALL_R
		if (absf(p.x) < GATE_CLEAR and absf(p.z) > 15.0) or (absf(p.z) < GATE_CLEAR and p.x < -15.0):  # gate openings (north, south, west trail)
			continue
		var len := TAU * WALL_R / n
		var gy := _on_ground(p.x, p.z).y
		for course in 3:
			var h: float = [0.5, 0.42, 0.22][course]
			var y: float = [0.25, 0.72, 1.04][course]
			var w: float = [0.95, 0.8, 1.0][course]
			var b := Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.12, 0.12))
			b = b.scaled(Vector3(len * rng.randf_range(1.0, 1.35), h * rng.randf_range(0.85, 1.15), w * rng.randf_range(0.85, 1.1)))
			var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(-0.08, 0.08)
			xf.append(Transform3D(b, p + off + Vector3(0, gy + y, 0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Build.mat("rock030", Vector3(0.6, 0.4, 1), Color(0.86, 0.84, 0.8))
	add_child(mmi)
	# collision: plain segments along the ring (with the same gate openings)
	var sb := StaticBody3D.new()
	add_child(sb)
	for i in 128:
		var a := TAU * (i + 0.5) / 128
		var p := Vector3(cos(a), 0, sin(a)) * WALL_R
		if (absf(p.x) < GATE_CLEAR and absf(p.z) > 15.0) or (absf(p.z) < GATE_CLEAR and p.x < -15.0):
			continue
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(TAU * WALL_R / 128 + 0.3, 1.2, 0.9)
		cs.shape = bx
		cs.position = Vector3(p.x, _on_ground(p.x, p.z).y + 0.6, p.z)
		cs.rotation.y = -a + PI * 0.5
		sb.add_child(cs)


# ---------------------------------------------------------------- builders (local space: front = -Z)

func _house(n: Node3D) -> void:  # your farmhouse: the AI-built cabin on stilts (assets/props/bld_ranch.glb)
	if ResourceLoader.exists("res://assets/props/bld_ranch.glb"):
		var m: Node3D = (load("res://assets/props/bld_ranch.glb") as PackedScene).instantiate()
		Props.fix(m)
		m.rotation.y = PI  # turned so its big deck (barrels, sliding doors) faces the yard: local -Z
		n.add_child(m)
		if not Props.lite:
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).create_trimesh_collision()  # walk on the deck, not through the walls
		# a plank ramp from the yard up to the deck (1.4 m high, 3.5 m run)
		var wood := Build.mat("planks012", Vector3(1, 3, 1), Color(0.78, 0.62, 0.44))
		Build.box(n, Vector3(0, 0.66, -6.35), Vector3(1.6, 0.14, 3.78), wood, true, Vector3(-0.38, 0, 0))
		for x in [-0.85, 0.85]:  # side stringers
			Build.box(n, Vector3(x, 0.72, -6.35), Vector3(0.12, 0.26, 3.78), wood, false, Vector3(-0.38, 0, 0))
		return
	_cyl(n, Vector3(0, 1.7, 0), 4.0, 4.2, 3.4, "woodsiding008", Vector3(7, 1.6, 1), true)
	_cyl(n, Vector3(0, 5.1, 0), 0.15, 5.6, 3.6, "roofingtiles006", Vector3(6, 2, 1), false)
	_box(n, Vector3(0, 1.2, -4.15), Vector3(1.6, 2.4, 0.2), "planks012", Vector3(1, 1, 1), false)
	_box(n, Vector3(0, 0.08, -5.0), Vector3(2.4, 0.16, 1.4), "planks012", Vector3(2, 1, 1), false)  # porch step


## Place an AI-built model from assets/props (front turned toward local -Z), with mesh collision. False if missing.
func _ai_model(n: Node3D, name: String, scale: float) -> bool:
	var path := "res://assets/props/%s.glb" % name
	if not ResourceLoader.exists(path):
		return false
	var m: Node3D = (load(path) as PackedScene).instantiate()
	Props.fix(m)
	m.scale = Vector3.ONE * scale
	m.rotation.y = PI
	n.add_child(m)
	if not Props.lite:  # a simple box: fast to build, and wandering kami can't get caught in fence gaps
		_box_collider(n, MonsterModel.bounds(m), scale)
	return true


func _box_collider(n: Node3D, bb: AABB, k: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(bb.size.x * k, bb.size.y * k, bb.size.z * k)
	cs.shape = bx
	cs.position = Vector3(-bb.get_center().x * k, bb.get_center().y * k, -bb.get_center().z * k)
	sb.add_child(cs)
	n.add_child(sb)


func _pen(n: Node3D) -> void:  # the starting shelter: a tidy lean-to with a straw bed, water and a feed box
	if ResourceLoader.exists("res://assets/props/bld_pen.glb"):  # the AI-built kami hut (back wall filled in)
		var m: Node3D = (load("res://assets/props/bld_pen.glb") as PackedScene).instantiate()
		Props.fix(m)
		m.scale = Vector3.ONE * 1.5  # roomy enough for a full-size kami
		m.rotation.y = PI  # its arched doorway faces the yard (local -Z)
		n.add_child(m)
		if not Props.lite:
			_box_collider(n, MonsterModel.bounds(m), 1.5)
		return
	var wall := Build.mat("woodsiding008", Vector3(2, 1.2, 1))
	Build.box(n, Vector3(0, 1.3, 1.6), Vector3(4.0, 2.6, 0.2), wall, true)
	for x in [-2.0, 2.0]:
		Build.box(n, Vector3(x, 1.0, 0.6), Vector3(0.2, 2.0, 2.2), wall, true)
	var roof := Build.box(n, Vector3(0, 2.62, 0.45), Vector3(4.6, 0.15, 3.0), Build.mat("roofingtiles006", Vector3(2, 1, 1)))
	roof.rotation_degrees.x = -14.0
	Build.box(n, Vector3(0, 0.05, 0.6), Vector3(3.8, 0.1, 2.0), Build.mat("planks012", Vector3(2, 1, 1)))
	Build.ball(n, Vector3(-0.5, 0.18, 0.8), 0.9, Vector3(1.3, 0.22, 0.9), Build.mat("", Vector3.ONE, Color(0.86, 0.74, 0.42)))  # straw bed
	Build.cyl(n, Vector3(1.4, 0.15, -0.6), 0.32, 0.26, 0.22, Build.mat("planks012", Vector3.ONE, Color(0.55, 0.4, 0.28)), true, 12)
	Build.cyl(n, Vector3(1.4, 0.24, -0.6), 0.27, 0.27, 0.04, Build.mat("", Vector3.ONE, Color(0.25, 0.5, 0.65)), false, 12)  # water
	Build.box(n, Vector3(-1.5, 0.3, -0.7), Vector3(0.9, 0.5, 0.6), Build.mat("planks012", Vector3.ONE, Color(0.7, 0.52, 0.34)), true)


func _stable(n: Node3D) -> void:  # kami stable: back wall, side walls, sloped roof, open front with stalls
	if _ai_model(n, "bld_stable", 2.2):  # the AI-built barn: lantern porch, loft, fenced front
		return
	var w := 12.0
	var d := 5.0
	_box(n, Vector3(0, 1.6, d / 2), Vector3(w, 3.2, 0.3), "woodsiding008", Vector3(5, 1.5, 1), true)
	for x in [-w / 2, w / 2]:
		_box(n, Vector3(x, 1.6, 0), Vector3(0.3, 3.2, d), "woodsiding008", Vector3(2, 1.5, 1), true)
	var roof := _box(n, Vector3(0, 3.6, 0), Vector3(w + 1.2, 0.2, d + 1.6), "roofingtiles006", Vector3(5, 2, 1), false)
	roof.rotation_degrees.x = -12.0
	for k in 4:  # stall dividers + front posts: room for 4 kami, extend by widening
		var x := -w / 2 + (k + 1) * w / 4
		if k < 3:
			_box(n, Vector3(x, 0.9, 0.6), Vector3(0.15, 1.8, d - 1.2), "planks012", Vector3(1, 1, 1), true)
		_box(n, Vector3(x - w / 8, 1.6, -d / 2), Vector3(0.22, 3.2, 0.22), "planks012", Vector3(1, 2, 1), true)
	_box(n, Vector3(0, 0.05, 0), Vector3(w, 0.1, d), "planks012", Vector3(6, 3, 1), false)  # straw-boarded floor


func _training_yard(n: Node3D) -> void:  # fenced yard with 4 gadget pads (training gadgets go here later)
	var r := 7.0
	var gap := 0.5  # gap at the front (-Z) so you can walk in
	for k in 20:
		var a0 := k / 20.0 * TAU
		var a1 := (k + 1) / 20.0 * TAU
		if absf(wrapf(a0 - (-PI / 2), -PI, PI)) < gap:
			continue
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		_box(n, p0 + Vector3(0, 0.6, 0), Vector3(0.18, 1.2, 0.18), "planks012", Vector3(1, 1, 1), true)
		var mid := (p0 + p1) / 2
		var rail := _box(n, mid + Vector3(0, 0.85, 0), Vector3(p0.distance_to(p1), 0.12, 0.08), "planks012", Vector3(1, 1, 1), false)
		rail.rotation.y = -atan2(p1.z - p0.z, p1.x - p0.x)
	for k in 4:
		var p := Vector3(-3.0 + (k % 2) * 6.0, 0.04, -2.5 + (k / 2) * 5.0)
		_box(n, p, Vector3(2.4, 0.08, 2.4), "rock030", Vector3(1, 1, 1), false)


func _storage(n: Node3D) -> void:  # feed and supplies: crates, barrels, a trough
	for k in 5:
		var p := Vector3(-1.5 + (k % 3) * 1.1, 0.5 + (k / 3) * 1.0, (k / 3) * 0.2)
		_box(n, p, Vector3(1.0, 1.0, 1.0), "planks012", Vector3(1, 1, 1), true)
	_cyl(n, Vector3(2.0, 0.6, 0.3), 0.5, 0.5, 1.2, "planks012", Vector3(2, 1, 1), true)
	if ResourceLoader.exists("res://assets/props/trough.glb"):
		_glb(n, "res://assets/props/trough.glb", Vector3(0, 0, 2.5), 0.0)


func _pond(n: Node3D) -> void:
	if ResourceLoader.exists("res://assets/props/pond.glb"):
		var p := _glb(n, "res://assets/props/pond.glb", Vector3.ZERO, 0.0)
		Props.water_swap(p)
		var sb := StaticBody3D.new()  # the pond is for looking at: a low wall of collision round the water keeps the player out
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 3.5
		cyl.height = 2.0
		cs.shape = cyl
		cs.position.y = 0.5
		sb.add_child(cs)
		n.add_child(sb)


func _plot(n: Node3D) -> void:  # an empty plot staked out for a future building
	for c in [Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(3, 0, 3), Vector3(-3, 0, 3)]:
		_box(n, c + Vector3(0, 0.45, 0), Vector3(0.1, 0.9, 0.1), "planks012", Vector3(1, 1, 1), false)
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.8, 0.7, 0.45)
	for e in [[Vector3(-3, 0, -3), Vector3(3, 0, -3)], [Vector3(3, 0, -3), Vector3(3, 0, 3)], [Vector3(3, 0, 3), Vector3(-3, 0, 3)], [Vector3(-3, 0, 3), Vector3(-3, 0, -3)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(e[0].distance_to(e[1]), 0.03, 0.03)
		mi.mesh = bm
		mi.material_override = rope
		mi.position = (e[0] + e[1]) / 2 + Vector3(0, 0.8, 0)
		mi.rotation.y = -atan2(e[1].z - e[0].z, e[1].x - e[0].x)
		n.add_child(mi)


# ---------------------------------------------------------------- helpers

func _mat(tex: String, scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_color.jpg" % tex)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/%s_normal.jpg" % tex)
	m.uv1_scale = scale
	m.roughness = 0.9
	return m


func _box(n: Node3D, p: Vector3, size: Vector3, tex: String, uv: Vector3, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(tex, uv)
	mi.position = p
	n.add_child(mi)
	if solid:
		mi.create_convex_collision()
	return mi


func _cyl(n: Node3D, p: Vector3, top: float, bottom: float, h: float, tex: String, uv: Vector3, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = _mat(tex, uv)
	mi.position = p
	n.add_child(mi)
	if solid:
		mi.create_convex_collision()
	return mi


func _glb(n: Node3D, path: String, p: Vector3, yaw: float) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.position = p
	node.rotation_degrees.y = yaw
	n.add_child(node)
	Props.fix(node)
	return node
