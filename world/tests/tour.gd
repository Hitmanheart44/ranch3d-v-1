extends Node
## Dev: a hands-on tour of the known problem spots, 60 seconds each (run WITH graphics):
##   godot --path . res://world/tests/tour.tscn
## Walk around at every stop; the next stop loads when the countdown ends. Esc quits.

const STOP_SECS := 60.0
var STOPS := [
	["Ranch: water edge, ranch exit, buildings against the hill", "res://world/zones/ranch_v2.tscn", {"entry": "south"}, null],
	["Shrine hill: shrine facing, signpost, fence, empty areas", "res://world/zones/shrine.tscn", {"entry": "south"}, null],
	["Town entrance: gate, slopes, boundary", "res://world/zones/town.tscn", {"entry": "north"}, null],
	["Harbor: boat and dock, sea boundary", "res://world/zones/town.tscn", {"entry": "start"}, TownLayout.QUAY],
	["Food shop interior", "res://world/zones/interior.tscn", {"room": "food_shop", "entry": "start"}, null],
	["Association hall exterior (moved onto level ground)", "res://world/zones/town.tscn", {"entry": "north"}, TownLayout.door("association")],
	["Association hall interior", "res://world/zones/interior.tscn", {"room": "association", "entry": "start"}, null],
	["Cave: chest, dead enemies, team pick", "res://explore/dungeon.tscn", {"team": [0], "dungeon": "hollow"}, null],
	["Arena duel: HUD, rounds text", "ARENA", {}, null],
]
var _label: Label
var _left := 0.0


func _ready() -> void:
	_run.call_deferred()


func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta)
	if _label != null:
		_label.text = _label.get_meta("title", "") + "   |   %d s" % int(ceil(_left))


func _scene() -> Node:
	return get_tree().current_scene


func _run() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 690)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.new_game(Summoner.summon_machine())
	Game.ap = Care.action_points()
	Game.planned_week = Game.week
	Game.trained_week = Game.week
	Game.set_meta("started", true)
	var stops: Array = STOPS
	if "assoc" in OS.get_cmdline_user_args():  # godot ... res://world/tests/tour.tscn -- assoc
		stops = STOPS.filter(func(x): return "Association" in str(x[0]))
	var i := 0
	for s in stops:
		i += 1
		_label.set_meta("title", "STOP %d/%d  %s" % [i, stops.size(), s[0]])
		print("TOUR ", i, " ", s[0])
		if s[1] == "ARENA":
			var c: CupDef = CupDef.all()[0]
			Scenes.goto("res://combat/arena.tscn", {"player": Game.monsters[0], "foes": c.make_foes(Game.week), "skill": c.ai_skill,
				"title": "Rank %s  %s" % [c.rank, c.display_name], "return_to": "res://world/zones/ranch_v2.tscn", "cup": c.id, "fighter": Game.monsters[0].name})
		else:
			Scenes.goto(s[1], s[2])
		await get_tree().create_timer(2.0).timeout
		if s[3] != null and _scene() != null and "trainer" in _scene():
			(_scene() as Node).trainer.global_position = s[3] + Vector3(0, 1.0, 0)
		_left = STOP_SECS
		await get_tree().create_timer(STOP_SECS).timeout
	print("TOUR DONE")
	get_tree().quit()
