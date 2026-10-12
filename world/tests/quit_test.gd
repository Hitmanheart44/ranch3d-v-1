extends Node


func _has_label(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text.contains(text):
		return true
	for c in n.get_children():
		if _has_label(c, text):
			return true
	return false


func _find(n: Node, text: String) -> Button:
	if n is Button and _has_label(n, text):
		return n
	for c in n.get_children():
		var r := _find(c, text)
		if r != null:
			return r
	return null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.new_game(Summoner.summon_machine())
	Game.trainer = "f"
	Game.intro_seen = true
	Game.set_meta("started", true)
	Game.set_meta("loaded", true)
	Game.planned_week = Game.week
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "start"})
	await get_tree().create_timer(3.0).timeout
	var z = get_tree().current_scene
	z.main_menu()
	await get_tree().create_timer(0.3).timeout
	var q := _find(z.hud_root, "QUIT TO MAIN MENU")
	print("QUIT main menu has the button: ", q != null)
	q.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	var yes := _find(z.hud_root, "SAVE AND QUIT")
	print("QUIT confirmation shown: ", yes != null, "   keep playing offered: ", _find(z.hud_root, "KEEP PLAYING") != null)
	yes.pressed.emit()
	await get_tree().create_timer(2.5).timeout
	var cs := get_tree().current_scene
	print("QUIT now on: ", cs.get_script().resource_path if cs and cs.get_script() else str(cs))
	get_tree().quit()
