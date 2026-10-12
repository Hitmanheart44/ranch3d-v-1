class_name MonsterModel
extends RefCounted
## MonsterModel: builds the 3D model for any species. The ONE source of kami art.
##
## Used by arena3d.gd (fighters) and monster_view.gd (every portrait in the ranch,
## stable, dex, hall and the summon screen), so a species looks the same everywhere.
##
##   var model := MonsterModel.create(monster_dict)        # Node3D, faces +Z, feet at y=0
##   MonsterModel.animate(model, time, speed_mul)           # call every frame
##   MonsterModel.set_flash(model, 0.0..1.0)                # white hit flash
##   MonsterModel.bounds(model)                             # AABB, for cameras and collision
##
## Look: dark armored bodies (hue from the kami) with a type-colored fresnel rim,
## glowing cracks on some species, white-hot slit eyes, bone fangs/claws. Two shaders
## below do the heavy lifting; parts are primitive meshes, so still no asset files.
##
## Material keys for _p(): body, veins (body + glowing cracks), plate (dark armor),
## bone, glow (type-colored light), eye.
## Anim kinds for _anim(): flicker, wag/flap (rot z), yaw (rot y), tilt (rot x),
## float (bob y), orbit, spin, blink.

const BODY_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 base_col : source_color = vec3(0.1);
uniform vec3 glow_col : source_color = vec3(1.0, 0.4, 0.2);
uniform float rim_energy = 1.6;
uniform float rim_power = 4.0;
uniform float metal = 0.3;
uniform float rough = 0.5;
uniform float veins = 0.0;
uniform float flash = 0.0;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_tex = false;
uniform bool use_vcol = false;
// Procedural animation for sculpted humanoid models (AI sculpts have no skeleton). Object space: height H,
// feet at y=0, front = +Z. Driven every frame by MonsterModel.drive().
uniform bool anim = false;
uniform float H = 2.4;
uniform float walk_phase = 0.0;
uniform float walk_amt = 0.0;
uniform float flap = 0.0;
uniform float breath = 0.0;
uniform vec3 inertia = vec3(0.0);
uniform int profile = 0;        // 0 biped, 1 quad, 2 float
uniform bool wings = false;
uniform bool hair_sway = false;
uniform bool chest_bounce = false;
varying vec3 opos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec2 rot2(vec2 v, float a) { return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a)); }

void vertex() {
	// object space, but scaled, so crack density is the same on every part
	opos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	if (anim) {
		vec3 p = VERTEX;
		float hip = 0.5 * H, knee = 0.27 * H, shoulder = 0.78 * H, neck = 0.85 * H;
		float side = p.x >= 0.0 ? 1.0 : -1.0;
		float limb = 1.0 - smoothstep(0.17 * H, 0.22 * H, abs(p.x));  // legs/body, not the wings
		// legs: swing from the hip. The side blends smoothly across the middle so legs that touch or cross
		// don't tear apart (sculpts have no skeleton to say which leg a vertex belongs to).
		if (profile == 2) {  // floats: hover bob, no legs
			p.y += sin(TIME * 2.0) * 0.03 * H + walk_amt * 0.02 * H;
		} else if (profile == 1) {  // four legs: diagonal pairs swing (front-left with back-right)
			float hipq = 0.38 * H;
			if (p.y < hipq) {
				float w = smoothstep(hipq, hipq * 0.4, p.y);
				float pair = clamp(p.x / (0.06 * H), -1.0, 1.0) * clamp(p.z / (0.08 * H), -1.0, 1.0);
				p.z += sin(walk_phase) * walk_amt * pair * 0.12 * H * w;
				p.y += max(0.0, sin(walk_phase) * pair) * walk_amt * 0.03 * H * w;
			}
		} else if (p.y < hip) {
			float w = smoothstep(hip - 0.02 * H, hip - 0.14 * H, p.y) * limb;
			float sidek = clamp(p.x / (0.05 * H), -1.0, 1.0);
			float swing = sin(walk_phase) * walk_amt * sidek;
			vec2 yz = rot2(vec2(p.y - hip, p.z), -swing * 0.38 * w);
			p.y = hip + yz.x;
			p.z = yz.y;
			p.y += max(0.0, sin(walk_phase) * sidek) * walk_amt * 0.03 * H * smoothstep(0.2 * H, 0.0, p.y);  // lift the stepping foot
		}
		// wings: flap around the shoulder line, trail behind movement
		float wing = wings ? smoothstep(0.17 * H, 0.32 * H, abs(p.x)) * step(hip - 0.12 * H, p.y) : 0.0;
		if (wing > 0.0) {
			vec2 xy = rot2(vec2(p.x - side * 0.1 * H, p.y - shoulder), side * flap * wing);
			p.x = side * 0.1 * H + xy.x;
			p.y = shoulder + xy.y;
			p -= inertia * 0.6 * wing;
		}
		// hair: magenta, above the hips, behind or beside the face -> sways and trails
		vec3 c = use_tex ? textureLod(tex, UV, 0.0).rgb : COLOR.rgb;  // hair found by color (texture or vertex paint)
		float hair = clamp((c.r + c.b) * 0.5 - c.g * 1.3 - 0.12, 0.0, 1.0) * 3.0;
		hair *= step(hip, p.y) * (1.0 - step(0.04 * H, p.z) * (1.0 - step(neck, p.y)));
		hair = hair_sway ? clamp(hair, 0.0, 1.0) * clamp((neck + 0.08 * H - p.y) / (0.35 * H), 0.0, 1.0) : 0.0;
		p.x += sin(TIME * 1.3 + p.y * 3.0) * 0.012 * H * hair;
		p -= inertia * 1.2 * hair;
		// chest: soft bounce with steps and inertia
		float chest = (chest_bounce ? 1.0 : 0.0) * smoothstep(0.05 * H, 0.09 * H, p.z) * smoothstep(0.62 * H, 0.68 * H, p.y) * (1.0 - smoothstep(0.74 * H, 0.78 * H, p.y)) * (1.0 - smoothstep(0.1 * H, 0.14 * H, abs(p.x)));
		p.y += (sin(walk_phase * 2.0) * walk_amt * 0.008 * H - inertia.y * 0.5) * chest;
		p.z -= inertia.z * 0.3 * chest;
		// breathing
		float torso = smoothstep(0.56 * H, 0.62 * H, p.y) * (1.0 - smoothstep(0.76 * H, 0.8 * H, p.y)) * limb;
		p.xz *= 1.0 + breath * 0.012 * torso;
		VERTEX = p;
	}
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, rim_power);
	vec3 alb = use_tex ? texture(tex, UV).rgb * base_col : base_col;
	if (use_vcol) {
		alb = COLOR.rgb * base_col;
	}
	vec3 em = glow_col * rim * rim_energy;
	if (veins > 0.0) {
		vec3 p = opos * 3.2;
		float n = vnoise(p) * 0.65 + vnoise(p * 2.3 + 7.0) * 0.35;
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.5));
		float pulse = 0.65 + 0.35 * sin(TIME * 2.4 + opos.y * 4.0);
		em += glow_col * crack * veins * 2.2 * pulse;
		alb = mix(alb, glow_col * 0.4, crack * veins);
	}
	ALBEDO = alb;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = em + vec3(flash * 2.5);
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 col : source_color = vec3(1.0, 0.4, 0.2);
uniform float energy = 3.0;
uniform float hot = 0.35;
uniform float flash = 0.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(col, vec3(1.0), ndv * ndv * hot);
	ALBEDO = c * energy * (0.55 + 0.45 * ndv) + vec3(flash * 2.0);
}
"""

static var _body_sh: Shader
static var _glow_sh: Shader
static var _mesh_cache: Dictionary = {}

var root: Node3D
var mats: Dictionary = {}
var anims: Array = []
var sil := false


static func create(m: Dictionary, silhouette: bool = false) -> Node3D:
	var id := str(m.get("species_id", ""))
	var def := SpeciesDB.get_def(StringName(str(m.get("breed", id))))  # the breed's own model wins over old model ids
	if def != null and def.model_scene != null:
		return MonsterModel.new()._imported(def.model_scene, m, silhouette)
	var b: MonsterModel = HumanoidModel.new() if HumanoidModel.handles(id) else MonsterModel.new()
	return b._build(m, silhouette)


## A real model (.glb from tools/blender). Its materials are swapped by NAME for the project shaders,
## so imported models get the same rim light, glow, hit flash and silhouette as everything else:
## glow/eye -> glow shader, anything else (skin, hair, plate, bone, wing...) -> body shader with its own color.
func _imported(scene: PackedScene, m: Dictionary, p_sil: bool) -> Node3D:
	sil = p_sil
	_make_mats(m)
	root = Node3D.new()
	root.name = "Model"
	var inst: Node3D = scene.instantiate()
	var sdef := SpeciesDB.get_def(StringName(str(m.get("breed", m.get("species_id", "")))))
	if sdef != null:
		inst.scale = Vector3.ONE * sdef.model_size
	root.add_child(inst)
	var glow: Color = mats["glow"].get_shader_parameter("col")
	var swapped := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			var key := src.resource_name if src != null else "skin"
			if not swapped.has(key):
				var bm := src as BaseMaterial3D
				var textured := bm != null and bm.albedo_texture != null
				if key == "glow" or key == "eye":
					swapped[key] = mats[key]
				elif sil:
					swapped[key] = mats["body"]
				elif textured and key in ["hair", "brows", "lashes"]:
					# hair cards: keep the texture, cut out the see-through parts, render both sides
					var hm := bm.duplicate() as BaseMaterial3D
					hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					hm.alpha_scissor_threshold = 0.4
					hm.cull_mode = BaseMaterial3D.CULL_DISABLED
					swapped[key] = hm
				else:
					var col := bm.albedo_color if bm != null else Color(0.3, 0.3, 0.3)
					var sm := _body(col, glow, 0.5 if textured else 0.6, 0.1, 0.45, 0.0)
					if key == "vcol" or key.begins_with("aitex"):  # AI sculpt: painted colors + procedural animation
						sm.set_shader_parameter("base_col", Color.WHITE)
						sm.set_shader_parameter("use_vcol", key == "vcol")  # "aitex" = textured (finished AI model)
						sm.set_shader_parameter("anim", true)
						var sd := SpeciesDB.get_def(StringName(str(m.get("breed", m.get("species_id", "")))))
						if sd != null:
							sm.set_shader_parameter("profile", ["biped", "quad", "float"].find(sd.anim_profile))
							sm.set_shader_parameter("wings", sd.anim_wings)
							sm.set_shader_parameter("hair_sway", sd.anim_hair)
							sm.set_shader_parameter("chest_bounce", sd.anim_chest)
						sm.set_shader_parameter("rim_energy", 0.35)
						root.set_meta("anim_mats", [sm])
					if textured:
						sm.set_shader_parameter("tex", bm.albedo_texture)
						sm.set_shader_parameter("use_tex", true)
					swapped[key] = sm
					mats[key] = sm
			(mi as MeshInstance3D).set_surface_override_material(i, swapped[key])
	root.set_meta("anims", anims)
	root.set_meta("mats", mats.values())
	for ap in root.find_children("*", "AnimationPlayer", true, false):  # rigged by tools/blender/autorig.py
		var player := ap as AnimationPlayer
		if not player.has_animation("Walk"):
			continue
		ExtraClips.add(player)
		for n in ["Idle", "Walk", "Run", "Talk", "Think", "Rest"]:
			if player.has_animation(n):
				player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		player.play("Idle")
		root.set_meta("skel", player)
	return root


## Rigged models: keep a looping clip ("Talk", "Think", "Rest") going while the model stands still; "" releases it.
static func hold(model: Node3D, anim: String) -> void:
	if model != null:
		model.set_meta("hold", anim)


## Rigged models: play a one-shot ("Attack", "Hit"); drive() returns to the loops when it ends.
static func play_action(model: Node3D, anim: String) -> void:
	if model == null or not model.has_meta("skel"):
		return
	var player: AnimationPlayer = model.get_meta("skel")
	if player.has_animation(anim):
		player.play(anim, 0.1)
		player.speed_scale = 1.0


static func animate(model: Node3D, t: float, mul: float = 1.0) -> void:
	if model == null or not model.has_meta("anims"):
		return
	var list: Array = model.get_meta("anims")
	for a in list:
		var n: Node3D = a["node"]
		if not is_instance_valid(n):
			continue
		var amp: float = a["amp"]
		var ph: float = a["ph"]
		var tt: float = t * float(a["spd"]) * mul + ph
		var br: Vector3 = a["rot"]
		var bp: Vector3 = a["pos"]
		var bs: Vector3 = a["scl"]
		match str(a["kind"]):
			"flicker":
				n.scale = Vector3(bs.x * (1.0 + amp * 0.5 * sin(tt * 1.7)), bs.y * (1.0 + amp * sin(tt)), bs.z * (1.0 + amp * 0.5 * sin(tt * 1.3)))
			"wag", "flap":
				n.rotation.z = br.z + amp * sin(tt)
			"yaw":
				n.rotation.y = br.y + amp * sin(tt)
			"tilt":
				n.rotation.x = br.x + amp * sin(tt)
			"float":
				n.position.y = bp.y + amp * sin(tt)
			"orbit":
				n.position = Vector3(cos(tt) * amp, bp.y + sin(tt * 1.3) * 0.15, sin(tt) * amp)
				n.rotation.y = tt
			"spin":
				n.rotation.y = br.y + tt
			"blink":
				var closed: bool = fmod(t + ph, 3.4) < 0.12
				n.scale = Vector3(bs.x, bs.y * (0.08 if closed else 1.0), bs.z)


## Per-frame animation input for procedurally animated (sculpted) models. Call every frame with the body's
## velocity in the model's own frame and its speed as a fraction of top speed. Spring physics: hair, wings and
## chest lag behind acceleration and settle (state kept in model meta). Does nothing for other models.
static func drive(model: Node3D, delta: float, local_vel: Vector3, speed_k: float, busy: bool = false) -> void:
	if model == null or not model.has_meta("anim_mats") or delta <= 0.0:
		return
	var st: Dictionary = model.get_meta("anim_state", {"phase": 0.0, "amt": 0.0, "t": 0.0, "x": Vector3.ZERO, "v": Vector3.ZERO, "last": Vector3.ZERO})
	st["t"] += delta
	st["phase"] += delta * (2.0 + 9.0 * speed_k)
	st["amt"] = lerpf(st["amt"], clampf(speed_k, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	var accel: Vector3 = (local_vel - st["last"]) / delta
	st["last"] = local_vel
	# damped spring pulled by acceleration (plus a little gravity bounce from footsteps)
	var force: Vector3 = accel * 0.004 + Vector3(0, absf(sin(float(st["phase"]))) * float(st["amt"]) * 0.02, 0)
	st["v"] = (st["v"] as Vector3) + (force - (st["x"] as Vector3) * 60.0 - (st["v"] as Vector3) * 9.0) * delta
	st["x"] = ((st["x"] as Vector3) + (st["v"] as Vector3) * delta).limit_length(0.12)
	model.set_meta("anim_state", st)
	var skinned := model.has_meta("skel")
	if skinned:  # skeleton does the body motion; shaders only add the springy secondary motion
		var player: AnimationPlayer = model.get_meta("skel")
		if not (player.current_animation in ["Attack", "Hit", "Cheer", "Wave", "Bow", "KO"] and player.is_playing()):
			var want := "Idle" if speed_k < 0.08 else ("Walk" if speed_k < 0.62 else "Run")
			if speed_k < 0.08 and str(model.get_meta("hold", "")) != "" and player.has_animation(str(model.get_meta("hold"))):
				want = str(model.get_meta("hold"))   # a looping pose held while standing still (Talk, Think, Rest)
			if player.current_animation != want:
				player.play(want, 0.2)
			player.speed_scale = 1.0 if want == "Idle" else clampf(speed_k / (0.45 if want == "Walk" else 1.0), 0.6, 1.6)
	var t: float = st["t"]
	var flap := sin(t * (3.0 + 6.0 * speed_k + (8.0 if busy else 0.0))) * (0.12 + 0.25 * speed_k + (0.3 if busy else 0.0))
	for m in (model.get_meta("anim_mats") as Array):
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("walk_phase", st["phase"])
		sm.set_shader_parameter("walk_amt", 0.0 if skinned else st["amt"])
		sm.set_shader_parameter("flap", flap)
		sm.set_shader_parameter("breath", sin(t * 2.2))
		sm.set_shader_parameter("inertia", st["x"])


## Box around every mesh in the model, in the model's own space. Sizes cameras and collision.
static func bounds(model: Node3D) -> AABB:
	return _bounds(model, Transform3D.IDENTITY)


static func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		var ab := AABB()
		var has := false
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			ab = cx * (c as MeshInstance3D).mesh.get_aabb()
			has = true
		var sub := _bounds(c, cx)
		if sub.size != Vector3.ZERO:
			ab = sub if not has else ab.merge(sub)
			has = true
		if has:
			out = ab if first else out.merge(ab)
			first = false
	return out


static func set_flash(model: Node3D, v: float) -> void:
	if model == null or not model.has_meta("mats"):
		return
	for mt in (model.get_meta("mats") as Array):
		(mt as ShaderMaterial).set_shader_parameter("flash", v)


# ---------------------------------------------------------------- materials

func _make_mats(m: Dictionary) -> void:
	if _body_sh == null:
		_body_sh = Shader.new()
		_body_sh.code = BODY_SHADER
		_glow_sh = Shader.new()
		_glow_sh.code = GLOW_SHADER
	var h := float(m.get("hue", 0)) / 360.0
	var tc: Color = Types.color(str(m.get("type", "fire")))
	var glow := Color.from_hsv(tc.h, minf(1.0, tc.s * 1.2 + 0.1), 1.0)
	if tc.s < 0.15:  # metal: cold steel-blue light instead of grey
		glow = Color(0.6, 0.8, 1.0)
	var body := Color.from_hsv(h, 0.42, 0.2)
	var plate := Color.from_hsv(h, 0.2, 0.075)
	var bone := Color(0.6, 0.57, 0.52)
	var eye := glow.lerp(Color.WHITE, 0.55)
	if sil:
		glow = Color(0.28, 0.3, 0.36)
		body = Color(0.01, 0.01, 0.015)
		plate = body
		bone = body
		eye = Color(0.12, 0.13, 0.16)
	mats["body"] = _body(body, glow, 0.9, 0.25, 0.55, 0.0)
	mats["veins"] = _body(body, glow, 0.9, 0.25, 0.55, 0.0 if sil else 1.0)
	mats["plate"] = _body(plate, glow, 0.5, 0.35, 0.5, 0.0)
	mats["bone"] = _body(bone, glow, 0.3, 0.0, 0.6, 0.0)
	mats["glow"] = _glow(glow, 0.4 if sil else 3.2, 0.3)
	mats["eye"] = _glow(eye, 0.6 if sil else 7.0, 0.6)


func _body(base: Color, glow: Color, rim: float, metal: float, rough: float, veins: float) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = _body_sh
	s.set_shader_parameter("base_col", base)
	s.set_shader_parameter("glow_col", glow)
	s.set_shader_parameter("rim_energy", rim)
	s.set_shader_parameter("metal", metal)
	s.set_shader_parameter("rough", rough)
	s.set_shader_parameter("veins", veins)
	return s


func _glow(c: Color, energy: float, hot: float) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = _glow_sh
	s.set_shader_parameter("col", c)
	s.set_shader_parameter("energy", energy)
	s.set_shader_parameter("hot", hot)
	return s


# ---------------------------------------------------------------- meshes (shared between all models)

static func _mesh(key: String) -> Mesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: Mesh
	match key:
		"sph":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 32
			s.rings = 16
			mesh = s
		"box":
			mesh = BoxMesh.new()
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 16
			mesh = c
		"pyr":  # 4-sided spike: reads sharper than a round cone
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 4
			c.rings = 1
			mesh = c
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 16
			mesh = c
		"prism":
			mesh = PrismMesh.new()
		"caps":
			var c := CapsuleMesh.new()
			c.radius = 0.5
			c.height = 2.0
			mesh = c
		"octa":
			mesh = _octahedron()
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.94
			t.outer_radius = 1.0
			t.rings = 48
			mesh = t
	_mesh_cache[key] = mesh
	return mesh


## Unit octahedron (radius 0.5), flat shaded. Crystals, shards, leaf tips.
static func _octahedron() -> ArrayMesh:
	var v := [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0.5, 0), Vector3(0, -0.5, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for xi in [0, 1]:
		for yi in [2, 3]:
			for zi in [4, 5]:
				var a: Vector3 = v[xi]
				var b: Vector3 = v[yi]
				var c: Vector3 = v[zi]
				# Godot front faces are clockwise: the cross product must point inward.
				if (b - a).cross(c - a).dot(a + b + c) > 0.0:
					var tmp := b
					b = c
					c = tmp
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
	st.generate_normals()
	return st.commit()


# ---------------------------------------------------------------- part helpers

func _p(parent: Node3D, mesh_key: String, pos: Vector3, scl: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(mesh_key)
	mi.material_override = mats[mat]
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	if mat == "glow" or mat == "eye":
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	return n


func _anim(n: Node3D, kind: String, amp: float, spd: float, ph: float = -1.0) -> void:
	anims.append({"node": n, "kind": kind, "amp": amp, "spd": spd, "ph": randf() * TAU if ph < 0.0 else ph,
		"pos": n.position, "rot": n.rotation, "scl": n.scale})


## Angry slit eyes: thin white-hot bars, inner ends tilted down.
func _eyes(parent: Node3D, y: float, z: float, sp: float, w: float, h: float, angle: float = 14.0) -> void:
	for sx in [-1.0, 1.0]:
		var e := _pivot(parent, Vector3(sx * sp, y, z), Vector3(0, sx * 12.0, sx * angle))
		_p(e, "box", Vector3.ZERO, Vector3(w, h, 0.06), "eye")
		_anim(e, "blink", 0.0, 1.0)


## Rising glowing particles (embers, spores, dust). World-space, so they trail when the kami moves.
func _particles(parent: Node3D, pos: Vector3, amount: int, extents: Vector3, vel: float, size: float = 0.035) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 4
	sm.rings = 2
	sm.material = mats["glow"]
	p.mesh = sm
	p.amount = amount
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = pos
	parent.add_child(p)


# ---------------------------------------------------------------- species

func _build(m: Dictionary, p_sil: bool) -> Node3D:
	sil = p_sil
	_make_mats(m)
	root = Node3D.new()
	root.name = "Model"
	# Each species is a method named after its id: _embergeist(), _vexa() (in HumanoidModel)...
	var fn := "_" + str(m.get("species_id", ""))
	if has_method(fn):
		call(fn)
	else:
		_p(root, "sph", Vector3(0, 1.0, 0), Vector3(1.6, 1.5, 1.5), "body")
		_eyes(root, 1.2, 0.72, 0.26, 0.24, 0.06)
	root.set_meta("anims", anims)
	root.set_meta("mats", mats.values())
	return root


## Fire spirit: cracked lava body over a flame tail, swept horns, flame crown, fanged grin.
func _embergeist() -> void:
	var c := _pivot(root, Vector3.ZERO)
	_anim(c, "float", 0.08, 2.2)
	_p(c, "sph", Vector3(0, 1.2, 0), Vector3(1.25, 1.3, 1.15), "veins")
	var tail := _p(c, "cone", Vector3(0, 0.55, -0.05), Vector3(0.9, 1.0, 0.85), "glow", Vector3(180, 0, 0))
	_anim(tail, "flicker", 0.18, 9.0)
	for sx in [-1.0, 1.0]:
		_p(c, "cone", Vector3(sx * 0.4, 1.9, -0.1), Vector3(0.17, 0.85, 0.17), "plate", Vector3(-30, 0, -sx * 28.0))
		_p(c, "sph", Vector3(sx * 0.72, 1.05, 0.25), Vector3(0.36, 0.5, 0.36), "body")
		for k in 3:
			_p(c, "pyr", Vector3(sx * (0.66 + 0.1 * k), 0.72, 0.3 + 0.06 * k), Vector3(0.07, 0.26, 0.07), "bone", Vector3(160, 0, 0))
	var crown := [Vector3(-0.28, 2.0, -0.28), Vector3(0, 2.2, -0.35), Vector3(0.28, 2.0, -0.28)]
	for i in crown.size():
		var fl := _p(c, "cone", crown[i], Vector3(0.22, 0.85, 0.22), "glow", Vector3(-25, 0, 0))
		_anim(fl, "flicker", 0.3, 7.0 + i * 2.0)
	_eyes(c, 1.42, 0.55, 0.24, 0.28, 0.07, 16.0)
	_p(c, "box", Vector3(0, 1.0, 0.56), Vector3(0.46, 0.05, 0.05), "glow")
	for sx in [-1.0, 1.0]:
		_p(c, "pyr", Vector3(sx * 0.13, 0.95, 0.57), Vector3(0.07, 0.15, 0.07), "bone", Vector3(180, 0, 0))
	if not sil:
		_particles(root, Vector3(0, 2.0, -0.25), 18, Vector3(0.35, 0.1, 0.25), 1.6)


## Sea serpent: segmented body, finned spine, long jaw with fangs, glowing gills and spots.
func _tidewyrm() -> void:
	var segs := [[Vector3(0, 0.5, -1.3), 0.62], [Vector3(0, 0.66, -0.7), 0.86], [Vector3(0, 0.82, -0.05), 1.1]]
	for i in segs.size():
		var pos: Vector3 = segs[i][0]
		var r: float = segs[i][1]
		var sg := _pivot(root, pos)
		_anim(sg, "float", 0.1, 3.5, float(i) * 1.1)
		_p(sg, "sph", Vector3.ZERO, Vector3(r, r * 0.95, r), "body")
		_p(sg, "pyr", Vector3(0, r * 0.55, -0.05), Vector3(0.12 + 0.03 * i, 0.4 + 0.15 * i, 0.3), "plate", Vector3(-35, 0, 0))
		for sx in [-1.0, 1.0]:
			_p(sg, "sph", Vector3(sx * r * 0.47, 0.0, 0.0), Vector3.ONE * 0.09, "glow")
	var hd := _pivot(root, Vector3(0, 0, 0))
	_anim(hd, "float", 0.06, 3.5, 3.3)
	_p(hd, "sph", Vector3(0, 1.15, 0.5), Vector3(0.8, 1.0, 0.8), "body", Vector3(25, 0, 0))
	_p(hd, "sph", Vector3(0, 1.62, 0.95), Vector3(0.85, 0.65, 1.3), "body")
	_p(hd, "box", Vector3(0, 1.4, 1.2), Vector3(0.6, 0.14, 0.85), "plate", Vector3(8, 0, 0))
	_p(hd, "pyr", Vector3(0, 2.0, 0.7), Vector3(0.12, 0.65, 0.35), "plate", Vector3(-55, 0, 0))
	for sx in [-1.0, 1.0]:
		_p(hd, "pyr", Vector3(sx * 0.17, 1.38, 1.55), Vector3(0.07, 0.2, 0.07), "bone", Vector3(180, 0, 0))
		_p(hd, "pyr", Vector3(sx * 0.42, 1.85, 0.75), Vector3(0.08, 0.5, 0.2), "plate", Vector3(-60, 0, -sx * 30.0))
		for k in 3:
			_p(hd, "box", Vector3(sx * 0.4, 1.05 + k * 0.13, 0.55), Vector3(0.03, 0.04, 0.3), "glow", Vector3(0, sx * 15.0, 0))
	_eyes(hd, 1.72, 1.42, 0.24, 0.22, 0.055, 18.0)
	var fin := _pivot(root, Vector3(0, 0.55, -1.7))
	_p(fin, "prism", Vector3(0, 0.1, -0.2), Vector3(0.8, 0.8, 0.05), "plate", Vector3(0, 90, 0))
	_anim(fin, "yaw", 0.35, 4.0)


## Forest golem: rune-cracked boulder, heavy brow, stone fists, branching antlers with glowing tips.
func _mossling() -> void:
	_p(root, "sph", Vector3(0, 0.95, 0), Vector3(1.8, 1.5, 1.55), "veins")
	_p(root, "box", Vector3(0, 1.38, 0.6), Vector3(1.05, 0.2, 0.4), "plate", Vector3(14, 0, 0))
	_eyes(root, 1.2, 0.74, 0.28, 0.22, 0.06, 10.0)
	_p(root, "box", Vector3(0, 0.82, 0.76), Vector3(0.5, 0.04, 0.05), "glow")
	for sx in [-1.0, 1.0]:
		_p(root, "box", Vector3(sx * 0.92, 1.38, -0.05), Vector3(0.6, 0.5, 0.65), "plate", Vector3(20, sx * 30.0, sx * 15.0))
		_p(root, "sph", Vector3(sx * 1.08, 0.52, 0.35), Vector3(0.6, 0.55, 0.6), "plate")
		_p(root, "box", Vector3(sx * 0.5, 0.18, 0.12), Vector3(0.5, 0.36, 0.6), "plate")
		var ant := _pivot(root, Vector3(sx * 0.32, 1.6, -0.1), Vector3(-12, 0, -sx * 22.0))
		_anim(ant, "wag", 0.04, 1.5)
		_p(ant, "cyl", Vector3(0, 0.45, 0), Vector3(0.09, 0.9, 0.09), "plate")
		_p(ant, "cyl", Vector3(sx * 0.18, 0.62, 0), Vector3(0.06, 0.45, 0.06), "plate", Vector3(0, 0, -sx * 50.0))
		_p(ant, "cyl", Vector3(-sx * 0.08, 0.85, 0), Vector3(0.05, 0.3, 0.05), "plate", Vector3(0, 0, sx * 35.0))
		for tip in [Vector3(0, 0.95, 0), Vector3(sx * 0.36, 0.8, 0), Vector3(-sx * 0.17, 1.0, 0)]:
			var g := _p(ant, "octa", tip, Vector3(0.14, 0.22, 0.14), "glow")
			_anim(g, "flicker", 0.25, 3.0)
	_particles(root, Vector3(0, 1.4, 0), 10, Vector3(0.9, 0.5, 0.7), 0.5, 0.03)


## Storm wolf: long body on four legs, blade ears, lightning spine and tail, fanged snout.
func _voltpup() -> void:
	_p(root, "caps", Vector3(0, 0.98, -0.15), Vector3(0.85, 0.7, 0.85), "body", Vector3(90, 0, 0))
	_p(root, "sph", Vector3(0, 1.08, 0.42), Vector3(0.9, 0.95, 0.9), "body")
	var hd := _pivot(root, Vector3(0, 0, 0))
	_anim(hd, "tilt", 0.03, 2.0)
	_p(hd, "sph", Vector3(0, 1.62, 0.72), Vector3(0.75, 0.62, 0.8), "body")
	_p(hd, "box", Vector3(0, 1.5, 1.12), Vector3(0.36, 0.26, 0.55), "body", Vector3(8, 0, 0))
	_p(hd, "box", Vector3(0, 1.34, 1.08), Vector3(0.3, 0.07, 0.45), "plate")
	_eyes(hd, 1.7, 1.06, 0.19, 0.2, 0.05, 20.0)
	for sx in [-1.0, 1.0]:
		var ear := _p(hd, "pyr", Vector3(sx * 0.26, 2.05, 0.58), Vector3(0.2, 0.62, 0.12), "plate", Vector3(-12, 0, -sx * 14.0))
		_anim(ear, "wag", sx * 0.12, 4.0, 0.0)
		_p(hd, "pyr", Vector3(sx * 0.12, 1.4, 1.36), Vector3(0.05, 0.15, 0.05), "bone", Vector3(180, 0, 0))
		var spark := _p(hd, "octa", Vector3(sx * 0.42, 1.5, 0.92), Vector3.ONE * 0.13, "glow")
		_anim(spark, "flicker", 0.5, 14.0)
		for zz in [0.45, -0.65]:
			_p(root, "cyl", Vector3(sx * 0.3, 0.38, zz), Vector3(0.17, 0.76, 0.17), "plate")
			_p(root, "pyr", Vector3(sx * 0.3, 0.05, zz + 0.12), Vector3(0.12, 0.2, 0.12), "bone", Vector3(80, 0, 0))
	for i in 5:
		var z := 0.35 - float(i) * 0.3
		var sp := _p(root, "pyr", Vector3(0, 1.45 - float(i) * 0.03, z), Vector3(0.1, 0.42 - float(i) * 0.04, 0.2), "glow", Vector3(-35, 0, 0))
		_anim(sp, "flicker", 0.35, 11.0)
	var tail := _pivot(root, Vector3(0, 1.15, -0.95))
	_anim(tail, "wag", 0.2, 6.0)
	for i in 3:
		_p(tail, "box", Vector3((0.12 if i % 2 == 0 else -0.12), 0.2 + float(i) * 0.3, -0.2 - float(i) * 0.22), Vector3(0.12, 0.12, 0.5), "glow", Vector3(-40, (25 if i % 2 == 0 else -25), 0))


## War mech: armored torso, reactor core, visor slit, spiked pauldrons, heavy fists, exhausts.
func _ironclad() -> void:
	for sx in [-1.0, 1.0]:
		_p(root, "box", Vector3(sx * 0.45, 0.48, 0), Vector3(0.52, 0.9, 0.58), "plate")
		_p(root, "box", Vector3(sx * 0.45, 0.08, 0.1), Vector3(0.62, 0.16, 0.85), "plate")
	_p(root, "box", Vector3(0, 0.98, 0), Vector3(1.2, 0.3, 0.7), "plate")
	_p(root, "box", Vector3(0, 1.62, 0), Vector3(1.7, 1.1, 1.05), "body")
	_p(root, "box", Vector3(0, 1.66, 0.5), Vector3(1.25, 0.8, 0.14), "plate", Vector3(-8, 0, 0))
	var core := _p(root, "octa", Vector3(0, 1.66, 0.6), Vector3(0.36, 0.36, 0.2), "glow")
	_anim(core, "flicker", 0.12, 4.0)
	_p(root, "box", Vector3(0, 2.4, 0.05), Vector3(0.62, 0.5, 0.6), "plate")
	_p(root, "box", Vector3(0, 2.6, 0.05), Vector3(0.12, 0.25, 0.7), "plate")
	var visor := _p(root, "box", Vector3(0, 2.42, 0.36), Vector3(0.48, 0.07, 0.05), "eye")
	_anim(visor, "flicker", 0.12, 3.0)
	for sx in [-1.0, 1.0]:
		_p(root, "box", Vector3(sx * 1.08, 2.08, 0), Vector3(0.75, 0.38, 0.88), "plate", Vector3(0, 0, -sx * 16.0))
		for zz in [-0.22, 0.22]:
			_p(root, "pyr", Vector3(sx * 1.2, 2.45, zz), Vector3(0.14, 0.5, 0.14), "plate", Vector3(0, 0, -sx * 25.0))
		_p(root, "cyl", Vector3(sx * 1.15, 1.42, 0), Vector3(0.38, 0.9, 0.38), "body")
		_p(root, "box", Vector3(sx * 1.15, 0.85, 0.08), Vector3(0.52, 0.48, 0.55), "plate")
		_p(root, "box", Vector3(sx * 1.15, 0.85, 0.37), Vector3(0.4, 0.06, 0.03), "glow")
		_p(root, "cyl", Vector3(sx * 0.38, 2.3, -0.55), Vector3(0.18, 0.75, 0.18), "plate", Vector3(-15, 0, 0))
		var ex := _p(root, "sph", Vector3(sx * 0.38, 2.68, -0.65), Vector3(0.13, 0.08, 0.13), "glow")
		_anim(ex, "flicker", 0.5, 9.0)


## Night moth: raised wings with glowing eye-spots, compound eyes, mandibles, falling dust.
func _gloomoth() -> void:
	var c := _pivot(root, Vector3.ZERO)
	_anim(c, "float", 0.1, 2.6, 0.0)
	_p(c, "sph", Vector3(0, 1.55, 0), Vector3(0.7, 0.9, 0.7), "body")
	_p(c, "sph", Vector3(0, 1.0, -0.35), Vector3(0.55, 1.05, 0.55), "veins", Vector3(30, 0, 0))
	_p(c, "sph", Vector3(0, 2.12, 0.18), Vector3(0.58, 0.52, 0.55), "body")
	for sx in [-1.0, 1.0]:
		_p(c, "sph", Vector3(sx * 0.19, 2.15, 0.36), Vector3(0.18, 0.2, 0.14), "glow")
		_p(c, "pyr", Vector3(sx * 0.1, 1.88, 0.42), Vector3(0.06, 0.24, 0.06), "bone", Vector3(150, 0, -sx * 20.0))
		var ant := _pivot(c, Vector3(sx * 0.12, 2.35, 0.2), Vector3(-25, 0, -sx * 25.0))
		_anim(ant, "wag", sx * 0.12, 4.0)
		_p(ant, "cyl", Vector3(0, 0.35, 0), Vector3(0.04, 0.7, 0.04), "plate")
		_p(ant, "pyr", Vector3(0, 0.55, 0), Vector3(0.18, 0.4, 0.04), "plate")
		var up := _pivot(c, Vector3(sx * 0.2, 1.8, -0.15), Vector3(0, -sx * 15.0, sx * 28.0))
		_anim(up, "flap", sx * 0.3, 6.0, 0.0)
		_p(up, "box", Vector3(sx * 0.85, 0, 0), Vector3(1.7, 0.04, 1.15), "plate")
		_p(up, "cyl", Vector3(sx * 1.0, 0.03, 0.05), Vector3(0.5, 0.02, 0.5), "glow")
		_p(up, "cyl", Vector3(sx * 1.0, 0.045, 0.05), Vector3(0.26, 0.02, 0.26), "plate")
		_p(up, "box", Vector3(sx * 0.85, 0.03, -0.55), Vector3(1.6, 0.02, 0.03), "glow")
		var lo := _pivot(c, Vector3(sx * 0.2, 1.42, -0.2), Vector3(0, sx * 10.0, -sx * 22.0))
		_anim(lo, "flap", sx * 0.22, 6.0, 0.4)
		_p(lo, "box", Vector3(sx * 0.6, 0, 0), Vector3(1.2, 0.04, 0.8), "plate")
		_p(lo, "box", Vector3(sx * 0.6, 0.03, 0.38), Vector3(1.1, 0.02, 0.03), "glow")
	if not sil:
		_particles(root, Vector3(0, 1.6, -0.2), 14, Vector3(1.4, 0.3, 0.5), 0.35)


## Wind fox: lean body, blade ears, three fanned tails with glowing tips, a cutting wind ring.
func _gustkit() -> void:
	_p(root, "sph", Vector3(0, 0.88, -0.12), Vector3(1.0, 0.9, 1.35), "body")
	_p(root, "sph", Vector3(0, 1.08, 0.35), Vector3(0.82, 0.88, 0.78), "body")
	_p(root, "sph", Vector3(0, 1.58, 0.55), Vector3(0.78, 0.68, 0.75), "body")
	_p(root, "cone", Vector3(0, 1.48, 0.98), Vector3(0.38, 0.55, 0.3), "body", Vector3(90, 0, 0))
	_eyes(root, 1.64, 0.88, 0.2, 0.2, 0.05, 22.0)
	for sx in [-1.0, 1.0]:
		_p(root, "pyr", Vector3(sx * 0.28, 2.08, 0.45), Vector3(0.22, 0.78, 0.14), "plate", Vector3(-10, 0, -sx * 12.0))
		_p(root, "pyr", Vector3(sx * 0.28, 2.0, 0.53), Vector3(0.1, 0.5, 0.04), "glow", Vector3(-10, 0, -sx * 12.0))
		_p(root, "pyr", Vector3(sx * 0.1, 1.36, 1.15), Vector3(0.04, 0.12, 0.04), "bone", Vector3(180, 0, 0))
		for zz in [0.4, -0.55]:
			_p(root, "cyl", Vector3(sx * 0.26, 0.3, zz), Vector3(0.13, 0.62, 0.13), "plate")
	for i in 3:
		var tp := _pivot(root, Vector3(0, 0.95, -0.7), Vector3(0, (float(i) - 1.0) * 32.0, 0))
		_anim(tp, "yaw", 0.25, 3.5, float(i) * 0.7)
		var d := Vector3(0, 0.5, -0.866)
		_p(tp, "cone", d * 0.7, Vector3(0.32, 1.4, 0.32), "body", Vector3(-60, 0, 0))
		_p(tp, "cone", d * 1.45, Vector3(0.2, 0.5, 0.2), "glow", Vector3(-60, 0, 0))
	var ring := _p(root, "ring", Vector3(0, 1.0, -0.1), Vector3(1.25, 1.0, 1.25), "glow", Vector3(12, 0, 8))
	_anim(ring, "spin", 0.0, 2.5)


## Rock brute: crack-veined boulder body, back plates, blade ears, tusks, huge fists.
func _boulderbun() -> void:
	_p(root, "sph", Vector3(0, 1.0, 0), Vector3(2.0, 1.7, 1.8), "veins")
	_p(root, "box", Vector3(0, 1.55, 0.72), Vector3(1.2, 0.2, 0.45), "plate", Vector3(14, 0, 0))
	_eyes(root, 1.36, 0.86, 0.34, 0.24, 0.07, 14.0)
	_p(root, "box", Vector3(0, 0.95, 0.9), Vector3(0.55, 0.05, 0.05), "glow")
	var plates := [[Vector3(0, 1.85, -0.45), Vector3(-20, 0, 0)], [Vector3(-0.6, 1.6, -0.6), Vector3(-25, -20, 15)], [Vector3(0.6, 1.6, -0.6), Vector3(-25, 20, -15)]]
	for pl in plates:
		_p(root, "box", pl[0], Vector3(0.7, 0.3, 0.65), "plate", pl[1])
	for sx in [-1.0, 1.0]:
		var ear := _pivot(root, Vector3(sx * 0.45, 1.8, -0.1), Vector3(-15, 0, -sx * 14.0))
		_anim(ear, "wag", sx * 0.07, 2.5)
		_p(ear, "pyr", Vector3(0, 0.65, 0), Vector3(0.32, 1.3, 0.16), "plate")
		_p(ear, "pyr", Vector3(0, 0.55, 0.05), Vector3(0.12, 0.9, 0.08), "glow")
		_p(root, "cone", Vector3(sx * 0.36, 0.95, 0.88), Vector3(0.12, 0.45, 0.12), "bone", Vector3(35, 0, -sx * 12.0))
		_p(root, "sph", Vector3(sx * 1.1, 0.55, 0.4), Vector3(0.62, 0.58, 0.62), "plate")
		_p(root, "box", Vector3(sx * 0.6, 0.15, 0.4), Vector3(0.6, 0.3, 0.75), "plate")


## Crystal entity: a white-hot core caged by four dark shards, orbiting splinters, levitation ring.
func _prismoid() -> void:
	var c := _pivot(root, Vector3.ZERO)
	_anim(c, "float", 0.15, 1.8, 0.0)
	var core := _p(c, "octa", Vector3(0, 1.6, 0), Vector3(0.6, 0.95, 0.6), "glow")
	_anim(core, "spin", 0.0, 1.2)
	var cage := _pivot(c, Vector3(0, 1.6, 0))
	_anim(cage, "spin", 0.0, -0.4)
	for i in 4:
		var arm := _pivot(cage, Vector3.ZERO, Vector3(0, -rad_to_deg(TAU * (float(i) + 0.5) / 4.0), 0))
		_p(arm, "octa", Vector3(0.72, 0, 0), Vector3(0.42, 1.7, 0.42), "plate", Vector3(0, 0, -12))
	_p(c, "ring", Vector3(0, 2.75, 0), Vector3(0.45, 1.0, 0.45), "glow")
	for i in 3:
		var g := _p(c, "octa", Vector3(1.2, 1.6, 0), Vector3(0.2, 0.32, 0.2), "glow")
		_anim(g, "orbit", 1.3 + 0.08 * float(i), 1.4, TAU * float(i) / 3.0)
	var halo := _p(root, "ring", Vector3(0, 0.05, 0), Vector3(1.0, 0.3, 1.0), "glow")
	_anim(halo, "flicker", 0.08, 3.0)


## Junk beast: box body, a furnace-lit maw with a working jaw, scrap spikes, smoking exhausts.
func _scrapjaw() -> void:
	_p(root, "box", Vector3(0, 0.95, -0.1), Vector3(1.8, 1.3, 1.6), "body")
	for sx in [-1.0, 1.0]:
		for zz in [0.45, -0.6]:
			_p(root, "box", Vector3(sx * 0.65, 0.2, zz), Vector3(0.38, 0.4, 0.45), "plate")
		_p(root, "cyl", Vector3(sx * 0.55, 1.95, -0.75), Vector3(0.2, 0.85, 0.2), "plate", Vector3(-20, 0, 0))
		var ex := _p(root, "sph", Vector3(sx * 0.55, 2.38, -0.9), Vector3(0.14, 0.08, 0.14), "glow")
		_anim(ex, "flicker", 0.5, 10.0)
		_p(root, "pyr", Vector3(sx * 0.48, 2.42, 0.2), Vector3(0.16, 0.55, 0.16), "plate", Vector3(-15, 0, -sx * 22.0))
		_p(root, "sph", Vector3(sx * 0.92, 1.25, 0.3), Vector3.ONE * 0.16, "glow")
	_p(root, "box", Vector3(0, 1.95, 0.35), Vector3(1.5, 0.7, 1.2), "plate", Vector3(-6, 0, 0))
	var maw := _p(root, "box", Vector3(0, 1.55, 0.42), Vector3(1.1, 0.24, 0.8), "glow")
	_anim(maw, "flicker", 0.15, 6.0)
	for i in 6:
		var x := -0.55 + float(i) * 0.22
		_p(root, "pyr", Vector3(x, 1.52, 0.9), Vector3(0.13, 0.28, 0.13), "bone", Vector3(180, 0, 0))
	var jaw := _pivot(root, Vector3(0, 1.42, -0.1), Vector3(14, 0, 0))
	_anim(jaw, "tilt", 0.08, 3.0)
	_p(jaw, "box", Vector3(0, -0.12, 0.55), Vector3(1.4, 0.3, 1.15), "plate")
	for i in 5:
		var x2 := -0.44 + float(i) * 0.22
		_p(jaw, "pyr", Vector3(x2, 0.12, 1.02), Vector3(0.12, 0.25, 0.12), "bone")
	_eyes(root, 2.08, 0.96, 0.42, 0.2, 0.06, 16.0)
