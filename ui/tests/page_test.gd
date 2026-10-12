extends Node
## F6: opens the ranch, then shows the MR4 kami page (and closes it after 2 s to prove the dismiss path).
## godot --path . --write-movie out.png --fixed-fps 30 --quit-after 150 res://ui/tests/page_test.tscn

func _ready() -> void:
	Game.monsters = [Summoner.summon_text("hello"), Summoner.summon_text("world")]
	Game.monsters[0].name = "Nysse"
	Game.monsters[1].name = "Plant"
	Game.add_pair_bond("Nysse", "Plant", 38)
	Game.planned_week = Game.week
	Game.trained_week = Game.week
	var z: Zone = (load("res://world/zones/ranch_v2.tscn") as PackedScene).instantiate()
	add_child(z)
	await get_tree().create_timer(1.5).timeout
	if OS.get_cmdline_user_args().has("planner"):
		return
	if OS.get_cmdline_user_args().has("calendar"):
		for c in z.hud_root.get_children():
			if c is WeekPlanner:
				c.queue_free()
		CalendarPanel.open(z)
		return
	for c in z.hud_root.get_children():
		if c is WeekPlanner:
			c.queue_free()
	z.in_menu = false
	z.main_menu()
	await get_tree().create_timer(1.0).timeout
	z.say("Hana", ["Welcome to the ranch, {you}!"])
	await get_tree().create_timer(1.0).timeout
	z._next_line()
	z._monster_info()
	await get_tree().create_timer(2.5).timeout
	if z.page != null:
		(z.page.get_meta("close") as Callable).call()
	z._breeder_info()
	await get_tree().create_timer(2.0).timeout
	print("TRAINER OPEN: ", z.page != null)
	if z.page != null:
		(z.page.get_meta("close") as Callable).call()
	await get_tree().create_timer(0.3).timeout
	print("PAGE CLOSED: ", z.page == null, "  in_menu: ", z.in_menu)
