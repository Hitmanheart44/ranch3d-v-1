class_name BalanceDef
extends Resource
## The numbers that tie ranks, stats and opposition together. One file: data/balance.tres. Every stat lives in [stat_min, stat_max].
## Rank order is E, D, C, B, A, S. A kami's gains drop to 10% once its stat total passes its rank's cap + 50 (it must rank up to grow).

@export var stat_min := 5
@export var stat_max := 250
## Stat-total cap per rank (E..S). S equals 5 x stat_max: every stat can reach the maximum.
@export var rank_caps := PackedInt32Array([480, 640, 800, 960, 1110, 1250])
## Foe stat total for adventure encounters per rank (E..S); cups carry their own foe_total in data/cups.
@export var adventure_totals := PackedInt32Array([340, 480, 590, 700, 900, 1100])
## Total a freshly summoned kami starts with.
@export var start_total := 300


static var _def: BalanceDef


static func get_def() -> BalanceDef:
	if _def == null:
		_def = load("res://data/balance.tres") as BalanceDef
	return _def


static func rank_index(rank: String) -> int:
	return maxi(0, ["E", "D", "C", "B", "A", "S"].find(rank))


static func rank_cap(rank: String) -> int:
	return get_def().rank_caps[rank_index(rank)]


static func adventure_total(rank: String) -> int:
	return get_def().adventure_totals[rank_index(rank)]
