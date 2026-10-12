class_name ExploreController
extends Node
## Walking around a dungeon: camera-relative movement and dodge, no attacks (fights happen in the arena).

@onready var body := get_parent() as MonsterBody


func _physics_process(_delta: float) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(v.x, 0.0, v.y)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		dir = dir.rotated(Vector3.UP, cam.global_rotation.y)
	body.move_dir = dir
