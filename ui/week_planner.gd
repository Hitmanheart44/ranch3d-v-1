class_name WeekPlanner
extends Control
## The start of every week (MR4's morning at the house): it opens by itself, before you roam. Shows the date,
## this week's event (if you're signed up for one), and each kami's condition and weekly drill. From here you
## change drills or open the wall calendar, then "OUT TO THE RANCH" lets you walk around until the weekend.
##   WeekPlanner.open(ranch)   (the ranch zone provides _plan(m), training is stored on each kami)

var zone



static func open(z) -> WeekPlanner:
	var w := WeekPlanner.new()
	w.zone = z
	z.hud_root.add_child(w)
	z.in_menu = true
	z.trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return w


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	_build()


## Kami Rancher 4's planning pose: the selected kami stands in the left window, the command menu is on the right,
## and each command swaps the right pane to its own page (TRAINING, STATUS), with BACK returning to the menu.
const LEFT_FRAC := 0.6
var _k := 0.0           # type and spacing scale: shrinks until the page fits the window, with no scrolling
var _holder: Control
var _pane_w := 600.0
var _v: VBoxContainer
var _wide := true   # the right pane is wide enough for two columns of drill cards
var _page := "main"
var _results := {}   # after a week of training: {"before": {kami: snapshot}, "lines": {kami: [text]}}


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var vs := get_viewport().get_visible_rect().size
	_wide = vs.x * (1.0 - LEFT_FRAC) - 36.0 >= 600.0
	_pane_w = vs.x * (1.0 - LEFT_FRAC) - 36.0
	if _k <= 0.0:
		_k = clampf(vs.y / 1000.0, 0.55, 1.0)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.08)   # the ranch stays visible behind the planner
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MR4.frame_style())
	if _page == "training":   # the whole screen, translucent, so the ranch and the kami still show through
		_pane_w = vs.x - 56.0
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(k, 28)
		add_child(margin)
		margin.add_child(panel)
		panel.self_modulate = Color(1, 1, 1, 0.68)
	else:
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var window := Control.new()   # the kami shows through here
		window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		window.size_flags_stretch_ratio = LEFT_FRAC
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(window)
		var side := MarginContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.size_flags_stretch_ratio = 1.0 - LEFT_FRAC
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			side.add_theme_constant_override(k, 18)
		row.add_child(side)
		side.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", maxi(4, _f(10)))
	_holder = Control.new()   # the page is laid out inside this and scaled to fit it
	_holder.custom_minimum_size = Vector2(100, 100)
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_holder)
	_holder.add_child(v)
	_v = v
	if Game.monsters.is_empty():
		v.add_child(_title("A NEW WEEK"))
		v.add_child(MR4.ink("You have no kami yet.", 22, true))
		v.add_child(_command("START THE WEEK", _leave, true))
		return
	_selected = clampi(_selected, 0, Game.monsters.size() - 1)
	var m: MonsterData = Game.monsters[_selected]
	match _page:
		"training":
			_page_training(v, m)
		"status":
			_page_status(v, m)
		"results":
			_page_results(v, m)
		_:
			_page_main(v, m)
	_focus_camera()
	_fit.call_deferred()


const FONT_BUMP := 1.15   # the planner's overall type size


func _f(n: float) -> int:   # a font size or length scaled to the window
	return maxi(12, roundi(n * FONT_BUMP * maxf(_k, 0.5)))


## After layout: if the page is taller or wider than the pane, the whole page is scaled down to fit (never cut off, never scrolling).
func _fit() -> void:
	await get_tree().process_frame
	if _v == null or not is_instance_valid(_v) or _holder == null or not is_instance_valid(_holder):
		return
	var avail := _holder.size
	var need := _v.get_combined_minimum_size()
	if avail.x < 50.0 or avail.y < 50.0:
		return
	var sc := minf(1.0, minf(avail.y / maxf(need.y, 1.0), avail.x / maxf(need.x, 1.0)))
	_v.scale = Vector2(sc, sc)
	_v.size = Vector2(avail.x / sc, maxf(need.y, avail.y / sc))


func _title(text: String) -> Control:
	var rib := MR4._ribbon(text)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rib


## A big menu button; the primary one is the red lacquer plate.
func _command(text: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.custom_minimum_size = Vector2(0, _f(56))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _f(24))
	if primary:
		UIStyle.make_primary(b)
		b.add_theme_font_size_override("font_size", _f(24))
	b.pressed.connect(func() -> void:
		Sound.sfx("click", -10.0)
		action.call())
	return b


func _go_page(page: String) -> void:
	_page = page
	_build()


func _page_main(v: VBoxContainer, m: MonsterData) -> void:
	v.add_child(_title("A NEW WEEK"))
	var date := MR4.ink(GameCalendar.label(), _f(28), false, "display")
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(date)
	var ev := MR4.ink(_event_text(), _f(16), true)
	ev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.custom_minimum_size = Vector2(300, 0)
	v.add_child(ev)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var multi := Game.monsters.size() > 1
	if multi:
		head.add_child(_arrow("◀", -1))
	var nm := MR4.ink(m.name, _f(38), false, "display")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if multi:
		head.add_child(_arrow("▶", 1))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	v.add_child(chips)
	chips.add_child(_chip("RANK", m.rank))
	chips.add_child(_chip("FATIGUE", Care.fatigue_word(m.fatigue)))
	chips.add_child(_chip("STRESS", Care.stress_word(m.stress)))
	v.add_child(MonsterPage._head("THIS WEEK"))
	var en := Schedule.entry_now()
	var fights: bool = not en.is_empty() and en["monster"] == m.name
	var week := MR4.ink("Competing" if fights else _drill_name(m).capitalize(), _f(32), false, "display")
	week.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(week)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	v.add_child(_command("TRAINING", func() -> void: _go_page("training")))
	v.add_child(_command("STATUS", func() -> void: _go_page("status")))
	v.add_child(_command("CALENDAR", _open_calendar))
	v.add_child(_command("START THE WEEK", _leave, true))


func _arrow(glyph: String, step: int) -> Button:   # a clean chevron, no box
	var b := Button.new()
	b.text = glyph
	b.flat = true
	b.custom_minimum_size = Vector2(_f(52), _f(52))
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _f(34))
	b.add_theme_color_override("font_color", MR4.INK_DIM)
	b.add_theme_color_override("font_hover_color", MR4.RIBBON)
	b.add_theme_color_override("font_pressed_color", MR4.RIBBON)
	b.pressed.connect(func() -> void: _switch(step))
	return b


## A small paper tag: a tiny caption over the value.
func _chip(caption: String, value: String) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = MR4.PAPER_DARK
	sb.border_color = MR4.WOOD_LIGHT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	pc.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pc.add_child(col)
	var cap := MR4.ink(caption, _f(12), true, "display")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var val := MR4.ink(value.capitalize(), _f(20), false, "display")
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(val)
	return pc


func _switch(step: int) -> void:
	if Game.monsters.size() < 2:
		return
	if _page == "results":   # one overview camera for everyone: only the overlay changes
		_apply_switch(step)
	else:
		Scenes.transition(_apply_switch.bind(step))   # the camera and the kami's spot change, so it fades like every other cut


func _apply_switch(step: int) -> void:
	_selected = posmod(_selected + step, Game.monsters.size())
	_build()


func _page_training(v: VBoxContainer, m: MonsterData) -> void:
	v.add_child(_title("TRAINING"))
	var nm := MR4.ink(m.name.to_upper(), _f(26), false, "display")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var en := Schedule.entry_now()
	var fights: bool = not en.is_empty() and en["monster"] == m.name
	v.add_child(_plan_row(m))
	var grid := GridContainer.new()
	grid.columns = 3 if _pane_w >= 860.0 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var cur := Training.entry_now_at(m, _slot).split(":")[0]
	var lv := 2 if "training" in Game.ranch_upgrades else 1
	for d in Training.all():
		grid.add_child(_drill_card(m, d.display_name, str(d.stat), "+%d-%d  ·  fatigue %d" % [d.gain_min, d.gain_max, d.fatigue], str(d.id) == cur, fights, "%s:%d" % [d.id, lv]))
	grid.add_child(_drill_card(m, "Rest", "", "recover fatigue and stress", cur == "", fights, ""))
	if fights:
		v.add_child(MR4.ink("%s competes this week, so no drill." % m.name, _f(16), true))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	var back := _command("BACK", func() -> void: _go_page("main"))
	back.custom_minimum_size.x = 320
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


## The week's training result, one kami at a time: what the drill did to each ability and to the gauges.
static func snapshot(m: MonsterData) -> Dictionary:
	return {"stats": m.stats.duplicate(), "fatigue": m.fatigue, "stress": m.stress, "fullness": m.fullness, "bond": m.bonding}


static func show_results(z, before: Dictionary, lines: Dictionary, trained: Dictionary = {}) -> WeekPlanner:
	var w := WeekPlanner.new()
	w.zone = z
	w._page = "results"
	w._results = {"before": before, "lines": lines, "trained": trained}
	z.hud_root.add_child(w)
	z.in_menu = true
	z.trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	w.modulate.a = 0.0   # the kami is seen drilling (or resting) first; the results fade in over it
	var tw := w.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(w, "modulate:a", 1.0, 0.6)
	return w


func _close_results() -> void:
	Scenes.transition(_finish_results)   # fade out, the camera goes back to the trainer, fade in on free roam


func _finish_results() -> void:
	zone.in_menu = false
	zone.free_trainer()
	if _focus != null and is_instance_valid(_focus):
		_focus.queue_free()
	queue_free()


func _delta_text(now: float, was: float) -> String:
	var d := int(round(now - was))
	return "" if d == 0 else ("  (%+d)" % d)


func _page_results(v: VBoxContainer, m: MonsterData) -> void:
	v.add_child(_title("THE WEEK'S TRAINING"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	if Game.monsters.size() > 1:
		head.add_child(_arrow("◀", -1))
	var nm := MR4.ink(m.name, _f(32), false, "display")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if Game.monsters.size() > 1:
		head.add_child(_arrow("▶", 1))
	var before: Dictionary = (_results["before"] as Dictionary).get(m, snapshot(m))
	var notes: Array = (_results["lines"] as Dictionary).get(m, [])
	if not notes.is_empty():   # the drill and its effort, then any success banner
		var drill := MR4.ink(str(notes[0]), _f(17), true)
		drill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		drill.custom_minimum_size = Vector2(200, 0)
		v.add_child(drill)
	if "GREAT SUCCESS!" in notes:
		var great := MR4.ink("GREAT SUCCESS!", _f(26), false, "display")
		great.add_theme_color_override("font_color", MR4.RIBBON)
		great.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(great)
	var bar_w := clampf(_pane_w - 238.0 - 90.0, 80.0, 300.0)
	v.add_child(MonsterPage._head("ABILITIES"))
	var top := float(BalanceDef.get_def().stat_max)
	for st in MonsterPage.STAT_COLS:
		var row: Control = MR4.stat_bar(st[0], m.stat(st[1]), top, st[2], bar_w)
		var was: float = float((before["stats"] as Dictionary).get(st[1], m.stat(st[1])))
		(row.get_child(2) as Label).text = "%d%s" % [m.stat(st[1]), _delta_text(m.stat(st[1]), was)]
		if m.stat(st[1]) > was:
			(row.get_child(2) as Label).add_theme_color_override("font_color", Color(0.2, 0.5, 0.2))
		v.add_child(row)
	v.add_child(MonsterPage._head("CONDITION"))
	var gauges := [["FATIGUE", m.fatigue, 999, Care.fatigue_word(m.fatigue), Color(0.9, 0.55, 0.2), before["fatigue"]],
		["STRESS", m.stress, 999, Care.stress_word(m.stress), Color(0.8, 0.35, 0.5), before["stress"]],
		["FULLNESS", m.fullness, 999, Care.fullness_word(m.fullness), Color(0.5, 0.7, 0.3), before["fullness"]],
		["BOND", m.bonding, 100, "", Color(0.9, 0.45, 0.55), before["bond"]]]
	for g in gauges:
		var row: Control = MonsterPage._gauge(g[0], g[1], g[2], g[3], g[4])
		var lab := row.get_child(2) as Label
		lab.text = ("%s%s" % [g[3], _delta_text(g[1], g[5])]) if g[3] != "" else "%d%s" % [g[1], _delta_text(g[1], g[5])]
		v.add_child(row)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	v.add_child(_command("CONTINUE", _close_results, true))


func _page_status(v: VBoxContainer, m: MonsterData) -> void:
	v.add_child(_title("STATUS"))
	var nm := MR4.ink(m.name, _f(32), false, "display")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var br := MR4.ink("%s   ·   %s type" % [m.breed_label(), str(m.type).capitalize()], _f(17), true)
	br.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(br)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 6)
	pips.add_child(MR4.ink("RANK %s" % m.rank, _f(20), false, "display"))
	for i in 3:
		var d := MR4.ink("◆" if i < m.rank_wins else "◇", _f(22), i >= m.rank_wins, "display")
		d.add_theme_color_override("font_color", MR4.RIBBON if i < m.rank_wins else MR4.INK_DIM)
		pips.add_child(d)
	v.add_child(pips)
	var months := int(m.age_weeks * 12.0 / 48.0)
	var age := MR4.ink("Age  %d years, %d months" % [months / 12, months % 12], _f(18), false, "display")
	age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(age)
	var bar_w := clampf(_pane_w - 238.0 - 90.0, 80.0, 300.0)
	v.add_child(MonsterPage._head("ABILITIES"))
	for st in MonsterPage.STAT_COLS:
		v.add_child(MR4.stat_bar(st[0], m.stat(st[1]), float(BalanceDef.get_def().stat_max), st[2], bar_w))
	v.add_child(MonsterPage._head("CONDITION"))
	v.add_child(MonsterPage._gauge("FATIGUE", m.fatigue, 999, Care.fatigue_word(m.fatigue), Color(0.9, 0.55, 0.2)))
	v.add_child(MonsterPage._gauge("STRESS", m.stress, 999, Care.stress_word(m.stress), Color(0.8, 0.35, 0.5)))
	v.add_child(MonsterPage._gauge("FULLNESS", m.fullness, 999, Care.fullness_word(m.fullness), Color(0.5, 0.7, 0.3)))
	v.add_child(MonsterPage._gauge("BOND", m.bonding, 100, "", Color(0.9, 0.45, 0.55)))
	if m.personality != "":
		var q := m.personality.capitalize()
		if not m.quirks.is_empty():
			q += "   ·   " + ", ".join(m.quirks).capitalize()
		var temper := MR4.ink("Temperament:  " + q, _f(21), false)
		temper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		temper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		temper.custom_minimum_size = Vector2(200, 0)
		v.add_child(temper)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	v.add_child(_command("BACK", func() -> void: _go_page("main")))


## The showcase: the selected kami stands in the yard in front of its pen, facing the camera, held still while you plan.
## The camera holds it in the middle of the left window (the screen position is measured, so it is right at any window size).
func _focus_camera() -> void:
	var cam = zone.get("cam")
	if not (cam is FollowCamera) or Game.monsters.is_empty() or not cam.is_inside_tree():
		return
	var body: MonsterBody = null
	for b in zone.get("bodies"):
		if b.data == Game.monsters[_selected]:
			body = b
	if body == null:
		return
	if _cam_saved.is_empty():
		if cam.has_meta("planner_orig"):   # another planner (the one that just ran training) already recorded the real camera
			_cam_saved = cam.get_meta("planner_orig")
		else:
			_cam_saved = {"target": cam.target, "distance": cam.distance, "look_height": cam.look_height, "pitch": cam.pitch_deg, "yaw": cam.yaw}
			cam.set_meta("planner_orig", _cam_saved)
	cam.ui_open = true
	if _page == "results":   # a cinematic overview of every kami where it stands; the trainer takes over again on CONTINUE
		_showcase = null
		_overview(cam)
		return
	_place_everyone()   # the whole roster stands at fixed spots in the yard; only the camera moves when you switch
	_showcase = body
	var away := _away_from_pen()
	cam.target = body
	cam.distance = 4.2   # close enough that only the selected kami is in frame
	cam.look_height = 1.0
	cam.pitch_deg = -6.0
	cam.yaw = atan2(away.x, away.z)


## The results view: every kami stands where it is (walking in place if it trained, still if it rested) and the camera
## looks over the group from a fixed three-quarter angle.
func _overview(cam: FollowCamera) -> void:
	if _focus == null or not is_instance_valid(_focus):
		_focus = Node3D.new()
		zone.add_child(_focus)
	_resume_wander()
	var trained: Dictionary = _results.get("trained", {})
	for b in zone.get("bodies"):
		for c in b.get_children():
			if c is WanderController:
				c.set_process(false)
				c.set_physics_process(false)
				_paused.append(c)
		b.move_dir = Vector3.ZERO
		var drilled: bool = bool(trained.get(b.data, false))
		b.in_place = 0.45 if drilled else 0.0
		MonsterModel.hold(b.model, "" if drilled else "Rest")
		_posed.append(b)
	_aim_overview()
	_focus.global_position = _overview_centre
	if cam.cam != null:
		cam.cam.v_offset = 0.0
	cam.target = _focus
	cam.distance = clampf(6.5 + _overview_spread * 1.3, 7.0, 20.0)
	cam.look_height = 0.6
	cam.pitch_deg = -17.0
	if not _overview_yaw_set:
		cam.yaw = atan2(_away_from_pen().x, _away_from_pen().z) + 0.6   # off to one side of the pen's open side: a three-quarter view
		_overview_yaw_set = true


func _aim_overview() -> void:   # centre and spread of the group
	var bodies: Array = zone.get("bodies")
	if bodies.is_empty():
		return
	var sum := Vector3.ZERO
	for b in bodies:
		sum += b.global_position
	_overview_centre = sum / float(bodies.size())
	_overview_spread = 0.0
	for b in bodies:
		_overview_spread = maxf(_overview_spread, b.global_position.distance_to(_overview_centre))


## Fixed spots in the yard in front of the pen, two to a row, side by side facing the camera (the barn is small for now).
func _yard_spot(i: int) -> Vector3:
	var away := _away_from_pen()
	var across := Vector3(-away.z, 0.0, away.x)
	var lane := 3.6 if i % 2 == 0 else -3.6   # far enough apart that the zoomed camera frames one kami at a time
	return _showcase_spot() + across * lane + away * (4.5 * float(i / 2))


func _place_everyone() -> void:
	if _placed:
		return
	_placed = true
	var bodies: Array = zone.get("bodies")
	for i in Game.monsters.size():
		for b in bodies:
			if b.data != Game.monsters[i]:
				continue
			var p := _yard_spot(i)
			b.global_position = Vector3(p.x, zone.ground(p.x, p.z) + 0.3, p.z)
			b.velocity = Vector3.ZERO
			b.move_dir = Vector3.ZERO
			for c in b.get_children():
				if c is WanderController:
					c.set_process(false)
					c.set_physics_process(false)
					_paused.append(c)
			_static.append(b)


func _away_from_pen() -> Vector3:   # the open side of the pen, where the camera stands
	var a: Vector3 = RanchLayout.home(0) - RanchLayout.SITES["pen"][1]
	a.y = 0.0
	return a.normalized()


func _showcase_spot() -> Vector3:   # in the yard in front of the pen, clear of its deck
	return RanchLayout.SITES["pen"][1] + _away_from_pen() * 5.2


func _process(delta: float) -> void:   # the showcased kami faces the camera and is held in the middle of the left window
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # the cursor stays available for the menu
	var cam = zone.get("cam") if zone != null else null
	if not (cam is FollowCamera) or cam.cam == null:
		return
	var subject: Node3D = null
	var height := 1.0
	if _page == "results" and _focus != null and is_instance_valid(_focus):
		_aim_overview()
		_focus.global_position = _focus.global_position.lerp(_overview_centre, 1.0 - exp(-4.0 * delta))
		for b in _posed:   # everyone faces the screen, not each other
			if is_instance_valid(b):
				var look: Vector3 = cam.cam.global_position - b.global_position
				look.y = 0.0
				if look.length() > 0.1:
					b.face_dir = look.normalized()
		subject = _focus
		height = 0.6
	elif _showcase != null and is_instance_valid(_showcase):
		for b in _static:
			if is_instance_valid(b):
				var to: Vector3 = cam.cam.global_position - b.global_position
				to.y = 0.0
				if to.length() > 0.1:
					b.face_dir = to.normalized()
		subject = _showcase
	if subject == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var mid: Vector3 = subject.global_position + Vector3(0, height, 0)
	if cam.cam.is_position_behind(mid):
		return
	var sx: float = cam.cam.unproject_position(mid).x
	var width: float = 2.0 * maxf(cam.cam.global_position.distance_to(mid), 0.5) * tan(deg_to_rad(cam.cam.fov * 0.5)) * (vp.x / maxf(vp.y, 1.0))
	# a positive frame_offset slides the view right, which moves the subject left on screen
	cam.frame_offset = clampf(cam.frame_offset + (sx - vp.x * LEFT_FRAC * 0.5) / maxf(vp.x, 1.0) * width * 0.3, -12.0, 12.0)


var _selected := 0
var _cam_saved := {}
var _paused: Array = []        # wander controllers held still while a kami is showcased
var _showcase: MonsterBody
var _placed := false
var _static: Array = []         # kami standing at their fixed spots while you plan
var _focus: Node3D              # what the results camera follows: the middle of the group
var _posed: Array = []          # kami held in a drill or rest pose for the results view
var _overview_centre := Vector3.ZERO
var _overview_spread := 0.0
var _overview_yaw_set := false


func _resume_wander() -> void:
	if _showcase != null and is_instance_valid(_showcase):
		_showcase.in_place = 0.0
		MonsterModel.hold(_showcase.model, "")
	for b in _posed:
		if is_instance_valid(b):
			b.in_place = 0.0
			MonsterModel.hold(b.model, "")
	_posed.clear()
	_static.clear()
	for c in _paused:
		if is_instance_valid(c):
			c.set_process(true)
			c.set_physics_process(true)
	_paused.clear()
	_showcase = null


## Another planner or results screen still on screen (this one is going away): leave the camera and the kami to it.
func _another_planner() -> bool:
	if zone == null or not is_instance_valid(zone) or zone.get("hud_root") == null:
		return false
	for c in zone.hud_root.get_children():
		if c != self and c is WeekPlanner and not c.is_queued_for_deletion():
			return true
	return false


func _restore_camera() -> void:
	if _another_planner():
		return
	_resume_wander()
	var cam = zone.get("cam") if zone != null else null
	if not (cam is FollowCamera) or not is_instance_valid(cam):
		return
	var saved: Dictionary = _cam_saved if not _cam_saved.is_empty() else (cam.get_meta("planner_orig") if cam.has_meta("planner_orig") else {})
	if saved.is_empty():
		return
	cam.target = saved["target"]
	cam.distance = saved["distance"]
	cam.look_height = saved["look_height"]
	cam.pitch_deg = saved["pitch"]
	cam.yaw = saved.get("yaw", cam.yaw)
	cam.frame_offset = 0.0
	cam.ui_open = false
	if cam.has_meta("planner_orig"):
		cam.remove_meta("planner_orig")
	cam.global_position = cam.target.global_position + Vector3(0, cam.look_height, 0)   # snap: the fade hides the move
	if cam.get("_arm") != null:
		cam._arm.spring_length = cam.distance
	_cam_saved = {}


func _exit_tree() -> void:
	_restore_camera()


func _input(e: InputEvent) -> void:
	if visible and e is InputEventMouseButton and (e as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		get_viewport().set_input_as_handled()   # the wheel does nothing here (it used to reach the camera and grab the mouse)
		return
	# switch between kami from the keyboard (before button focus takes the arrows)
	if not visible or Game.monsters.size() < 2 or not (e is InputEventKey and e.pressed and not e.echo):
		return
	var step := 0
	match (e as InputEventKey).keycode:
		KEY_LEFT, KEY_UP:
			step = -1
		KEY_RIGHT, KEY_DOWN:
			step = 1
	if step != 0:
		_selected = posmod(_selected + step, Game.monsters.size())
		_build()
		get_viewport().set_input_as_handled()
var _slot := 0   # which planned week (0 = this week .. 7) the drill cards edit


func _event_text() -> String:
	var en := Schedule.entry_now()
	var life := ""   # how long a kami will live is never shown
	if not en.is_empty():
		return "THIS WEEK: %s fights in the %s. Leave for it from your house at the weekend." % [en["monster"], en["name"]] + life
	var soon := _next_entry()
	if not soon.is_empty():
		return "Coming up: %s in the %s (%s)." % [soon["monster"], soon["name"], GameCalendar.label_of(int(soon["week"]))] + life
	return "No event this week. Train hard, or sign up for an upcoming cup." + life


## Every kami listed equally on the left (name, rank, condition, current drill); the drill grid on the right is for
## whichever row is selected. No portraits: this screen is about the week.
## Eight week slots: pick a slot, then pick a drill for it. "Same for all" fills up to eight weeks; unplanned weeks rest.
func _plan_row(m: MonsterData) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var row := GridContainer.new()
	row.columns = 8 if _pane_w >= 860.0 else 4
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	for i in Training.MAX_PLAN_WEEKS:
		var e := Training.entry_now_at(m, i)
		var d := Training.find(e.split(":")[0]) if e != "" else null
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, _f(60))
		b.text = "W%d  %s" % [i + 1, (d.display_name.left(9) if d != null else "Rest")]
		b.add_theme_font_size_override("font_size", _f(16))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.96, 0.82) if i == _slot else MR4.PAPER_DARK
		sb.border_color = MR4.RIBBON if i == _slot else MR4.WOOD_LIGHT
		sb.set_border_width_all(3 if i == _slot else 1)
		sb.set_corner_radius_all(3)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", MR4.INK)
		b.add_theme_color_override("font_hover_color", MR4.INK)
		b.add_theme_color_override("font_pressed_color", MR4.INK)
		b.pressed.connect(func() -> void:
			_slot = i
			_build())
		row.add_child(b)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	vb.add_child(tools)
	var same := Button.new()
	same.text = "SAME FOR 8 WEEKS"
	same.focus_mode = Control.FOCUS_NONE
	same.add_theme_font_size_override("font_size", _f(17))
	same.pressed.connect(func() -> void:
		Training.fill_plan(m, Training.entry_now_at(m, _slot), Training.MAX_PLAN_WEEKS)
		Save.write()
		_build())
	tools.add_child(same)
	var clear := Button.new()
	clear.text = "CLEAR PLAN"
	clear.focus_mode = Control.FOCUS_NONE
	clear.add_theme_font_size_override("font_size", _f(17))
	clear.pressed.connect(func() -> void:
		m.schedule = []
		_slot = 0
		Save.write()
		_build())
	tools.add_child(clear)
	return vb


func _drill_card(m: MonsterData, title: String, stat: String, info: String, on: bool, locked: bool, code: String) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, _f(100))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(1.0, 0.96, 0.82) if st == "hover" else MR4.PAPER_DARK
		s.border_color = MR4.RIBBON if on else MR4.WOOD_LIGHT
		s.set_border_width_all(4 if on else 2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 12
		s.content_margin_right = 10
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, s)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12
	vb.offset_top = 7
	vb.offset_right = -8
	vb.add_theme_constant_override("separation", 1)
	b.add_child(vb)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	head.add_child(MR4.ink(title.to_upper(), _f(20), false, "display"))
	var sub := MR4.ink(("%s   ·   " % stat.to_upper() if stat != "" else "") + info, _f(14), true)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(120, 0)
	if stat != "":
		sub.add_theme_color_override("font_color", MonsterPage.stat_color(stat).darkened(0.3))
	vb.add_child(sub)
	for c in vb.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func() -> void:
		Sound.sfx("click", -10.0)
		Training.set_slot(m, _slot, code)
		_slot = mini(_slot + 1, Training.MAX_PLAN_WEEKS - 1) if _slot < m.schedule.size() else _slot
		Save.write()
		_build())
	return b


func _next_entry() -> Dictionary:
	var best := {}
	for en in Game.entries:
		if int(en["week"]) > Game.week and (best.is_empty() or int(en["week"]) < int(best["week"])):
			best = en
	return best


func _drill_name(m: MonsterData) -> String:
	if m.schedule.is_empty() or str(m.schedule[0]) == "":
		return "rest"
	var id := str(m.schedule[0]).split(":")[0]
	for d in Training.all():
		if str(d.id) == id:
			return d.display_name
	return id


## The drill list comes up over the planner; picking one (or backing out) returns here.
func _change_drill(m: MonsterData) -> void:
	Sound.sfx("click", -10.0)
	visible = false
	zone.set_meta("planner", self)
	zone._plan(m)


func _open_calendar() -> void:
	Sound.sfx("click", -10.0)
	visible = false
	zone.set_meta("planner", self)
	CalendarPanel.open(zone)


## Called by the zone when a menu or the calendar it opened from here closes.
func resume() -> void:
	zone.remove_meta("planner")
	_build()
	visible = true
	zone.in_menu = true
	zone.trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _leave() -> void:
	Sound.sfx("click", -10.0)
	Game.planned_week = Game.week
	Save.write()
	Scenes.transition(_start_training)   # fade to black, then the week's drills run and the results come up over the trainer's view


func _start_training() -> void:
	zone.in_menu = false
	zone.free_trainer()
	queue_free()
	if Game.trained_week != Game.week and zone.has_method("run_training"):
		zone.run_training()
