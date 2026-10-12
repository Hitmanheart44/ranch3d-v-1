extends Node3D
## Vetting gallery. Shows the shortlist (see SHORT) one item at a time; mark each KEEP or TRASH.
##   godot --path . res://tools/vet/vet.tscn
## Keys: K keep   T trash   M maybe (counts as trash unless you revisit)   ←/→ move   Space replay sound   Esc quit (progress saved)
## Results: ~/.local/share/Ranch3D/vet.json {path: "keep"|"trash"|"maybe"}. Then run tools/vet/apply_vet.py.

const SHORT := [
	["character / kami models", ["assets/models/trainer_f.glb", "assets/models/trainer_m.glb", "assets/models/nysse.glb", "assets/models/sylvara.glb",
		"assets/models/valkra.glb", "assets/models/vexa.glb", "assets/models/revenant.glb", "assets/models/plant.glb", "assets/models/prismoid.glb",
		"assets/models/flame.glb", "assets/models/npc_carpenter.glb", "assets/models/npc_hana.glb", "assets/models/npc_mira.glb", "assets/models/npc_tobin.glb"]],
	["buildings", ["assets/props/bld_ranch.glb", "assets/props/bld_home.glb", "assets/props/bld_pen.glb", "assets/props/bld_stable.glb", "assets/props/bld_hall.glb", "assets/props/bld_shop.glb"]],
	["shrine and harbor props", ["assets/props/sf/torii_s23.glb", "assets/props/sf/hokora_s16.glb", "assets/props/sf/stone_lantern_6.glb", "assets/props/sf/lighthouse_9.glb",
		"assets/props/sf/market_stall_1.glb", "assets/props/sf/well_3.glb", "assets/props/sf/tree_pine11.glb", "assets/props/ph/ship_pinnace.glb", "assets/props/ph/treasure_chest.glb"]],
	["music", ["assets/audio/music_title.ogg", "assets/audio/music_ranch.ogg", "assets/audio/music_shrine.ogg", "assets/audio/music_town.ogg", "assets/audio/music_cave.ogg", "assets/audio/music_battle.ogg"]],
	["ui art", ["assets/ui/panel_paper.png", "assets/ui/panel_dark.png", "assets/ui/ribbon.png", "assets/ui/plate_normal.png", "assets/ui/plate_primary_normal.png",
		"assets/ui/tab_on.png", "assets/ui/bar_fill.png", "assets/ui/divider.png"]],
]
const PATH := "user://vet.json"

var items: Array = []     # [category, path]
var marks := {}
var idx := 0
var pivot: Node3D
var cam: Camera3D
var player: AudioStreamPlayer
var lbl: Label
var info: Label
var tex: TextureRect
var _model: Node3D


func _ready() -> void:
	for c in SHORT:
		for p in c[1]:
			if FileAccess.file_exists("res://" + p):
				items.append([c[0], p])
	if FileAccess.file_exists(PATH):
		marks = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 30, 0)
	add_child(l)
	cam = Camera3D.new()
	add_child(cam)
	pivot = Node3D.new()
	add_child(pivot)
	player = AudioStreamPlayer.new()
	add_child(player)
	var layer := CanvasLayer.new()
	add_child(layer)
	tex = TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.offset_top = 80
	tex.offset_bottom = -80
	layer.add_child(tex)
	lbl = UIStyle.label("", 28, Color.WHITE, "display")
	lbl.position = Vector2(24, 14)
	layer.add_child(lbl)
	info = UIStyle.label("", 18, Color(0.9, 0.85, 0.7), "body")
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(24, -64)
	layer.add_child(info)
	var first := 0
	for i in items.size():
		if not marks.has(items[i][1]):
			first = i
			break
	_show(first)


func _show(i: int) -> void:
	idx = clampi(i, 0, items.size() - 1)
	var p: String = items[idx][1]
	if _model != null:
		_model.queue_free()
		_model = null
	player.stop()
	tex.texture = null
	pivot.rotation = Vector3.ZERO
	if p.ends_with(".glb"):
		_model = (load("res://" + p) as PackedScene).instantiate()
		pivot.add_child(_model)
		var bb := MonsterModel.bounds(_model)
		var r := maxf(bb.size.length() * 0.5, 0.5)
		_model.position = -bb.get_center()
		cam.position = Vector3(0, 0, r * 2.6)
		cam.look_at(Vector3.ZERO)
	elif p.ends_with(".ogg"):
		var st: AudioStream = load("res://" + p)
		player.stream = st
		player.play()
	else:
		tex.texture = load("res://" + p)
	var m: String = marks.get(p, "?")
	lbl.text = "%d / %d    %s    [%s]" % [idx + 1, items.size(), p.get_file(), m.to_upper()]
	info.text = "%s     K keep   T trash   M maybe   ← →   Space replay   Esc quit      kept %d  trashed %d" % [items[idx][0], _count("keep"), _count("trash")]


func _count(k: String) -> int:
	var n := 0
	for v in marks.values():
		if v == k:
			n += 1
	return n


func _mark(v: String) -> void:
	marks[items[idx][1]] = v
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(marks))
	f.close()
	_show(idx + 1)


func _process(delta: float) -> void:
	pivot.rotation.y += delta * 0.8


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_K: _mark("keep")
		KEY_T: _mark("trash")
		KEY_M: _mark("maybe")
		KEY_RIGHT: _show(idx + 1)
		KEY_LEFT: _show(idx - 1)
		KEY_SPACE:
			if player.stream != null:
				player.play()
		KEY_ESCAPE: get_tree().quit()
