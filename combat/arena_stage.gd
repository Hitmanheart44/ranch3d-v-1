class_name ArenaStage
extends Node3D
## The arena's look and walls (no match logic): obsidian hex floor, a ring wall, monoliths with
## floating shards, spotlights cutting through fog, embers and ash. Ported from ChipMon's arena.
##   var stage := ArenaStage.new(); stage.accent = Types.glow("fire"); add_child(stage)

const RADIUS := 13.0

const FLOOR_SHADER := """
shader_type spatial;
uniform vec3 glow_col : source_color = vec3(1.0, 0.3, 0.2);
uniform float arena_r = 13.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hexdist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}

void fragment() {
	vec2 p = wpos.xz;
	float r = length(p);
	vec2 uv = p * 0.75;
	vec2 rr = vec2(1.0, 1.732);
	vec2 a = mod(uv, rr) - rr * 0.5;
	vec2 b = mod(uv - rr * 0.5, rr) - rr * 0.5;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 cell = uv - gv;
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float edge = smoothstep(0.45, 0.5, hexdist(gv));
	float inside = 1.0 - smoothstep(arena_r - 0.4, arena_r, r);

	float wave = pow(0.5 + 0.5 * sin(r * 0.7 - TIME * 1.6), 10.0);
	float lines = edge * (0.05 + 0.5 * wave) * inside;
	float ring1 = 1.0 - smoothstep(0.0, 0.05, abs(r - 4.5));
	float ring2 = 1.0 - smoothstep(0.0, 0.05, abs(r - 9.0));
	float outer = 1.0 - smoothstep(0.0, 0.12, abs(r - (arena_r - 0.25)));
	float ang = atan(p.y, p.x) / 6.28318;
	float band = step(arena_r - 1.15, r) * step(r, arena_r - 0.6);
	float ticks = step(0.8, fract(ang * 72.0)) * band;
	float lit = step(0.985, rnd) * (0.5 + 0.5 * sin(TIME * 1.5 + rnd * 40.0)) * inside;

	vec3 em = glow_col * (lines + ring1 * 0.5 + ring2 * 0.4 + outer * 3.0 + ticks * 1.2 + lit * 0.12);
	ALBEDO = vec3(0.018, 0.02, 0.026) * (0.7 + 0.6 * rnd);
	METALLIC = 0.5;
	ROUGHNESS = mix(0.18, 0.4, rnd);
	EMISSION = em * mix(0.15, 1.0, inside);
}
"""

@export var accent := Color(1.0, 0.3, 0.2)
var _shards: Array = []
var _t := 0.0


func _ready() -> void:  # v2: a daylight kami tournament ground (stone ring, torii, lanterns, banners, stands)
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/tex/sky.hdr")
	sky.sky_material = pano
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.8, 0.68)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 140, 0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	_floor()
	_wall()
	var stone := Build.mat("rock030", Vector3(6, 6, 1), Color(0.86, 0.83, 0.78))
	Build.cyl(self, Vector3(0, 0.08, 0), RADIUS, RADIUS + 0.3, 0.16, stone, false, 48)  # fighting ring
	var rim := Build.mat("rock030", Vector3(1, 1, 1), Color(0.7, 0.67, 0.62))
	for i in 40:  # raised stone rim
		var a := TAU * i / 40.0
		var blk := Build.box(self, Vector3(cos(a), 0, sin(a)) * (RADIUS + 0.6) + Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 0.7), rim)
		blk.rotation.y = -a + PI * 0.5
	var red := Build.mat("planks012", Vector3(1, 3, 1), Color(0.95, 0.28, 0.16))
	var black := Build.mat("planks012", Vector3(3, 1, 1), Color(0.18, 0.15, 0.14))
	for q in 4:  # a torii at each quarter, facing the ring
		var g := Node3D.new()
		g.position = Vector3(cos(q * PI / 2), 0, sin(q * PI / 2)) * (RADIUS + 4.0)
		g.rotation.y = -q * PI / 2 + PI / 2
		add_child(g)
		for x in [-1.9, 1.9]:
			Build.cyl(g, Vector3(x, 2.1, 0), 0.19, 0.23, 4.2, red)
		Build.box(g, Vector3(0, 3.15, 0), Vector3(4.6, 0.24, 0.26), red)
		Build.box(g, Vector3(0, 3.8, 0), Vector3(5.0, 0.22, 0.34), red)
		Build.box(g, Vector3(0, 4.05, 0), Vector3(5.6, 0.26, 0.44), black)
	var glow := Build.mat("", Vector3.ONE, Color(1.0, 0.72, 0.35), 3.0)
	var cloth := Build.mat("", Vector3.ONE, accent.lerp(Color.WHITE, 0.15))
	var white := Build.mat("", Vector3.ONE, Color(0.96, 0.94, 0.88))
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * (RADIUS + 2.2)
		Build.cyl(self, p + Vector3(0, 0.55, 0), 0.13, 0.16, 1.1, rim, false, 6)  # stone lantern
		Build.box(self, p + Vector3(0, 1.25, 0), Vector3(0.42, 0.36, 0.42), glow)
		Build.cyl(self, p + Vector3(0, 1.55, 0), 0.05, 0.5, 0.3, rim, false, 6)
		var bp := Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * (RADIUS + 3.4)  # banner pole + cloth
		Build.cyl(self, bp + Vector3(0, 2.5, 0), 0.05, 0.05, 5.0, black, false, 6)
		Build.box(self, bp + Vector3(0, 3.4, 0.0), Vector3(0.7, 2.6, 0.03), cloth if k % 2 == 0 else white, false, Vector3(0, -a, 0))
	var wood := Build.mat("planks012", Vector3(4, 1, 1))
	for side in [-1, 1]:  # spectator stands
		for row in 3:
			for seg in 7:
				var a: float = side * PI / 2 + (seg - 3) * 0.22
				var r := RADIUS + 8.0 + row * 1.6
				var st := Build.box(self, Vector3(cos(a) * r, 0.4 + row * 0.7, sin(a) * r), Vector3(3.4, 0.8 + row * 1.4, 1.5), wood)
				st.rotation.y = -a + PI * 0.5
				st.position.y = (0.8 + row * 1.4) / 2.0
	ArenaDress.build(self)


func _floor() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(160, 1, 160)
	cs.shape = bs
	cs.position.y = -0.5
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	mi.mesh = pm
	mi.material_override = Build.mat("grass004", Vector3(50, 50, 1), Color(0.7, 0.82, 0.55))
	mi.visible = false   # ArenaDress draws the ground (hills) instead; the box stays as the collision floor
	sb.add_child(mi)
	add_child(sb)


## Invisible ring of boxes at the arena edge (Godot has no hollow cylinder shape).
## Layer 4 "walls": blocks kami and bolts but not the camera's SpringArm.
func _wall() -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 8
	sb.collision_mask = 0
	var n := 32
	for i in n:
		var a := TAU * float(i) / float(n)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(TAU * RADIUS / float(n) + 0.3, 6.0, 1.0)
		cs.shape = bs
		cs.position = Vector3(cos(a), 0.0, sin(a)) * (RADIUS + 0.3) + Vector3(0, 3, 0)
		cs.rotation.y = -a + PI * 0.5
		sb.add_child(cs)
	add_child(sb)


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _particles(col: Color, n: int, size: float, dir: Vector3, vmin: float, vmax: float, emit: float) -> void:
	var p := CPUParticles3D.new()
	var mm := SphereMesh.new()
	mm.radius = size
	mm.height = size * 2.0
	mm.radial_segments = 4
	mm.rings = 2
	if emit > 0.0:
		mm.material = HitFx.glow_mat(col, emit)
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		mm.material = m
	p.mesh = mm
	p.amount = n
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(RADIUS + 4.0, 4.0, RADIUS + 4.0)
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0.25, 0, 0)
	add_child(p)
	p.position = Vector3(0, 4.0, 0)


func _process(delta: float) -> void:
	_t += delta
	for s in _shards:
		var n := s[0] as Node3D
		n.rotation.y = _t * 1.2
		n.position.y = float(s[1]) + 0.2 * sin(_t * 1.5 + n.position.x)
