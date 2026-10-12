extends Node
## Headless check of the v2 loop: summon -> plan -> end week -> training show -> back to the ranch with results.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dummy := Node.new()  # scene changes free the current scene; keep this test node out of the way
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.new_game()
	Game.intro_seen = true
	Game.trainer = "f"
	var m := Summoner.summon_machine()
	Game.add_monster(m)
	Game.summoned.append(m.seed_hex)
	Game.ap = Care.action_points()
	Save.write()
	Scenes.goto("res://world/zones/ranch_v2.tscn")
	await get_tree().create_timer(1.5).timeout
	var r = get_tree().current_scene
	print("on ranch: ", r.scene_file_path, "  kami ", Game.monsters.size(), "  capacity ", RanchLayout.capacity())
	print("blocked second summon: ", SummonRitual.blocked().split("\n")[0])
	Game.monsters[0].schedule = ["weights:1"]
	var w := Game.week
	r.end_week([], "THE WEEK")
	await get_tree().create_timer(2.5).timeout
	var back = get_tree().current_scene
	var cards: Array = back.hud_root.get_children().filter(func(c): return c is PanelContainer and c.visible and c != back.menu_panel and c != back.result_box and c != back.dialog_box)
	print("back: %s  week %d -> %d  report cards %d  free to walk %s  -> %s" % [back.scene_file_path, w, Game.week, cards.size(), not back.trainer.frozen,
		"OK" if Game.week == w + 1 and cards.size() == 1 and not back.trainer.frozen else "MISMATCH"])
	# adventure defeat: lose the only fight with a team of one -> ranch, week ends, DEFEATED results
	var w2 := Game.week
	var d := Adventure.get_dungeon("hollow")
	Game.run = {"dungeon": d[0], "floor": 1, "seed": 1, "team": [0], "ko": [], "pos": null, "spirit": 50, "spirit_max": 50,
		"money": 0, "items": {}, "opened": [], "exp": 0}
	Scenes.goto("res://explore/dungeon.tscn", {"cup_result": {"won": false, "rounds_won": 0, "rounds": 1}, "fighter": "0", "boss": false})
	await get_tree().create_timer(4.0).timeout
	var r2 = get_tree().current_scene
	print("after defeat: scene %s  week %d -> %d  free to walk %s  -> %s" % [r2.scene_file_path, w2, Game.week, not r2.trainer.frozen,
		"OK" if Game.week == w2 + 1 and not r2.trainer.frozen else "MISMATCH"])
	get_tree().quit()
