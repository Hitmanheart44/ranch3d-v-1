extends Node
## M7 check: runs every drill a few times on a fresh kami and prints the results.

func _ready() -> void:
	var m := Summoner.summon_text("trainee")
	print("before ", m.describe())
	for d in Training.all():
		m.fatigue = 0
		m.stress = 0
		var r := Training.run(m, d, 2)
		print(" | ".join(r["lines"]))
	print("after  ", m.describe())
	get_tree().quit()
