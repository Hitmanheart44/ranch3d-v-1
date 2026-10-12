extends Node3D
## Character creator: pick your trainer (female / male) and a name, before you load into the ranch.
## Shows the real trainer model when it's built (res://assets/models/trainer_<g>.glb), else a stand-in.
## Drag or A/D to turn the model. Begin -> the ranch.

var gender := "f"
var pivot: Node3D
var model: Node3D
var name_box: LineEdit
var btn_f: Button
var btn_m: Button
var _drag := false
var _spin := PI   # start facing the camera


func _ready() -> void:
	# The stage is the real shrine hill (the overworld's intro zone): the trainer stands on a stone plinth in front of the
	# torii, with the sea behind. Everything that belongs to the portrait hangs off `stage`, turned to face north.
	var ow := Overworld.new()
	ow.zone = "intro"
	add_child(ow)
	var spot := Vector3(Overworld.SHRINE_C.x, 0.0, Overworld.SHRINE_C.z + 19.0)
	spot.y = ow.height(spot.x, spot.z)
	var stage := Node3D.new()
	stage.position = spot
	stage.rotation.y = PI
	add_child(stage)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.5, 2.5, -2.0)
	rim.light_color = Color(0.6, 1.0, 0.9)
	rim.light_energy = 2.0
	rim.omni_range = 8.0
	stage.add_child(rim)
	Build.cyl(stage, Vector3(0, -0.15, 0), 1.6, 1.8, 0.3, Build.mat("rock030", Vector3(2, 2, 1), Color(0.85, 0.82, 0.76)), false, 32)
	var cam := Camera3D.new()
	cam.fov = 40
	stage.add_child(cam)
	cam.position = Vector3(1.1, 1.3, -4.8)
	cam.look_at_from_position(cam.global_position, stage.to_global(Vector3(1.1, 0.95, 0)))
	cam.make_current()
	pivot = Node3D.new()
	stage.add_child(pivot)
	_build_ui()
	_show("f")


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UIStyle.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(70, -190)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", MR4.frame_style())
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var ttl := MR4.ink("Your Trainer", 40, false, "display")
	ttl.add_theme_color_override("font_color", MR4.RIBBON)
	vb.add_child(ttl)
	vb.add_child(MR4.ink("Who will raise the kami?", 16, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	btn_f = Button.new()
	btn_f.text = "Female"
	btn_f.toggle_mode = true
	btn_f.custom_minimum_size = Vector2(190, 46)
	btn_f.pressed.connect(_show.bind("f"))
	row.add_child(btn_f)
	btn_m = Button.new()
	btn_m.text = "Male"
	btn_m.toggle_mode = true
	btn_m.custom_minimum_size = Vector2(190, 46)
	btn_m.pressed.connect(_show.bind("m"))
	row.add_child(btn_m)
	vb.add_child(MR4.ink("Name", 18, false, "display"))
	name_box = LineEdit.new()
	name_box.text = "Rio"
	name_box.max_length = 14
	name_box.custom_minimum_size = Vector2(390, 46)
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(1.0, 0.97, 0.88)
	nb.border_color = MR4.WOOD_LIGHT
	nb.set_border_width_all(2)
	nb.set_corner_radius_all(4)
	nb.content_margin_left = 12
	nb.content_margin_right = 12
	name_box.add_theme_stylebox_override("normal", nb)
	name_box.add_theme_stylebox_override("focus", nb)
	name_box.add_theme_color_override("font_color", MR4.INK)
	name_box.add_theme_color_override("caret_color", MR4.RIBBON)
	name_box.text_submitted.connect(func(_t): _begin())
	vb.add_child(name_box)
	var begin := Button.new()
	begin.text = "Begin"
	begin.custom_minimum_size = Vector2(390, 54)
	begin.pressed.connect(_begin)
	UIStyle.make_primary(begin)
	vb.add_child(begin)
	var hint := UIStyle.label("drag or A / D to turn", 13, UIStyle.DIM, "body")
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(80, -60)
	root.add_child(hint)


func _show(g: String) -> void:
	gender = g
	btn_f.button_pressed = g == "f"
	btn_m.button_pressed = g == "m"
	if model != null:
		model.queue_free()
	var path := "res://assets/models/trainer_%s.glb" % g
	if ResourceLoader.exists(path):
		model = MonsterModel.new()._imported(load(path), {"type": "light", "hue": 0}, false)
	else:
		model = _stand_in(g)
	pivot.add_child(model)
	var bb := MonsterModel.bounds(model)
	model.position.y = -bb.position.y   # feet on the plinth, not floating above it
	if model.has_meta("skel"):   # a held standing pose: humans do not hover or bob
		var pl: AnimationPlayer = model.get_meta("skel")
		pl.play("Idle")
		pl.seek(0.0, true)
		pl.pause()


func _stand_in(g: String) -> Node3D:  # until the trainer model is built
	var n := Node3D.new()
	var body := Build.mat("", Vector3.ONE, Color(0.55, 0.62, 0.7) if g == "f" else Color(0.3, 0.32, 0.38))
	var skin := Build.mat("", Vector3.ONE, Color(0.96, 0.82, 0.7))
	var hair := Build.mat("", Vector3.ONE, Color(0.3, 0.75, 0.6) if g == "f" else Color(0.12, 0.12, 0.16))
	Build.cyl(n, Vector3(0, 0.45, 0), 0.32, 0.45, 0.9, body)
	Build.cyl(n, Vector3(0, 1.15, 0), 0.24 if g == "f" else 0.3, 0.3, 0.6, body)
	Build.ball(n, Vector3(0, 1.62, 0), 0.2, Vector3.ONE, skin)
	Build.ball(n, Vector3(0, 1.7, 0.03), 0.22, Vector3(1.05, 0.9, 1.05), hair)
	if g == "f":
		Build.cyl(n, Vector3(0, 1.45, 0.22), 0.06, 0.1, 0.5, hair)
	return n


func _process(delta: float) -> void:
	_spin += Input.get_axis("move_left", "move_right") * 2.0 * delta   # turned by hand only (drag or A / D); no idle spin or motion
	pivot.rotation.y = _spin


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed and (e as InputEventMouseButton).position.x > get_viewport().get_visible_rect().size.x * 0.45
	elif e is InputEventMouseMotion and _drag:
		_spin += (e as InputEventMouseMotion).relative.x * 0.01


func _begin() -> void:
	Game.trainer = gender
	Game.player_name = name_box.text.strip_edges() if name_box.text.strip_edges() != "" else "Rio"
	Save.write()
	Scenes.goto("res://world/zones/ranch_v2.tscn")
