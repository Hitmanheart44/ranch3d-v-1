class_name CaveDress
extends RefCounted
## Dresses a CaveRoom with real scanned rocks (Poly Haven CC0): boulders hugging the walls, low stones and moss rocks
## across the floor, ferns in the damp corners, and glowing crystal clusters that actually light their surroundings.
## All instanced multimeshes (a handful of draw calls). The middle of the room stays clear for the fight.

const SETS := [  # glb in assets/props/ph, count, scale range, zone (0 wall ring, 1 floor), tilt
	["boulder_01", 14, Vector2(1.3, 2.6), 0, 0.2], ["rock_07", 12, Vector2(1.0, 2.0), 0, 0.3], ["rock_09", 10, Vector2(0.9, 1.8), 0, 0.3],
	["rock_moss_set_01", 16, Vector2(0.6, 1.1), 1, 0.2], ["rock_moss_set_02", 12, Vector2(0.6, 1.1), 1, 0.2], ["stone_01", 18, Vector2(0.4, 0.9), 1, 0.4],
	["fern_02", 26, Vector2(0.9, 1.6), 0, 0.0],
]
const CLEAR := 7.5   # keep the fight area free


static func build(room: CaveRoom, glow: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = room.room_seed * 31 + 7
	for set in SETS:
		var parts := Props.parts("ph/" + str(set[0]))
		if parts.is_empty():
			continue
		var bb: AABB = parts[0][2]
		var unit := 1.0 / maxf(bb.size.y, 0.05)   # normalise each model to ~1 m tall, then scale per instance
		var xf: Array[Transform3D] = []
		var tries := 0
		while xf.size() < int(set[1]) and tries < 400:
			tries += 1
			var a := rng.randf() * TAU
			if room._gap(a):
				continue
			var wr := room.wall_r(a)
			var r := wr - rng.randf_range(0.8, 4.5) if int(set[3]) == 0 else rng.randf_range(CLEAR, wr - 1.5)
			var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
			var s := rng.randf_range((set[2] as Vector2).x, (set[2] as Vector2).y)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-1.0, 1.0) * float(set[4]))
			xf.append(Transform3D(b.scaled(Vector3.ONE * s * unit), p - Vector3(0, bb.position.y * s * unit + 0.12, 0)))
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = xf.size()
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			var mat: Material = part[1]
			if mat is BaseMaterial3D:
				mat = (mat as BaseMaterial3D).duplicate()
				(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
			mmi.material_override = mat
			mmi.visibility_range_end = 60.0
			room.add_child(mmi)
	_crystals(room, rng, glow)


## Crystal clusters on the wall ring; every other cluster carries a small coloured light.
static func _crystals(room: CaveRoom, rng: RandomNumberGenerator, glow: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = glow.darkened(0.3)
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 3.2
	mat.roughness = 0.2
	var n := 9
	for i in n:
		var a := (float(i) + rng.randf_range(-0.3, 0.3)) / n * TAU
		if room._gap(a):
			continue
		var base := Vector3(cos(a), 0, sin(a)) * (room.wall_r(a) - rng.randf_range(1.2, 2.6))
		for k in rng.randi_range(3, 6):
			var m := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(rng.randf_range(0.25, 0.5), rng.randf_range(0.9, 2.6), rng.randf_range(0.25, 0.5))
			m.mesh = pm
			m.material_override = mat
			m.position = base + Vector3(rng.randf_range(-0.7, 0.7), pm.size.y * 0.5, rng.randf_range(-0.7, 0.7))
			m.rotation = Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			room.add_child(m)
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = glow
			l.light_energy = 2.4
			l.omni_range = 11.0
			l.position = base + Vector3(0, 1.2, 0) - Vector3(cos(a), 0, sin(a)) * 0.8
			room.add_child(l)
