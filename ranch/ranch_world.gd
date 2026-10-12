class_name RanchWorld
extends Node3D
## The ranch's look (no game logic): a golden-hour plateau with a sunset sky, distant mountains, rolling hills,
## wind-swept grass, a fenced paddock, a barn with lit windows, trees, rocks, a pond, training props and fireflies.
## The paddock is a circle of PADDOCK_R around the origin, flat and walkable.
##
## ASSET SLOTS: every prop is placed through _slot(name, ...). If res://assets/props/<name>.glb (or .tscn) exists,
## that model is used; otherwise the placeholder built from primitives here is used. Real art = drop in files,
## no code changes. Slot list, sizes and conventions: ART_SLOTS.md.

const PADDOCK_R := 15.0
const BARN_POS := Vector3(-11.0, 0.0, -10.0)
const POND_POS := Vector3(10.0, 0.0, -8.0)

const GROUND_SHADER := """
shader_type spatial;
uniform float flat_r = 17.0;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float hills(vec2 p) {
	float h = noise(p * 0.02) * 9.0 + noise(p * 0.06) * 3.0;
	return h * smoothstep(flat_r, flat_r + 25.0, length(p));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += hills(w.xz);
	wpos = w;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 0.35) * 0.6 + noise(p * 1.7) * 0.4;
	vec3 grass = mix(vec3(0.2, 0.36, 0.1), vec3(0.42, 0.5, 0.16), n);
	// worn dirt track around the inside of the fence and a path to the barn
	float r = length(p);
	float ring = 1.0 - smoothstep(0.0, 1.6, abs(r - 12.5));
	vec2 bp = p - vec2(-11.0, -10.0);
	float path = (1.0 - smoothstep(0.6, 1.8, abs(dot(normalize(vec2(-11.0, -10.0)), vec2(-p.y, p.x)) / 1.0))) * step(r, 15.5);
	vec3 dirt = mix(vec3(0.28, 0.2, 0.12), vec3(0.36, 0.27, 0.16), n);
	ALBEDO = mix(grass, dirt, clamp(ring * 0.75 + path * 0.8, 0.0, 1.0) * (0.7 + 0.3 * n));
	ROUGHNESS = 0.95;
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_col : source_color = vec3(0.2, 0.36, 0.1);
uniform vec3 tip_col : source_color = vec3(0.62, 0.68, 0.24);
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.6 + w.x * 0.35 + w.z * 0.22) * 0.5 + sin(TIME * 3.1 + w.x * 1.3) * 0.15;
	VERTEX.x += sway * VERTEX.y * 0.35;
	VERTEX.z += sway * VERTEX.y * 0.15;
}
void fragment() {
	ALBEDO = mix(base_col, tip_col, UV.y);
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
void fragment() {
	vec2 uv = UV * 6.0;
	float w = sin(uv.x * 3.0 + TIME * 1.2) * sin(uv.y * 2.7 - TIME) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.02, 0.06, 0.08), vec3(0.05, 0.12, 0.14), w);
	METALLIC = 0.2;
	ROUGHNESS = 0.05 + 0.08 * w;
	NORMAL_MAP = vec3(0.5 + 0.06 * cos(uv.x * 3.0 + TIME * 1.2), 0.5 + 0.06 * cos(uv.y * 2.7 - TIME), 1.0);
}
"""

## false = open field (expeditions): no fence wall, no barn/props.
var paddock := true
var fence := true  # v2 shrine-ranch has no paddock fence ring
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}


func _ready() -> void:
	_rng.seed = 42
	_sky()
	_ground()
	_grass()
	if paddock and fence:
		_fence()
	if paddock:
		_barn()
		_pond()
		_props()
	_trees()
	_mountains()
	_fireflies()


# ---------------------------------------------------------------- helpers

## Places the real model for `slot` if one exists (res://assets/props/<slot>.glb or .tscn). Returns false if not,
## so the caller builds its placeholder instead. Models: meters, Y up, origin at the base center, front = +Z.
func _slot(slot: String, pos: Vector3, yaw_deg: float = 0.0, scale_f: float = 1.0) -> bool:
	for ext in [".tscn", ".glb"]:
		var path: String = "res://assets/props/" + slot + ext
		if ResourceLoader.exists(path):
			var n := (load(path) as PackedScene).instantiate() as Node3D
			n.position = pos
			n.rotation_degrees.y = yaw_deg
			n.scale = Vector3.ONE * scale_f
			add_child(n)
			Props.fix(n)
			_water_swap(n)
			return true
	return false


## Prop surfaces whose material is named "water" get the animated water shader instead of a flat color.
func _water_swap(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m != null and m.resource_name.begins_with("water"):
				if not _mats.has("water"):
					var sm := ShaderMaterial.new()
					sm.shader = Shader.new()
					sm.shader.code = WATER
					_mats["water"] = sm
				(mi as MeshInstance3D).set_surface_override_material(i, _mats["water"])


const WATER := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float waves(vec2 p, float t) { return n(p * 1.3 + vec2(t * 0.25, t * 0.18)) * 0.6 + n(p * 3.1 - vec2(t * 0.35, -t * 0.22)) * 0.4; }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float t = TIME;
	float e = 0.05;
	float w0 = waves(wp.xz, t);
	vec3 nrm = normalize(vec3(w0 - waves(wp.xz + vec2(e, 0.0), t), 0.35, w0 - waves(wp.xz + vec2(0.0, e), t)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 deep = vec3(0.04, 0.18, 0.24), shallow = vec3(0.16, 0.45, 0.48), sky = vec3(0.75, 0.82, 0.9);
	vec3 c = mix(deep, shallow, smoothstep(0.3, 0.8, w0));
	c = mix(c, sky, fres * 0.7);
	float sparkle = smoothstep(0.86, 0.95, waves(wp.xz * 2.3, t * 1.7));
	ALBEDO = c;
	EMISSION = vec3(1.0, 0.92, 0.75) * sparkle * 0.6;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.8;
}
"""


func _mat(key: String, col: Color, rough: float = 0.85, emit: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	(parent if parent != null else self).add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


func _sph(r: float, seg: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return s


func _solid(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)


# ---------------------------------------------------------------- pieces

func _sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.98, 0.62, 0.36)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.6, 0.42, 0.3)
	sky_mat.ground_bottom_color = Color(0.1, 0.08, 0.08)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.98, 0.82, 0.62)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, 140, 0)
	sun.light_color = Color(1.0, 0.8, 0.58)
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(520, 520)
	pm.subdivide_width = 160
	pm.subdivide_depth = 160
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = GROUND_SHADER
	_mesh(pm, Vector3.ZERO, sm)
	_solid(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	if not paddock:
		return
	# invisible wall at the fence, so the kami stays in the paddock
	var sb := StaticBody3D.new()
	sb.collision_layer = 8
	for i in 28:
		var a := TAU * float(i) / 28.0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(TAU * PADDOCK_R / 28.0 + 0.3, 3.0, 0.6)
		cs.shape = bs
		cs.position = Vector3(cos(a), 0, sin(a)) * (PADDOCK_R + 0.3) + Vector3(0, 1.5, 0)
		cs.rotation.y = -a + PI * 0.5
		sb.add_child(cs)
	add_child(sb)


func _grass() -> void:
	var blade := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.035, 0, 0), Vector3(0.035, 0, 0), Vector3(0, 0.32, 0)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	var n := 16000
	mm.instance_count = n
	for i in n:
		var r := sqrt(_rng.randf()) * 34.0
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(r - 12.5) < 1.4 or p.distance_to(BARN_POS) < 6.0 or p.distance_to(POND_POS) < 4.2:
			p = Vector3(cos(a) * 30.0, 0, sin(a) * 30.0)  # keep the track and buildings clear
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.4))
		mm.set_instance_transform(i, Transform3D(b, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = GRASS_SHADER
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _fence() -> void:
	var wood := _mat("fence", Color(0.36, 0.24, 0.14), 0.9)
	var n := 40
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector3(cos(a), 0, sin(a)) * (PADDOCK_R + 0.3)
		var seg_mid := (p + Vector3(cos(TAU * float(i + 1) / float(n)), 0, sin(TAU * float(i + 1) / float(n))) * (PADDOCK_R + 0.3)) * 0.5
		if _slot("fence_segment", seg_mid, -rad_to_deg(a + PI / float(n)) + 90.0):
			continue
		_mesh(_box(Vector3(0.22, 1.3, 0.22)), p + Vector3(0, 0.65, 0), wood, Vector3(0, -rad_to_deg(a), _rng.randf_range(-3, 3)))
		var a2 := TAU * float(i + 1) / float(n)
		var p2 := Vector3(cos(a2), 0, sin(a2)) * (PADDOCK_R + 0.3)
		var mid := (p + p2) * 0.5
		var length := p.distance_to(p2)
		for y in [0.55, 1.05]:
			_mesh(_box(Vector3(length, 0.1, 0.08)), mid + Vector3(0, y, 0), wood, Vector3(0, -rad_to_deg((a + a2) * 0.5) + 90.0, 0))


func _barn() -> void:
	_solid(BARN_POS + Vector3(0, 2, 0), Vector3(8, 4, 8))
	if _slot("barn", BARN_POS, 40.0):
		return
	var b := Node3D.new()
	b.position = BARN_POS
	b.rotation_degrees.y = 40.0
	add_child(b)
	var wall := _mat("barn", Color(0.42, 0.14, 0.1), 0.85)
	var trim := _mat("trim", Color(0.82, 0.76, 0.66), 0.8)
	var roof := _mat("roof", Color(0.16, 0.12, 0.12), 0.7)
	var lit := _mat("window", Color(1.0, 0.7, 0.35), 0.5, 3.5)
	_mesh(_box(Vector3(7, 4, 6)), Vector3(0, 2, 0), wall, Vector3.ZERO, Vector3.ONE, b)
	var pr := PrismMesh.new()
	pr.size = Vector3(7.6, 2.6, 6.6)
	_mesh(pr, Vector3(0, 5.3, 0), roof, Vector3(0, 90, 0), Vector3.ONE, b)
	_mesh(_box(Vector3(2.4, 3.0, 0.1)), Vector3(0, 1.5, 3.02), _mat("door", Color(0.2, 0.08, 0.05)), Vector3.ZERO, Vector3.ONE, b)
	for x in [-1.2, 1.2]:
		_mesh(_box(Vector3(0.12, 3.0, 0.12)), Vector3(x, 1.5, 3.06), trim, Vector3.ZERO, Vector3.ONE, b)
	_mesh(_box(Vector3(2.5, 0.12, 0.12)), Vector3(0, 3.0, 3.06), trim, Vector3.ZERO, Vector3.ONE, b)
	for x in [-2.5, 2.5]:
		_mesh(_box(Vector3(1.0, 0.9, 0.08)), Vector3(x, 2.4, 3.02), lit, Vector3.ZERO, Vector3.ONE, b)
		_mesh(_box(Vector3(0.6, 0.6, 0.08)), Vector3(x * 1.0, 2.4, -3.02), lit, Vector3.ZERO, Vector3.ONE, b)
	_mesh(_box(Vector3(1.2, 1.2, 0.08)), Vector3(0, 5.0, 3.32), lit, Vector3.ZERO, Vector3.ONE, b)
	for x in [-1.6, 1.6]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 3.2, 3.6)
		lamp.light_color = Color(1.0, 0.65, 0.3)
		lamp.light_energy = 2.5
		lamp.omni_range = 7.0
		b.add_child(lamp)
		_mesh(_sph(0.15, 8), Vector3(x, 3.2, 3.5), _mat("lamp", Color(1.0, 0.75, 0.4), 0.5, 6.0), Vector3.ZERO, Vector3.ONE, b)
	# hay bales by the door
	var hay := _mat("hay", Color(0.75, 0.6, 0.25), 0.95)
	for i in 3:
		_mesh(_cyl(0.6, 0.6, 1.1, 14), Vector3(3.6 + i * 0.4, 0.6 + (0.9 if i == 2 else 0.0), 2.5 - i * 1.0 + (0.5 if i == 2 else 0.0)), hay, Vector3(0, 0, 90), Vector3.ONE, b)


func _pond() -> void:
	_solid(POND_POS, Vector3(7, 1, 7))
	if _slot("pond", POND_POS):
		return
	var w := ShaderMaterial.new()
	w.shader = Shader.new()
	w.shader.code = WATER_SHADER
	_mesh(_cyl(3.6, 3.6, 0.05, 32), POND_POS + Vector3(0, 0.02, 0), w)
	var rock := _mat("rock", Color(0.32, 0.3, 0.3), 0.9)
	for i in 14:
		var a := TAU * float(i) / 14.0 + _rng.randf() * 0.3
		var s := _rng.randf_range(0.35, 0.8)
		_mesh(_sph(0.5, 6), POND_POS + Vector3(cos(a), 0, sin(a)) * 3.8 + Vector3(0, 0.1, 0), rock,
			Vector3(_rng.randf() * 40, _rng.randf() * 360, 0), Vector3(s * 1.4, s * 0.7, s))


func _props() -> void:
	var wood := _mat("prop", Color(0.42, 0.29, 0.17), 0.9)
	# sparring post with crossbar and a straw head
	var post := Vector3(5.0, 0, 6.0)
	var tgt := Vector3(-6.0, 0, 7.0)
	_solid(post + Vector3(0, 1.1, 0), Vector3(0.6, 2.2, 0.6))
	_solid(tgt + Vector3(0, 0.8, 0), Vector3(1.6, 1.6, 0.4))
	var real_post := _slot("sparring_post", post)
	var real_tgt := _slot("target", tgt)
	var real_logs := _slot("log_pile", Vector3(-1.9, 0, -12.0), 90.0)
	var real_trough := _slot("trough", Vector3(4.5, 0, -12.5), -20.0)
	if real_post and real_tgt and real_logs and real_trough:
		return
	_mesh(_cyl(0.18, 0.22, 2.2), post + Vector3(0, 1.1, 0), wood)
	_mesh(_box(Vector3(1.6, 0.16, 0.16)), post + Vector3(0, 1.6, 0), wood)
	_mesh(_sph(0.32, 10), post + Vector3(0, 2.35, 0), _mat("hay", Color(0.75, 0.6, 0.25)))
	# target board
	_mesh(_box(Vector3(0.15, 1.2, 0.15)), tgt + Vector3(0, 0.6, 0), wood)
	var rings := [[0.75, Color(0.85, 0.8, 0.7)], [0.55, Color(0.7, 0.1, 0.08)], [0.35, Color(0.85, 0.8, 0.7)], [0.15, Color(0.7, 0.1, 0.08)]]
	for k in rings.size():
		_mesh(_cyl(rings[k][0], rings[k][0], 0.06, 24), tgt + Vector3(0, 1.5, 0.05 + 0.012 * k), _mat("ring%d" % k, rings[k][1]), Vector3(90, 0, 0))
	# log pile
	for i in 5:
		_mesh(_cyl(0.28, 0.28, 2.0, 10), Vector3(-2.5 + (i % 3) * 0.6 + (0.3 if i >= 3 else 0.0), 0.28 + (0.5 if i >= 3 else 0.0), -12.0), wood, Vector3(90, 90, 0))
	# water trough
	_mesh(_box(Vector3(2.2, 0.6, 0.8)), Vector3(4.5, 0.3, -12.5), wood, Vector3(0, -20, 0))
	_mesh(_box(Vector3(2.0, 0.05, 0.6)), Vector3(4.5, 0.56, -12.5), _mat("trough_water", Color(0.05, 0.12, 0.14), 0.05), Vector3(0, -20, 0))


func _trees() -> void:
	var bark := _mat("bark", Color(0.24, 0.16, 0.1))
	for i in 46:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(19.0, 48.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := _rng.randf_range(4.0, 8.0)
		var kind := "tree_pine" if i % 3 == 0 else "tree_round"
		if _slot(kind, p, _rng.randf() * 360.0, h / 6.0):
			continue
		_mesh(_cyl(0.18, 0.32, h * 0.5, 7), p + Vector3(0, h * 0.25, 0), bark)
		var leaf := _mat("leaf%d" % (i % 4), Color.from_hsv(_rng.randf_range(0.2, 0.3), 0.6, _rng.randf_range(0.22, 0.35)))
		if i % 3 == 0:  # pine
			for k in 3:
				_mesh(_cyl(0.0, h * (0.32 - 0.07 * k), h * 0.45, 8), p + Vector3(0, h * (0.45 + 0.2 * k), 0), leaf)
		else:  # round crown
			for k in 3:
				var off := Vector3(_rng.randf_range(-0.6, 0.6), h * 0.6 + k * 0.5, _rng.randf_range(-0.6, 0.6))
				_mesh(_sph(h * 0.22, 10), p + off, leaf, Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
	var rock := _mat("rock", Color(0.32, 0.3, 0.3), 0.9)
	for i in 18:
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(17.0, 30.0)
		var s := _rng.randf_range(0.5, 1.6)
		if _slot("rock", p, _rng.randf() * 360.0, s):
			continue
		_mesh(_sph(0.6, 6), p, rock, Vector3(_rng.randf() * 30, _rng.randf() * 360, 0), Vector3(s * 1.3, s * 0.8, s))


func _mountains() -> void:
	for i in 22:
		var a := TAU * float(i) / 22.0 + _rng.randf() * 0.2
		var d := _rng.randf_range(185.0, 240.0)
		var h := _rng.randf_range(30.0, 58.0)
		if _slot("mountain", Vector3(cos(a) * d, -4.0, sin(a) * d), _rng.randf() * 360.0, h / 45.0):
			continue
		var mat := _mat("mtn%d" % (i % 3), Color(0.36, 0.38, 0.55).lerp(Color(0.46, 0.42, 0.58), float(i % 3) / 3.0), 1.0)
		_mesh(_cyl(0.0, h * 0.9, h, 7), Vector3(cos(a) * d, h * 0.5 - 4.0, sin(a) * d), mat, Vector3(0, _rng.randf() * 60, 0))
		_mesh(_cyl(0.0, h * 0.22, h * 0.24, 7), Vector3(cos(a) * d, h - 4.0 - h * 0.12, sin(a) * d), _mat("snow", Color(0.85, 0.8, 0.85), 0.8))


func _fireflies() -> void:
	var p := CPUParticles3D.new()
	var sm := _sph(0.035, 6)
	sm.material = _mat("firefly", Color(1.0, 0.85, 0.35), 0.5, 6.0)
	p.mesh = sm
	p.amount = 70
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 1.2, 22)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	p.position = Vector3(0, 1.4, 0)
	add_child(p)
