extends Node3D
## M1 check (F6): summons this machine's kami, prints it, checks determinism and that every
## breed can be summoned, then shows the model.


func _ready() -> void:
	var m := Summoner.summon_machine()
	print("MACHINE  ", m.describe())
	var a := Summoner.summon_text("hello")
	var b := Summoner.summon_text("hello")
	print("TEXT     ", a.describe())
	print("deterministic: ", a.seed_hex == b.seed_hex and a.stats == b.stats and a.sub_breed == b.sub_breed)

	var mains := {}
	var subs := {}
	var pure := 0
	for i in 3000:
		var x := Summoner.summon_text("probe %d" % i)
		mains[x.main_breed] = int(mains.get(x.main_breed, 0)) + 1
		subs[x.sub_breed] = int(subs.get(x.sub_breed, 0)) + 1
		if x.is_pure():
			pure += 1
		assert(x.total() == Summoner.STAT_BUDGET)
	print("breeds reachable as main: %d / %d, as sub: %d, pure breeds: %d / 3000" % [mains.size(), SpeciesDB.all().size(), subs.size(), pure])
	print("main counts: ", mains)

	_show(m)


func _show(m: MonsterData) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UIStyle.BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var model := MonsterModel.create(m.model_dict())
	model.rotation_degrees.y = 25.0
	add_child(model)
	var lbl := Label3D.new()
	lbl.text = "%s\n%s  //  %s" % [m.breed_label().to_upper(), m.type.to_upper(), m.main_def().body_class.to_upper()]
	lbl.font = UIStyle.font("display")
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, -0.4, 1.0)
	add_child(lbl)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0, 2.4, 6.5)
	cam.look_at(Vector3(0, 1.0, 0))
