extends Node
## Game state (autoload "Game"): owned kami, money, week, rank. The rules for changing them live here,
## every change is announced on Events, and Save turns it into JSON and back.
##   Game.new_game(Summoner.summon_machine())
##   Game.advance_week()        # ages every kami one week
##   if Game.spend(40): ...     # false if not enough money

const START_MONEY := 500
const MAX_MONSTERS := 6
const RANKS := ["E", "D", "C", "B", "A", "S"]

var monsters: Array[MonsterData] = []
var active_index := 0
var money := START_MONEY
var week := 1
## Cup sign-ups: [{event, name, week (absolute), kami (name), kind}] (see core/schedule.gd)
var entries: Array = []
## The last week whose start-of-week planner was finished (so it opens once per week).
var planned_week := 0
## The last week whose training ran (the planner's "out to the ranch" runs it; then it's the weekend).
var trained_week := 0
var rank := "E"
## The highest rank any kami you have made has reached (retired ones count). It decides which dungeons you may enter.
var top_rank := "E"
## MR4 week phase: "week" (training) -> "free" (action points) -> "weekend".
var phase := "week"
var ap := 0
## Live dungeon run (survives trips to the arena; not saved: quitting mid-dungeon abandons it).
var run: Dictionary = {}
## Seeds already summoned from hardware this game.
var summoned: Array = []
## Item counts by id (stones from expeditions, etc.).
var inventory: Dictionary = {}
## Retired kami: [{name, breed, stats, age_weeks, week_retired, cause}]
var hall: Array = []
## Encyclopedia: species id -> {"owned": bool, "fought": int}. Filled by see().
var seen: Dictionary = {}
## Friendship between kami (0..100), keyed "A|B" with names sorted. Grows when they train the same drill together.
var pair_bonds: Dictionary = {}


var intro_seen := false
## Ranch additions built so far (RanchLayout.SITES). A new ranch is just a house and a pen for one kami.
var ranch_upgrades: Array = ["house", "pen"]
## Stable level 0..3: the ranch holds 1, 2, 3, then 6 kami (see RanchRules.CAPACITY). Raised by story events.
var stable_level := 0
var trainer := ""  # "f" / "m": which trainer you play ("" = not chosen yet)
var player_name := "Rio"


func new_game(first: MonsterData = null) -> void:  # v2: a new game starts with no kami (intro, then summon)
	monsters.clear()
	active_index = 0
	money = START_MONEY
	week = 1
	entries = []
	planned_week = 0
	trained_week = 0
	rank = "E"
	top_rank = "E"
	hall = []
	summoned = []
	inventory = {}
	phase = "week"
	ap = 0
	intro_seen = false
	ranch_upgrades = ["house", "pen"]
	stable_level = 0
	trainer = ""
	player_name = "Rio"
	if first != null:
		add_monster(first)
	Events.money_changed.emit(money)
	Events.week_advanced.emit(week)


func active() -> MonsterData:
	return monsters[active_index] if active_index < monsters.size() else null


func set_active(i: int) -> void:
	active_index = clampi(i, 0, maxi(0, monsters.size() - 1))
	Events.active_changed.emit(active())


func add_monster(m: MonsterData) -> bool:
	if monsters.size() >= MAX_MONSTERS:
		return false
	monsters.append(m)
	see(str(m.main_breed), true)
	Events.monster_added.emit(m)
	if monsters.size() == 1:
		set_active(0)
	return true


func remove_monster(m: MonsterData) -> void:
	var i := monsters.find(m)
	if i < 0:
		return
	monsters.remove_at(i)
	Events.monster_removed.emit(m)
	if active_index >= monsters.size():
		set_active(monsters.size() - 1)


func add_item(id: String, n: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + n
	if int(inventory[id]) <= 0:
		inventory.erase(id)


func add_money(n: int) -> void:
	money = maxi(0, money + n)
	Events.money_changed.emit(money)


## Pay `n` if affordable. Returns false (and changes nothing) otherwise.
func spend(n: int) -> bool:
	if n > money:
		return false
	add_money(-n)
	return true


## Time passes for every kami: they age and decline in old age. (MR4: only Rest recovers fatigue/stress.)
func advance_week(n: int = 1) -> void:
	week += n
	for m in monsters:
		m.age_weeks += n
		if not m.schedule.is_empty():   # this week's planned entry is used up; the next planned week moves to the front
			m.schedule.pop_front()
		if m.life_left() < m.lifespan_weeks / 4:  # old age: a random stat slips each week
			var s: String = MonsterData.STAT_NAMES[randi() % 5]
			m.stats[s] = maxi(1, m.stat(s) - n)
	Events.week_advanced.emit(week)


## Kami whose lifespan has run out.
func expired() -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for m in monsters:
		if m.life_left() <= 0.0:
			out.append(m)
	return out


## Move a kami to the Hall of Fame.
func retire(m: MonsterData, cause: String = "retired") -> void:
	hall.append({"name": m.name, "breed": m.breed_label(), "stats": m.stats.duplicate(), "age_weeks": m.age_weeks,
		"week_retired": week, "cause": cause, "rank": m.rank})
	remove_monster(m)


## The trainer rank: the highest rank among your kami, now or ever (a high-water mark, saved).
func trainer_rank() -> String:
	var best := RANKS.find(top_rank)
	for m in monsters:
		best = maxi(best, RANKS.find((m as MonsterData).rank))
	for h in hall:
		best = maxi(best, RANKS.find(str((h as Dictionary).get("rank", "E"))))
	top_rank = RANKS[maxi(best, 0)]
	return top_rank


func rank_up() -> void:
	var i := RANKS.find(rank)
	if i >= 0 and i < RANKS.size() - 1:
		rank = RANKS[i + 1]


## A story event raises the stable to its next level (capacity 1 -> 2 -> 3 -> 6).
func raise_stable() -> bool:
	if stable_level >= 3:
		return false
	stable_level += 1
	return true


func see(species_id: String, owned := false) -> void:
	var e: Dictionary = seen.get(species_id, {"owned": false, "fought": 0})
	if owned:
		e["owned"] = true
	else:
		e["fought"] = int(e["fought"]) + 1
	seen[species_id] = e


func pair_key(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])


func pair_bond(a: String, b: String) -> int:
	return int(pair_bonds.get(pair_key(a, b), 0))


func add_pair_bond(a: String, b: String, n: int) -> void:
	pair_bonds[pair_key(a, b)] = clampi(pair_bond(a, b) + n, 0, 100)


func to_dict() -> Dictionary:
	var ms: Array = []
	for m in monsters:
		ms.append(m.to_dict())
	return {"version": 1, "monsters": ms, "active": active_index, "money": money, "week": week, "rank": rank, "hall": hall,
		"summoned": summoned, "inventory": inventory, "phase": phase, "ap": ap, "intro_seen": intro_seen, "ranch_upgrades": ranch_upgrades, "stable_level": stable_level, "trainer": trainer, "player_name": player_name, "entries": entries, "planned_week": planned_week, "top_rank": top_rank, "trained_week": trained_week, "pair_bonds": pair_bonds, "seen": seen}


func from_dict(d: Dictionary) -> void:
	monsters.clear()
	for md in d.get("monsters", []):
		monsters.append(MonsterData.from_dict(md))
	money = int(d.get("money", START_MONEY))
	week = int(d.get("week", 1))
	rank = str(d.get("rank", "E"))
	hall = d.get("hall", [])
	summoned = d.get("summoned", [])
	inventory = d.get("inventory", {})
	phase = str(d.get("phase", "week"))
	ap = int(d.get("ap", 0))
	intro_seen = bool(d.get("intro_seen", true))
	ranch_upgrades = d.get("ranch_upgrades", ["house", "pen"])
	stable_level = clampi(int(d.get("stable_level", 0)), 0, 3)
	trainer = str(d.get("trainer", "f"))
	player_name = str(d.get("player_name", "Rio"))
	entries = d.get("entries", [])
	planned_week = int(d.get("planned_week", 0))
	top_rank = str(d.get("top_rank", "E"))
	trained_week = int(d.get("trained_week", 0))
	pair_bonds = d.get("pair_bonds", {})
	seen = d.get("seen", {})
	for m in monsters:   # saves from before the encyclopedia: everything you own counts as discovered
		see(str(m.main_breed), true)
	active_index = clampi(int(d.get("active", 0)), 0, maxi(0, monsters.size() - 1))
	Events.game_loaded.emit()
