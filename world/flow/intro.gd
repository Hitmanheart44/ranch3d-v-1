extends Node3D
## New-game intro: a letterboxed camera flight through the world with narration, then the title, then the ranch.
## Edit the narration freely (SHOTS). Any key or click skips.

const TITLE := "SPIRIT IN THE MACHINE"
# [camera from, camera to, look from, look to, seconds, narration]
const SHOTS := [
	[Vector3(110, 32, 34), Vector3(58, 30, 10), Vector3(20, 0, 0), Vector3(2, 0, 0), 8.0,
		"They say anything that serves long enough grows a soul."],
	[Vector3(0, 3.5, -11), Vector3(3, 5, -19), Vector3(8, 4, -32), Vector3(18, 7, -38), 7.0,
		"Tools. Lanterns. Swords. And now, machines."],
	[Vector3(10, 15, -22), Vector3(16, 11, -29), Vector3(18, 6, -40), Vector3(9, 6, -62), 7.5,
		"Their spirits are called kami. Most of them sleep."],
	[Vector3(15, 13, -54), Vector3(12, 11, -58), Vector3(9, 6.5, -66), Vector3(9, 6.5, -67), 6.0,
		"A rare few people can call them out, and raise them."],
	[Vector3(30, 14, 26), Vector3(8, 5, 14), Vector3(-6, 2, 4), Vector3(0, 1.5, 0), 8.0,
		"This empty ranch on the cliffs is yours now. And somewhere, a machine has been listening."],
]

var world: Overworld
var cam: Camera3D
var shot := 0
var t := 0.0
var text: Label
var title: Label
var fade: ColorRect
var done := false


func _ready() -> void:
	world = Overworld.new()
	world.zone = "intro"
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	add_child(PostFx.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	for top in [true, false]:  # letterbox
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 90)
		if not top:
			bar.position.y -= 90
		layer.add_child(bar)
	text = UIStyle.label("", 26, Color(1.0, 0.95, 0.85), "display")
	text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	text.offset_top = -170
	text.offset_bottom = -110
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(text)
	title = UIStyle.label(TITLE, 64, Color(1.0, 0.86, 0.5), "display")
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.modulate.a = 0.0
	layer.add_child(title)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 1.5)


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	if shot >= SHOTS.size():
		_title()
		return
	var s: Array = SHOTS[shot]
	var k := clampf(t / float(s[4]), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var cp := (s[0] as Vector3).lerp(s[1], e)
	cp.y = maxf(cp.y, world.height(cp.x, cp.z) + 2.5)  # never inside a hill
	cam.global_position = cp
	cam.look_at((s[2] as Vector3).lerp(s[3], e))
	text.text = s[5]
	text.modulate.a = clampf(minf(t / 1.0, (float(s[4]) - t) / 1.0), 0.0, 1.0)
	if t >= float(s[4]):
		t = 0.0
		shot += 1


func _title() -> void:
	done = true
	text.text = ""
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.2)
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	tw.tween_callback(_finish)


func _finish() -> void:
	Game.intro_seen = true
	Save.write()
	Scenes.goto("res://world/flow/creator.tscn" if Game.trainer == "" else "res://world/zones/ranch_v2.tscn")


func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventKey or e is InputEventMouseButton) and e.is_pressed() and not done and not "noskip" in OS.get_cmdline_user_args():
		shot = SHOTS.size()
