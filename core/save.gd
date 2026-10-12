extends Node
## Save/load (autoload "Save"). JSON on purpose: Godot .tres files can carry scripts that run on load,
## so a shared save file could execute code. JSON is plain data.
##   Save.write()  /  if Save.exists(): Save.read()

## Tests (any res://*_test.tscn, or any scene under a /tests/ folder) get their own file so they never touch the player's save.
var PATH := "user://save_test.json" if Array(OS.get_cmdline_args()).any(func(a): return str(a).ends_with("_test.tscn") or "/tests/" in str(a)) else "user://save.json"


func exists() -> bool:
	return FileAccess.file_exists(PATH)


func write() -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save: can't write %s (%s)" % [PATH, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(Game.to_dict(), "\t"))
	return true


func read() -> bool:
	if not exists():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Save: %s is not valid save data" % PATH)
		return false
	Game.from_dict(data)
	return true


func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
