class_name TownLayout
extends Node3D
## The harbor town (its own zone): one street runs down a valley from where the ranch road arrives to a stone quay
## and pier in a cove. Shops and homes line both sides facing the street; the square with the well sits halfway;
## the Trainers' Association hall stands at the bottom by the harbor, facing up the street.
## Buildings use AI-built models (assets/props/bld_<kind>.glb, see ART_SLOTS.md) when they exist, plain placeholders until then.

const C := Overworld.TOWN_C
const SQUARE_R := 7.5
# name: [fraction down the street, side (-1 west, +1 east), setback from the street center, kind, width, depth, height]
const PLAN := {
	"workshop": [0.1, -1, 8.0, "workshop", 8.0, 6.5, 4.5],
	"home_a": [0.13, 1, 7.5, "home", 7.0, 6.0, 4.2],
	"item_shop": [0.28, 1, 7.5, "shop", 7.0, 6.0, 4.3],
	"food_shop": [0.31, -1, 7.5, "shop", 8.0, 6.0, 4.3],
	"home_b": [0.56, -1, 7.5, "home", 7.0, 6.0, 4.2],
	"home_c": [0.6, 1, 7.5, "home", 6.5, 6.0, 4.0],
	"home_d": [0.74, -1, 7.5, "home", 7.0, 6.0, 4.2],
	"association": [0.93, 1, 12.0, "hall", 13.0, 9.0, 6.5],
}
const SHOW_SQUARE_PROPS := false   # the square's well and market stalls (placeholder dressing); true brings them back
const QUAY := Vector3(33, -23, 140)
const PIER_END := Vector3(41.5, -23, 141)
static var _cache := {}


## Each building: [position (ground y), yaw (deg, front faces the street), kind, width, depth, height].
static func buildings() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for k in PLAN:
		var pl: Array = PLAN[k]
		var sa: Array = Overworld.street_at(pl[0])
		var dir: Vector3 = sa[1]
		var side := Vector3(-dir.z, 0, dir.x) * float(pl[1])  # +1 = east of a southbound street
		var pos: Vector3 = (sa[0] as Vector3) + side * float(pl[2])
		var f := -side  # the front faces the street
		if k == "association":  # turned to look up the street
			f = (f - dir).normalized()
		_cache[k] = [pos, rad_to_deg(atan2(-f.x, -f.z)), pl[3], pl[4], pl[5], pl[6]]
	return _cache


## Where you stand to talk at / enter each building (in front of its door).
static func door(name: String) -> Vector3:
	var b: Array = buildings()[name]
	var yaw := deg_to_rad(float(b[1]))
	return (b[0] as Vector3) + Vector3(-sin(yaw), 0, -cos(yaw)) * (float(b[4]) / 2.0 + 1.8)


## True where the ground is paved: the street, the square, the quay.
static func paved(x: float, z: float) -> bool:
	if Vector2(x - C.x, z - C.z).length() < SQUARE_R or Vector2(x - QUAY.x, z - QUAY.z).length() < 7.0:
		return true
	return Overworld.street_info(x, z).x < 3.0 and z > 50.0


func _ready() -> void:
	var ow := get_parent()
	var bs := buildings()
	for k in bs:
		var b: Array = bs[k]
		var n := Node3D.new()
		n.position = b[0]
		n.position.y = (b[0] as Vector3).y  # the terrain is levelled to this pad (Overworld.height)
		n.rotation_degrees.y = b[1]
		add_child(n)
		_building(n, b[2], b[3], b[4], b[5])
	if SHOW_SQUARE_PROPS:
		_well(Vector3(C.x + 2.5, C.y, C.z + 1.0))
		var cloths := [Color(0.55, 0.22, 0.16), Color(0.7, 0.62, 0.42), Color(0.25, 0.32, 0.42)]
		for k in 2:  # market stalls along the west side of the square
			var p := C + Vector3(-5.0, 0, -3.5 + k * 6.0)
			_stall(p, PI / 2, cloths[k])
	_chimneys()
	_dressing(ow)
	var glow := Build.mat("", Vector3.ONE, Color(1.0, 0.72, 0.4), 2.0)
	var post := Build.mat("planks012", Vector3.ONE, Color(0.3, 0.24, 0.2))
	var lamp_at := lamp_spots()
	for i in 7:  # lamp posts down the street, alternating sides
		var p: Vector3 = lamp_at[i]
		p.y = ow.height(p.x, p.z) if ow.has_method("height") else p.y
		if Props.model(self, "sf/lamp_6", p, 3.2, -float(i) * 0.3, false) == null:
			Build.cyl(self, p + Vector3(0, 1.3, 0), 0.07, 0.09, 2.6, post, true, 6)
			Build.box(self, p + Vector3(0, 2.75, 0), Vector3(0.32, 0.4, 0.32), glow)
		var lamp_light := OmniLight3D.new()
		lamp_light.position = p + Vector3(0, 2.9, 0)
		lamp_light.light_color = Color(1.0, 0.75, 0.45)
		lamp_light.light_energy = 0.6
		lamp_light.omni_range = 5.0
		add_child(lamp_light)


func _building(n: Node3D, kind: String, w: float, d: float, h: float) -> void:
	var model := "res://assets/props/bld_%s.glb" % kind
	if kind == "workshop" and not ResourceLoader.exists(model):  # Goro works out of a shop-style building for now
		model = "res://assets/props/bld_shop.glb"
	if model != "" and ResourceLoader.exists(model):  # the AI-built building, scaled to its footprint
		var m: Node3D = (load(model) as PackedScene).instantiate()
		Props.fix(m)
		var bb := MonsterModel.bounds(m)
		var k := minf(w / maxf(bb.size.x, 0.01), d / maxf(bb.size.z, 0.01))
		m.scale = Vector3.ONE * k
		m.rotation.y = PI  # models face +Z; building fronts face -Z here
		m.position.y = -bb.position.y * k
		n.add_child(m)
		if not Props.lite:
			_footprint(n, w, d, h)
		return
	# placeholder until the model is approved: plaster and dark timber, grey tiles, a stone plinth for the slope
	var wall := Build.mat("woodsiding008", Vector3(w / 2.0, h / 2.0, 1), Color(0.72, 0.68, 0.6))
	Build.box(n, Vector3(0, h / 2.0, 0), Vector3(w, h, d), wall, true)
	Build.box(n, Vector3(0, -1.2, 0), Vector3(w + 0.4, 3.0, d + 0.4), Build.mat("rock030", Vector3(2, 1, 1), Color(0.55, 0.53, 0.5)))
	var roof := Build.mat("roofingtiles006", Vector3(w / 2.5, 2, 1), Color(0.38, 0.38, 0.4))
	for sx in [-1, 1]:  # gable roof, ridge along the width
		Build.box(n, Vector3(0, h + d * 0.22, sx * d * 0.27), Vector3(w + 0.8, 0.14, d * 0.62), roof, false, Vector3(sx * 0.5, 0, 0))
	Build.box(n, Vector3(0, 1.15, -d / 2.0 - 0.06), Vector3(1.4, 2.3, 0.1), Build.mat("planks012", Vector3.ONE, Color(0.32, 0.22, 0.15)))


## Where the moored ship lies: its long side flush against the shore, the whole hull in the water. The waterline is read off the
## terrain near the old quay; the ship is sized down until its footprint is clear of the land. Returns [centre, yaw, height].
static func ship_berth(ow: Node) -> Array:
	var wet := func(x: float, z: float) -> bool: return ow.height(x, z) < Overworld.SEA_Y - 0.3
	var d0 := (Vector3(Overworld.COVE.x, 0, Overworld.COVE.z) - Vector3(QUAY.x, 0, QUAY.z)).normalized()
	var shore := Vector3(QUAY.x, 0, QUAY.z)   # the first water along a line from the quay toward the middle of the cove
	for i in 400:
		if wet.call(shore.x, shore.z):
			break
		shore += d0 * 0.1
	var gx: float = ow.height(shore.x + 1.0, shore.z) - ow.height(shore.x - 1.0, shore.z)
	var gz: float = ow.height(shore.x, shore.z + 1.0) - ow.height(shore.x, shore.z - 1.0)
	var n := Vector3(-gx, 0, -gz).normalized()   # out over the water (downhill)
	var t := Vector3(-n.z, 0, n.x)               # along the shore
	var k := 1.0
	while k > 0.35:
		var len := 19.53 * k
		var wid := 4.68 * k
		# the shore line: how far along n the land reaches at each point along the hull's length
		var reach := -99.0
		var low := 99.0
		var s := -len / 2.0
		while s <= len / 2.0:
			var base := shore + t * s
			var o := -4.0
			while o < 8.0 and not wet.call(base.x + n.x * o, base.z + n.z * o):
				o += 0.1
			reach = maxf(reach, o)
			low = minf(low, o)
			s += 1.0
		if reach - low > 0.9:   # the shore curves away from a straight hull here: a shorter ship is needed to lie flush
			k -= 0.05
			continue
		var side := reach - 0.3                   # seated a little into the bank at the shore's highest point, so the hull lies flush along it
		var centre := shore + n * (side + wid / 2.0)
		var clear := true
		for sx in [-0.5, 0.0, 0.5]:
			for sz in [0.5, 1.0]:   # the water-facing half of the footprint
				var q: Vector3 = centre + t * (len * float(sx)) + n * (wid * (float(sz) - 0.5))
				if not wet.call(q.x, q.z):
					clear = false
		if clear:
			return [Vector3(centre.x, Overworld.SEA_Y - 0.6 * k, centre.z), atan2(t.x, t.z), 16.0 * k]
		k -= 0.05
	return [PIER_END + Vector3(1.0, -3.6, 4.2), PI / 2, 16.0]


## Where the street's lamp posts stand (alternating sides): dressing props keep clear of these.
static func _near_lamp(p: Vector3, lamps: Array) -> bool:
	for l in lamps:
		if Vector2(p.x - l.x, p.z - l.z).length() < 1.4:
			return true
	return false


static func lamp_spots() -> Array:
	var out: Array = []
	for i in 7:
		var sa: Array = Overworld.street_at(0.06 + i * 0.14)
		var dir: Vector3 = sa[1]
		out.append((sa[0] as Vector3) + Vector3(-dir.z, 0, dir.x) * (3.6 if i % 2 == 0 else -3.6))
	return out


## Free props (Poly Haven CC0 / Sketchfab CC-BY, see CREDITS) beside the buildings and along the street.
func _dressing(ow: Node) -> void:
	var bs := buildings()
	var spots := {  # building -> [[prop, local offset beside its front (x right, z out), height, yaw]]
		"workshop": [["sf/cart_4", Vector3(4.2, 0, 1.0), 1.4, 0.4], ["ph/wooden_crate_01", Vector3(-3.6, 0, 1.2), 0.7, 0.2],
			["ph/wooden_crate_02", Vector3(-4.3, 0, 0.4), 0.55, 1.1], ["ph/wooden_ladder", Vector3(3.0, 0, -0.2), 2.4, 0.0]],
		"food_shop": [["ph/wicker_basket_02", Vector3(2.6, 0, 1.0), 0.5, 0.3], ["ph/wooden_barrels_01", Vector3(-2.8, 0, 0.8), 1.0, 0.8]],
		"item_shop": [["ph/wine_barrel_01", Vector3(2.6, 0, 0.9), 1.0, 0.0], ["ph/planter_box_01", Vector3(-2.6, 0, 0.9), 0.5, 0.0]],
		"home_a": [["ph/wooden_bucket_01", Vector3(2.2, 0, 1.0), 0.4, 0.5], ["ph/planter_pot_clay", Vector3(-2.2, 0, 1.0), 0.5, 0.0]],
		"home_b": [["ph/painted_wooden_bench", Vector3(2.0, 0, 1.0), 0.8, 0.0], ["ph/wooden_bucket_02", Vector3(-2.3, 0, 0.9), 0.35, 0.0]],
		"home_c": [["ph/planter_box_02", Vector3(-2.0, 0, 1.0), 0.5, 0.0], ["ph/wooden_broom", Vector3(2.4, 0, 0.6), 1.4, 0.3]],
		"home_d": [["ph/wicker_basket_01", Vector3(2.1, 0, 1.0), 0.35, 0.0], ["ph/wooden_stool_01", Vector3(-2.1, 0, 1.0), 0.6, 0.4]],
		"association": [["sf/stone_lantern_6", Vector3(3.6, 0, 2.0), 1.9, 0.0], ["sf/stone_lantern_6", Vector3(-3.6, 0, 2.0), 1.9, 0.0]],
	}
	var lamps := lamp_spots()
	for k in spots:
		if not bs.has(k):
			continue
		var b: Array = bs[k]
		var yaw := deg_to_rad(float(b[1]))
		var front := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		for it in spots[k]:
			var o: Vector3 = it[1]
			var pos: Vector3 = (b[0] as Vector3) + front * (float(b[4]) / 2.0 + o.z) + right * o.x
			if _near_lamp(pos, lamps):   # a lamp post stands there: try the building's other side, else leave the prop out
				pos = (b[0] as Vector3) + front * (float(b[4]) / 2.0 + o.z) + right * -o.x
				if _near_lamp(pos, lamps):
					continue
			pos.y = ow.height(pos.x, pos.z) if ow.has_method("height") else pos.y
			Props.model(self, it[0], pos, it[2], yaw + float(it[3]), it[2] > 0.6)
	var top: Array = Overworld.street_at(0.03)  # a signpost where the road from the ranch comes into town
	var sp: Vector3 = (top[0] as Vector3) + Vector3(3.2, 0, 0)
	sp.y = ow.height(sp.x, sp.z) if ow.has_method("height") else sp.y
	Props.model(self, "sf/signpost_4", sp, 2.3, PI * 0.8, false)
	var berth := ship_berth(ow)
	Props.model(self, "ph/ship_pinnace", berth[0], berth[2], berth[1], false)   # moored flush against the shore


func _footprint(n: Node3D, w: float, d: float, h: float) -> void:  # invisible collision for a model building
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(w * 0.9, h, d * 0.9)
	cs.shape = bx
	cs.position.y = h / 2.0
	sb.add_child(cs)
	n.add_child(sb)


func _chimneys() -> void:  # a wisp of smoke over each home
	var bs := buildings()
	for k in bs:
		if bs[k][2] != "home":
			continue
		var b: Array = bs[k]
		var p := GPUParticles3D.new()
		p.amount = 14
		p.lifetime = 4.0
		p.position = (b[0] as Vector3) + Vector3(0, float(b[5]) + float(b[4]) * 0.3 + 0.8, 0)
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.3, 1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 0.4
		pm.initial_velocity_max = 0.7
		pm.gravity = Vector3(0.2, 0.15, 0)
		pm.scale_min = 1.0
		pm.scale_max = 2.4
		var fade := Gradient.new()
		fade.set_color(0, Color(0.85, 0.85, 0.85, 0.5))
		fade.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = fade
		pm.color_ramp = gt
		p.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.6, 0.6)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = KamiLayout._dot()
		quad.material = mat
		p.draw_pass_1 = quad
		add_child(p)


func _well(p: Vector3) -> void:
	if Props.model(self, "sf/well_3", p, 3.2) != null:
		return
	var stone := Build.mat("rock030", Vector3(2, 1, 1), Color(0.8, 0.77, 0.72))
	Build.cyl(self, p + Vector3(0, 0.45, 0), 1.3, 1.4, 0.9, stone, true, 20)
	var water := Build.cyl(self, p + Vector3(0, 0.82, 0), 1.1, 1.1, 0.04, Build.mat("", Vector3.ONE, Color(0.2, 0.5, 0.6)), false, 20)
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = RanchWorld.WATER
	water.material_override = sm
	var wood := Build.mat("planks012", Vector3(1, 2, 1), Color(0.55, 0.38, 0.24))
	for x in [-1.2, 1.2]:
		Build.box(self, p + Vector3(x, 1.5, 0), Vector3(0.15, 1.6, 0.15), wood)
	Build.box(self, p + Vector3(0, 2.4, 0), Vector3(3.0, 0.12, 1.6), Build.mat("roofingtiles006", Vector3(2, 1, 1), Color(0.8, 0.45, 0.35)), false, Vector3(0.25, 0, 0))


func _stall(p: Vector3, yaw: float, cloth: Color) -> void:
	if Props.model(self, "sf/market_stall_1", p, 2.3, yaw + PI) != null:
		return
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	var wood := Build.mat("planks012", Vector3.ONE, Color(0.6, 0.42, 0.26))
	Build.box(n, Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 1.0), wood, true)
	for x in [-1.2, 1.2]:
		for z in [-0.45, 0.45]:
			Build.box(n, Vector3(x, 1.2, z), Vector3(0.1, 2.4, 0.1), wood)
	Build.box(n, Vector3(0, 2.45, -0.2), Vector3(2.9, 0.06, 1.7), Build.mat("", Vector3.ONE, cloth), false, Vector3(-0.2, 0, 0))
	var goods := [Color(0.7, 0.3, 0.22), Color(0.78, 0.62, 0.28), Color(0.42, 0.58, 0.3)]
	for k in 5:  # produce on the counter
		Build.ball(n, Vector3(-0.9 + k * 0.45, 1.12, 0), 0.16, Vector3.ONE, Build.mat("", Vector3.ONE, goods[k % 3]))
