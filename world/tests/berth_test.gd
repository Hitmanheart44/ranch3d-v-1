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
	var b := TownLayout.ship_berth(ov)
	var c: Vector3 = b[0]
	var yaw: float = b[1]
	var k: float = float(b[2]) / 16.0
	var along := Vector3(sin(yaw), 0, cos(yaw))
	var across := Vector3(-along.z, 0, along.x)
	var len := 19.53 * k
	var wid := 4.68 * k
	var inwater := 0
	var total := 0
	var land_side := 0
	var land_side_total := 0
	for sx in range(-4, 5):
		for sz in range(-2, 3):
			var q: Vector3 = c + along * (len * float(sx) / 8.0) + across * (wid * float(sz) / 4.0)
			total += 1
			if ov.height(q.x, q.z) < Overworld.SEA_Y - 0.3:
				inwater += 1
	# flush: from each long side, how far must you go outward to reach land?
	for sgn in [-1.0, 1.0]:
		var gaps := []
		for sx in range(-4, 5):
			var base: Vector3 = c + along * (len * float(sx) / 8.0) + across * float(sgn) * (wid / 2.0)
			var o := 0.0
			while o < 6.0 and ov.height(base.x + across.x * float(sgn) * o, base.z + across.z * float(sgn) * o) < Overworld.SEA_Y - 0.3:
				o += 0.05
			gaps.append(o)
		var mx := 0.0
		var sum := 0.0
		for g in gaps:
			mx = maxf(mx, g)
			sum += g
		print("BERTH ", "side A" if sgn < 0 else "side B", ": gap from hull to land, average ", snappedf(sum / gaps.size(), 0.01), " m, worst ", snappedf(mx, 0.01), " m")
	print("BERTH ship scale ", snappedf(k, 0.01), " (length ", snappedf(len, 0.1), " m, width ", snappedf(wid, 0.1), " m), centre ", c.snapped(Vector3(0.1, 0.1, 0.1)), ", yaw ", snappedf(rad_to_deg(yaw), 0.1), " deg; hull footprint points in water: ", inwater, "/", total)
	get_tree().quit()
