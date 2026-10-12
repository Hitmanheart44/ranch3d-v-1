extends Node3D
## Playground (F6): run around with a kami and beat on a training dummy.
## Every hit on the dummy is checked against the Damage formula and printed.
## `godot res://combat/tests/playground.tscn -- demo` drives the input on a script (for renders and checks).

const FLOOR_SHADER := """
shader_type spatial;
uniform vec3 accent : source_color;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 coord = wpos.xz / 2.0;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord) * 1.2, vec2(1e-4));
	float line = 1.0 - clamp(min(grid.x, grid.y), 0.0, 1.0);
	vec2 c = floor(wpos.xz / 2.0);
	float rnd = fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
	float fade = 1.0 - smoothstep(8.0, 28.0, length(wpos - CAMERA_POSITION_WORLD));
	ALBEDO = vec3(0.02, 0.022, 0.028) * (0.75 + 0.5 * rnd);
	ROUGHNESS = mix(0.2, 0.45, rnd);
	METALLIC = 0.4;
	EMISSION = accent * line * 0.18 * fade;
}
"""

var demo := false
var _demo_t := 0.0
var _demo_i := 0
## time, action, pressed
var _script := [
	[0.3, "move_forward", true], [1.2, "move_forward", false],
	[1.4, "attack", true], [2.9, "attack", false],
	[3.0, "move_back", true], [3.6, "move_back", false], [3.6, "move_forward", true], [3.7, "move_forward", false],
	[3.9, "blast", true], [4.0, "blast", false],
	[4.6, "dodge", true], [4.65, "dodge", false],
	[5.0, "move_forward", true], [5.9, "move_forward", false],
	[6.0, "attack", true], [7.6, "attack", false],
]
var dummy: MonsterBody
var _tag: Label3D


func _ready() -> void:
	demo = "demo" in OS.get_cmdline_user_args()
	var body := preload("res://monsters/monster_body.tscn").instantiate() as MonsterBody
	body.data = Summoner.summon_machine()
	var accent := Types.color(body.data.type)

	var we := WorldEnvironment.new()
	we.environment = EnvPresets.night(accent)
	add_child(we)
	add_child(EnvPresets.moon())

	_floor(accent)
	var slab := Color(0.035, 0.037, 0.045)
	_block(Vector3(6, 1.0, -4), Vector3(2, 2, 2), 20.0, slab, accent)
	_block(Vector3(-7, 1.5, -6), Vector3(1.5, 3, 4), -15.0, slab, accent)
	_block(Vector3(-5, 0.5, 6), Vector3(4, 1, 1.2), 40.0, slab, accent)
	_block(Vector3(9, 2.5, 7), Vector3(1.2, 5, 1.2), 0.0, slab, accent)
	var ramp := _block(Vector3(0, 0.6, -11), Vector3(4, 0.3, 6), 0.0, slab, accent)
	ramp.rotation_degrees.x = 12.0

	body.add_child(PlayerController.new())
	add_child(body)
	_spawn_dummy()

	var cam := FollowCamera.new()
	cam.target = body
	add_child(cam)
	_hint()


func _spawn_dummy() -> void:
	dummy = preload("res://monsters/monster_body.tscn").instantiate() as MonsterBody
	# A brute makes a good punching bag: big, easy to see past the camera.
	var i := 0
	dummy.data = Summoner.summon_text("training dummy 0")
	while dummy.data.main_def().body_class != "brute" and i < 200:
		i += 1
		dummy.data = Summoner.summon_text("training dummy %d" % i)
	dummy.position = Vector3(0, 0, -5)
	dummy.face_dir = Vector3(0, 0, 1)
	add_child(dummy)
	_tag = Label3D.new()
	_tag.font = UIStyle.font("mono")
	_tag.font_size = 40
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3(0, 3.4, 0)
	dummy.add_child(_tag)
	dummy.health.changed.connect(func(hp: int, mx: int) -> void:
		_tag.text = "DUMMY  %s\nHP %d / %d" % [dummy.data.breed_label().to_upper(), hp, mx])
	dummy.health.changed.emit(dummy.health.hp, dummy.health.max_hp)
	(dummy.get_node("Hurtbox") as Hurtbox).hurt.connect(_check_hit)
	dummy.health.died.connect(func() -> void:
		await get_tree().create_timer(1.5).timeout
		dummy.health.heal(dummy.health.max_hp))


## Checks the dealt damage against Damage.expected_range().
func _check_hit(r: Dictionary) -> void:
	var move := r["move"] as MoveDef
	var att := r["attacker"] as MonsterBody
	var base: float = r["base"]
	var rng := Damage.expected_range(base, r["guarded"], att.data.fatigue)
	var lo := rng.x
	var hi := rng.y
	var ok: bool = r["amount"] >= lo and r["amount"] <= hi
	print("HIT %s %d (base %.1f, type x%.1f, expected %d..%d) %s" % [move.id, r["amount"], base, r["mult"], lo, hi, "OK" if ok else "MISMATCH"])


func _floor(accent: Color) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(80, 1, 80)
	cs.shape = bs
	cs.position.y = -0.5
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = FLOOR_SHADER
	mat.set_shader_parameter("accent", accent)
	mi.material_override = mat
	sb.add_child(mi)
	add_child(sb)


## A dark static slab with a glowing seam on top.
func _block(pos: Vector3, size: Vector3, yaw_deg: float, col: Color, accent: Color) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees.y = yaw_deg
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	mi.material_override = m
	sb.add_child(mi)
	var seam := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(size.x + 0.02, 0.04, 0.06)
	seam.mesh = sm
	var em := StandardMaterial3D.new()
	em.albedo_color = accent
	em.emission_enabled = true
	em.emission = accent
	em.emission_energy_multiplier = 4.0
	seam.material_override = em
	seam.position = Vector3(0, size.y * 0.5 - 0.15, size.z * 0.5 + 0.01)
	sb.add_child(seam)
	add_child(sb)
	return sb


func _hint() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := UIStyle.label("WASD MOVE  //  J / LMB STRIKE  //  K / RMB BLAST  //  HOLD L / SHIFT GUARD  //  SPACE DODGE  //  Q E / MOUSE CAMERA", 13, UIStyle.DIM, "mono")
	layer.add_child(l)
	l.position = Vector2(24, 20)


func _process(delta: float) -> void:
	if not demo or _demo_i >= _script.size():
		return
	_demo_t += delta
	while _demo_i < _script.size() and _demo_t >= float(_script[_demo_i][0]):
		var ev := InputEventAction.new()
		ev.action = _script[_demo_i][1]
		ev.pressed = _script[_demo_i][2]
		ev.strength = 1.0 if ev.pressed else 0.0
		Input.parse_input_event(ev)
		_demo_i += 1
