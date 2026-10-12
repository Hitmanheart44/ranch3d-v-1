extends Node


func _find(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.begins_with(text):
		return n
	for c in n.get_children():
		var r := _find(c, text)
		if r != null:
			return r
	return null


func _ready() -> void:
	var t: Node = (load("res://world/flow/title.tscn") as PackedScene).instantiate()
	add_child(t)
	await get_tree().create_timer(0.5).timeout
	print("TITLE credits button present: ", _find(t, "CREDITS") != null, "   options button present: ", _find(t, "OPTIONS") != null)
	_find(t, "OPTIONS").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	var vp := get_viewport().get_visible_rect().size
	await get_tree().process_frame
	var back := _find(t._options, "BACK")
	print("TITLE options panel fits the window: BACK bottom edge at y=", snappedf(back.global_position.y + back.size.y, 1.0), " of ", vp.y)
	var g := _find(t, "GRAPHICS")
	print("TITLE options open, ", g.text if g else "no graphics button", "   sound: ", _find(t, "SOUND").text, "   display: ", _find(t, "DISPLAY").text)
	g.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	print("TITLE after pressing graphics: ", _find(t, "GRAPHICS").text)
	_find(t, "GRAPHICS").pressed.emit()   # cycle on to Medium, then High, so the saved setting ends where it started
	await get_tree().create_timer(0.1).timeout
	_find(t, "GRAPHICS").pressed.emit()
	await get_tree().create_timer(0.1).timeout
	print("TITLE graphics left at: ", _find(t, "GRAPHICS").text)
	_find(t, "BACK").pressed.emit()
	await get_tree().create_timer(0.2).timeout
	print("TITLE back to the main menu: new game button visible=", _find(t, "NEW GAME").is_visible_in_tree())
	get_tree().quit()
