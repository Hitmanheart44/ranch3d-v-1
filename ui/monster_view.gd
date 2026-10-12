class_name MonsterView
extends Control
## A live 3D portrait of a kami, usable anywhere a Control fits.
## Usage (unchanged from the alpha's 2D version):
##   var v := MonsterView.new(); v.custom_minimum_size = Vector2(300, 260); v.setup(monster_dict)
##
## Renders MonsterModel (the same model the arena uses) in its own transparent SubViewport
## with its own lights, so the ranch, stable, dex, hall and summon screen all show the
## real 3D kami. The old code-drawn 2D art is in ~/summoner_backup_pre_restyle/ (ChipMon).
##
## Public API kept for main.gd / summon_screen.gd: setup(), hit(), unknown, faint, facing, shake.

var species_id: String = "embergeist"
var hue: int = 0
var type_id: String = "fire"
var unknown: bool = false:   # dark silhouette (for the Dex)
	set(v):
		if v != unknown:
			unknown = v
			_rebuild()
var faint: bool = false      # knocked out: tips over
var facing: float = 1.0      # 1 = turned toward the right, -1 = toward the left
var shake: float = 0.0       # hit reaction
var t: float = 0.0
var phase: float = randf() * 6.28

var _m: Dictionary = {}
var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: Node3D
var _ring: MeshInstance3D
var _rim_l: OmniLight3D
var _rim_r: OmniLight3D
var _flash := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.0
	key.light_color = Color(0.95, 0.93, 1.0)
	_vp.add_child(key)
	_rim_l = OmniLight3D.new()
	_rim_l.position = Vector3(-2.5, 2.5, -2.0)
	_rim_l.omni_range = 7.0
	_rim_l.light_energy = 2.0
	_vp.add_child(_rim_l)
	_rim_r = OmniLight3D.new()
	_rim_r.position = Vector3(2.5, 1.5, -2.0)
	_rim_r.omni_range = 7.0
	_rim_r.light_energy = 1.4
	_vp.add_child(_rim_r)

	_pivot = Node3D.new()
	_vp.add_child(_pivot)

	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.17
	tm.outer_radius = 1.2
	tm.rings = 64
	_ring.mesh = tm
	_ring.position.y = 0.01
	_vp.add_child(_ring)

	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)


func setup(m: Dictionary, p_unknown: bool = false) -> void:
	_m = m
	species_id = str(m.get("species_id", "embergeist"))
	hue = int(m.get("hue", 0))
	type_id = str(m.get("type", "fire"))
	faint = false
	unknown = p_unknown
	_rebuild()


func hit() -> void:
	shake = 1.0
	_flash = 1.0


func _rebuild() -> void:
	if _pivot == null:
		return
	if _model != null:
		_model.queue_free()
	var m := _m.duplicate() if _m != null else {}
	m.merge({"species_id": species_id, "hue": hue, "type": type_id}, true)
	_model = MonsterModel.create(m, unknown)
	_pivot.add_child(_model)

	var tc: Color = Types.color(type_id)
	var glow := Color(0.3, 0.32, 0.38) if unknown else Color.from_hsv(tc.h, minf(1.0, tc.s * 1.2 + 0.1), 1.0)
	_rim_l.light_color = glow
	_rim_r.light_color = glow.lerp(Color.WHITE, 0.4)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = glow * (0.4 if unknown else 0.9)
	_ring.material_override = rm

	# Frame the camera on the model's bounds, so tall and wide species both fit.
	var ab := MonsterModel.bounds(_model)
	var ctr := ab.get_center()
	_ring.scale = Vector3.ONE * clampf(ab.size.x * 0.45, 0.5, 1.1)
	var reach := maxf(ab.size.y, maxf(ab.size.x, ab.size.z) * 0.8) * 0.5
	var dist := reach / tan(deg_to_rad(_cam.fov * 0.5)) * 1.18
	var eye := ctr + Vector3(0, ab.size.y * 0.25 + 0.3, dist)
	_cam.transform = Transform3D(Basis(), eye).looking_at(ctr + Vector3(0, -0.05, 0), Vector3.UP)


func _process(delta: float) -> void:
	if _model == null or not is_visible_in_tree():
		return
	t += delta
	shake = maxf(0.0, shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 4.0)
	MonsterModel.animate(_model, t + phase)
	MonsterModel.drive(_model, delta, Vector3.ZERO, 0.0)
	MonsterModel.set_flash(_model, _flash)
	_pivot.rotation.y = deg_to_rad(28.0) * facing + sin(t * 0.4 + phase) * 0.12
	_pivot.position.x = sin(t * 70.0) * 0.12 * shake
	if faint:
		_pivot.rotation.z = lerpf(_pivot.rotation.z, -1.3 * facing, 1.0 - exp(-8.0 * delta))
	else:
		_pivot.rotation.z = 0.0
