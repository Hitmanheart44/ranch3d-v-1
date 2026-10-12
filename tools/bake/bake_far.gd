extends Node
## Bakes each zone's horizon mesh into assets/terrain/far_<zone>.res (see Overworld._far_terrain).
##   godot --headless --path . res://tools/bake/bake_far.tscn
func _ready() -> void:
	for z in ["ranch", "shrine", "town", "intro"]:
		var ov := Overworld.new()
		ov.zone = z
		ov.region = Overworld.REGIONS[z]
		ov.rng.seed = 7
		ov.noise.seed = 3
		ov.noise.frequency = 0.012
		ov.noise2.seed = 11
		ov.noise2.frequency = 0.05
		ov._build_road()
		var m := ov.build_far_mesh()
		var err := ResourceSaver.save(m, "res://assets/terrain/far_%s.res" % z, ResourceSaver.FLAG_COMPRESS)
		print("FAR ", z, " ", m.get_surface_count(), " surfaces, save: ", err)
	get_tree().quit()
