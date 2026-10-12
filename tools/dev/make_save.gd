extends Node
## Dev tool: fresh save = your machine's kami (as if summoned at the shrine) + one gifted breed, selected.
## Run WITH graphics (headless has no GPU name, so the machine kami would differ):
##   godot --path . res://tools/dev/make_save.tscn -- vexa

func _ready() -> void:
	var breed := "vexa"
	for a in OS.get_cmdline_user_args():
		breed = a
	var machine := Summoner.summon_machine()
	Game.new_game(machine)
	Game.summoned.append(machine.seed_hex)
	var gift: MonsterData
	for i in 2000:
		var m := Summoner.summon_text("gift %d" % i)
		if str(m.main_breed) == breed:
			gift = m
			break
	if gift != null:
		gift.source = "gift"
		Game.add_monster(gift)
		Game.set_active(Game.monsters.size() - 1)
	Save.write()
	print("SAVE: ", machine.breed_label(), " + ", gift.breed_label() if gift else "no " + breed)
	get_tree().quit()
