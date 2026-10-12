extends Node
func _ready():
	Quality.level = 0
	Game.monsters = [Summoner.summon_text("a"), Summoner.summon_text("b")]
	Game.planned_week = Game.week
	Game.trained_week = Game.week
	add_child((load("res://world/zones/ranch_v2.tscn") as PackedScene).instantiate())
	await get_tree().create_timer(3.0).timeout
	var rows := []
	for n in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		var t := 0
		var cnt := 1
		if n is MeshInstance3D and n.mesh != null:
			for i in n.mesh.get_surface_count():
				var arr = n.mesh.surface_get_arrays(i)
				t += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		elif n is MultiMeshInstance3D and n.multimesh != null and n.multimesh.mesh != null:
			cnt = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
			for i in n.multimesh.mesh.get_surface_count():
				var arr = n.multimesh.mesh.surface_get_arrays(i)
				t += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		else:
			continue
		rows.append([t * cnt, cnt, str(n.get_path()).right(60)])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 14):
		print("TRI ", r[0], " x", r[1], " ", r[2])
	get_tree().quit()
