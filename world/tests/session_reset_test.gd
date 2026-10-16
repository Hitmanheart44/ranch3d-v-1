extends Node
## Test real New Game resets, initialization signals and isolated persistence.
var checks := 0
var failures := 0
var observed: Array = []
var signal_states: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("VN-03 FAIL: " + label)


func json_data(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func kami(label: String, breed: StringName) -> MonsterData:
	var m := MonsterData.new()
	m.name = label
	m.main_breed = breed
	m.sub_breed = breed
	m.type = SpeciesDB.get_def(breed).type
	m.lifespan_weeks = 240
	m.seed_hex = "0000000000000003"
	for stat in MonsterData.STAT_NAMES:
		m.stats[stat] = 50
	return m


func defaults(first: MonsterData = null) -> Dictionary:
	# Explicit expectations for existing defaults, independent of the reset implementation.
	return {"version": 1, "monsters": [] if first == null else [first.to_dict()], "active": 0,
		"money": 500, "week": 1, "rank": "E", "hall": [], "summoned": [], "inventory": {},
		"phase": "week", "ap": 0, "intro_seen": false, "ranch_upgrades": ["house", "pen"],
		"stable_level": 0, "trainer": "", "player_name": "Rio", "entries": [], "planned_week": 0,
		"top_rank": "E", "trained_week": 0, "pair_bonds": {},
		"seen": {} if first == null else {str(first.main_breed): {"owned": true, "fought": 0}}}


func contaminate() -> void:
	var old := kami("old session test kami", &"plant")
	Game.from_dict({"monsters": [old.to_dict()], "active": 0, "money": 9999, "week": 48,
		"rank": "C", "top_rank": "B", "hall": [{"name": "old Hall test kami", "rank": "B"}],
		"summoned": ["old seed"], "inventory": {"berries": 9}, "phase": "weekend", "ap": 6,
		"intro_seen": true, "ranch_upgrades": ["house", "pen", "training"], "stable_level": 3,
		"trainer": "m", "player_name": "old trainer test label", "planned_week": 48, "trained_week": 48,
		"entries": [{"event": "cup:iron", "week": 49, "monster": old.name}]})
	Game.see("plant")
	Game.add_pair_bond("old A test kami", "old B test kami", 75)
	Game.run = {"rank": "C", "sector": 2, "loot": {"berries": 4}}
	observed.clear()
	signal_states.clear()


func record(kind: String, value: Variant = null) -> void:
	observed.append([kind, value])
	signal_states.append({"seen": Game.seen.duplicate(true), "bonds": Game.pair_bonds.duplicate(true),
		"run": Game.run.duplicate(true), "money": Game.money, "week": Game.week})


func on_money(value: int) -> void:
	record("money", value)


func on_week(value: int) -> void:
	record("week", value)


func on_added(value: MonsterData) -> void:
	record("added", value)


func on_active(value: MonsterData) -> void:
	record("active", value)


func on_removed(value: MonsterData) -> void:
	record("removed", value)


func on_loaded() -> void:
	record("loaded")


func _ready() -> void:
	var scratch := OS.get_environment("VN03_SCRATCH").simplify_path()
	var save_path := ProjectSettings.globalize_path(Save.PATH).simplify_path()
	if not scratch.begins_with("/tmp/vn-03-") or not save_path.begins_with(scratch + "/") \
			or Save.PATH != "user://save_test.json":
		push_error("VN-03: isolated save path required before any Save access: " + save_path)
		get_tree().quit(2)
		return
	print("VN-03 SAVE_PATH=", save_path)
	if Save.exists():
		push_error("VN-03: fresh scratch required; existing test save left untouched")
		get_tree().quit(2)
		return
	var prior_game := Game.to_dict().duplicate(true)
	var prior_run := Game.run.duplicate(true)
	Events.money_changed.connect(on_money)
	Events.week_advanced.connect(on_week)
	Events.monster_added.connect(on_added)
	Events.active_changed.connect(on_active)
	Events.monster_removed.connect(on_removed)
	Events.game_loaded.connect(on_loaded)
	var first := kami("initial test kami", &"flame")
	first.rank = "D"
	first.rank_wins = 2
	first.schedule = ["weights:2"]
	for initial in [null, first]:
		reset_case(initial)
		save_case(initial)
	Events.money_changed.disconnect(on_money)
	Events.week_advanced.disconnect(on_week)
	Events.monster_added.disconnect(on_added)
	Events.active_changed.disconnect(on_active)
	Events.monster_removed.disconnect(on_removed)
	Events.game_loaded.disconnect(on_loaded)
	Save.delete()
	Game.from_dict(prior_game)
	Game.run = prior_run
	print("VN-03: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func reset_case(first: MonsterData) -> void:
	contaminate()
	check(Game.seen.has("plant") and Game.pair_bond("old A test kami", "old B test kami") == 75 and not Game.run.is_empty(), "prior session contamination established")
	var expected := defaults(first)
	var first_before: Dictionary = {} if first == null else first.to_dict().duplicate(true)
	Game.new_game(first)
	var actual := Game.to_dict()
	for key in expected:
		check(actual.get(key) == expected[key], "New Game default %s; initial=%s" % [key, first != null])
	check(actual.size() == expected.size(), "default schema unchanged")
	check(Game.run.is_empty(), "live Exploration run reset")
	check(Game.active() == first and Game.active_index == 0, "optional first kami selected, or no active kami")
	if first != null:
		check(first.to_dict() == first_before and Game.monsters == [first], "supplied first kami preserved and registered exactly once")
	var expected_signals: Array = [["money", 500], ["week", 1]]
	if first != null:
		expected_signals = [["added", first], ["active", first]] + expected_signals
	check(observed == expected_signals, "existing initial signal counts/order/payloads")
	var initialized := true
	for state: Dictionary in signal_states:
		initialized = initialized and state["seen"] == expected["seen"] and state["bonds"].is_empty() \
			and state["run"].is_empty() and state["money"] == 500 and state["week"] == 1
	check(initialized, "listeners observe cleared session and initialized defaults")
	observed.clear()
	signal_states.clear()
	Game.new_game(first)
	check(Game.to_dict() == expected and Game.run.is_empty(), "repeat New Game has identical clean defaults")
	check(observed == expected_signals, "repeat New Game preserves initial signal contract")
	print("VN-03 CASE New Game initial=%s seen=%s bonds=%s run=%s" % [first != null, Game.seen, Game.pair_bonds, Game.run])


func save_case(first: MonsterData) -> void:
	contaminate()
	check(Save.write(), "write prior isolated session")
	var old_json := FileAccess.get_file_as_string(Save.PATH)
	var old_state: Variant = json_data(Game.to_dict())
	Game.new_game(first)
	check(FileAccess.get_file_as_string(Save.PATH) == old_json, "New Game itself does not overwrite existing save")
	check(Save.read() and json_data(Game.to_dict()) == old_state, "Continue still loads stored prior session unchanged")
	Game.new_game(first)
	check(Save.write(), "write reset session through real Save")
	var encoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.PATH))
	var expected := defaults(first)
	check(encoded.get("seen") == json_data(expected["seen"]), "reset save excludes stale discoveries")
	check(encoded.get("pair_bonds") == {}, "reset save excludes stale pair bonds")
	check(not encoded.has("run") and int(encoded.get("version", 0)) == 1, "live run remains transient; save version retained")
	Game.from_dict({})
	Game.run = {}
	check(Save.read(), "read reset session through real Save")
	check(json_data(Game.to_dict()) == json_data(expected) and Game.run.is_empty(), "reset save round trip retains only current defaults")
	check(Game.seen == expected["seen"] and Game.pair_bonds.is_empty(), "no old discoveries or bonds replay after reload")
	check(Game.active() == null if first == null else Game.active().seed_hex == first.seed_hex, "reloaded optional first identity")
	print("VN-03 CASE Save/Continue round trip initial=", first != null)
