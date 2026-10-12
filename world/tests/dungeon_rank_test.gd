extends Node


func _ready() -> void:
	Game.new_game(Summoner.summon_machine())
	print("DUNGEONS rank E kami -> trainer rank ", Game.trainer_rank(), ", choices: ", Adventure.dungeon_choices().size())
	Game.monsters[0].rank = "C"
	print("DUNGEONS a rank C kami -> trainer rank ", Game.trainer_rank(), ", choices: ", Adventure.dungeon_choices().size(), " (", (Adventure.dungeon_choices().map(func(c): return c[0])), ")")
	Game.retire(Game.monsters[0], "test")
	Game.add_monster(Summoner.summon_text("new kami"))
	print("DUNGEONS after the C kami retires and a fresh E kami arrives -> trainer rank ", Game.trainer_rank(), ", choices: ", Adventure.dungeon_choices().size())
	var d := Game.to_dict()
	Game.top_rank = "E"
	Game.from_dict(d)
	print("DUNGEONS saved and reloaded -> trainer rank ", Game.trainer_rank())
	get_tree().quit()
