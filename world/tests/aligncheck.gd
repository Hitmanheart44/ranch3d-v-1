extends Node


func _ready() -> void:
	var ov := Overworld.new()
	ov.zone = "intro"   # exactly how tools/bake/export_heights.gd builds it
	ov.rng.seed = 7
	ov.noise.seed = 3
	ov.noise.frequency = 0.012
	ov.noise2.seed = 11
	ov.noise2.frequency = 0.05
	ov._build_road()
	var rect := Rect2i(-128, -128, 256, 384)
	var bytes := FileAccess.get_file_as_bytes("res://assets/terrain/world_height.bin")
	var f := TerrainField.new()
	f.rect = rect
	f.heights = bytes.to_float32_array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst := 0.0
	var sum := 0.0
	var n := 4000
	for k in n:
		var x := rng.randf_range(-30, 70)
		var z := rng.randf_range(45, 150)
		var d := absf(f.height_at(x, z) - ov.height(x, z))
		worst = maxf(worst, d)
		sum += d
	print("ALIGN town: mean error ", snappedf(sum / n, 0.001), " m, worst ", snappedf(worst, 0.001), " m over ", n, " points")
	get_tree().quit()
