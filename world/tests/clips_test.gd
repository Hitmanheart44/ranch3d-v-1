extends Node


func _ready() -> void:
	for id in ["trainer_f", "trainer_m", "valkra", "vexa", "nysse", "plant", "prismoid", "revenant", "sylvara", "flame", "embergeist"]:
		var path := "res://assets/models/%s.glb" % id
		if not ResourceLoader.exists(path):
			print("CLIPS ", id, ": no model file")
			continue
		var root: Node = (load(path) as PackedScene).instantiate()
		var players := root.find_children("*", "AnimationPlayer", true, false)
		var skel := root.find_children("*", "Skeleton3D", true, false)
		var names := []
		for p in players:
			for n in (p as AnimationPlayer).get_animation_list():
				names.append(n)
		print("CLIPS ", id, ": skeleton=", skel.size() > 0, "  clips=", names)
		root.free()
	get_tree().quit()
