class_name KamiLayout
extends Node3D
## The shrine-ranch layout (VISION.md): torii entrance, a lantern-lined stepping-stone path to the shrine yard
## (sacred tree, hokora = the summoning shrine, machine stones, bamboo fence), plus drifting kami wisps.
## Props come from tools/blender/kami_props.py (res://assets/props/kami/).

const DIR := "res://assets/props/kami/"
const SHRINE := Vector3(9.0, 0, 14.0)  # the hokora; the summoning spot is just in front of it

var lanterns: Array[Node3D] = []


func _ready() -> void:
	var gate := Vector3(0, 0, -16)
	_put("torii", gate, 0.0, 1.45)  # tall enough to walk under with room to spare
	# stepping-stone path from the torii to the shrine yard, lanterns in pairs along it
	var path_end := SHRINE + Vector3(-1.5, 0, -4.0)
	var n := 16
	for i in n + 1:
		var t := float(i) / n
		var p := gate.lerp(path_end, t) + Vector3(sin(t * 5.0) * 0.6, 0, 0)
		_put("stepping_stone", p + Vector3(0, 0.01, 0), randf() * 360.0, randf_range(0.85, 1.15))
		if i % 4 == 2:
			var side := (path_end - gate).normalized().cross(Vector3.UP)
			for s in [-1.6, 1.6]:
				lanterns.append(_put("lantern", p + side * s, 0.0))
	# shrine yard
	_put("sacred_tree", SHRINE + Vector3(5.5, 0, 4.0), 30.0)
	_put("hokora", SHRINE, 112.0)   # the porch and stairs are the model's +x side (measured); this turns them toward the stone path
	# machine stones go back in when their model exists (concept approved; the primitive stand-ins looked wrong)
	for k in 7:  # bamboo fence arc around the back of the yard
		var a := -0.3 + k * 0.45
		var p := SHRINE + Vector3(cos(a), 0, sin(a)) * 8.5
		_put("bamboo_fence", p, -rad_to_deg(a) + 90.0)
	_wisps(SHRINE + Vector3(0, 1.5, 0), 5.0, 60)
	_wisps(Vector3(0, 2.0, 0), 22.0, 90)


## Each shrine prop is built here from textured primitives (Build), matching the ranch's look.
func _put(name: String, pos: Vector3, yaw: float, s: float = 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * s
	add_child(n)
	var model := {"torii": ["sf/torii_s23", 4.4, false], "lantern": ["sf/stone_lantern_6", 1.9, true], "hokora": ["sf/hokora_s16", 3.4, true]}
	if model.has(name) and Props.model(n, model[name][0], Vector3.ZERO, model[name][1], 0.0, model[name][2]) != null:
		if name == "torii":  # walk-through gate: collide on the two pillars only
			for x in [-1.28, 1.28]:   # the model's real pillar feet (measured), not the old guess of 1.9
				Build.pillar_collider(n, Vector3(x, 0, 0), 0.42, 4.2)
		return n
	call("_" + name, n)
	return n


func _torii(n: Node3D) -> void:
	var red := Build.mat("planks012", Vector3(1, 3, 1), Color(0.95, 0.28, 0.16))
	var black := Build.mat("planks012", Vector3(3, 1, 1), Color(0.18, 0.15, 0.14))
	for x in [-1.9, 1.9]:
		Build.cyl(n, Vector3(x, 2.1, 0), 0.19, 0.23, 4.2, red)
		Build.cyl(n, Vector3(x, 0.15, 0), 0.3, 0.32, 0.3, black)
		Build.pillar_collider(n, Vector3(x, 0, 0), 0.3, 4.2)
	Build.box(n, Vector3(0, 3.15, 0), Vector3(4.6, 0.24, 0.26), red)
	Build.box(n, Vector3(0, 3.5, 0), Vector3(0.26, 0.5, 0.2), red)
	Build.box(n, Vector3(0, 3.8, 0), Vector3(5.0, 0.22, 0.34), red)
	var top := Build.box(n, Vector3(0, 4.05, 0), Vector3(5.6, 0.26, 0.44), black)
	for sx in [-1, 1]:  # the top beam sweeps up at its ends
		Build.box(n, Vector3(sx * 2.9, 4.13, 0), Vector3(0.7, 0.24, 0.44), black, false, Vector3(0, 0, sx * 0.25))
	top.name = "kasagi"


func _lantern(n: Node3D) -> void:
	var stone := Build.mat("rock030", Vector3(1, 1, 1), Color(0.85, 0.82, 0.76))
	Build.cyl(n, Vector3(0, 0.12, 0), 0.38, 0.42, 0.24, stone, true, 6)
	Build.cyl(n, Vector3(0, 0.6, 0), 0.12, 0.14, 0.8, stone, false, 8)
	Build.cyl(n, Vector3(0, 1.05, 0), 0.34, 0.3, 0.12, stone, false, 6)
	Build.box(n, Vector3(0, 1.3, 0), Vector3(0.42, 0.38, 0.42), stone)
	var glow := Build.mat("", Vector3.ONE, Color(1.0, 0.72, 0.35), 3.0)
	Build.box(n, Vector3(0, 1.3, 0), Vector3(0.46, 0.24, 0.24), glow)
	Build.box(n, Vector3(0, 1.3, 0), Vector3(0.24, 0.24, 0.46), glow)
	Build.cyl(n, Vector3(0, 1.62, 0), 0.06, 0.56, 0.32, stone, false, 6)
	Build.ball(n, Vector3(0, 1.82, 0), 0.09, Vector3.ONE, stone)


func _sacred_tree(n: Node3D) -> void:
	var parts: Array = Overworld._card_tree(0)
	var scale := Vector3.ONE * 2.1
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.scale = scale
		n.add_child(mi)
	Build.pillar_collider(n, Vector3.ZERO, 1.0, 6.0)
	# (the primitive rope ring and streamers came out looking wrong; the tree stands plain until a real shimenawa model)


func _hokora(n: Node3D) -> void:
	var stone := Build.mat("rock030", Vector3(2, 1, 1), Color(0.8, 0.78, 0.72))
	Build.box(n, Vector3(0, 0.35, 0), Vector3(2.0, 0.7, 1.6), stone, true)
	Build.box(n, Vector3(0, 1.25, 0), Vector3(1.3, 1.1, 1.0), Build.mat("woodsiding008", Vector3(1, 1, 1), Color(0.95, 0.85, 0.75)), true)
	Build.box(n, Vector3(0, 1.2, -0.51), Vector3(0.9, 0.85, 0.04), Build.mat("planks012", Vector3(1, 1, 1), Color(0.9, 0.25, 0.15)))
	var roof := Build.mat("roofingtiles006", Vector3(2, 1, 1))
	for sx in [-1, 1]:
		Build.box(n, Vector3(sx * 0.52, 2.08, 0), Vector3(1.25, 0.1, 1.5), roof, false, Vector3(0, 0, sx * -0.55))
	Build.box(n, Vector3(0, 2.38, 0), Vector3(0.16, 0.14, 1.55), Build.mat("planks012", Vector3.ONE, Color(0.25, 0.2, 0.18)))


func _machine_stone(n: Node3D) -> void:  # an old machine standing as a shrine stone
	var metal := Build.mat("rock030", Vector3(1, 2, 1), Color(0.42, 0.44, 0.46))
	Build.box(n, Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.9), metal, true)
	var bay := Build.mat("planks012", Vector3.ONE, Color(0.12, 0.12, 0.13))
	for k in 5:
		Build.box(n, Vector3(0, 0.35 + k * 0.32, -0.46), Vector3(0.66, 0.18, 0.03), bay)
	Build.box(n, Vector3(0.22, 1.85, -0.47), Vector3(0.08, 0.08, 0.02), Build.mat("", Vector3.ONE, Color(0.4, 1.0, 0.85), 5.0))
	var moss := Build.mat("grass004", Vector3(2, 2, 1), Color(0.55, 0.75, 0.45))
	Build.ball(n, Vector3(0.05, 2.02, 0), 0.5, Vector3(1.0, 0.28, 1.05), moss)
	Build.ball(n, Vector3(-0.3, 0.08, -0.2), 0.4, Vector3(1.0, 0.3, 1.0), moss)
	Build.torus(n, Vector3(0, 1.35, 0), 0.66, 0.06, Build.mat("", Vector3.ONE, Color(0.86, 0.74, 0.46)))


func _stepping_stone(n: Node3D) -> void:
	Build.cyl(n, Vector3(0, 0.05, 0), 0.5, 0.55, 0.12, Build.mat("rock030", Vector3(0.6, 0.6, 1), Color(0.85, 0.82, 0.76)), false, 10)


func _bamboo_fence(n: Node3D) -> void:
	var bamboo := Build.mat("planks012", Vector3(0.3, 2, 1), Color(0.9, 0.85, 0.5))
	for i in 11:
		Build.cyl(n, Vector3(-1.1 + i * 0.22, 0.7, 0), 0.06, 0.06, 1.4, bamboo, false, 8)
	for z in [0.45, 1.05]:
		Build.box(n, Vector3(0, z, -0.08), Vector3(2.5, 0.08, 0.08), bamboo)
	Build.box(n, Vector3(0, 0.7, 0), Vector3(2.5, 1.4, 0.2), bamboo, true).visible = false


## Kami wisps: soft glowing motes drifting up and wandering (additive, unshaded).
func _wisps(center: Vector3, radius: float, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = center
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, 0.05, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(0.6, 1.0, 0.9, 0.0))
	fade.add_point(0.25, Color(0.7, 1.0, 0.92, 0.9))
	fade.add_point(0.75, Color(1.0, 0.9, 0.6, 0.7))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.8, 0.5, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _dot()
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)


static func _dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t
