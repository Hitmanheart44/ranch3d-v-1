class_name HomeMenu
extends Node3D
## The MR4-style home screen: your kami asleep on their beds in the stable, a camera that cycles between them, and the
## command column (training, calendar, kami, encyclopedia, trainer, shrine, association, settings, go outside).
## It is also the "host" the shared pages talk to (hud_root, in_menu, trainer.frozen, toast(), run_training()), so the week
## planner and calendar open here unchanged. Opens by itself at the start of every week (ranch_v2 sends you here).
##   Scenes.goto("res://ranch/home_menu.tscn")

const BODY := preload("res://monsters/monster_body.tscn")
const SLOTS := [Vector3(-3.6, 0, -1.2), Vector3(-1.2, 0, -1.9), Vector3(1.2, 0, -1.9), Vector3(3.6, 0, -1.2), Vector3(0, 0, 0.6)]

class Frozen:
	var frozen := false

var hud_root: Control
var in_menu := false
var trainer := Frozen.new()
var page: Control
var bodies: Array[MonsterBody] = []
var sel := 0
var cam: Camera3D
var _card: PanelContainer
var _toast: Label
var _buttons: VBoxContainer
var _t := 0.0


func _ready() -> void:
	_room()
	for i in mini(Game.monsters.size(), SLOTS.size()):
		_bed(i)
	_ui()
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.make_current()
	_aim(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.planned_week != Game.week and not Game.monsters.is_empty():
		_open_training.call_deferred()


func _room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.03, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.82, 0.6)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = Quality.glow()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var wood := Build.mat("planks012", Vector3(2, 2, 1), Color(0.78, 0.6, 0.42))
	var dark := Build.mat("planks012", Vector3(1, 3, 1), Color(0.5, 0.36, 0.24))
	Build.box(self, Vector3(0, -0.15, 0), Vector3(16, 0.3, 11), wood, true)
	Build.box(self, Vector3(0, 2.5, -5.2), Vector3(16, 5.2, 0.3), dark)
	Build.box(self, Vector3(-8, 2.5, 0), Vector3(0.3, 5.2, 11), dark)
	Build.box(self, Vector3(8, 2.5, 0), Vector3(0.3, 5.2, 11), dark)
	for x in [-6.0, -2.0, 2.0, 6.0]:   # roof beams and posts
		Build.box(self, Vector3(x, 5.0, -2.0), Vector3(0.3, 0.35, 7.0), dark)
		Build.box(self, Vector3(x, 2.4, -4.9), Vector3(0.35, 4.8, 0.35), dark)
	var glow := Build.mat("", Vector3.ONE, Color(1.0, 0.82, 0.55), 2.2)
	Build.box(self, Vector3(0, 3.0, -5.02), Vector3(3.0, 1.6, 0.06), glow)   # a window: warm light from outside
	var sun := SpotLight3D.new()
	sun.position = Vector3(0, 3.0, -4.6)
	sun.rotation_degrees = Vector3(-18, 0, 0)
	sun.light_color = Color(1.0, 0.86, 0.62)
	sun.light_energy = 6.0
	sun.spot_range = 14.0
	sun.spot_angle = 55.0
	sun.shadow_enabled = Quality.shadows()
	add_child(sun)
	for x in [-5.0, 5.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 3.2, 0.5)
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 1.4
		l.omni_range = 9.0
		add_child(l)
		Build.box(self, l.position + Vector3(0, 0.3, 0), Vector3(0.28, 0.4, 0.28), glow)


func _bed(i: int) -> void:
	var p: Vector3 = SLOTS[i]
	var hay := Build.mat("", Vector3.ONE, Color(0.86, 0.72, 0.38))
	var mound := Build.cyl(self, p + Vector3(0, 0.1, 0), 1.45, 1.6, 0.22, hay, false, 18)
	mound.scale.y = 1.0
	Build.cyl(self, p + Vector3(0, 0.03, 0), 1.9, 1.95, 0.08, Build.mat("planks012", Vector3(1, 1, 1), Color(0.45, 0.32, 0.2)), false, 20)
	var b := BODY.instantiate() as MonsterBody
	b.data = Game.monsters[i]
	b.position = p + Vector3(0, 0.45, 0)
	b.rotation.y = 0.0
	add_child(b)
	b.face_dir = Vector3(0, 0, 1)
	bodies.append(b)
	MonsterModel.hold.call_deferred(b.model, "Rest")


func _aim(snap := false) -> void:
	var goal := Vector3(0, 1.6, 3.6)
	var look := Vector3(0, 0.8, -1.0)
	if not bodies.is_empty():
		var bp := bodies[sel].position
		goal = bp + Vector3(0.9, 1.5, 3.4)
		look = bp + Vector3(0, 0.75, 0)
	if snap:
		cam.position = goal
	else:
		cam.position = cam.position.lerp(goal, 0.08)
	var dir := (look - cam.position).normalized()
	cam.basis = cam.basis.slerp(Basis.looking_at(dir, Vector3.UP), 0.12 if not snap else 1.0)


func _process(delta: float) -> void:
	_t += delta
	_aim()
	_card_update()


# ---------------------------------------------------------------- UI

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_root = Control.new()
	hud_root.theme = UIStyle.theme()
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud_root)
	var date := UIStyle.label(GameCalendar.label(), 24, Color(1, 0.95, 0.8), "display")
	date.position = Vector2(28, 18)
	hud_root.add_child(date)
	var ap := UIStyle.label("%d G" % Game.money, 18, Color(1.0, 0.86, 0.45), "display")
	ap.position = Vector2(28, 52)
	hud_root.add_child(ap)
	var col := PanelContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	col.position = Vector2(-300, -250)
	col.add_theme_stylebox_override("panel", UIStyle.tex_box("panel_dark", 20, 18.0, 16.0))
	hud_root.add_child(col)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	col.add_child(_buttons)
	for c in [["TRAINING", "Weekly drills and rest", _open_training], ["CALENDAR", "Cups and promotion matches", _open_calendar],
			["KAMI", "Status of every kami", _open_monsters], ["ENCYCLOPEDIA", "Every breed you have met", _open_encyclopedia],
			["TRAINER", "You, your ranch and bonds", _open_breeder], ["SHRINE", "Summon a new kami", _go_shrine],
			["ASSOCIATION", "Entries and combining kami", _open_association], ["SETTINGS", "Sound and graphics", _open_settings]]:
		var b := Button.new()
		b.text = c[0]
		b.tooltip_text = c[1]
		b.custom_minimum_size = Vector2(240, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			Sound.sfx("confirm", -12.0)
			(c[2] as Callable).call())
		b.mouse_entered.connect(func() -> void: Sound.sfx("hover", -18.0))
		_buttons.add_child(b)
	var out := Button.new()
	out.text = "GO OUTSIDE"
	out.custom_minimum_size = Vector2(240, 52)
	UIStyle.make_primary(out)
	out.pressed.connect(_go_outside)
	_buttons.add_child(out)
	(_buttons.get_child(0) as Button).grab_focus.call_deferred()
	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_card.position = Vector2(28, -210)
	_card.custom_minimum_size = Vector2(330, 0)
	_card.add_theme_stylebox_override("panel", MR4.frame_style())
	hud_root.add_child(_card)
	var hint := UIStyle.label("◀ ▶  or  Q / E  :  change kami", 14, Color(1, 0.95, 0.8, 0.8), "body")
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(30, -34)
	hud_root.add_child(hint)
	_toast = UIStyle.label("", 20, Color.WHITE, "body")
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 100
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(_toast)
	_card_fill(true)


var _card_for := -1


func _card_update() -> void:
	if _card_for != sel:
		_card_fill()


func _card_fill(force := false) -> void:
	_card_for = sel
	for c in _card.get_children():
		c.queue_free()
	if Game.monsters.is_empty():
		var l := MR4.ink("Your stable is empty.\nThe shrine is where trainers call their first kami.", 16, true)
		_card.add_child(l)
		return
	var m: MonsterData = Game.monsters[sel]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_card.add_child(v)
	v.add_child(MR4.ink(m.name, 24, false, "display"))
	v.add_child(MR4.ink("%s  ·  rank %s" % [m.breed_label(), m.rank], 13, true))
	v.add_child(MR4.stat_bar("FATIGUE", m.fatigue, 999, Color(0.9, 0.55, 0.2), 120.0))
	v.add_child(MR4.stat_bar("STRESS", m.stress, 999, Color(0.8, 0.35, 0.5), 120.0))
	var drill := "Rest"
	if not m.schedule.is_empty() and str(m.schedule[0]) != "":
		var d := Training.find(str(m.schedule[0]).split(":")[0])
		drill = d.display_name if d != null else "Rest"
	v.add_child(MR4.ink("This week:  %s" % drill, 14, false, "display"))


func _unhandled_input(e: InputEvent) -> void:
	if page != null and is_instance_valid(page):
		var dismiss: bool = e.is_action_pressed("ui_cancel") or (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)
		if dismiss:
			(page.get_meta("close") as Callable).call()
			get_viewport().set_input_as_handled()
		return
	if in_menu or bodies.is_empty():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k in [KEY_RIGHT, KEY_E]:
			sel = (sel + 1) % bodies.size()
		elif k in [KEY_LEFT, KEY_Q]:
			sel = (sel - 1 + bodies.size()) % bodies.size()


# ---------------------------------------------------------------- the host interface the shared pages use

func open_page(title: String, body: Control) -> void:
	in_menu = true
	page = MR4.page(hud_root, title, body, func() -> void:
		page = null
		in_menu = false
		_card_fill(true))


func free_trainer() -> void:
	pass


func toast(t: String) -> void:
	Sound.sfx("chime", -14.0)
	_toast.text = t
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Called by the week planner's START THE WEEK: the drills run and results show once you are back at the ranch.
func run_training() -> void:
	Save.write()
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "start", "train": true})


# ---------------------------------------------------------------- commands

func _open_training() -> void:
	if Game.monsters.is_empty():
		toast("You have no kami yet. The shrine is where trainers call their first kami.")
		return
	WeekPlanner.open(self)


func _open_calendar() -> void:
	CalendarPanel.open(self)


func _open_monsters() -> void:
	if Game.monsters.is_empty():
		toast("No kami yet.")
		return
	open_page("KAMI", MonsterPage.body(Game.monsters, sel))


func _open_encyclopedia() -> void:
	open_page("ENCYCLOPEDIA", EncyclopediaPage.body())


func _open_breeder() -> void:
	open_page("TRAINER", BreederPage.body())


func _open_association() -> void:
	open_page("TRAINERS' ASSOCIATION", AssociationPage.body(self))


func _open_settings() -> void:
	open_page("SETTINGS", SettingsPage.body(self))


func _go_shrine() -> void:
	Save.write()
	Scenes.goto("res://world/zones/shrine.tscn", {"entry": "south"})


func _go_outside() -> void:
	if not Game.monsters.is_empty() and Game.planned_week != Game.week:
		toast("Plan the week first: TRAINING, then START THE WEEK.")
		_open_training()
		return
	Save.write()
	Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "start"})
