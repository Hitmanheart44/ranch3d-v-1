extends Node
## Dev: the ranch at morning, dusk, night and in rain/snow. godot --path . --write-movie o.png --fixed-fps 30 --quit-after 150 res://tools/dev/atmo_preview.tscn
func _ready() -> void:
	Game.monsters = [Summoner.summon_text("a")]
	Game.planned_week = Game.week
	Game.trained_week = Game.week
	var z: Node = (load("res://world/zones/ranch_v2.tscn") as PackedScene).instantiate()
	add_child(z)
	await get_tree().create_timer(1.0).timeout
	var a: Atmosphere = z.find_children("*", "Atmosphere", true, false)[0]
	a.set_process(false)
	for step in [[12.0, "clear"], [18.2, "clear"], [23.0, "clear"], [14.0, "rain"]]:
		a.hour = step[0]
		a.weather = step[1]
		if step[1] != "clear" and a._precip == null:
			a._precip = a._make_precip(false)
			a.add_child(a._precip)
		a._apply()
		await get_tree().create_timer(1.0).timeout
