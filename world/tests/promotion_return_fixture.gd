extends RefCounted
## Suppress construction/presentation only; all result and progression methods are inherited.

class Arena extends "res://combat/arena.gd":
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_DISABLED


class Ranch extends "res://world/zones/ranch_v2.gd":
	var reports: Array = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_DISABLED

	func close_menu() -> void:
		pass

	func report(title: String, lines: Array, bad := false) -> void:
		reports.append({"title": title, "lines": lines, "bad": bad})


class CupIntro extends "res://world/flow/cup_intro.gd":
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_DISABLED
