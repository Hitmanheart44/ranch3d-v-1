class_name DrillDef
extends Resource
## One training drill (a .tres in res://data/drills/). Training.run() applies it.

@export var id: StringName
@export var display_name: String
@export_multiline var blurb: String
@export_enum("hp", "power", "guard", "speed", "focus") var stat: String = "power"
@export var gain_min := 3
@export var gain_max := 6
## Optional side effect: another stat goes up (or down if negative).
@export_enum("none", "hp", "power", "guard", "speed", "focus") var side_stat: String = "none"
@export var side_gain := 0
@export var fatigue := 15
@export var stress := 5
@export_range(0.0, 1.0) var success := 0.85
@export var cost := 0
