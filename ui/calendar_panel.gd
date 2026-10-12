class_name CalendarPanel
extends Control
## The Association's event calendar: one month at a time, four week columns, each event a card (rank badge,
## regular cup or Promotion Match, entry fee, prize, who's signed up). Click a card to sign a kami up.
##   CalendarPanel.open(zone)

const COL_W := 250.0
var zone
var month_off := 0  # 0 = this month .. 2 (sign-ups open three months ahead)
var _body: Control


static func open(z) -> CalendarPanel:
	var c := CalendarPanel.new()
	c.zone = z
	z.hud_root.add_child(c)
	z.in_menu = true
	z.trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	theme.set_constant("outline_size", "Label", 0)   # parchment text has no dark outline
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	_draw_month()


func _month() -> int:
	return (Schedule.month_of(Game.week) + month_off) % 12


const PAPER := Color(0.93, 0.88, 0.76)
const PAPER_DARK := Color(0.82, 0.74, 0.58)
const INK := Color(0.2, 0.13, 0.08)
const INK_DIM := Color(0.42, 0.32, 0.22)
const STAMP := Color(0.72, 0.13, 0.08)
const RANK_COL := {"E": Color(0.45, 0.42, 0.38), "D": Color(0.25, 0.48, 0.3), "C": Color(0.22, 0.38, 0.62),
	"B": Color(0.52, 0.28, 0.6), "A": Color(0.72, 0.42, 0.12), "S": Color(0.7, 0.12, 0.1)}


## A paper wall calendar: twelve month tabs across the top, the month in big brush letters, four week rows with
## the events stamped in, this week circled in red.
func _draw_month() -> void:
	for c in _body.get_children():
		c.queue_free()
	var vs := get_viewport_rect().size
	var w := minf(1180.0, vs.x - 60.0)
	var page := PanelContainer.new()
	var sb := MR4.frame_style()
	sb.content_margin_left = 50
	sb.content_margin_right = 50
	sb.content_margin_top = 34
	sb.content_margin_bottom = 30
	page.add_theme_stylebox_override("panel", sb)
	page.position = Vector2((vs.x - w) / 2.0, 14)
	page.custom_minimum_size = Vector2(w, vs.y - 28)
	page.size = page.custom_minimum_size
	page.clip_contents = true
	_body.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	page.add_child(v)
	# month tabs
	var tabs := HBoxContainer.new()
	tabs.clip_contents = true
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	var now_m := Schedule.month_of(Game.week)
	for i in 12:
		var mi := (now_m + i) % 12
		var t := Button.new()
		t.text = GameCalendar.MONTHS[mi].replace("Early ", "E.").replace("Late ", "L.")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_font_size_override("font_size", 12)
		var ts := StyleBoxFlat.new()
		ts.bg_color = STAMP if i == month_off else (PAPER_DARK if i < 3 else PAPER_DARK.darkened(0.15))
		ts.set_corner_radius_all(3)
		t.add_theme_stylebox_override("normal", ts)
		t.add_theme_stylebox_override("hover", ts)
		t.add_theme_stylebox_override("disabled", ts)
		t.add_theme_color_override("font_color", PAPER if i == month_off else INK)
		t.add_theme_color_override("font_disabled_color", INK_DIM)
		t.disabled = i > 2  # sign-ups open three months ahead
		var idx := i
		t.pressed.connect(func(): month_off = idx; Sound.sfx("click", -10.0); _draw_month())
		tabs.add_child(t)
	var head := HBoxContainer.new()
	v.add_child(head)
	var big := MR4.lab(GameCalendar.MONTHS[_month()], 54, INK, "display")
	big.remove_theme_constant_override("outline_size")
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(big)
	var yr := (Game.week - 1) / 48 + 1 + ((now_m + month_off) / 12)
	var meta := MR4.lab("Year %d\nyour rank %s  ·  %d G" % [yr, Game.rank, Game.money], 16, INK_DIM, "body")
	meta.remove_theme_constant_override("outline_size")
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(meta)
	var events := Schedule.events_in(_month())
	for wk in range(1, 5):
		var aw := Schedule.abs_week(_month(), wk, Game.week)
		var now := aw == Game.week
		var past := month_off == 0 and Schedule.week_of_year(Game.week) % 4 + 1 > wk
		var row := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = PAPER.lightened(0.05) if not past else PAPER_DARK.lightened(0.1)
		rs.border_color = STAMP if now else Color(0.6, 0.5, 0.36)
		rs.set_border_width_all(4 if now else 1)
		rs.set_corner_radius_all(18 if now else 2)  # this week: circled in red
		rs.content_margin_left = 12
		rs.content_margin_right = 12
		rs.content_margin_top = 6
		rs.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", rs)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(row)
		var hrow := HBoxContainer.new()
		hrow.add_theme_constant_override("separation", 12)
		row.add_child(hrow)
		var day := VBoxContainer.new()
		day.custom_minimum_size = Vector2(120, 0)
		hrow.add_child(day)
		var h := HFlowContainer.new()  # the week's events wrap onto a second line when there are many
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("h_separation", 10)
		h.add_theme_constant_override("v_separation", 6)
		hrow.add_child(h)
		var wl := MR4.lab("WEEK %d" % wk, 26, STAMP if now else INK, "display")
		wl.remove_theme_constant_override("outline_size")
		day.add_child(wl)
		var sub := MR4.lab("this week" if now else ("passed" if past else ""), 13, STAMP if now else INK_DIM, "body")
		sub.remove_theme_constant_override("outline_size")
		day.add_child(sub)
		var any := false
		for e in events:
			if int(e["week"]) == wk:
				h.add_child(_card(e, aw, past))
				any = true
		if not any:
			var quiet := MR4.lab("—  no events  —", 15, INK_DIM, "body")
			quiet.remove_theme_constant_override("outline_size")
			quiet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(quiet)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	var hint := MR4.lab("Click an event to sign a kami up. It fights that week: leave for it from your house at the weekend.", 14, INK_DIM, "body")
	hint.remove_theme_constant_override("outline_size")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var close := Button.new()
	close.text = "  CLOSE  "
	UIStyle.make_primary(close)
	close.pressed.connect(_close)
	foot.add_child(close)


## One event, stamped onto its week: a rank seal, the name, fee / prize or who's signed up.
func _card(e: Dictionary, aw: int, past: bool) -> Control:
	var promo: bool = e["kind"] == "promotion"
	var cup: CupDef = e["cup"]
	var reg := Schedule.registered(e["id"], aw)
	var b := Button.new()
	b.custom_minimum_size = Vector2(232, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.97, 0.88) if not promo else Color(0.98, 0.9, 0.62)
	sb.border_color = STAMP if promo else Color(0.55, 0.45, 0.32)
	sb.set_border_width_all(3 if promo else 1)
	sb.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.border_color = STAMP
	hov.set_border_width_all(3)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("disabled", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.add_theme_constant_override("separation", 10)
	b.add_child(h)
	var seal := Label.new()  # the rank, as a round ink seal
	seal.text = str(e["rank"])
	seal.custom_minimum_size = Vector2(42, 42)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_override("font", UIStyle.font("display"))
	seal.add_theme_font_size_override("font_size", 24)
	seal.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	var ss := StyleBoxFlat.new()
	ss.bg_color = RANK_COL.get(e["rank"], INK)
	ss.set_corner_radius_all(6)
	seal.add_theme_stylebox_override("normal", ss)
	h.add_child(seal)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(info)
	var nm := MR4.lab(str(e["name"]).replace(" Promotion Match", " Promotion"), 16, STAMP if promo else INK, "display")
	nm.remove_theme_constant_override("outline_size")
	info.add_child(nm)
	var status := "entry %d G  ·  prize %d G" % [cup.entry_fee, cup.prize]
	var col := INK_DIM
	if not reg.is_empty():
		status = "SIGNED UP: %s" % reg["monster"]
		col = Color(0.15, 0.45, 0.2)
	elif past:
		status = "already held"
	var st := MR4.lab(status, 13, col, "body")
	st.remove_theme_constant_override("outline_size")
	info.add_child(st)
	b.disabled = past and reg.is_empty()
	b.pressed.connect(func(): _pick(e, aw))
	return b


func _pick(e: Dictionary, aw: int) -> void:
	Sound.sfx("click", -10.0)
	var reg := Schedule.registered(e["id"], aw)
	if not reg.is_empty():
		_ask("WITHDRAW %s?" % str(reg["monster"]).to_upper(), [["WITHDRAW", "No refund of the entry fee.", func():
			Game.entries.erase(reg)
			Save.write()
			_draw_month()]])
		return
	var opts: Array = []
	for m in Game.monsters:
		var busy := false
		for en in Game.entries:
			if int(en["week"]) == aw and en["monster"] == m.name:
				busy = true
		var ok := Schedule.eligible(e, m) and not busy
		var why := "rank %s" % m.rank if ok else ("already entered that week" if busy else (("needs rank %s" % e["rank"]) if e["kind"] == "promotion" and m.rank != e["rank"] else ("needs %d rank-%s cup wins (has %d)" % [Schedule.WINS_TO_PROMOTE, m.rank, m.rank_wins] if e["kind"] == "promotion" else "rank too low")))
		opts.append([m.name.to_upper(), why, (func(): _register(e, aw, m)) if ok else Callable()])
	if opts.is_empty():
		zone.toast("You have no kami to enter.")
		return
	_ask("WHO ENTERS THE %s?" % str(e["name"]).to_upper(), opts)


func _register(e: Dictionary, aw: int, m: MonsterData) -> void:
	var cup: CupDef = e["cup"]
	if not Game.spend(cup.entry_fee):
		zone.toast("The entry fee is %d G." % cup.entry_fee)
		return
	Game.entries.append({"event": e["id"], "name": e["name"], "week": aw, "monster": m.name, "kind": e["kind"], "month": e["month"]})
	Save.write()
	Sound.sfx("coin", -8.0)
	zone.toast("%s is signed up for the %s (week %d)." % [m.name, e["name"], e["week"]])
	_draw_month()


## A small choice list floating over the calendar.
func _ask(title: String, opts: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	p.position = get_viewport_rect().size / 2.0 - Vector2(280, 160)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(MR4.lab(title, 22, UIStyle.ACCENT, "display"))
	for o in opts + [["BACK", "", Callable()]]:
		var b := Button.new()
		b.text = "%s     %s" % [o[0], o[1]] if str(o[1]) != "" else str(o[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(540, 40)
		var fn: Callable = o[2]
		b.disabled = not fn.is_valid() and o[0] != "BACK"
		b.pressed.connect(func():
			dim.queue_free()
			if fn.is_valid():
				fn.call())
		v.add_child(b)


func _close() -> void:
	zone.in_menu = false
	zone.free_trainer()
	queue_free()
	if zone.has_meta("planner"):  # opened from the start-of-week planner: go back to it
		(zone.get_meta("planner") as WeekPlanner).resume()


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
