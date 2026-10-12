class_name Training
extends RefCounted
## MR4-style drills: 4 levels, effort %, gauge costs per level, stat caps by rank, policy drift.
## Training.run(kami, drill, level) -> {lines, effort}. Schedules hold "drill_id:level" strings.

const DIR := "res://data/drills/"
const LV_FATIGUE := [95, 155, 215, 278]
const LV_STRESS := [78, 118, 158, 198]
const LV_HUNGER := [113, 180, 247, 313]
const LV_GAIN := [1.0, 1.5, 2.1, 2.8]
const LIKES := {
	"stubborn": ["guard", "speed"], "curious": ["focus", "guard"], "lazy": ["hp", "power"], "fierce": ["power", "focus"],
	"shy": ["guard", "power"], "loyal": ["hp", "speed"], "mischievous": ["speed", "hp"], "calm": ["focus", "speed"],
	"proud": ["power", "hp"], "anxious": ["speed", "focus"], "cheerful": ["hp", "guard"], "grumpy": ["guard", "focus"],
}  # personality: [liked stat, disliked stat]


static func all() -> Array[DrillDef]:
	var out: Array[DrillDef] = []
	for f in DirAccess.get_files_at(DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			out.append(load(DIR + f) as DrillDef)
	out.sort_custom(func(a: DrillDef, b: DrillDef) -> bool: return a.display_name < b.display_name)
	return out


static func find(id: String) -> DrillDef:
	for d in all():
		if str(d.id) == id:
			return d
	return null


const MAX_PLAN_WEEKS := 8


## A kami's plan is a list of up to eight weekly entries ("weights:2", or "" = rest); the first entry is this week. An empty plan rests.
static func entry_now(m: MonsterData) -> String:
	return "" if m.schedule.is_empty() else str(m.schedule[0])


static func entry_now_at(m: MonsterData, slot: int) -> String:
	return str(m.schedule[slot]) if slot < m.schedule.size() else ""


## Sets week `slot` (0 = this week) of the plan, padding earlier unplanned weeks with rest.
static func set_slot(m: MonsterData, slot: int, entry: String) -> void:
	slot = clampi(slot, 0, MAX_PLAN_WEEKS - 1)
	while m.schedule.size() <= slot:
		m.schedule.append("")
	m.schedule[slot] = entry


## The same entry for the next `weeks` weeks (1..8).
static func fill_plan(m: MonsterData, entry: String, weeks: int) -> void:
	m.schedule = []
	for i in clampi(weeks, 1, MAX_PLAN_WEEKS):
		m.schedule.append(entry)


## Runs one schedule entry ("weights:2", or "" = rest).
static func run_entry(m: MonsterData, entry: String) -> Array:
	if entry == "":
		m.last_effort = -1
		return Care.rest(m)
	var parts := entry.split(":")
	var d := find(parts[0])
	if d == null:
		return Care.rest(m)
	return run(m, d, int(parts[1]) if parts.size() > 1 else 1)["lines"]


static func run(m: MonsterData, d: DrillDef, level: int) -> Dictionary:
	level = clampi(level, 1, 4)
	var lv := level - 1
	var lines: Array = []
	# effort: willing, focused, bonded kami try harder; tired and stressed ones don't
	var effort := int(clampf(55.0 + m.bonding * 0.25 + m.focus * 4.0 - m.fatigue / 25.0 - m.stress / 40.0
		+ m.policy * 0.15 + randf_range(-20.0, 20.0), 0.0, 100.0))
	m.last_effort = effort
	var mult: float = LV_GAIN[lv] * (0.4 + effort / 100.0) * Care.cap_mult(m)
	var pref: Array = LIKES.get(m.personality, ["", ""])
	if pref[0] == d.stat:
		mult *= 1.25
	elif pref[1] == d.stat:
		mult *= 0.8
	var great := effort >= 90 and randf() < 0.35
	if great:
		mult *= 1.5
		lines.append("GREAT SUCCESS!")
	_add(m, d.stat, maxi(1, int(round(randi_range(d.gain_min, d.gain_max) * mult))), lines)
	if d.side_stat != "none" and d.side_gain != 0:
		_add(m, d.side_stat, int(round(d.side_gain * LV_GAIN[lv])), lines)
	var q := m.quirks
	if ("hivemind" in q and randf() < 0.35) or ("multithreaded" in q and randf() < 0.2):
		_add(m, MonsterData.STAT_NAMES[randi() % 5], 2 * level, lines)
	# gauges, scaled by body form
	var fat_k := 2.0 if m.form > 50 else (1.5 if m.form > 25 else 1.0)
	var str_k := 1.5 if m.form < -25 else 1.0
	m.fatigue = mini(999, m.fatigue + int(LV_FATIGUE[lv] * fat_k))
	m.stress = mini(999, m.stress + int(LV_STRESS[lv] * str_k))
	m.fullness = maxi(0, m.fullness - LV_HUNGER[lv])
	m.form = clampi(m.form - 2 * level, -100, 100)
	m.policy -= signi(m.policy) * randi_range(1, 3)  # policy drifts back toward Normal
	lines.push_front("%s: %s Lv%d, effort %d%% (%s)." % [m.name, d.display_name, level, effort, Care.effort_band(m, effort)])
	lines.append("  Fatigue %s   Stress %s   %s" % [Care.fatigue_word(m.fatigue), Care.stress_word(m.stress), Care.fullness_word(m.fullness)])
	return {"lines": lines, "effort": effort}


static func _add(m: MonsterData, stat: String, g: int, lines: Array) -> void:
	m.stats[stat] = clampi(m.stat(stat) + g, BalanceDef.get_def().stat_min, BalanceDef.get_def().stat_max)
	lines.append("  %s %s%d" % [stat.to_upper(), "+" if g >= 0 else "", g])
