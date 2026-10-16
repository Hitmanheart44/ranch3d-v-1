extends Node
## Enforced checks for the existing Version Negative loop, without scene construction.
var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("VN-02 FAIL: " + label)


func json_data(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func kami(label: String, breed: StringName = &"flame", points := 50) -> MonsterData:
	var m := MonsterData.new()
	m.name = label
	m.main_breed = breed
	m.sub_breed = breed
	m.type = SpeciesDB.get_def(breed).type
	m.personality = "test neutral"
	m.bonding = 0
	m.focus = 0
	m.lifespan_weeks = 240
	for stat in MonsterData.STAT_NAMES:
		m.stats[stat] = points
	return m


func _ready() -> void:
	var scratch := OS.get_environment("VN02_SCRATCH").simplify_path()
	var save_path := ProjectSettings.globalize_path(Save.PATH).simplify_path()
	if not scratch.begins_with("/tmp/vn-02-") or not save_path.begins_with(scratch + "/") \
			or Save.PATH != "user://save_test.json":
		push_error("VN-02: isolated save path required before any Save access: " + save_path)
		get_tree().quit(2)
		return
	print("VN-02 SAVE_PATH=", save_path)
	if Save.exists():
		push_error("VN-02: fresh scratch required; existing test save left untouched")
		get_tree().quit(2)
		return
	var prior_game := Game.to_dict().duplicate(true)
	var prior_run := Game.run.duplicate(true)
	Game.from_dict({})
	Game.run = {}
	training_cases()
	life_cases()
	var child := combining_cases()
	save_case(child)
	Save.delete()
	Game.from_dict(prior_game)
	Game.run = prior_run
	print("VN-02: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func training_cases() -> void:
	var drill := Training.find("weights")
	check(drill != null and drill.stat == "power" and drill.side_stat == "speed", "real weights resource")
	var m := kami("training test kami")
	seed(2202)
	var result := Training.run(m, drill, 1)
	check(m.stat("power") >= 53 and m.stat("power") <= 58, "level-one neutral weights gain 3..8")
	check(m.stat("speed") == 49, "weights speed penalty")
	check(m.stat("hp") == 50 and m.stat("guard") == 50 and m.stat("focus") == 50, "unrelated trained stats unchanged")
	check(m.fatigue == 95 and m.stress == 78 and m.fullness == 587 and m.form == -2, "level-one care costs")
	check(m.last_effort == result["effort"] and m.last_effort >= 35 and m.last_effort <= 75, "neutral effort bounds")
	check(not result["lines"].is_empty(), "training returns report")
	var replay := kami("training test kami")
	seed(2202)
	Training.run_entry(replay, "weights:1")
	check(replay.to_dict() == m.to_dict() and replay.last_effort == m.last_effort, "schedule training repeats seeded direct run")
	var capped := kami("cap test kami")
	capped.stats["power"] = 249
	capped.stats["speed"] = 5
	seed(2202)
	Training.run(capped, drill, 1)
	check(capped.stat("power") == 250 and capped.stat("speed") == 5, "stat maximum and side-effect floor")
	var reduced := kami("rank cap test kami", &"flame", 110)
	seed(2202)
	Training.run(reduced, drill, 1)
	check(reduced.stat("power") == 111, "rank-E over-cap gain drops to minimum one")
	var low := kami("level clamp test kami")
	seed(2202)
	Training.run(low, drill, -10)
	check(low.stats == m.stats and low.fatigue == 95, "low level clamps to one")
	var high := kami("level clamp test kami")
	seed(2202)
	Training.run(high, drill, 99)
	check(high.fatigue == 278 and high.stress == 198 and high.fullness == 387 and high.form == -8, "high level clamps to four")
	check(high.stat("speed") == 47 and high.stat("power") >= 58 and high.stat("power") <= 73, "level-four gain and side penalty")
	var rest := kami("rest test kami")
	rest.fatigue = 400
	rest.stress = 300
	rest.fullness = 700
	rest.last_effort = 80
	var stats_before := rest.stats.duplicate()
	Training.run_entry(rest, "")
	check(rest.fatigue == 30 and rest.stress == 50 and rest.fullness == 634 and rest.policy == 1, "Rest recovery and policy")
	check(rest.stats == stats_before and rest.last_effort == -1, "Rest preserves stats and clears effort")
	var invalid := kami("invalid entry test kami")
	invalid.fatigue = 100
	invalid.stress = 100
	invalid.fullness = 40
	check(Training.find("vn02_missing_drill") == null, "invalid drill is absent")
	Training.run_entry(invalid, "vn02_missing_drill:2")
	check(invalid.fatigue == 0 and invalid.stress == 0 and invalid.fullness == 0 and invalid.policy == 2, "invalid entry falls back to bounded Rest")
	check(invalid.stats == stats_before, "invalid entry does not train")
	Training.set_slot(m, 2, "weights:2")
	check(m.schedule == ["", "", "weights:2"], "plan slots pad with Rest")
	check(Training.entry_now(m) == "" and Training.entry_now_at(m, 2) == "weights:2", "read planned slots")
	Training.fill_plan(m, "weights:1", 99)
	check(m.schedule.size() == 8 and m.schedule.count("weights:1") == 8, "plan duration capped at eight")
	Training.set_slot(m, 99, "")
	check(m.schedule.size() == 8 and Training.entry_now_at(m, 7) == "", "slot capped to final planned week")
	print("VN-02 CASE training/rest/invalid entry/caps/plans")


func life_cases() -> void:
	Game.from_dict({})
	var m := kami("life boundary test kami")
	m.age_weeks = 237
	m.life_lost = 2.0
	m.rank = "C"
	m.schedule = ["weights:1", "", "sprints:2"]
	Game.add_monster(m)
	Game.week = 10
	check(m.life_left() == 1.0 and Game.expired().is_empty(), "positive life remaining is not expired")
	seed(2203)
	Game.advance_week()
	check(Game.week == 11 and m.age_weeks == 238, "week and age advance together")
	check(m.schedule == ["", "sprints:2"], "one weekly plan entry consumed")
	check(m.life_left() == 0.0 and Game.expired() == [m], "zero-life expiry boundary")
	var decreased := 0
	for stat in MonsterData.STAT_NAMES:
		if m.stat(stat) == 49:
			decreased += 1
		else:
			check(m.stat(stat) == 50, "old-age change restricted to one stat")
	check(decreased == 1 and m.total() == 249, "existing old-age one-point decline")
	var last_stats := m.stats.duplicate()
	Game.retire(m, "old age")
	check(Game.monsters.is_empty() and Game.active() == null and Game.expired().is_empty(), "retirement removes kami from roster")
	check(Game.hall.size() == 1, "one Hall record")
	var hall: Dictionary = Game.hall[0]
	check(hall["name"] == m.name and hall["age_weeks"] == 238 and hall["week_retired"] == 11, "Hall identity and timing")
	check(hall["stats"] == last_stats and hall["rank"] == "C" and hall["cause"] == "old age", "Hall stats/rank/cause")
	check(hall["breed"] == SpeciesDB.get_def(&"flame").display_name, "Hall resolves valid breed")
	check(Game.trainer_rank() == "C", "retired rank retained in trainer high-water mark")
	m.stats["power"] = 200
	check(hall["stats"] == last_stats, "Hall stats snapshot independent of retired resource")
	print("VN-02 CASE week/life boundary/retirement/Hall")


func combining_cases() -> MonsterData:
	var a := kami("parent A test kami", &"flame", 50)
	var b := kami("parent B test kami", &"plant", 100)
	a.seed_hex = "0000000000000001"
	b.seed_hex = "ffffffffffffffff"
	a.quirks = PackedStringArray(["veteran"])
	b.quirks = PackedStringArray(["glutton"])
	var before_a := a.to_dict().duplicate(true)
	var before_b := b.to_dict().duplicate(true)
	var child := Summoner.combine(a, b)
	var repeated := Summoner.combine(a, b)
	var reversed := Summoner.combine(b, a)
	check(child.to_dict() == repeated.to_dict(), "same fixed pair repeats full combined result")
	check(child.to_dict() == reversed.to_dict(), "distinct seeds sort before combining")
	check(child.source == "combine" and child.seed_hex.length() == 16, "combined source and seed identity")
	check(SpeciesDB.get_def(child.main_breed) != null and SpeciesDB.get_def(child.sub_breed) != null, "child breed references resolve")
	check([child.main_breed, child.sub_breed].has(a.main_breed) and [child.main_breed, child.sub_breed].has(b.main_breed), "both parental main breeds represented")
	check(child.type == child.main_def().type and child.name == child.main_def().display_name, "child uses resolved main identity")
	check(child.quirks == PackedStringArray(["veteran", "glutton"]), "quirk union in sorted-parent order")
	check(child.total() >= 326 and child.total() <= 330, "existing 60-percent fresh and 40-percent parent contribution budget")
	for stat in MonsterData.STAT_NAMES:
		check(child.stat(stat) >= 33 and child.stat(stat) <= 198, "combined inherited stat bounds: " + stat)
	check(a.to_dict() == before_a and b.to_dict() == before_b, "combining preserves parents")
	var trained_a := MonsterData.from_dict(before_a)
	trained_a.stats["power"] += 100
	var inherited := Summoner.combine(trained_a, b)
	check(inherited.stat("power") == child.stat("power") + 20, "+100 parent power inherits exactly +20")
	for stat in ["hp", "guard", "speed", "focus"]:
		check(inherited.stat(stat) == child.stat(stat), "training one parent stat preserves other child stats: " + stat)
	check(inherited.seed_hex == child.seed_hex and inherited.main_breed == child.main_breed and inherited.sub_breed == child.sub_breed, "trained parent retains pair seed/identity")
	# Equal-seed ties are not reordered: record the current order sensitivity explicitly.
	b.seed_hex = a.seed_hex
	var tie_ab := Summoner.combine(a, b)
	var tie_ba := Summoner.combine(b, a)
	check(tie_ab.seed_hex == tie_ba.seed_hex, "equal-seed tie hashes the same pair key")
	check(tie_ab.main_breed == tie_ba.sub_breed and tie_ab.sub_breed == tie_ba.main_breed, "equal-seed tie reverses main/sub with input order")
	check(tie_ab.quirks == PackedStringArray(["veteran", "glutton"]) and tie_ba.quirks == PackedStringArray(["glutton", "veteran"]), "equal-seed tie preserves input quirk order")
	print("VN-02 CASE combining repeatability/inheritance/order; child seed=", child.seed_hex)
	return child


func save_case(child: MonsterData) -> void:
	# Retain the real Hall/progression from life_cases and store an actually trained kami.
	var trainee := kami("saved training test kami")
	seed(2202)
	Training.run_entry(trainee, "weights:1")
	trainee.schedule = ["weights:2", "", "sprints:1"]
	Game.add_monster(trainee)
	Game.add_monster(child)
	Game.set_active(1)
	Game.add_item("berries", 3)
	Game.add_money(75)
	Game.rank = "C"
	Game.phase = "weekend"
	Game.ap = 2
	Game.planned_week = 11
	Game.trained_week = 11
	Game.entries = [{"event": "cup:iron", "monster": trainee.name, "week": 17}]
	var before: Variant = json_data(Game.to_dict())
	check(Save.write() and Save.exists(), "write isolated real JSON save")
	Game.from_dict({})
	check(Save.read(), "read isolated real JSON save")
	check(json_data(Game.to_dict()) == before, "full serialized progression round trip")
	check(Game.active_index == 1 and Game.active().seed_hex == child.seed_hex and Game.active().source == "combine", "selected combined identity and seed retained")
	check(Game.active().main_breed == child.main_breed and Game.active().sub_breed == child.sub_breed, "combined main/sub retained")
	check(Game.monsters[0].stats == trainee.stats and Game.monsters[0].fatigue == 95 and Game.monsters[0].fullness == 587, "trained stats and care retained")
	check(Game.monsters[0].schedule == ["weights:2", "", "sprints:1"], "weekly training plan retained")
	check(Game.week == 11 and Game.rank == "C" and Game.top_rank == "C" and Game.hall.size() == 1, "rank/week/Hall progression retained")
	check(int(Game.inventory.get("berries", 0)) == 3 and Game.money == 575 and Game.entries.size() == 1, "inventory/rewards/calendar retained")
	print("VN-02 CASE Save round trip with trained kami and combined child")
