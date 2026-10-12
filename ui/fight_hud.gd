class_name FightHud
extends CanvasLayer
## Fighting-game HUD, drawn in code (ported from ChipMon). The arena feeds it; it only reads.
##   hud.set_fighters(player, foe); hud.set_round(i, total, won, title)
##   hud.banner("ROUND 1", "SUB TEXT", color); hud.show_result(won, rounds_won, total, hint)

var player: MonsterBody
var foe: MonsterBody
var round_i := 0
var rounds_total := 1
var rounds_won := 0
var title := ""
var _view: _View


func _ready() -> void:
	layer = 2
	_view = _View.new()
	_view.hud = self
	add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_fighters(p: MonsterBody, f: MonsterBody) -> void:
	player = p
	foe = f
	_view.ghost_f = 1.0


func set_round(i: int, total: int, won: int, p_title: String = "") -> void:
	round_i = i
	rounds_total = total
	rounds_won = won
	if p_title != "":
		title = p_title


func banner(txt: String, sub: String, col: Color = UIStyle.TEXT) -> void:
	_view.banner = txt
	_view.banner_sub = sub
	_view.banner_col = col
	_view.banner_t = 0.0


func show_result(won: bool, p_rounds_won: int, total: int, hint: String) -> void:
	rounds_won = p_rounds_won
	rounds_total = total
	_view.result = "VICTORY" if won else "DEFEAT"
	_view.result_won = won
	_view.result_hint = hint
	_view.result_t = 0.0


class _View extends Control:
	var hud: FightHud
	var ghost_p := 1.0
	var ghost_f := 1.0
	var banner := ""
	var banner_sub := ""
	var banner_col := Color.WHITE
	var banner_t := 99.0
	var result := ""
	var result_won := false
	var result_hint := ""
	var result_t := 0.0
	var clock := 0.0
	var f_disp: Font
	var f_mono: Font
	var sb_panel: StyleBoxTexture
	var sb_small: StyleBoxTexture
	var sb_trough: StyleBoxTexture
	var sb_ribbon: StyleBoxTexture

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		f_disp = UIStyle.font("display")
		f_mono = UIStyle.font("mono")
		sb_panel = UIStyle.tex_box("panel_dark", 20)
		sb_small = UIStyle.tex_box("panel_dark", 14)
		sb_trough = UIStyle.tex_box("bar_trough", 11)
		sb_ribbon = UIStyle.tex_box("ribbon", 34)

	func _process(delta: float) -> void:
		clock += delta
		banner_t += delta
		result_t += delta
		ghost_p = _ghost(hud.player, ghost_p, delta)
		ghost_f = _ghost(hud.foe, ghost_f, delta)
		queue_redraw()

	## The white "recent damage" bar drains toward real HP after a short delay.
	func _ghost(b: MonsterBody, g: float, delta: float) -> float:
		if b == null or not is_instance_valid(b):
			return g
		var f := b.health.fraction()
		return f if g < f else move_toward(g, f, delta * 0.5)

	func _para(x: float, y: float, w: float, h: float, sk: float, col: Color) -> void:
		if w <= 0.0:
			return
		draw_colored_polygon(PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h)]), col)

	func _txt(f: Font, x: float, y: float, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var xx := x
		var w := -1.0
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			xx = x - 600.0
			w = 1200.0
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			xx = x - 1200.0
			w = 1200.0
		draw_string(f, Vector2(xx, y), s, align, w, sz, col)

	func _plate(b: MonsterBody, ghost: float, right: bool) -> void:
		if b == null or not is_instance_valid(b):
			return
		var w := minf(460.0, size.x * 0.36)
		var x := 28.0 if not right else size.x - 28.0 - w
		var y := 22.0
		var sk := -12.0 if not right else 12.0
		var col := Types.glow(b.data.type)
		draw_style_box(sb_panel, Rect2(x - 6.0, y - 6.0, w + 12.0, 92.0))
		_para(x + (w - 70.0 if right else 6.0), y + 64.0, 64.0, 3.0, 0.0, col)  # type tag
		var nm := b.data.breed_label().to_upper()
		var tp := "%s  %s" % [b.data.type.to_upper(), b.data.main_def().body_class.to_upper()]
		var hp_s := "%d / %d" % [b.health.hp, b.health.max_hp]
		# name + HP on top, the bar, then type/class under the bar
		if not right:
			_txt(f_disp, x + 16.0, y + 34.0, nm, 26, UIStyle.TEXT)
			_txt(f_mono, x + w - 16.0, y + 33.0, hp_s, 14, UIStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
			_txt(f_mono, x + 16.0, y + 74.0, tp, 11, col)
		else:
			_txt(f_disp, x + w - 16.0, y + 34.0, nm, 26, UIStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
			_txt(f_mono, x + 16.0, y + 33.0, hp_s, 14, UIStyle.DIM)
			_txt(f_mono, x + w - 16.0, y + 74.0, tp, 11, col, HORIZONTAL_ALIGNMENT_RIGHT)
		var bx := x + 14.0
		var bw := w - 28.0
		var by := y + 44.0
		var bh := 14.0
		var bsk := sk * 0.2
		var frac := b.health.fraction()
		var fill := col
		if frac < 0.3:
			fill = UIStyle.BAD.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(clock * 12.0)))
		draw_style_box(sb_trough, Rect2(bx - 3.0, by - 3.0, bw + 6.0, bh + 6.0))
		var gx := bx if not right else bx + bw * (1.0 - ghost)
		draw_rect(Rect2(gx, by + 1.0, bw * ghost, bh - 2.0), Color(1, 1, 1, 0.7))
		var fx := bx if not right else bx + bw * (1.0 - frac)
		draw_rect(Rect2(fx, by + 1.0, bw * frac, bh - 2.0), fill)
		draw_rect(Rect2(fx, by + 1.0, bw * frac, (bh - 2.0) * 0.4), Color(1, 1, 1, 0.25))  # gloss
		for i in range(1, 10):
			var tx := bx + bw * float(i) / 10.0
			draw_line(Vector2(tx, by), Vector2(tx, by + bh), Color(UIStyle.BG, 0.5), 2.0)
		if right and hud.player != null:
			var mult := Types.mult(b.data.type, hud.player.data.type)
			if mult != 1.0:
				var warn := ("TYPE ADVANTAGE  x%.1f" if mult > 1.0 else "WEAK VS YOU  x%.1f") % mult
				_txt(f_mono, x + w - 16.0, y + 100.0, warn, 12, UIStyle.BAD if mult > 1.0 else UIStyle.GOOD, HORIZONTAL_ALIGNMENT_RIGHT)

	func _center() -> void:
		var cx := size.x * 0.5
		draw_style_box(sb_panel, Rect2(cx - 116.0, 8.0, 232.0, 94.0))
		_txt(f_mono, cx, 34.0, hud.title.to_upper(), 12, UIStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(f_disp, cx, 66.0, "ROUND %d" % mini(hud.round_i + 1, hud.rounds_total), 30, UIStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var n := hud.rounds_total
		for i in n:
			var c := Vector2(cx + (float(i) - float(n - 1) * 0.5) * 22.0, 84.0)
			var col := Color(0.35, 0.22, 0.16)
			if i < hud.rounds_won:
				col = UIStyle.ACCENT
			elif i == hud.round_i:
				col = Color(1, 1, 1, 0.6 + 0.4 * sin(clock * 5.0))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), col)

	func _slot(x: float, y: float, key: String, nm: String, cd: float, maxcd: float, col: Color, active: bool) -> void:
		var w := 132.0
		var h := 50.0
		var ready := cd <= 0.0
		draw_style_box(sb_small, Rect2(x - 3.0, y - 3.0, w + 6.0, h + 6.0))
		if not ready:
			var k := clampf(1.0 - cd / maxf(maxcd, 0.01), 0.0, 1.0)
			draw_rect(Rect2(x + 4.0, y + 4.0 + (h - 8.0) * (1.0 - k), w - 8.0, (h - 8.0) * k), Color(col, 0.2))
		if active:
			draw_rect(Rect2(x + 4.0, y + 4.0, w - 8.0, h - 8.0), Color(col, 0.35))
		draw_rect(Rect2(x + 8.0, y + h - 4.0, w - 16.0, 2.0), UIStyle.LINE_HI if ready else Color(0.3, 0.2, 0.15))
		_txt(f_mono, x + 14.0, y + 17.0, key, 11, col if ready else UIStyle.DIM)
		_txt(f_disp, x + 14.0, y + 40.0, nm.to_upper(), 20, UIStyle.TEXT if ready else Color(0.55, 0.45, 0.38))

	func _slots() -> void:
		var p := hud.player
		var at := p.get_node("Attacker") as Attacker
		var sx := size.x * 0.5 - (4.0 * 132.0 + 3.0 * 14.0) * 0.5
		var sy := size.y - 72.0
		var strike := at.get_move(&"strike")
		var blast := at.get_move(&"blast")
		var busy := 9.0 if at.is_busy() else 0.0
		_slot(sx, sy, "SPACE", "Dodge", p.dodge_cooldown_left(), MonsterBody.DODGE_CD, Color(0.6, 0.85, 1.0), false)
		_slot(sx + 146.0, sy, "J / LMB", "Strike", maxf(at.cooldown_left(&"strike"), minf(busy, 0.01)), strike.cooldown, Color(1.0, 0.75, 0.3), false)
		_slot(sx + 292.0, sy, "K / RMB", "Blast", at.cooldown_left(&"blast"), blast.cooldown, Types.glow(p.data.type), false)
		_slot(sx + 438.0, sy, "L / SHIFT", "Guard", 0.0, 1.0, Color(0.45, 1.0, 0.65), p.guarding)

	## Diamond marker over the locked-on enemy.
	func _lock_marker() -> void:
		var p := hud.player
		if p.face_target == null or not is_instance_valid(p.face_target):
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var wp := p.face_target.global_position + Vector3(0, 3.2, 0)
		if cam.is_position_behind(wp):
			return
		var c := cam.unproject_position(wp)
		var r := 9.0 + 2.0 * sin(clock * 6.0)
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
		draw_polyline(pts, UIStyle.ACCENT, 2.0, true)
		draw_circle(c, 2.5, UIStyle.ACCENT)

	func _draw() -> void:
		if hud.player == null or not is_instance_valid(hud.player):
			return
		_plate(hud.player, ghost_p, false)
		_plate(hud.foe, ghost_f, true)
		_center()
		_slots()
		_lock_marker()
		if banner_t < 1.8 and banner != "":
			var k := banner_t / 1.8
			var al := clampf(banner_t / 0.12, 0.0, 1.0) * clampf((1.8 - banner_t) / 0.35, 0.0, 1.0)
			var punch := 1.0 + 0.6 * exp(-banner_t * 14.0)
			var cy := size.y * 0.42
			var lw := size.x * (0.2 + 0.25 * minf(1.0, banner_t * 4.0))
			draw_rect(Rect2(0, cy - 62.0, size.x, 96.0), Color(0, 0, 0, 0.45 * al))
			draw_line(Vector2(size.x * 0.5 - lw, cy - 62.0), Vector2(size.x * 0.5 + lw, cy - 62.0), Color(banner_col, al), 2.0)
			draw_line(Vector2(size.x * 0.5 - lw, cy + 34.0), Vector2(size.x * 0.5 + lw, cy + 34.0), Color(banner_col, al), 2.0)
			_txt(f_disp, size.x * 0.5 + (k - 0.5) * 30.0, cy + 10.0, banner, int(72.0 * punch), Color(banner_col, al), HORIZONTAL_ALIGNMENT_CENTER)
			_txt(f_mono, size.x * 0.5, cy + 58.0, banner_sub, 14, Color(1, 1, 1, 0.7 * al), HORIZONTAL_ALIGNMENT_CENTER)
		if result != "":
			var al2 := clampf(result_t / 0.4, 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65 * al2))
			var hc := UIStyle.TEXT if result_won else UIStyle.BAD
			var cy2 := size.y * 0.45
			var punch2 := 1.0 + 0.5 * exp(-result_t * 10.0)
			sb_ribbon.modulate_color = Color(1, 1, 1, al2) if result_won else Color(0.55, 0.6, 0.75, al2)
			draw_style_box(sb_ribbon, Rect2(size.x * 0.5 - 420.0, cy2 - 120.0, 840.0, 190.0))
			_txt(f_disp, size.x * 0.5, cy2 + 20.0, result, int(130.0 * punch2), Color(hc, al2), HORIZONTAL_ALIGNMENT_CENTER)
			if hud.rounds_total > 1:
				_txt(f_mono, size.x * 0.5, cy2 + 92.0, "ROUNDS WON  %d / %d" % [hud.rounds_won, hud.rounds_total], 18, Color(1, 1, 1, al2), HORIZONTAL_ALIGNMENT_CENTER)
			_txt(f_mono, size.x * 0.5, cy2 + 140.0, result_hint, 15, Color(1, 1, 1, al2 * (0.55 + 0.45 * sin(clock * 4.0))), HORIZONTAL_ALIGNMENT_CENTER)
