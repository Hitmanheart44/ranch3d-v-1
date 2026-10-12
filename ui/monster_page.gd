class_name MonsterPage
extends RefCounted
## The MR4-style kami status page: tabs per kami, a framed 3D portrait, rank pips, stat bars, condition gauges
## and a life bar. Build the body with MonsterPage.body(); show it with MR4.page() (HomeMenu.open_page does).

const STAT_COLS := [["HP", "hp", Color(0.86, 0.3, 0.24)], ["POWER", "power", Color(0.92, 0.6, 0.18)], ["GUARD", "guard", Color(0.34, 0.6, 0.86)],
	["SPEED", "speed", Color(0.4, 0.76, 0.4)], ["FOCUS", "focus", Color(0.66, 0.46, 0.82)]]


static func body(monsters: Array, start := 0) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	var holder := MarginContainer.new()
	root.add_child(holder)
	var show := func(i: int, self_fn: Callable) -> void:
		for c in holder.get_children():
			c.queue_free()
		holder.add_child(_sheet(monsters[i]))
		for j in tabs.get_child_count():
			(tabs.get_child(j) as Button).button_pressed = j == i
	for i in monsters.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = (monsters[i] as MonsterData).name
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UIStyle.tex_box("tab_off", 14, 18.0, 8.0))
		b.add_theme_stylebox_override("hover", UIStyle.tex_box("tab_off", 14, 18.0, 8.0))
		b.add_theme_stylebox_override("pressed", UIStyle.tex_box("tab_on", 14, 18.0, 8.0))
		b.add_theme_stylebox_override("hover_pressed", UIStyle.tex_box("tab_on", 14, 18.0, 8.0))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, MR4.INK if k.contains("pressed") else Color(0.95, 0.88, 0.7))
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(show.bind(i, show))
		tabs.add_child(b)
	tabs.visible = monsters.size() > 1
	show.call(clampi(start, 0, monsters.size() - 1), show)
	return root


static func stat_color(stat: String) -> Color:
	for st in STAT_COLS:
		if st[1] == stat:
			return st[2]
	return MR4.INK


static func _sheet(m: MonsterData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	# left: portrait in a dark inset, name, rank pips
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var pf := PanelContainer.new()
	var inset := UIStyle.tex_box("panel_dark", 20, 6.0, 6.0)
	pf.add_theme_stylebox_override("panel", inset)
	left.add_child(pf)
	var view := MonsterView.new()
	view.custom_minimum_size = Vector2(250, 250)
	view.setup(m.model_dict())
	pf.add_child(view)
	var nm := MR4.ink(m.name, 26, false, "display")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(nm)
	var br := MR4.ink(m.breed_label(), 14, true)
	br.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(br)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 6)
	pips.add_child(MR4.ink("RANK %s" % m.rank, 16, false, "display"))
	for i in 3:
		var d := MR4.ink("◆" if i < m.rank_wins else "◇", 18, i >= m.rank_wins, "display")
		d.add_theme_color_override("font_color", MR4.RIBBON if i < m.rank_wins else MR4.INK_DIM)
		pips.add_child(d)
	left.add_child(pips)
	# right: stats, condition, life
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 7)
	right.custom_minimum_size = Vector2(380, 0)
	row.add_child(right)
	var top := float(BalanceDef.get_def().stat_max)
	right.add_child(_head("ABILITIES"))
	for st in STAT_COLS:
		right.add_child(MR4.stat_bar(st[0], m.stat(st[1]), top, st[2], 230.0))
	right.add_child(_head("CONDITION"))
	right.add_child(_gauge("FATIGUE", m.fatigue, 999, Care.fatigue_word(m.fatigue), Color(0.9, 0.55, 0.2)))
	right.add_child(_gauge("STRESS", m.stress, 999, Care.stress_word(m.stress), Color(0.8, 0.35, 0.5)))
	right.add_child(_gauge("FULLNESS", m.fullness, 999, Care.fullness_word(m.fullness), Color(0.5, 0.7, 0.3)))
	right.add_child(_gauge("BOND", m.bonding, 100, "", Color(0.9, 0.45, 0.55)))
	right.add_child(_head("AGE"))
	var months := int(m.age_weeks * 12.0 / 48.0)
	right.add_child(MR4.ink("%d years, %d months" % [months / 12, months % 12], 17, false, "display"))
	if m.personality != "":
		left.add_child(_head("TEMPERAMENT"))
		left.add_child(MR4.ink(m.personality.capitalize(), 16, false, "display"))
		if not m.quirks.is_empty():
			var q := MR4.ink(", ".join(m.quirks).capitalize(), 13, true)
			q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			q.custom_minimum_size = Vector2(250, 0)
			left.add_child(q)
	return row


static func _head(t: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	v.add_child(pad)
	v.add_child(MR4.ink(t, 14, true, "display"))
	var d := TextureRect.new()
	d.texture = load("res://assets/ui/divider.png")
	d.custom_minimum_size = Vector2(0, 12)
	d.stretch_mode = TextureRect.STRETCH_SCALE
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.add_child(d)
	return v


static func _gauge(label: String, value: float, max_value: float, word: String, col: Color) -> Control:
	var row := MR4.stat_bar(label, value, max_value, col, 200.0)
	if word != "":
		(row.get_child(2) as Label).text = word
	return row
