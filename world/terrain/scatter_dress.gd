class_name ScatterDress
extends RefCounted
## Rocks, shrubs and ferns for a zone, placed by ProtonScatter (runtime-built: a random-inside-box create modifier,
## then ScatterRule for this game's ground). Scatter builds instanced, LOD'd multimeshes; the scene tree only holds
## a few nodes. Add a kind of clutter = add a row to SETS.

const SCATTER := preload("res://addons/proton_scatter/src/scatter.gd")
const ITEM := preload("res://addons/proton_scatter/src/scatter_item.gd")
const SHAPE := preload("res://addons/proton_scatter/src/scatter_shape.gd")
const STACK := preload("res://addons/proton_scatter/src/stack/modifier_stack.gd")
const CREATE := preload("res://addons/proton_scatter/src/modifiers/create_inside_random.gd")
const RULE := preload("res://world/terrain/scatter_rule.gd")

## [name, [glb names in assets/props/ph], count per 10 000 m2, model scale, rule overrides]
const SETS := [
	["boulders", ["boulder_01", "rock_07", "rock_09"], 8, 0.7, {"min_slope": 0.25, "cliff_margin": -1.0, "min_ranch_dist": 31.0, "max_scale": 1.8}],
	["stones", ["stone_01", "rock_moss_set_01", "rock_moss_set_02"], 20, 0.6, {"min_ranch_dist": 31.0, "max_slope": 0.8, "max_scale": 1.0}],
	["shrubs", ["fern_02"], 40, 1.0, {"max_slope": 0.7, "min_ranch_dist": 29.0}],
	["ferns", ["fern_02"], 80, 1.0, {"max_slope": 0.6, "min_ranch_dist": 27.0}],
	# the shrine plateau: a ring of shrubs, ferns and mossy stones around the yard, the path and the hokora left clear
	["grove_ferns", ["fern_02"], 220, 1.4, {"shrine_ring": Vector2(8, 24), "max_slope": 0.8, "min_scale": 0.9, "max_scale": 1.5, "cliff_margin": 1.0}],
	["grove_stones", ["rock_moss_set_01", "rock_moss_set_02", "stone_01"], 40, 0.55, {"shrine_ring": Vector2(10, 24), "max_slope": 0.9, "cliff_margin": 0.0}],
]


static func build(parent: Node3D, ov: Overworld) -> void:
	if Quality.level == 0:   # the scanned rocks and ferns are 6-26k triangles each: not on the weakest tier
		return
	RULE.ov = ov
	var reg := ov.region
	var area := reg.size.x * reg.size.y / 10000.0
	for i in SETS.size():
		var set: Array = SETS[i]
		var sc := SCATTER.new()
		sc.name = "Scatter_" + set[0]
		sc.global_seed = 100 + i
		sc.dbg_disable_thread = true       # build on the spot: the rules read plain data and the counts are small
		sc.force_rebuild_on_load = true
		var create := CREATE.new()
		create.amount = int(set[2] * area * Quality.density())
		var rule := RULE.new()
		for k in set[4]:
			rule.set(k, set[4][k])
		var stack := STACK.new()
		stack.stack = [create, rule]
		sc.modifier_stack = stack
		parent.add_child(sc)
		for g in set[1]:
			var it := ITEM.new()
			it.name = g
			it.source = 1
			it.source_scale_multiplier = set[3]
			it.visibility_range_end = 90.0
			it.visibility_range_end_margin = 15.0
			it.visibility_range_fade_mode = 1
			it.override_cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			it.path = "res://assets/props/ph/%s.glb" % g
			sc.add_child(it)
		var shape := SHAPE.new()
		var box := ProtonScatterBoxShape.new()
		box.size = Vector3(reg.size.x, 2.0, reg.size.y)
		shape.shape = box
		shape.position = Vector3(reg.get_center().x, 0.0, reg.get_center().y)
		sc.add_child(shape)
