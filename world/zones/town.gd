class_name Town
extends Zone
## The coastal town: a plaza, streets, an overlook above the sea, villagers going about their day. The food shop,
## item shop and Trainers' Association are rooms you walk into (world/interior.gd). Goro the carpenter works
## outside. The road north leads home. Shop / Association menus are static so the rooms can use them too.

const RANCH := "res://world/zones/ranch_v2.tscn"
const ROOM := "res://world/zones/interior.tscn"
const SHOW_PLACEHOLDER_NPCS := false   # Lookout Juno is still a plain cone body; true brings him back


func zone_id() -> String:
	return "town"


func entries() -> Dictionary:
	var e := {"start": [TownLayout.C + Vector3(0, 0, -6), 0.0], "north": [Vector3(7.5, 0, 54), 0.0]}
	for k in ["food_shop", "item_shop", "association"]:  # stepping back out of a room
		var b: Array = TownLayout.buildings()[k]
		e[k + "_door"] = [TownLayout.door(k), deg_to_rad(float(b[1])) + PI]
	return e


func setup() -> void:
	add_exit(Vector3(5, 0, 42.8), 0.0, RANCH, "south", "Home to the ranch", Vector2(10.0, 1.6))  # where the road meets the border
	for k in ["food_shop", "item_shop", "association"]:  # doors into the rooms
		var b: Array = TownLayout.buildings()[k]
		var yaw := deg_to_rad(float(b[1]))
		var at: Vector3 = (b[0] as Vector3) + Vector3(-sin(yaw), 0, -cos(yaw)) * (float(b[4]) / 2.0 + 0.5)
		exits.append({"pos": at, "r": 0.9, "scene": ROOM, "entry": "start", "label": k, "params": {"room": k}})
	var c := TownLayout.C
	add_npc(Npc.make("Goro, carpenter", TownLayout.door("workshop"), ["Need more room out on that cliff ranch? I build stables, yards, storehouses.",
		"Pay up front and it'll be standing when you get home."], {"robe": Color(0.55, 0.4, 0.25), "hair": Color(0.3, 0.2, 0.12),
		"model": "npc_carpenter"}, func(): Town.builder(self)))
	add_npc(Npc.make("Old Genny", c + Vector3(3.0, 0, -2.0), ["So you're the one living out on the cliff ranch, {you}.",
		"Everything that serves long enough grows a soul. Machines too. Most folk forget that.",
		"Your machine's kami is waiting at the shrine on the hill. Out your north gate and up.",
		"Feed it, train it, bring it to the Association when it's ready to prove itself."],
		{"robe": Color(0.5, 0.45, 0.35), "hair": Color(0.9, 0.9, 0.9), "model": "trainer_f"}))   # the female model stands in until she has her own
	if SHOW_PLACEHOLDER_NPCS:
		add_npc(Npc.make("Lookout Juno", TownLayout.PIER_END + Vector3(-1.0, 0.2, 0), ["Best view in town. On a clear day you can see the lighthouse lamp turn.",
			"They say the old lamp's kami is the oldest on this coast."], {"robe": Color(0.25, 0.35, 0.5), "hair": Color(0.2, 0.15, 0.1)}))


# ---------------------------------------------------------------- services (static: used here and in the rooms)

static func builder(z: Zone) -> void:
	var opts: Array = []
	for k in RanchLayout.ADDITIONS:
		if k in Game.ranch_upgrades:
			continue
		var a: Array = RanchLayout.ADDITIONS[k]
		opts.append([("%s  %d G" % [a[1], a[0]]).to_upper(), a[2], func():
			if not Game.spend(int(a[0])):
				z.toast("Not enough money.")
				return
			Game.ranch_upgrades.append(k)
			Sound.sfx("coin", -8.0)
			Save.write()
			z.close_menu()
			z.say("Goro, carpenter", ["Done deal. Your %s will be standing when you get home." % str(a[1]).to_lower()])])
	if opts.is_empty():
		z.say("Goro, carpenter", ["Your ranch has everything I build. Fine work, if I say so myself."])
		return
	opts.append(["LEAVE", "", z.close_menu])
	z.show_menu("GORO'S BUILDS     %d G" % Game.money, opts)


static func shop(z: Zone, food: bool, title: String) -> void:
	var opts: Array = []
	for it in ItemDef.all():
		if it.food != food:
			continue
		opts.append([("%s  %d G" % [it.display_name, it.cost]).to_upper(), "have %d" % int(Game.inventory.get(str(it.id), 0)), func():
			if not Game.spend(it.cost):
				z.toast("Not enough money.")
				return
			Game.add_item(str(it.id), 1)
			Sound.sfx("coin", -8.0)
			Save.write()
			z.toast("Bought %s." % it.display_name)
			Town.shop(z, food, title)])
	opts.append(["LEAVE", "", z.close_menu])
	z.show_menu("%s     %d G" % [title.to_upper(), Game.money], opts)


static func association(z: Zone) -> void:
	if Game.monsters.is_empty():
		z.say("Clerk Hana", ["You'll need a kami first. The shrine on the hill is where trainers call theirs."])
		return
	var opts: Array = [["ABOUT EVENTS", "", func(): z.say("Clerk Hana", ["Cups run all year: check the event calendar at your house when you plan the week.",
		"Once a year, in Late Summer, each rank holds its Promotion Match. A kami needs three cup wins at its rank to enter.",
		"Win it and your kami moves up a rank. Few kami live long enough to reach S without help.",
		"Adventures leave from home too: set out at the weekend."])]]
	if not Game.entries.is_empty():
		var lines: Array = []
		for en in Game.entries:
			lines.append("%s: %s (%s)" % [Zone.calendar_of(int(en["week"])), en["name"], en["monster"]])
		opts.insert(0, ["YOUR ENTRIES (%d)" % Game.entries.size(), "", func(): z.say("Clerk Hana", lines)])
	opts.append(["LEAVE", "", z.close_menu])
	z.show_menu("TRAINERS' ASSOCIATION", opts)  # sign-ups and departures happen at your house


## (Kept for dev tests: an immediate cup without the calendar.)
static func cups(z: Zone) -> void:
	var m: MonsterData = Game.monsters[0]
	var opts: Array = []
	for c in CupDef.all():
		if Care.RANKS.find(c.rank) <= Care.RANKS.find(m.rank):
			opts.append([("Rank %s  %s" % [c.rank, c.display_name]).to_upper(), "entry %d G  ·  prize %d G" % [c.entry_fee, c.prize], func():
				if not Game.spend(c.entry_fee):
					z.toast("Entry costs %d G." % c.entry_fee)
					return
				Save.write()
				Scenes.goto("res://combat/arena.tscn", {"player": m, "foes": c.make_foes(Game.week), "skill": c.ai_skill,
					"title": "Rank %s  %s" % [c.rank, c.display_name], "return_to": RANCH, "cup": c.id, "fighter": m.name})])
	opts.append(["BACK", "", func(): Town.association(z)])
	z.show_menu("%s ENTERS... (rank %s)" % [m.name.to_upper(), m.rank], opts)


## Pick up to three kami for the adventure (tick them), then the dungeon.
static func dungeons(z: Zone, picked: Array = []) -> void:
	if picked.is_empty() and Game.monsters.size() <= 3:
		for i in Game.monsters.size():
			picked.append(i)
	var opts: Array = []
	for i in Game.monsters.size():
		var m: MonsterData = Game.monsters[i]
		var on := i in picked
		opts.append([("[x]  " if on else "[  ]  ") + m.name.to_upper(), "rank %s  ·  %s" % [m.rank, Care.fatigue_word(m.fatigue)], func():
			var nxt := picked.duplicate()
			if on:
				nxt.erase(i)
			elif nxt.size() < 3:
				nxt.append(i)
			else:
				z.toast("Three kami at most.")
			Town.dungeons(z, nxt)])
	if not picked.is_empty():
		opts.append(["CHOOSE A DUNGEON", "Team of %d." % picked.size(), func(): Town._dungeon_pick(z, picked)])
	opts.append(["BACK", "", z.close_menu])
	z.show_menu("WHO GOES ON THE ADVENTURE? (UP TO 3)", opts)


static func _dungeon_pick(z: Zone, team: Array) -> void:
	var opts: Array = []
	for d in Adventure.dungeon_choices():
		opts.append([str(d[1]), str(d[2]), func():
			Save.write()
			Scenes.goto("res://explore/dungeon.tscn", {"team": team, "dungeon": str(d[0]).substr(8)})])
	opts.append(["BACK", "", func(): Town.dungeons(z, team)])
	z.show_menu("WHICH DUNGEON?     TRAINER RANK %s" % Game.trainer_rank(), opts)
