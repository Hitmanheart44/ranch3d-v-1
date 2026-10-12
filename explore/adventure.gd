class_name Adventure
extends RefCounted
## Dungeon list for MR4-style adventures (MR4_SYSTEMS.md): same structure as MR4 (5/7/8/10 floors by rank,
## harder "+" versions), our own places. The dungeon scene is explore/dungeon.gd.

# id, name, recommended rank, floors, foe stat total
const DUNGEONS := [
	["hollow", "The Machine Graveyard", "E", 5, 340],
	["thornwild", "The Haunted Forest", "D", 7, 480],
	["spires", "The Desert", "C", 7, 590],
	["cinder", "The Tropical Island", "B", 8, 700],
	["thornwild_a", "The Evil Swamp", "A", 10, 900],
	["hollow_s", "The Ruined Castle", "S", 10, 1100],
]


static func get_dungeon(id: String) -> Array:
	for d in DUNGEONS:
		if d[0] == id:
			return d
	return DUNGEONS[0]


## The dungeons you may enter: those of your trainer rank (the highest rank of any kami you have made) and below.
static func dungeon_choices() -> Array:
	var cap := Game.RANKS.find(Game.trainer_rank())
	var out: Array = []
	for d in DUNGEONS:
		if Game.RANKS.find(d[2]) > cap:
			continue
		out.append(["dungeon:" + d[0], "%s   (RANK %s)" % [d[1].to_upper(), d[2]], "%d floors, boss on the last  //  foes ~%d stat points" % [d[3], d[4]]])
	return out


## Spirit gauge for a team: adventure levels + team size (MR4: levels, affinity, items).
static func spirit_max(team: Array) -> int:
	var s := 40
	for m in team:
		s += 20 + (m as MonsterData).adv_level * 10
	return s
