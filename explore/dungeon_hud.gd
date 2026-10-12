class_name DungeonHud
extends CanvasLayer
## Adventure HUD in MR4's layout: a round spirit dial, the dungeon name and floor, the team list (top left).
## Plus a choice list (ask) and pop-up messages (toast).

const GOLD := Color(1.0, 0.78, 0.32)

var dungeon  # explore/dungeon.gd (untyped: reads its run dictionary)
var _view: Control
var _ask_box: VBoxContainer
var _toast: Label
var _fade: ColorRect


func _ready() -> void:
	var root := Control.new()
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_plate)
	root.add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ask_box = VBoxContainer.new()
	_ask_box.position = Vector2(24, 200)
	root.add_child(_ask_box)
	_toast = UIStyle.label("", 22, GOLD, "display")
	root.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y += 120
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint := UIStyle.label("WASD run  //  RIGHT-DRAG look  //  SPACE dodge  //  ESC leave", 12, UIStyle.DIM, "mono")
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, hint.position.y - 34)


## Fade the screen to black (a = 1) or back (a = 0) between rooms.
func fade(a: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished


func _process(_delta: float) -> void:
	_view.queue_redraw()


func _draw_plate() -> void:
	var run: Dictionary = dungeon.run
	if run.is_empty():
		return
	var d: Array = dungeon._dungeon()
	var f_disp := UIStyle.font("display")
	var f_mono := UIStyle.font("mono")
	# plate
	_view.draw_style_box(UIStyle.tex_box("panel_dark", 20), Rect2(10, 8, 440, 170))
	_minimap()
	# spirit dial
	var c := Vector2(88, 92)
	var k := clampf(float(run["spirit"]) / float(run["spirit_max"]), 0.0, 1.0)
	_view.draw_circle(c, 56, Color(0.12, 0.06, 0.05))
	_view.draw_arc(c, 48, -PI / 2, -PI / 2 + TAU * k, 48, Color(0.86, 0.3, 0.22), 14.0, true)
	_view.draw_arc(c, 48, -PI / 2, -PI / 2 + TAU * k, 48, Color(1, 1, 1, 0.18), 5.0, true)
	_view.draw_arc(c, 57, 0, TAU, 48, GOLD, 3.0, true)
	_view.draw_arc(c, 41, 0, TAU, 48, Color(0.55, 0.38, 0.2), 2.0, true)
	_view.draw_string(f_disp, c + Vector2(-60, 10), str(maxi(0, int(run["spirit"]))), HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color.WHITE)
	# name + floor
	_view.draw_string(f_disp, Vector2(160, 56), d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	_view.draw_string(f_disp, Vector2(400, 56), "%dF" % int(run["floor"]), HORIZONTAL_ALIGNMENT_RIGHT, -1, 28, GOLD)
	# team
	var y := 84.0
	for i in (run["team"] as Array):
		var m: MonsterData = Game.monsters[int(i)]
		var ko: bool = int(i) in run["ko"]
		_view.draw_string(f_mono, Vector2(160, y + 12), m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.DIM if ko else Color.WHITE)
		_view.draw_style_box(UIStyle.tex_box("bar_trough", 11), Rect2(287, y - 2, 136, 14))
		if not ko:
			_view.draw_rect(Rect2(290, y + 1, 130 * (1.0 - float(m.fatigue) / 999.0), 8), Color(0.45, 0.78, 0.4))
		y += 24.0
	_view.draw_string(f_mono, Vector2(28, 186), "LOOT  %d G  //  %d items" % [int(run["money"]), (run["items"] as Dictionary).values().reduce(func(a, b): return a + b, 0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)


func ask(title: String, opts: Array, cb: Callable) -> void:
	for c in _ask_box.get_children():
		c.queue_free()
	_ask_box.add_child(UIStyle.label(title, 20, GOLD, "display"))
	for o in opts:
		var b := Button.new()
		b.text = "%s   %s" % [o[1], o[2]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440, 42)
		b.pressed.connect(func() -> void:
			for c in _ask_box.get_children():
				c.queue_free()
			cb.call(str(o[0])))
		_ask_box.add_child(b)


func toast(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


## Map of the floor's rooms you've seen (top right): rooms as tiles, tunnels as links, you as a gold dot.
func _minimap() -> void:
	var cell := 26.0
	var g: int = dungeon.GRID
	var o := Vector2(_view.size.x - 24 - g * cell, 18)
	_view.draw_style_box(UIStyle.tex_box("panel_dark", 20), Rect2(o - Vector2(14, 14), Vector2(g * cell + 28, g * cell + 28)))
	var run: Dictionary = dungeon.run
	for c in dungeon.rooms:
		if not "%d:%d:%d" % [run["floor"], c.x, c.y] in run["visited"]:
			continue
		var r := Rect2(o + Vector2(c.x, c.y) * cell + Vector2(4, 4), Vector2(cell - 8, cell - 8))
		var kind: String = dungeon.rooms[c]["kind"]
		_view.draw_rect(r, Color(0.6, 0.4, 1.0) if kind == "exit" else UIStyle.DIM.darkened(0.35))
		for e in dungeon.exits_of(c):
			var d: Vector2i = dungeon._off(e)
			_view.draw_line(r.get_center(), r.get_center() + Vector2(d) * cell * 0.5, UIStyle.DIM.darkened(0.35), 4.0)
	var cur: Vector2i = dungeon.room
	var lp: Vector3 = dungeon.leader.global_position if dungeon.leader != null else Vector3.ZERO
	var at: Vector2 = o + (Vector2(cur) + Vector2(0.5, 0.5)) * cell + Vector2(lp.x, lp.z) / (CaveRoom.R * 2.0) * (cell - 8)
	_view.draw_circle(at, 4.5, GOLD)
