class_name MR4
extends RefCounted
## Kami Rancher 4 style UI pieces: parchment pages in a wooden frame with a ribbon title and a Back button,
## stat bars, and a modal wrapper that closes on click-away, Esc, right-click or Back. Build screens from these.

const PAPER := Color(0.93, 0.87, 0.72)
const PAPER_DARK := Color(0.84, 0.76, 0.58)
const WOOD := Color(0.36, 0.2, 0.1)
const WOOD_LIGHT := Color(0.55, 0.34, 0.16)
const INK := Color(0.2, 0.11, 0.06)
const INK_DIM := Color(0.42, 0.3, 0.2)
const RIBBON := Color(0.62, 0.14, 0.09)
const GOLD := Color(0.86, 0.66, 0.3)


static func frame_style() -> StyleBoxTexture:
	var s := UIStyle.tex_box("panel_paper", 58, 44.0, 36.0)
	s.content_margin_top = 30
	return s


## Ink-coloured label for use on parchment.
static func ink(text: String, size: int = 17, dim := false, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIStyle.font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK_DIM if dim else INK)
	l.add_theme_constant_override("outline_size", 0)
	return l


## UIStyle.label without the dark outline (for use on parchment).
static func lab(text: String, size: int, col: Color, kind := "body") -> Label:
	var l := UIStyle.label(text, size, col, kind)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A horizontal stat bar: name, wooden trough, coloured fill, number.
static func stat_bar(stat: String, value: float, max_value: float, col: Color, width := 260.0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var n := ink(stat, 15, false, "display")
	n.custom_minimum_size = Vector2(98, 0)
	row.add_child(n)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	var fill := UIStyle.tex_box("bar_fill", 9, 0.0, 0.0)
	fill.modulate_color = col
	bar.add_theme_stylebox_override("background", UIStyle.tex_box("bar_trough", 11, 0.0, 0.0))
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var v := ink(str(int(value)), 15, false, "display")
	v.custom_minimum_size = Vector2(120, 0)
	row.add_child(v)
	return row


static func _ribbon(title: String) -> Control:
	var p := PanelContainer.new()
	var st := UIStyle.tex_box("ribbon", 34, 54.0, 6.0)
	st.texture_margin_top = 8
	st.texture_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)
	p.add_child(UIStyle.label(title, 24, Color(1.0, 0.95, 0.8), "display"))
	return p


## A modal page on `host` (a full-screen Control): dimmed backdrop, framed parchment holding `body`, ribbon title,
## Back button. `on_close` runs once however it is dismissed. Returns the root; free it (or call on_close) to dismiss.
static func page(host: Control, title: String, body: Control, on_close: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var closed := [false]
	var close := func() -> void:
		if closed[0]:
			return
		closed[0] = true
		Sound.sfx("menu_close", -10.0)
		root.queue_free()
		on_close.call()
	root.set_meta("close", close)
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			close.call())
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame_style())
	panel.mouse_filter = Control.MOUSE_FILTER_PASS   # clicks inside the page don't dismiss it; the hint says where to click
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var ribbon := _ribbon(title)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ribbon)
	vb.add_child(body)
	var foot := HBoxContainer.new()
	vb.add_child(foot)
	var hint := ink("click outside  ·  Esc  ·  right-click to close", 12, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var back := Button.new()
	back.text = "  BACK  "
	UIStyle.make_primary(back)
	back.pressed.connect(close)
	foot.add_child(back)
	host.add_child(root)
	Sound.sfx("menu_open", -10.0)
	back.grab_focus.call_deferred()
	return root


## Parchment text body for simple pages.
static func text_body(lines: Array, width := 640.0) -> Control:
	var l := ink("\n".join(lines), 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l
