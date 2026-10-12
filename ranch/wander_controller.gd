class_name WanderController
extends Node
## Ranch behavior for a MonsterBody: stroll to a random spot in the paddock, idle a while, sometimes turn
## to look at the camera. Same job as PlayerController/AIController (sets move_dir), calmer brain.

@export var radius := 11.0
@export var walk := 0.4  # fraction of top speed: a stroll, not a run
## Spots to keep away from: [Vector3 centre, float radius]. The map sets these (barn, pond...).
var avoid: Array = []

@onready var body := get_parent() as MonsterBody
var _target := Vector3.ZERO
var _idle := 1.5
var _look_cam := 0.0
var _stuck := 0.0
var _from := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _idle > 0.0:
		_idle -= delta
		body.move_dir = Vector3.ZERO
		_look_cam -= delta
		if _look_cam > 0.0:
			var cam := get_viewport().get_camera_3d()
			if cam != null:
				var to := cam.global_position - body.global_position
				to.y = 0.0
				body.face_dir = body.face_dir.slerp(to.normalized(), 1.0 - exp(-3.0 * delta))
		if _idle <= 0.0:
			_pick()
		return
	var to := _target - body.global_position
	to.y = 0.0
	_stuck += delta
	if _stuck > 1.2:  # barely moved for a while: blocked, go somewhere else
		_stuck = 0.0
		if body.global_position.distance_to(_from) < 0.4:
			_pick()
			return
		_from = body.global_position
	if to.length() < 0.8:
		_idle = randf_range(2.0, 5.5)
		_look_cam = _idle * 0.6 if randf() < 0.4 else 0.0
		body.move_dir = Vector3.ZERO
	else:
		body.move_dir = to.normalized() * walk


func _pick() -> void:
	for _i in 10:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for zone in avoid:
			if p.distance_to(zone[0]) < float(zone[1]):
				ok = false
		if ok:
			_target = p
			return
	_target = Vector3.ZERO
