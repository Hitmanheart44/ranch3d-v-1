class_name PlayerController
extends Node
## Drives the parent MonsterBody from the input map, relative to the active camera.
## Add as a child of a MonsterBody. The enemy version (M4) is AIController, with the same job and different brains.

@onready var body := get_parent() as MonsterBody
@onready var attacker := body.get_node("Attacker") as Attacker
var _sulk := 0.0  # a disloyal kami sometimes ignores orders for a moment


func _physics_process(_delta: float) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(v.x, 0.0, v.y)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		dir = dir.rotated(Vector3.UP, cam.global_rotation.y)
	body.move_dir = dir
	body.guarding = Input.is_action_pressed("guard") and not attacker.is_busy()
	_sulk = maxf(0.0, _sulk - _delta)
	var wants := Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("blast")
	if wants and randf() < Care.disobey_chance(body.data) * 0.5:  # MR4 obedience from bonding, halved for real-time play
		_sulk = 0.8
		HitFx.popup(body.get_parent(), body.global_position + Vector3(0, 3.0, 0), "?", Color(1, 0.85, 0.3))
	# Holding a button repeats the attack as soon as it's allowed.
	if not body.guarding and _sulk <= 0.0:
		if Input.is_action_pressed("attack"):
			attacker.use(&"strike")
		elif Input.is_action_pressed("blast"):
			attacker.use(&"blast")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge"):
		body.dodge()
	elif event.is_action_pressed("lock_on"):
		toggle_lock()


## Lock on to the nearest living enemy, or release the current lock.
func toggle_lock() -> void:
	if body.face_target != null:
		body.face_target = null
		return
	var best: MonsterBody
	var best_d := 30.0
	for n in get_tree().get_nodes_in_group("hurtbox"):
		var hb := n as Hurtbox
		if hb.body == body or hb.health.is_dead():
			continue
		var d := hb.body.global_position.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = hb.body
	body.face_target = best
