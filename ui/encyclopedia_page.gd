class_name EncyclopediaPage
extends RefCounted
## The kami encyclopedia, a book with one page for each breed you have met, in roster order (turn with the arrows or Left / Right).
## A page shows the breed's portrait, type, class, stat leanings, how you met it and its lore.
## Breeds come from data/species/*.tres (SpeciesDB), discovery from Game.seen.
## Show it with HomeMenu.open_page("ENCYCLOPEDIA", EncyclopediaPage.body()).

const STATS := [["HP", Color(0.86, 0.3, 0.24)], ["POWER", Color(0.92, 0.6, 0.18)], ["GUARD", Color(0.34, 0.6, 0.86)],
	["SPEED", Color(0.4, 0.76, 0.4)], ["FOCUS", Color(0.66, 0.46, 0.82)]]


static func body() -> Control:
	var all: Array = SpeciesDB.all().duplicate()
	all.sort_custom(func(a: SpeciesDef, b: SpeciesDef) -> bool: return a.roster_order < b.roster_order)
	var met: Array = []
	for d in all:
		if Game.seen.has(str(d.id)):
			met.append(d)
	var book := Book.new()
	book.total = all.size()
	book.setup(met, 0)
	return book


## The book: a pager over the top and the current page below it.
class Book extends VBoxContainer:
	var defs: Array = []
	var idx := 0
	var total := 0   # every breed in the game, for the "discovered" count
	var _title: Label
	var _page: VBoxContainer

	func setup(p_defs: Array, start: int) -> void:
		defs = p_defs
		idx = clampi(start, 0, maxi(defs.size() - 1, 0))
		add_theme_constant_override("separation", 10)
		var pager := HBoxContainer.new()
		pager.add_theme_constant_override("separation", 10)
		add_child(pager)
		pager.add_child(_arrow("◀", -1))
		_title = MR4.ink("", 18, true, "display")
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pager.add_child(_title)
		pager.add_child(_arrow("▶", 1))
		_page = VBoxContainer.new()
		_page.custom_minimum_size = Vector2(640, 460)
		_page.add_theme_constant_override("separation", 8)
		add_child(_page)
		render()

	func _arrow(glyph: String, step: int) -> Button:
		var b := Button.new()
		b.text = glyph
		b.flat = true
		b.custom_minimum_size = Vector2(52, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 34)
		b.add_theme_color_override("font_color", MR4.INK_DIM)
		b.add_theme_color_override("font_hover_color", MR4.RIBBON)
		b.add_theme_color_override("font_pressed_color", MR4.RIBBON)
		b.pressed.connect(func() -> void: turn(step))
		return b

	func turn(step: int) -> void:
		if defs.is_empty():
			return
		Sound.sfx("click", -12.0)
		idx = posmod(idx + step, defs.size())
		render()

	func _input(e: InputEvent) -> void:   # the page turns with the arrow keys too
		if not is_visible_in_tree() or not (e is InputEventKey and e.pressed and not e.echo):
			return
		match (e as InputEventKey).keycode:
			KEY_LEFT, KEY_A:
				turn(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				turn(1)
				get_viewport().set_input_as_handled()

	func render() -> void:
		for c in _page.get_children():
			c.queue_free()
		if defs.is_empty():
			_title.text = ""
			_page.add_child(MR4.ink("Nothing recorded yet.\nSummon or meet a kami and it is written here.", 18, true))
			return
		_title.text = "Page %d of %d     ·     Discovered %d / %d" % [idx + 1, defs.size(), defs.size(), total]
		EncyclopediaPage._known_page(_page, defs[idx] as SpeciesDef)


static func _known_page(into: VBoxContainer, d: SpeciesDef) -> void:
	var e: Dictionary = Game.seen.get(str(d.id), {})
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	into.add_child(top)
	var pf := PanelContainer.new()
	pf.add_theme_stylebox_override("panel", UIStyle.tex_box("panel_dark", 20, 6.0, 6.0))
	top.add_child(pf)
	var view := MonsterView.new()
	view.custom_minimum_size = Vector2(260, 300)
	view.setup({"species_id": d.model_key(), "breed": str(d.id), "type": d.type, "hue": 0})
	pf.add_child(view)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(MR4.ink("No. %02d" % (d.roster_order + 1), 14, true, "display"))
	info.add_child(MR4.ink(d.display_name, 36, false, "display"))
	info.add_child(MR4.ink("%s  /  %s" % [d.type.capitalize() + ((" + " + d.type2.capitalize()) if d.type2 != "" else ""), d.body_class.capitalize()], 17, true))
	info.add_child(MR4.ink(("Raised on your ranch" if e.get("owned", false) else "Met in battle  x%d" % int(e.get("fought", 0))), 15, true))
	for i in STATS.size():
		info.add_child(MR4.stat_bar(STATS[i][0], float(d.bias[i]) if i < d.bias.size() else 2.0, 5.0, STATS[i][1], 150.0))
	into.add_child(MonsterPage._head("LORE"))
	var lore := MR4.ink(d.lore if d.lore != "" else "No notes yet.", 18)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(620, 0)
	into.add_child(lore)
