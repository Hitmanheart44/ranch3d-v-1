class_name Hitbox
extends Area3D
## A short-lived damage sphere. Hits each Hurtbox once, never its owner.
## Attacker spawns one for melee moves; Projectile extends it.

var owner_body: MonsterBody
var move: MoveDef
var life := 0.1
var _hit: Array = []


func _init() -> void:
	collision_layer = 0
	collision_mask = 4
	monitorable = false


func setup(p_owner: MonsterBody, p_move: MoveDef, radius: float, p_life: float) -> void:
	owner_body = p_owner
	move = p_move
	life = p_life
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = radius
	cs.shape = sp
	add_child(cs)


func _physics_process(delta: float) -> void:
	_scan()
	life -= delta
	if life <= 0.0:
		queue_free()


func _scan() -> void:
	for a in get_overlapping_areas():
		var hb := a as Hurtbox
		if hb == null or hb.body == owner_body or hb in _hit:
			continue
		_hit.append(hb)
		_on_hit(hb)


func _on_hit(hb: Hurtbox) -> void:
	var dir := hb.body.global_position - owner_body.global_position
	dir.y = 0.0
	hb.take_hit({"attacker": owner_body, "move": move, "dir": dir.normalized(),
		"point": hb.global_position.lerp(global_position, 0.4) + Vector3(0, 0.2, 0)})
