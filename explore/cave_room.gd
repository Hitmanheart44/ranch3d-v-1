class_name CaveRoom
extends Node3D
## One cave chamber of an adventure floor: a big irregular room (one merged rock-wall mesh, the mossy cave floor)
## with tunnels out on the sides that lead to neighbouring rooms. Built from a seed, so the dungeon and the arena
## (fights happen in the room you were in) build the exact same place. Cheap: a few meshes, box collision, 2 lights.
##   CaveRoom.make({"theme": "hollow", "seed": 123, "exits": [0, 2]})   exits: 0 east, 1 south, 2 west, 3 north

const R := 17.0          # room radius (34 m across: room for a fight and the camera)
const H := 9.0           # wall height
const TUNNEL := 11.0     # tunnel length beyond the wall
const GAP := 3.4         # half-width of a tunnel mouth
const DIRS := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
const THEMES := {  # glow (crystals, torch tint), rock tint, fog
	"hollow": [Color(1.0, 0.55, 0.2), Color(0.34, 0.28, 0.23), Color(0.12, 0.07, 0.04)],
	"thornwild": [Color(0.5, 1.0, 0.35), Color(0.26, 0.3, 0.2), Color(0.05, 0.09, 0.04)],
	"spires": [Color(0.35, 0.75, 1.0), Color(0.24, 0.28, 0.32), Color(0.03, 0.06, 0.1)],
	"cinder": [Color(1.0, 0.3, 0.15), Color(0.3, 0.22, 0.2), Color(0.12, 0.04, 0.03)],
}

var theme := "hollow"
var room_seed := 0
var exits: Array = []
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()


static func make(p: Dictionary) -> CaveRoom:
	var c := CaveRoom.new()
	c.theme = str(p.get("theme", "hollow")).trim_suffix("_plus")
	if not THEMES.has(c.theme):
		c.theme = "hollow"
	c.room_seed = int(p.get("seed", 0))
	c.exits = p.get("exits", [])
	return c


func _ready() -> void:
	rng.seed = room_seed
	noise.seed = room_seed
	noise.frequency = 0.18
	var th: Array = THEMES[theme]
	_environment(th)
	_floor()
	_walls(th[1])
	for e in exits:
		_tunnel(int(e), th[1])
	_props(th)
	CaveDress.build(self, th[0])


## Radius of the wall at angle a (lumpy, never pinching the middle).
func wall_r(a: float) -> float:
	return R + noise.get_noise_2d(cos(a) * 8.0, sin(a) * 8.0) * 2.2


func _gap(a: float) -> bool:
	for e in exits:
		var d := absf(wrapf(a - int(e) * PI / 2.0, -PI, PI))
		if d < asin(GAP / R) + 0.02:
			return true
	return false


func _environment(th: Array) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = (th[0] as Color).lerp(Color(0.6, 0.6, 0.6), 0.6)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = th[2]
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()  # soft light from cracks above, so the room reads
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-70, 30, 0)
	key.light_color = Color(0.75, 0.8, 0.9)
	key.light_energy = 0.35
	add_child(key)


func _floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segs := 64
	for ri in rings:
		for si in segs:
			var pts: Array[Vector3] = []
			for c in [[0, 0], [1, 1], [1, 0], [0, 0], [0, 1], [1, 1]]:   # front face up
				var a: float = (si + c[0]) * TAU / segs
				var t := float(ri + c[1]) / rings
				var r := wall_r(a) * t + 0.8 * t
				var y := pow(t, 6.0) * 0.6  # the floor curls up into the wall
				pts.append(Vector3(cos(a) * r, y, sin(a) * r))
			for p in pts:
				st.set_uv(Vector2(p.x, p.z) * 0.1)
				st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _floor_mat()
	add_child(mi)
	var sb := StaticBody3D.new()  # flat collision floor under everything
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	cs.position.y = -0.5
	sb.add_child(cs)
	add_child(sb)


## The chamber wall: one displaced mesh around the outline (holes at the tunnel mouths), boxes for collision.
func _walls(tint: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 96
	var rows := 6
	for si in segs:
		var a0 := si * TAU / segs
		var a1 := (si + 1) * TAU / segs
		if _gap((a0 + a1) / 2.0):
			continue
		for yi in rows:
			var q: Array[Vector3] = []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var a := a0 if c[0] == 0 else a1
				var y := float(yi + c[1]) / rows * H
				var lean := pow(y / H, 2.0) * 3.0  # leans in overhead like a cave
				var bump := noise.get_noise_3d(cos(a) * 10.0, y * 0.8, sin(a) * 10.0) * 1.6
				var r := wall_r(a) + 0.6 - lean + bump
				q.append(Vector3(cos(a) * r, y, sin(a) * r))
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2((a0 if k in [0, 3] else a1) * 8.0, q[k].y * 0.25))
				st.add_vertex(q[k])
		var mid := (a0 + a1) / 2.0  # collision
		_block(Vector3(cos(mid), 0, sin(mid)) * (wall_r(mid) + 0.9), Vector3(1.4, H, wall_r(mid) * TAU / segs + 0.6), -mid)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _shader(CAVE_ROCK)
	m.set_shader_parameter("tint", tint)
	mi.material_override = m
	add_child(mi)


func _tunnel(e: int, tint: Color) -> void:
	var d: Vector3 = DIRS[e]
	var side := Vector3(-d.z, 0, d.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	for s in [-1.0, 1.0]:
		for i in n:
			for yi in 4:
				var q: Array[Vector3] = []
				for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
					var along := R - 1.5 + float(i + c[0]) / n * TUNNEL
					var y := float(yi + c[1]) / 4.0 * H * 0.8
					var w := GAP + 0.4 - pow(y / H, 2.0) * 2.0 + noise.get_noise_2d(along * 1.5, y + s * 20.0) * 0.8
					q.append(d * along + side * s * w + Vector3(0, y, 0))
				for k in ([0, 1, 2, 0, 2, 3] if s > 0 else [0, 2, 1, 0, 3, 2]):
					st.set_uv(Vector2(q[k].dot(d) * 0.25, q[k].y * 0.25))
					st.add_vertex(q[k])
		_block(d * (R + TUNNEL / 2.0) + side * s * (GAP + 1.2), Vector3(TUNNEL + 2.0, H, 1.4) if e % 2 == 0 else Vector3(1.4, H, TUNNEL + 2.0), 0.0)
	# floor strip and a curtain of darkness at the far end
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TUNNEL + 2.0, GAP * 2.4) if e % 2 == 0 else Vector2(GAP * 2.4, TUNNEL + 2.0)
	fl.mesh = pm
	fl.position = d * (R + TUNNEL / 2.0) + Vector3(0, 0.02, 0)
	fl.material_override = _floor_mat()
	add_child(fl)
	var dark := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(GAP * 3.0, H)
	dark.mesh = qm
	dark.position = d * (R + TUNNEL - 1.0) + Vector3(0, H / 2.0, 0)
	dark.rotation.y = atan2(d.x, d.z)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0, 0, 0)
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.material_override = dm
	add_child(dark)
	_block(d * (R + TUNNEL + 4.0), Vector3(GAP * 3, H, GAP * 3), 0.0)  # the far end (the room change happens before it)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _shader(CAVE_ROCK)
	m.set_shader_parameter("tint", tint)
	mi.material_override = m
	add_child(mi)


func _block(pos: Vector3, size: Vector3, yaw: float) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos + Vector3(0, size.y / 2.0, 0)
	sb.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	sb.add_child(cs)
	add_child(sb)


## Stalagmites along the walls, glowing crystals, two torches, drifting motes. The middle stays clear for fights.
func _props(th: Array) -> void:
	var rock := _shader(CAVE_ROCK)
	rock.set_shader_parameter("tint", th[1])
	var glow := StandardMaterial3D.new()
	glow.albedo_color = th[0]
	glow.emission_enabled = true
	glow.emission = th[0]
	glow.emission_energy_multiplier = 2.5
	for i in 22:
		var a := rng.randf() * TAU
		if _gap(a):
			continue
		var r := wall_r(a) - rng.randf_range(1.0, 3.5)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = rng.randf_range(0.5, 1.2)
		cm.height = rng.randf_range(1.5, 4.5)
		cm.radial_segments = 7
		cm.rings = 2
		mi.mesh = cm
		mi.position = p + Vector3(0, cm.height / 2.0 - 0.1, 0)
		mi.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		mi.material_override = rock
		add_child(mi)
		if i % 3 == 0:  # crystal clusters
			for k in 3:
				var c := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(0.35, rng.randf_range(0.8, 1.8), 0.35)
				c.mesh = pm
				c.position = p + Vector3(rng.randf_range(-0.8, 0.8), pm.size.y / 2.0, rng.randf_range(-0.8, 0.8))
				c.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
				c.material_override = glow
				add_child(c)
	for k in 2:  # torches on the wall
		var a := k * PI + 0.7 + rng.randf_range(-0.3, 0.3)
		var l := OmniLight3D.new()
		l.light_color = (th[0] as Color).lerp(Color(1.0, 0.7, 0.4), 0.5)
		l.light_energy = 2.6
		l.omni_range = 26.0
		l.position = Vector3(cos(a), 0, sin(a)) * (wall_r(a) - 2.5) + Vector3(0, 4.0, 0)
		add_child(l)
		var fire := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.6
		fire.mesh = sm
		fire.position = l.position
		fire.material_override = glow
		add_child(fire)
	var motes := GPUParticles3D.new()
	motes.amount = 60
	motes.lifetime = 8.0
	motes.visibility_aabb = AABB(Vector3(-R, 0, -R), Vector3(R * 2, H, R * 2))
	var pm2 := ParticleProcessMaterial.new()
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm2.emission_box_extents = Vector3(R * 0.8, 3.0, R * 0.8)
	pm2.gravity = Vector3(0, 0.05, 0)
	pm2.initial_velocity_min = 0.05
	pm2.initial_velocity_max = 0.2
	pm2.spread = 180.0
	motes.process_material = pm2
	motes.position.y = 3.0
	var dot := QuadMesh.new()
	dot.size = Vector2(0.08, 0.08)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = (th[0] as Color).lerp(Color.WHITE, 0.4)
	dot.material = dm
	motes.draw_pass_1 = dot
	add_child(motes)


func _floor_mat() -> ShaderMaterial:  # scanned rock + earth textures (CC0), lit by the room
	var m := _shader(CAVE_FLOOR)
	m.set_shader_parameter("rock", load("res://assets/tex/rock030_color.jpg"))
	m.set_shader_parameter("dirt", load("res://assets/tex/ground037_color.jpg"))
	m.set_shader_parameter("tint", THEMES[theme][1])
	return m


func _shader(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	return m


const CAVE_FLOOR := """
shader_type spatial;
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(0.34, 0.28, 0.23);
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float v = n(wp.xz * 0.6) * 0.6 + n(wp.xz * 2.3) * 0.4;
	float mixk = smoothstep(0.35, 0.65, n(wp.xz * 0.15 + 3.0));
	vec3 r = texture(rock, wp.xz / 3.5).rgb;
	vec3 d = texture(dirt, wp.xz / 2.8).rgb;
	vec3 c = mix(d, r, mixk) * mix(0.85, 1.15, v) * (tint / 0.3);
	float moss = smoothstep(0.62, 0.85, n(wp.xz * 0.25 + 9.0));
	ALBEDO = mix(c, vec3(0.22, 0.32, 0.12), moss * 0.6);
	ROUGHNESS = 0.92;
}
"""

const CAVE_ROCK := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint = vec3(0.3, 0.26, 0.22);
varying vec3 wp;
float h(vec3 p) { p = fract(p * 0.3183 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float n(vec3 x) { vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float v = n(wp * 1.7) * 0.6 + n(wp * 5.0) * 0.4;
	float strata = 0.5 + 0.5 * sin(wp.y * 3.0 + n(wp * 0.7) * 4.0);
	float moss = smoothstep(0.6, 0.85, n(wp * 0.5 + 3.0)) * smoothstep(0.3, 1.0, NORMAL.y + 0.6);
	vec3 c = tint * mix(0.8, 1.45, v) * mix(0.85, 1.05, strata);
	ALBEDO = mix(c, vec3(0.2, 0.3, 0.12), moss * 0.7);
	ROUGHNESS = 0.95;
}
"""
