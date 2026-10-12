class_name Schedule
extends RefCounted
## The yearly tournament calendar (MR4-style). A year is 48 weeks: 12 months x 4 weeks, repeating every year.
## Regular cups (data/cups/*.tres) run in set weeks by rank. Once a year (Late Summer, week 4) there is a Promotion
## Match for every rank below S: only kami with 3 cup wins at their current rank may enter; win it to rank up.
## Best case: E->D at week 24, then one rank a year, S at week 216 = exactly 4.5 years. Kami live 4-6 years.
## Entries are signed up at the Association (Game.entries) and fought when you end that week at your house.
##   Schedule.events_in(month)        -> [{id, name, rank, kind, month, week, cup}]
##   Schedule.week_of_year(abs_week)  -> 0..47

const WEEKS_PER_YEAR := 48
const PROMO_MONTHS := [5]  # Late Summer: the year's promotion matches
const WINS_TO_PROMOTE := 3
# when each rank's regular cup runs: [months (0-based; empty = every month), week of the month 1..4]
const REGULAR := {
	"E": [[], 2], "D": [[], 3], "C": [[0, 2, 4, 6, 8, 10], 1], "B": [[1, 3, 5, 7, 9, 11], 1],
	"A": [[1, 4, 7, 10], 2], "S": [[5, 11], 3],
}


static func week_of_year(abs_week: int) -> int:
	return (abs_week - 1) % WEEKS_PER_YEAR


static func month_of(abs_week: int) -> int:
	return week_of_year(abs_week) / 4


## Absolute week number of (month, week 1..4) on or after `from_week`.
static func abs_week(month: int, week: int, from_week: int) -> int:
	var target := month * 4 + (week - 1)
	var cur := week_of_year(from_week)
	var delta := (target - cur + WEEKS_PER_YEAR) % WEEKS_PER_YEAR
	return from_week + delta


static func events_in(month: int) -> Array:
	var out: Array = []
	for c in CupDef.all():
		var r: Array = REGULAR.get(c.rank, [[], 4])
		if (r[0] as Array).is_empty() or month in r[0]:
			out.append({"id": "cup:" + str(c.id), "name": c.display_name, "rank": c.rank, "kind": "regular", "month": month,
				"week": int(r[1]), "cup": c})
	if month in PROMO_MONTHS:
		for rk in Game.RANKS:
			if rk == "S":
				continue
			out.append({"id": "promo:" + rk, "name": "%s-Rank Promotion Match" % rk, "rank": rk, "kind": "promotion",
				"month": month, "week": 4, "cup": promo_cup(rk)})
	out.sort_custom(func(a, b): return a["week"] < b["week"] or (a["week"] == b["week"] and Game.RANKS.find(a["rank"]) < Game.RANKS.find(b["rank"])))
	return out


## The promotion match for a rank: three opponents at the strength of the next rank's cup.
static func promo_cup(rk: String) -> CupDef:
	var c := CupDef.new()
	c.id = StringName("promo_" + rk.to_lower())
	c.display_name = "%s-Rank Promotion Match" % rk
	c.rank = rk
	var next: String = Game.RANKS[mini(Game.RANKS.find(rk) + 1, Game.RANKS.size() - 1)]
	var base := 300
	for k in CupDef.all():
		if k.rank == rk:
			base = k.foe_total
	for k in CupDef.all():
		if k.rank == next:
			c.foe_total = int((base + k.foe_total) / 2)
	if c.foe_total == 0:
		c.foe_total = int(base * 1.2)
	c.entry_fee = 0
	c.prize = base * 2
	c.rounds = 3
	c.ai_skill = 0.35 + 0.08 * Game.RANKS.find(rk)
	return c


static func find(event_id: String, month: int) -> Dictionary:
	for e in events_in(month):
		if e["id"] == event_id:
			return e
	return {}


## Can this kami sign up? Regular cups: its rank or below. Promotion: exactly its rank.
static func eligible(e: Dictionary, m: MonsterData) -> bool:
	if e["kind"] == "promotion":
		return m.rank == e["rank"] and m.rank_wins >= WINS_TO_PROMOTE
	return Game.RANKS.find(e["rank"]) <= Game.RANKS.find(m.rank)


## The entry (if any) being fought this week.
static func entry_now() -> Dictionary:
	for en in Game.entries:
		if int(en["week"]) == Game.week:
			return en
	return {}


static func registered(event_id: String, wk: int) -> Dictionary:
	for en in Game.entries:
		if en["event"] == event_id and int(en["week"]) == wk:
			return en
	return {}


## Drop entries whose week has passed (missed).
static func prune() -> Array:
	var missed: Array = []
	for en in Game.entries.duplicate():
		if int(en["week"]) < Game.week:
			Game.entries.erase(en)
			missed.append(en)
	return missed
