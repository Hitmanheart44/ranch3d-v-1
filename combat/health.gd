class_name Health
extends Node
## HP for anything that can be hurt. Knows nothing about combat; Hurtbox calls damage().

signal changed(hp: int, max_hp: int)
signal died

var max_hp := 100
var hp := 100


func setup(max_value: int) -> void:
	max_hp = max_value
	hp = max_value
	changed.emit(hp, max_hp)


func is_dead() -> bool:
	return hp <= 0


func damage(n: int) -> void:
	if is_dead():
		return
	hp = maxi(0, hp - n)
	changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()


func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	changed.emit(hp, max_hp)


func fraction() -> float:
	return float(hp) / float(maxi(1, max_hp))
