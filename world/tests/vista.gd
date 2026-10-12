extends Node
## Dev: screenshots from each zone toward the others (distant scenery, seams, pop-in). Run WITH graphics:
##   godot --path . res://world/tests/vista.tscn      -> ~/.cache/ranch3d_tmp/vista/NN_name.png

const OUT := "/home/hitmanheart/.cache/ranch3d_tmp/vista/"
var VIEWS := [  # scene, entry, name, camera position, look-at
	["res://world/zones/shrine.tscn", "south", "lighthouse", Vector3(40, 14, -50), Vector3(95, -20, -30)],
	["res://world/zones/shrine.tscn", "south", "shrine_fence", Vector3(8, 9, -26), Vector3(18, 6, -37)],
	["res://world/zones/shrine.tscn", "south", "shrine_front", Vector3(14, 9, -50), Vector3(9, 7, -66)],
	["res://world/zones/shrine.tscn", "south", "shrine_wide", Vector3(34, 14, -40), Vector3(16, 6, -62)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_north_gate", Vector3(0, 3, -16), Vector3(0, 2, -30)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_west_gate", Vector3(-19, 4.5, -5), Vector3(-27, 2, 0)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_house", Vector3(-1, 4, 10), Vector3(-11, 1.5, 5)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_ramp", Vector3(-3, 2.2, 1), Vector3(-8, 1, 5)],
	["res://world/zones/shrine.tscn", "south", "shrine_to_ranch", Vector3(6, 9, -34), Vector3(0, 0, 0)],
	["res://world/zones/shrine.tscn", "south", "shrine_yard", Vector3(10, 10, -38), Vector3(18, 6, -56)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_to_shrine", Vector3(-2, 3, 8), Vector3(18, 6, -52)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_to_town", Vector3(0, 3, 18), Vector3(16, -6, 92)],
	["res://world/zones/ranch_v2.tscn", "start", "ranch_to_sea", Vector3(-6, 4, 0), Vector3(60, -10, 10)],
	["res://world/zones/town.tscn", "north", "town_top", Vector3(7, 4, 50), Vector3(24, -15, 115)],
	["res://world/zones/town.tscn", "start", "town_square", Vector3(16, -4, 84), Vector3(18, -9, 100)],
	["res://world/zones/town.tscn", "start", "goro", TownLayout.door("workshop") * 2.0 - (TownLayout.buildings()["workshop"][0] as Vector3) + Vector3(0, 1.8, 0), TownLayout.door("workshop") + Vector3(0, 0.9, 0)],
	["res://world/zones/town.tscn", "start", "harbor", Vector3(26, -18, 128), Vector3(42, -24, 142)],
	["res://world/zones/town.tscn", "start", "town_to_ranch", Vector3(24, -10, 125), Vector3(5, 0, 30)],
]
var n := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	var last := ""
	Game.planned_week = Game.week  # no start-of-week planner over the shots
	Game.trained_week = Game.week
	for v in VIEWS:
		if v[0] != last:
			Scenes.goto(v[0], {"entry": v[1]})
			await get_tree().create_timer(3.0).timeout
			last = v[0]
		var cam := Camera3D.new()
		cam.fov = 70.0
		cam.far = 2000.0
		get_tree().current_scene.add_child(cam)
		cam.look_at_from_position(v[3], v[4])
		cam.make_current()
		for i in 3:
			await RenderingServer.frame_post_draw
		n += 1
		get_viewport().get_texture().get_image().save_png(OUT + "%02d_%s.png" % [n, v[2]])
		print("VISTA ", v[2])
		cam.queue_free()
	get_tree().quit()
