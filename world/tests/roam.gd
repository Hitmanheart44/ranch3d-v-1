extends Node


func _snap(z: Node) -> Array:
	var out := []
	for b in z.bodies:
		out.append(b.global_position)
	return out


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.new_game(Summoner.summon_machine())
	Game.ap = Care.action_points()
	Game.planned_week = Game.week
	Game.trained_week = Game.week
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "south"})
	await get_tree().create_timer(3.0).timeout
	var z = get_tree().current_scene
	print("ROAM bodies=", z.bodies.size(), " trainer=", z.trainer.global_position, " frozen=", z.trainer.frozen)
	var a := _snap(z)
	await get_tree().create_timer(10.0).timeout
	var b := _snap(z)
	for i in a.size():
		print("ROAM body", i, " moved ", (a[i] as Vector3).distance_to(b[i]), " m, move_dir=", z.bodies[i].get_child_count())
	# walk the trainer for 3 s
	var p0: Vector3 = z.trainer.global_position
	for i in 90:
		z.trainer.velocity = Vector3(5.0, z.trainer.velocity.y - 0.3, 0)
		z.trainer.move_and_slide()
		await get_tree().physics_frame
	print("ROAM trainer walked ", p0.distance_to(z.trainer.global_position), " m")
	# stand in front of the first kami, facing it
	if not z.bodies.is_empty():
		var m = z.bodies[0]
		z.trainer.global_position = m.global_position + Vector3(0, 0.2, -1.8)
		z.trainer.model.rotation.y = 0.0
		await get_tree().create_timer(0.6).timeout
		print("ROAM prompt='", z.prompt.text, "' current=", z.current.keys(), " facing=", z.trainer.facing())
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.6).timeout
		print("ROAM after E: in_menu=", z.in_menu, " talking=", z.talking != null)
		var md: MonsterData = m.data
		var ap0: int = Game.ap
		var full0: float = md.fullness
		z._feed()
		await get_tree().create_timer(0.5).timeout
		print("ROAM feed: ap ", ap0, "->", Game.ap, " fullness ", full0, "->", md.fullness, " in_menu=", z.in_menu)
		z._pet()
		await get_tree().create_timer(0.5).timeout
		print("ROAM pet: ap ->", Game.ap, " in_menu=", z.in_menu)
		z.close_menu()
		await get_tree().create_timer(3.0).timeout
		var p1: Vector3 = m.global_position
		await get_tree().create_timer(5.0).timeout
		print("ROAM after menu closed, kami roams again: moved ", p1.distance_to(m.global_position), " m")
	get_tree().quit()
