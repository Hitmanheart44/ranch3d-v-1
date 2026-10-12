class_name CupDef
extends Resource
## One tournament (a .tres in res://data/cups/). The ranch lists cups at or below your rank.

@export var id: StringName
@export var display_name: String
@export_enum("E", "D", "C", "B", "A", "S") var rank: String = "E"
@export var entry_fee := 0
@export var prize := 300
## Total stat points each foe is scaled to (a fresh summon has 300).
@export var foe_total := 300
@export var rounds := 3
@export_range(0.0, 1.0) var ai_skill := 0.3


static func all() -> Array[CupDef]:
	var out: Array[CupDef] = []
	for f in DirAccess.get_files_at("res://data/cups/"):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			out.append(load("res://data/cups/" + f) as CupDef)
	out.sort_custom(func(a: CupDef, b: CupDef) -> bool: return Game.RANKS.find(a.rank) < Game.RANKS.find(b.rank))
	return out


## Foes for this cup: summoned, then scaled so their stats total foe_total (+8% per round).
func make_foes(week: int) -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for r in rounds:
		var f := Summoner.summon_text("cup %s %d %d" % [id, week, r])
		var k := float(foe_total) * (1.0 + 0.08 * r) / float(maxi(1, f.total()))
		for s in MonsterData.STAT_NAMES:
			f.stats[s] = clampi(int(round(f.stat(s) * k)), BalanceDef.get_def().stat_min, BalanceDef.get_def().stat_max)
		out.append(f)
	return out
