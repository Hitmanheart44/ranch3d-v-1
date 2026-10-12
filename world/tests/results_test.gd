extends Node
## Dev (headless-safe): runs a training week on the ranch and builds the results screen. Uses the test save only.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.new_game(Summoner.summon_machine())
	Game.add_monster(Summoner.summon_text("second kami"))
	Game.trainer = "f"
	Game.intro_seen = true
	Game.set_meta("started", true)
	Game.set_meta("loaded", true)
	Game.planned_week = 0   # the planner opens by itself, as in a real week
	Game.ap = Care.action_points()
	Game.monsters[0].schedule = ["weights:1"]
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "start"})
	await get_tree().create_timer(3.0).timeout
	var z = get_tree().current_scene
	var pl: WeekPlanner = null
	for c in z.hud_root.get_children():
		if c is WeekPlanner:
			pl = c
	print("PATH planner open=", pl != null, " in_menu=", z.in_menu, " cam target=", z.cam.target.name)
	var before_pos := []
	for b in z.bodies:
		before_pos.append(b.global_position)
	var t0: Node3D = z.cam.target
	print("PATH kami at fixed spots: ", before_pos.size(), "  apart by ", snappedf((before_pos[0] as Vector3).distance_to(before_pos[1]), 0.1), " m  wandering stopped=", pl._paused.size() >= 2)
	pl._switch(1)   # a switch fades like every other view change
	await get_tree().create_timer(0.3).timeout
	print("PATH switching: selected still ", pl._selected, " (changes under the black)")
	await get_tree().create_timer(1.4).timeout
	var moved := 0
	for i in z.bodies.size():
		if (before_pos[i] as Vector3).distance_to(z.bodies[i].global_position) > 0.05:
			moved += 1
	print("PATH switched: selected ", pl._selected, "  camera moved to another kami=", z.cam.target != t0, "  kami that moved=", moved)
	await get_tree().create_timer(1.0).timeout   # let the camera settle on the new kami
	var vp := z.get_viewport().get_visible_rect()
	for i in z.bodies.size():
		var mid: Vector3 = z.bodies[i].global_position + Vector3(0, 1.0, 0)
		var scr: Vector2 = z.cam.cam.unproject_position(mid)
		var visible_now: bool = (not z.cam.cam.is_position_behind(mid)) and vp.has_point(scr)
		print("PATH kami ", i, " in frame=", visible_now, "  (selected=", i == pl._selected, ")  screen x=", snappedf(scr.x / vp.size.x, 0.01))
	pl._switch(-1)
	await get_tree().create_timer(1.6).timeout
	print("PATH switched back: selected ", pl._selected)
	pl._leave()   # START THE WEEK: fade out, then the results come up over the trainer's view
	await get_tree().create_timer(0.2).timeout
	print("PATH mid-fade: screen going black, planner still there=", is_instance_valid(pl) and not pl.is_queued_for_deletion())
	await get_tree().create_timer(2.6).timeout
	var res: WeekPlanner = null
	for c in z.hud_root.get_children():
		if c is WeekPlanner and not c.is_queued_for_deletion():
			res = c
	print("PATH results shown=", res != null, " page=", res._page if res else "-", " in_menu=", z.in_menu)
	if res != null:
		var shown: MonsterBody = res._showcase
		var posed := 0
		for b in z.bodies:
			if b.in_place > 0.0:
				posed += 1
		print("PATH results: camera on the group overview=", z.cam.target == res._focus and res._focus != null, "  kami drilling in place=", posed, "/", z.bodies.size(),
			"  overlay alpha=", snappedf(res.modulate.a, 0.01), "  camera distance=", snappedf(z.cam.distance, 0.1), "  trainer frozen=", z.trainer.frozen)
		var facing := 0
		for b in z.bodies:
			var to_cam: Vector3 = z.cam.cam.global_position - b.global_position
			to_cam.y = 0.0
			if to_cam.normalized().dot(b.face_dir) > 0.95:
				facing += 1
		print("PATH kami facing the camera: ", facing, "/", z.bodies.size())
		var y0: float = z.cam.yaw
		await get_tree().create_timer(2.0).timeout
		print("PATH camera holds still: yaw changed by ", snappedf(z.cam.yaw - y0, 0.001))
	if res != null:
		res._switch(1)
		await get_tree().create_timer(0.3).timeout
		res._close_results()   # CONTINUE: fade out, back to the trainer, fade in
	await get_tree().create_timer(2.2).timeout
	print("PATH after CONTINUE: in_menu=", z.in_menu, " trainer frozen=", z.trainer.frozen, " cam target is trainer=", z.cam.target == z.trainer,
		" ui_open=", z.cam.ui_open, " frame_offset=", z.cam.frame_offset, " distance=", z.cam.distance)
	var p0: Vector3 = z.trainer.global_position
	for i in 60:
		z.trainer.velocity = Vector3(4.0, z.trainer.velocity.y - 0.3, 0)
		z.trainer.move_and_slide()
		await get_tree().physics_frame
	print("PATH trainer can walk: moved ", snappedf(p0.distance_to(z.trainer.global_position), 0.1), " m")
	var roamers := 0
	for b in z.bodies:
		var q: Vector3 = b.global_position
		await get_tree().create_timer(3.0).timeout
		if q.distance_to(b.global_position) > 0.5:
			roamers += 1
		break
	print("PATH kami roaming again: ", roamers > 0)
	get_tree().quit()
