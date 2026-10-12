class_name AssociationPage
extends RefCounted
## The Trainers' Association desk: your signed-up events, how events work, and COMBINE two kami into one new one.
## Combining retires both and sends you to the shrine hokora for the ritual that calls the child.

static func body(host) -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 26)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	left.add_child(MonsterPage._head("YOUR ENTRIES"))
	if Game.entries.is_empty():
		left.add_child(MR4.ink("None yet. Sign up from the calendar.", 14, true))
	for en in Game.entries:
		left.add_child(MR4.ink("%s\n   %s  ·  %s" % [GameCalendar.label_of(int(en["week"])), en["name"], en["monster"]], 14))
	left.add_child(MonsterPage._head("HOW EVENTS WORK"))
	var how := MR4.ink("Cups run all year. Each rank holds one Promotion Match in Late Summer; a kami needs three cup wins at its rank to enter it.", 13, true)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(320, 0)
	left.add_child(how)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)
	right.add_child(MonsterPage._head("COMBINE TWO KAMI"))
	if Game.monsters.size() < 2:
		right.add_child(MR4.ink("You need two kami.", 14, true))
		return root
	var picked: Array = []
	var go := Button.new()
	go.text = "COMBINE"
	go.disabled = true
	UIStyle.make_primary(go)
	var info := MR4.ink("Pick two. Both are consumed; a new kami is called at the shrine.", 13, true)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(380, 0)
	for m in Game.monsters:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s   (%s, rank %s)" % [m.name, m.breed_label(), m.rank]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggled.connect(func(on: bool) -> void:
			if on:
				picked.append(m)
			else:
				picked.erase(m)
			go.disabled = picked.size() != 2
			info.text = "%s and %s will become one new kami." % [picked[0].name, picked[1].name] if picked.size() == 2 else "Pick two. Both are consumed; a new kami is called at the shrine.")
		right.add_child(b)
	right.add_child(info)
	go.pressed.connect(func() -> void:
		if picked.size() != 2:
			return
		var child := Summoner.combine(picked[0], picked[1])
		Game.retire(picked[0], "combined")
		Game.retire(picked[1], "combined")
		Save.write()
		Scenes.goto("res://world/zones/shrine.tscn", {"entry": "south", "combine_child": child.to_dict()}))
	right.add_child(go)
	return root
