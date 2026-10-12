extends Node


func _ready() -> void:
	var ov := Overworld.new()
	ov.zone = "intro"
	ov.rng.seed = 7
	ov.noise.seed = 3
	ov.noise.frequency = 0.012
	ov.noise2.seed = 11
	ov.noise2.frequency = 0.05
	ov._build_road()
	var z := Overworld.SHRINE_C.z + 16.0
	var line := "PROFILE z=%.0f coast=%.1f :" % [z, Overworld.coast(z)]
	var x := 24.0
	while x <= 40.0:
		line += "  %.0f:%.1f" % [x, ov.height(x, z)]
		x += 1.0
	print(line)
	get_tree().quit()
