extends Node


func _ready() -> void:
	var ov := Overworld.new()
	ov.zone = "town"
	add_child(ov)
	await get_tree().process_frame
	var tl: Node3D = null
	for c in ov.get_children():
		if c is TownLayout:
			tl = c
	var lamps: Array = []
	for i in 7:
		var sa: Array = Overworld.street_at(0.06 + i * 0.14)
		var dir: Vector3 = sa[1]
		lamps.append((sa[0] as Vector3) + Vector3(-dir.z, 0, dir.x) * (3.6 if i % 2 == 0 else -3.6))
	var clashes := 0
	var worst := 99.0
	for c in tl.get_children():
		if not (c is Node3D) or c is MeshInstance3D or c is OmniLight3D or c is StaticBody3D or c is GPUParticles3D:
			continue
		for l in lamps:
			var d := Vector2(c.global_position.x - l.x, c.global_position.z - l.z).length()
			if d < 0.05:
				continue   # the lamp itself
			if d < 1.4:
				clashes += 1
				worst = minf(worst, d)
	print("LAMPS props within 1.4 m of a lamp post: ", clashes, "   closest ", snappedf(worst, 0.01) if clashes > 0 else "none")
	get_tree().quit()
