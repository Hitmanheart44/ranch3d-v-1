extends Node


func _ready() -> void:
	var ov := Overworld.new()
	ov.zone = "ranch"
	add_child(ov)
	await get_tree().process_frame
	var lens := []
	var dirs := []
	var ends := []
	for sb in ov.get_children():
		if sb is StaticBody3D:
			for c in sb.get_children():
				if c is CollisionShape3D and c.shape is BoxShape3D and absf((c.shape as BoxShape3D).size.x - 0.3) < 0.001:
					var l: float = (c.shape as BoxShape3D).size.z
					lens.append(l)
					dirs.append(c.transform.basis.z)
					var dir: Vector3 = c.transform.basis.z
					ends.append(c.position + dir * l / 2.0)
					ends.append(c.position - dir * l / 2.0)
	var turn := 0.0
	for i in range(1, dirs.size()):
		var d0: Vector3 = (dirs[i - 1] as Vector3)
		var d1: Vector3 = (dirs[i] as Vector3)
		var ang := rad_to_deg(acos(clampf(absf(d0.dot(d1)), 0.0, 1.0)))
		turn = maxf(turn, ang)
	print("FENCE sharpest bend between neighbouring spans: ", snappedf(turn, 0.1), " degrees")
	lens.sort()
	var pillars := [Vector3(Overworld.SHRINE_C.x - 1.86, 0, Overworld.SHRINE_C.z + 16.0), Vector3(Overworld.SHRINE_C.x + 1.86, 0, Overworld.SHRINE_C.z + 16.0)]
	var best := 1e9
	for e in ends:
		for p in pillars:
			best = minf(best, Vector2(e.x - p.x, e.z - p.z).length())
	var gate_best := 1e9
	for e in ends:
		gate_best = minf(gate_best, Vector2(e.x - 0.0, e.z + 28.0).length())
	var east := Vector3(Overworld.SHRINE_C.x + 1.86, 0, Overworld.SHRINE_C.z + 16.0)
	var wall_x: float = Overworld.coast(east.z) - 2.5
	var drop_x := wall_x
	var xx := east.x + 2.0
	while xx < wall_x + 3.0:
		if ov.height(xx, east.z) < ov.height(xx - 1.0, east.z) - 0.7:
			drop_x = xx - 1.0
			break
		xx += 0.5
	var east_best := 1e9
	var far_x := -1e9
	for e in ends:
		east_best = minf(east_best, Vector2(e.x - east.x, e.z - east.z).length())
		if absf(e.z - east.z) < 0.5:
			far_x = maxf(far_x, e.x)
	var sealed := 0.0
	for sb in ov.get_children():
		if sb is StaticBody3D:
			for c in sb.get_children():
				if c is CollisionShape3D and c.shape is BoxShape3D and absf((c.shape as BoxShape3D).size.y - 3.0) < 0.001 and absf((c.shape as BoxShape3D).size.z - 0.5) < 0.001:
					sealed = (c.shape as BoxShape3D).size.x
					print("FENCE seal: x ", snappedf(c.position.x - sealed / 2.0, 0.1), " .. ", snappedf(c.position.x + sealed / 2.0, 0.1))
	print("FENCE east: ground drops away at x=", snappedf(drop_x, 0.1), " ; visible fence ends at x=", snappedf(far_x, 0.1), " ; cliff wall at x=", snappedf(wall_x, 0.1), " ; first span starts ", snappedf(east_best, 0.01), " m from the east pillar")
	print("FENCE spans=", lens.size(), "  length min ", snappedf(lens[0], 0.01), " max ", snappedf(lens[-1], 0.01),
		"  nearest span end to a torii pillar: ", snappedf(best, 0.01), " m   nearest to the gate arch: ", snappedf(gate_best, 0.1), " m")
	get_tree().quit()
