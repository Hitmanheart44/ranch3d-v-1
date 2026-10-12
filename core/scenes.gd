extends Node
## Scene switching with a fade (autoload "Scenes"). Pass data to the next scene through `params`.
##   Scenes.goto("res://combat/arena.tscn", {"player": m, "foes": foes, "return_to": "res://world/zones/ranch_v2.tscn"})
##   # in the next scene's _ready():  var p := Scenes.params

const FADE := 0.35

var params: Dictionary = {}
var _fade: ColorRect
var _busy := false
var _pending: Array = []  # a goto asked for mid-transition runs right after it (was silently dropped)


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Fade to black, run `mid` while the screen is black, fade back in (a change within a scene: planner to training, and so on).
func transition(mid: Callable, hold := 0.15) -> void:
	if _busy:
		mid.call()
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	await tw.finished
	mid.call()
	await get_tree().create_timer(hold).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE)
	await tw2.finished
	_busy = false


func goto(path: String, p_params: Dictionary = {}) -> void:
	if _busy:
		_pending = [path, p_params]
		return
	_busy = true
	params = p_params
	Engine.time_scale = 1.0  # never carry a hitstop freeze into the next scene
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE)
	await tw2.finished
	_busy = false
	if not _pending.is_empty():
		var p: Array = _pending
		_pending = []
		goto(p[0], p[1])
