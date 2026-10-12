class_name SummonRitual
extends Node3D
## The heart of the game: calling out the kami of YOUR machine at the hokora.
## The camera frames the shrine, kami wisps converge, the game reads out this machine's real hardware, a pillar of
## light rises and the kami takes form as a kami. You name it and it joins your ranch. One kami per hardware setup.

signal finished(m: MonsterData)  # null if nothing was summoned

var spot: Vector3           # where the kami appears
var shrine: Vector3         # the hokora
var chip: MonsterData
var cam: Camera3D
var ui: Control
var lines: Label
var reveal: Label
var name_box: LineEdit
var model: Node3D
var light: OmniLight3D
var _orbit := 0.0
var _orbiting := false


## Returns "" if a summon can happen, else why not (shown to the player).
static func blocked() -> String:
	var c := Summoner.summon_machine()
	if c.seed_hex in Game.summoned:
		return "The kami of this machine already walks with you.\nNew hardware would answer with a different kami."
	if Game.monsters.size() >= RanchLayout.capacity():
		return "There's no room at your ranch for another kami.\nBuild a stable first."
	return ""


func start(p_shrine: Vector3, p_spot: Vector3, p_chip: MonsterData = null) -> void:
	Sound.sfx("summon", -4.0)
	shrine = p_shrine
	spot = p_spot
	chip = p_chip if p_chip != null else Summoner.summon_machine()  # a stone / combined kami can be passed in
	cam = Camera3D.new()
	cam.fov = 48
	add_child(cam)
	cam.global_position = spot + (spot - shrine).normalized() * 9.0 + Vector3(0, 7.0, 0)
	cam.look_at(shrine + Vector3(0, 1.5, 0))
	cam.make_current()
	light = OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.9)
	light.omni_range = 14.0
	light.light_energy = 0.0
	add_child(light)
	light.global_position = spot + Vector3(0, 2.0, 0)
	_build_ui()
	_converge()
	var hw := Summoner.read_hardware()
	var cpu := OS.get_processor_name().strip_edges()
	var gpu := RenderingServer.get_video_adapter_name().strip_edges()
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 3.0, 2.5)
	tw.parallel().tween_property(cam, "global_position", spot + (spot - shrine).normalized() * 7.0 + Vector3(0, 5.0, 0), 3.0)
	for l in ["The hokora hums. Something in the machine is listening...", "", "CPU      %s  (%d threads)" % [cpu, int(hw["threads"])],
			"GPU      %s" % gpu, "MEMORY   %d GB" % int(hw["ram_gb"]), "", "THE KAMI OF THIS MACHINE STIRS."]:
		tw.tween_callback(func(): lines.text += l + "\n")
		tw.tween_interval(0.9)
	tw.tween_callback(_pillar)
	tw.tween_interval(2.2)
	tw.tween_callback(_emerge)
	tw.tween_interval(2.5)
	tw.tween_callback(_ask_name)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = UIStyle.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 80)
		if not top:
			bar.position.y -= 80
		ui.add_child(bar)
	lines = UIStyle.label("", 18, Color(0.7, 1.0, 0.92), "mono")
	lines.position = Vector2(60, 120)
	ui.add_child(lines)
	reveal = UIStyle.label("", 40, Color(1.0, 0.88, 0.5), "display")
	reveal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	reveal.offset_top = -200
	reveal.offset_bottom = -120
	reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(reveal)


func _converge() -> void:  # wisps drawn in from all around to the spot
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 2.5
	p.position = spot + Vector3(0, 1.5, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 7.0
	pm.radial_accel_min = -6.0
	pm.radial_accel_max = -4.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color = Color(0.6, 1.0, 0.92)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = KamiLayout._dot()
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)


func _pillar() -> void:
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.6
	cm.height = 30.0
	col.mesh = cm
	col.material_override = HitFx.additive_mat(Color(0.6, 1.0, 0.9, 0.35), 4.0)
	add_child(col)
	col.global_position = spot + Vector3(0, 15.0, 0)
	col.scale = Vector3(0.05, 1, 0.05)
	var tw := create_tween()
	tw.tween_property(col, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(light, "light_energy", 9.0, 0.8)
	tw.tween_interval(1.2)
	tw.tween_property(col, "scale", Vector3(0.0, 1, 0.0), 0.6)
	tw.tween_callback(col.queue_free)


func _emerge() -> void:
	model = MonsterModel.create(chip.model_dict())
	add_child(model)
	model.global_position = spot
	model.look_at(Vector3(cam.global_position.x, spot.y, cam.global_position.z), Vector3.UP, true)
	model.scale = Vector3.ONE * 0.01
	create_tween().tween_property(model, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	HitFx.burst(self, spot + Vector3(0, 1.2, 0), Color(0.7, 1.0, 0.95), 60, 7.0)
	create_tween().tween_property(light, "light_energy", 2.0, 1.5)
	lines.text = ""
	reveal.text = "A %s kami answers!\n%s type" % [chip.breed_label(), chip.type.capitalize()]
	_orbiting = true


func _ask_name() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	reveal.text = "What will you call it?"
	name_box = LineEdit.new()
	name_box.text = chip.name
	name_box.custom_minimum_size = Vector2(420, 50)
	name_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_box.max_length = 14
	name_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_box.position = Vector2(-210, -110)
	ui.add_child(name_box)
	name_box.grab_focus()
	name_box.select_all()
	name_box.text_submitted.connect(_named)


func _named(t: String) -> void:
	chip.name = t.strip_edges() if t.strip_edges() != "" else chip.name
	Game.add_monster(chip)
	if chip.source == "machine":
		Game.summoned.append(chip.seed_hex)
	Save.write()
	reveal.text = "%s joins your ranch!" % chip.name
	name_box.queue_free()
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): finished.emit(chip); queue_free())


func _process(delta: float) -> void:
	if _orbiting and cam != null:
		_orbit += delta * 0.35
		var off := (spot - shrine).normalized().rotated(Vector3.UP, sin(_orbit) * 0.6) * 6.0
		cam.global_position = cam.global_position.lerp(spot + off + Vector3(0, 4.2, 0), 1.0 - exp(-2.0 * delta))
		cam.look_at(spot + Vector3(0, 1.2, 0))
		if model != null:
			MonsterModel.drive(model, delta, Vector3.ZERO, 0.0)
