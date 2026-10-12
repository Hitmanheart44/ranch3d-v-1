extends Node
## M5 check (F6, run it twice): 1st run makes a game and saves it, 2nd run loads it and verifies.
## `-- reset` deletes the save first.


func _ready() -> void:
	if "reset" in OS.get_cmdline_user_args():
		Save.delete()
	if Save.exists():
		Save.read()
		var m := Game.active()
		var ok := Game.week == 4 and Game.money == 460 and Game.monsters.size() == 2 and m.age_weeks == 3
		print("LOADED week %d, money %d, %d kami, active: %s (age %dw)  -> %s" % [Game.week, Game.money, Game.monsters.size(), m.describe(), m.age_weeks, "OK" if ok else "MISMATCH"])
	else:
		Game.new_game(Summoner.summon_machine())
		Game.add_monster(Summoner.summon_text("second kami"))
		Game.spend(40)
		Game.advance_week(3)
		Save.write()
		print("SAVED week %d, money %d, %d kami -> %s" % [Game.week, Game.money, Game.monsters.size(), ProjectSettings.globalize_path(Save.PATH)])
	get_tree().quit()
