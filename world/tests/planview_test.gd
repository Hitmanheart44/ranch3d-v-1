extends Node
## Dev: opens the start-of-week planner over the ranch with your real kami, interactive.
##   godot --path . res://world/tests/planview_test.tscn
## The real save is read once; every write goes to user://save_test.json (the *_test.tscn rule in core/save.gd).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var real := Save.PATH
	Save.PATH = "user://save.json"
	var ok := Save.read()
	Save.PATH = "user://save_test.json"
	if not ok or Game.monsters.is_empty():
		Game.new_game(Summoner.summon_machine())
		Game.trainer = "f"
		Game.intro_seen = true
	Game.set_meta("started", true)
	Game.set_meta("loaded", true)
	Game.planned_week = 0
	Game.trained_week = 0
	Game.ap = Care.action_points()
	print("PLANVIEW real save read: ", ok, "  kami: ", Game.monsters.size(), "  writes go to ", Save.PATH, " (real: ", real, ")")
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "start"})
