extends Node


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _ready() -> void:
	Game.new_game(Summoner.summon_machine())
	Game.add_monster(Summoner.summon_text("second kami"))
	Game.retire(Game.monsters[1], "old age")
	Game.add_monster(Summoner.summon_text("third kami"))
	Game.entries = [{"event": "cup:x", "name": "Test Cup", "week": 3, "monster": Game.monsters[0].name, "kind": "regular", "month": 1}]
	var page := BreederPage.body()
	add_child(page)
	await get_tree().process_frame
	var t: Array = []
	_texts(page, t)
	var joined := "\\n".join(t)
	print("TRAINER has SIGNED UP: ", joined.contains("SIGNED UP"), "   BONDS: ", joined.contains("BONDS"), "   HALL OF FAME: ", joined.contains("HALL OF FAME"), "   hall entry listed: ", joined.contains("lived"), "   event text leaked: ", joined.contains("Test Cup"))
	get_tree().quit()
