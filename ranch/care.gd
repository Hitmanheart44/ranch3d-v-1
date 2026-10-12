class_name Care
extends RefCounted
## MR4 kami-care rules in one place (MR4_SYSTEMS.md): gauge statuses, rest, food, praise/scold,
## lifespan hits, focus, obedience, action points, rank caps, tournament/adventure costs.

const RANKS := ["E", "D", "C", "B", "A", "S"]
# personality -> temperament group (effort thresholds) and how it feels about fighting
const TEMPER := {"proud": "A", "fierce": "A", "stubborn": "A", "grumpy": "A", "curious": "B", "loyal": "B",
	"calm": "B", "cheerful": "B", "lazy": "C", "shy": "C", "anxious": "C", "mischievous": "C"}
const LIKES_BATTLE := {"fierce": 1, "proud": 1, "mischievous": 1, "shy": -1, "anxious": -1, "lazy": -1}
const BANDS := {"A": [60, 70], "B": [50, 60], "C": [40, 50]}  # [mid from, high from]
# praise/scold by effort band: [bonding, focus flags, stress, policy]
const PRAISE := {"high": [2, 1, -80, 5], "mid": [1, 1, -80, 5], "low": [-1, 0, -150, 20]}
const SCOLD := {"high": [0, 0, 150, -15], "mid": [1, 1, 80, -5], "low": [2, 1, 80, -10]}
const STACK := [1.0, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5]


static func fatigue_word(f: int) -> String:
	return "Exhausted" if f >= 900 else ("Worn-out" if f >= 700 else ("Tired" if f > 300 else ("OK" if f > 100 else "Lively")))


static func stress_word(s: int) -> String:
	return "Irritated" if s >= 700 else ("Frustrated" if s > 300 else "Normal")


static func fullness_word(f: int) -> String:
	return "Starving" if f <= 100 else ("Hungry" if f <= 400 else "Normal")


static func effort_band(m: MonsterData, effort: int) -> String:
	var b: Array = BANDS[TEMPER.get(m.personality, "B")]
	return "high" if effort >= b[1] else ("mid" if effort >= b[0] else "low")


static func action_points() -> int:
	return mini(1 + Game.monsters.size(), 7)   # one per kami plus one: 2 with a single kami, 7 at the maximum of 6


## MR4 obedience curve (normal policy): bonding 0 -> 53%, 50 -> 13%, 100 -> ~1-3%.
static func disobey_chance(m: MonsterData) -> float:
	var base := 0.53 * exp(-float(m.bonding) / 35.0)
	return base * (1.0 - clampf(float(m.policy) / 400.0, -0.1, 0.25))


static func cap_mult(m: MonsterData) -> float:
	return 0.1 if m.total() > BalanceDef.rank_cap(m.rank) + 50 else 1.0


static func rank_up(m: MonsterData) -> void:
	m.rank = RANKS[mini(RANKS.find(m.rank) + 1, RANKS.size() - 1)]
	m.won_rank_cup = false
	m.rank_wins = 0


static func update_focus(m: MonsterData) -> void:
	var g := [m.fatigue, m.stress, 999 - m.fullness]
	var f := 5
	for v in g:
		if v >= 250:
			f -= 1
		if v >= 900:
			f -= 1
	if g.min() >= 750:
		f = 0
	m.focus = clampi(f, 0, 5)


static func rest(m: MonsterData) -> Array:
	m.policy += 3 if m.fatigue < 100 else (2 if m.fatigue < 300 else 1)
	m.fatigue = maxi(0, m.fatigue - 370)
	m.stress = maxi(0, m.stress - 250)
	m.fullness = maxi(0, m.fullness - 66)
	return ["%s rested. Fatigue %s, stress %s." % [m.name, fatigue_word(m.fatigue), stress_word(m.stress)]]


static func feed(m: MonsterData, it: ItemDef) -> Array:
	m.fullness = clampi(m.fullness + it.fullness, 0, 999)
	m.fatigue = clampi(m.fatigue + it.fatigue, 0, 999)
	m.stress = clampi(m.stress + mini(it.stress, 0), 0, 999)  # food never raises stress (MR4)
	m.bonding = clampi(m.bonding + it.loyalty, 0, 100)
	m.form = clampi(m.form + it.form, -100, 100)
	var lines := ["%s ate the %s. (%s)" % [m.name, it.display_name, fullness_word(m.fullness)]]
	if it.stat != "none":
		m.stats[it.stat] = mini(999, m.stat(it.stat) + it.stat_gain)
		lines.append("%s +%d" % [it.stat.to_upper(), it.stat_gain])
	return lines


static func praise(m: MonsterData, scold: bool) -> Array:
	if m.last_effort < 0:
		return ["%s didn't train this week. Nothing to %s." % [m.name, "scold" if scold else "praise"]]
	var band := effort_band(m, m.last_effort)
	var fx: Array = (SCOLD if scold else PRAISE)[band]
	var k: float = STACK[mini(m.praises_this_week, STACK.size() - 1)]
	m.praises_this_week += 1
	m.bonding = clampi(m.bonding + fx[0], 0, 100)
	m.focus = clampi(m.focus + fx[1], 0, 5)
	m.stress = clampi(m.stress + int(fx[2] * k), 0, 999)
	m.policy = clampi(m.policy + fx[3], -100, 100)
	var mood := {"high": "proud", "mid": "content", "low": "sheepish"}
	return ["You %s %s (%s effort). It looks %s." % ["scolded" if scold else "praised", m.name, band, mood[band]],
		"Bonding %+d   Stress %+d" % [fx[0], int(fx[2] * k)]]


## End of the week for one kami: lifespan hits from gauges, injury/illness/runaway, focus, aging.
static func week_end(m: MonsterData) -> Array:
	var lines: Array = []
	var hit := _gauge_hit(m.fatigue) + _gauge_hit(m.stress)
	if m.fullness <= 100:
		hit += 0.5
		if m.fullness == 0:
			m.stress = mini(999, m.stress + 100)
			m.fatigue = mini(999, m.fatigue + 100)
		lines.append("%s is starving!" % m.name)
	if m.fatigue >= 700 and m.stress >= 500 and randf() < 0.35:
		hit += 4.0
		lines.append("%s fell ill from overwork." % m.name)
	elif m.fatigue >= 500 and m.stress >= 700 and randf() < 0.25:
		hit += 4.0
		lines.append("%s ran away for a few days and came back worse for wear." % m.name)
	if hit >= 1.0:
		m.life_lost += hit
		lines.append("%s's health suffered this week." % m.name)
	m.fullness = maxi(0, m.fullness - 40)  # a week of living
	m.praises_this_week = 0
	m.last_effort = -1
	update_focus(m)
	return lines


static func _gauge_hit(v: int) -> float:
	return 2.0 if v >= 900 else (1.2 if v >= 700 else (0.6 if v >= 500 else (0.2 if v > 300 else 0.0)))


static func tournament_cost(m: MonsterData, won: bool) -> Array:
	var like: int = LIKES_BATTLE.get(m.personality, 0)
	m.fatigue = mini(999, m.fatigue + (229 if won else 300))
	m.fullness = maxi(0, m.fullness - 100)
	var ds: int = ([20, 0, -60] if won else [100, 0, 20])[like + 1]
	m.stress = clampi(m.stress + ds, 0, 999)
	var lines: Array = ["Fatigue +%d   Stress %+d" % [229 if won else 300, ds]]
	lines.append_array(_injury(m, 0.08 if won else 0.3, 3.0))
	return lines


## A fight can leave a kami hurt; injuries quietly shorten its life (the owner never sees by how much).
static func _injury(m: MonsterData, chance: float, weeks: float) -> Array:
	if randf() >= chance:
		return []
	m.life_lost += weeks
	m.stress = mini(999, m.stress + 60)
	return ["%s was hurt in the fight." % m.name]


static func adventure_cost(m: MonsterData, cleared: bool) -> void:
	m.fatigue = mini(999, m.fatigue + (150 if cleared else 500))
	m.fullness = maxi(0, m.fullness - 120)
	if randf() < (0.05 if cleared else 0.25):  # hurt in the dungeon: a quiet life hit
		m.life_lost += 3.0


## Kami that trained the same drill in the same week grow closer; any two that both trained, a little.
static func training_bonds(monsters: Array, skip: String) -> Array:
	var lines: Array = []
	for i in monsters.size():
		for j in range(i + 1, monsters.size()):
			var a: MonsterData = monsters[i]
			var b: MonsterData = monsters[j]
			if a.name == skip or b.name == skip or a.schedule.is_empty() or b.schedule.is_empty():
				continue
			var da := str(a.schedule[0]).split(":")[0]
			var db := str(b.schedule[0]).split(":")[0]
			if da == "" or db == "":
				continue
			var before := Game.pair_bond(a.name, b.name)
			Game.add_pair_bond(a.name, b.name, 6 if da == db else 2)
			if da == db and before < 50 and Game.pair_bond(a.name, b.name) >= 50:
				lines.append("%s and %s have become good friends." % [a.name, b.name])
	return lines
