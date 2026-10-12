class_name Damage
extends RefCounted
## The one damage formula (carried over from ChipMon / the alpha, scaled for real-time combat).
##   dmg = max(MIN_HIT, (atk_stat * atk_mult * type_mult - guard * def_mult) * jitter 0.85..1.15 * SCALE)
##   guarding x0.4, attacker fatigue x(1 - fatigue/3000), never below 1.
## SCALE exists because the alpha's numbers were tuned for turn-based fights (2-3 hits to KO);
## real-time fights should take ~8-12 landed strikes. Balance by changing SCALE first.

const GUARD_MULT := 0.4
const SCALE := 0.25
const MIN_HIT := 2.0


static func max_hp(m: MonsterData) -> int:
	return 100 + m.stat("hp") * 3


## Returns {amount, base, mult, guarded}. `base` is before jitter/guard/fatigue (for tests and UI).
static func compute(att: MonsterData, dfn: MonsterData, move: MoveDef, guarding: bool = false, jitter: float = -1.0) -> Dictionary:
	if jitter < 0.0:
		jitter = randf_range(0.85, 1.15)
	var raw := float(att.stat(move.atk_stat)) * move.atk_mult
	var reduce := float(dfn.stat("guard")) * move.def_mult
	var mult := Types.mult(att.type, dfn.type) if move.use_type else 1.0
	var base := raw * mult - reduce
	var amount := int(maxf(MIN_HIT, base * jitter * SCALE))
	if guarding:
		amount = int(float(amount) * GUARD_MULT)
	amount = maxi(1, int(float(amount) * (1.0 - float(att.fatigue) / 3000.0)))  # fatigue 0..999
	return {"amount": amount, "base": base, "mult": mult, "guarded": guarding}


## Lowest and highest damage compute() can return for this base (used by tests/debug checks).
static func expected_range(base: float, guarded: bool, fatigue: int) -> Vector2i:
	var k := (GUARD_MULT if guarded else 1.0) * (1.0 - float(fatigue) / 3000.0)
	var lo := maxi(1, int(float(int(maxf(MIN_HIT, base * 0.85 * SCALE))) * k))
	var hi := maxi(1, int(float(int(maxf(MIN_HIT, base * 1.15 * SCALE))) * k))
	return Vector2i(lo, hi)
