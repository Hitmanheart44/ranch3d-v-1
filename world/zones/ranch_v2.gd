extends Zone
## The ranch zone. Your kami live here; your house is where the week happens:
##   your kami  [E] feed / praise / scold / pet (action points)
##   house door    [E] plan training, end the week, ranch additions
##   north road -> the shrine (summoning)     south road -> the town (shops, Association: events, rank-ups)

const BODY := preload("res://monsters/monster_body.tscn")
const SELF := "res://world/zones/ranch_v2.tscn"

var bodies: Array[MonsterBody] = []
var talking: MonsterBody


func zone_id() -> String:
	return "ranch"


func entries() -> Dictionary:
	return {"start": [Vector3(0, 0, -6), 0.0], "north": [Vector3(0, 0, -10), 0.0], "south": [Vector3(0, 0, 18), PI],
		"house": [house_door() + Vector3(4.5, 0, -1.0), PI / 2]}


func _pre_ready() -> bool:
	if not Game.has_meta("started"):
		Game.set_meta("started", true)
		if not (Save.exists() and Save.read()):
			Game.new_game()  # v2: no kami at the start; the intro plays, then you summon at the shrine
			Game.ap = Care.action_points()
			Save.write()
	if not Game.intro_seen and not "nointro" in OS.get_cmdline_user_args():
		Scenes.goto.call_deferred("res://world/flow/intro.tscn")
		return false
	if Game.trainer == "" and not "nointro" in OS.get_cmdline_user_args():
		Scenes.goto.call_deferred("res://world/flow/creator.tscn")
		return false
	if Game.inventory.is_empty() and Game.week == 1:
		Game.add_item("berries", 3)
		Game.add_item("meat", 1)
	return true


func setup() -> void:
	for i in Game.monsters.size():
		_spawn(Game.monsters[i], i)
	if "showcase" in OS.get_cmdline_user_args():  # dev: every finished model out roaming the yard
		_showcase()
	add_spot(house_door(), 3.0, "Your house", _house_menu)
	# the only ways out are the two gaps in the stone wall; step into a gap and you're on your way
	add_exit(Vector3(0, 0, -28.0), 0.0, "res://world/zones/shrine.tscn", "south", "To the shrine", Vector2(6.4, 1.6))
	add_exit(Vector3(0, 0, 28.0), 0.0, "res://world/zones/town.tscn", "north", "To town", Vector2(6.4, 1.6))
	_south_gate()
	RanchLayout.gate_arch(self, Vector3(-RanchLayout.WALL_R, 0, 0), PI * 0.5)  # the mountain trail: an adventure, any day of the week
	add_trail(Vector3(-RanchLayout.WALL_R, 0, 0), Vector3.RIGHT, "To the mountain trail (adventure)", Vector2(1.6, 6.4), _adventure_gate)
	_returns()
	if Scenes.params.get("weekend", false):
		Scenes.params.erase("weekend")
		_house_menu.call_deferred()
	if Scenes.params.get("train", false):   # the home menu's START THE WEEK: the drills run now
		Scenes.params.erase("train")
		run_training.call_deferred()
	elif not Game.monsters.is_empty() and Game.planned_week != Game.week and not Scenes.params.has("cup_result") \
			and not Scenes.params.has("adventure_result") and not Scenes.params.has("morning"):
		_open_planner.call_deferred()   # every week starts with the planner over the ranch: the camera shows the kami you pick
	if "testsummon" in OS.get_cmdline_user_args():  # dev: go do the ritual
		Scenes.goto.call_deferred("res://world/zones/shrine.tscn", {"entry": "hokora"})


func house_door() -> Vector3:
	var s: Array = RanchLayout.SITES["house"]
	var yaw := deg_to_rad(float(s[2]))
	return (s[1] as Vector3) + Vector3(-sin(yaw), 0, -cos(yaw)) * 8.8  # the foot of the ramp up to the deck


func _adventure_gate() -> void:
	if Game.monsters.is_empty():
		toast("You need a kami to take on the trail.")
		return
	Town.dungeons(self)


func _south_gate() -> void:  # matches the north gate: the road to town
	RanchLayout.gate_arch(self, Vector3(0, 0, RanchLayout.WALL_R))


func _showcase() -> void:
	var breeds := ["vexa", "nysse", "plant", "prismoid"]
	for i in breeds.size():
		var m := Summoner.summon_text("showcase " + breeds[i])
		var sd := SpeciesDB.get_def(StringName(breeds[i]))
		m.main_breed = StringName(breeds[i])
		m.sub_breed = StringName(breeds[i])
		m.name = sd.display_name if sd != null else breeds[i].capitalize()
		if sd != null:
			m.type = sd.type
		var b := BODY.instantiate() as MonsterBody
		b.data = m
		b.position = Vector3(-4.0 + i * 3.0, 0.3, 6.0)
		var w := WanderController.new()
		w.radius = 9.0
		b.add_child(w)
		add_child(b)
	add_npc(Npc.make("Goro, carpenter", Vector3(4, 0, 8), ["Came by to look at the land. Plenty of room for a stable out here."],
		{"robe": Color(0.55, 0.4, 0.25), "model": "npc_carpenter"}, Callable(), 6.0))


func _spawn(m: MonsterData, i: int) -> void:
	var b := BODY.instantiate() as MonsterBody
	b.data = m
	b.position = RanchLayout.home(i) + Vector3(0, 0.3, 0)
	var w := WanderController.new()
	w.radius = 6.0
	b.add_child(w)
	add_child(b)
	bodies.append(b)


# ---------------------------------------------------------------- kami (near-check + menu)

func _zone_prompt() -> void:
	var p := trainer.global_position
	var best := REACH
	var near: MonsterBody
	for b in bodies:
		var to := b.global_position - p
		to.y = 0
		if to.length() < best and to.normalized().dot(trainer.facing()) > 0.2:
			best = to.length()
			near = b
	if near != null and not current.has("npc"):
		current = {"monster": near}
		prompt.text = "[E]  %s" % near.data.name
		return
	super._zone_prompt()


func _process(delta: float) -> void:
	super._process(delta)
	if talking != null:
		talking.move_dir = Vector3.ZERO


func _interact_other() -> void:
	if current.has("monster"):
		_open(current["monster"])


func close_menu() -> void:
	super.close_menu()
	if talking != null:
		for c in talking.get_children():
			if c is WanderController:
				c.set_process(true)
				c.set_physics_process(true)
	talking = null
	if has_meta("planner"):  # a menu opened from the week planner closed: back to the planner
		(get_meta("planner") as WeekPlanner).resume()


func _open(b: MonsterBody) -> void:
	talking = b
	for c in b.get_children():
		if c is WanderController:
			c.set_process(false)
			c.set_physics_process(false)
	b.look_at(Vector3(trainer.global_position.x, b.global_position.y, trainer.global_position.z), Vector3.UP, true)
	_monster_menu(b.data)


func _monster_menu(m: MonsterData) -> void:
	show_menu("%s     Fatigue %s  ·  Stress %s  ·  %s" % [m.name.to_upper(), Care.fatigue_word(m.fatigue), Care.stress_word(m.stress),
		Care.fullness_word(m.fullness)], [["FEED", "1 AP", _feed], ["PRAISE", "1 AP", func(): _care(Care.praise(m, false))],
		["SCOLD", "1 AP", func(): _care(Care.praise(m, true))], ["PET", "1 AP", _pet]] + ([["GIVE KAMI ELIXIR", "+3 months of life (have %d)" % int(Game.inventory.get("longevity", 0)), func():
			Game.add_item("longevity", -1)
			m.life_lost -= 12.0
			Save.write()
			close_menu()
			toast("%s looks younger. About three more months of life." % m.name)]] if int(Game.inventory.get("longevity", 0)) > 0 else []) + [["LEAVE", "", close_menu]])


func _feed() -> void:
	var m: MonsterData = talking.data
	for it in ItemDef.all():
		if it.food and int(Game.inventory.get(str(it.id), 0)) > 0:
			if not spend_ap():
				return
			Game.inventory[str(it.id)] = int(Game.inventory[str(it.id)]) - 1
			_care(Care.feed(m, it))
			return
	toast("No food left. Buy some at the food shop in town.")


func _pet() -> void:
	if not spend_ap():
		return
	var m: MonsterData = talking.data
	m.bonding = mini(100, m.bonding + 1)
	m.stress = maxi(0, m.stress - 30)
	toast("%s leans into your hand. (Bonding +1, stress down)" % m.name)
	HitFx.burst(self, talking.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.6, 0.8), 12, 2.0)
	Save.write()
	_monster_menu(m)


func _care(lines: Array) -> void:
	toast("\n".join(lines))
	Save.write()
	_monster_menu(talking.data)


# ---------------------------------------------------------------- house

func _open_planner() -> void:
	await get_tree().process_frame   # still black: the scene's fade-in reveals the planner view, not a cut to it
	WeekPlanner.open(self)


func _weekend_menu() -> void:  # at the ranch the menu's weekend choices are the house's
	_house_menu()


func _house_menu() -> void:  # the weekend at home
	var opts: Array = []
	var en := Schedule.entry_now()
	if not en.is_empty():
		opts.append(["GO TO THE %s" % str(en["name"]).to_upper(), "%s competes." % en["monster"], func(): _go_to_cup(en)])
	opts.append(["GO ON AN ADVENTURE", "Take your team into a dungeon.", func(): Town.dungeons(self)])
	opts.append(["SKIP TO NEXT WEEK", "Use up your remaining %d AP and start a new week." % Game.ap, func(): end_week([], "A NEW WEEK")])
	opts.append(["LEAVE", "", close_menu])
	show_menu("THE WEEKEND", opts)


## Match day: the intro (a video when one exists), then the arena; the result comes back to _returns.
func _go_to_cup(en: Dictionary) -> void:
	close_menu()
	var m: MonsterData
	for b in Game.monsters:
		if b.name == en["monster"]:
			m = b
	var e := Schedule.find(str(en["event"]), int(en.get("month", Schedule.month_of(Game.week))))
	if m == null or e.is_empty():
		Game.entries.erase(en)
		toast("That entry is no longer valid.")
		return
	var cup: CupDef = e["cup"]
	Scenes.goto("res://world/flow/cup_intro.tscn", {"kind": e["kind"], "event": e["id"], "title": e["name"], "rank": e["rank"],
		"arena": {"player": m, "foes": cup.make_foes(Game.week), "skill": cup.ai_skill, "title": "Rank %s  %s" % [cup.rank, cup.display_name],
			"return_to": SELF, "cup": str(cup.id), "fighter": m.name, "event": e["id"], "kind": e["kind"]}})


func _after_plan() -> void:
	if has_meta("planner"):
		close_menu()
	else:
		_house_menu()


func _plan(m: MonsterData) -> void:
	var lv := 2 if "training" in Game.ranch_upgrades else 1  # the training yard unlocks harder drills
	var opts: Array = []
	for d in Training.all():
		opts.append([d.display_name.to_upper(), "%s  ·  Lv %d" % [str(d.stat).to_upper(), lv], func():
			m.schedule = ["%s:%d" % [d.id, lv]]
			Save.write()
			toast("%s will do %s every week." % [m.name, d.display_name])
			_after_plan()])
	opts.append(["REST", "Recover fatigue and stress.", func():
		m.schedule = [""]
		Save.write()
		_after_plan()])
	show_menu("%s'S WEEKLY DRILL" % m.name.to_upper(), opts)


# ---------------------------------------------------------------- the week

## Runs the week: each kami's drill, the week-end care rules, aging. sleep = fade to the next morning first
## (ending the week at the house); from a cup / adventure you're already arriving home, so it reports in place.
## Start of the week, after planning: everyone does their drill and the week's results come up. Then it's the weekend.
func run_training() -> void:
	var lines: Array = []
	var before := {}
	var per := {}
	var trained := {}
	var en := Schedule.entry_now()
	for m in Game.monsters:
		before[m] = WeekPlanner.snapshot(m)
		if not en.is_empty() and en["monster"] == m.name:
			var rest := ["%s rests up for the %s." % [m.name, en["name"]]]
			per[m] = rest
			lines += rest
			continue
		var entry := str(m.schedule[0]) if not m.schedule.is_empty() else ""
		var mine: Array = Training.run_entry(m, entry)
		trained[m] = entry != ""
		per[m] = mine
		lines += mine
	lines += Care.training_bonds(Game.monsters, str(en.get("monster", "")))
	for m in Game.monsters.duplicate():
		var end: Array = Care.week_end(m)
		(per[m] as Array).append_array(end)
		lines += end
	Game.trained_week = Game.week
	Save.write()
	if Game.monsters.is_empty():
		report("THE WEEK'S TRAINING", lines if not lines.is_empty() else ["A quiet week on the ranch."], false)
	else:
		WeekPlanner.show_results(self, before, per, trained)
	toast("The weekend: %d AP to spend. Your cup or an adventure leaves from your house." % Game.ap)


## The weekend is over (AP spent, skipped, or back from a cup / adventure): a new week begins.
func end_week(extra: Array, title: String, bad := false, sleep := true, _skip := "") -> void:
	close_menu()
	var lines: Array = extra.duplicate()
	if Game.trained_week != Game.week:  # never got to train this week (old save): do it now
		for m in Game.monsters:
			lines += Training.run_entry(m, str(m.schedule[0]) if not m.schedule.is_empty() else "")
		for m in Game.monsters.duplicate():
			lines += Care.week_end(m)
	Game.advance_week()
	for missed in Schedule.prune():
		lines.append("%s missed the %s." % [missed["monster"], missed["name"]])
	for old in Game.expired():
		lines.append("%s has reached the end of their life and retires to the Hall of Fame." % old.name)
		Game.retire(old, "old age")
	Game.ap = Care.action_points()
	Save.write()
	if sleep:
		Scenes.goto(SELF, {"morning": {"title": title, "lines": lines, "bad": bad}, "entry": "house"} if not lines.is_empty() else {"entry": "house"})
	else:
		if not lines.is_empty():
			report(title, lines, bad)
		Scenes.transition(func() -> void: WeekPlanner.open(self))


func spend_ap() -> bool:
	var ok := super.spend_ap()
	if ok and Game.ap <= 0 and Game.trained_week == Game.week:
		get_tree().create_timer(2.5).timeout.connect(func():  # out of AP: the weekend ends
			if is_inside_tree() and not in_menu:
				end_week([], "A NEW WEEK"))
	return ok


func _returns() -> void:  # a new morning, or coming home from a cup / adventure (events start in town, end here)
	var p := Scenes.params
	if p.has("morning"):
		var mo: Dictionary = p["morning"]
		p.erase("morning")
		report.call_deferred(str(mo["title"]), mo["lines"], bool(mo.get("bad", false)))
		if not Game.monsters.is_empty() and Game.planned_week != Game.week:
			_open_planner.call_deferred()
	elif p.has("cup_result"):
		var res: Dictionary = p["cup_result"]
		p.erase("cup_result")
		var m: MonsterData = Game.monsters[0]
		for b in Game.monsters:
			if b.name == str(p.get("fighter", "")):
				m = b
		var cup: CupDef
		for c in CupDef.all():
			if str(c.id) == str(p.get("cup", "")):
				cup = c
		var promo := str(p.get("kind", "")) == "promotion"
		if promo:
			cup = Schedule.promo_cup(m.rank)
		var won: bool = res.get("won", false)
		var lines := ["Rounds won: %d / %d" % [res.get("rounds_won", 0), res.get("rounds", 3)]]
		var prize := 0
		if cup != null:
			prize = cup.prize if won else cup.prize * int(res.get("rounds_won", 0)) / 10
			if won and not promo and cup.rank == m.rank:
				m.rank_wins += 1
				var left := Schedule.WINS_TO_PROMOTE - m.rank_wins
				lines.append(("%s has %d wins at rank %s: eligible for this year's promotion match!" % [m.name, m.rank_wins, m.rank]) if left <= 0
					else "%s: %d of %d rank-%s wins toward promotion." % [m.name, m.rank_wins, Schedule.WINS_TO_PROMOTE, m.rank])
			if won and promo:
				Care.rank_up(m)
				if Game.RANKS.find(m.rank) > Game.RANKS.find(Game.rank):
					Game.rank = m.rank
				lines.append("PROMOTED! %s is now rank %s." % [m.name, m.rank])
		var en := Schedule.entry_now()
		if not en.is_empty():
			Game.entries.erase(en)
		Game.add_money(prize)
		lines.append("Prize: %d G" % prize)
		lines += Care.tournament_cost(m, won)
		end_week.call_deferred(lines, ("PROMOTED!" if promo else "CUP CLEARED!") if won else "CUP OVER", not won, false)
	elif p.has("adventure_result"):
		var ar: Dictionary = p["adventure_result"]
		var lines: Array = ar.get("lines", [])
		p.erase("adventure_result")
		var lost: bool = ar.get("defeat", false)
		if lost:
			lines.push_front("Your team collapsed in the dungeon and was carried home to recover.")
		end_week.call_deferred(lines, "DEFEATED" if lost else "BACK FROM ADVENTURE", lost, false)
