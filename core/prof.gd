class_name Prof
extends RefCounted
## Load-time marks: set RANCH_PROFILE=1 and every Prof.mark("what") prints the milliseconds since the previous mark.
static var _last := 0
static var _on := OS.get_environment("RANCH_PROFILE") != ""

static func mark(what: String) -> void:
	if not _on:
		return
	var now := Time.get_ticks_msec()
	if _last != 0:
		print("PROF %5d ms  %s" % [now - _last, what])
	_last = now
