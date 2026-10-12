class_name MonsterData
extends Resource
## One owned kami: who it is (breeds, stats, personality) and how it's doing (age, fatigue...).
## Saved as part of the game state. Made by Summoner, later by combining.

const STAT_NAMES := ["hp", "power", "guard", "speed", "focus"]

@export var main_breed: StringName
@export var sub_breed: StringName
@export var name: String
@export var type: String
@export var hue: int = 0
@export var stats: Dictionary = {"hp": 0, "power": 0, "guard": 0, "speed": 0, "focus": 0}
@export var personality: String
@export var quirks: PackedStringArray = PackedStringArray()

@export var age_weeks: int = 0
@export var lifespan_weeks: int = 190
## Weeks of life lost to overwork, hunger, injury (MR4 lifespan hits). See Care.week_end().
@export var life_lost := 0.0

# MR4 gauges (see MR4_SYSTEMS.md). fatigue/stress: 0 fresh .. 999 exhausted. fullness: 999 full .. 0 starving.
@export_range(0, 999) var fatigue: int = 0
@export_range(0, 999) var stress: int = 0
@export_range(0, 999) var fullness: int = 700
@export_range(0, 5) var focus: int = 5          # 5 flags
@export_range(0, 100) var bonding: int = 30     # obedience
@export_range(-100, 100) var policy: int = 0    # training policy: lenient - .. + strict
@export_range(-100, 100) var form: int = 0      # thin - .. + fat
@export var rank := "E"                         # per-kami rank (stat caps)
@export var rank_wins := 0                      # cups won at its current rank (3 unlock the yearly promotion match)
@export var won_rank_cup := false               # cleared a cup of its own rank: may rank up at the association
@export var adv_level := 1
@export var adv_exp := 0
## Drill queue, up to 8 weeks: ["weights:1", "sprints:3", ...] ("" = rest that week).
@export var schedule: Array = []
## Effort of the last drill, 0..100 (praise/scold reads it). -1 = no drill this week.
var last_effort := -1
var praises_this_week := 0

@export var source: String   # how it was summoned: machine, text, file...
@export var seed_hex: String


func main_def() -> SpeciesDef:
	return SpeciesDB.get_def(main_breed)


func sub_def() -> SpeciesDef:
	return SpeciesDB.get_def(sub_breed)


func is_pure() -> bool:
	return main_breed == sub_breed


## "Cragback" for a pure breed, "Cragback / Embergeist" for a mix.
func breed_label() -> String:
	var a := main_def().display_name
	return a if is_pure() else "%s / %s" % [a, sub_def().display_name]


func stat(s: String) -> int:
	return int(stats.get(s, 0))


func total() -> int:
	var t := 0
	for s in STAT_NAMES:
		t += stat(s)
	return t


## Input for MonsterModel.create(). Art track A1 replaces this with MonsterData directly.
func model_dict() -> Dictionary:
	return {"species_id": main_def().model_key(), "breed": str(main_breed), "type": type, "hue": hue}


func life_left() -> float:
	return float(lifespan_weeks) - life_lost - float(age_weeks)


## Plain-data copy for save files (see core/save.gd).
func to_dict() -> Dictionary:
	return {"main_breed": str(main_breed), "sub_breed": str(sub_breed), "name": name, "type": type, "hue": hue,
		"stats": stats.duplicate(), "personality": personality, "quirks": Array(quirks),
		"age_weeks": age_weeks, "lifespan_weeks": lifespan_weeks, "life_lost": life_lost,
		"fatigue": fatigue, "stress": stress, "fullness": fullness, "focus": focus, "bonding": bonding,
		"policy": policy, "form": form, "rank": rank, "won_rank_cup": won_rank_cup, "rank_wins": rank_wins,
		"adv_level": adv_level, "adv_exp": adv_exp, "schedule": schedule.duplicate(),
		"source": source, "seed_hex": seed_hex, "v": 2}


static func from_dict(d: Dictionary) -> MonsterData:
	var m := MonsterData.new()
	m.main_breed = StringName(d.get("main_breed", ""))
	m.sub_breed = StringName(d.get("sub_breed", ""))
	m.name = str(d.get("name", ""))
	m.type = str(d.get("type", "fire"))
	m.hue = int(d.get("hue", 0))
	var st: Dictionary = d.get("stats", {})
	for s in STAT_NAMES:
		m.stats[s] = int(st.get(s, 0))
	m.personality = str(d.get("personality", ""))
	m.quirks = PackedStringArray(d.get("quirks", []))
	m.age_weeks = int(d.get("age_weeks", 0))
	m.lifespan_weeks = int(d.get("lifespan_weeks", 190))
	var old := int(d.get("v", 1)) < 2  # pre-MR4 saves: 0..100 gauges and short lifespans
	var k := 10 if old else 1
	m.fatigue = clampi(int(d.get("fatigue", 0)) * k, 0, 999)
	m.stress = clampi(int(d.get("stress", 0)) * k, 0, 999)
	if old:
		m.lifespan_weeks = int(m.lifespan_weeks * 2.5)
	if m.lifespan_weeks < 192:  # older saves: bring them up to the 4-6 year lifespan
		m.lifespan_weeks = clampi(192 + int(round(float(m.lifespan_weeks - 150) / 50.0 * 96.0)), 192, 288)
	m.life_lost = float(d.get("life_lost", 0.0))
	m.fullness = int(d.get("fullness", 700))
	m.focus = int(d.get("focus", 5))
	m.bonding = int(d.get("bonding", d.get("loyalty", 30)))
	m.policy = int(d.get("policy", 0))
	m.form = int(d.get("form", 0))
	m.rank = str(d.get("rank", "E"))
	m.won_rank_cup = bool(d.get("won_rank_cup", false))
	m.rank_wins = int(d.get("rank_wins", 0))
	m.adv_level = int(d.get("adv_level", 1))
	m.adv_exp = int(d.get("adv_exp", 0))
	m.schedule = d.get("schedule", [])
	m.source = str(d.get("source", ""))
	m.seed_hex = str(d.get("seed_hex", ""))
	return m


func describe() -> String:
	var st := []
	for s in STAT_NAMES:
		st.append("%s %d" % [s, stat(s)])
	return "%s [%s, %s, %s, rank %s] %s | %s | life %dw | quirks %s | seed %s" % [
		name, breed_label(), type, main_def().body_class, rank, ", ".join(st), personality,
		lifespan_weeks, ", ".join(quirks), seed_hex]
