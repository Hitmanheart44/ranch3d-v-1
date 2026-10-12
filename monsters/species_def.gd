class_name SpeciesDef
extends Resource
## One breed. Lives as a .tres in res://data/species/. Adding a breed = adding a file.
## See BESTIARY.md for the design of each breed.

## Summon order. Append-only: give a new breed the next free number. Changing these changes
## which kami every hardware/text summon produces.
@export var roster_order: int = 0
@export var id: StringName
@export var display_name: String
@export_enum("brute", "stalker", "duelist", "caster", "bulwark", "flyer") var body_class: String = "brute"
@export_enum("fire", "water", "plant", "rock", "metal", "magic", "dark", "light") var type: String = "fire"
## Second type for subbreeds (MR-style main/sub, e.g. Vexa = faerie magic / dark). "" = pure breed.
@export var type2: String = ""
## Breed family: main breed id (dog, dino, faerie, mermaid, ...) and the subbreed ("" or same = pure, e.g. dog/dog).
@export var main_breed: String = ""
@export var sub_breed: String = ""
## Stat weights 1..5, in order: hp, power, guard, speed, focus.
@export var bias: PackedInt32Array = PackedInt32Array([2, 2, 2, 2, 2])
@export var lifespan_weeks: int = 70
## Procedural builder key in MonsterModel. Empty = use `id`. Lets a new breed borrow a placeholder model.
@export var model_id: String = ""
## Optional imported model (.glb / .tscn). When set, it wins over the procedural builder (art track A5).
@export var model_scene: PackedScene
## Size multiplier on the model (its file is built at a standard height). 0.55 = small fairy, 1.4 = big brute.
@export var model_size := 1.0
## How an imported (sculpted) model is animated by the body shader until it gets a real skeleton:
## biped = two legs, quad = four legs, float = hovers (no legs). Flags pick which parts move.
@export_enum("biped", "quad", "float") var anim_profile: String = "biped"
@export var anim_wings := false
@export var anim_hair := false
@export var anim_chest := false
## Encyclopedia text (shown once the breed has been seen).
@export_multiline var lore: String = ""
## Part this breed bolts onto others when it is the SUB breed (art track A1).
@export var graft: String = ""


func model_key() -> String:
	return model_id if model_id != "" else str(id)
