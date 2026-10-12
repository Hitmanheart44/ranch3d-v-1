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
	var worst := 0.0
	var wz := Vector2.ZERO
	var buried := 0
	for i in 240:
		var a := TAU * (i + 0.5) / 240.0
		var h := ov.height(cos(a) * RanchLayout.WALL_R, sin(a) * RanchLayout.WALL_R)
		if absf(h) > 0.15:
			buried += 1
		if absf(h) > absf(worst):
			worst = h
			wz = Vector2(cos(a), sin(a)) * RanchLayout.WALL_R
	print("RING ground height along the wall: worst ", snappedf(worst, 0.01), " m at ", wz.round(), "; ", buried, "/240 points more than 0.15 m off the old flat y=0")
	# the torii: where are the pillars really?
	var n := Node3D.new()
	add_child(n)
	n.scale = Vector3.ONE * 1.45
	var m := Props.model(n, "sf/torii_s23", Vector3.ZERO, 4.4, 0.0, false)
	await get_tree().process_frame
	var left := []
	var right := []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var vs: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in vs:
				var w: Vector3 = n.to_local((mi as Node3D).to_global(v))
				if w.y < 0.6:
					(left if w.x < 0.0 else right).append(w)
	for side in [left, right]:
		if side.is_empty():
			continue
		var lo := Vector3(1e9, 0, 1e9)
		var hi := Vector3(-1e9, 0, -1e9)
		for w in side:
			lo = Vector3(minf(lo.x, w.x), 0, minf(lo.z, w.z))
			hi = Vector3(maxf(hi.x, w.x), 0, maxf(hi.z, w.z))
		print("RING torii pillar foot: x ", snappedf(lo.x, 0.01), "..", snappedf(hi.x, 0.01), "  centre x ", snappedf((lo.x + hi.x) / 2.0, 0.01), "  z centre ", snappedf((lo.z + hi.z) / 2.0, 0.01), "  radius ~", snappedf((hi.x - lo.x) / 2.0, 0.01))
	get_tree().quit()
