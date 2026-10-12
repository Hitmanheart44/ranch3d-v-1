extends Node
## M9 check: age a kami to the end of its life, retire it, round-trip the Hall through save data.

func _ready() -> void:
	Game.new_game(Summoner.summon_text("old timer"))
	var m := Game.active()
	m.fatigue = 600
	var start := m.total()
	Game.advance_week(m.lifespan_weeks)
	var exp := Game.expired()
	print("aged %dw: fatigue 600 -> %d, stats %d -> %d (old age), expired=%d" % [m.age_weeks, m.fatigue, start, m.total(), exp.size()])
	for o in exp:
		Game.retire(o, "old age")
	var d := Game.to_dict()
	Game.from_dict(JSON.parse_string(JSON.stringify(d)))
	print("hall %d, kami %d -> %s" % [Game.hall.size(), Game.monsters.size(), "OK" if Game.hall.size() == 1 and Game.monsters.is_empty() and exp.size() == 1 else "MISMATCH"])
	get_tree().quit()
