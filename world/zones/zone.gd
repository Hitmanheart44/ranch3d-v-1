class_name Zone
extends Node3D
## A walkable place (ranch, town, shrine): its own scene, building only its own region of the world (Overworld
## zone), so little is ever loaded at once. Provides the trainer + camera, the HUD (calendar, goal, prompt),
## menus, MR4-style dialogue boxes, walk-up spots, NPCs, and LOADING ZONES: walk into one and the screen fades
## to the next place, arriving at the matching entrance (Scenes.params["entry"]).
## Subclasses override: zone_id(), entries(), setup().

const REACH := 2.8
const MONTHS := ["Early Spring", "Spring", "Late Spring", "Early Summer", "Summer", "Late Summer", "Early Autumn", "Autumn",
	"Late Autumn", "Early Winter", "Winter", "Late Winter"]

var world: Overworld
var trainer: Trainer
var cam: FollowCamera
var spots: Array = []          # {pos, r, label, fn}
var exits: Array = []          # {pos, r, scene, entry, label}
var npcs: Array[Npc] = []
var current: Dictionary = {}   # the spot / npc you're at
var in_menu := false
var page: Control          # the open MR4 page (kami, trainer...), if any
var _leaving := false
# HUD
var hud_layer: CanvasLayer
var hud_root: Control
var prompt: Label
var info: Label
var goal: Label
var menu: VBoxContainer
var menu_panel: PanelContainer
var result_box: PanelContainer
var toast_l: Label
var dialog_box: PanelContainer
var dialog_name: Label
var dialog_text: Label
var _dialog_lines: Array = []
var _dialog_then := Callable()


func zone_id() -> String:
	return "ranch"


## entrance name -> [position, yaw (radians, facing)]
func entries() -> Dictionary:
	return {"start": [Vector3.ZERO, 0.0]}


func setup() -> void:
	pass


func _ready() -> void:
	if not Game.has_meta("loaded"):  # launched straight into a zone (dev): load the save once
		Game.set_meta("loaded", true)
		if Save.exists():
			Save.read()
	if not _pre_ready():
		return
	if outdoor():
		world = Overworld.new()
		world.zone = zone_id()
		add_child(world)
	else:
		build_room()
	var e: Dictionary = entries()
	var ent: Array = e.get(str(Scenes.params.get("entry", "start")), e.values()[0])
	trainer = Trainer.new()
	add_child(trainer)
	var p: Vector3 = ent[0]
	trainer.global_position = Vector3(p.x, ground(p.x, p.z) + 0.3, p.z)
	trainer.model.rotation.y = ent[1]
	cam = FollowCamera.new()
	cam.target = trainer
	cam.distance = 5.5
	cam.look_height = 1.5
	cam.pitch_deg = -14.0
	cam.capture_mouse = true
	cam.yaw = float(ent[1]) + PI
	add_child(cam)
	add_child(PostFx.new())
	_build_hud()
	_bounds()
	setup()
	for n in npcs:
		add_child(n)
		n.position.y = ground(n.position.x, n.position.z)


## Outdoor zones build their region of the world; indoor zones (shops, halls) build a room instead.
func outdoor() -> bool:
	return true


func build_room() -> void:
	pass


func ground(x: float, z: float) -> float:
	return world.height(x, z) if world != null else 0.0


## Subclass hook before the world is built; return false to stop (e.g. redirect to the intro).
func _pre_ready() -> bool:
	return true


# ---------------------------------------------------------------- building blocks for subclasses

func add_spot(pos: Vector3, r: float, label: String, fn: Callable) -> void:
	spots.append({"pos": pos, "r": r, "label": label, "fn": fn})


## A loading zone. With `gate` (width, depth) it's a strip across an opening in the zone's border, with a glowing
## curtain exactly where it triggers (walk into the opening = leave). Without it, a small circle (doorways).
func add_exit(pos: Vector3, r: float, scene: String, entry: String, label: String, gate := Vector2.ZERO) -> void:
	exits.append({"pos": pos, "r": r, "scene": scene, "entry": entry, "label": label, "gate": gate})
	if gate == Vector2.ZERO:
		return
	var y := ground(pos.x, pos.z)
	var curtain := MeshInstance3D.new()  # a soft wall of light across the opening
	var qm := QuadMesh.new()
	qm.size = Vector2(maxf(gate.x, gate.y), 3.0)
	curtain.mesh = qm
	var m := ShaderMaterial.new()  # warm haze rising off the ground, fading up and toward the sides (no hard edges)
	m.shader = Shader.new()
	m.shader.code = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never;\nvoid fragment() {\n" + \
		"\tfloat up = pow(1.0 - UV.y, 2.5);\n\tfloat side = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);\n" + \
		"\tfloat flick = 0.85 + 0.15 * sin(TIME * 2.0 + UV.x * 9.0);\n\tALBEDO = vec3(1.0, 0.78, 0.45);\n\tALPHA = up * side * flick * 0.22;\n}\n"
	curtain.material_override = m
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.position = Vector3(pos.x, y + 1.5, pos.z)
	curtain.rotation.y = 0.0 if gate.x >= gate.y else PI / 2.0
	add_child(curtain)


func _in_exit(ex: Dictionary, p: Vector3) -> bool:
	var g: Vector2 = ex.get("gate", Vector2.ZERO)
	if g == Vector2.ZERO:
		return Vector2(p.x - ex["pos"].x, p.z - ex["pos"].z).length() < ex["r"]
	return absf(p.x - ex["pos"].x) < g.x / 2.0 and absf(p.z - ex["pos"].z) < g.y / 2.0


## Invisible walls: the edge of this zone's detailed region, and the cliff tops (no walking into the sea).
func _bounds() -> void:
	if not outdoor():
		return  # rooms have their own walls
	var r := world.region.grow(-2.0)
	var sb := StaticBody3D.new()
	add_child(sb)
	for e in [[Vector2(r.position.x, r.get_center().y), Vector2(1, r.size.y)], [Vector2(r.end.x, r.get_center().y), Vector2(1, r.size.y)],
			[Vector2(r.get_center().x, r.position.y), Vector2(r.size.x, 1)], [Vector2(r.get_center().x, r.end.y), Vector2(r.size.x, 1)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(e[1].x, 60.0, e[1].y)
		cs.shape = bs
		cs.position = Vector3(e[0].x, 0, e[0].y)
		sb.add_child(cs)
	var z := world.region.position.y
	while z < world.region.end.y:  # along the cliff edge
		var z2 := z + 4.0
		var a := Vector3(Overworld.coast(z) - 2.5, 0, z)
		var b := Vector3(Overworld.coast(z2) - 2.5, 0, z2)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.6, 60.0, a.distance_to(b) + 0.4)
		cs.shape = bs
		cs.position = (a + b) / 2.0
		cs.rotation.y = atan2(b.x - a.x, b.z - a.z)
		sb.add_child(cs)
		z = z2


func add_npc(n: Npc) -> void:
	npcs.append(n)


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.theme = UIStyle.theme()
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud_root)
	var shade := TextureRect.new()  # a soft dark band so the calendar and goal read over a bright sky
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.05, 0.03, 0.02, 0.6), Color(0.05, 0.03, 0.02, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.custom_minimum_size = Vector2(0, 96)
	shade.size = Vector2(0, 96)
	hud_root.add_child(shade)
	info = UIStyle.label("", 18, UIStyle.TEXT, "display")
	info.position = Vector2(24, 16)
	hud_root.add_child(info)
	var menu_btn := Button.new()  # the main menu (MR4's triangle button): weekend, kami / trainer info, settings
	menu_btn.text = "  MENU  [Tab]  "
	menu_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.position = Vector2(-190, 14)
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.pressed.connect(main_menu)
	hud_root.add_child(menu_btn)
	goal = UIStyle.label("", 15, UIStyle.ACCENT, "body")
	goal.position = Vector2(24, 48)
	hud_root.add_child(goal)
	prompt = UIStyle.label("", 22, UIStyle.ACCENT, "display")
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -175
	prompt.offset_bottom = -130
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(prompt)
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	menu_panel.position = Vector2(50, -200)
	menu_panel.visible = false
	menu_panel.add_theme_stylebox_override("panel", MR4.frame_style())
	hud_root.add_child(menu_panel)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu)
	result_box = PanelContainer.new()
	result_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_box.custom_minimum_size = Vector2(640, 0)
	result_box.position = Vector2(-320, -230)
	result_box.visible = false
	result_box.add_theme_stylebox_override("panel", MR4.frame_style())
	hud_root.add_child(result_box)
	dialog_box = PanelContainer.new()
	dialog_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialog_box.offset_left = 140
	dialog_box.offset_right = -140
	dialog_box.offset_top = -210
	dialog_box.offset_bottom = -40
	dialog_box.visible = false
	dialog_box.add_theme_stylebox_override("panel", MR4.frame_style())
	hud_root.add_child(dialog_box)
	var dv := VBoxContainer.new()
	dialog_box.add_child(dv)
	dialog_name = MR4.ink("", 22, false, "display")
	dialog_name.add_theme_color_override("font_color", MR4.RIBBON)
	dv.add_child(dialog_name)
	dialog_text = MR4.ink("", 19)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(dialog_text)
	dv.add_child(MR4.ink("click or [E]  ▸", 13, true))
	toast_l = UIStyle.label("", 18, Color.WHITE, "body")
	toast_l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_l.offset_top = 100
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(toast_l)
	var hint := UIStyle.label("WASD walk  ·  SHIFT run  ·  MOUSE look  ·  E talk / use  ·  ESC back", 13, UIStyle.DIM, "body")
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, hint.position.y - 30)
	hud_root.add_child(hint)


static func calendar() -> String:
	return calendar_of(Game.week)


static func calendar_of(abs_week: int) -> String:
	var w := abs_week - 1
	return "Year %d  ·  %s  ·  Week %d" % [w / 48 + 1, MONTHS[(w / 4) % 12], w % 4 + 1]


static func goal_text() -> String:
	var en := Schedule.entry_now()
	if not en.is_empty():
		return "This week: %s fights in the %s. Leave for it from your house at the weekend." % [en["monster"], en["name"]]
	if Game.monsters.is_empty():
		return "Goal: go out the north gate and up the hill to the shrine. Call out your machine's kami at the hokora."
	if Game.trained_week == Game.week:
		return "The weekend: %d AP left. Care for your kami, shop in town, or leave from your house." % Game.ap
	if Game.inventory.values().reduce(func(a, b): return a + b, 0) < 2:
		return "Goal: you're low on food. The town's food shop is down the south road."
	return "Goal: care for your kami, end the week at your house, or enter events at the town's Association."


var _last_dry := Vector3.INF


## Water is scenery: standing in the sea or the harbor is never allowed, so a step into it puts you back on the last dry ground.
func _physics_process(_delta: float) -> void:
	if trainer == null or not outdoor():
		return
	var p := trainer.global_position
	if p.y > Overworld.SEA_Y + 1.0:
		if trainer.is_on_floor():
			_last_dry = p
	elif p.y < Overworld.SEA_Y + 0.3 and _last_dry != Vector3.INF:
		trainer.global_position = _last_dry
		trainer.velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	if info == null:  # the title backdrop builds a zone without its HUD
		return
	info.text = "%s     %d AP     %d G" % [calendar(), Game.ap, Game.money]
	goal.text = goal_text()
	if in_menu or trainer.frozen or _leaving:
		prompt.text = ""
		return
	var p := trainer.global_position
	for ex in exits:  # loading zones trigger by walking in
		if _in_exit(ex, p):
			_leave(ex)
			return
	current = {}
	var best := REACH
	for n in npcs:
		var d := n.global_position.distance_to(p)
		if d < 5.0:
			n.face(p)
		if d < best and (n.global_position - p).normalized().dot(trainer.facing()) > 0.1:
			best = d
			current = {"npc": n}
	if current.is_empty():
		for s in spots:
			if Vector2(p.x - s["pos"].x, p.z - s["pos"].z).length() < s["r"]:
				current = s
				break
	_zone_prompt()


## Sets the prompt for what you're at; subclasses may extend (e.g. kami).
func _zone_prompt() -> void:
	if current.has("npc"):
		prompt.text = "[E]  Talk to %s" % (current["npc"] as Npc).npc_name
	elif current.has("label"):
		prompt.text = "[E]  " + str(current["label"])
	else:
		prompt.text = ""


## A gap that runs code instead of loading a scene (e.g. the trailhead that opens the adventure picker). The trainer is
## nudged back inside first so closing the menu doesn't re-trigger it.
func add_trail(pos: Vector3, inward: Vector3, label: String, gate: Vector2, fn: Callable) -> void:
	add_exit(pos, 0.0, "", "", label, gate)
	exits[exits.size() - 1]["fn"] = fn
	exits[exits.size() - 1]["inward"] = inward


func _leave(ex: Dictionary) -> void:
	if ex.has("fn"):
		trainer.global_position += (ex["inward"] as Vector3).normalized() * 3.0
		(ex["fn"] as Callable).call()
		return
	_leaving = true
	if "room" in ex.get("params", {}) or zone_id() == "interior":
		Sound.sfx("door", -8.0)
	trainer.frozen = true
	Save.write()
	var params: Dictionary = {"entry": ex["entry"]}
	params.merge(ex.get("params", {}))
	Scenes.goto(ex["scene"], params)


func _unhandled_input(e: InputEvent) -> void:
	if page != null and is_instance_valid(page):
		var dismiss: bool = e.is_action_pressed("interact") or (e is InputEventKey and e.pressed and (e as InputEventKey).keycode in [KEY_ENTER, KEY_ESCAPE, KEY_TAB]) \
			or (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)
		if dismiss:
			(page.get_meta("close") as Callable).call()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if dialog_box.visible:       # click the dialogue box to go on
			_next_line()
			return
		if result_box.visible:
			result_box.visible = false
			free_trainer()
			return
		if in_menu and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			close_menu()
			return
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_TAB and not dialog_box.visible:
		if in_menu:
			close_menu()
		else:
			main_menu()
		get_viewport().set_input_as_handled()
		return
	if dialog_box == null:
		return
	if dialog_box.visible:
		if e.is_action_pressed("interact") or (e is InputEventKey and e.pressed and (e as InputEventKey).keycode in [KEY_ENTER, KEY_SPACE]):
			_next_line()
		return
	if result_box.visible:
		if e.is_action_pressed("interact") or (e is InputEventKey and e.pressed and (e as InputEventKey).keycode in [KEY_ENTER, KEY_ESCAPE]):
			result_box.visible = false
			free_trainer()
		return
	if in_menu and e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			var btns := menu.get_children().filter(func(c): return c is Button)
			if k - KEY_1 < btns.size():
				(btns[k - KEY_1] as Button).pressed.emit()
		elif k == KEY_ESCAPE:
			close_menu()
		return
	if not e.is_action_pressed("interact") or trainer.frozen:
		return
	if current.has("npc"):
		var n: Npc = current["npc"]
		say(n.npc_name, n.lines, n.service)
	elif current.has("fn"):
		(current["fn"] as Callable).call()
	else:
		_interact_other()


## Subclass hook for E when nothing generic is in reach (e.g. kami on the ranch).
func _interact_other() -> void:
	pass


# ---------------------------------------------------------------- the main menu

func main_menu() -> void:
	if _leaving:
		return
	show_menu("MENU     %s" % calendar(), [["THE WEEKEND", "Your cup, an adventure, or start the next week.", _weekend_menu],
		["KAMI", "Stats, condition, age.", _monster_info], ["ENCYCLOPEDIA", "Every kami you have met.", _encyclopedia], ["TRAINER", "%s  ·  rank %s  ·  %d G" % [Game.player_name, Game.rank, Game.money], _breeder_info],
		["SETTINGS", "Sound and display.", _settings], ["QUIT TO MAIN MENU", "Saves your game first.", _quit_menu], ["CLOSE", "", close_menu]])


## Back to the title screen. Asks first; the game is saved on the way out.
func _quit_menu() -> void:
	show_menu("QUIT TO MAIN MENU?", [["SAVE AND QUIT", "Back to the title screen.", func() -> void:
			_leaving = true
			trainer.frozen = true
			Save.write()
			Scenes.goto("res://world/flow/title.tscn")],
		["KEEP PLAYING", "", main_menu]])


## The weekend's choices. The ranch offers them directly; everywhere else you head home first.
func _weekend_menu() -> void:
	var en := Schedule.entry_now()
	show_menu("THE WEEKEND", [["HEAD HOME", ("Your %s is this week." % en["name"]) if not en.is_empty() else "Plan the weekend at the ranch.", func():
			_leaving = true
			trainer.frozen = true
			Save.write()
			Scenes.goto("res://world/zones/ranch_v2.tscn", {"entry": "house", "weekend": true})],
		["BACK", "", main_menu]])


func _monster_info() -> void:
	if Game.monsters.is_empty():
		toast("No kami yet.")
		return
	open_page("KAMI", MonsterPage.body(Game.monsters))


func _encyclopedia() -> void:
	open_page("ENCYCLOPEDIA", EncyclopediaPage.body())


func _breeder_info() -> void:
	open_page("TRAINER", BreederPage.body())


## A modal MR4 page: closes on Back, click-away, right-click, Esc or Enter, then hands the player back.
func open_page(title: String, body: Control) -> void:
	menu_panel.visible = false
	in_menu = true
	trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	page = MR4.page(hud_root, title, body, func() -> void:
		page = null
		in_menu = false
		free_trainer())


func _settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(bus)
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	show_menu("SETTINGS", [["SOUND: %s" % ("OFF" if muted else "ON"), "", func():
			AudioServer.set_bus_mute(bus, not muted)
			_settings()],
		["GRAPHICS: %s" % Quality.NAMES[Quality.level], "Render scale, shadows, clutter. Applies fully next zone.", func():
			Quality.cycle()
			_settings()],
		["DISPLAY: %s" % ("FULLSCREEN" if full else "WINDOW"), "", func():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			_settings()],
		["BACK", "", main_menu]])


# ---------------------------------------------------------------- menus, dialogue, results

func show_menu(title: String, opts: Array) -> void:  # opts: [label, desc, callable]
	for c in menu.get_children():
		c.queue_free()
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	menu.add_child(head)
	var ttl := MR4.ink(title, 26, false, "display")
	ttl.add_theme_color_override("font_color", MR4.RIBBON)
	head.add_child(ttl)
	var rule := ColorRect.new()
	rule.color = MR4.WOOD_LIGHT
	rule.custom_minimum_size = Vector2(0, 2)
	head.add_child(rule)
	for i in opts.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(640, 48)
		b.focus_mode = Control.FOCUS_ALL
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -14
		row.add_theme_constant_override("separation", 12)
		b.add_child(row)
		var num := MR4.ink(str(i + 1), 15, true, "display")  # quiet key hint, no badge
		num.custom_minimum_size = Vector2(18, 0)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(num)
		var name := MR4.ink(str(opts[i][0]), 19, false, "display")
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name)
		var desc := MR4.ink(str(opts[i][1]), 14, true)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		desc.clip_text = true
		row.add_child(desc)
		b.pressed.connect(func(): Sound.sfx("confirm", -12.0))
		b.mouse_entered.connect(func(): Sound.sfx("hover", -18.0))
		b.pressed.connect(opts[i][2])
		b.mouse_entered.connect(b.grab_focus)
		menu.add_child(b)
	var hint := MR4.ink("Number keys or click to choose.   Esc or right-click to close.", 12, true)
	menu.add_child(hint)
	menu_panel.visible = true
	in_menu = true
	trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first := menu.get_children().filter(func(c): return c is Button)
	if not first.is_empty():
		(first[0] as Button).grab_focus.call_deferred()


func close_menu() -> void:
	menu_panel.visible = false
	in_menu = false
	free_trainer()


func free_trainer() -> void:
	trainer.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func say(who: String, lines: Array, then := Callable()) -> void:
	_talker = null
	for n in npcs:
		if n.npc_name == who:
			_talker = n
			n.talk(true)
	_dialog_lines = lines.duplicate()
	_dialog_then = then
	dialog_name.text = who
	dialog_box.visible = true
	trainer.frozen = true
	_next_line()


var _talker: Npc


func _next_line() -> void:
	if _dialog_lines.is_empty():
		if _talker != null:
			_talker.talk(false)
			_talker = null
		dialog_box.visible = false
		if _dialog_then.is_valid():
			_dialog_then.call()
		else:
			free_trainer()
		return
	dialog_text.text = str(_dialog_lines.pop_front()).replace("{you}", Game.player_name)


func results(title: String, lines: Array) -> void:
	menu_panel.visible = false
	in_menu = false
	for c in result_box.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	result_box.add_child(vb)
	var bad := title.begins_with("DEFEAT") or title == "CUP OVER"
	var rt := MR4.ink(title, 34 if bad else 26, false, "display")
	rt.add_theme_color_override("font_color", MR4.RIBBON)
	vb.add_child(rt)
	vb.add_child(MR4.ink("\n".join(lines), 16))
	vb.add_child(MR4.ink("[E] or click  ·  continue", 13, true))
	result_box.visible = true
	trainer.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Non-blocking report card (week results etc.): sits at the right, fades by itself, you keep walking.
## bad = a big red banner first (DEFEATED, CUP OVER).
func report(title: String, lines: Array, bad := false) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.custom_minimum_size = Vector2(430, 0)
	panel.add_theme_stylebox_override("panel", MR4.frame_style())
	panel.position = Vector2(-470, -200)
	hud_root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var rtt := MR4.ink(title, 24, false, "display")
	rtt.add_theme_color_override("font_color", MR4.RIBBON)
	vb.add_child(rtt)
	var body := MR4.ink("\n".join(lines.slice(0, 14)), 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(400, 0)
	vb.add_child(body)
	var tw := create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(panel, "modulate:a", 0.0, 1.0)
	tw.tween_callback(panel.queue_free)
	if bad:
		var banner := UIStyle.label(title, 72, UIStyle.BAD, "display")
		banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hud_root.add_child(banner)
		var bt := create_tween()
		bt.tween_interval(2.0)
		bt.tween_property(banner, "modulate:a", 0.0, 0.8)
		bt.tween_callback(banner.queue_free)


func toast(t: String) -> void:
	Sound.sfx("chime", -14.0)
	toast_l.text = t
	toast_l.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(toast_l, "modulate:a", 0.0, 0.6)


func spend_ap() -> bool:
	if Game.ap <= 0:
		toast("No action points left this week.")
		return false
	Game.ap -= 1
	return true
