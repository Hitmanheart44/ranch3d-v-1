class_name BreederPage
extends RefCounted
## The trainer card: who you are, your standing and gold, the ranch's buildings, your kami' bonds and the Hall of Fame.


static func body() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var seal := PanelContainer.new()
	seal.add_theme_stylebox_override("panel", UIStyle.tex_box("panel_dark", 20, 14.0, 14.0))
	left.add_child(seal)
	var sv := VBoxContainer.new()
	sv.custom_minimum_size = Vector2(230, 0)
	sv.add_theme_constant_override("separation", 6)
	seal.add_child(sv)
	sv.add_child(_center(UIStyle.label("TRAINER", 14, UIStyle.DIM, "display")))
	sv.add_child(_center(UIStyle.label(Game.player_name, 34, UIStyle.ACCENT, "display")))
	sv.add_child(_center(UIStyle.label("RANK  %s" % Game.rank, 22, UIStyle.TEXT, "display")))
	sv.add_child(_center(UIStyle.label("%d G" % Game.money, 22, Color(1.0, 0.86, 0.45), "display")))
	left.add_child(MonsterPage._head("STANDING"))
	left.add_child(MR4.ink(GameCalendar.label(), 15, false, "display"))
	var raised := Game.monsters.size() + Game.hall.size()
	left.add_child(MR4.ink("%d kami raised  ·  %d retired" % [raised, Game.hall.size()], 14, true))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 7)
	right.custom_minimum_size = Vector2(400, 0)
	row.add_child(right)
	right.add_child(MonsterPage._head("RANCH"))
	var have := PackedStringArray()
	for k in Game.ranch_upgrades:
		have.append(_title(str(k)))
	right.add_child(MR4.ink("  ·  ".join(have), 16))
	var missing := PackedStringArray()
	for k in RanchRules.ADDITIONS:
		if not k in Game.ranch_upgrades:
			missing.append(str(RanchRules.ADDITIONS[k][1]))
	if not missing.is_empty():
		right.add_child(MR4.ink("Not built yet: " + ", ".join(missing), 13, true))
	right.add_child(MonsterPage._head("BONDS"))
	if Game.monsters.is_empty():
		right.add_child(MR4.ink("No kami yet.", 14, true))
	for m in Game.monsters:
		right.add_child(MR4.stat_bar(m.name.left(9).to_upper(), m.bonding, 100, Color(0.9, 0.45, 0.55), 170.0))
	var pairs := 0
	for i in Game.monsters.size():
		for j in range(i + 1, Game.monsters.size()):
			var a: MonsterData = Game.monsters[i]
			var b: MonsterData = Game.monsters[j]
			right.add_child(MR4.stat_bar("%s & %s" % [a.name.left(4), b.name.left(4)], Game.pair_bond(a.name, b.name), 100, Color(0.5, 0.7, 0.85), 170.0))
			pairs += 1
	if pairs == 0 and Game.monsters.size() == 1:
		right.add_child(MR4.ink("Train two kami on the same drill and they will become friends.", 13, true))
	right.add_child(MonsterPage._head("HALL OF FAME"))
	if Game.hall.is_empty():
		right.add_child(MR4.ink("Empty so far. Kami that live a full life are remembered here.", 14, true))
	for h in Game.hall.slice(maxi(0, Game.hall.size() - 8)):
		right.add_child(MR4.ink("%s   (%s)   lived %.1f years" % [h["name"], h["breed"], float(h["age_weeks"]) / 48.0], 15))
	return row


static func _title(k: String) -> String:
	return k.replace("_", " ").capitalize()


static func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
