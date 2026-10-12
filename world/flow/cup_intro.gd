extends Node3D
## Before every cup match: an intro, then the arena.
##  - Promotion matches get the special intro; every other match gets the short generic one.
##  - A video takes over when its file exists (Theora .ogv, Godot plays these natively):
##      res://assets/video/promo_<rank>.ogv   (e.g. promo_e.ogv)  -> that rank's promotion intro
##      res://assets/video/cup_<cup id>.ogv                        -> one cup's own intro
##      res://assets/video/match.ogv                               -> the generic pre-match intro
##    Without a video, an in-engine sequence plays: the camera sweeps the arena under banners and a title card.
## Any key / click skips. Params: {kind, event, title, rank, arena: <arena params>}

const PROMO_TIME := 8.0
const MATCH_TIME := 3.5
const ARENA := "res://combat/arena.tscn"

var p: Dictionary
var t := 0.0
var length := MATCH_TIME
var cam: Camera3D
var promo := false
var _done := false
var _title: Label
var _sub: Label
var _bar_top: ColorRect
var _bar_bot: ColorRect


func _ready() -> void:
	p = Scenes.params
	promo = str(p.get("kind", "")) == "promotion"
	length = PROMO_TIME if promo else MATCH_TIME
	var ui := CanvasLayer.new()
	add_child(ui)
	var video := _video_path()
	if video != "":
		var vp := VideoStreamPlayer.new()
		vp.stream = load(video)
		vp.expand = true
		vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(vp)
		vp.finished.connect(_go)
		vp.play()
		length = 1e9
		Sound.play_music("")
		return
	var stage := ArenaStage.new()
	add_child(stage)
	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.make_current()
	for top in [true, false]:  # letterbox
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 90)
		if not top:
			bar.position.y -= 90
		ui.add_child(bar)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	ui.add_child(root)
	var box := VBoxContainer.new()  # title over subtitle, centred
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	_title = UIStyle.label(str(p.get("title", "")).to_upper(), 64 if promo else 52, UIStyle.LINE_HI if promo else UIStyle.TEXT, "display")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	box.add_child(_title)
	var next: String = Game.RANKS[mini(Game.RANKS.find(str(p.get("rank", "E"))) + 1, Game.RANKS.size() - 1)]
	var arena_p: Dictionary = p.get("arena", {})
	var fighter := str(arena_p.get("fighter", ""))
	_sub = UIStyle.label(("Win and %s rises to rank %s." % [fighter, next]) if promo else ("%s enters the ring." % fighter), 24, UIStyle.ACCENT, "display")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate.a = 0.0
	box.add_child(_sub)
	var skip := UIStyle.label("any key to skip", 13, UIStyle.DIM, "mono")
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position += Vector2(-150, -60)
	root.add_child(skip)
	Sound.play_music("battle")
	Sound.sfx("summon", -6.0 if promo else -12.0)


func _video_path() -> String:
	var arena_p: Dictionary = p.get("arena", {})
	var cands: Array = []
	if promo:
		cands.append("res://assets/video/promo_%s.ogv" % str(p.get("rank", "e")).to_lower())
	cands.append("res://assets/video/cup_%s.ogv" % str(arena_p.get("cup", "")))
	if not promo:
		cands.append("res://assets/video/match.ogv")
	for c in cands:
		if ResourceLoader.exists(c):
			return c
	return ""


func _process(delta: float) -> void:
	t += delta
	if cam != null:
		var k := clampf(t / length, 0.0, 1.0)
		var a := lerpf(-0.6, 1.4, k) if promo else lerpf(0.4, 1.1, k)  # sweep around the ring
		var r := lerpf(34.0, 18.0, k) if promo else 20.0
		var h := lerpf(16.0, 4.0, k) if promo else lerpf(6.0, 3.5, k)
		cam.position = Vector3(cos(a) * r, h, sin(a) * r)
		cam.look_at(Vector3(0, 1.5, 0))
		var title_in := 0.3 if not promo else 1.2
		_title.modulate.a = clampf((t - title_in) / 0.4, 0.0, 1.0) * clampf((length - t) / 0.4, 0.0, 1.0)
		_sub.modulate.a = clampf((t - title_in - 0.5) / 0.4, 0.0, 1.0) * clampf((length - t) / 0.4, 0.0, 1.0)
	if t >= length:
		_go()


func _go() -> void:
	if _done:
		return
	_done = true
	Scenes.goto(ARENA, p.get("arena", {}))


func _unhandled_input(e: InputEvent) -> void:
	if t > 0.4 and ((e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed)):
		_go()
