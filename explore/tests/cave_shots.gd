extends Node
## Dev: screenshots of the adventure: a cave room, the battle-start shatter, the fight in the same room.
##   godot --path . res://explore/tests/cave_shots.tscn      -> ~/.cache/ranch3d_tmp/cave/NN_name.png

const OUT := "/home/hitmanheart/.cache/ranch3d_tmp/cave/"
var n := 0


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	get_viewport().get_texture().get_image().save_png(OUT + "%02d_%s.png" % [n, name])
	print("SHOT ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.new_game(Summoner.summon_text("cave a"))
	Game.add_monster(Summoner.summon_text("cave b"))
	for dg in ["hollow", "spires"]:
		Game.run = {}
		Scenes.goto("res://explore/dungeon.tscn", {"team": [0, 1], "dungeon": dg})
		await wait(2.5)
		var d = get_tree().current_scene
		d.leader.global_position = Vector3(0, 0.3, 6)
		await wait(1.0)
		await shot(dg + "_room")
		d.cam.yaw += PI
		await wait(0.6)
		await shot(dg + "_room_back")
	var d = get_tree().current_scene
	d.cam.yaw -= PI
	d._battle(false)
	await wait(0.5)
	d.hud._ask_box.get_child(1).emit_signal("pressed")
	await wait(0.45)
	await shot("intro_seal")
	await wait(1.0)
	await shot("intro_shatter")
	await wait(2.5)
	await shot("arena_sweep")
	await wait(2.0)
	await shot("arena_fight")
	get_tree().quit()
