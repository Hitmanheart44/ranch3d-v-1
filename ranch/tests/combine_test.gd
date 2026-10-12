extends Node
## M12 check: combining is deterministic and inherits trained stats.

func _ready() -> void:
	var a := Summoner.summon_text("parent a")
	var b := Summoner.summon_text("parent b")
	var c1 := Summoner.combine(a, b)
	var c2 := Summoner.combine(b, a)
	a.stats["power"] += 200  # a heavily trained parent
	var c3 := Summoner.combine(a, b)
	print("A ", a.breed_label(), "  B ", b.breed_label())
	print("child ", c1.describe())
	print("same pair, either order -> same child: ", c1.seed_hex == c2.seed_hex and c1.stats == c2.stats)
	print("trained parent raises child power: %d -> %d" % [c1.stat("power"), c3.stat("power")])
	get_tree().quit()
