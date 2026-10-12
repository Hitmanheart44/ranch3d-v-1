extends Node3D
## Model viewer: look at one breed up close. Drag to orbit, wheel to zoom, Q/E to swap breeds.
## godot --path ~/Projects/ranch3d res://tools/dev/viewer.tscn -- vexa

var defs: Array[SpeciesDef] = []
var i := 0
var model: Node3D
var cam: Camera3D
var yaw := 0.4
var pitch := -0.12
var dist := 4.2
var t := 0.0
var label: Label
var walking := false  # W toggles a walk-in-place preview of the animation


func _ready() -> void:
	defs = SpeciesDB.all()
	walking = "walk" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		for k in defs.size():
			if str(defs[k].id) == a:
				i = k
	var we := WorldEnvironment.new()
	we.environment = EnvPresets.night(Color(0.6, 0.4, 1.0))
	we.environment.volumetric_fog_enabled = false
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 30, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	for p in [Vector3(-3, 3, -3), Vector3(3, 2, -2)]:
		var rim := OmniLight3D.new()
		rim.position = p
		rim.omni_range = 9.0
		rim.light_energy = 2.5
		rim.light_color = Color(0.7, 0.5, 1.0)
		add_child(rim)
	cam = Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = UIStyle.label("", 18, UIStyle.TEXT, "display")
	label.position = Vector2(24, 18)
	layer.add_child(label)
	_show()


func _show() -> void:
	if model != null:
		model.queue_free()
	var d := defs[i]
	model = MonsterModel.create({"species_id": d.model_key(), "type": d.type, "hue": 270})
	add_child(model)
	label.text = "%s   //   %s %s   //   drag to orbit, wheel to zoom, Q / E next breed, W walk" % [d.display_name.to_upper(), d.type.to_upper(), d.body_class.to_upper()]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		yaw -= e.relative.x * 0.01
		pitch = clampf(pitch - e.relative.y * 0.01, -1.2, 0.6)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(1.0, dist * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(12.0, dist * 1.1)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_W:
			walking = not walking
		elif e.keycode == KEY_E or e.keycode == KEY_Q:
			i = (i + (1 if e.keycode == KEY_E else -1) + defs.size()) % defs.size()
			_show()


func _process(delta: float) -> void:
	t += delta
	MonsterModel.animate(model, t)
	MonsterModel.drive(model, delta, Vector3(0, 0, 3.0 if walking else 0.0), 0.6 if walking else 0.0)
	var target := Vector3(0, 1.25, 0)
	cam.position = target + Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(target)
