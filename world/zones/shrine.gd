extends Zone
## The shrine on the headland: call out your machine's kami (SummonRitual), wake a summoning stone found on
## adventures, or combine two of your kami. The shrine keeper explains. The road back leads to the ranch.

const RANCH := "res://world/zones/ranch_v2.tscn"
const BODY := preload("res://monsters/monster_body.tscn")


func zone_id() -> String:
	return "shrine"


func entries() -> Dictionary:
	var hk := hokora()
	return {"start": [Vector3(6, 0, -30), 2.0], "south": [Vector3(6, 0, -30), 2.0],
		"hokora": [hk + (Overworld.SHRINE_C - hk).normalized() * 3.0, 0.0]}


static func hokora() -> Vector3:
	return Overworld.SHRINE_C + KamiLayout.SHRINE.rotated(Vector3.UP, PI)


func setup() -> void:
	if Scenes.params.has("combine_child"):   # sent here by the Association: the combined kami is called at the hokora
		var child := MonsterData.from_dict(Scenes.params["combine_child"])
		Scenes.params.erase("combine_child")
		_summon.call_deferred(child)
	add_exit(Vector3(2, 0, -22.8), 0.0, RANCH, "north", "Back to the ranch", Vector2(9.0, 1.6))  # where the road meets the border
	add_spot(hokora(), 4.5, "The hokora", _hokora_menu)
	var keeper_pos := Overworld.SHRINE_C + Vector3(-3, 0, 12)
	add_npc(Npc.make("Old Tobin, shrine keeper", keeper_pos, ["The kami here are old. Lanterns, tools, machines that served too long to stay asleep.",
		"Kneel at the hokora and your own machine's kami may answer, {you}. Each machine answers only once.",
		"Stones from the deep places hold kami too. And two kami can become one, if you can bear to part with them."],
		{"robe": Color(0.95, 0.95, 0.92), "hair": Color(0.15, 0.1, 0.1), "model": "npc_tobin"}))
	if "testsummon" in OS.get_cmdline_user_args():  # dev: run the ritual unattended for a render
		get_tree().create_timer(0.5).timeout.connect(_summon)
		get_tree().create_timer(15.0).timeout.connect(func():
			for r in find_children("*", "SummonRitual", false, false):
				if r.name_box != null:
					r.name_box.text_submitted.emit(r.name_box.text))


func _hokora_menu() -> void:
	var stones := int(Game.inventory.get("stone", 0))
	var opts: Array = [["CALL OUT YOUR MACHINE'S KAMI", "The heart of the shrine.", _summon]]
	if stones > 0:
		opts.append(["WAKE A SUMMONING STONE", "You have %d." % stones, _stone])
	if Game.monsters.size() >= 2:
		opts.append(["COMBINE TWO KAMI", "Two of yours become one new kami.", _combine_pick.bind(-1)])
	opts.append(["LEAVE", "", close_menu])
	show_menu("THE HOKORA", opts)


func _summon(chip: MonsterData = null) -> void:
	close_menu()
	var why := "" if chip != null else SummonRitual.blocked()
	if chip != null and Game.monsters.size() >= RanchLayout.capacity():
		why = "There's no room at your ranch for another kami.\nBuild a stable first."
	if why != "":
		toast(why)
		return
	trainer.frozen = true
	hud_layer.visible = false
	var r := SummonRitual.new()
	add_child(r)
	var hk := hokora()
	r.start(hk, hk + (Overworld.SHRINE_C - hk).normalized() * 4.0, chip)
	r.finished.connect(func(m: MonsterData) -> void:
		hud_layer.visible = true
		free_trainer()
		cam.cam.make_current()
		if m != null:
			toast("%s is waiting for you at the ranch." % m.name))


func _stone() -> void:
	Game.add_item("stone", -1)
	var chip := Summoner.summon_text("stone %d %d" % [Game.week, Game.summoned.size()])
	chip.source = "stone"
	_summon(chip)


func _combine_pick(first: int) -> void:
	var opts: Array = []
	for i in Game.monsters.size():
		if i == first:
			continue
		var m: MonsterData = Game.monsters[i]
		opts.append([m.name.to_upper(), "%s  rank %s" % [m.breed_label(), m.rank], func():
			if first < 0:
				_combine_pick(i)
			else:
				_combine(first, i)])
	opts.append(["BACK", "", _hokora_menu])
	show_menu("COMBINE: %s" % ("FIRST KAMI" if first < 0 else "SECOND KAMI"), opts)


func _combine(a: int, b: int) -> void:
	var ma: MonsterData = Game.monsters[a]
	var mb: MonsterData = Game.monsters[b]
	var child := Summoner.combine(ma, mb)
	Game.retire(ma, "combined")
	Game.retire(mb, "combined")
	_summon(child)
