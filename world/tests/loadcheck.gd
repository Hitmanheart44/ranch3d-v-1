extends Node


func _ready() -> void:
	var bad := 0
	for p in ["res://ui/week_planner.gd", "res://world/zones/ranch_v2.gd", "res://world/zones/town.gd", "res://ui/breeder_page.gd", "res://ui/encyclopedia_page.gd", "res://world/layouts/town_layout.gd",
			"res://world/zones/zone.gd", "res://world/zones/interior.gd", "res://world/characters/npc.gd", "res://world/layouts/kami_layout.gd",
			"res://world/layouts/ranch_layout.gd", "res://world/zones/overworld.gd", "res://world/terrain/terrain_ground.gd"]:
		var s = load(p)
		if s == null or not (s as GDScript).can_instantiate():
			bad += 1
			print("LOADCHECK FAIL ", p)
	print("LOADCHECK done, failures: ", bad)
	get_tree().quit()
