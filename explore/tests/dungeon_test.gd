extends Node
## Adventure check: start a run with two kami, walk through tunnels room to room, print the state.

func _ready() -> void:
	Game.new_game(Summoner.summon_text("adv a"))
	Game.add_monster(Summoner.summon_text("adv b"))
	Scenes.params = {"team": [0, 1], "dungeon": "hollow"}
	var d = load("res://explore/dungeon.tscn").instantiate()
	add_child(d)
	await get_tree().process_frame
	for c in d.leader.get_children():  # steer it ourselves
		if c is ExploreController:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	var moves := 0
	for hop in 6:  # head down a tunnel, let the room change, repeat
		var ex: Array = d.exits_of(d.room)
		var dir: Vector3 = CaveRoom.DIRS[ex[hop % ex.size()]]
		d.leader.global_position = Vector3(0, 0.3, 0)  # from the middle of the room
		var before: Vector2i = d.room
		for i in 300:
			if d.room != before or d._busy and d.hud.get("_ask_box") != null and d.hud._ask_box.get_child_count() > 0:
				break
			d.leader.move_dir = dir
			await get_tree().physics_frame
			moves += 1
		d.leader.move_dir = Vector3.ZERO
		await get_tree().create_timer(1.0).timeout
		print("pos %s" % d.leader.global_position)
		print("hop %d: room %s -> %s  (%d rooms on floor, %d visited)" % [hop, before, d.room, d.rooms.size(), (Game.run["visited"] as Array).size()])
		if d._busy:
			print("  stopped by a prompt (wild kami)")
			break
	print("floor %d, spirit %d/%d" % [Game.run.get("floor", 0), Game.run.get("spirit", 0), Game.run.get("spirit_max", 0)])
	get_tree().quit()
