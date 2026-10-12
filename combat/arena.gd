extends Node3D
## A match: the player's kami vs one AI opponent per round, in the ArenaStage.
## Round flow: intro banner (no control) -> fight -> K.O. -> next round (player heals 30%) -> result.
##
## Embedded (cups, M8):  arena.setup(player_data, [foe1, foe2, foe3], skill, "Cup name")
##                       arena.match_finished.connect(...)   # {won, rounds_won, rounds}
## Standalone (F6): your machine's kami vs three summoned opponents. R restarts.
## `-- demo` makes the player an AI too (for renders). `-- foe_skill=0.2` sets the opponents' skill.

signal match_finished(result: Dictionary)

const BODY := preload("res://monsters/monster_body.tscn")
const INTRO_TIME := 2.2
const KO_TIME := 2.4
const HEAL_BETWEEN := 0.5

var player_data: MonsterData
var foe_datas: Array[MonsterData] = []
var ai_skill := 0.5
var title := "Exhibition"

var player: MonsterBody
var foe: MonsterBody
var hud: FightHud
var round_i := 0
var rounds_won := 0
var state := ""  # intro, fight, ko, done
var _state_t := 0.0
var _sent := false
var _demo := false
var _clock := 0.0  # game seconds since the match started
var cam: FollowCamera
var _intro_cam: Camera3D


func setup(p: MonsterData, foes: Array[MonsterData], skill: float = 0.5, p_title: String = "") -> void:
	player_data = p
	foe_datas = foes
	ai_skill = skill
	if p_title != "":
		title = p_title


func _ready() -> void:
	_demo = "demo" in OS.get_cmdline_user_args()
	var sp := Scenes.params
	if sp.has("player"):  # launched from the ranch
		var fs: Array[MonsterData] = []
		fs.assign(sp["foes"])
		setup(sp["player"], fs, float(sp.get("skill", 0.5)), str(sp.get("title", "")))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("foe_skill="):
			ai_skill = float(a.substr(10))
	if player_data == null:
		player_data = Summoner.summon_machine()
	if foe_datas.is_empty():
		for i in 3:
			foe_datas.append(Summoner.summon_text("arena foe %d" % i))

	if sp.has("stage"):  # an adventure fight happens in the cave room you were standing in
		add_child(CaveRoom.make(sp["stage"]))
	else:
		var stage := ArenaStage.new()
		stage.accent = Types.glow(player_data.type)
		add_child(stage)

	player = BODY.instantiate() as MonsterBody
	player.data = player_data
	player.position = Vector3(-5, 0, 5)
	var ctrl: Node = AIController.new() if _demo else PlayerController.new()
	ctrl.name = "Controller"
	player.add_child(ctrl)
	add_child(player)
	(player.get_node("Hurtbox") as Hurtbox).hurt.connect(func(_r: Dictionary) -> void:
		get_tree().call_group("post_fx", "hurt"))
	player.health.died.connect(_on_player_died)

	cam = FollowCamera.new()
	cam.target = player
	add_child(cam)
	_intro_cam = Camera3D.new()  # first round: a sweep around both fighters before control starts
	_intro_cam.fov = 60.0
	add_child(_intro_cam)
	_intro_cam.make_current()
	add_child(PostFx.new())
	hud = FightHud.new()
	add_child(hud)
	_start_round()


func _start_round() -> void:
	if foe != null:
		foe.queue_free()
	foe = BODY.instantiate() as MonsterBody
	foe.data = foe_datas[round_i]
	Game.see(str(foe.data.main_breed))
	foe.position = Vector3(5, 0, -5)
	var ai := AIController.new()
	ai.name = "Controller"
	ai.skill = ai_skill
	ai.target = player
	foe.add_child(ai)
	add_child(foe)
	foe.health.died.connect(_on_foe_died)
	if _demo:
		for b: MonsterBody in [player, foe]:
			var hb := b.get_node("Hurtbox") as Hurtbox
			if not hb.hurt.is_connected(_log_hit):
				hb.hurt.connect(_log_hit.bind(b))
	player.face_target = foe
	if _demo:
		var pai := player.get_node("Controller") as AIController
		pai.skill = 0.7
		pai.set_target(foe)
	hud.set_fighters(player, foe)
	hud.set_round(round_i, foe_datas.size(), rounds_won, title)
	hud.banner("ROUND %d" % (round_i + 1), "%s  //  %s TYPE" % [foe.data.breed_label().to_upper(), foe.data.type.to_upper()])
	_set_state("intro")


func _log_hit(r: Dictionary, victim: MonsterBody) -> void:
	print("  %.1fs %s hits %s with %s for %d -> %d hp" % [_clock, "FOE" if victim == player else "PLAYER",
		"player" if victim == player else "foe", (r["move"] as MoveDef).id, r["amount"], victim.health.hp])


func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0
	# Controllers only run during the fight. Bodies keep simulating (knockback, falls, KO tilt).
	var live := s == "fight"
	for b in [player, foe]:
		if b == null or not is_instance_valid(b):
			continue
		for c in b.get_children():
			if c is PlayerController or c is AIController:
				c.process_mode = Node.PROCESS_MODE_INHERIT if live else Node.PROCESS_MODE_DISABLED
		if not live:
			b.move_dir = Vector3.ZERO
			b.guarding = false


func _process(delta: float) -> void:
	_clock += delta
	_state_t += delta
	match state:
		"intro":
			if _intro_cam != null:
				var k := clampf(_state_t / INTRO_TIME, 0.0, 1.0)
				var e := 1.0 - pow(1.0 - k, 3.0)
				var mid := (player.global_position + foe.global_position) / 2.0
				var a := lerpf(2.4, 0.75, e)  # swing round from the foe's side to behind the player
				var dist := lerpf(7.0, 13.0, e)
				_intro_cam.global_position = mid + Vector3(cos(a) * dist, lerpf(1.2, 6.0, e), sin(a) * dist)
				_intro_cam.look_at(mid + Vector3(0, 1.4, 0))
			if _state_t >= INTRO_TIME:
				if _intro_cam != null:
					_intro_cam.queue_free()
					_intro_cam = null
					cam.cam.make_current()
				hud.banner("FIGHT", "", UIStyle.ACCENT)
				_set_state("fight")
		"ko":
			if _state_t >= KO_TIME:
				round_i += 1
				player.health.heal(int(float(player.health.max_hp) * HEAL_BETWEEN))
				_start_round()


func _on_foe_died() -> void:
	if state != "fight":
		return
	rounds_won += 1
	hud.set_round(round_i, foe_datas.size(), rounds_won)
	if rounds_won >= foe_datas.size():
		_finish(true)
	else:
		hud.banner("K.O.", "ROUND %d TAKEN" % (round_i + 1), UIStyle.ACCENT)
		_set_state("ko")


func _on_player_died() -> void:
	if state == "fight" or state == "ko":
		_finish(false)


func _finish(won: bool) -> void:
	_set_state("done")
	var hint := "[ ENTER ]  CONTINUE"
	if get_tree().current_scene == self and not Scenes.params.has("return_to"):  # dev test scene only
		hint += "        [ R ]  RESTART"
	Sound.sfx("victory" if won else "defeat", -4.0)
	if won and player != null:
		MonsterModel.play_action(player.model, "Cheer")
	hud.show_result(won, rounds_won, foe_datas.size(), hint)
	if _demo:
		print("MATCH %s  rounds won %d / %d  (%.0fs)" % ["WON" if won else "LOST", rounds_won, foe_datas.size(), _clock])
		get_tree().create_timer(0.5).timeout.connect(get_tree().quit)


func _unhandled_input(event: InputEvent) -> void:
	if state != "done":
		return
	if event.is_action_pressed("ui_accept") and not _sent:
		_sent = true
		var res := {"won": rounds_won >= foe_datas.size(), "rounds_won": rounds_won, "rounds": foe_datas.size()}
		match_finished.emit(res)
		if Scenes.params.has("return_to"):
			var back := {"cup_result": res}
			for k in ["cup", "fighter", "boss"]:  # pass through what the caller needs to resume
				if Scenes.params.has(k):
					back[k] = Scenes.params[k]
			Scenes.goto(Scenes.params["return_to"], back)
		elif get_tree().current_scene == self:
			print("match_finished ", res)
	elif event.is_action_pressed("restart") and get_tree().current_scene == self:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
