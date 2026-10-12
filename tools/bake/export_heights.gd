extends Node
## Step 1 of the terrain bake: dump Overworld.height() for the whole playable rectangle (1 m grid) as raw float32.
##   godot --headless --path . res://tools/bake/export_heights.tscn   -> ~/.cache/ranch3d_tmp/world_height.bin
## (then tools/bake/bake_terrain.py, or just tools/bake/bake_all.sh)
const RECT := Rect2i(-128, -128, 256, 384)   # x -128..128, z -128..256: covers every zone's region + margin

func _ready() -> void:
	var ov := Overworld.new()
	ov.zone = "intro"
	ov.rng.seed = 7
	ov.noise.seed = 3
	ov.noise.frequency = 0.012
	ov.noise2.seed = 11
	ov.noise2.frequency = 0.05
	ov._build_road()
	var f := PackedFloat32Array()
	f.resize(RECT.size.x * RECT.size.y)
	for j in RECT.size.y:
		for i in RECT.size.x:
			f[j * RECT.size.x + i] = ov.height(RECT.position.x + i, RECT.position.y + j)   # Terrain3D vertices sit on whole metres
	var out := FileAccess.open(OS.get_environment("HOME") + "/.cache/ranch3d_tmp/world_height.bin", FileAccess.WRITE)
	out.store_buffer(f.to_byte_array())
	out.close()
	print("EXPORTED ", RECT, " ", f.size(), " samples")
	get_tree().quit()
