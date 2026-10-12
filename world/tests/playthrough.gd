extends Node
## Dev: plays a fresh save through the whole loop and saves screenshots at each step (run WITH graphics).
##   godot --path . res://world/tests/playthrough.tscn -- noskip     -> ~/.cache/ranch3d_tmp/play/NN_name.png

const OUT := "/home/hitmanheart/.cache/ranch3d_tmp/play/"
var n := 0


func _ready() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	get_viewport().get_texture().get_image().save_png(OUT + "%02d_%s.png" % [n, name])
	print("SHOT ", n, " ", name)


func scene() -> Node:
	return get_tree().current_scene


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func go(path: String, params: Dictionary = {}) -> void:
	Scenes.goto(path, params)
	await wait(2.0)


func walk_to(z: Node, target: Vector3, secs := 6.0) -> void:  # steer the trainer like a player would
	var t := 0.0
	while t < secs and is_instance_valid(z) and z.is_inside_tree():  # stops when a loading zone takes us away
		var d: Vector3 = target - z.trainer.global_position
		d.y = 0
		if d.length() < 1.0:
			break
		z.trainer.velocity = Vector3(d.normalized().x * 7.0, z.trainer.velocity.y - 0.3, d.normalized().z * 7.0)
		z.trainer.move_and_slide()
		z.trainer.model.rotation.y = atan2(d.x, d.z)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Save.delete()
	Game.new_game()
	Game.ap = Care.action_points()
	Save.write()
	Game.set_meta("started", true)
	await go("res://world/flow/intro.tscn")
	await wait(2.0)
	await shot("intro")
	scene()._finish()
	await wait(2.5)
	await shot("creator")
	scene()._begin()
	await wait(4.0)
	var z = scene()
	await shot("ranch_arrival")
	await walk_to(z, Vector3(0, 0, -28), 9.0)
	await wait(3.0)
	z = scene()
	await shot("shrine_arrival")
	await walk_to(z, z.hokora() + (Overworld.SHRINE_C - z.hokora()).normalized() * 3.0, 10.0)
	await wait(0.5)
	await shot("at_hokora")
	z._summon()
	await wait(7.0)
	await shot("ritual_readout")
	await wait(4.5)
	await shot("ritual_emerge")
	await wait(4.0)
	for r in z.find_children("*", "SummonRitual", false, false):
		if r.name_box != null:
			r.name_box.text_submitted.emit(r.name_box.text)
	await wait(3.0)
	await go("res://world/zones/ranch_v2.tscn", {"entry": "north"})
	z = scene()
	await wait(1.5)
	await shot("ranch_with_monster")
	if not z.bodies.is_empty():
		z.trainer.global_position = z.bodies[0].global_position + Vector3(0, 0, -2.0)
		z._open(z.bodies[0])
		await wait(0.5)
		await shot("monster_menu")
		z._feed()
		await wait(0.5)
		await shot("fed")
		z.close_menu()
	z._house_menu()
	await wait(0.4)
	await shot("house_menu")
	z._plan(Game.monsters[0])
	await wait(0.4)
	await shot("plan_menu")
	z.close_menu()
	Game.monsters[0].schedule = ["weights:1"]
	z.end_week([], "THE WEEK")
	await wait(3.5)
	z = scene()
	await shot("next_morning")
	await walk_to(z, Vector3(0, 0, 28), 10.0)
	await wait(3.0)
	z = scene()
	await shot("town_arrival")
	await walk_to(z, TownLayout.C + Vector3(0, 0, -3), 8.0)
	await shot("plaza")
	for npc in z.npcs:
		if npc.npc_name == "Old Gen":
			z.say(npc.npc_name, npc.lines)
	await wait(0.4)
	await shot("dialogue")
	z.dialog_box.visible = false
	Town.builder(z)
	await wait(0.4)
	await shot("carpenter")
	z.close_menu()
	await walk_to(z, TownLayout.QUAY, 10.0)
	await shot("harbor")
	for room in ["food_shop", "association"]:
		await go("res://world/zones/interior.tscn", {"room": room, "entry": "start"})
		z = scene()
		await wait(1.0)
		await shot(room)
		if room == "association":
			Town.association(z)
			await wait(0.4)
			await shot("association_menu")
			z.close_menu()
	var c: CupDef = CupDef.all()[0]
	await go("res://combat/arena.tscn", {"player": Game.monsters[0], "foes": c.make_foes(Game.week), "skill": c.ai_skill,
		"title": "Rank %s  %s" % [c.rank, c.display_name], "return_to": "res://world/zones/ranch_v2.tscn", "cup": c.id, "fighter": Game.monsters[0].name})
	await wait(3.0)
	await shot("arena")
	print("PLAYTHROUGH DONE")
	get_tree().quit()
