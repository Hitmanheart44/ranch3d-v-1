class_name Projectile
extends Hitbox
## A glowing bolt that flies straight, hits the first Hurtbox (not its owner) or wall, then bursts.

var velocity := Vector3.ZERO
var color := Color.WHITE


func launch(p_owner: MonsterBody, p_move: MoveDef, dir: Vector3, col: Color) -> void:
	setup(p_owner, p_move, p_move.radius, p_move.reach / maxf(p_move.proj_speed, 0.1))
	collision_mask = 4 | 1 | 8  # hurtboxes, world, walls
	velocity = dir.normalized() * p_move.proj_speed
	color = col
	body_entered.connect(_on_wall)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = p_move.radius * 0.55
	sm.height = p_move.radius * 1.1
	core.mesh = sm
	core.material_override = HitFx.glow_mat(col.lerp(Color.WHITE, 0.4), 9.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var shell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = p_move.radius
	sm2.height = p_move.radius * 2.0
	shell.mesh = sm2
	shell.material_override = HitFx.additive_mat(Color(col, 0.35), 3.0)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var lt := OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = 3.0
	lt.omni_range = 6.0
	add_child(lt)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	super(delta)


func _on_hit(hb: Hurtbox) -> void:
	if is_queued_for_deletion():
		return
	var r := hb.take_hit({"attacker": owner_body, "move": move, "dir": velocity.normalized(), "point": global_position})
	if not r.is_empty():  # empty = target was dodging: fly on through
		queue_free()


func _on_wall(b: Node3D) -> void:
	if b == owner_body or b is CharacterBody3D:
		return
	HitFx.burst(get_parent(), global_position, color, 10, 4.0)
	queue_free()
