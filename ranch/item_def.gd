class_name ItemDef
extends Resource
## Food and other consumables (a .tres in res://data/items/). Used by FEED on the ranch.

@export var id: StringName
@export var display_name: String
@export var blurb: String
@export var cost := 20
## true = food (FEED); false = an item you give (GIVE ITEM).
@export var food := true
@export var fullness := 0   # 0..999 scale
@export var form := 0       # + fattens, - slims
@export var fatigue := 0
@export var stress := 0
@export var loyalty := 0  # bonding change
@export_enum("none", "hp", "power", "guard", "speed", "focus") var stat: String = "none"
@export var stat_gain := 0


static func all() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for f in DirAccess.get_files_at("res://data/items/"):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			out.append(load("res://data/items/" + f) as ItemDef)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.cost < b.cost)
	return out
