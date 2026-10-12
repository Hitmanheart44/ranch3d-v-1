extends Node
## F6: the home menu with three test kami. godot --path . res://ranch/tests/home_test.tscn
func _ready() -> void:
	Game.new_game()
	for n in ["alpha", "beta", "gamma"]:
		Game.add_monster(Summoner.summon_text(n))
	Game.monsters[0].name = "Nysse"
	Game.monsters[1].name = "Plant"
	Game.monsters[2].name = "Vexa"
	add_child((load("res://ranch/home_menu.tscn") as PackedScene).instantiate())
