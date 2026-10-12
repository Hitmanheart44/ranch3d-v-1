class_name SpeciesDB
extends RefCounted
## Loads every SpeciesDef in res://data/species/ once, sorted by roster_order.

const DIR := "res://data/species/"

static var _list: Array[SpeciesDef] = []
static var _by_id: Dictionary = {}


static func all() -> Array[SpeciesDef]:
	if _list.is_empty():
		_load()
	return _list


static func get_def(id: StringName) -> SpeciesDef:
	if _list.is_empty():
		_load()
	return _by_id.get(id)


static func _load() -> void:
	for f in DirAccess.get_files_at(DIR):
		f = f.trim_suffix(".remap")  # exported builds rename resources
		if not f.ends_with(".tres"):
			continue
		var d := load(DIR + f) as SpeciesDef
		if d == null:
			push_error("SpeciesDB: %s is not a SpeciesDef" % f)
			continue
		_list.append(d)
	_list.sort_custom(func(a: SpeciesDef, b: SpeciesDef) -> bool: return a.roster_order < b.roster_order)
	for i in _list.size():
		var d := _list[i]
		if i > 0 and d.roster_order == _list[i - 1].roster_order:
			push_error("SpeciesDB: %s and %s share roster_order %d" % [d.id, _list[i - 1].id, d.roster_order])
		_by_id[d.id] = d
