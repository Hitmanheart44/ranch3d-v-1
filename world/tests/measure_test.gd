extends Node


func _verts(root: Node3D, ref: Node3D) -> Array:
	var out := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			for v in (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(ref.to_local((mi as Node3D).to_global(v)))
	return out


func _ready() -> void:
	# hokora: which side has the porch and stairs? (low geometry sticking out beyond the body)
	var n := Node3D.new()
	add_child(n)
	var h := Props.model(n, "sf/hokora_s16", Vector3.ZERO, 3.4, 0.0, false)
	await get_tree().process_frame
	var vs := _verts(h, h)
	var top := -1e9
	for v in vs:
		top = maxf(top, v.y)
	var low := {"xmin": 1e9, "xmax": -1e9, "zmin": 1e9, "zmax": -1e9}
	var up := {"xmin": 1e9, "xmax": -1e9, "zmin": 1e9, "zmax": -1e9}
	for v in vs:
		var d: Dictionary = low if v.y < top * 0.3 else up
		d["xmin"] = minf(d["xmin"], v.x)
		d["xmax"] = maxf(d["xmax"], v.x)
		d["zmin"] = minf(d["zmin"], v.z)
		d["zmax"] = maxf(d["zmax"], v.z)
	print("MEASURE hokora height ", snappedf(top, 0.01), "  lower part x ", snappedf(low["xmin"], 0.1), "..", snappedf(low["xmax"], 0.1), " z ", snappedf(low["zmin"], 0.1), "..", snappedf(low["zmax"], 0.1))
	print("MEASURE hokora upper body x ", snappedf(up["xmin"], 0.1), "..", snappedf(up["xmax"], 0.1), " z ", snappedf(up["zmin"], 0.1), "..", snappedf(up["zmax"], 0.1), "   (the porch side is where the lower part sticks out past the body)")
	# the ship beside the pier: bulwark and deck heights on the pier side
	var holder := Node3D.new()
	add_child(holder)
	holder.position = TownLayout.PIER_END + Vector3(1.0, -3.6, 4.2)
	holder.rotation.y = PI / 2
	var ship := Props.model(holder, "ph/ship_pinnace", Vector3.ZERO, 16.0, 0.0, false)
	await get_tree().process_frame
	var sv := _verts(ship, n)   # n sits at the origin, so this is world space
	var hist := {}
	var zmin := 1e9
	for v in sv:
		if v.x > 36.0 and v.x < 47.0 and v.y < -17.0:
			zmin = minf(zmin, v.z)
			if v.z < zmin + 1.2:
				var y := snappedf(v.y, 0.25)
				hist[y] = int(hist.get(y, 0)) + 1
	var ys := hist.keys()
	ys.sort()
	var line := "MEASURE ship hull side nearest the pier is at z=%.2f; vertex heights within 1.2 m of that side (x 36..47):" % zmin
	for y in ys:
		line += "  %.2f(%d)" % [y, hist[y]]
	print(line)
	print("MEASURE pier deck y=", TownLayout.QUAY.y + 0.1, "  pier end ", TownLayout.PIER_END, "  pier half-width 1.2 -> pier edge z ~", snappedf(TownLayout.PIER_END.z + 1.2, 0.1))
	get_tree().quit()
