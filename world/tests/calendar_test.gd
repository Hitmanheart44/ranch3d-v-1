extends Node
## Dev: the cup calendar end to end, with screenshots (run WITH graphics).
##   godot --path . res://world/tests/calendar_test.tscn   -> ~/.cache/ranch3d_tmp/cal/NN_name.png
const OUT := "/home/hitmanheart/.cache/ranch3d_tmp/cal/"
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
	Game.new_game(Summoner.summon_text("cal test"))
	Game.intro_seen = true
	Game.trainer = "f"
	Game.money = 2000
	Game.week = 21  # Late Summer week 1: the year's promotion matches
	Game.monsters[0].rank_wins = 3
	Game.set_meta("started", true)
	Save.write()
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "house"})
	await wait(2.5)
	var z = get_tree().current_scene
	await wait(1.0)
	await shot("week_planner")
	var planner: WeekPlanner = z.find_children("*", "WeekPlanner", true, false)[0]
	planner._open_calendar()
	await wait(0.6)
	var cal: CalendarPanel = z.find_children("*", "CalendarPanel", true, false)[0]
	await shot("calendar")
	var m: MonsterData = Game.monsters[0]
	var promo := Schedule.find("promo:E", Schedule.month_of(Game.week))
	cal._register(promo, Schedule.abs_week(promo["month"], 4, Game.week), m)
	await wait(0.5)
	await shot("calendar_signed")
	cal._close()
	await wait(0.5)
	await shot("planner_after")
	planner._leave()
	await wait(1.0)
	await shot("training_results")
	print("ENTRIES ", Game.entries, " LIFE ", Game.monsters[0].lifespan_weeks)
	Game.week = int(Game.entries[0]["week"])
	Save.write()
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "house"})
	await wait(2.5)
	z = get_tree().current_scene
	await wait(1.0)
	await shot("planner_match_week")
	for pl in z.find_children("*", "WeekPlanner", true, false):
		pl._leave()
	await wait(0.4)
	await shot("goal_this_week")
	z._house_menu()
	await wait(0.4)
	await shot("house_weekend")
	z._go_to_cup(Schedule.entry_now())
	await wait(2.5)
	await shot("promo_intro_a")
	await wait(3.0)
	await shot("promo_intro_b")
	await wait(4.5)
	await shot("arena")
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "house", "cup_result": {"won": true, "rounds_won": 3, "rounds": 3},
		"fighter": m.name, "cup": "promo_e", "kind": "promotion", "event": "promo:E"})
	await wait(3.5)
	await shot("promoted")
	print("RANK ", m.rank, " ENTRIES ", Game.entries.size())
	get_tree().quit()
