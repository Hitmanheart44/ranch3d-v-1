class_name Npc
extends Node3D
## A townsperson: a simple stylized figure (placeholder until NPC models), a name, what they say, and optionally a
## service (shop / association) that opens after they talk. Turns to face you when you're close. Can wander a little.

var npc_name := ""
var lines: Array = []          # what they say (one box each)
var service: Callable          # runs after the dialogue (shop menu etc.), optional
var wander := 0.0
var look := {"robe": Color(0.4, 0.45, 0.6), "hair": Color(0.2, 0.15, 0.12), "skin": Color(0.95, 0.8, 0.68)}
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _t := 0.0
var _body: Node3D


static func make(p_name: String, pos: Vector3, p_lines: Array, p_look: Dictionary = {}, p_service := Callable(), p_wander := 0.0) -> Npc:
	var n := Npc.new()
	n.npc_name = p_name
	n.position = pos
	n.lines = p_lines
	n.look.merge(p_look, true)
	n.service = p_service
	n.wander = p_wander
	return n


var _real: Node3D
var yaw0 := 0.0   # which way the NPC faces until the player comes close (0 = toward +z)


func _ready() -> void:
	_home = position
	_target = position
	_t = randf() * 10.0
	_body = Node3D.new()
	_body.rotation.y = yaw0
	add_child(_body)
	var mpath := "res://assets/models/%s.glb" % str(look.get("model", ""))
	if look.has("model") and ResourceLoader.exists(mpath):  # a real (AI-built, rigged) model
		_real = MonsterModel.new()._imported(load(mpath), {"type": "light", "hue": 0}, false)
		_body.add_child(_real)
	else:
		_primitive_body()
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	sb.add_child(cs)
	add_child(sb)


func _primitive_body() -> void:
	var robe := Build.mat("", Vector3.ONE, look["robe"])
	var skin := Build.mat("", Vector3.ONE, look["skin"])
	var hair := Build.mat("", Vector3.ONE, look["hair"])
	Build.cyl(_body, Vector3(0, 0.5, 0), 0.26, 0.4, 1.0, robe)
	Build.cyl(_body, Vector3(0, 1.18, 0), 0.2, 0.26, 0.45, robe)
	Build.ball(_body, Vector3(0, 1.58, 0), 0.19, Vector3.ONE, skin)
	Build.ball(_body, Vector3(0, 1.66, 0.04), 0.205, Vector3(1.05, 0.85, 1.05), hair)
	Build.box(_body, Vector3(0, 0.95, 0), Vector3(0.62, 0.08, 0.5), Build.mat("", Vector3.ONE, look["robe"].darkened(0.4)))  # sash


## Gesture while the player is talking to them.
func talk(on: bool) -> void:
	if _real != null:
		MonsterModel.hold(_real, "Talk" if on else "")


func face(p: Vector3) -> void:
	var to := p - global_position
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 0.2)


func _process(delta: float) -> void:
	_t += delta
	if _real != null:
		var walking := wander > 0.0 and (_target - position).length() > 0.3
		MonsterModel.drive(_real, delta, Vector3(0, 0, 1.1 if walking else 0.0), 0.3 if walking else 0.0)
	_body.position.y = absf(sin(_t * 1.7)) * 0.015
	if wander > 0.0:
		var to := _target - position
		to.y = 0
		if to.length() < 0.3:
			if randf() < delta * 0.3:
				_target = _home + Vector3(randf_range(-wander, wander), 0, randf_range(-wander, wander))
		else:
			position += to.normalized() * delta * 1.1
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
			_body.position.y = absf(sin(_t * 9.0)) * 0.05
