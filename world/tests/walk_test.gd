extends Node
## Headless: arrive in each zone from the road and walk toward its center; you must get well inside.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.new_game()
	Game.intro_seen = true
	Game.trainer = "f"
	for t in [["res://world/zones/town.tscn", "north", TownLayout.C], ["res://world/zones/shrine.tscn", "south", Overworld.SHRINE_C],
			["res://world/zones/ranch_v2.tscn", "north", Vector3.ZERO], ["res://world/zones/ranch_v2.tscn", "south", Vector3.ZERO]]:
		Scenes.goto(t[0], {"entry": t[1]})
		await get_tree().create_timer(1.6).timeout
		var z = get_tree().current_scene
		var start: Vector3 = z.trainer.global_position
		for f in 240:  # walk straight at the zone's center for 4 s
			var d: Vector3 = t[2] - z.trainer.global_position
			d.y = 0
			z.trainer.velocity = d.normalized() * 6.0
			z.trainer.move_and_slide()
			await get_tree().physics_frame
		var moved: float = Vector2(z.trainer.global_position.x - start.x, z.trainer.global_position.z - start.z).length()
		print("%s from %s: walked %.1f m  -> %s" % [t[0].get_file(), t[1], moved, "OK" if moved > 8.0 else "BLOCKED"])
	get_tree().quit()
