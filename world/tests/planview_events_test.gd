extends Node
## Dev: the planner over the ranch in a populated week: three kami, drills partly planned, an event this week and one
## coming up. Test save only (the *_test.tscn rule). godot --path . res://world/tests/planview_events_test.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.new_game(Summoner.summon_machine())
	Game.add_monster(Summoner.summon_text("second kami"))
	Game.add_monster(Summoner.summon_text("third kami"))
	Game.trainer = "f"
	Game.intro_seen = true
	Game.week = 2
	Game.money = 1280
	Game.set_meta("started", true)
	Game.set_meta("loaded", true)
	Game.planned_week = 0
	Game.trained_week = 0
	Game.ap = Care.action_points()
	Game.monsters[0].schedule = ["weights:1", "weights:1", "sprints:1", "", "meditation:1"]
	Game.monsters[1].schedule = ["sprints:1", "marathon:1", "marathon:1"]
	var events := Schedule.events_in(Schedule.month_of(Game.week))
	var e: Dictionary = events[0] if not events.is_empty() else {"id": "cup:demo", "name": "Meadow Cup", "kind": "regular", "month": 1}
	Game.entries = [
		{"event": e["id"], "name": e["name"], "week": Game.week, "monster": Game.monsters[1].name, "kind": e["kind"], "month": e["month"]},
		{"event": e["id"], "name": e["name"], "week": Game.week + 2, "monster": Game.monsters[0].name, "kind": e["kind"], "month": e["month"]}]
	print("PLANEVENTS kami=", Game.monsters.size(), " entries=", Game.entries.size(), " save path=", Save.PATH)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "start"})
