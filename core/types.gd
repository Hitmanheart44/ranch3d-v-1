class_name Types
extends RefCounted
## Elemental types: colors and the matchup table. Pure data + tiny helpers.

const COLORS := {
	"fire": Color(0.91, 0.39, 0.24),
	"water": Color(0.25, 0.55, 0.95),
	"plant": Color(0.35, 0.76, 0.40),
	"rock": Color(0.62, 0.45, 0.28),
	"metal": Color(0.62, 0.66, 0.72),
	"magic": Color(0.95, 0.45, 0.85),
	"dark": Color(0.40, 0.25, 0.55),
	"light": Color(1.0, 0.95, 0.70),
}

# Each type is strong (x1.5) against the listed types, and takes x0.7 from them back.
const BEATS := {  # placeholder wheel (owner sets matchups later); no pair beats each other both ways
	"fire": ["plant", "metal"],
	"water": ["fire", "rock"],
	"plant": ["water", "rock"],
	"rock": ["fire"],
	"metal": ["rock"],
	"magic": ["light"],
	"light": ["dark"],
	"dark": ["magic"],
}


static func color(t: String) -> Color:
	return COLORS.get(t, Color.WHITE)


## The type color pushed to full brightness: the light a kami gives off (HUD bars, auras, bolts).
static func glow(t: String) -> Color:
	var c := color(t)
	if c.s < 0.15:
		return Color(0.6, 0.8, 1.0)  # metal: cold steel-blue instead of grey
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.2 + 0.1), 1.0)


static func mult(atk: String, dfn: String) -> float:
	if dfn in BEATS.get(atk, []):
		return 1.5
	if atk in BEATS.get(dfn, []):
		return 0.7
	return 1.0
