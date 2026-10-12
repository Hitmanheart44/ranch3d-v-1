class_name Trainer
extends CharacterBody3D
## The player: a trainer walking the ranch (third person). WASD moves relative to the camera, Shift runs.
## Placeholder body until the trainer model is approved and built.

const WALK := 4.2
const RUN := 7.5

var frozen := false  # true while a menu is open
var model: Node3D
var real: Node3D  # the trainer model, when built


func _ready() -> void:
	for a in [["interact", KEY_E], ["run", KEY_SHIFT]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	model = Node3D.new()
	add_child(model)
	var path := "res://assets/models/trainer_%s.glb" % (Game.trainer if Game.trainer != "" else "f")
	if ResourceLoader.exists(path):  # the real trainer model (AI pipeline), animated by the shared body shader
		real = MonsterModel.new()._imported(load(path), {"type": "light", "hue": 0}, false)
		model.add_child(real)
		return
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.3
	body.mesh = cm
	body.position.y = 0.75
	body.material_override = _mat(Color(0.25, 0.3, 0.42))
	model.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	head.mesh = sm
	head.position.y = 1.58
	head.material_override = _mat(Color(0.95, 0.8, 0.68))
	model.add_child(head)
	var nose := MeshInstance3D.new()  # shows which way the trainer faces
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.06, 0.12)
	nose.mesh = bm
	nose.position = Vector3(0, 1.56, 0.2)
	nose.material_override = _mat(Color(0.8, 0.3, 0.2))
	model.add_child(nose)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


var _stride := 0.0


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(v.x, 0, v.y)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		dir = dir.rotated(Vector3.UP, cam.global_rotation.y)
	var spd := RUN if Input.is_action_pressed("run") else WALK
	var want := dir * spd
	velocity.x = move_toward(velocity.x, want.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 30.0 * delta)
	velocity.y -= 20.0 * delta if not is_on_floor() else 0.0
	move_and_slide()
	if dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
	var moving := Vector2(velocity.x, velocity.z).length()
	_stride += moving * delta
	if _stride > 1.6 and is_on_floor():  # footsteps
		_stride = 0.0
		var on_path := RanchLayout.dirt(global_position.x, global_position.z) > 0.4 or TownLayout.paved(global_position.x, global_position.z)
		Sound.sfx("step_dirt" if on_path else "step_grass", -14.0, 0.1)
	if real != null:
		MonsterModel.drive(real, delta, Vector3(0, 0, moving), minf(1.0, moving / RUN))
	else:  # placeholder walk bob
		model.position.y = absf(sin(Time.get_ticks_msec() * 0.012 * (moving / WALK))) * 0.06 * minf(1.0, moving / WALK)


func facing() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
