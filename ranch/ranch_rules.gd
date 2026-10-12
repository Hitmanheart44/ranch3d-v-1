class_name RanchRules
extends RefCounted
## What the ranch can hold. A new ranch is a house and a pen (one kami); additions are bought at the carpenter.
## Pure data + rules: the maps decide where each building stands.

## id: [price G, display name, blurb]
const ADDITIONS := {"training": [1200, "Training yard", "A fenced yard with gadget pads for harder drills."],
	"storage": [600, "Storage", "Crates and a trough: keep more food on hand."]}

## Kami the ranch holds at stable level 0..3. The levels are raised by story events (`Game.raise_stable()`).
const CAPACITY := [1, 2, 3, 6]


static func capacity() -> int:
	return CAPACITY[clampi(Game.stable_level, 0, CAPACITY.size() - 1)]
