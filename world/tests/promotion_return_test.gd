extends Node
## CPU regression through actual caller, intro, arena input, routing queue and ranch consumer.
const Fixture := preload("res://world/tests/promotion_return_fixture.gd")
const RANCH := "res://world/zones/ranch_v2.tscn"
var checks := 0
var failures := 0
var completions := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("VN-01 FAIL: " + label)


func _ready() -> void:
	var scratch := OS.get_environment("VN01_SCRATCH").simplify_path()
	var save_path := ProjectSettings.globalize_path(Save.PATH).simplify_path()
	if not scratch.begins_with("/tmp/vn-01-") or not save_path.begins_with(scratch + "/") \
			or Save.PATH != "user://save_test.json":
		push_error("VN-01: isolated save path required before any Save access: " + save_path)
		get_tree().quit(2)
		return
	print("VN-01 SAVE_PATH=", save_path)
	if Save.exists():
		push_error("VN-01: fresh scratch required; existing test save left untouched")
		get_tree().quit(2)
		return
	get_tree().create_timer(15.0).timeout.connect(func():
		push_error("VN-01 watchdog expired")
		get_tree().quit(3))
	var prior_game := Game.to_dict().duplicate(true)
	var prior_run := Game.run.duplicate(true)
	var prior_params := Scenes.params
	var prior_busy: bool = Scenes._busy
	var prior_pending: Array = Scenes._pending
	var prior_mode := Scenes.process_mode
	var prior_time := Engine.time_scale
	# Bound presentation tweens cannot advance; actual end_week still runs and saves.
	Scenes.process_mode = Node.PROCESS_MODE_DISABLED
	Events.week_advanced.connect(_completed)
	for promo in [true, false]:
		for won in [true, false]:
			await cup_case(promo, won)
	context_cases()
	Events.week_advanced.disconnect(_completed)
	Save.delete()
	Game.from_dict(prior_game)
	Game.run = prior_run
	Scenes.params = prior_params
	Scenes._busy = prior_busy
	Scenes._pending = prior_pending
	Scenes.process_mode = prior_mode
	Engine.time_scale = prior_time
	print("VN-01: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _completed(_week: int) -> void:
	completions += 1


func kami(label: String) -> MonsterData:
	var m := MonsterData.new()
	m.name = label
	m.main_breed = SpeciesDB.all()[0].id
	m.sub_breed = m.main_breed
	m.type = SpeciesDB.all()[0].type
	m.personality = "calm"
	m.lifespan_weeks = 240
	m.rank_wins = Schedule.WINS_TO_PROMOTE
	m.won_rank_cup = true
	return m


func reset_routes() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	Scenes._busy = true
	Scenes._pending = []
	Scenes.params = {}


func accept() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	return event


func cup_case(promo: bool, won: bool) -> void:
	reset_routes()
	Game.from_dict({})
	Game.run = {}
	var other := kami("unselected test kami")
	var m := kami("selected test kami")
	Game.add_monster(other)
	Game.add_monster(m)
	Game.week = 24 if promo else 22
	Game.trained_week = Game.week
	Game.phase = "weekend"
	var cup: CupDef = Schedule.promo_cup("E") if promo else CupDef.all()[0]
	var event_id := "promo:E" if promo else "cup:" + str(cup.id)
	var entry := {"event": event_id, "monster": m.name, "name": cup.display_name,
		"kind": "promotion" if promo else "regular", "week": Game.week, "month": 5}
	var future := {"event": "cup:dustbin", "monster": other.name, "name": "future test entry", "week": 50}
	Game.entries = [entry, future]
	var ranch := Fixture.Ranch.new()
	add_child(ranch)
	# Obtain the caller's actual arena inputs, including promotion metadata.
	ranch._go_to_cup(entry)
	check(Scenes._pending.size() == 2, "ranch queues intro")
	if Scenes._pending.size() != 2:
		ranch.free()
		return
	check(Scenes._pending[0] == "res://world/flow/cup_intro.tscn", "intro path")
	var intro := Fixture.CupIntro.new()
	intro.p = Scenes._pending[1]
	intro._go()
	check(Scenes._pending[0] == "res://combat/arena.tscn", "intro forwards arena path")
	var inputs: Dictionary = Scenes._pending[1]
	intro.free()
	Scenes.params = inputs
	Scenes._pending = []
	var arena := Fixture.Arena.new()
	add_child(arena)
	var foes: Array[MonsterData] = []
	foes.assign(inputs["foes"])
	arena.setup(inputs["player"], foes)
	arena.rounds_won = foes.size() if won else 1
	arena.state = "done"
	var emitted: Array = []
	arena.match_finished.connect(func(result: Dictionary): emitted.append(result.duplicate()))
	arena._unhandled_input(accept())
	var outgoing: Array = Scenes._pending
	check(outgoing.size() == 2, "arena queues return")
	if outgoing.size() != 2:
		arena.free()
		ranch.free()
		return
	var payload: Dictionary = outgoing[1]  # exact production dictionary, never repaired by test
	check(outgoing[0] == RANCH, "actual return path")
	check(payload.get("kind") == inputs["kind"], "actual arena return retains kind")
	check(payload.get("event") == inputs["event"], "actual arena return retains event")
	check(payload.get("cup") == str(cup.id) and payload.get("fighter") == m.name, "cup/fighter survive")
	var result := {"won": won, "rounds_won": arena.rounds_won, "rounds": foes.size()}
	check(payload.get("cup_result") == result and emitted == [result], "result counts and signal")
	check(not payload.has("player") and not payload.has("foes") and not payload.has("return_to"), "allowlist only")
	arena._unhandled_input(accept())
	check(arena._sent and emitted.size() == 1 and Scenes._pending == outgoing, "Continue emitted once")
	var expected := MonsterData.from_dict(m.to_dict())
	if won and promo:
		Care.rank_up(expected)
	elif won:
		expected.rank_wins += 1
	seed(7101)
	Care.tournament_cost(expected, won)
	seed(7101)
	Scenes.params = payload
	var before_completion := completions
	ranch._returns()
	check(m.to_dict() == expected.to_dict(), "real consumer rank and care: promotion=%s won=%s rank=%s" % [promo, won, m.rank])
	check(m.rank == ("D" if promo and won else "E"), "selected kami rank")
	check(Game.rank == ("D" if promo and won else "E"), "trainer rank")
	check(other.rank == "E" and other.rank_wins == Schedule.WINS_TO_PROMOTE, "unselected kami unchanged")
	var prize := cup.prize if won else cup.prize * arena.rounds_won / 10
	check(Game.money == Game.START_MONEY + prize, "existing reward amount")
	check(Game.entries == [future] and not payload.has("cup_result"), "entry removed and result consumed")
	# Let the real deferred end_week run. Only its presentation tween is disabled.
	Scenes._busy = false
	await get_tree().process_frame
	await get_tree().process_frame
	check(completions == before_completion + 1 and Game.week == (25 if promo else 23), "one real week completion")
	check(m.age_weeks == 1 and Game.ap == Care.action_points(), "existing aging and AP")
	check(ranch.reports.size() == 1, "one result report")
	var completed := Game.to_dict().duplicate(true)
	ranch._returns()
	await get_tree().process_frame
	check(Game.to_dict() == completed and completions == before_completion + 1, "consumed result cannot replay")
	check(Save.exists() and Save.write(), "isolated Save write")
	Game.from_dict({})
	check(Save.read(), "isolated Save read")
	check(JSON.parse_string(JSON.stringify(Game.to_dict())) == JSON.parse_string(JSON.stringify(completed)), "saved rank/rewards/calendar/care/week round trip")
	ranch._returns()
	await get_tree().process_frame
	check(JSON.parse_string(JSON.stringify(Game.to_dict())) == JSON.parse_string(JSON.stringify(completed)) and completions == before_completion + 1, "no result replay after reload")
	print("VN-01 CASE promotion=%s won=%s rank=%s money=%d week=%d" % [promo, won, Game.monsters[1].rank, Game.money, Game.week])
	reset_routes()
	arena.free()
	ranch.free()


func context_cases() -> void:
	reset_routes()
	var arena := Fixture.Arena.new()
	get_tree().root.add_child(arena)
	arena.foe_datas.append(kami("test foe"))
	var emitted: Array = []
	arena.match_finished.connect(func(result: Dictionary): emitted.append(result))
	Scenes.params = {"return_to": "res://explore/dungeon.tscn", "boss": "test boss token",
		"cup": "test cup token", "fighter": "test fighter token", "private_input": 99}
	arena.state = "fight"
	arena._unhandled_input(accept())
	check(emitted.is_empty() and Scenes._pending.is_empty(), "Continue ignored before done")
	arena.state = "done"
	arena._unhandled_input(accept())
	check(Scenes._pending[0] == Scenes.params["return_to"], "boss return path retained")
	var back: Dictionary = Scenes._pending[1]
	check(back == {"cup_result": {"won": false, "rounds_won": 0, "rounds": 1},
		"boss": "test boss token", "cup": "test cup token", "fighter": "test fighter token"}, "legacy caller exact allowlist, no manufactured promotion")
	reset_routes()
	arena._sent = false
	arena.rounds_won = 1
	emitted.clear()
	var prior_scene := get_tree().current_scene
	get_tree().current_scene = arena
	arena._unhandled_input(accept())
	arena._unhandled_input(accept())
	get_tree().current_scene = prior_scene
	check(emitted == [{"won": true, "rounds_won": 1, "rounds": 1}], "standalone match_finished once")
	check(Scenes._pending.is_empty(), "standalone queues no scene return")
	arena.free()
	print("VN-01 CASE boss/legacy forwarding and standalone match_finished")
