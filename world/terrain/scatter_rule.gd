@tool
extends "res://addons/proton_scatter/src/modifiers/base_modifier.gd"
## ProtonScatter modifier for this game's ground: drops the transforms that land on roads, yards, town paving,
## buildings' valley, the shrine plateau or the wrong slope, then snaps the rest onto Overworld.height()
## (so no physics raycast is needed) with a random yaw and scale.

static var ov: Overworld

@export var min_slope := 0.0          # gradient (rise/run) a spot must have...
@export var max_slope := 9.0          # ...and may not exceed
@export var min_scale := 0.8
@export var max_scale := 1.3
@export var min_ranch_dist := 0.0     # keep clear of the ranch yard
@export var cliff_margin := 3.0       # keep this far from the cliff edge (negative: allow right at it)
@export var sink := 0.0               # push into the ground a little
@export var shrine_ring := Vector2.ZERO   # (min, max) distance from the shrine centre: dresses the plateau instead of skipping it


func _init() -> void:
	display_name = "Game Ground Rules"
	category = "Edit"
	can_override_seed = true


func _process_transforms(transforms, _domain, random_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var keep: Array[Transform3D] = []
	for t: Transform3D in transforms.list:
		var x := t.origin.x
		var z := t.origin.z
		var h := ov.height(x, z)
		var gx := ov.height(x + 1.0, z) - ov.height(x - 1.0, z)
		var gz := ov.height(x, z + 1.0) - ov.height(x, z - 1.0)
		var slope := sqrt(gx * gx + gz * gz) * 0.5
		if slope < min_slope or slope > max_slope or h < -3.0 and ov.zone != "town":
			continue
		if x > Overworld.coast(z) - cliff_margin or Vector2(x, z).length() < min_ranch_dist:
			continue
		if ov.road_info(x, z).x < 4.0 or RanchLayout.dirt(x, z) > 0.05 or TownLayout.paved(x, z):
			continue
		var sd := Vector2(x - Overworld.SHRINE_C.x, z - Overworld.SHRINE_C.z).length()
		if ov.street_info(x, z).x < 14.0:
			continue
		if shrine_ring != Vector2.ZERO:
			if sd < shrine_ring.x or sd > shrine_ring.y or _near_shrine_path(x, z):
				continue
		elif sd < 24.0 and h > 4.0:
			continue
		var s := rng.randf_range(min_scale, max_scale)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		keep.append(Transform3D(b, Vector3(x, h - sink, z)))
	transforms.list = keep


## The stepping-stone path from the torii to the hokora (world space) and the yard around the hokora stay clear.
static func _near_shrine_path(x: float, z: float) -> bool:
	var a := Vector2(Overworld.SHRINE_C.x, Overworld.SHRINE_C.z + 16.0)    # the torii
	var b := Vector2(Overworld.SHRINE_C.x - 9.0, Overworld.SHRINE_C.z - 14.0)  # the hokora
	var p := Vector2(x, z)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) < 4.5 or p.distance_to(b) < 6.0
