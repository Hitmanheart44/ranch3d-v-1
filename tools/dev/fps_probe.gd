extends Node
## Dev: average FPS of a zone after warm-up. Software GL (no GPU) approximates a weak PC:
##   LIBGL_ALWAYS_SOFTWARE=1 godot --path . res://tools/dev/fps_probe.tscn -- <scene> <quality 0-2>
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var scene: String = a[0] if a.size() > 0 else "res://world/zones/ranch_v2.tscn"
	Quality.level = int(a[1]) if a.size() > 1 else 0
	Quality.apply()
	Game.monsters = [Summoner.summon_text("a"), Summoner.summon_text("b")]
	Game.planned_week = Game.week
	Game.trained_week = Game.week
	var t_load := Time.get_ticks_msec()
	add_child((load(scene) as PackedScene).instantiate())
	print("LOAD_MS ", Time.get_ticks_msec() - t_load)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(3.0).timeout
	for cls in (a[2].split(",") if a.size() > 2 else []):   # e.g. hide=MultiMeshInstance3D,Terrain3D (profiling: what costs the most)
		for n in get_tree().root.find_children("*", cls, true, false):
			n.visible = false
			if a.size() > 3 and a[3] == "free":
				n.queue_free()
	await get_tree().create_timer(3.0).timeout
	var n := 0
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_frames_drawn()
	await get_tree().create_timer(8.0).timeout
	print("FPS ", scene.get_file(), " quality ", Quality.NAMES[Quality.level], ": ", snappedf((Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - t0), 0.1), "  adapter: ", RenderingServer.get_video_adapter_name())
	print("DRAWS ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  PRIMS ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "  OBJECTS ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "  proc_ms ", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), "  TEXMEM_MB ", snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1), "  phys_ms ", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1))
	get_tree().quit()
