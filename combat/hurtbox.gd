class_name Hurtbox
extends Area3D
## The part of a MonsterBody that can be hit. Turns a hit into damage, knockback, stun and effects.
## Sits on physics layer 3 ("hurtboxes"); Hitbox/Projectile look for it.

signal hurt(result: Dictionary)

@onready var body := get_parent() as MonsterBody
@onready var health := body.get_node("Health") as Health


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	add_to_group("hurtbox")


## info: {attacker: MonsterBody, move: MoveDef, dir: Vector3, point: Vector3}. Returns {} if ignored.
func take_hit(info: Dictionary) -> Dictionary:
	if health.is_dead() or body.is_invulnerable():
		return {}
	var att := info["attacker"] as MonsterBody
	var move := info["move"] as MoveDef
	var dir: Vector3 = info["dir"]
	var r := Damage.compute(att.data, body.data, move, body.guarding)
	health.damage(r["amount"])
	body.knock(dir * move.knockback * (0.35 if body.guarding else 1.0))
	body.flash()
	body.stun(0.08 if body.guarding else move.hitstun)
	r["killed"] = health.is_dead()
	r["move"] = move
	r["attacker"] = att
	HitFx.on_hit(body.get_parent(), info["point"], dir, Types.color(att.data.type), r)
	Sound.sfx("guard" if body.guarding else ("hit_heavy" if move.knockback > 7.0 or r["killed"] else "hit"), -6.0, 0.06)
	hurt.emit(r)
	return r
