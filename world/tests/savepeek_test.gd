extends Node


func _ready() -> void:
	Save.PATH = "user://save.json"
	var ok := Save.read()
	print("SAVEPEEK read=", ok, " kami=", Game.monsters.size(), " week=", Game.week, " planned=", Game.planned_week, " entries=", Game.entries.size())
	for m in Game.monsters:
		print("SAVEPEEK  ", m.name, " rank ", m.rank, " schedule ", m.schedule)
	for e in Game.entries:
		print("SAVEPEEK  entry ", e)
	get_tree().quit()
