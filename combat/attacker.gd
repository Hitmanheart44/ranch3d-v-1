class_name Attacker
extends Node
## Plays MoveDefs for its parent MonsterBody: windup -> active (hitbox / projectile) -> recovery.
## Controllers call use(&"strike"). Moves come from `moves`; empty = the default kit below.

signal move_started(move: MoveDef)

const DEFAULT_MOVES := ["res://data/moves/strike.tres", "res://data/moves/blast.tres"]
## Soft aim: attacks turn toward the nearest target inside this distance / cone.
const AIM_RANGE := 16.0
const AIM_DOT := 0.35

@export var moves: Array[MoveDef] = []
## Scales windup (enemies use > 1 so players can read their attacks).
@export var windup_mult := 1.0

@onready var body := get_parent() as MonsterBody
var current: MoveDef
var phase := ""  # "", windup, active, recovery
var _t := 0.0
var _cd: Dictionary = {}


func _ready() -> void:
	if moves.is_empty():
		for p in DEFAULT_MOVES:
			moves.append(load(p) as MoveDef)


func get_move(id: StringName) -> MoveDef:
	for mv in moves:
		if mv.id == id:
			return mv
	return null


func is_busy() -> bool:
	return current != null


func cooldown_left(id: StringName) -> float:
	return float(_cd.get(id, 0.0))


func use(id: StringName) -> bool:
	var mv := get_move(id)
	if mv == null or is_busy() or cooldown_left(id) > 0.0 or body.is_dodging() or body.is_stunned():
		return false
	current = mv
	phase = "windup"
	_t = 0.0
	body.face_dir = _aim_dir()
	Sound.sfx("blast" if str(id) == "blast" else "swing", -8.0, 0.08)
	move_started.emit(mv)
	return true


func _physics_process(delta: float) -> void:
	for k in _cd.keys():
		_cd[k] = maxf(0.0, float(_cd[k]) - delta)
	if current == null:
		body.charge = 0.0
		return
	if body.is_stunned():  # got hit out of it
		_end()
		return
	_t += delta
	body.move_lock = true
	match phase:
		"windup":
			body.charge = 0.12 + 0.08 * sin(_t * 40.0)
			if _t >= current.windup * windup_mult:
				_fire()
				phase = "active"
				_t = 0.0
		"active":
			body.charge = 0.0
			if _t >= current.active:
				phase = "recovery"
				_t = 0.0
		"recovery":
			if _t >= current.recovery:
				_end()


func _end() -> void:
	if current != null:
		_cd[current.id] = current.cooldown
	current = null
	phase = ""
	body.move_lock = false
	body.charge = 0.0


func _fire() -> void:
	var dir := _aim_dir()
	body.face_dir = dir
	var world := body.get_parent()
	var col := Types.color(body.data.type)
	if current.kind == "projectile":
		var p := Projectile.new()
		world.add_child(p)
		p.global_position = body.global_position + dir * 1.3 + Vector3(0, 1.1, 0)
		p.launch(body, current, dir, col)
		HitFx.burst(world, p.global_position, col, 8, 3.0)
	else:
		var hb := Hitbox.new()
		hb.setup(body, current, current.radius, current.active)
		world.add_child(hb)
		hb.global_position = body.global_position + dir * current.reach + Vector3(0, 1.0, 0)
		body.knock(dir * current.lunge)
		HitFx.slash(world, body.global_position + Vector3(0, 1.0, 0), dir, col)


## Lock-on target if there is one, else the nearest Hurtbox ahead, else straight ahead.
func _aim_dir() -> Vector3:
	var fwd := body.face_dir
	if body.move_dir.length() > 0.1:
		fwd = body.move_dir.normalized()
	if body.face_target != null and is_instance_valid(body.face_target):
		return _flat(body.face_target.global_position - body.global_position, fwd)
	var best: Vector3 = fwd
	var best_d := AIM_RANGE
	for n in get_tree().get_nodes_in_group("hurtbox"):
		var hb := n as Hurtbox
		if hb.body == body or hb.health.is_dead():
			continue
		var to := hb.body.global_position - body.global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and d > 0.01 and to.normalized().dot(fwd) > AIM_DOT:
			best_d = d
			best = to.normalized()
	return best


func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else fallback
