class_name AIController
extends Node
## Enemy brain for a MonsterBody. Same job as PlayerController (set move_dir/guarding, call
## dodge() and Attacker.use()) but decided by a small state machine:
##   approach -> circle (hold preferred range, strafe) -> attack -> recover -> circle ...
## Reacts to the target starting an attack by dodging or guarding (more often at higher skill).
## Casters and flyers (or focus > power) fight at range with blasts; everyone else goes melee.

## 0 = sloppy and slow to strike, 1 = sharp. Scales wind-up length, reactions and pressure.
@export_range(0.0, 1.0) var skill := 0.5
var target: MonsterBody

@onready var body := get_parent() as MonsterBody
@onready var attacker := body.get_node("Attacker") as Attacker
var state := "approach"
var ranged := false
var _t := 0.0
var _think := 0.5
var _strafe := 1.0
var _guard_t := 0.0
var _tele: MeshInstance3D


func _ready() -> void:
	attacker.windup_mult = lerpf(4.5, 2.2, skill)  # strike wind-up ~0.36s at 0, ~0.18s at 1
	var cls := body.data.main_def().body_class
	ranged = cls == "caster" or cls == "flyer" or body.data.stat("focus") > body.data.stat("power")
	_tele = _make_telegraph()
	body.add_child.call_deferred(_tele)
	if target != null:
		set_target(target)


func set_target(t: MonsterBody) -> void:
	target = t
	body.face_target = t
	var ta := t.get_node("Attacker") as Attacker
	if not ta.move_started.is_connected(_on_threat):
		ta.move_started.connect(_on_threat)


func _physics_process(delta: float) -> void:
	_tele.visible = attacker.phase == "windup"
	if target == null or not is_instance_valid(target) or target.health.is_dead() or body.health.is_dead():
		body.move_dir = Vector3.ZERO
		body.guarding = false
		return
	_t += delta
	_think -= delta
	_guard_t -= delta
	body.guarding = _guard_t > 0.0
	if attacker.is_busy() or body.guarding:
		body.move_dir = Vector3.ZERO
		return

	var to := target.global_position - body.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var side := Vector3(-dir.z, 0.0, dir.x) * _strafe
	var want := 8.0 if ranged else 2.2

	match state:
		"approach":
			body.move_dir = dir
			if dist < want + 0.5:
				_go("circle")
		"circle":
			var push := clampf((dist - want) * 0.6, -1.0, 1.0)
			body.move_dir = (side * 0.8 + dir * push).limit_length(1.0)
			if randf() < delta * 0.5:
				_strafe = -_strafe
			if dist > want + 3.0:
				_go("approach")
			elif _think <= 0.0:
				_think = lerpf(1.1, 0.35, skill) * randf_range(0.7, 1.3)
				_try_attack(dist)
		"recover":
			body.move_dir = -dir * 0.6 + side * 0.4
			if _t > lerpf(0.9, 0.4, skill):
				_go("circle")


func _try_attack(dist: float) -> void:
	var mv := &"blast" if ranged else &"strike"
	if not ranged and dist > 3.4:
		# Melee kami sometimes throw a blast to punish backing off.
		if randf() < 0.35 and attacker.cooldown_left(&"blast") <= 0.0:
			mv = &"blast"
		else:
			_go("approach")
			return
	if randf() < lerpf(0.45, 0.85, skill) and attacker.use(mv):
		_go("recover")


func _go(s: String) -> void:
	state = s
	_t = 0.0


## The target started an attack: maybe sidestep it or guard.
func _on_threat(_move: MoveDef) -> void:
	if target == null or body.health.is_dead() or attacker.is_busy():
		return
	var dist := body.global_position.distance_to(target.global_position)
	if dist > 6.0:
		return
	var roll := randf()
	if roll < skill * 0.35 and body.dodge_ready():
		var away := body.global_position - target.global_position
		away.y = 0.0
		body.move_dir = Vector3(-away.z, 0.0, away.x).normalized() * _strafe
		body.dodge()
	elif roll < skill * 0.6:
		_guard_t = randf_range(0.35, 0.7)


## Red ring under the kami while it winds up an attack.
func _make_telegraph() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 2.0
	t.outer_radius = 2.15
	t.rings = 48
	mi.mesh = t
	mi.material_override = HitFx.glow_mat(Color(1.0, 0.1, 0.05), 6.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.06
	mi.visible = false
	return mi
